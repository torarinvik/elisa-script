# WASM export scanner parity contract

Reference: `Elisa-compiler/scripts/wasm_export_scan.py` at commit
`0019dfcfff405b98369dd1b51562619668e29707` (`main`). Do not silently switch
to the separate `wasm-sdk-compiler` worktree: it is three commits behind and
maps `int` to `i64`, while the pinned main scanner, facade, documentation, and
unit assertion agree on `int -> i32` for wasm32. The source scanner is an
implementation detail imported by `scripts/wasm_build.py`; replacing it
requires a structured interface usable by that caller, not merely similar
human-readable output.

## `parse_exports` observable contract

- Scan source lines in order with one-based line numbers using Python's
  `str.splitlines()` boundaries. This is a line/regex scanner, not the Elisa
  parser. Preserve accepted lines, skipped malformed lines, row order,
  duplicate handling, and exact error text.
- The candidate materializes line views before scanning and caps that metadata
  at 131,072 lines. More lines fail with
  `WASM source line count exceeds Elisascript scan limit`. This candidate-only
  safeguard prevents newline-dense input from allocating millions of line
  descriptors; generated boundary cases must not reach the Python oracle.
- `@link_name(...)` accepts either a quoted, possibly empty string or an ASCII
  identifier. A non-empty pending name survives blank and `#` comment lines;
  the last annotation wins. It attaches only to the next recognized export.
  Any other nonblank, non-comment line clears it. An empty quoted annotation
  clears any earlier name and is not emitted. Implicit `main` rows never inherit
  it.
- Explicit declarations match the pinned Python `EXPORT_RE` whole-line grammar:
  `export fn IDENT(params) [-> type] [= IDENT [A-Za-z0-9_:]*]`. This regex is
  more permissive than a namespace parser: once the target's first ASCII
  identifier character is present, any following ASCII letters, digits,
  underscores, and colons are accepted, including `a:`, `a:::b`, and `a::::b`.
  Preserve this observed behavior; target resolution or a future grammar
  tightening belongs to a separately versioned change. The target defaults to
  the public name and the return type defaults to `void`. Unmatched
  export-looking text is ignored. Duplicate public names fail with
  `duplicate WASM export 'NAME' on line N` before parsing that row.
- Parameter capture follows Python's greedy `(.*)`: when nested type syntax
  contains several `)` characters, use the rightmost closing parenthesis whose
  suffix matches the return/target grammar. The implicit-main matcher applies
  the same greedy choice.
- To prevent adversarial malformed headers from making that compatibility scan
  quadratic, Elisascript applies one aggregate weighted work ceiling of
  1,048,576 units to right-to-left header rescans across the flattened source.
  Reverse-search bytes cost one unit; each suffix candidate charges 16 fixed
  units plus eight times the remaining suffix bytes before parsing it. This
  meter bounds the repeated/backtracking work, not every instruction; the
  remaining prefix and line scans are linear in the separate 8 MiB source cap.
  Explicit exports and implicit `main` share this guard and fail with
  `WASM header scan work exceeds Elisascript scan limit`. This is an
  Elisascript-specific resource safeguard, not a Python behavior. Its generated
  candidate-only regressions cover a single expensive header and multiple
  individually-under-limit headers that exceed the aggregate; they do not
  invoke the pinned Python parser on hostile input, which has no corresponding
  work ceiling.
- Duplicate-name detection also has one 1,048,576-unit aggregate comparison
  budget across the flattened source. Before each name equality check, the
  candidate charges the smaller byte length of the two nonempty ASCII
  identifiers, bounding both compared bytes and the number of comparisons; an
  exhausted budget fails with
  `WASM export-name comparison work exceeds Elisascript scan limit`. Implicit
  `main` presence is tracked separately as a boolean, avoiding a full name-list
  scan for every ordinary source line. A generated unique-export exhaustion
  case is candidate-only because the Python oracle has no matching budget.
- A whole-line `def main(params) [-> type]:` adds an implicit `main` row at that
  source position only if `main` has not already been seen. An explicit `main`
  before it suppresses the implicit row; an explicit `main` after it is a
  duplicate. At most one implicit row is emitted.
- Split parameters on top-level commas and defaults on the first top-level
  `=`. Both scans honor nested `()`, `[]`, `{}`, quoted strings, and backslash
  escapes; empty parameter segments are discarded. Nesting is depth-counted,
  not delimiter-pair validated. A parameter needs a colon and an ASCII
  identifier name. Its first colon separates name from type.
- Normalize each type by trimming it, removing one leading storage modifier
  (`mutable`, `lmut`, `heap`, `stack`, or `static`) followed by whitespace, then
  removing all remaining whitespace. Preserve the stripped raw default string
  or null.
- Each export row has ordered fields `name`, `target`, `parameters`, `return`,
  `binding`, `wasm_type`, `line`, then optional `link_name` or `implicit`.
  Parameter fields are ordered `name`, `type`, `default`, `binding`,
  `wasm_type`. Parameter and export order are source order. JSON IPC comparison
  must distinguish absent optional keys, null defaults, empty strings, booleans,
  and integers rather than comparing a lossy TSV projection.
- ABI mappings: `i8/u8/i16/u16/i32/u32/int/isize/usize/uintptr/bool ->
  (scalar,i32)`; `i64/u64/char -> (scalar,i64)`; `f32 -> (scalar,f32)`;
  `f64 -> (scalar,f64)`; `void -> (scalar,void)`; `cstr -> (string,i32)`;
  types ending in `&` (including `&&`) -> `(pointer,i32)`. Nullable types fail
  before other mapping checks. Every other type fails with the actionable
  `export a scalar or pointer adapter` diagnostic.
- Component ABI mode matches the pinned parser's `component=True` behavior:
  after nullable, `cstr`, pointer, and built-in scalar checks, any remaining
  named type maps to `(scalar,i32)` for later WIT/component validation. The
  candidate exposes this as `--component <source>` for the export array and
  `--build-component-payload <source>` for the build payload. The ordinary
  `--build-payload` remains strict and rejects unsupported types.
- Parameter shape errors identify the exported function and original text.
  Invalid parameter names, nullable types, and unsupported ABI types preserve
  Python's exact message and validation order. If no export or implicit main
  remains, fail with ``WASM source has no exported function; add `export fn
  name(...) -> T = target` ``.

## Candidate CLI process protocol

The launcher accepts the default export-array form
`<launcher> scripts/wasm_export_scan.elisascript <absolute-source-path>`, its
component form `--component <absolute-source-path>`, and the payload forms
`--build-payload <absolute-source-path>`, `--build-component-payload
<absolute-source-path>`, or `--flatten-payload <absolute-source-path>`.
These options are reserved in the first operand position. The build-payload
form is a caller-migration seam: its compact JSON object has ordered
fields `version`, `flattened_source`, and `exports`; `version` is integer `1`,
`flattened_source` is the exact UTF-8 include-expanded source consumed by the
scanner, and `exports` has the row schema above. Its JSON bytes are capped at
64 MiB minus one byte so the final newline keeps total stdout at or below the
differential runner's 64 MiB hard capture limit. The scanner additionally caps
each export at 4,096 parameters and the complete export set at 16,384
parameters. The optional host-side payload client applies the same aggregate
ceiling before passing records to the build flow. These cardinality limits do
not impose a hard RSS bound on the subprocess or on JSON decoding. All modes
use the same bounded path loader.

The component option is reserved in the first operand position, like the
payload options. `--component` emits only the JSON export array;
`--build-component-payload` emits the same ordered version-1 shape as
`--build-payload`, with component ABI mappings enabled.

The flatten-payload form does not require exports. Its ordered version-1 object
contains only `version` and `flattened_source`, allowing callers to use the
candidate's include expansion for runtime-source cache keys without invoking
the export parser.

The default form emits only the compact ordered JSON export array. Each payload
form emits its compact object. On success, every form exits with status `0`,
appends one newline to stdout, and leaves stderr empty. Process failures are:

- On a source, include, parse, ABI, or bounded-resource failure: exit status
  `1`, empty stdout, and stderr containing exactly
  `wasm export scan: MESSAGE\n`, where `MESSAGE` is the candidate/reference
  diagnostic for the case.
- On an invalid mode/operand count: exit status `2`, empty stdout, and stderr
  exactly `usage: wasm export scan <source> | --component <source> | --build-payload <source> | --build-component-payload <source> | --flatten-payload <source>\n`.

The launcher parity source compares status/stdout/stderr for the default
single-source invocation and scanner cases. It also compares the build payload
against the Python adapter for ordinary, component-enum, nested, diamond, missing, and
Unicode-line-separator inputs, and checks the candidate's invalid-arity tuple
for default and payload modes. The source fixture separately pins flatten-only
include expansion order, including a file with no export-parser dependency.
The arity check is not compared against the
Python adapter: the adapter has its own optional expected-JSON argument and
its usage text is not the candidate CLI contract.
The length-delimited response frame used by `differential_path_response` is an
in-process test transport; it is not part of the public launcher's stdout
protocol. The launcher source, payload comparisons, and arity checks remain
unexecuted under the validation hold.

## `read_flat_source` observable contract

- Resolve each path before cycle/dedup checks. Detect a path already on the
  active stack before checking the global seen set. A cycle reports the full
  resolved chain; a repeated completed include contributes the empty string.
- Python `Path.resolve()` is non-strict by default: it returns a canonicalized
  absolute spelling for a missing leaf after resolving existing symlink
  prefixes. The candidate walks components from the root or current directory,
  resolves every existing component before processing a following `..`, and
  retains missing suffix components so a later `..` can cancel them. When a
  component is a dangling symlink, it reads the link target and prepends that
  target to the unprocessed component worklist; relative targets begin at the
  link's parent, absolute targets reset to the root, and target `.`/`..`
  components use the same iterative resolver. Raw, target, and resolved path
  spellings are capped at fewer than 4096 bytes (maximum 4095). Aggregate path
  work charges components, target spelling bytes, and tail rewrites; dangling
  link expansion also has a 128-hop per-path ceiling to bound cycles. Fixtures
  compare missing leaves under an existing directory and symlink,
  `alias/../child` where `alias` points to a nested directory, and links
  beneath a distinct `links/` parent so relative-target origin is observable.
  The dangling-link cases cover relative and absolute targets, nested links,
  original child and post-link `../child` tails, target
  `../missing/../actual` cancellation to an existing file, and a target that
  remains missing. The
  cycle/hop rejection is candidate-specific; successful and missing-path cases
  are compared with the pinned Python adapter.
- The optional `seen` set and active `stack` list are caller-owned and mutated:
  add the resolved file to `seen`, then to `stack` before reading. Successful
  reads pop the stack; a read/decode/child error leaves those mutations in
  place because the Python implementation has no `finally` cleanup. The
  Elisascript CLI owns these collections, checks cycles before de-duplication,
  and uses an explicit depth-first frame stack; caller-visible mutation of
  Python's optional collections is outside its CLI protocol.
- Require a regular file and strict UTF-8. Relative includes resolve against
  the including file's resolved parent; absolute includes are used directly.
  Expand includes depth-first in source order, without adding a newline at the
  include site. Preserve each non-include line and ending yielded by Python's
  `splitlines(keepends=True)`. The Elisascript loader applies per-file and
  aggregate byte ceilings plus path-spelling, aggregate path-component work,
  include-file, directive, and depth ceilings; those bounded rejection cases
  are Elisascript-specific safeguards. The candidate now opens the resolved
  path with `O_NONBLOCK | O_NOFOLLOW`, verifies with `fstat` that the opened
  descriptor is a regular file, and compares its device/inode with path stats
  taken before and after opening. It reads fixed-size chunks under the minimum
  of the per-file and remaining graph budgets, rejecting an overflow probe
  before retaining that chunk, and closes the descriptor on handled success and
  failure. `open`, `stat`, `fstat`, and `read` interruption retries are bounded
  to four per operation. `O_NONBLOCK` prevents a final-component FIFO
  replacement from waiting for a writer; `fstat` rejects opened non-regular
  objects before any read. Device-specific open behavior remains
  platform-dependent. The identity
  comparisons detect a regular-file replacement during the open/check window;
  after validation, reads stay attached to the opened descriptor even if the
  pathname is replaced. Source review indicates this avoids buffering an
  oversized file in full, but execution evidence is still required. The
  candidate-only fixture writes a file one byte over the 8 MiB per-file ceiling
  and expects rejection without invoking Python. Another candidate-only fixture
  combines five individually admissible 8 MiB files to exceed the 32 MiB graph
  budget, also without invoking Python. A growth-during-read fixture must still
  mutate an already-open file and verify prompt rejection; no runtime
  parity/safety evidence has been gathered. A dedicated path-replacement/no-
  hang fixture is still required. The opened descriptor pins object identity,
  but an in-place writer can still change the regular file during reading; the
  byte budget is not a content snapshot. Parity runs must use immutable inputs
  or add a synchronization/snapshot contract for concurrent writers.
- Python `Path.read_text` universal-newline translation converts CRLF and bare
  CR to LF before `splitlines(keepends=True)`. The candidate makes that
  normalization explicit. Include directives are whole lines matching
  optional indentation and optional `#` before `include`, with a nonempty
  path between quote characters and no trailing text. The pinned regex does
  not backreference the opening quote, so mixed delimiters are accepted; the
  candidate preserves this permissive behavior.
- Elisascript `read_text` returns the file's raw bytes as text and does not
  perform Python's strict UTF-8 decoding or universal-newline translation.
  The candidate validates UTF-8 and normalizes CRLF/bare CR to LF before
  applying the include-line and `splitlines(keepends=True)` rules; a successful
  raw read alone is insufficient.
- Beyond LF, Python `splitlines` also recognizes vertical tab, form feed,
  U+001C..U+001E, NEL, and Unicode line/paragraph separators. A generated Python
  differential fixture now places distinct exports across each of those
  separators and compares structured output, including one-based line numbers.
  A checked-in `unicode_line_separator.input` also pins U+2028 at the public
  launcher process boundary, including the second export's one-based line number.
  A second generated case puts an include before U+2028 and an export after it,
  pinning include recognition and splice behavior at that boundary. CRLF and
  bare-CR normalization are covered separately. These fixtures remain
  unexecuted under the validation hold.
- Explicit failures include `missing source/include: RESOLVED` and
  `cyclic include while building WASM: CHAIN`. For any CLI/IPC adapter, map
  those failures deterministically and preserve the resolved paths.

## Required acceptance matrix

The generated unsupported-type diagnostic also covers U+FEFF ZERO WIDTH
NO-BREAK SPACE, selected supplementary format controls, a private-use scalar,
Unicode noncharacters, U+1680 OGHAM SPACE MARK, and U+3000 IDEOGRAPHIC SPACE.

Every case must compare the pinned Python reference and Elisascript adapter on
decoded structured output or exact failure status/diagnostic. Also compare
valid source cases with `src/driver/emit_wasm_exports.elisa`; that emitter is an
AST-based implementation, so malformed-text cases are Python-vs-Elisascript
only unless they are valid Elisa programs.

| Case group | Required cases |
| --- | --- |
| Record shape | zero parameters, default/no return, explicit target, line numbers, source order, exact optional-key presence, permissive target-regex behavior |
| ABI | every scalar mapping, `cstr`, `&`, `&&`, nullable, unsupported aggregate, modifier/whitespace normalization, greedy nested-signature suffix selection, Python-compatible diagnostic quoting for C1 controls, U+00AD SOFT HYPHEN, U+061C ARABIC LETTER MARK, U+070F/U+0890/U+08E2 format controls, U+1680/U+3000 spaces, U+200B ZERO WIDTH SPACE, U+200E LEFT-TO-RIGHT MARK, U+2060/U+2065, U+FEFF ZERO WIDTH NO-BREAK SPACE, selected supplementary format controls, private-use scalars, and Unicode noncharacters |
| Parameter scanner | nested delimiters including `{}`, quoted commas/equals, escapes, empty segments, missing colon, invalid name |
| Link annotation | quoted/bare, blank/comment retention, overwrite, empty, dangling, reset by ordinary text, implicit-main exclusion |
| `main` | implicit position and fields, repeated definitions, explicit-before/after behavior, duplicate line diagnostic |
| Invalid source | ignored malformed export forms and exact no-export failure; colon forms admitted by the pinned target regex are preserved |
| Include graph | nested/absolute/relative, duplicate and diamond include order, cycle chain, missing file, relative/absolute dangling symlink targets, nested links, target and post-link `..` resolution, no-newline splice, CRLF/bare-CR normalization, empty file |
| Bounds and failure | bounded file/aggregate bytes, materialized source line count, per-export and aggregate parameter counts, include depth/count, aggregate path-component and symlink-expansion work, explicit and implicit header-suffix scan work, aggregate duplicate-name comparison work, structured-output overflow, unreadable and invalid UTF-8 input, no partial success output |
| Integration (future acceptance; not covered by this launcher test) | resolved absolute source path; ordered JSON-array mode and versioned `{version, flattened_source, exports}` / `{version, flattened_source}` payloads; exact scan-failure and wrong-arity process tuples; consumption by the pinned `wasm_build.py` caller and runtime-cache hashing; no Python scanner on the accepted replacement path |

Current caller review (source-only; not adoption evidence): the pinned
`wasm_build.py` uses `--export-scan-launcher` plus `--export-scan-script` (or
their environment defaults) for normal invocations. Missing configuration now
fails before output-directory creation or compiler launch instead of silently
using Python. The explicit `--python-reference-scanner` flag retains the pinned
Python implementation for parity-oracle runs; the stage0 comparison scripts
select it deliberately. The candidate path invokes the scanner with the
resolved source path, bounds captured process output to 64 MiB and runtime to
120 seconds, validates the versioned payload and ordered record shapes, and
passes the returned flattened source and exports through the existing build
flow. Its
frequent RSS sampler also streams the host `ps` snapshot under incremental
8 MiB byte and 65,536-row ceilings, plus a one-second post-launch read
deadline; missing, oversized, malformed, duplicate-PID, or timed-out snapshots
fail closed. Duplicate process identities are rejected before table insertion,
so a later low-RSS row cannot overwrite the scanner's earlier RSS observation.
The scanner client and the stage1 command guard share the pinned compiler's
streaming snapshot reader, with caller-specific row ceilings, so the watchdog's
own `ps` capture is also byte- and time-bounded before decoding. The helper
invokes `/bin/ps` directly with a C locale, avoiding command shadowing through
the monitored toolchain's inherited `PATH`.
Descendant discovery uses a visited-set queue, independent of `ps` row order,
instead of repeated whole-table passes. Unit cases cover reverse-ordered
descendants, exact byte/row limits, byte and row overflow, duplicate PIDs, and
a stalled read.
The same configured caller can now request flatten-only payloads for the runtime
cache hash, including runtime sources that declare no exports; the façade's
small type normalizer has been localized so it no longer imports the scanner.
The Python `read_flat_source` and `parse_exports` functions remain available
only for explicit oracle mode and compatibility imports. Source unit cases
cover payload validation, required scanner selection, explicit oracle
selection, flatten-payload validation, runtime-cache selection, and façade
normalization, but neither the unit cases nor a candidate-backed caller
invocation has run. Requiring the candidate removes silent fallback; it is not
yet accepted replacement or runtime adoption evidence.

The first parity slice is represented by
`test/script_parity/wasm_export_scan_test.elisascript` and its pinned-process
adapter `scripts/wasm_export_scan_reference.py`. The Elisascript test includes
the candidate module and calls its shared path-response function; the Python
side runs the pinned scanner's `read_flat_source` and `parse_exports` as a
process. The Python status/stdout/stderr are encoded
as one length-delimited `DifferentialValue.Text` before typed comparison,
because in-process console output is intentionally not captured by the current
differential adapter. Cases cover positive records, parser and ABI errors, the
pinned target-regex edge, nested relative includes, diamond de-duplication,
cycles, missing leaves, absolute includes, mixed quote delimiters, and
existing/missing leaves beneath a symlink prefix including `..` after the
symlink. Generated dangling-link cases put relative links below a directory
distinct from the including source, retain child and parent-traversal components
after the link, cover nested and absolute targets, cancel a missing target
component with `..`, and compare a still-missing target's exact path diagnostic.
A candidate-only two-link cycle checks the 128-hop bound. A second candidate-only
case chains 60 relative links whose targets each contain 400 `./` components;
it asserts the shared weighted path-work rejection without invoking Python.
A generated link-name case places `@link_name("")` after a nonempty
annotation and compares the omitted optional key with Python. Generated temporary inputs
also cover CRLF/bare-CR normalization, all additional Python `splitlines`
separators (vertical tab, form feed, U+001C..U+001E, NEL, U+2028, and U+2029)
with one-based record-line comparison, no-final-newline splicing, invalid
UTF-8, an overlong source spelling rejected by the path-byte cap, and repeated
relative includes expected to exceed the aggregate path-component-work cap
with an exact-diagnostic assertion. A separate candidate-only generated case
checks the explicit-export and implicit-main header-work failures without
calling the unbounded Python parser, and another checks the shared aggregate
budget across multiple individually-under-limit headers;
`scripts/check_wasm_export_scan_bounds.sh` statically checks both header-work
guard paths, the parameter-count cap, and the rejection fixtures. Another
candidate-only generated case asserts the unique-export comparison-work limit
without invoking Python. A generated Python differential case covers explicit
`main` before implicit `main` and
implicit `main` before a later explicit duplicate, plus repeated implicit
definitions that must yield only one row. The ordering cases include many
ordinary lines between exports to exercise the maintained presence flag. A
generated unsupported-type diagnostic containing U+009F, U+00AD, U+061C,
U+070F, U+180E, U+0890, U+08E2, U+200B, U+200E, U+202A, U+2060, U+2065,
U+FEFF, U+110BD, U+E0001, a private-use scalar, and U+FDD0 is compared with
the pinned Python adapter to check C1, soft-hyphen, format, zero-width,
embedding, supplementary format, private-use, and noncharacter `repr` escaping.
The tag-block diagnostic also includes U+E0000, U+E0002, and U+E001F, covering
the reserved/unassigned gap before the assigned tag characters at U+E0020;
these must be escaped just like U+E0001 and the tag characters themselves.
A malformed parameter-name diagnostic separately checks U+1680 and U+3000 in
preserved text, because type normalization would remove those whitespace code
points before rendering. The checked-in
`unsupported_type.input` fixture carries U+FEFF, U+200E, U+061C, and U+2060 in
the type span for public-launcher coverage; `unicode_repr.input` adds process-
level coverage for representative format/private-use/noncharacter scalars.
Newline-dense inputs check that 131,072 lines reach the ordinary no-export
diagnostic while 131,073 lines hit the candidate-only line-view cap, without
entering Python. `python_repr` now uses a private, versioned Unicode 16.0.0
range table generated from the official `UnicodeData.txt`; the range predicate
matches Python 3.14's rule that L/M/N/P/S categories plus U+0020 are printable,
so unassigned and private-use scalars are covered instead of maintained as
hand-picked exceptions. The generated-source comment records the UCD input
SHA-256 and Unicode License v3 attribution. Elisa's general `Text.isprintable()`
predicate remains deliberately ASCII-only; the scanner uses this narrow,
version-pinned helper instead. These are static source contracts, not executed
evidence. The differential sample now includes the U+0378..U+0379 unassigned
gap between printable U+0377 and U+037A. The generated one-line malformed-name
fixture now concatenates every range start, midpoint, end, and immediate
neighbors that can be represented in a single strict-UTF-8 scanner line; one
scanner/Python differential pair checks all of those diagnostic escapes at
once. The source audit caps that input at 32 KiB, requires one line, and pins
exactly one candidate/Python pair so boundary coverage cannot regress into a
process-per-codepoint loop. It excludes U+0085/U+2028/U+2029 because they split
source lines, and surrogates because strict UTF-8 cannot encode them. The
runtime-built malformed-type input separately exercises C0/NUL/DEL and Latin-1
escaping; the malformed-name case covers ASCII space/punctuation plus Unicode
whitespace.
These remain unexecuted source contracts. A candidate-only self-check also
probes every declared range's start, midpoint, end, and immediate neighbors;
it checks interval and binary-lookup consistency against the generated table,
not independent Unicode classification. Runtime parity still needs explicit
authorization under the validation hold. A
candidate-only generated input also
exercises rejection of 4,097 parameters before storing the excess parameter
slice or creating `Parameter` records, without entering Python. The bounded
top-level splitter stops as soon as the next nonempty part would exceed the
per-export ceiling, rather than materializing the full parameter list first.
A candidate-only generated input also puts five
exports at 4,096, 4,096, 4,096, 4,096, and one parameter respectively to check
the aggregate ceiling of 16,384 without entering the unbounded Python parser.
Another candidate-only filesystem case creates a
129-file include chain and checks the 128-frame depth rejection while cleaning
up every generated file. A separate candidate-only case repeats one completed
child include 16,385 times to pin the independent include-directive ceiling;
it avoids invoking the Python loader on this generated bound case. Another
candidate-only case creates 4,096 unique sibling includes so the root plus
those children reaches the independent 4,096-file ceiling; it cleans every
generated file and avoids invoking the Python loader. Positive snapshots are
also checked against their checked-in JSON. The Python adapter
reads the pinned scanner through a bounded regular-file descriptor, computes
the Git blob ID from those captured bytes, compares it with the pinned commit,
and compiles that exact verified snapshot. This avoids both an unbounded
path-based `git hash-object` read and a second path-based Python import that
could execute bytes different from the checked blob.
The reference process also fails closed unless it runs Python 3.14.7 with
Unicode database 16.0.0. This pins the runtime-dependent Unicode printability
table used by Python `repr` diagnostics; selecting another `python3` from PATH
must produce the adapter's stable status-2 runtime-requirement diagnostic,
not silently alter the oracle.
Before invoking the reference's recursive loader, the adapter performs a
streaming include-graph preflight with the same per-file, graph-byte,
output-byte, path, path-component-work, directive, depth, and unique-file
ceilings; this
avoids unbounded oracle reads while retaining the pinned loader as the
accepted-input reference. It also normalizes host `OSError` read failures to
the candidate's stable path diagnostic. Preflight source reads use
`O_NONBLOCK | O_NOFOLLOW`, verify the opened descriptor and named path refer
to the same regular file, and consume at most the smaller of the per-file and
remaining graph budgets plus one byte in fixed-size chunks. This bounds a
concurrent growth attempt and prevents waiting on a raced FIFO; it does not
snapshot concurrent in-place writes, and the later pinned recursive read still
assumes parity inputs stay immutable for the run. Checked-in expected JSON is
opened as a no-follow regular file, read to a 1 MiB + 1 byte sentinel, and rejected above
128 nested containers before `json.loads`; focused oversized/deep/symlink
fixtures pin those bounds and the stable rejection in source. This test source has not been run: it
remains behind the disabled bounded compiler wrapper and does not yet cover
unreadable input under a non-root user or caller integration. A candidate-only
structured-output case now uses a 6 MiB opaque component type: the admitted
source and the duplicated parameter metadata each JSON-escape that value,
exceeding the payload ceiling while staying below the flattened-source cap.
It expects a stable failure frame rather than partial output. The fixture is
source-only and has not been executed. Aggregate include-graph bytes and
unique-file rejection are also covered only by candidate-only generated source
cases and have not been executed.

The separate `test/script_parity/wasm_export_scan_launcher_test.elisascript`
source compares the configured launcher executable process against the pinned
Python process across every checked-in top-level `.input` case, including
positive output, target-regex compatibility, duplicate-export, greedy-header,
ABI, and no-export failures, plus diamond, mixed-quote, missing, nested, and
cyclic include graphs and the checked-in U+2028 line-separator and
`unicode_repr.input` fixtures. The test first resolves each input to an absolute
path and passes that single argument to both processes, matching the real
caller's path shape. This checks
the CLI invocation contract only; it does not modify or prove caller adoption.
The test requires
`ELISASCRIPT_PUBLIC_LAUNCHER` to name an absolute path and
`ELISASCRIPT_PUBLIC_LAUNCHER_SHA256` to provide its lowercase SHA-256 from a
recorded build identity. It invokes `/usr/bin/shasum -a 256` through the
differential process runner before and after comparisons, with an empty
environment and bounded output/time. `/usr/bin/shasum` is a current macOS
harness dependency; portability needs a reviewed platform adapter. Before
hashing, the test requires a
regular file no larger than 64 MiB. It checks the full digest-tool output line
and prints the verified path and digest into the bounded run log. This binds
the tested path's bytes to the supplied digest but does not establish that the
digest came from this checkout's intended build; the qualification record must
tie it to the launcher build/revision separately. Size/hash checks and process
execution are path-based, so the launcher artifact must remain immutable for
the duration of the run; pre/post hashing is not a defense against a transient
concurrent replacement. Process output still compares captured exit status,
stdout, and stderr directly. This does not claim caller adoption or substitute
for the direct structured parity suite. The test fails closed unless
`ELISASCRIPT_VALIDATION_REAUTHORIZED` is `1` and `ELISA_LOCAL_COMPILER` names
the pinned StructPy compiler. Even then, run it only through the bounded
wrapper so the RSS monitor covers the launcher, reference, and digest-tool
children.

Neither test has run. Once validation is explicitly reauthorized, run each
test from the repository root only through `scripts/run_bounded_test.sh`, with
`ELISASCRIPT_PUBLIC_LAUNCHER` set to the absolute public launcher path and
`ELISASCRIPT_PUBLIC_LAUNCHER_SHA256` set to the digest recorded for that exact
launcher build. Pin the local compiler and use the wrapper's RSS monitoring as
specified in `docs/development.md`; do not invoke the compiler directly.

Existing pinned Python tests cover only a subset: selected `int`/`i64` and
`cstr` behavior, one unsupported aggregate, duplicate exports, quoted link
names, and three positive build-artifact parity examples. They do not establish
the matrix above. This document is an acceptance contract, not evidence that
the port is complete or that any parity has been run. Compiler/script
validation remains disabled until explicitly reauthorized.
