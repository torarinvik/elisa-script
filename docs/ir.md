# Elisascript shared typed IR

Elisascript uses one backend-neutral, verified IR between its typed frontend and
all execution engines. Bytecode, an interpreter, LLVM JIT/AOT, and Wasm are
lowerings of this IR; none receives the source AST directly.

## Initial representation

The first implementation in `src/ir` is a flat SSA control-flow graph. Functions
own flat instruction and operand pools, while blocks and instructions reference
contiguous slices; this avoids nested region ownership and is ready for canonical
serialization:

- Functions have explicit parameter and return types, effect rows, blocks, and an entry block.
- Blocks have typed parameters, ordered instructions, and exactly one terminator.
- Every nonzero value id has one definition within its function.
- Control-flow targets are block ids rather than backend labels.
- Source spans survive lowering for diagnostics and reproducible failures.
- Nominal types retain their Elisa name instead of collapsing to a machine representation.

Immutable, initialized module-level `const` declarations are lowered into typed
SSA constants at each function entry. They are ordinary lexical bindings, so a
parameter or local with the same name shadows the module constant. Scalar
`global` declarations live in `Module.globals`; `LoadGlobal` and `StoreGlobal`
provide shared storage across calls, with zero values for uninitialized bindings.
Scalar literals and one-level literal arrays/maps are encoded as flat global
payloads and materialized in the runtime arena. Nested aggregates and non-literal
initializers remain outside this lowering subset. Runtime global admission also
fails closed on malformed odd-length map payloads, even though verified modules
already reject them before execution.

Tuple syntax `(a, b, ...)` is lowered through the same `MakeArray` operation after
each element is checked against one homogeneous `T`. In an explicit `darray[T]`
context this is also how `()` provides a typed empty array initializer. The IR does
not yet claim a first-class heterogeneous tuple representation, so heterogeneous
and unconstrained empty tuple values remain lowering diagnostics.

Destructuring assignment over literal tuple/array values evaluates all source
elements first and then performs typed SSA rebinds. Fresh `=` targets infer their
individual types, while `<-` and compound forms require mutable existing bindings;
dynamic homogeneous-array unpacking uses checked `UnpackArray` operations and
requires the runtime array length to equal the target count.

Aggregate `Type` fields remain bounded for compatibility with the first lowering,
but every lowered module also carries a pointer-free `TypeTable`. Its one-based
`TypeDescriptor` rows refer to child rows through a flat `u32` pool; interning
deduplicates `(kind, name, width, signedness, children)` structurally. This is the
recursive descriptor seam for future tuples, records, and arbitrarily nested
containers, without putting recursive values or allocator addresses in the IR.
Legacy inline fields stay populated while verifier and backend consumers migrate.
Type interning rejects child pools wider than the descriptor's `u16` count or
the serialized `u32` offset domain and returns the verifier's invalid id
sentinel before narrowing; this prevents oversized host collections from
aliasing a valid structural type. Descriptor rows also use a closed `TypeKind`
vocabulary: unknown serialized enum ordinals are rejected before child
traversal rather than being interpreted as a backend-specific type. The same
closed-vocabulary check applies to legacy inline type fields even when a module
has no interned table. Inline-shape matching also has a 128-level recursion
guard, so cyclic or hostile descriptor graphs fail as `InvalidTypeTable` before
host-stack exhaustion. Current rows additionally require array/map child arities
and canonical child-before-parent ordering; forward or self references are
rejected until a future recursive descriptor kind defines an explicit cycle
representation and verifier policy. The public interner applies the same kind,
arity, nonzero-id, and child-before-parent checks at construction time, so
callers cannot intentionally create a malformed row and defer its rejection to
the verifier.

The vocabulary intentionally contains no LLVM values, native registers, pointer
sizes, bytecode slots, or host ABI facts. Those belong to target-specific lowering.
The copied compiler's EASM remains a later machine-level representation and is
not used as the shared IR.

Contextual integer literals use an empty `Named` descriptor as the explicit
unknown/context sentinel. The lowerer must only compare against members of the
closed `TypeKind` enum; `scripts/check_lower_ast_integrity.sh` is a compiler-free
guard for this invariant and for both signed and unsigned suffixed literals in
contextual return positions.

## Host-runtime namespace

`EsRuntime` is the sole qualified namespace for the POSIX host boundary. Its
public section exposes the Darwin layout records/constants needed by the typed
filesystem operations and forwarding functions consumed by `EsIr` and
`EsDifferential`. Each `src/runtime/*_posix.elisa` extension keeps its
`@link_name` C declarations private and gives them an `_impl` suffix; callers
cannot bind the platform ABI symbol directly or accidentally bypass the typed
effect/error boundary. The public forwarding names retain the existing
`elisascript_posix_*` source contract while preserving the native libc symbol.
`EsRuntime::Contract::VERSION` is metadata for cache/tooling checks,
not a promise of cross-platform ABI compatibility. A non-POSIX adapter must
extend the same namespace with equivalent typed operations rather than leaking
new global declarations.

The native launcher follows the same rule. `src/driver/elisascript.elisa`
defines an `EsDriver` module whose argument collection, CLI parsing, stderr
formatting, and phase-reporting helpers are private. Its only public surface is
`EsDriver::run`; the required process entrypoint `main(argc, argv)` is a global
ABI shim that forwards directly to that function. This keeps host-facing ABI
code small while preventing driver implementation helpers from entering the
program-wide namespace.

`EsCli::CliInvocation` is the launcher argument contract: run/check/test/fmt/doc
and help/version modes are explicit, `--color` and `--strict-engine` are typed
options, source-requiring modes accept only the `.elisascript` suffix, and the
first source path ends launcher-option parsing. A literal `--`
marks the script-argument boundary and is omitted from the script's argv;
subsequent values are preserved byte-for-byte and are never shell-expanded.
`validate_cli_invocation` enforces source,
argument, NUL, and text ceilings, rejects source/script arguments for
source-free help/version modes, rejects trailing arguments for `--test` until
the test-selection channel is defined, and rejects repeated colors through
`error[CliContractError]`, while
`parse_cli_arguments` rejects unknown options, duplicate modes/options, and
missing option values before source loading.

The native `EsDriver` collector preserves that distinction while it turns
borrowed host `argv` slots into `sview` values. A script argument whose bounded
scan is clamped by the remaining aggregate byte budget is reported as an
aggregate argument overflow; only an unclamped scan that reaches the ordinary
C-string ceiling is reported as a host C-string overflow. This prevents a
known aggregate-budget violation from being mislabeled when the complete host
string has not been scanned.

For `--run`, `--strict-engine` selects the direct bytecode engine and fails with
`UnsupportedInstruction` if the verified program requires interpreter
fallback; it never silently changes engines. Without the option, ordinary runs
retain the compatibility behavior and may use the verified interpreter
fallback. With `--check`, strict-engine is intentionally inert: check validates
source and bytecode but does not select or execute a backend.

`EsDriver::run` now consumes that typed invocation directly. Help/version exit
before source allocation. `--check` loads and type-checks the source, lowers
and verifies its IR/bytecode, and returns success without requiring `main`,
staging script arguments, or executing code. Test/fmt/doc still return an
explicit unsupported-mode diagnostic rather than silently taking the run
path; source arguments and the `--` boundary are passed to the typed runner
only for an actual run. `--test` rejects trailing script arguments because the
current in-process test adapter has no argument or selection semantics; this
prevents a future driver route from silently discarding them.

EsCliWorkflow separates planning from host execution. Each accepted mode maps
to a fixed step sequence: run loads, lowers, verifies, executes the entrypoint,
and renders; test uses a distinct `ExecuteTests` step for discovered test
functions; check omits execution; fmt and doc select their dedicated transformation;
help/version render directly. The workflow reconciles its cursor with
Planned/Running/Complete states, consumes steps in order, and exposes
explicit failure and cancellation transitions. A cancelling workflow must also
retain an unfinished cursor. Failed and cancelled workflows
must retain an unfinished cursor, so unsupported host adapters
cannot masquerade as a successful run.

`EsModule` supplies the source/package-facing identity boundary. A
`ModuleDescriptor` carries explicit public and private symbol sets, ordered
imports with aliases and visibility, and a bounded source path; duplicate
imports, missing graph targets, public/private collisions, malformed identities,
and oversized import or symbol sets fail through `error[ModuleContractError]`.
Resolution advances
`Planned → Resolving → Resolved/Failed` one event at a time, while
`ModuleResolutionStack` rejects recursive identities before a loader can loop.
Graph validation also performs bounded topological elimination and rejects a
mutually importing module subgraph before resolution begins.
Descriptor validation rejects `Planned` modules carrying progress and `Resolved`
modules that have not accounted for every import.
The graph contract is independent of host path lookup and leaves package roots,
lockfiles, and filesystem canonicalization to the launcher/adapter.

`EsPackage` supplies that package-facing contract without letting a registry or
filesystem adapter invent semantics. `PackageManifest` declares a bounded
versioned root, typed runtime/development/build/native dependencies, native
dependency names, and an offline-only policy. `PackageLock` records the same
offline policy alongside exact
ordered entries with source kind, locator, four-word integrity identity, and
bounded transitive dependency names; duplicate dependency edges are rejected
before resolution. `validate_package_resolution` checks root
identity, offline-policy agreement, every manifest constraint (including empty equal-bound intervals), and every lock dependency before source
loading; `advance_package_resolution` exposes the explicit
`Declared → Locked → Verified` state machine with fail/reset edges. Registry
selection, signature verification, cache storage, and publishing still belong
to separately qualified host adapters.

EsPackageRegistry makes that adapter boundary explicit. PackageCandidate rows
must carry bounded names, versions, locators, source kinds, and four-word
integrity identities; a registry accepts them only in deterministic
name/version/source/locator order and exposes lookup only after sealing.
Version ordering follows semver's stable-release precedence over a matching
numeric prerelease, so deterministic tables accept `1.0.0-alpha` before
`1.0.0` and reject the reverse order. Constraint-aware lookup therefore cannot consume an unverified or
out-of-order index, while loading-only failure and cancellation edges remain
explicit; an
`Empty` registry cannot carry preloaded candidates.

EsPackageCache complements the registry with a bounded identity cache. Entries
are ordered and integrity-bound, aggregate bytes are checked before admission,
lookup requires an exact fingerprint, and invalidation moves the cache back
through an updating state before it can be sealed again. A refresh replaces an
invalidated tombstone in place, preserving order while re-accounting the
replacement's exact byte count; live duplicate identities remain rejected and
only valid entries may be stored. Failure is admitted only while updating, and
a cache miss is typed; an `Empty` cache cannot carry preloaded entries or bytes.
Host reads, writes, and atomic replacement remain outside the IR.

`EsData` is the format-neutral boundary for the P8 structured-data libraries.
`DataDecodeLimits` caps input bytes, tokens, nesting, records, fields, and field
bytes; `JsonPolicy` makes duplicate-key, trailing-comma, comment, and numeric
behavior explicit; and `CsvPolicy` makes separators, quoting, escaping, headers,
and trimming explicit. `DataDecoder` advances through `Ready → Decoding →
Complete|Failed|Cancelled` with bounded token/record accounting and requires
its byte offset to equal accounted input bytes, so JSON,
JSONL, CSV, and TSV adapters share the same cancellation and limit semantics
instead of inheriting host parser defaults. Field payload bytes have their own
bounded ledger and cannot exceed the input delta. Validation rejects forged ready
counters and complete decoders with residual depth. Schema conversion and streaming
parser implementations remain separate work.
Token and record events both account their supplied byte, field, and field-byte
deltas cumulatively; record boundaries cannot reset field totals or bypass the
input/offset ledger.

`EsJson` is the namespaced owned-document boundary for JSON parsing. A
version-5 `JsonDocument` owns bounded tables of non-recursive `JsonNode`
values, source ranges, array-child edges, object members, decoded key bytes,
decoded text/number-lexeme bytes, a verified per-object sorted key index, and
roots, while `JsonPolicy` and
`DataDecodeLimits` remain explicit inputs. `advance_json_document` revalidates
the complete document ledger before every transition, requires `Empty → Building
→ Sealed` (or `Failed`) transitions, and rejects out-of-range
children, duplicate object keys, oversized source/token/node/child/member tables, and
malformed ranges before a renderer or schema decoder can consume the table.
Validation also reconciles empty/sealed lifecycle shape, maximum node depth,
scalar payload spans, and source ranges; composite nodes cannot carry scalar
payloads. String, key, and container source spans must meet their minimum
two-byte lexical width before any width arithmetic is performed. `JsonNodeInput`
borrows scalar input only for the append call, and
the document copies it into a bounded byte arena. Text retains decoded UTF-8
bytes (including empty strings and U+0000), while numbers retain their exact
JSON number lexemes; the adapter does not coerce numbers through binary float
or otherwise select a `DataNumberPolicy`. Boolean truth is stored explicitly
on `JsonNode`; null and composite nodes have no scalar payload. Per-value
field-byte and aggregate input-byte ceilings are checked before mutation, and
the document validator checks contiguous arena ownership, UTF-8 text, and the
JSON number grammar. Retained decoded keys and scalar payloads share a
subtraction-checked aggregate ceiling no larger than the source-byte ledger.
`copy_json_scalar` returns an owned copy from a sealed
document rather than exposing a borrowed view with an unclear lifetime.
`json_object_member_index` and its bounded batch companion perform checked
lookups through the document's sorted per-object key index; the batch form
validates the document once for all requested keys.
`EsJsonLex::lex_json` provides the bounded lexical pass before grammar parsing:
it preserves exact half-open byte spans for punctuation, literals, strings,
and numbers, while decoded string/key bytes live in an owned UTF-8 arena.
String escapes and surrogate pairs are decoded and validated, number spellings
remain source-backed rather than passing through `f64`, and optional comments
are admitted only by explicit policy. The lexer checks input/token/string/depth
ceilings and balanced delimiter kinds. Validation rescans the owned source and
checks the complete token and decoded-string ledgers, so forged metadata cannot
drop non-trivia source bytes or substitute a decoded value. It deliberately
does not claim that a token stream is a syntactically valid JSON document.
`EsJsonParse::parse_json_document` supplies that grammar/materialization
boundary: an explicit array/object phase stack enforces JSON grammar without
host recursion, then appends values postorder so every child index precedes its
container owner. Decoded keys and exact source-backed number lexemes are copied
into the owned document by a parser-owned bounded batch. Each object's pending
member count and merge workspace are capped by `DataDecodeLimits.fields`, and
its keys are stably merge-sorted once; the document retains a verified sorted
per-object key-index permutation while preserving source member order. Sealing
performs one full-ledger validation, which checks duplicate keys in an ordered
linear pass rather than a pairwise scan. The separate `advance_json_document`
event API still revalidates the complete ledger per transition and is intended
for small incremental construction; the parser avoids that repeated scan.
`EsJsonLinesParse::next_json_lines_document` composes that framer with the
lexer and parser one record at a time. It returns a sealed document with its
1-based record number and absolute source offset, without retaining a
collection of all parsed documents. Cumulative input, lexical-token, retained
member, and decoded key/scalar-byte budgets span the entire reader rather than
resetting per record. When `allow_empty_records` is enabled, zero-byte and
JSON-whitespace-only frames (including blank CRLF frames) are counted and
skipped; they do not become fabricated JSON values. A parse or budget failure
makes the reader terminal and retains the failed record number/start for correlating its
record-relative diagnostic offset. The whole-view reader borrows a complete
`sview`; schema materialization remains a separate phase.
`JsonStreamPolicy.record_boundary` makes the framing choice explicit. Its
compatibility default, `JsonLineBoundaryMode.BalancedContainers`, ends records
only at newlines outside strings and balanced containers, so newlines inside
containers remain JSON whitespace in one record. The opt-in
`JsonLineBoundaryMode.PhysicalLines` treats every LF as a physical record
boundary: an LF while a container is open fails with `UnterminatedValue`, and
an LF inside a string fails with `UnterminatedString`. Such a rejected LF is
not charged to input or record counters. In both modes, LF contributes to the
total input budget but not the record-byte budget, and a top-level CR is held
until lookahead distinguishes CRLF from ordinary JSON whitespace. Consequently,
CRLF works as JSON trailing whitespace without charging its CR half to the
record-byte budget, while a lone CR is retained as record data and a final
record without LF is accepted at EOF. The same policy is preserved by the
whole-view, chunk, and POSIX file readers. Algorithmic
scaling is improved, but runtime/performance qualification remains open.
For caller-driven chunk input, `begin_json_lines_chunk_reader` and
`feed_json_lines_chunk` retain only the current bounded record buffer. A feed
returns `NeedInput`, `Document`, or `Complete` plus the exact byte count it
consumed; when it returns a document before the supplied chunk ends, the caller
resubmits the unconsumed suffix and preserves the final-input flag if the
original chunk was final. For a final suffix, the reader checks that the
resubmitted length matches the previously reported remainder; the caller must
also preserve the suffix bytes exactly. The chunk view is borrowed only for
that call, while record bytes are copied into the bounded scratch buffer. This
keeps host file ownership and I/O effects outside the parser; the POSIX
`FileStream` adapter is described below, and runtime qualification remains open.
`EsJsonLinesFilePosix::begin_json_lines_file_reader` opens a caller-path-backed
binary `FileStream` and feeds the parser in bounded 16 KiB reads. It returns
one document per `next_json_lines_file_document` call and keeps any already-read
suffix in the same buffer, so records split across reads and multiple records
inside one read are both preserved. The adapter caps parser input to the
smaller of the requested limits and `FILE_STREAM_DEFAULT_MAX_BYTES - 1`, then
uses the extra FileStream byte-budget slot as a one-byte overflow probe; this
allows exact-limit EOF to be distinguished from an oversized file. JSON
lexing, not FileStream text decoding, validates JSON bytes. The path storage
must remain alive until `close_json_lines_file_reader`, which is explicit and
idempotent after successful close; failures leave the adapter terminal until
the caller closes it. The adapter does not use physical-line reads, preserving
the parser's selected line-boundary behavior. The source fixture covers
multiple documents in one host read, a final non-newline-terminated document,
exact-limit EOF, one-byte overflow, and close after both completion and
failure; those file-I/O cases remain unexecuted under the validation stop.
Detached duplicate candidates keep their node and scalar span in the arena;
normalization changes ownership/references, not the contiguous payload ledger.
`EsJsonEncode::encode_json_root` emits one selected root as compact JSON under
an explicit output-byte ceiling. Its iterative container stack preserves
member order and exact number lexemes, escapes quotes, backslashes, and control
bytes, and never recurses on the host stack.
Arrays index an explicit `JsonArrayChild`
table; each edge names its array owner, value node, and ordinal. Objects index
their own contiguous member ranges, and each `JsonMember` names its object owner,
value node, decoded-key byte span, and ordinal. `JsonMemberInput` borrows the
decoded key only for the append call; the document copies retained decoded keys
into its bounded byte table, so sealed members do not depend on the parser's
temporary input buffer. Key spans cover that table contiguously and exactly;
decoded key bytes must be valid UTF-8, with U+0000 still permitted. Retained
key-byte accounting participates in that combined source-size ceiling rather
than receiving an independent allowance.
Each decoded key is bounded by `DataDecodeLimits.field_bytes` and the model's
per-key ceiling; retained keys also share a subtraction-checked aggregate arena
ceiling. A newly retained member supplies its normalized insertion ordinal;
duplicate candidates ignore theirs and preserve the first member's ordinal.
Every node is either detached or has exactly one verified array/member/root
owner; roots cannot be reused and an attached container cannot be changed.
Multiple roots are ordered and their source ranges cannot overlap, supporting
record-oriented adapters without allowing aliased input spans.
Detached subtrees remain legal so KeepFirst/Reject can discard a duplicate and
KeepLast can detach the superseded value without corrupting its descendants.
Array child source spans must be ordered and non-overlapping, and each object
key's raw span must precede its value span; retained key spans remain ordered
and non-overlapping even when KeepLast points an earlier member at a later value.
The ranges are checked against their respective tables (never against the node
table), with complete table coverage and owner/order checks. The sorted-key
index is a checked permutation of all member rows; it is grouped by owner and
strictly ordered by document-owned decoded key bytes, so duplicate comparison
is scoped to one object without quadratic pair scans;
decoded keys may contain U+0000, which is legal in JSON strings and must not be
rejected using path/C-string rules.
Reject, KeepFirst, and KeepLast therefore cannot merge equal names from distinct
nested or sibling objects. The retained object table is canonical under all
three policies: append applies KeepFirst/KeepLast, while validation rejects a
forged duplicate or malformed key-index permutation in the final table.
`EsJsonParse` supplies decoded keys and appends node/edge/member rows in the
required postorder. It remains separate from the vendor's global parser names;
typed target-width conversion and runtime/performance qualification remain open,
while compact encoding is provided by `EsJsonEncode`.

`EsSchema` adds the checked schema-conversion boundary that follows parsing.
`SchemaDescriptor` declares named fields, source format, requiredness,
expected value kinds, aliases, and positional source indexes. JSON ignores
`source_index`; CSV/TSV use it without a header, with the auto sentinel mapping
fields by declaration order. `SchemaDecodeSession` validates its complete ledger before
each transition and binds each field at most once and
advances `Ready → Binding → Complete|Failed`. Missing required fields,
duplicate source names, out-of-range node references, and kind mismatches are
reported through `error[SchemaContractError]` before application code receives
a value; forged ready/completed binding state is rejected as well. Validation
also rejects collisions between an explicit source alias and another field's
default source name. `EsSchemaJson` materializes one object root into an owned
record in schema-field order: text values are decoded UTF-8, JSON numbers retain
their exact lexemes by default (including `-0` and exponent spelling),
booleans and nulls remain distinct, and missing optional fields use an explicit
`Missing` tag. A field may opt into an exact `I8`/`I16`/`I32`/`I64` or
`U8`/`U16`/`U32`/`U64` `integer_target`; the adapter then accepts only an
integer JSON number (bounded to 4,096 bytes), checks the target range, and
stores a tagged signed or unsigned integer without floating-point conversion.
JSON's grammar rejects leading plus signs and leading-zero forms, while decimal
and exponent forms are not integers for this target. Unknown keys follow
`allow_unknown`; required-field and JSON-kind mismatches fail before a record
is returned. Array and object fields own a bounded flat value graph with
source-order child/member tables and independent decoded-key/scalar arenas.
Nested strings remain decoded UTF-8, nested numbers retain their exact JSON
lexemes, and traversal is iterative with explicit depth, node, edge, member,
and aggregate-payload limits. JSON descriptors may add an indexed
`SchemaTypeNode` graph and contiguous `SchemaNestedField` ranges to describe
recursive arrays and objects, per-object aliases, requiredness, exact numeric
targets, and nested `allow_unknown` policy. Type references may be cyclic;
materialization walks only the finite input tree with a bounded work queue.
Object-field ranges must be in canonical effective-source-name order, so
decoded member keys can be resolved by binary search; type/name tables are
bounded, and unreachable type nodes are rejected. Nested values receive
schema type/field annotations, and exact integer/decimal conversions apply at
any depth. `validate_schema_json_record_against` rechecks those annotations,
nested key-to-field mappings, requiredness, kind/target agreement, and per-
object unknown-field policy. Root-level unknown keys are checked during
materialization, while the source document is available.
The descriptor-free `validate_schema_json_record` intentionally accepts only
unannotated generic records; it rejects schema annotations it cannot
authenticate and duplicate object keys. `Any` remains unsupported. Generated
native record constructors remain open.

JSON `Number` and CSV/TSV `Text` fields may instead opt into
`decimal_target: SchemaDecimalTarget.Exact` (mutually exclusive with
`integer_target`). The owned `SchemaDecimalValue` represents
`(-1)^negative × coefficient_digits × 10^-scale`; it retains coefficient
trailing zeroes and the sign of zero, so `1.0`, `1.00`, and `-0.00` remain
distinguishable without binary floating-point conversion. Decimal lexemes use
the bounded numeric scanner (4,096 input bytes/digits and at most four exponent
digits, with separators disabled); JSON continues to enforce JSON's own number
grammar, while CSV/TSV admit the scanner's optional leading sign. The output
payload budget counts retained coefficient digits. `compare_schema_decimal`
compares mathematical values without conversion or allocation: it orders sign
and decimal magnitude while treating scale-only variants such as `1.0`/`1.00`
and positive/negative zero as equal. It does not rewrite either preserved
representation. `round_schema_decimal` quantizes to a caller-selected bounded
scale using an explicit `TowardZero`, `AwayFromZero`, `Floor`, `Ceiling`,
`HalfAwayFromZero`, or `HalfToEven` policy. Midpoint handling is exact, and a
rounded coefficient that exceeds the digit ceiling fails with a typed error.
`format_schema_decimal` emits fixed ASCII decimal notation under a caller's
output-byte limit; it preserves coefficient leading zeroes, stored fractional
zeroes, and the sign of zero, and never switches to exponent notation. Thus a
CSV-origin value such as `001.00` formats as `001.00`; it is a representation-
preserving decimal formatter, not a JSON-number canonicalizer. Its internal
fixed-output ceiling is 14,098 bytes. The shared `parse_float` evaluator bounds
decimal text at 64 MiB, rescales its mantissa before applying fractional and
explicit exponents, and bounds the effective scale walk at 4,096 steps. This
prevents intermediate overflow/underflow for compensated mantissas, but does
not establish correctly-rounded decimal-to-binary conversion. Binary-float
schema conversion, rounding, formatting, and comparison policies remain open
contracts.

`EsCsv` turns the `CsvPolicy` into a quote-aware streaming state machine.
`CsvStream` counts input bytes, fields, field bytes, and records against the
shared limits while distinguishing unquoted, quoted, escaped, and post-quote
states. Separators inside quotes are data; doubled quotes and configured escape
bytes are explicit transitions; malformed post-quote bytes, unterminated
quotes, and cancellation become typed `CsvContractError` values. Validation
also reconciles ready/complete state counters before admission, and rejected
byte events leave input and field counters unchanged. `CsvPolicy` keeps the
legacy configurable single-byte terminator by default and also names explicit
LF, CRLF, or CR modes; the legacy `record_separator` byte is read and validated
only in `ConfiguredByte` mode. CRLF is recognized across byte events with a
pending-CR state; an invalid or incomplete suffix is rejected without
consuming the offending byte. CR and LF remain payload inside quoted fields,
while an unmatched CR or LF outside quotes is invalid in CRLF mode. Empty input
completes with zero records, while a physical blank record contains zero
fields, matching Python's `csv.reader`; a quoted empty cell such as `""`
remains one field. The span materializer preserves zero-field records without
inventing field spans. External-spill aggregation remains adapter work.

`EsCsvMaterialize` gives CSV/TSV adapters a policy-bound borrowed-span
boundary. Each field span is range-checked against the source and checked as a
well-formed quoted or unquoted cell; each record must consume the next
contiguous field range with the configured field separator and exact configured
record terminator at every boundary. Unquoted cells may not contain bytes that
form the selected record terminator; quoted cells may contain newline payload.
Field and record ceilings are shared with `EsData`, including exact-limit
inputs and cells, and a ready session must have clean source, field, record,
and cursor accounting. An empty source can complete without spans or records;
a terminator-only source still requires one zero-width field span and one
record. Lookup returns only validated slices while the session
is building or complete. Record starts are range-checked before subtraction.
The incremental event API revalidates its ledger and is intended for small
construction; a future large adapter should capture bounded parser batches.

`EsSchemaCsv` materializes completed CSV/TSV records as owned UTF-8 text in
schema order. It binds decoded header names through `source_name` aliases, or
uses `source_index` (declaration order by default) without a header; duplicate
headers/indexes, unknown columns, invalid quoting/UTF-8, and missing required
fields fail explicitly. `allow_unknown` controls unmatched header and data
columns. Optional missing columns carry a `Missing` tag, distinct from an
empty `Text` cell: a blank zero-field row maps an optional column to `Missing`,
while a quoted empty cell maps it to empty `Text`. Doubled quotes and
configured in-quote escapes are decoded;
optional unquoted trimming is ASCII space/tab only and never affects quoted
cells. CSV/TSV fields remain declared as `Text`; an explicit integer target
instead parses the decoded cell as a base-10 integer without whitespace,
underscores, decimal point, exponent, or floating conversion, with a 4,096-byte
token ceiling. Existing
`trim_unquoted` policy may remove outer ASCII space/tab first; quoted cells are
never trimmed. Signed targets accept `+` or `-`; unsigned targets accept digits
only. Values are range-checked before being stored in the tagged integer
payload. `materialize_csv_schema_batch` validates its inputs and prepares the
header/positional projection once per call for an exact data-row range, then
returns the owned batch atomically. Each batch is capped at 4,096 rows,
`DATA_MAX_FIELDS` output values (including `Missing`), and
`DATA_MAX_INPUT_BYTES` aggregate retained text payload. Empty ranges are
allowed at a valid row boundary; out-of-range requests fail rather than
truncate. A zero-byte source with `header: true` has no header and zero data
rows: zero-row batches succeed, while record lookup reports `RowIndexInvalid`.

`EsSchemaToml` binds a resolved typed TOML configuration to the common
`SchemaDescriptor`. It enforces required fields, aliases, unknown-key policy,
duplicate resolved keys, scalar kinds, array/inline-table container kinds, and
exact integer/decimal targets. TOML numbers retain exact source spelling until
conversion; environment and CLI strings are parsed only when a field declares
a boolean or numeric target. The resulting record refers to the resolved
configuration for text, arrays, and inline-table contents, so both the schema
and resolution must outlive it. `materialize_toml_schema_table` selects one
canonical dotted table path (or the document root) and binds only its immediate
keys; sibling tables and dotted descendants are left for separate schemas.
Schema type graphs validate recursive array items and inline-table fields,
including nested aliases, required/unknown-field rules, and exact numeric
targets. The adapter caps resolved values, schema fields, types, and nested fields at 4,096
before descriptor validation to keep work predictable. The
recursive TOML value graph is traversed against array-item and object-field
types. The record borrows those graph values by resolution index instead of
constructing a second owned nested typed graph. Dates/times and typed
cross-source merging remain unsupported. Source fixtures and static
guards describe the behavior but are not runtime evidence while compiler
validation is held.

`EsInstall` makes release publication a typed state machine. An
`InstallPlan` names the package version, workspace/user/system scope, source,
bytecode, or native artifact targets, destination paths, typed `Data` or
`Executable` mode, and a four-word SHA-256 integrity identity. `validate_install_plan` rejects empty plans,
duplicate or parent/child-conflicting destinations, non-canonical relative
paths, invalid package-version text, non-`.elisascript` source artifacts,
oversized per-artifact or aggregate payloads, and an explicitly absent integrity
identity. Identity presence is separate from its contents, so zero-valued digest
words and empty artifacts remain representable;
`EsInstallSourcePosix.verify_install_source_at` performs a descriptor-relative,
no-follow, size-bounded read and compares SHA-256 plus byte count to the manifest.
Its receipt carries the observed device/inode/mtime/ctime stamp for later
revalidation before copying; it rejects size mismatch before allocating the
content buffer. `verify_install_sources_at` builds a complete receipt vector in
plan order, and `validate_install_source_receipts` rejects omissions, reuse, or
reordering before a caller proceeds; successful batch verification advances
the plan to `SourcesVerified`, without which `Stage` is rejected.
`stage_install_plan` requires one `InstallStageReceipt` per planned artifact in
canonical order, with the exact destination, size, SHA-256 words, and declared
data/executable mode, before the plan can enter `Staged`. The POSIX
`verify_install_stage_at` adapter requires a stage-root directory with mode
`0700`, derives receipts by no-follow readback, checks byte count and SHA-256,
then verifies exact file modes (`0644` for data, `0755` for executables) on the
reopened descriptor, then scans the complete tree against the manifest. It
returns an `InstallStageProof` binding the ordered receipts to the private
effective-user-owned stage-root device/inode and each file's stable stamp.
After this readback succeeds it advances the plan through `Staged` to
`Verified`. `stage_install_sources_at` is the complete population entry point:
it consumes the ordered source receipts, requires a fresh empty root, copies
each artifact, verifies readback, and removes the private stage on copy or
verification failure. Either failure also moves the plan to terminal `Failed`
state, even when stage cleanup succeeds; a retry starts with a new plan and new
source receipts. Stage creation, population, readback, preflight revalidation,
and cleanup require an active exclusive `FileLockPosixLease` on the parent
directory. The stage handle binds that lease by parent/lock identity, owner,
and exact lock name, and each operation rejects a missing or substituted lease.
The caller must retain it through publication or rollback; advisory locking
coordinates cooperating writers, not a malicious same-user process.
`create_install_stage_root_at` creates a caller-named exclusive sibling with
mode `0700`, opens it without following links, binds its name to the opened
directory and the active mutation lease, syncs the directory and parent entry,
and returns an owned descriptor plus borrowed parent capability.
It accepts only effective-user-owned or root-owned parents, and rejects
group/world-writable non-sticky parents. Name collisions fail closed; the
caller retains its candidate leaf for reconciling a post-create error.
`revalidate_install_stage_at` rechecks those identities and modes before
publication without rehashing large files, then repeats the bounded,
descriptor-relative whole-tree walk performed during initial stage admission.
The walk admits only the manifest files and their required parent directories,
rejects symlinks and other entries, requires directory mode `0755`, and checks
file identity, owner, device, link count, and mode. It enforces explicit path,
depth, and entry limits, then advances the plan from `Verified` to
`PublishReady`. `Publish` is rejected until that preflight state is
acknowledged. The orchestration layer must use the POSIX revalidation result as
the source of that acknowledgement; the value-only model cannot itself attest
a filesystem observation. This is a point-in-time check, not protection
against a same-user concurrent mutation during or after preflight.
`open_install_source_for_copy` reopens each receipt beneath the same root
capability and retains the matching descriptor. `read_install_source_chunk`
streams at most 64 KiB per call; `finish_install_source_copy` checks descriptor
and path identity again and consumes the descriptor, while
`cancel_install_source_copy` closes an abandoned stream.
`copy_install_source_to_stage` opens destination parents one component at a
time without following links, creates missing directories as `0755`, and
exclusively creates a private `0600` regular file. It streams only the receipt's
bounded byte count, revalidates the source, applies the manifest mode, syncs the
file and directory entries, and rechecks descriptor/name identity. Its byte
count is not a staging proof: the caller must still run
`verify_install_stage_at` to hash the staged bytes and verify exact tree
closure. A failed copy can leave partial content in the private stage, so the
orchestrator must not publish that stage. The higher-level
`stage_install_sources_at` invokes this copy operation for every receipt and
then performs whole-tree verification before yielding a proof.
`remove_install_stage_root` provides
bounded iterative cleanup through no-follow directory capabilities, checks
entry identity before removal, syncs directory changes, and removes the named
private root only after its contents are gone. A cleanup failure may leave a
partially emptied stage for retry; an interrupted unlink is reported as
outcome-unknown and requires reconciling the retained root name before retry.
Successful removal consumes the owned stage descriptor.
The identity checks are point-in-time: portable `unlinkat` has no
inode-conditional removal operation, so a same-user process that can mutate
the relevant parent concurrently can still race a name replacement. The
installer must serialize cleanup/publication with its directory lease when it
needs that stronger guarantee.
`advance_install_plan` separates `Publishing` from acknowledged `Published`,
tracks `PublishUncertain`, and requires rollback to be acknowledged or explicitly
remain `RollbackUncertain`. The tree scan is only a verifier: nested stage-tree
destination directory permission mapping, multi-artifact atomic replacement,
recovery journal, and the end-to-end
installation adapter remain unimplemented.

`EsSourceMap` gives diagnostics and navigation a bounded identity layer across
modules. Files are explicit unique paths, entries carry generated and original
file/line/column locations plus an optional symbol, and generated locations must
be strictly ordered. `advance_source_map` adds files and seals the append-only
map through an explicit `Empty → Building → Sealed` protocol (with
invalidation), while
`source_map_lookup` returns a bounded entry index or the table-count sentinel;
empty maps start without preloaded files or entries, and no consumer scans an
unvalidated or path-inferred map. Invalidated maps are rejected at lookup rather
than being treated as ordinary empty results.

`EsOutput` gives launcher, test, and differential renderers one bounded
document contract. `OutputOptions` fixes human/JSON/JUnit format, color policy,
quiet/fail-fast behavior, and a total text budget; `OutputRecord` carries a
typed pass/flaky/fail/error/skip/crashed/timed-out/cancelled status with
bounded name and channel text.
`advance_output_document` appends records through `Empty → Building → Sealed`
while reconciling aggregate channel text and failed records against stored
accounting and rejecting budget overflow before mutation. Events reject
irrelevant payloads: only `Append` accepts a non-empty record payload.
Renderers can therefore remain format-specific without changing result
semantics or truncating machine output silently.

EsOutputRender adds the renderer-side state machine. Validation requires a
sealed document before any renderer state is admitted; it consumes records in
index order, charges each format's exact serialized byte cost before each
chunk, accumulates every per-record component with
checked addition, and accounts format framing bytes against the same
document budget. It reconciles the emitted-byte total with the exact rendered
prefix (including header and, only on completion, footer), validates
state/chunk/record accounting, and refuses completion until every record has
been emitted. A Ready renderer also computes the full document size before
offering any frame, so reports that cannot fit their byte budget fail before a
host can write a partial header. Cancellation and failure are explicit
transitions, leaving actual host writes to a bounded adapter. `EsOutputHuman`
provides deterministic status/name/duration lines, separate pass, flaky,
failure, crash, timeout, error, skip, and cancellation counts, and optional
message/stdout/stderr blocks. It escapes
line/control bytes and invalid UTF-8 in record fields
so captured text cannot forge report structure or inject ANSI sequences. It
emits ANSI status colors when explicitly enabled; `Always` requires that
capability, `Never` forbids it, and `Auto` is resolved by the host-provided
capability flag.
`OutputRenderFrame` exposes only the next frame kind, record index, sequence,
and checked byte count; it does not retain
borrowed text; only `Emit` accepts a nonzero record index. `EsOutputTransport`
wraps that renderer with a bounded
`Planned → Streaming → Complete/Failed/Cancelling/Cancelled` hand-off. A host
adapter must acknowledge the exact frame descriptor and full byte count before
the renderer advances; reordered, forged, oversized, or short writes are
rejected. Non-`Emit` events reject frame/write payloads. The transport and
document each enforce their own byte ceiling; a transport policy may use the
global maximum while the document sets a smaller limit. The complete report,
each frame ceiling, and the required frame count are checked before the
transport is returned, so streaming cannot first discover one of those caps
after a partial report has been written. The transport still does not perform
OS writes or prove what an OS writer actually accepted.
`EsOutputJunit` now provides a bounded whole-document JUnit serializer for a
sealed `OutputDocument`. It validates UTF-8/XML characters, escapes XML text
and attributes, maps failure/error/skip outcomes, retains flaky-pass metadata,
wraps captured stdout/stderr, and rejects output that exceeds its selected
byte limit. `OutputRecord` includes bounded typed retry history; each failed,
crashed, timed-out, or errored prior attempt is emitted as a `<flakyFailure>`
child with its diagnostic and captured streams, while flaky-pass properties
remain for consumers without flaky-history support. Header, record, and footer
frame APIs use a count-only writer over the same emission path, and
`EsOutputRender` derives JUnit frame lengths from those measures. Generic JSON
now has the same count/write contract, emits every record field and retry
attempt plus summary counters, and rejects invalid UTF-8. Retry text is charged
to the document's aggregate byte budget. Its JSON status names include `pass`,
`flaky`, `fail`, `error`, `skip`, `crashed`, `timed_out`, and `cancelled`.
JUnit preserves crash and timeout types in `<error>` children and marks
cancellation on the `<skipped>` child while keeping standard aggregate
counters. `EsOutputTransport` hands hosts canonical owned
Human/JSON/JUnit frame bytes;
its checked payload acknowledgement rejects mutated or independently
reformatted content before advancing. This still cannot prove what an OS writer
actually accepted—the byte count remains the host adapter's acknowledgement.
The separate single-case differential JUnit renderer remains a different
schema. `OutputStatus.Flaky` preserves successful retry classification in
typed records while retaining the existing status ordinals.

`EsBuild` is the shell-replacement boundary for build and test recipes.
`BuildGraph` contains typed `ProcessCommand` nodes, stable fingerprints,
bounded per-node/aggregate logs, and resolved dependency node indices. Each
dependency index must refer to an earlier node; dependency lists are strictly
ascending and duplicate-free, so edge validation and scheduler dependency
readiness use direct bounded lookups without repeated dependency-name scans.
The build-definition adapter can pass target and dependency names to
`resolve_build_dependencies`, which uses a sorted name index and emits each
edge list in canonical node-index order. Its `BuildDependencyResolution` also
returns the name-order index; `attach_build_dependency_resolution` checks the
complete resolution against a fresh graph of command templates before
attaching edges and the index. This avoids hand-copying parallel edge arrays
and rejects malformed resolutions before graph mutation. Indexed graph
validation then checks unique names linearly and cache lookups use binary
search. The resolver bounds node names, per-node edges, and aggregate edges.
Manual graphs without an index are accepted only up to
`UNINDEXED_NAME_SCAN_NODES` (128 nodes); larger graphs fail with
`NodeNameIndexRequired` and must use the resolver/attachment path. This caps
the legacy pairwise uniqueness check while preserving indexed linear
validation and logarithmic cache lookup for large graphs.
`BuildUsageGraphPlan` also retains each action's original dependency indices
and fingerprint; execution-boundary revalidation rejects a substituted but
otherwise valid edge or a changed nonzero fingerprint, rather than accepting
any graph that merely remains a valid DAG.
Validation rejects missing, duplicate, unordered, and cyclic dependencies and
preserves process-command errors. `advance_build_graph` limits active nodes and
records per-node completion or failure. It exposes cancellation acknowledgement
so a scheduler cannot silently overrun parallelism or abandon children. A node
start is admitted only after every indexed dependency is `Succeeded`, so
dependency readiness cannot be forged by an otherwise valid topological graph.
Aggregate counters are
reconciled with node states, and terminal graph states reject forged progress
or unfinished completion. A node failure is latched immediately, all remaining
planned nodes become `Cancelled`, and the graph enters `Failing` while active
siblings are stopped. New starts are forbidden in that state; sibling exits can
still be accounted individually, or host-confirmed stop/reap acknowledgement
drains the remaining siblings before the graph reaches `Failed`.
Graph validation keeps `Running`, `Failing`, `Cancelling`, `Succeeded`,
`Failed`, and `Cancelled` shapes disjoint: failure cannot be acknowledged as
ordinary cancellation, and success/cancellation must contain the corresponding
node outcomes.
Aggregate log admission proves the accumulated log total before subtracting
each node's remaining log capacity.
Cancellation acknowledgement also accounts any still-running nodes as
`Cancelled` after the host confirms they stopped; it cannot leave active
children unaccounted.

`EsBuildCompilationDatabase` projects explicitly selected translation-unit
actions from a validated `BuildUsageGraphPlan` into bounded deterministic JSON
for `compile_commands.json`. It preserves the executable and each argument as
separate strings in the standard `arguments` array, rather than attempting to
quote shell command text. Directory, source, and selected JSON output paths
must be absolute bounded UTF-8; action indexes must be unique and in graph
order; the caller may select one declared object output even when the action
also owns byproducts. Compile actions must contain
one unambiguous `-c source` pair; each primary-output spelling (`-o file`,
`-ofile`, `--output file`, or `--output=file`) may occur at most once and, when
present, must have a nonempty operand declared in that action's output set,
even when the optional JSON `output` field is omitted. With no explicit
primary-output option, the GCC/Clang default object path (source basename with
`.o` under the command working directory) must be declared by the action. If
the optional JSON `output` field is supplied for such a command, it must match
that derived object path. Relative output operands resolve against the command
working directory before graph ownership is checked. An explicit
dependency-file output (`-MF file`, `-MFfile`, or Clang's `-dependency-file`
alias) is limited to one nonempty operand and must name a declared action
output; directing it to `-` is accepted as stdout rather than a sidecar. `-MD`
and `-MMD` require one of these explicit paths so the compiler's implicit
depfile destination cannot escape graph ownership. Clang's separate-operand
`-dependency-dot` output is likewise limited to one nonempty, distinct,
graph-owned path. Joined spellings of the `-dependency-file` and
`-dependency-dot` options are rejected because Clang declares both as
separate-operand options.
Clang's `-MJ` compilation-database fragment output is likewise limited to one
declared action output. Clang's `-serialize-diagnostics` and
`--serialize-diagnostics` options must likewise have one separate output
operand declared by the action. A selected output must resolve to the same
declared path as the primary-output operand. File-producing primary and
sidecar outputs must resolve to distinct paths so one compiler option cannot
overwrite another output that happens to share a graph declaration; `-MF -`
is excluded because it directs dependency output to stdout.
Clang's `-fmodule-output=<path>` BMI sidecar is graph-owned like the other
outputs; bare `-fmodule-output` derives the source basename with `.pcm` beside
the primary object and must also be declared.
JSON escaping, entry count, and the 64 MiB output ceiling are checked
before bytes are returned. Because
the standard format has no process-environment field, commands must inherit
the parent environment with no explicit entries; commands with cleared or
replaced environments are rejected instead of silently changing meaning. The
caller still owns atomic file publication and must decide which graph actions
are compilation units.
The projection rejects -c commands that switch to preprocessing, assembly,
dependency-only (`-M`, `-MM`, `--dependencies`, `--user-dependencies`),
syntax-only, precompile, analysis, or another non-object frontend stage rather
than attributing an object output to them. Clang's -emit-llvm -c form derives a
.bc primary output instead of .o, and conflicting stage-selection options are
rejected. Header-language `-x` modes that create precompiled headers require an
explicit graph-owned `-o`, because GCC and Clang use different implicit PCH
suffixes. Commands that write unmodeled compiler byproducts are also rejected:
`-save-temps` intermediates, `-save-stats` files, `-fproc-stat-report` CSV,
GCC's `-fstack-usage` `.su` and `-fcallgraph-info` `.ci` sidecars, GCC pass
dumps from `-fdump-*`, `--dump=...`, or `-da`, explicit `-fprofile-note`
`.gcno` output, file-targeted `-fopt-info`, and coverage notes from
`-ftest-coverage` or `--coverage`/`-coverage`. GCC `-fopt-info` forms directed
to `stderr`, `stdout`, or `-` remain projectable.
Compiler plugin loading is also rejected: GCC `-fplugin`/`-fplugin-arg-*`,
Clang `-fplugin`/`-fpass-plugin`, and cc1 plugin loading forwarded through
`-Xclang`. Since such dynamically loaded code can emit opaque extra files, its
outputs cannot be proven graph-owned by this projection.
It also refuses Clang's unmodeled module-dependency directory, module cache
and user module-build paths, index-store and index-unit outputs, symbol-graph,
dynamic-debugging temporary, and crash-reproducer outputs; those can produce
directory trees or failure-path files not listed as graph outputs. Explicit
`-gen-reproducer=off` and `-fcrash-diagnostics=off` remain projectable because
they disable those failure-path outputs.
Clang commands that enable implicit module compilation are rejected as well:
`-fmodules` uses a system-selected cache directory by default, an explicit
`-fimplicit-modules` enables implicit module construction, and
`-fmodules-driver` may schedule module builds whose cache outputs are outside
the selected action. The ordered combination `-fmodules -fno-implicit-modules`
remains projectable for commands that consume prebuilt modules without
creating implicit cache entries.
Clang's `-gen-cdb-fragment-path <directory>` is rejected because it emits
uniquely named fragments that cannot be derived as a deterministic action
output. If `-MJ <file>` is also present, Clang gives `-MJ` precedence, so the
projector accepts the command only when that `-MJ` file is itself a distinct,
declared output.
Clang's `-ftime-trace` is modeled: the bare option derives a `.json` output
beside the primary output. With `-ftime-trace=<path>`, the path may be a file
or directory; exactly one interpretation must resolve to a distinct declared
action output (the directory form uses the primary-output stem plus `.json`).
With debug information enabled, split DWARF (`-gsplit-dwarf` or
`-gsplit-dwarf=split`) similarly derives a `.dwo` beside the primary output;
that sidecar must be a distinct graph-owned action output. Single-file mode
(`-gsplit-dwarf=single`) and `-gno-split-dwarf` do not claim a DWO. The
projector rejects path-changing `-dumpdir`, `-dumpbase`, and `-dumpbase-ext`
overrides while split output is active, along with split-DWARF bitcode and
precompiled-header actions whose sidecar identity is not modeled.
Clang's `-fsave-optimization-record` and `-foptimization-record-passes=<filter>`
are modeled as producing an optimization-record sidecar. The default YAML
record is derived as `<primary-stem>.opt.yaml`. Supported formats are YAML and
bitstream; the explicit
`-fsave-optimization-record=bitstream` format uses
`<primary-stem>.opt.bitstream`. `-foptimization-record-file=<path>` instead
names the record directly, and that path must be a distinct declared action
output. Repeated record-file or format options, unsupported formats,
undeclared outputs, and collisions are rejected. LTO, Darwin `-arch`, and
precompiled-header actions are rejected while record output is active because
this projection does not model their alternate sidecar naming.
`-fno-save-optimization-record` disables the implicit sidecar when it is the
final save/disable option.

`EsBuildIncremental` is the pure CMake/Ninja-style stale-decision boundary over
that graph. A bounded target manifest records the last successful recipe,
input, and output fingerprints plus ordered target dependencies. `Phony` targets
cover aggregate, test, and alias tasks that intentionally have no output file;
validation rejects any phony target that declares an output, while accepting
outputless phony targets whose recipe and dependency state is still classified.
A host adapter
supplies current path observations and dependency-current flags; classification
returns `UpToDate`, `RecipeChanged`, `DependencyDirty`, `InputChanged`,
`OutputMissing`, or another typed reason before the scheduler can admit a
cache hit or dispatch a rebuild. Duplicate paths, missing fingerprints,
dependency-order violations, and malformed observations are rejected through
`error[BuildIncrementalError]`. A target that consumes a path produced by
another target must name that producer directly; undeclared output edges are
rejected before scheduling so a consumer cannot run against a stale generated
file. The module performs no filesystem or process effects, so it is
independently testable and can drive clean/no-op/incremental build comparisons.
Cache recipe signing rejects commands with inherited host environments unless a
future API supplies and hashes an explicit environment snapshot. Cacheable build
actions must currently use a fully specified `Replace` or `Clear` environment,
an absolute executable and working directory, null stdin, captured stdout and
stderr, no file redirection, checked failure semantics, and a nonzero timeout.
These are the serial build executor's supported command policies; rejecting
anything else at signing prevents an unsupported command from being accepted
as a cache hit without ever reaching dispatch. In particular, relative or
empty working directories and inherited stdin would let ambient host state
change the action's meaning without changing its signature. The serial build
executor preserves `Replace`/`Clear` by dispatching through the absolute POSIX
`/usr/bin/env -i` shim; the requested tool must itself be an absolute path.
Incremental callers must associate the canonical relative
`usr/bin/env` helper path with each such command. Its descriptor-relative file
digest is mixed into that node's observed toolchain identity before planning
and before cache publication. Each observation pass hashes a unique resolved
executable/helper path set once and shares its identity/stamps across nodes with
the same set; an open-addressed index resolves hash collisions by exact path-set
comparison and returns a typed error after 64 probes. A final metadata pass
checks that no set drifted while the others were being read. A file stamp
(device, inode, size, mtime, and ctime) is captured during the content hash.
Immediately before each dirty-node dispatch, the executor opens the executable
and helper through the same directory capability and compares its stamp,
avoiding a second full binary read for every target. Drift aborts with
`ToolchainChanged`. Because the process adapter still spawns by pathname,
replacement in the narrow interval between that last observation and `exec`
remains possible; descriptor-bound execution is required to close that race.
`Inherit` continues to use the captured-process overlay path and cannot be
signed for cache reuse without a captured ambient snapshot. Source fixtures
cover mode dispatch and identity/stamp mismatches, but E07 runtime behavior and
cache acceptance remain unverified under the validation hold.
`resolve_incremental_build_dependencies` validates that same manifest and
converts its target/dependency names into the canonical node indices and bound
name-order index expected by `BuildGraph`; callers no longer need to maintain
parallel hand-written name and index arrays.
Manifest validation resolves target/dependency names once and sorts bounded
input/output path-owner indexes, rejecting duplicate inputs/outputs, cross-
target output collisions, and undeclared generated-output edges without nested
whole-manifest scans. Aggregate input and output records are each capped at
1,048,576 so the indexes have an explicit memory ceiling.
Observation capacity is 2,097,152 records, enough to fingerprint every unique
path referenced by manifests at those aggregate ceilings.
`classify_build_incremental_manifest` returns one deterministic decision per
manifest target in manifest order. It derives each dependency's currentness
from the already-classified earlier targets rather than accepting caller-made
dependency flags, so staleness propagates through the DAG before dispatch.
Observation paths are validated once into a bounded sorted index; duplicate
paths are rejected and target input/output fingerprints use binary search
rather than rescanning the full observation list.
Manifest paths use a portable canonical-relative form: `/` is the only path
separator, empty and `.`/`..` segments are rejected, and absolute, drive-prefixed,
backslash-containing, NUL, tab, and line-break paths are refused before any host
adapter resolves them beneath its build-root capability. This keeps a manifest
from changing meaning when it is consumed by a different platform adapter.
`plan_build_incremental_cleanup` reconciles a previously successful manifest
with the current graph in deterministic target/output order. It returns a
bounded list of outputs removed by a target deletion or rename, retains an
output adopted by another current target, and rejects
`OrphanedOutputInput` when a current consumer still names a removed generated
output. The returned `BuildIncrementalStaleOutput` includes the previous owner
and fingerprint so a host adapter can re-check the build root and file identity
immediately before deletion; an empty current manifest means that all previous
outputs are obsolete for cleanup purposes, while the scheduler-facing manifest
validator still rejects an empty graph. The pure module never removes files
itself.

`EsBuildIncrementalPosixExecutor::execute_build_graph_incremental_cached_at`
provides the POSIX cache-locked route. Before each dirty node starts, matching
previously cached outputs are invalidated through a no-follow directory
capability. If a command fails, or post-run validation/cache publication
fails, the executor preflights and removes outputs of every node that started
in the transaction; outputs of later, unstarted nodes are retained. A failure
before cache replacement leaves the previous manifest installed, but an
uncertain publication may already have replaced it. Output-cleanup errors do
not replace the original publication error, so `PublishOutcomeUnknown` remains
visible even if some outputs could not be removed. This allows an ordinary observed
failure to be retried without treating partial command output as a user edit.
After each successful command, every declared output is observed before the
node is marked successful or any dependent node can start; a missing output
fails that node and triggers the same started-output cleanup path.
The build root must remain exclusively owned during the transaction. A host
kill or machine crash bypasses in-process cleanup; partial outputs then fail
closed against the prior manifest and require explicit repair. After a
successful graph and commit validation, removed-target stale outputs are
preflighted against their previous complete fingerprints and removed through
the same no-follow directory capability before the new cache manifest is
published. A modified stale output is preserved and prevents cache publication;
stale cleanup candidates are cleared from the returned commit only after their
cleanup succeeds. The cache publisher also compares an existing regular cache
manifest against the validated new bytes while holding its writer lock; an
exact match returns a committed publication marked `unchanged` without creating
a staging file or replacing the manifest, preserving its timestamp. It uses
`EsFileReadAtPosix::read_regular_file_at`, a shared bounded helper that rejects
non-regular entries, opens without following the leaf, and rechecks descriptor
and named-entry identity/size/mtime/ctime after reading. The lock serializes
cooperating writers only; hostile non-cooperating mutation is not excluded by
this cache adapter. `BuildIncrementalPosixCacheRun` exposes this
case as `cache_unchanged`, separately from `cache_published`, so callers can
distinguish an up-to-date manifest from one that was newly replaced.

`EsBuildExecutor::execute_build_graph_serial_with_outputs` is the fresh-build
host route. It requires every declared absolute output path to be absent before
the first command, rechecks the current node's outputs immediately before
launch, and verifies the node's outputs resolve to files before admitting its
success transition. A later node whose output appeared before its producer's
dispatch is rejected as `PrematureOutput`, rather than receiving false output
credit from an earlier action. Output paths must use a lexically normalized
absolute POSIX spelling: empty, `.` and `..` segments, repeated separators, and
trailing separators are rejected so string-distinct keys cannot name the same
lexical output. Symlinked ancestor aliases and arbitrary concurrent filesystem
mutation remain outside this lexical check.
A pre-existing filesystem entry, including a symlink, is rejected as
`OutputAlreadyPresent` while the graph remains planned; callers must clean
prior outputs explicitly. These checks are observations, not an atomic
filesystem reservation, so they do not exclude arbitrary concurrent mutation.
Incremental execution has a separate observation/cache contract and does not
inherit this fresh-output precondition.

`EsResource` is the ownership ledger shared by runtime adapters. A lease names
the resource kind, nonzero identity, and owner token; `ResourceLedger` keeps
active/failed counts bounded and rejects duplicate identities. The close path is
explicit (`Acquired → Closing → Released`), while failure/abandonment records a
terminal `Failed` lease; owner mismatches and double-close attempts fail through
`error[ResourceContractError]`. OS handle acquisition, actual cleanup, and
cross-thread transfer still require adapter evidence.

`EsValueOwnership::ValueOwnershipLedger` is the allocator-independent runtime
ownership boundary. Values carry arena identity, owner token, generation, kind,
and retained bytes; acquisition admits only initially `Owned` values, dropped values must carry no retained payload, linear values allow at most one active borrow, borrowed
views cannot be reborrowed, moves require an unborrowed owned value and advance
the generation, and drops reclaim retained bytes without deleting provenance.
Borrow leases record borrower identity, source generation, and an expiry token;
duplicate ids, stale leases, owner mismatches, double-end, accounting drift,
and reclamation while borrowed raise `error[ValueOwnershipError]`. Validation
also requires the value/borrow state relation to be consistent in both
directions: active leases must reference `Borrowed` values, and a `Borrowed`
value must retain at least one active lease.

`EsErrorProvenance::ErrorProvenanceLedger` preserves operational error identity
across runner and driver boundaries. Each envelope records a closed origin
(`Script`, `Host`, `InvalidCompilerOutput`, `Cancelled`, or `LimitExceeded`),
phase, nonzero code, bounded message, optional source location, retryability,
and an earlier cause id. Capture, forward, handle, and cancel are explicit
state transitions; length checks precede content scans so oversize text reports
`TextLimitExceeded` and embedded NULs report `EmbeddedNul`; forwarding cannot
reclassify the origin, a captured envelope cannot claim forwarding history, and
a forwarded envelope must record at least one forward. Future/self causes
are rejected, cause depth and retained text are bounded inclusively at their
configured budgets, and handled errors cannot be cancelled again through
`error[ErrorProvenanceError]`.

`EsCancellation::CancellationLedger` is the cooperative cancellation boundary
for VM safe points and blocking host adapters. Tokens have bounded parent/child
trees, owner identity, polling counts, and explicit `Request → Propagate →
Acknowledge → Complete` or `Fail` transitions. Polling a requested token at a
VM checkpoint propagates cancellation only after its parent is already
requested or propagating; polling before a blocking host wait raises
`HostBlockDenied` without consuming a poll or changing the last checkpoint,
while acknowledgement is admitted only after a
cleanup or completed-block checkpoint. Validation also rejects externally
assembled acknowledged tokens whose last checkpoint is not one of those safe
points through `error[CancellationError]`; children cannot be registered under
a completed or failed parent, because such a child could never satisfy the
parent propagation edge.

`EsTelemetry::TelemetryLedger` provides optional bounded observability. Disabled
mode rejects recording; counter mode stores fixed metric identities, while
event mode admits sampled run/error/cancellation/span events with bounded names,
positive bounded payload sizes, total event attempts, span depth, and monotonic
sequence numbers.
Sampled-out events still consume the event ceiling and sequence accounting, and
span begin/end accounting remains active even when an event is not retained. A
recording attempt is rejected before any sequence, sampling, or span counter is
mutated once retained plus sampled attempts reach the event ceiling. A fresh
ready ledger must have zero activity, retained sequence numbers must fit within
the retained-plus-sampled attempt range, repeated failure is rejected, and a
run may seal only after all spans close through `error[TelemetryError]`.

`EsStructuredTask::StructuredTaskScope` makes structured concurrency explicit
for scheduler adapters. Child start/success/failure, fail-fast transition,
scope cancellation, cleanup entry/exit, cancellation acknowledgement, and join
are separate transitions. Planned scopes must be empty, cleanup depth is present
only for `Cleaning` children, a child in `Cleaning` cannot acknowledge
cancellation until its cleanup depth returns to zero; nested cleanup entries are
admitted up to the policy's `max_cleanup_depth`. Join reports failure
or cancellation only after every active child is accounted for through
`error[StructuredTaskError]`; a join also rejects any admitted child that is
still `Planned`. The transient `Joining` shape is also required to have no
active children and all admitted children complete before it can settle.
Validation also requires `Succeeded` and `Cancelled` scopes
to account for every child with no failures, and rejects `Failed` scopes that
still claim active children.

`EsExitStatus::ExitStatus` gives the launcher one stable process-status
contract. Success, user statuses, usage/source/check/test failures, script and
host failures, resource limits, cancellation, and signal death are distinct
outcomes; user `main -> i64` values are restricted to `0..123`, reserved
categories use fixed codes, success/user/signal outcomes reject diagnostic
detail payloads, and signals map to `128 + signal` only for bounded positive
signal numbers through `error[ExitStatusError]`.

`EsDeadline::DeadlineClock` separates host monotonic time from deterministic
virtual time. Bounded waits are armed with owner identities, advances are
strictly positive and capped, pending waits become ready only through an
explicit due-fire transition in deterministic global deadline/id order, cancellation is terminal for that wait, and a
clock cannot seal while pending waits remain. Backward time and oversized
advances fail through `error[DeadlineError]`; imported `Ready` waits must also
be due at the current clock.

`EsDebugger::DebuggerSession` bounds source breakpoints, stack frames, handler
and continuation-depth metadata, and replay branches with nonempty choices and
acyclic parent chains. Attach/pause/continue/
step, frame push/pop, branch selection, termination, and failure are explicit
state transitions; locations and names are bounded before publication, a
detached session cannot carry frames, and a terminated session cannot resume
through `error[DebuggerError]`; failure cannot be entered while detached and
a failed session cannot be re-terminated.

`EsArchive::ArchiveSession` is the admission boundary for tar/zip extraction.
Relative path segments reject absolute paths, backslashes, empty/dot/traversal
segments, embedded NULs, and overlong names before publication; one or more
trailing separators are accepted as archive directory spelling and ignored for
duplicate-path comparison. Entry count,
per-entry bytes, subtraction-safe aggregate bytes, duplicate ids/paths, link policy, and
planned/extracting/committed/failed/cancelled states are bounded through
`error[ArchiveError]`; non-link entries cannot carry hidden link targets, a
planned session cannot contain preloaded entries or counters, failure is
admitted only during active extraction. Aggregate byte admission proves the
existing total before subtracting remaining capacity. ID and normalized-path
index operations stop after 64 probes and return a typed error if unresolved;
admission preflights both indexes before mutating its entry ledger. Filesystem
writes remain host-adapter work.

`EsHash::HashContext` is the bounded integrity boundary used by package,
archive, and artifact adapters. Algorithm identity, input/chunk ceilings,
one-way begin/update/finalize/fail transitions, canonical digest word shape,
planned-state accounting, paired chunk/byte counters, zeroed unpublished digest payloads, and algorithm matching are checked before
publication. The module also exposes explicit modulo-2^64 add/multiply helpers
for FNV/index fingerprints so hashing stays consistent with Elisa's checked
integer operators; the model delegates cryptographic computation to a
maintained host/library implementation through `error[HashError]`.

`EsBinary::BinaryCursor` keeps binary parsing distinct from text. It bounds the
input and read count, admits explicit little- or big-endian scalar reads with
subtraction-safe offsets, supports bounded skipping, and requires an explicit
finish with no trailing bytes; truncation, post-finish reads, impossible
offset/read accounting, and malformed
state (including a forged exhausted cursor before EOF) fail through
`error[BinaryError]`.

Binary format adapters can use `EsBinary::BinaryCursor` as their shared input
contract: it preserves byte-oriented semantics, explicit endianness, and
trailing-byte policy while leaving format-specific schemas above the cursor.

EsHandle supplies the host-handle table that those adapters consume. Raw
handle identity is distinct from the logical resource id and owner token;
duplicate identities are rejected, ownership transfer requires a new owner,
and close, release, failure, and abandonment update bounded accounting before
the next operation. No platform descriptor is exposed to source code.

Every verified module also has canonical structural bytes through
`canonical_module_bytes(module)` and a compact fingerprint through
`module_fingerprint(module)` (with `canonical_module_hash` as the explicit
algorithm name). The reference implementation uses fixed little-endian scalar
encodings and schema markers over types, source spans, trace sites, ordered SSA
pools, blocks, functions, and handlers. The module stream begins with `ES` and
format version `1`; collection lengths are included before their elements, and
hashing those exact bytes yields the module fingerprint. No pointers, allocator
addresses, padding, host word sizes, or backend instruction layout enter the
encoding. This makes the bytes and their deterministic
non-cryptographic `u64` fingerprint suitable for backend and differential-test
artifact correlation; neither is a security identity or a replacement for IR
verification.
`canonical_bytes_sha256` and `canonical_module_digest` now provide a portable
32-byte SHA-256 digest over that exact stream, with a bounded 256 MiB input
contract and an empty sentinel for unavailable/oversized streams. The digest
is the candidate trust/cache identity; the existing `u64` fingerprint remains
only a compact correlation key. `canonical_digest_word` and
`canonical_module_digest_word` expose the fixed four-word representation used
by artifact metadata without changing the canonical stream.
Before either operation, `canonical_module_counts_valid` checks every collection
whose length is encoded as u32, including nested globals, handlers, and function
pools. An unrepresentable host count therefore returns the empty byte sentinel
from `canonical_module_bytes` and zero from `canonical_module_hash` instead of
silently truncating a cache identity; normal verified modules remain on the
version-1 stream.
That admission also performs an allocation-free module budget pass: every
borrowed text field is capped at 64 MiB, text payloads and collection elements
are accumulated with checked subtraction, and the conservative total stays
within the 256 MiB canonical-stream ceiling before `darray[u8]` emission begins.
TypeTable child lookups also use a subtraction-based host-index helper after
validating the serialized u32 start and u16 count. They never add a hostile
offset in u32 space before checking bounds, and tables whose row or child pool
counts cannot fit the serialized u32 domain are rejected before iteration.
Field-level emitters and hash primitives are private to `EsIr`'s serializer. The
bytecode artifact envelope uses only the qualified
`EsIr::canonical_artifact_*` adapters, keeping its metadata format independent
of the IR serializer's representation helpers.

When a module has an interned `TypeTable`, the canonical stream appends tagged
descriptor-row and child-pool records before the function collection. Tables with
both rows and children empty are omitted so hand-built legacy modules retain their
original version-1 encoding; any non-empty child pool is serialized and fingerprinted
even when malformed, while verifier admission rejects an orphaned pool.

`EsIrArtifact.ModuleArtifact` is the small version-2 typed metadata envelope used by
differential reports today. It records format version, backend label, source
revision, the compact fingerprint, and all four words of the canonical
SHA-256 digest; the owned canonical byte stream is kept as the separate
`canonical_module_bytes` value so its inferred region remains with the artifact
writer. `artifact_metadata_valid` rejects version mismatches, an empty backend
label, oversized backend/source-revision views, a zero compact fingerprint, or any zero digest word before
`artifact_fingerprint_matches_module` correlates both identities with a module.
`canonical_module_artifact_bytes` persists this metadata as a bounded version-2
`ESIA` envelope, and `module_artifact_bytes_valid`/`decode_module_artifact`
reject legacy versions, malformed lengths, incomplete digests, and trailing
bytes before exposing borrowed text views. `module_artifact_envelope_status`
and `module_artifact_requires_migration` distinguish the known version-1
envelope from malformed bytes so a future cache migration can be explicit
without weakening current fail-closed admission. Both metadata strings are
also rejected when they contain an embedded NUL, preserving host C-string
boundaries. `migrate_module_artifact` can upgrade an in-memory legacy record,
but only after matching its fingerprint to the verified module and recomputing
all digest words; stale or unavailable records return an invalid sentinel.

## Bytecode lowering

`EsBytecode.lower_bytecode` is the first backend facade. It accepts only a module
with zero verifier issues, copies the typed instruction/operand/edge pools and
handler metadata in declaration order, and adds a deterministic block-offset table
for each function. `BytecodeBlock.terminator` remains the original typed CFG
terminator, so branches and edge arguments are not rewritten into host labels or
machine addresses. A malformed module returns the verifier issues and an empty
bytecode module; no backend-specific recovery is permitted. The initial bytecode
representation deliberately preserves semantic `Opcode` values, giving a future
packed encoder and VM one checked source of truth while the reference interpreter
continues to define behavior.

Each bytecode function also carries a parallel `dispatch_classes` table. The
exhaustive `bytecode_opcode_class` state machine groups every semantic opcode into
the handler family that a packed VM will use (literal, frame, aggregate, process,
effect, continuation, and so on). `bytecode_dispatch_table_valid` walks functions
and instructions with explicit preflight states and rejects a missing, stale, or
invalid class entry before execution. It also validates the cumulative u32 block
layout by proving each block offset before subtracting its count, and checks exact
instruction coverage before `bytecode_to_ir` reconstructs
instruction starts, preventing a malformed block-count sum from wrapping the
reconstruction cursor ahead of full IR verification.

`bytecode_next_control` is the first executable packed-loop primitive. Its
program-counter cursor advances one instruction at a time and then selects a
verified `Return`, `Jump`, `Branch`, or `Invalid` action through explicit control
states. Branch selection is supplied by the value engine; this keeps control-flow
ownership separate from effects and runtime values while the remaining opcode
families are migrated.

The `EsBytecode` namespace keeps preflight/execution cursors and direct opcode
helpers private. `BytecodeControlCursor` and the small classification/offset
inspection functions are public deliberately because tooling and conformance
fixtures use them as stable structural inspection APIs; new consumers should use
those APIs rather than reaching into VM state.

`EsBytecode.execute_bytecode` selects the packed loop whenever all instructions
belong to the direct subset, including guarded error recovery. It rebuilds the
verified IR shape and delegates to `EsIr.interpret` only for modules that still
contain dynamic effects, handlers, continuations, supported global initializers
outside the direct type/width set, or another unsupported family. The direct
bytecode runner initializes scalar and flat literal collection globals once per
top-level run, stores collection payloads in the bounded runtime arena, and
shares global descriptors across nested calls. Both paths are checked against
the same result and observation trace/value contract in the bytecode tests.
Every `Execution` also records its `engine`: `ReferenceInterpreter` for direct
interpreter calls, `DirectBytecode` for the packed state machine, and
`BytecodeInterpreterFallback` when the compatibility entrypoint deliberately
reuses the verified interpreter. Consumers must inspect this field before
counting a run as independent backend evidence.
Bytecode executions also carry a backend-neutral `ExecutionCapability` snapshot
with a `capability_known` bit and the preflight's direct-support, function,
instruction, and global counts. This keeps capability evidence attached to the
value returned from the execution boundary, rather than relying on a caller to
recompute or remember a separate report. Direct interpreter calls leave the bit
false because they have no bytecode preflight.
Both engines also consume the shared `ES_RUNTIME_DEFAULT_MAX_EXECUTION_CALL_DEPTH`
contract (currently 4,096 active calls/handler depth) while ordinary calls still
use host-recursive adapters. Hitting that boundary is a typed `OutputLimit`
failure, not a fabricated return value; keeping the constant in the runtime model
prevents backend-specific stack policies from drifting.
The same runtime model owns the 128-level aggregate equality recursion boundary;
both engines fail closed on cyclic or hostile nested storage at that limit instead
of allowing a backend-specific host-stack exhaustion.
Recoverable error-guard nesting is likewise governed by the shared
`ES_RUNTIME_DEFAULT_MAX_ERROR_GUARD_DEPTH` ceiling (4,096), rather than treating
the bytecode and interpreter guard stacks as unrelated resource policies.
Every execution carries the per-run `EsRuntime::RuntimeResourcePolicy` and the
matching `RuntimeResourceUsage` snapshot. The policy names the common budget
dimensions—steps, optional elapsed time, memory, open handles, child
processes, output bytes, regex work, retained traces, and concurrent tasks—so a
nested call or backend fallback has an explicit place to inherit the parent
contract. `runtime_resource_policy_valid` now caps every declared resource
dimension against the shared host ceilings before execution. `runtime_resource_usage_within_policy` uses subtraction-free
comparisons and treats only the elapsed-time field's zero as "timer not
attached"; a zero in every other field is an exact zero budget, and a usage
record cannot claim elapsed time while that timer sentinel remains zero. The current
`runtime_resource_acquire`/`runtime_resource_release` counter edges provide
typed overflow/underflow-safe admission for handles, child processes, and
concurrent tasks. The corresponding `runtime_resource_add_*` helpers apply the
same checked-subtraction rule to steps, memory, output, regex work, and retained
traces; each helper rejects an already-over-budget usage value before subtracting
remaining capacity. `runtime_resource_add_elapsed` applies the same bounded edge while
preserving `elapsed_micros == 0` as the explicit “timer not attached” sentinel;
host bridges still need to sample a monotonic clock and thread these edges
through every nested path.
`runtime_resource_remaining_policy` derives a child, callback, or replay
admission policy from already-consumed usage with saturating subtraction across
every bounded dimension; an exhausted parent therefore gives the child zero
remaining capacity, while an unattached elapsed timer remains the explicit zero
sentinel. This is a pure admission calculation and does not claim that a host
bridge has started accounting an otherwise unaccounted dimension.
The reference interpreter now acquires a process slot immediately before each
of its four `fork` sites and releases it only after `waitpid` confirms that the
direct child was reaped. Fork failure rolls the slot back; uncertain cleanup
retains the slot and aborts rather than understating live resource use or
allowing a recoverable handler to continue. This counter covers the
interpreter-owned child leader, not arbitrary descendants launched by that
child. The policy-aware bytecode facade routes narrowed process budgets through
the reference interpreter; strict direct-only execution rejects them because
its process bridges do not share the packed loop's ledger. Default direct
bytecode process adapters use the interpreter's default process policy per
opcode, but do not publish peak process usage into the enclosing bytecode
snapshot. The shared `runtime_resource_policy_has_unaccounted_dimensions`
predicate therefore continues to fail closed on non-default elapsed, memory,
open-handle, and concurrent-task budgets. Steps, output, regex, retained traces,
and reference-interpreter child-process admission are implemented policy
dimensions.
Short-lived reference-interpreter filesystem streams, process-capture temporary
files, secure `mkstemp` descriptors, and directory scans now acquire an
open-handle slot before `fopen`, `tmpfile`, `mkstemp`, or `opendir`; failed opens
roll the slot back, and every close path retires it after the host close
attempt. An uncertain `close` failure retains the slot and aborts. This applies
the shared default handle ceiling during interpretation. Narrower
caller-supplied handle policies remain fail-closed until the standalone
`EsRuntime::FileStream` lifetime can carry the same per-run ledger;
`open_handles` currently measures active leases, not the peak number observed
during a completed run.
The reference interpreter's `tick` uses the step edge directly, keeping its
live usage ledger aligned with the step-limit failure path.
Console writes and completed process-capture streams now charge their admitted
byte counts through the shared output edge before returning a value, so a
caller-supplied output budget cannot be bypassed by switching between console
and child-process adapters. Host-side process polling still keeps its separate
capture ceiling and bounded overshoot contract.
Reference-interpreter regex operations derive their local matcher budget from
the same policy and account newly spent work exactly once, including multi-pass
capture and replacement scans; an exhausted shared regex budget fails before
the operation returns a value.
The allocation-free public regex adapters use the identical
`ES_RUNTIME_DEFAULT_MAX_REGEX_WORK` ceiling, so direct bytecode calls cannot
silently run beyond the default policy while custom regex budgets continue to
route through the reference interpreter.
interpreter and direct bytecode paths populate the step/retained-trace limits
and returned usage snapshot, rejecting a trace pool that exceeds the caller's
policy, while their existing host bridges continue enforcing their specialized
ceilings. `interpret_with_resource_policy`,
`execute_bytecode_with_resource_policy`, and
`execute_bytecode_direct_only_with_resource_policy` make this boundary explicit;
the policy-aware bytecode facade routes caller-specific output/regex limits
through the reference interpreter (which owns those counters), while strict
direct-only entrypoints reject policies with unaccounted dimensions instead of
silently ignoring them;
the direct loop also aggregates console and process-capture bytes into its
default execution usage snapshot; nested direct calls share the parent's
output ledger and return their accumulated usage to the caller, so child
captures cannot reset or bypass the enclosing output ceiling, including when
a child emits bytes before a recoverable failure;
the bytecode loop receives the retained-trace limit before each `Observe`
append, so a custom zero/one/boundary policy cannot allocate the default trace
pool first;
the legacy entrypoints remain compatibility wrappers that construct the default
policy with a caller-supplied step limit, but reject a limit above the shared
`ES_RUNTIME_DEFAULT_MAX_STEPS` ceiling before entering the packed loop
(`WORKTREE`). Full cross-bridge accounting,
wall-clock enforcement, and adverse-resource evidence remain an open P6
qualification item.
`EsBytecode.bytecode_capability_report` exposes the same decision before a run,
along with function, instruction, and global counts. Record this report beside
the execution artifact; counts are descriptive telemetry, while
`direct_supported` and `engine` are the authoritative backend-selection facts.
`EsBytecode.make_bytecode_artifact` provides the typed pairing for that record:
it stores the canonical module fingerprint, all four canonical SHA-256 digest
words, source revision, backend tag, and capability report together.
`bytecode_artifact_matches_module` first validates the payload's dispatch/layout
and reconstructed IR, then compares its canonical fingerprint and all four
digest words with the source module before checking capability counts/decision.
This prevents a changed instruction from being admitted merely because it kept
the same counts and source-revision string. Legacy migration uses the same
payload gate. `canonical_bytecode_artifact_bytes` emits
version-2 `ESBC` metadata with length-prefixed backend/revision strings, the
module fingerprint, all digest words, and the complete capability snapshot.
Version 1 envelopes are intentionally rejected: cache migration must rewrite
legacy unbound records before admission. `bytecode_artifact_envelope_status`
and `bytecode_artifact_requires_migration` expose that legacy state separately
from malformed current bytes. The reader and writer reject embedded NULs in
the source-revision label before any host-string adapter sees it. The writer
applies the same version,
backend, digest-presence, revision-size, and engine/directness checks as the
reader and returns the empty sentinel for metadata that would not be
cache-admissible. `migrate_bytecode_artifact` upgrades an in-memory legacy
record only after recomputing the digest and matching the stored capability
snapshot against the verified bytecode; stale records return an invalid
sentinel. `bytecode_artifact_fingerprint`
returns zero for that invalid metadata and otherwise hashes the exact envelope
for cache keys or diagnostic correlation; it is intentionally not a substitute
for validating the artifact against the verified module.

`EsArtifactCache` keeps typed admission beside a bounded POSIX adapter. Its
load helpers reject files larger than the 64 KiB envelope before allocation,
require the post-read byte count to equal the size snapshot, and return both
borrowed bytes and a current/migratable/invalid decision. A concurrent shrink
or short host read therefore fails before artifact classification rather than
publishing a truncated cache record. Its
publication helpers write through `FileStream` to a staging path, close the
handle, sync the file descriptor, remove the staging file on a write/sync/close
failure, and publish only with one `rename` edge after `Empty → Staged →
Committed` admission. Restart-before-commit remains non-committed. The pure
`artifact_cache_recovery_action` state machine now tells a host adapter whether
to keep a digest-validated publication, remove stale staging bytes, rebuild a
missing/invalid destination, or do nothing; it never promotes bytes merely
because a destination path exists. Directory fsync, crash recovery, concurrent
writer arbitration, and corruption-repair execution evidence remain open host
qualification work. `ArtifactCacheWriterLease` adds a typed nonzero-owner
admission state machine (`Available → Held → Published/Aborted`) so stale or
competing tokens fail closed before the host adapter mutates a staging path; it
is deliberately not presented as an OS lock. Callers that provide the parent
directory also get a typed `opendir → dirfd → fsync → closedir` durability edge
after the rename; `DirectorySyncFailed` is propagated instead of being
discarded; crash/restart recovery and platform-specific lock semantics
remain open. POSIX hosts may additionally use `ArtifactCacheWriterLock`, which
opens a bounded append-only lock stream and acquires `flock(LOCK_EX|LOCK_NB)`;
the portable lease remains the source-level fallback and lock-file lifecycle
cleanup is still host-qualified. The `_locked` publication wrappers hold that
lock across staging, file sync, rename, and optional parent-directory sync, and
release it on both success and publication failure; a successful release failure
is reported as a typed lock error while the original publication error remains
the failure reported after best-effort cleanup. The lock itself uses an explicit
`Available → Held → Released` transition table, including reacquisition from
`Released`; invalid events leave the state unchanged.
All borrowed cache paths now pass a private bounded 4 KiB terminator admission
before file-size reads, staging, rename, directory sync, or advisory lock
operations; an unterminated path returns `ArtifactCacheIoError.PathTooLong`
(or the typed read failure at the load boundary) before any POSIX helper scans
it. Publication also rejects equal staging/destination paths and lock-path
aliases with `ArtifactCacheIoError.PathCollision`, preventing a caller from
truncating the destination or overwriting the lock file before the atomic
rename edge.

`EsRuntime::FileStream` is the first typed large-file vertical slice. A handle
is opened with an explicit read/text/binary/write/append mode and a byte budget
bounded by the shared runtime memory ceiling. Its encoding policy is explicit:
`Auto` selects strict UTF-8 for text modes and byte-preserving reads/writes for
binary modes, `Utf8` validates incrementally across chunk boundaries, and
`Bytes` preserves arbitrary byte sequences. Invalid UTF-8 is a typed error at
the stream boundary, including an incomplete sequence at EOF or sync.
The IR fixture records the continuation bounds for split three- and four-byte
sequences so chunk boundaries cannot silently reset decoder state.
`file_stream_read_chunk` and
`file_stream_write_chunk` admit each request with ordered over-budget and
subtraction-before-addition checks, return typed progress records, and reject
closed handles, wrong directions, and budget overflow. A write state machine
retries positive short `fwrite`
progress from the advanced buffer offset; zero or over-counted host progress,
or a positive count accompanied by the stdio error indicator, is a typed write
failure, so a partial write cannot be reported as complete or spin forever.
`file_stream_read_line_mode` makes newline policy explicit:
`Lf` keeps CR as data, `Universal` treats LF, CRLF, and lone CR as delimiters,
and `Retain` includes delimiter bytes in the record. Its state machine uses a
one-byte pending slot to avoid losing the byte after a lone CR, checks the byte
budget before every host `fread`, rejects exhaustion without an extra EOF probe,
and rejects a record before its destination grows past the caller's maximum.
If a universal/retained record read consumes a non-delimiter lookahead, the
next chunk read publishes that pending byte before probing the host again, so
switching between record and byte APIs cannot drop data or bypass the shared
budget.
Chunk and byte reads also reject a positive `fread` count accompanied by the
stdio error indicator, preserving the typed read failure instead of publishing
partially poisoned stream data. EOF validation consults the decoder state even
when a pending lookahead byte was already published into the chunk, so an
incomplete multi-byte sequence cannot bypass the typed `InvalidUtf8` error.
`file_stream_read_line` remains the bounded LF-only compatibility spelling.
`file_stream_tell` reports the logical position before an unpublished
lookahead, and `file_stream_seek` exposes explicit begin/current/end origins;
current-origin seeks rewind that lookahead before applying the requested
offset, while all successful seeks clear the pending slot. A seek on a UTF-8
write/append stream is rejected while an incomplete code point remains, since
discarding that decoder state after output has been emitted would make an
invalid prefix appear valid to later writes or close; read seeks may establish
a new decoder boundary.
`file_stream_sync` is write/append-only and flushes the libc stream before
calling descriptor `fsync`; flush and descriptor failures remain distinct
typed errors.
`file_stream_publish_staged` provides the generic atomic publication edge for a
caller-created sibling staging file and can sync the destination parent after
rename; it rejects equal staging and destination paths with the typed
`FileStreamError.PathCollision` row before crossing the host rename boundary,
reports rename and directory-sync failures separately, and leaves staging
cleanup policy with the caller. It is intentionally path-based and has no
descriptor-identity or retained-parent-descriptor contract; W04 publication
must use the descriptor-aware `EsLuaBundlePublication` seam and a matching host
adapter instead of treating this helper as proof of secure staging.
`file_stream_close` is idempotent only for a self-consistent terminal state:
`Closed` must carry a null handle, while an `Open` stream must carry a live
handle. Split-brain handles assembled outside the adapter fail with the typed
`FileStreamError.CleanupStateInvalid` row rather than being silently accepted.
For a valid open handle, close transitions the stream to `Closed` before
reporting a host close failure, and prevents use-after-close through the typed
`FileStreamError.Closed` row. The path is borrowed for the handle lifetime and
the opaque POSIX value is owned by the stream module. The host-facing `cstr`
path is admitted by a private bounded 4 KiB non-empty terminator scan before
`fopen`; an empty or unterminated path returns `FileStreamError.PathTooLong`
without crossing the libc boundary. `FileStreamCleanupGuard`
is an explicit one-shot token: a successful commit closes the stream and marks
the guard closed, while abort closes it and marks the guard aborted; repeated or
cross-state cleanup fails with a typed error. Compiler-enforced lexical drop and
platform-independent adapters remain open qualification work.
`decode_bytecode_artifact` first applies that allocation-free validation and then
returns a borrowed, typed metadata record without copying its strings;
all length-delimited metadata readers use the public
`runtime_bounded_slice_end` admission helper. It checks `start <= bound` and
`length <= bound - start` before writing the end offset, so a malformed u64
length cannot wrap a target `usize` or expose a partially validated borrowed
view. Fixed-width artifact readers likewise check `offset <= bytes.count` before
subtracting their eight-byte window. `scripts/check_serialization_bounds.sh` audits this shared invariant,
the bytecode reader, verifier range checks, and its boundary fixture without
launching the compiler.
`bytecode_artifact_bytes_valid` is the allocation-free cache-boundary check: it
rejects records above the 64 KiB envelope ceiling, then requires the exact
magic/version, backend tag, a bounded 4 KiB source-revision
field, the four non-zero digest words, and other bounded length-prefixed fields,
known engine ordinal, consistent direct/fallback flag, all capability counters,
capability counters representable by the host `usize`, and no trailing bytes.
`bytecode_artifact_metadata_valid` performs the same
cross-field checks on a decoded record, including nonzero module identity, while
`bytecode_artifact_matches_module` independently validates dispatch/layout and
the reconstructed IR, binds the payload identity to the source module, and only
then compares the recomputed capability report before execution.

`EsBytecode.execute_bytecode_direct_only` is the strict evidence entrypoint. It
performs the same dispatch-table and IR verification, then rejects any module
outside `bytecode_direct_supported` with `InterpretError.UnsupportedInstruction`
instead of falling back. Differential and backend conformance tests should use
this mode when they need to prove that the packed bytecode engine itself ran;
the ordinary `execute_bytecode` API remains the compatibility path that may use
the verified interpreter for unsupported features.

The direct subset supports initialized and defaulted scalar module globals and
flat literal arrays/maps whose elements, keys, and values are supported scalar
types. Direct integers include signed and unsigned 8-, 16-, 32-, and 64-bit
types, while direct floating-point values are f64. It supports typed
loads/stores shared across nested calls. Nested
aggregate global types remain invalid at IR verification; valid global
initializers outside the direct scalar type/width set use the verified
interpreter fallback, and strict direct-only execution rejects them. Aggregate
payloads use the runtime storage value ceiling, and both execution engines
reject modules with more than
`ES_RUNTIME_DEFAULT_MAX_STORAGE_VALUES` globals before materializing the
per-run global arena.

## Algebraic effects

`Perform` is an IR operation, not an early rewrite to a runtime function call. It
names an effect family and operation separately, carries typed operands/result,
and must be covered by the enclosing function's effect row. A backend may lower
it to an interpreter dispatch, VM opcode, continuation operation, or optimized
native handler only after semantic optimizations are complete.

Elisa's `signal Family.Operation` and `signal Family.Operation(payload, ...)`
syntax lower directly to `Perform`; payload expressions are evaluated once in
source order and become its typed operand slice.
Source `effect Family:` declarations register their first-level operation names
and payload arities in parser metadata. Duplicate operation names within one family
are rejected because the runtime identity is the `(family, operation)` pair; overloads
are not part of the initial ABI. Semantic analysis uses that registry to
reject unknown operations and payload-count mismatches for both `signal` and
value-producing `perform` requests in user-declared families;
builtin and permission-only families keep their host-defined operation sets.
The source reference must contain exactly one non-empty `Family.Operation`
separator. Bare families and multi-dot names are rejected during lowering rather
than being reinterpreted as a synthetic operation, so handler clause lookup and
effect-row coverage cannot silently diverge from the source spelling.
The function effect row may grant the complete operation or its family. Every
operation-bearing instruction also carries a stable FNV-1a `u64` identity derived
from its `(family, operation)` pair. Parser metadata, semantic lookup, handler
clauses, and lowered `Perform`/`Raise`/`Panic`/error-guard instructions share the
same identity rule; the verifier preserves zero as a legacy-fixture escape hatch
but rejects any populated id that disagrees with the readable names. Every perform
also receives a stable source-derived trace identity.
The interpreter now uses the identity when both the performed instruction and a
handler clause provide it, while treating zero as a compatibility wildcard for
older hand-authored modules; raised-error guards apply the same rule. `Resume`
instructions likewise carry a stable resumption token derived from their handler
symbol, and the captured continuation rejects a populated token mismatch.
Canonical IR emission and hashing include both IDs (and handler-clause operation
IDs), so artifact fingerprints cannot silently discard typed dispatch metadata.

Value-producing effect requests use the compiler-known
`perform("Family.Operation", payload)` intrinsic in an expected-type position,
for example `return perform("Process.Run", command)`. The lowerer requires a
string-literal `Family.Operation` reference, uses the surrounding destination
type as the resumed result type, and emits a result-bearing `Perform` with the
optional typed payload. The referenced operation is added to the function's
effect row unless an active dynamic handler covers its family; malformed or
untyped uses are lowering diagnostics rather than implicit dynamic values.

## Differential testing

`Perform` and `Observe` require stable, nonzero trace-site ids. These ids are
frontend identities and therefore remain comparable across bytecode, JIT, AOT,
Wasm, reference, and candidate executions even when their machine instruction
layouts differ. Trace labels are descriptive only; identity does not depend on
text or source formatting.

`observe(value)` is a compiler-known, value-consuming intrinsic that lowers to
`Observe` without defining a result. It provides a typed, backend-independent
checkpoint for differential tests without depending on stdout or debug logging.
The interpreter and direct-bytecode engine share a one-million-event observation
budget and raise `InterpretError.OutputLimit` before appending beyond it, so a
tight trace loop cannot turn caller-owned evidence storage into an unbounded
allocation.

The differential adapter copies runtime arrays into its owned comparison pool
only after validating their half-open ranges with checked subtraction. Its
comparator applies the same fail-closed rule to externally assembled snapshots,
so a wrapped `u32` offset can produce a structured mismatch but can never become
an unchecked host index.

`assert(condition)` lowers to `Assert` with one boolean operand, a void result,
and the containing function's `AssertionError` error row entry. The reference
interpreter and direct bytecode path both evaluate the operand once, continue on
`true`, and raise the typed assertion failure on `false`; no result sentinel or
implicit truthiness conversion is involved. Because assertion failure is a
recoverable runtime error, verified error guards may transfer to their fallback
block and clear the failure before resuming normal state-machine execution.
Void-producing operations can use the statement form `try operation() else void`
(or another void fallback); the guard and fallback merge without a value parameter.
Terminating recovery also accepts a void operation, for example `try assert(x) else
return`, when the recovery clause ends control flow.

Source `raise Error.Tag` (or `raise Error.Tag(payload, ...)`) lowers to a void
`Raise` instruction whose
`effect_family` and `effect_operation` fields preserve the declared error
identity. The lowerer requires the declared family in the function's `error[...]`
row and rejects unknown family/tag pairs; the verifier repeats the row check for
hand-built IR.
`Raise` is recoverable by the same error guards as built-in failures, while an
uncaught raise is reported as `InterpretError.Raised`. Catch expressions may use an
explicit `Family.Tag` arm; the lowerer records that identity on the guard and the
reference interpreter recovers only a matching explicit raise. Positional fields
must match the declared payload arity and lower to typed `ErrorPayload` instructions
for bindings (wildcards discard the corresponding value). Wildcard and `error`
arms remain catch-all for built-in failures and any raised variant. A raised
constructor may carry zero or more ordered SSA operands; the reference interpreter
snapshots those runtime values in its failure channel while unwinding. Variant
arms may terminate their fallback block after normal return-type checking.

`panic([message])` lowers to a void `Panic` instruction with `Abort.Panic` effect
metadata and zero or one evaluated operand. Unlike `Raise`, `Panic` is not an
error-set variant and is deliberately excluded from error-guard recovery; an
uncaught panic reports `InterpretError.Panic` on both the reference interpreter
and direct bytecode path.

F-strings are parser sugar for the compiler-owned `__fstr` call. Lowering accepts
text, `char`, any integer width, `f32`/`f64`, `bool`, text-backed nominal, array, and
dictionary expressions, converting non-text pieces with the existing
`FormatChar`/`FormatInt`/`FormatFloat`/`FormatBool`/`FormatNominal`/`FormatAggregate`
operations before emitting a left-to-right chain of ordinary `Concat`
instructions; literal chunks remain `Constant` values. `FormatAggregate` uses
an explicit stack to render nested arrays and dictionaries in stable bracketed
form with a 64 MiB output bound. This
keeps interpolation visible in the verified IR and gives the interpreter,
bytecode, JIT, and native backends one ownership and evaluation-order contract.

## Dynamic handlers

Elisascript uses lexically scoped, dynamically selected handlers:

```elisa
with handler sandbox:
    run_build()
```

The IR declares each handler's covered effect families, introduced effects,
`error[...]` sets, and continuation policy (`Terminal`, `Linear`, `Affine`,
`MultiReplay`, or `MultiClone`). The policy is a closed enum: the verifier
rejects unknown ordinals and the runtime fails closed if one reaches dispatch.
`HandlerPush` and `HandlerPop` delimit dynamic
installation. `Resume` names the handler whose continuation it consumes and
requires one payload operand plus a typed result; the verifier rejects terminal
handlers, malformed payload/result pairs, unknown handlers, and unbalanced
handler operations.
Handler installation and removal are control-only operations: they must carry
no operand slice, no SSA result id, and a `Void` result type. This keeps a
malformed handler instruction from manufacturing a value that the runtime
stack operation would silently discard.
Executable handler clauses map an exact effect family and operation to an ordinary
typed IR function. At each covered `Perform`, verification matches the performed
payload to that function's parameters and its return type to the resumed value.
The callback is an ordinary call boundary for capability accounting as well: every
callback effect must be covered by an active operation-aware handler or the enclosing
function's effect row, and every callback `error[...]` entry must appear in the
enclosing function's error row. A clause cannot smuggle undeclared effects or errors
past the handler's static contract. Source `@handler` decorators materialize those
callback rows into the derived handler descriptor before `with handler` lowering;
the ordinary `introduces_effects`/`errors` propagation path therefore applies to
source and host-supplied descriptors alike.
Clause families must belong to the handler coverage set, callback symbols must
exist, coverage entries must be non-empty and unique, and duplicate operation
clauses are rejected. Terminal handlers cannot use
this resuming clause form; nonterminal policies select whether the captured frame
is consumed once (`Linear`/`Affine`) or remains available for repeated callback-local
resumptions (`MultiReplay`/`MultiClone`).
Replay-safe effect metadata is also a set: entries cannot be empty or duplicated.
Continuation-capture metadata is also checked before execution: names must be
non-empty and unique, capture types cannot be `Void`, and the capture class must
be one of the six declared ownership classes. Unknown enum ordinals are rejected
as handler-contract issues rather than being treated as replay-safe by default.
Multi-shot captures whose declared type is an array or map are rejected as
`UnsafeMultiShot` at verification time until deep aggregate storage cloning is
available. Verification checks both the six-level legacy inline descriptor
chain and, when present, the capture's interned TypeTable identity; the bounded
child graph rejects nested array/map descendants as well, and unknown or
malformed child links fail closed. The runtime keeps a matching fail-closed
check for legacy hand-built descriptors. The IR regression fixtures cover both
inline and interned nominal roots that hide an array, with the malformed table
case requiring both the unsafe multi-shot and invalid-table diagnostics.
TypeTable interning proves the existing child pool count before subtracting the
new descriptor width, so oversized generated descriptors cannot wrap their
capacity check.
Malformed metadata is a handler-contract issue rather than permission to replay
an untyped or unknown value.
Coverage is operation-aware: a handler with one or more clauses handles only the
exact `Family.Operation` pairs it declares, so an unmatched operation continues
searching through outer handlers. A handler with an empty clause set is an
intentional family mask and consumes every operation in each listed family.

Source callbacks may spell a typed resumption as `return resume("echo", payload)`.
The lowerer requires a compile-time string-literal handler name, a non-void callback
return type, and an exact payload/return type match, then emits `Opcode.Resume`.
Source files may derive operation clauses with `@handler("name", "Family.Operation"[, "Policy"])`
on ordinary callback functions. The source lowerer aggregates callbacks
with the same handler name, preserves host-supplied descriptors, and leaves payload /
resume typing to the callback signature plus the verifier. Host configuration remains
the escape hatch for captures, introduced effects, and explicit `error[...]` rows.

Handler failures are stored in explicit error-set rows on handlers and functions.
They are not represented as `Result` values and are not merged into effect rows.
Installing a handler subtracts only the exact operation requirements covered at
that program point (or the whole family for an explicit empty-clause mask).
Effects introduced by running the handler and its explicit
`error[...]` sets are propagated into the enclosing function's respective rows.
The verifier checks both sides of this contract independently.
Structured lowering emits explicit handler unwinding before `return`, `break`,
and `continue`. Loop exits unwind only handlers installed inside that loop;
handlers surrounding the loop remain active until their own lexical scope ends.
The canonical source boundary exposes this same configuration through
`lower_elisascript_source_with_handlers`/`lower_elisascript_file_with_handlers`
and the matching `execute_elisascript_*_with_handlers` entry points. The default
loader and launcher pass an empty handler table, while hosts that need dynamic
effect interception can provide the verified handler descriptors explicitly.

Multi-shot behavior is never inferred. The reference interpreter executes a
callback's `Resume` as a typed tail resumption for `Linear` and `Affine`: its
payload becomes the value of the suspended `Perform`, the callback frame stops
immediately, and the continuation frame is consumed exactly once. A missing,
already-consumed, or terminal continuation raises `InterpretError.InvalidContinuation`.
`MultiReplay` and `MultiClone` now retain their captured frame while the callback is
active, so each `Resume` re-enters the suspended function at the instruction after
`Perform`, with a fresh copy of its SSA environment and dynamic-handler stack. Each
payload therefore observes the same post-`Perform` computation independently; the
enclosing `Perform` receives the callback's final return value. The frame records the
resumption count and stores its flat snapshot in machine-owned pools. Both
`MultiClone` and `MultiReplay` require every declared captured value to be
classified `Unrestricted`; affine, linear, borrowed, region-bound, and opaque
captures are rejected until an explicit replay/clone protocol proves their
safety. `MultiReplay` also requires every effect introduced by the handler to appear in
its statically verified replay-safe effect set. The snapshot now includes the
active direct-call chain, so a handled effect in a helper replays the helper's
post-`Perform` suffix and each caller's post-call suffix in order. A future
increment can replace this flat replay chain with a general suspended-stack
object for non-call control transfers.
The runtime rejects a continuation before its `u32` resumption counter would
wrap or before its 100,000-resumption policy budget is exceeded, reporting
`InterpretError.InvalidContinuation` rather than silently reusing a wrapped
count. Snapshot ids, values, handler names, and replay frames
also use bounded machine pools (one million copied values and 100,000 frames).
Each replay frame records independent starts and counts for the id and value
pools; the counts must agree, and each slice checks its start bound before the
subtraction-based count bound and before indexing. Cleanup likewise truncates the two pools to their independent
saved starts. Malformed continuation metadata therefore fails closed with
`InvalidContinuation` rather than exposing an out-of-range read or retaining a
suffix from an unrelated pool.
A dynamic handler that exceeds those limits fails with `InvalidContinuation`
without retaining a partial snapshot; completed callbacks reclaim their private
replay suffixes.
Until deep storage cloning is available, the interpreter also rejects
`MultiReplay` and `MultiClone` snapshots containing mutable array or map views.
This prevents copied `RuntimeValue` descriptors from aliasing caller-owned flat
storage across resumptions; the rejection is `InterpretError.InvalidContinuation`.

The IR verifier rejects missing/duplicate trace sites, ungranted effects,
undefined or duplicate SSA values, bad entry blocks, unknown branch targets, and
malformed terminators before a backend runs. It also validates SSA dominance, so
a value created in one branch cannot be consumed from its sibling branch. Every backend must consume only a
verified module, preventing backend-specific recovery from becoming an observable
semantic difference.

Core operation types are verified rather than delegated to a runtime engine.
Copies preserve their exact type; arithmetic requires identical numeric operands
and a matching result; remainder is integer-only; equality and ordering produce
booleans over their supported operand families. Direct calls must name a declared
function and match its parameter and return types exactly. There are no implicit
integer-width or integer/float conversions at the IR boundary.
Explicit integer suffixes (`u8`, `u16`, `u32`, `u64`, `usize`, `i8`, `i16`,
`i32`, `i64`, and `isize`) lower to their exact signedness and bit width. The
suffix is stored per AST literal rather than inferred from line metadata, so two
differently suffixed literals on the same line cannot exchange types. `char` and
`u8` are distinct IR families: characters participate in text operations, while
`u8` is an unsigned numeric type. Unsuffixed integer literals remain `i64`, and
no implicit widening occurs in arithmetic or comparisons. Narrow explicit literals
must fit their suffix range. Signed minimum spellings are lowered atomically—such
as `-128i8`—so the compiler never has to construct the invalid intermediate
positive literal `128i8`; negating an explicitly unsigned literal is rejected.
The reference interpreter applies checked fixed-width semantics to narrow integer
addition, subtraction, multiplication, division results, left shifts, and signed
negation. A result outside its declared type raises `InterpretError.IntegerOverflow`
through Elisa's `error[...]` channel. Unsigned complement masks unused host bits, so
`~1u8` is `254u8` rather than the host `i64` value `-2`. These checks happen before
the host operation wherever the host intermediate could overflow.
Compiler-known typed literals use `Named` constants with immutable text payloads;
runtime `sview` adaptation uses explicit `MakePath`, `MakeGlob`, `MakeRegex`, and
`MakeUrl` constructors (with `MakeExecutable` for the existing executable adapter).
The verifier admits both representations, and the interpreter retains the text
payload while all static compatibility decisions continue to use the nominal IR
type.
Text and nominal constants pass through the shared literal escape decoder before
runtime materialization. This keeps ordinary and adjacent triple-quoted literals
consistent across the reference interpreter and bytecode backends: standard Elisa
escapes decode, while unknown or malformed escapes remain source bytes. Triple-
quoted payloads can contain newlines; bare triple quotes are still lexed as block
comments.
`TextPartition` has signature `Text × Text -> Array[Text]`. Its two text operands
are the haystack and separator; `Instruction.integer` mode 0 selects the first
separator and mode 1 the last. The result always contains exactly three fields
(before, separator, after), using an empty separator field when no occurrence
exists. Both global and receiver partition spellings lower to this verified
operation.
`RegexSearch` is a separate semantic opcode with the exact signature
`Text × Named(Regex) -> Bool`. The reference interpreter executes it through an
explicit search machine with greedy backtracking; future bytecode, JIT, and native
lowerings therefore share the operation contract without inheriting a host
language's regex behavior. Character ranges and Perl-style shorthand classes have
fixed ASCII definitions rather than platform locale semantics. Zero-width word
boundaries (`\b`/`\B`) detect ASCII word/non-word transitions, and bounded
repetitions (`{m}`, `{m,n}`, `{m,}`) use decimal, non-decreasing limits. Top-level
alternation is split only at unescaped pipes outside character classes, and each
branch runs through the same bounded matcher states. Parenthesized groups are
matched recursively, including nested alternation and quantifiers. Character
classes accept a leading `]` (after an optional `^`) as a literal member.
Perl-style named group markers (`(?<name>...)`) are accepted for matching; replacement
captures use their positional `$1` through `$9` references, plus `${name}` and
`$<name>` when a flat group has one unique name.
`RegexReplace` has signature `Text × Named(Regex) × Text -> Text`. It reuses the
same branch matcher to locate non-overlapping spans, copies unmatched and replacement
bytes into fresh storage, expands `$0` to each complete matched span, and advances
after zero-width matches so an empty pattern cannot loop forever. `$1` through `$9`
also expand when the pattern contains a flat sequence of non-quantified or `?`-optional capture groups
whose spans can be proven against the complete match (for example,
`([a-z]+)=([0-9]+)`). Nested, repeated/braced, or top-level-alternating capture layouts
remain literal rather than guessing a branch; this conservative fallback keeps
replacement behavior deterministic until recursive regex match values are defined.
The replacement language also accepts AWK/sed's `&` whole-match token, Perl/Python
whole-match spellings `\0` and `\g<0>`, positional `\1` through `\9` and
numeric `\g<1>` through `\g<9>` aliases for `$1` through `$9`, and named
`\g<name>` aliases for `${name}`/`$<name>`. Perl's
`$$` literal-dollar token and `\&` literal-ampersand token remain available; each
token is consumed atomically and unknown forms remain literal. Named references
with unknown or duplicate names are also kept literal rather than selecting an
ambiguous capture.
`regex_quote_replacement` is the explicit literal-replacement helper: it
escapes backslashes, dollar references, and AWK/sed ampersands before the
replacement scanner sees them. A doubled backslash is consumed as one literal
backslash, so quoted user text cannot accidentally become `$1`, `&`, `\1`, or
`\&`; the helper applies the same 64 MiB replacement ceiling as substitution.
`RegexSplit` has signature `Text × Named(Regex) -> Array[Text]`. It uses those same
spans as field boundaries, preserves empty fields, and applies an explicit one-byte
advance for zero-width matches. The result is materialized in caller-owned flat
storage, so indexing, iteration, and structural equality remain ordinary verified
array operations.
`RegexFind` has the same operands and returns an `Array[Text]` containing each
non-overlapping matched span. Zero-width matches advance explicitly, matching the
termination rule used by `RegexSplit` and `RegexReplace`.
If matcher work is exhausted after earlier spans were found, both operations roll
the shared storage cursor back before raising `OutputLimit`, so failed regex
materialization is failure-atomic.
The implementations collect spans locally and preflight the exact result count
before publishing, avoiding text-length over-admission when few matches exist.

`EsRecord::RecordStreamPolicy` and `EsRecord::Record` provide the typed boundary
for Perl/AWK-style record processing. Separator mode is explicit (`Line`,
`Literal`, `Regex`, or `Paragraph`), as is field extraction (`Whole`,
`Whitespace`, `Literal`, `Regex`, `FixedWidth`, or `Schema`). Literal/regex
separators must be present only in their selected modes; fixed-width policies
require nonzero widths whose sum remains within both the policy's
`max_record_bytes` ceiling and the shared 64 MiB text envelope, then continue
through the shared schema/separator checks; schema policies require
a nonempty schema name. Every record carries source,
optional filename, global/file-local numbers, byte offset, raw bytes, and the
separator actually consumed when `preserve_separator` is enabled.
`validate_record_stream_policy`, `validate_record`,
and `validate_record_field` validate both the shared policy and parent-record
metadata, then reject embedded NULs, oversized text, zero metadata
numbers, out-of-range field slices, non-empty payloads on absent fields, and
inconsistent field payloads through
`error[RecordContractError]` before a scanner, regex walk, or aggregation buffer
is allocated. This is a reusable contract; record I/O, external sort, and
transactional in-place rewriting remain host adapters.
`EsRecordFieldScan::split_record_fields` supplies bounded byte-span scanning
for `Whole`, collapsed ASCII-whitespace, literal separators that preserve
empty fields, and fixed-width columns. Empty non-whole records produce no
fields; short fixed-width records carry explicit absent trailing columns, and
bytes beyond the declared widths are rejected. Regex mode has a companion
`split_record_fields_from_regex_spans` entry point that consumes validated,
complete delimiter byte spans in matcher order, preserves empty fields, and
follows the matcher’s zero-width forward-progress rule. Regex matching itself
and schema extraction remain adapter responsibilities; the ordinary scanner
rejects those modes instead of silently guessing.
Its output can be submitted in field-index order to
`EsRecordMaterialize::RecordMaterializer`, which retains the validated spans
under its record/field/text ceilings. `select_record_field` exposes AWK-style
`$0` as the raw record and positive one-based field numbers as validated
selections; out-of-range fields return an explicit absent/empty selection,
while inconsistent field indexes and requests above the policy ceiling fail.

`EsRecordNumeric::RecordNumericSession` supplies bounded lexical numeric
admission for extracted fields. Signed and unsigned integers use a checked
`magnitude` accumulator with the signed-minimum boundary represented without
wrapping; decimal fields retain coefficient/fraction digit counts and a
bounded signed exponent for a later exact-decimal or floating adapter. Signs,
underscores, decimal points, exponent markers, and finish conditions are
state-machine validated with up to 20 exponent digits, including rejection of underscores immediately before
decimal points, with explicit empty/trailing-separator, overflow,
digit, exponent, cancellation, and invalid-character errors. Validation also
reconciles digit/byte counters, decimal flags, phase/flag coherence, and
integer magnitude bounds.
Decimal lexemes accept both leading-point forms such as `.5` and trailing-point
forms such as `1.`; an exponent may follow a trailing point (`1.e2`) when the
coefficient already contains a digit. The session stores and validates an
explicit trailing-point candidate, so it cannot be confused with a malformed
trailing separator. A bare point and a trailing underscore remain invalid.
Rejected bytes and overflow attempts are failure-atomic: character, digit,
and magnitude accounting is published only after the byte passes its phase
checks. Exponent lead/sign/digit phases are cross-checked against exponent
digit accounting, rejecting snapshots that claim exponent digits without any.
No implicit float conversion occurs at the record boundary.
`parse_record_numeric` applies that state machine to a complete borrowed field
view under the caller's explicit byte/digit/underscore policy. Optional
`trim_ascii_whitespace` removes only ASCII space, tab, LF, VT, FF, and CR from
the field ends; the input byte ceiling is charged before trimming. It does not
apply locale coercion.
Integer `RecordNumericResult` values can be materialized through checked
`record_numeric_result_i64` and `record_numeric_result_u64` accessors. Signed
conversion handles the minimum value without negating an unrepresentable
positive intermediate and rejects values outside the selected type.

`EsRecordMaterialize::RecordMaterializer` adds the bounded stream-adapter
boundary without embedding a regex engine or file descriptor. A producer opens
one `Record`, appends zero or more validated `RecordField` values in index order,
closes that record after enforcing the record ceiling, and repeats until `Seal`;
an empty input may seal directly from the planned state. `Fail` and `Cancel` are
explicit terminal alternatives. The materializer retains borrowed record/field spans,
checks contiguous record-to-field ownership, counts record/field/text budgets
with subtraction-safe admission (including start-before-count range checks), and
rejects all transitions after sealing or
cancellation through `error[RecordMaterializerError]`. Validation also rejects
forged planned/empty collecting state, stale inactive borrowed records/cursors,
and sealing without a completed record. Closing a record and the Fail/Cancel
rollback edges clear the inactive borrowed record and field cursor; Fail and
Cancel also roll back any open record's borrowed fields and text accounting
before entering their terminal state.
This makes Perl/AWK-style
`$0`/field streams deterministic for later adapters while leaving byte input,
regex scanning, external sort, and transactional rewrite effects outside the
typed core.

`EsRecordSort::RecordSortSession` is the deterministic ordering boundary for
external-sort adapters. A policy declares one or more unique field positions,
text or signed-integer key kinds, direction, missing-key placement, and stable
tie behavior. Entries carry validated records, typed keys, and a monotonic
ordinal; missing keys carry no hidden text/integer payload, text keys carry no
hidden integer payload, and integer keys carry no hidden text, while the session
admits entries only from a clean `Planned → Collecting → Sealed` lifecycle with
bounded record and key-text accounting. `compare_record_sort_entries` provides
the same lexicographic order for in-memory sorting and disk-run merging, while
`error[RecordSortError]` rejects duplicate key positions, malformed key kinds,
ordinal gaps, duplicate keys under `unique`, over-budget text, and post-terminal
transitions. Disk runs,
atomic spill files, and merge I/O remain host responsibilities.
`EsRecordSortFields::record_sort_key_from_field` validates each selected field
against its owning record/policy, retains text views as text keys, and routes
integer keys through bounded lexical parsing plus checked `i64` conversion;
absent fields become explicit missing keys, while malformed integers fail
before a key is published. `record_sort_entry_from_fields` validates the sort
policy once, requires one field per declared key in spec order, and builds the
complete key vector in private scratch storage before returning an entry.
`record_sort_order_indices` is the bounded in-memory path: after `Seal`, it
returns a stable bottom-up merge ordering of entry indices, using two index
vectors rather than copying record payloads. Its comparisons reuse the
validated key comparator; unsealed sessions are rejected.

`EsRecordRewrite::RecordRewriteSession` is the safe in-place transformation
boundary for Perl `-pi`, sed-like, and record/regex rewrite adapters. A plan
allows source and destination to be the same for an in-place rewrite, but
requires a distinct sibling staging path and an optional non-colliding backup,
a closed symlink policy (`Reject`, `FollowSource`, or
`ReplaceLink`), and a bounded output ceiling. The
session admits `Begin → Append* → Sync → DirectorySync? → Commit → CommitAck`, with explicit
failure, cancellation, and `BeginRollback → RollbackAck` recovery edges; an
empty staged output is valid, but commit is impossible before the sync edge.
Each append proves the existing output total before subtracting remaining output
capacity, so malformed session accounting cannot underflow admission.
Validation also rejects imported phase flags that claim a staging or commit
acknowledgement before its corresponding state transition, including a
`Committing` snapshot that omits required directory synchronization.
It also rejects rollback acknowledgements in non-rollback states and committed
snapshots that omit staging synchronization, so terminal records cannot be
forged by mixing flags from different lifecycle phases. Directory synchronization
and commit acknowledgement are also globally subordinate to staged synchronization,
and a required directory sync is mandatory before any acknowledged commit.
The typed contract performs no rename or fsync itself, leaving platform error
mapping, permissions, crash recovery, and multi-file traversal to host code.

`EsRecordLifecycle::RecordLifecycleSession` defines the hook order around a
stream and its files: `Begin`, `FileBegin`, `RecordBegin`, `RecordEnd`,
`FileEnd`, and `End`, with typed failure and cancellation exits. It counts files
and records, checks the record ceiling before `RecordEnd`, rejects records outside a file, prevents closing a file with an
open record, reconciles open-file counters, and can require every file to contain
at least one record. The validator also reconciles the current-file name and per-file record count with
the open-file state, and requires imported `Planned` sessions to have pristine
counters and ownership fields. The state machine is deliberately callback-neutral so a host can dispatch typed
begin/per-file/per-record/end functions without weakening ordering or early
exit cleanup. Validation also rejects record/file counter asymmetry when no
file has ever been opened and requires the per-file counter to be zero after
`FileEnd`, failure, or cancellation.

`EsRecordAggregate::RecordAggregateSession` provides a bounded associative
count operation for AWK/Perl-style keyed aggregation. Keys retain insertion
order, duplicate keys increment their count without changing that order, and
planned sessions must be empty before `Begin`; new groups plus aggregate key
bytes are admitted against explicit inclusive ceilings, so a key exactly
`max_key_bytes` bytes long is valid and the next byte is rejected.
`AddValue` adds a bounded signed integer value to the same stable group, with an
explicit per-session sum ceiling; `record_aggregate_group_count` and
`record_aggregate_group_sum` are available only after `Seal`. Malformed keys,
duplicate internal groups, event/group/sum overflow, and terminal mutation
return `error[RecordAggregateError]`. Signed sums, averages, joins, and
spill-to-disk aggregation remain separate policies rather than implicit numeric
conversions. Validation derives the event total and rejects duplicate first
ordinals, so externally assembled groups cannot forge aggregate cardinality.
Open-addressed lookup and rehash placement stop after 64 probes and fail with
`IndexProbeLimitExceeded`; this bounds collision-heavy work but may reject an
otherwise valid input whose keys form a longer probe chain. The FNV index is
not collision-resistant, and throughput remains unmeasured. New-group insertion
preflights an empty slot before appending the group, so a malformed full index
cannot leave group, event, and key-byte accounting partially updated.
`EsRecordNumericAggregate::record_aggregate_add_numeric_field` parses a field
view under an explicit numeric policy, then bridges its checked integer result
into `AddValue`. `record_aggregate_add_numeric_record_field` first validates a
materialized field against its owning record and stream policy, rejects absent
fields explicitly, then uses the same numeric bridge. Invalid spans, absent
fields, malformed numbers, or sum-limit failures do not change the aggregate;
decimal/floating coercion remains explicit and unavailable here.
`record_aggregate_add_numeric_record_fields` validates a key field and a
numeric value field from one record before applying one keyed `AddValue`, so
AWK-style `sum[$1] += $2` does not need to reconstruct either field as text.

`EsRecordFields::RecordFieldEditSession` is the bounded mutation boundary for
AWK `$N` updates and Perl-style record rewrites. A policy fixes the maximum
field/edit counts, output bytes, output separator, trailing-separator behavior,
and whether assigning at the next index may append a field. `Set` preserves
field positions; an edit with `present: false` clears a field to the empty
value instead of silently changing `NF`. `record_field_edit_reconstruct_length`
performs subtraction-safe output accounting before allocation, and
`record_field_reconstruct` joins only a `Ready` session; `Ready` output bytes
must match the reconstructed field length. The state machine
rejects pre-begin edits/output, post-terminal mutation, invalid indices, malformed/NUL-bearing text,
and output overflows through `error[RecordFieldEditError]`; host adapters own
the borrowed field storage and any subsequent file publication.

`EsRecordFieldEditAdapter::record_field_edit_session_from_fields` bridges this
state machine to `EsRecordFieldScan` for whole-record, ASCII-whitespace, and
literal-separator modes. It compares the caller's fields with a fresh bounded
scan before opening an edit session, rejecting omitted, reordered, or altered
fields as `RecordFieldScanError.FieldSetMismatch` rather than reconstructing a
partial record. After that admission, the private transfer copies validated
field views without rescanning the entire record for every field. Regex spans
need an explicit matcher-to-adapter contract;
`record_field_edit_session_from_regex_spans` accepts ordered spans from a
bounded regex matcher and lets the scanner validate progress and produce the
canonical field list. Scanning uses the stricter of the stream and edit field
ceilings, so malformed/overlapping spans or field-count overflow fail before
an oversized field list is accumulated. Fixed-width padding and schema
serializers are not inferred, so those modes currently return `UnsupportedMode`.
`record_field_reconstruct_record` joins
the edited fields with the edit policy's field separator and then appends either
the consumed record separator (`preserve_separator`) or the record policy's
output separator, both retained in the adapter session created from that
record. Reconstruction cannot accidentally pair one edit session with a
different record argument. It calculates the exact content length and checks the
separator against `max_record_bytes` before allocating reconstructed content.
Focused adapter fixtures and the compiler-free audit are source-level evidence
only; runtime validation remains withheld under the active compiler-process
safety hold.

`EsRecordWindow::RecordWindowSession` supplies a bounded rolling numeric
window for streaming actions. It retains an event history capped by
`max_events`, tracks an active suffix capped by `width`, stages eviction and
checks the prospective sum before admitting a new value, and maintains a
subtraction-safe unsigned sum under an explicit ceiling. `record_window_count` and `record_window_sum`
are available while collecting or after sealing; invalid terminal transitions,
forged planned-state contents, empty-history drift, out-of-policy values in
retained history, window accounting drift, and event/sum overflow return
`error[RecordWindowError]`. A nonempty retained history must also retain a
nonempty active suffix, so an imported cursor cannot skip every retained value.
Keyed windows and signed/decimal numeric policies
remain explicit extensions rather than implicit conversions.

`EsRecordJoin::RecordJoinSession` is the deterministic keyed-join boundary.
Rows carry a side-local ordinal plus borrowed key/value views; planned sessions
must be empty before `Begin`, and admission caps row, key, and value bytes before
mutation. `Inner`, `Left`, `Right`, and `Full`
policies are explicit. After `Seal`, `record_join_pair_count` counts duplicate
key Cartesian matches and adds one pair for each unmatched outer row where
requested, all under a pair ceiling. It sorts a bounded scratch array of row
indexes by key with a stable merge sort, then counts each key group once, so
counting performs O(n log n) key comparisons rather than comparing every row
pair. Common-prefix byte work can repeat across comparisons and remains
workload-sensitive. `Add` revalidates the complete row/ordinal/byte ledger
before mutation because callers can construct or alter public session values;
this preserves rejection-before-mutation for forged ledgers, though collection
validation remains quadratic in the number of appended rows. An opaque session
API is needed before safely removing that cost. The row-index scratch is bounded
by the session's row limit. Empty keys, NUL
keys/values, broken ordinals, overflow-safe accounting drift checks, and
post-terminal mutation return `error[RecordJoinError]`; materializing the
paired rows and external sort/merge remain host responsibilities.

`EsFileMetadata::FileMetadataSnapshot` is the typed stat/lstat-shaped metadata
boundary. Entries retain stable ordinals and reject duplicate paths while
admitting regular, directory, symlink, other, or explicitly allowed missing
objects. Missing entries carry zero size and no inode/device/link identity.
Permission bits, size, inode/device/link identity, and timestamps are
bounded fields; symlink targets are required only when `preserve_symlink` is
enabled and the entry is a symlink. Path, target, and aggregate-byte ceilings
are checked before publication, and `file_metadata_lookup` is sealed-only.
Planned snapshots must remain empty and zero-accounted until `Begin`.
`error[FileMetadataError]` covers malformed paths, NULs, identity/mode/size
violations, missing/symlink policy, duplicate entries, accounting drift, and
terminal misuse. Embedded NULs in entry paths and symlink targets are reported
distinctly before ordinary path/target-shape errors; native stat/lstat, chmod,
hardlink, and race-safe traversal remain host responsibilities.

`EsFileLock::FileLockTable` is the portable advisory-lock ownership boundary.
Requests name a bounded path, nonzero owner token, and explicit `Shared` or
`Exclusive` mode; only shared holders of the same path may coexist, and a
single owner cannot implicitly re-enter a path. `Begin`, `Acquire`, `Retry`,
`Timeout`, `Cancel`/`CancelAck`, `Release`/`ReleaseAck`, and `Fail` are explicit
state-machine edges. Nonblocking conflicts return `error[FileLockError.Conflict]`;
bounded waits return `WouldBlock` until a finite attempt budget is exhausted,
then become `TimedOut`; timeout is admitted only after at least one acquisition
attempt. Each conflict exposes one retry permit, which is consumed before the
next acquisition attempt so a caller cannot spin retries without progress. A
held lease remains active through `Releasing` until
the host acknowledges release, while failures decrement active accounting and
retain a failed lease record. Held, releasing, and released sessions also
require a consumed acquisition attempt. Embedded NULs in lease and request
paths are classified as `FileLockError.EmbeddedNul` before ordinary path errors.
Lease allocation rejects the terminal `u64` identity before publishing a lease,
so the next-identity counter cannot
wrap to zero or leave a partially committed table. The contract remains
advisory-only. `EsFileLockPosix` now supplies a descriptor-relative,
nonblocking adapter: it pins the parent directory and private single-link lock
inode, revalidates the no-follow name, and confirms the shared or exclusive
`flock` before a lease is relied on or released. Persistent lock names are
never unlinked, avoiding split-lock races. The portable model still owns
bounded retry/timeout policy; fairness, mandatory-locking semantics, and
behavior on other platforms remain host limitations. Generic atomic-file POSIX
mutations now require this lease capability at each operation boundary; its
runtime behavior remains unverified.

`EsFileAtomic::AtomicFileSession` is the stronger publication boundary for
generated files, cache entries, and build outputs. A plan binds a nonzero
owner token and parent identity to distinct destination, sibling staging, and
optional backup paths, and requires an observed expected destination identity.
`EsFileAtomicPosix::observe_atomic_file_at` now supplies a bounded
descriptor-relative destination snapshot: it returns device/inode metadata for
the parent descriptor and either an observed absence or a regular-file
identity backed by SHA-256 of a no-follow, stable read. The caller must retain
and revalidate that parent capability and destination receipt under its
mutation policy. `atomic_file_bytes_equal_at` separately compares a bounded
destination read to caller-owned bytes byte-for-byte for an unchanged-content
fast path; the SHA-256 identity is not treated as proof of exact content
equality.
`capture_atomic_file_stage_proof` verifies that an open staging descriptor
matches its no-follow sibling entry, is a private single-link regular file,
and shares the parent directory's filesystem; `revalidate_atomic_file_stage_proof`
repeats those checks before a later mutation. These receipts are identity
snapshots, not locks. Mutating entrypoints also require a live exclusive
directory-lease capability. `begin_atomic_file_stage`
captures the proof and retains the parent/stage device, inode, descriptor, and
owner identities in the session before `Begin`; later POSIX append, cleanup,
compare, and commit operations reject a proof or sealed identity that does not
match the admitted stage. Every mutating entrypoint rejects a lock leaf that
aliases the staging, destination, or configured backup leaf, so publication or
cleanup cannot replace the persistent lock inode being used for coordination.
`create_atomic_file_stage` creates the exclusive
private sibling, admits its proof, and returns the descriptor to the caller.
Create failures preserve host
`errno`; `EINTR`/`EIO` are outcome-unknown rather than safe retry signals. If
post-create admission fails, it makes one close attempt, preserves the
unproven path for recovery, and returns `StageAdmissionUncertain` with the
path, descriptor, and close status rather than unlinking an unverified name.
`append_atomic_file_stage` accepts the handle directly, checks the retained
admission, writes with bounded short-write/EINTR handling, revalidates the
stage, and advances the model's append count only after a complete write.
Partial/uncertain writes move the model to `FailedPendingCleanup`; the handle
remains open for cleanup. `seal_atomic_file_stage` consumes the mutable handle
after live proof revalidation, records its descriptor as consumed after one
close attempt, then obtains a stable post-close identity/digest receipt and
advances `StageReady`. `cleanup_unsealed_atomic_file_stage` similarly closes
and consumes the handle only after cleanup is acknowledged; on preflight or
cleanup failure the caller retains it. Both close failures are reported with
their status, stored in the handle, and are never retried.
`compare_atomic_file_stage` binds caller bytes to the sealed stage by digest
and exact readback, takes stable
destination identity snapshots around an exact byte comparison, and advances
`Compare`; its API requires the POSIX exclusive directory-lease capability and
revalidates it before recording the comparison. Identity-only reads rewind
their temporary arena storage so repeated comparisons do not retain one
full-file allocation per snapshot.
`commit_atomic_file_stage` recaptures the stage and destination, transitions to
`Committing`, performs one same-directory `renameat`, syncs the parent when
required, and acknowledges only after observing the staged inode at the
destination with private mode and a single link. Rename failures and all post-rename proof/sync failures transition
to `PublishedUncertain`; callers must observe/recover and must not blindly
retry the rename. The adapter requires and revalidates the exclusive directory
lease immediately before rename and after publication-sensitive operations.
If the lease is lost after entering `Committing`, it preserves
`PublishedUncertain` for recovery. `cleanup_atomic_file_stage` removes a closed,
sealed staging entry only after matching its no-follow identity to the session
receipt and requiring private single-link file metadata. After revalidating
the exclusive directory-lease capability, an already-absent stage is reconciled as
completed cleanup; unlink or post-unlink verification failures leave cleanup
pending. When `require_directory_sync` is set, both cleanup paths sync the
parent directory before acknowledging removal; if that sync fails after
unlink, the session remains pending and a retry can sync the already-absent
entry. This sealed-stage path does not cover partial or unsealed stages that
have no sealed identity receipt; `PublishedUncertain` destinations must go
through publication reconciliation instead of cleanup.
`cleanup_unsealed_atomic_file_stage` covers the partial-write failure path: it
uses the captured device/inode proof plus private, single-link metadata to
remove the stage entry without treating incomplete bytes as a sealed receipt.
It also confirms that the caller's still-open descriptor and the no-follow
stage entry identify the same inode; the stage handle is consumed and closed
only after cleanup has been acknowledged. If sealing consumed the descriptor
before receipt creation failed, cleanup instead requires the retained
admission proof, repeated no-follow inode checks, and the same live lease; it
never claims an open descriptor remains. Both cleanup APIs require and
revalidate the caller's exclusive directory lease. The descriptor-relative
incremental artifact-cache writer now consumes this generic publisher; other
generated-file/build-output callers, cross-platform adapters, and runtime
parity remain open.
Unchanged cache content preserves the destination inode, but the generic flow
still creates and seals a stage before comparison. An unresolved publication
preserves its candidate and returns an unknown-outcome error; the cache wrapper
does not persist the session receipt for recovery after returning or crashing.
`Begin` and bounded
`Append` edges build the staging result; `StageReady` requires a host-supplied
size/digest/object-identity receipt after staging sync and close, including a
valid digest for empty output.
`Compare` captures the destination identity before mutation and requires an
explicit host byte-for-byte equality receipt before entering
`UnchangedPendingCleanup → Unchanged` (no rename, preserving destination
metadata); otherwise it acknowledges that a commit is needed. A changed
destination against the expected identity fails closed before the receipt is
stored. The remaining `Commit → DirectorySync → CommitAck` edges are explicit,
and `CommitAck` requires a post-publication identity whose content matches the
staged result. A
`PublishedUncertain` state represents any post-rename result that the host
cannot prove. `reconcile_atomic_file_publication` now has two fail-closed
resolutions under the live exclusive lease: the staged inode at the destination
with its stage name absent (then directory sync and `ResolvePublished`), or the
original destination unchanged while the exact staged inode remains at its
stage name (`ResolveNotPublished`, returning the session to `Ready`). Mixed,
foreign, or unstable observations remain uncertain, and stage cleanup cannot
erase an unresolved publication candidate. `BeginRestore → RestoreAck` reaches `RolledBack` only when
the host first observes a destination identity matching the pre-commit
snapshot or a known staged/published identity. That observed source identity is
retained as the restore precondition; the host adapter must refuse a
compare-and-restore operation if the destination changes before mutation.
`RestoreAck` then requires the restored destination identity to exactly match
the pre-commit snapshot, and cleanup must be acknowledged. `Fail` and `Cancel` first enter
cleanup-pending states, and an ambiguous publication cannot be mistaken for
an ordinary failure. `error[AtomicFileError]` covers path/NUL/owner/receipt limits,
duplicate synchronization, destination races, unproven restoration, missing
cleanup, and every invalid transition. The model does not perform I/O,
locking, hashing, rename, or cleanup; those remain host-adapter duties.

`EsRecordSpill::RecordSpillSession` is the external-sort staging boundary.
Runs receive stable ordinals and distinct sibling paths, append only within
per-run and aggregate record/byte ceilings, and must cross `SealRun` into
`Ready` before `BeginMerge`; a new run from `Ready` re-enters `Spilling`.
Merge runs are consumed in ordinal order; `Commit` is accepted
only after every sealed run has been merged. Destination/staging collisions,
duplicate run paths, active-run misuse, forged lifecycle state, accounting drift,
impossible inactive-run cursors, and cancellation or failure transitions are typed through
`error[RecordSpillError]`. `Merging` and `Sealed` states require at least one
sealed run, matching the only transition that can enter either state; the host owns
sorting, temporary-file creation, fsync/rename, cleanup, and crash recovery.

`EsDirectoryTree::DirectoryTreeSession` makes recursive filesystem traversal
policy explicit. A walk caps depth, entries, retained identities, and bytes;
each visited path has a nonzero identity and a depth matching the active
parent scope; an active parent depth cannot exceed the number of admitted
entries, and duplicate identities fail closed as cycle/alias protection.
Planned snapshots are empty,
`DoNotFollow` and `FollowDirectories` symlink policies plus fail-fast/collect
behavior are enforced at `Descend`, including admission of symlinked
directories only under `FollowDirectories`; regular-file symlinks remain leaves
because traversal has no target-resolution edge. These failures are
typed, and `Descend`/`Leave` maintain an explicit depth stack. Cancellation and
completion require a balanced walk; fail-fast failures inside a nested scope
remain in `Walking` until matching `Leave` edges unwind to depth zero, then
become `Failed`, while further visits are rejected. Failure counts are bounded
before each failure edge, and embedded NULs are classified as
`DirectoryTreeError.EmbeddedNul` before ordinary malformed-path errors;
non-directories, denied symlink descent, limits, and identity/byte accounting
failures use `error[DirectoryTreeError]`.

`EsDirectoryMutation::DirectoryMutationSession` is the bounded recursive
copy/remove planning boundary. Every admitted entry carries source and (for
copy) destination paths, an identity, depth, byte count, and an explicit
`Planned`/`Applied`/`Skipped`/`Failed` outcome. `Preserve`, `Follow`, `Skip`,
and `Reject` symlink policies, fail-fast versus collected failures, identity
cycle/alias rejection, depth/entry/byte/failure ceilings, balanced
`Enter`/`Leave` scopes, source-equal or descendant copy-destination rejection,
duplicate copy destinations, clean planned state, and
cancellation are all checked before host mutation. A fail-fast failure inside
an `Enter` scope remains `Executing` while matching `Leave` edges unwind; it
becomes `Failed` only at depth zero and rejects further planning or completion.
Aggregate byte admission proves the accumulated total before subtracting each
entry's remaining capacity, so malformed plans fail closed without underflow.
The identity vector is reconciled positionally with admitted entries so
externally assembled plans cannot forge ownership accounting.
`Complete` and `Cancelled` states retain no active scope or pending entry; a
collected failure is retained in the completed report rather than silently
converted into success. The host owns mkdir/copy/unlink/rmdir calls, canonical
source/destination checks, permissions, race handling, and rollback. Embedded
NULs in session and entry source/destination paths are classified as
`DirectoryMutationError.EmbeddedNul` before ordinary path or destination
errors, including during `Plan` admission.

`EsWorkingDirectory::WorkingDirectoryTable` serializes process-global cwd
ownership for adapters that cannot use a descriptor or child-specific cwd.
Each invocation records an original path and owner token; `Begin` admits one
active context, `Change`/`ChangeAck` makes host movement explicit and bounded,
and `Restore`/`RestoreAck` must return to the original path before the lease is
released. A second active owner is rejected, changing/restoring operations
cannot be cancelled mid-flight, and failed contexts remain recorded as failed
rather than silently releasing an unknown cwd. Allocation rejects the terminal
`u64` lease identity before publishing a context, preserving monotonic IDs
without a zero-wrap or partial table mutation. Hosts should prefer descriptor
or child-cwd APIs where available; this contract is the conservative fallback
for unavoidable process-global changes. Lease validation also ties pending-path
presence and restored-path equality to the corresponding lease state.
Embedded NULs in request, lease initial/current/pending, and change paths are
classified as `WorkingDirectoryError.EmbeddedNul` before ordinary path errors.

`EsRegexCallback::RegexCallbackSession` is the callback-aware replacement
boundary. The matcher submits non-overlapping spans and capture counts; the
session accounts bounded input, unmatched prefixes, callback replacement bytes,
the exact matcher-supplied byte span skipped after a zero-width match, and the
final suffix under one output ceiling. Global versus single replacement is explicit,
and capture budgets must be nonzero,
zero-width matches must advance (including the EOF non-progress guard), and a
callback cannot be re-entered while a replacement is pending. Match/capture/
output limits, spans that rewind before the consumed cursor, malformed spans,
cancellation, and premature end use
`error[RegexCallbackError]`; validation also rejects forged planned counters and
impossible pre-match cursor/ledger state, pending callbacks outside matching,
and a complete session must have consumed the entire input cursor. A pending
match also retains the output count before its unmatched prefix; validation
rejects forged pending spans whose prefix bytes were omitted or over-counted.
Callback invocation and capture materialization remain host/interpreter work.

`EsJsonStream::JsonStreamSession` is the JSON/JSONL framing layer before value
materialization. It bounds total input, per-record bytes, record count, and
bracket depth while tracking a typed delimiter stack, quoted strings, and
escapes. `JsonStreamPolicy.record_boundary` selects top-level boundaries in
the compatibility `BalancedContainers` mode or physical LF boundaries in
`PhysicalLines` mode; the strict mode rejects line breaks inside a string or
unclosed container. Exact record-byte boundaries are accepted, and final partial records
are accepted at `End`, while empty records are rejected unless the policy opts
in, and unterminated strings/values,
underflow, invalid stack contents, forged ready/complete state, and cancellation
are explicit typed errors. Rejected byte events are atomic: input and record
counters advance only after depth, delimiter, and record-limit admission passes;
complete state also reconciles input bytes with the
number of admitted records. A full parser consumes
one sealed record at a time, so this contract does not claim JSON semantic
validation or whole-document allocation. `EsJsonLinesParse` supplies the next
boundary: it borrows the source view, drives framing through each delimiter,
then runs `EsJsonLex` and `EsJsonParse` for the completed record before
returning its document. Its single reader carries `EsData::DataDecoder`
counters across records, records absolute source offsets, and becomes terminal
on malformed JSON or cumulative-budget failure. Empty records admitted by the
framing policy are counted and skipped; the parser also treats whitespace-only
frames as empty under that policy, including CRLF-only frames. The default
`BalancedContainers` mode treats newlines inside balanced containers as
whitespace within one record; callers can select `PhysicalLines` when they
need strict JSON Lines framing. The parser-level chunk feed and POSIX
`FileStream` adapter preserve this same policy; execution evidence remains
open.

`EsRecordControl::RecordControlSession` makes AWK-style control keywords
explicit: `RecordEnd` and `NextRecord` check the record ceiling before closing the current record,
then `NextRecord` advances to the next one,
`NextFile` accounts for and closes an open record before closing the file scope, and `Exit` terminates cleanly from
any running scope. The bounded state machine rejects calls outside an open file,
double-open records, impossible open-file counters, file closure with a live
record, and post-terminal events;
validation also reconciles skipped/file scope ownership, record/file counters,
and planned counters.
Failure and cancellation clear ownership state so a host callback cannot leave a
half-open traversal.

`EsRecordPattern::RecordPatternSession` owns bounded pattern/action selection and
inclusive record ranges. Clauses have typed predicates (`Always`, numeric
metadata, text equality/containment, or host-supplied `External`) and an
explicit `Select`/`Skip` action. The host supplies one observation per clause,
while the state machine opens a range on its start match, includes its end
match, closes it deterministically, and records one bounded decision per input
record; selection is the OR of all matching clauses for that record. Its policy
carries the source `RecordStreamPolicy` explicitly, so separator preservation
and the record byte ceiling are not replaced by a silent default during
observation validation. Predicate text at exactly the configured text ceiling
is admitted consistently with the record byte ceiling. Validation reconciles decision cardinality/selection counters and
running/terminal clause-state shape, and requires strictly increasing global
record numbers in the retained decisions. Shape mismatches, duplicate or
out-of-order records, unterminated ranges,
malformed predicates, text limits, cancellation, and terminal transitions use
`error[RecordPatternError]`; regex compilation and callback dispatch remain
separate adapters.

`EsNetwork::NetworkRequest` and `NetworkResponse` define a transport-neutral
HTTP/TLS boundary. Requests carry an explicit method, URL, ordered header pairs,
binary body, positive timeout, response ceiling, and redirect policy; responses
carry a closed outcome (`Success`, DNS/TLS/transport failure, timeout, protocol,
status, decode, or cancellation), status, headers, body, and bounded error text.
`validate_network_request` and `validate_network_response` reject malformed or
duplicate (ASCII case-insensitive) headers, non-token field names, control bytes in values, embedded NULs, oversized URL/header/body payloads, zero
timeouts, invalid response ceilings, and status/outcome contradictions through
`error[NetworkContractError]`. `NetworkRetryPolicy` makes retry intent explicit:
`Never` permits one attempt, `IdempotentOnly` permits bounded retries only for
GET/HEAD/PUT/DELETE, and `Explicit` is required for mutation retries. Every
multi-attempt policy carries nonzero bounded backoff ceilings; TLS roots, socket
ownership, total deadlines, and streaming/cancellation adapters remain explicit
host responsibilities. `network_retry_backoff_micros` derives the delay for a
one-based attempt with zero delay for the initial dispatch, checked doubling,
and saturation at the configured ceiling, so hosts do not reimplement retry
arithmetic with overflow-prone defaults.
`NetworkRequestJob` supplies the corresponding lifecycle state machine:
`Planned → Resolving → Connecting → Securing → Sending → Receiving → Completed`,
with explicit `Failed`, `Cancelling`, `Cancelled`, and bounded `Retry` edges.
Attempt accounting is part of that state machine: active/terminal attempt states
require a consumed attempt, planned retries must retain budget, and exhausted or
over-counted jobs are rejected before a transition. Adapters cannot acknowledge
cancellation or reuse a failed attempt without the matching state transition.
`NetworkTlsPolicy` makes trust selection explicit: system roots are the default,
custom bundles require a bounded path, and `InsecureTestOnly` is a visibly named
escape hatch rather than an implicit verification downgrade. Certificate and
private-key paths must be supplied together, and all TLS paths/server-name text
reject embedded NULs and oversized values before a host TLS library is called.
`NetworkStream` and `NetworkChunk` provide bounded request/response streaming
with sequence numbers, explicit pause/resume backpressure, final-chunk and
drain requirements, and cancellation/failure states. Stream state and sequence
accounting reject forged terminal completion before any adapter is called, and
cancelled streams must discard buffered bytes and final-chunk state;
enqueueing cannot exceed
the configured in-flight ceiling or occur after a final chunk; a stream cannot
finish until the final chunk has been observed and all buffered bytes consumed;
cancellation clears buffered bytes and final-chunk state before both the
`Cancelling` and `Cancelled` states are exposed.

EsNetworkSession binds those policies to one transport attempt. It requires
the DNS/connect/TLS/send/receive order, charges request and response bytes
before advancing, caps polls and redirects, requires explicit redirect opt-in,
and models each redirect as an
explicit `Receiving → Resolving` edge that validates a 3xx status and clears
transient request/response accounting before the next resolution. It preserves
status failures as typed completed outcomes, and exposes retry/failure/cancellation edges without
opening sockets itself. Planned/retry states clear transient I/O fields,
completed states require a real status, and failure/cancellation outcomes must
match their states; `StatusFailure` failures require a non-2xx/3xx HTTP status,
while other failures retain neutral status. A failure edge cannot carry the distinct `Cancelled`
outcome; cancellation must use the explicit cancellation state machine.
Completed sessions also require the full request body to be accounted for, and
cancellation states cannot retain an HTTP status; every post-planned state must
also account for at least one consumed attempt.
Active transport phases also retain the neutral success/zero-status pair until
the explicit receive-completion or failure edge.

`EsProcessBatch::ProcessBatchSession` supplies the bounded fan-out/fan-in layer
for process maps. Jobs have unique IDs, pending/running/awaiting-reap/retryable/
terminal states, bounded attempts, and explicit launch/complete/fail/reap/retry
edges; launch rechecks the selected pending job's attempt ceiling before
mutation. Every launch publishes a nonzero attempt token, and complete/fail/
reap receipts must echo the current token, so a delayed receipt from an older
retry cannot mutate a newer process. A failed job must receive `ReapAck` before
it becomes retryable or terminal. A policy caps total jobs and active parallelism and selects fail-fast versus
aggregate failure. Planned cancellation marks all pending jobs cancelled,
`Succeeded` requires every job completed, and `Cancelled` cannot retain
unfinished jobs. `Cancel → CancelAck` marks every still-owned slot cancelled;
fail-fast exhaustion enters `Draining`, cancels queued work, and waits for
active siblings to finish (whether they complete or fail) before reaching `Failed`; a `Failed` snapshot likewise
requires every job to be terminal and cannot retain active or queued work.
Failures below the attempt ceiling remain `Retryable` under `FailFast` after
`ReapAck`; only an exhausted attempt or a previously latched drain enters
terminal failure.
`Running` and `Cancelling` snapshots must still retain unfinished work, so a
forged already-terminal snapshot cannot be relabelled as cancelled by
`CancelAck`;
the contract never starts a child or sends a signal. Non-pending execution
states also require a consumed attempt, so a retry/failure record cannot be
forged before its first launch. Duplicate IDs, stale job indices, retry
exhaustion, no-pending launches, counter drift, and post-terminal events return
`error[ProcessBatchError]`.
Aggregate success/failure counters are reconciled with subtraction-based
bounds, so forged maximum-width counters cannot wrap their admission checks.
Once fail-fast has latched a real failure, `Cancel → CancelAck` drains the
remaining siblings but still terminates as `Failed`; cancellation cannot mask
the failed child. If cancellation arrives before that child’s reap receipt,
`CancelAck` records the child as a failed terminal outcome before cancelling
the siblings. The latch is valid only under the `FailFast` policy; an imported
aggregate batch cannot smuggle itself into fail-fast draining.

`EsTestRunner` builds the test/CI layer over these process and output
contracts. `TestSpec` binds a stable nonzero ID and unique name to one
validated `ProcessCommand`; discovery and selection are separate states, so
unselected cases become explicit skipped records with a bounded reason rather
than disappearing. Each selected launch consumes a one-based attempt token,
and a completion receipt must echo that token. Process outcomes are classified
as pass, flaky pass, failure, crash, timeout, cancellation, or error; retry
policy and attempt ceilings are explicit, and a failed attempt becomes
`Retryable` without being counted terminal until the host sends `Retry` and
launches again. An exhausted or non-retryable failure, including an unexpected
process cancellation, latches failure, cancels queued work, and drains live
children through explicit `Draining`/`Cancelling` states. A requested
cancellation yields `Cancelled` only when no failure is latched, so `Failed`
wins if both events occur. Only after every case is terminal can
`BeginReport → SealReport` construct a bounded, ordered `OutputDocument` for
Human/JSON/JUnit renderers. A pass after one or more failed attempts retains a
typed `Flaky` status in the output record instead of being flattened to an
ordinary pass; it remains a successful suite outcome while staying visible to
machine consumers. The runner never
spawns or writes files itself, so host adapters remain responsible for
discovery, process launch/reap, and report transport; the source fixture and
`check_test_runner.sh` audit are static evidence only. A process adapter's
`error_text` is promoted into the test message when no explicit message is
provided (and conflicting non-empty values are rejected), so host diagnostics
cannot vanish from the sealed report. Per-channel diagnostic text is capped at
1 MiB while the runner's retained aggregate remains capped at 64 MiB. Running
and successful terminal snapshots also reject nonzero failed, crashed, timed
out, cancelled, or error counters unless the corresponding failure/cancellation
state is exposed, preventing forged failures from being reported as success.
The intermediate `Reporting` state applies the same latch consistency before
`SealReport`, so a forged failed report cannot be sealed and returned as
`Complete`.

`EsScriptTest` supplies the in-process `@test` boundary used by the CLI's
`ExecuteTests` workflow step. Discovery is ordered and bounded to 4,096 cases;
each case carries a nonempty NUL-free name, source line, and planned state.
`Begin → CaseBegin → CasePass/CaseFail` executes one verified zero-argument test
at a time, keeps the passed prefix and active case cursor explicit, and retains
the first failure's case/name/line/message for deterministic diagnostics. A
run with no discovered cases is rejected instead of becoming a false green.
`Cancel → CancelAck` marks every unfinished case cancelled and reaches a
terminal state only after the active cursor is cleared. Duplicate names,
forged case states, skipped/out-of-order callbacks, hidden counters, and
malformed cancellation snapshots are rejected by `error[ScriptTestError]`.
The module is a pure state machine: discovery, function invocation, fresh
per-case storage, timeout/resource policy, and report rendering remain host or
runner adapters. The focused IR fixture and `check_script_test.sh` audit are
static evidence only while compiler/test execution is held.

`LowerResult.test_functions` is the first discovery side channel for that
contract. The lowerer scans only direct top-level `Decl.Func` nodes, preserves
source order, records the function name and definition line, and admits only
parameter-free void functions carrying `@test`. It shares the 4,096-case
ceiling and reports a bounded lowering issue rather than silently dropping
additional cases. The metadata intentionally stays outside `Module` and
serialized bytecode; source/file loader wrappers and the runner will copy it
only while the source region remains alive.

Source/file loader wrappers preserve the compact `Module` APIs while exposing
this catalog through caller-owned `darray[ElisascriptTestFunction]` storage.
The diagnostic-and-tests core clears the destination before validation and
publishes metadata only after lowering and IR verification succeed, so every
failure leaves an empty catalog. Buffer and file loaders borrow names from
their retained source region; length-delimited byte loaders copy input into
the loader context's permanent region before returning views. The wrappers do
not invoke tests or alter serialized IR identity.

The runner's file, NUL-terminated source-buffer, and length-delimited
source-byte discovery adapters bind their loader catalogs to `EsScriptTest` in
source order without requiring `main`; each resets the caller's session before
loading, so a failed reload cannot leak a prior catalog, and leaves a validated
session in `Planned` so cancellation or execution policy remains an explicit
caller transition. Source-buffer discovery borrows both source and filename
bytes; source-byte discovery copies the source payload but still borrows the
filename during the returned module's lifetime. Report names and failure/skip
messages borrow the same session/source backing storage and must be rendered
or copied before that storage is released. `execute_elisascript_test` accepts only a planned,
bounded descriptor whose bytecode function is zero-argument and `void`, clears
observations/storage for a fresh case, and invokes the named entry through the
shared policy-aware bytecode facade. Unknown names and signature drift are
typed `ScriptTestError`s, while runtime failures remain `InterpretError`s; the
helper does not infer success from a non-void value.

`execute_elisascript_file_tests` is the bounded multi-case adapter. It lowers
the verified module once, prevalidates every discovered function, and drives
`Begin → CaseBegin → CasePass/CaseFail` in source order through a state-machine
cursor. Each case receives fresh observation/storage arrays and a remaining
`RuntimeResourcePolicy`, so step/output/regex and other accounted dimensions
cannot reset at a suite boundary. The returned `ElisascriptTestRun` retains
only bounded scalar summaries for successful completed cases; suite usage sums
consumptive dimensions and takes the maximum of reported active/retained
dimensions. Live resources are still enforced during each invocation, but the
current `Execution` contract does not expose historical in-case peaks. The
suite case-count ceiling is checked before charging usage from the next
completed case, so a rejected over-limit case cannot partially advance the
aggregate ledger.
Borrowed runtime values are never retained. A runtime `InterpretError` becomes
the first typed case failure while the error enum is preserved beside the
session diagnostic. The boolean cancellation request is a synchronous
boundary snapshot: it cancels before the first case when true and is checked
only between cases, with `Cancel → CancelAck` leaving every unstarted case
`Cancelled`. File, NUL-terminated source-buffer, and length-delimited
source-byte adapters all call the same machine; each has dynamic-handler and
no-handler entry points, so source-buffer differential runs cannot silently
use a different policy or failure path. Driver `--test` routing and
compiler/runtime qualification remain open. The private run validator checks
that successful summaries match the passed prefix, scalar counters stay within
shared ceilings, and rejects a runtime-error latch on a non-failed state. A
runner-produced runtime failure still sets the latch on `Failed`, while a
host/static failed session may legitimately carry no `InterpretError` enum.
`build_elisascript_test_report` projects a terminal run into a temporary
shared `OutputDocument` and publishes it only after `Begin → Append* → Seal`
validation succeeds. Passing cases are
`Pass`, the first runtime failure is `Fail`, and trailing planned or cancelled
cases are explicit `Skip` records using the canonical messages `runner stopped
after test failure` and `cancelled before launch`; a report cannot be built from a planned,
running, or cancellation-in-flight session.

Before any regex opcode executes, both backends enforce a shared input-size
boundary: haystack text is at most 64 MiB, the compiled-pattern payload is at
most 64 KiB, and replacement text is at most 64 MiB. Oversized operands fail
with `InterpretError.OutputLimit` before the matcher, scanner, or replacement
builder can allocate or recurse. Each complete operation shares a 100-million
state matcher budget across all scanner positions, recursive backtracking, and
capture probes; exhaustion reports the same typed limit instead of resetting for
the next candidate match. These boundaries contain input amplification but do
not make the recursive matcher provably linear. Replacement construction also
rejects output growth beyond 64 MiB before final publication. Every output span
proves `start <= end` and the source bound before subtracting its width, so
malformed matcher metadata cannot underflow a remaining-capacity check.
Pattern delimiter, group, class, and quantifier helper scans charge the same
work budget by their inspected span, and candidate-position scans charge it
again for each search/replacement probe. This keeps helper-only work from
escaping the operation limit.
To contain host-stack use as a separate concern, pattern admission rejects
more than 1,024 nested groups and one repeated atom cannot descend through
more than 8,192 recursive repetition states. These failures use the same
typed `InterpretError.OutputLimit` as the other regex resource guards, and
are checked consistently by the reference and direct-bytecode entrypoints.
Literal, class, dot, and non-boundary escape repetitions take an explicit
greedy/backtracking loop; only compound or zero-width atoms use the guarded
recursive path.

Compiled `Regex` values also expose `search(text)`, `match(text)`, and
`fullmatch(text)`, plus `findall(text)` (with `find_all(text)` as a spelling
alias). `search` is unanchored, `match` anchors at the beginning while
permitting a suffix, and `fullmatch` requires the entire haystack to be
consumed. These receiver forms lower to the same `RegexSearch` contract; its
`Instruction.integer` mode is 0, 1, or 2 respectively. `findall` lowers to
`RegexFind`; no backend-specific regex state is introduced.

`RegexCapture` has the same `Text × Named(Regex)` operands and returns an
`Array[Text]` for the first match. Element zero is the complete matched span;
subsequent elements are proven positional capture groups. If no match exists the
result is empty. A flat group followed by `?` is supported; when it does not
participate, its positional element is an empty text value. Other quantified,
nested, or top-level-alternating capture layouts conservatively return only the
full match, preserving deterministic behavior across the interpreter and
bytecode facade. The receiver `capture_names(text)` uses the same proven layout
and returns positional group names, including empty text for unnamed groups;
unsupported layouts and missing matches return an empty array.

`Regex.count(text)` is a registry-described `RegexFind,Length` composition and
returns the exact `usize` count of non-overlapping matches, including the
single zero-width match at an anchored start and zero for a missing pattern.
The pattern-first global `regex_count(pattern, text)` uses the same composition
and operand ordering as the other `regex_*` facades.

`Regex.capture_named(text, name)` and the pattern-first
`regex_capture_named(pattern, name, text)` use the verified
`RegexCaptureNamed` operation. The operation returns the unique participating
named capture from the first match, or empty text when the name is missing,
ambiguous, or non-participating; both reference and direct-bytecode execution
share the same bounded flat-layout proof.

EsRegex exposes the same limits as a public adapter contract. A
RegexSession identifies search/match/fullmatch/findall/split/replace,
charges helper work and capture groups before publication, bounds replacement
output and match count, enforces the request's single/global match policy,
rejects standalone match events for replacement operations so one replacement
cannot be counted twice,
rejects forged ready-state counters and non-replacement output, and
makes cancellation explicit. The matcher can therefore remain engine-specific
while policy, error variants, and resource accounting stay identical across
interpreter and bytecode paths.
Every `Work` event must charge at least one unit; a zero-cost work transition
is rejected so an adapter cannot spin without consuming the request's work
budget. Other events may report work together with their match or replacement
result and are charged atomically. A non-global request is also limited to one
match in both live transitions and caller-supplied session states.

`Map` is the closed aggregate counterpart to `Array`. Its `Type` descriptor carries
one exact scalar key type and one recursively represented value type within the
inline descriptor limit; `MakeMap` consumes an even key/value
operand sequence and produces the corresponding map. `Index`, `IndexValid`, `Contains`,
`Length`, and `SetIndex` accept maps with typed key/value contracts. Runtime map payloads are
interleaved key/value pairs in caller-owned flat storage and validate their complete
pair range before access. Because view offsets are serialized as `u32`, validation
also rejects a non-empty span whose final addressed element would exceed the
`u32` offset domain, even when the host `usize` can represent the backing storage.
Array and map literal construction also rolls the shared storage cursor back when
frame lookup or global-literal decoding fails, so malformed aggregate inputs do
not publish a partial value before the typed error is raised.
Indexed map updates search for an existing key before choosing the output span:
replacement of a present key only needs the original pair count, while insertion
preflights the possible extra key/value pair and the map-count ceiling before
copying. A full storage pool therefore cannot reject a valid replacement or
partially materialize an insertion before the overflow error is reported.
Map concatenation likewise counts only right-hand keys absent from both the left
map and earlier right-hand entries, so duplicate-heavy merges do not require
capacity for pairs that will be overwritten.
Map removals search before sizing their shortened copy and require only
`count - 1` pairs after a match; absent-key `PopMap`/`DeleteIndex` no-ops do not
need any replacement capacity.
Glob expansion similarly counts sorted unique matches before checking flat-pool
capacity, so duplicate matches from overlapping variants do not over-reserve.
Regex capture materialization sizes the exact proven group/name result after
matcher work completes rather than charging the entire pattern length.
Scalar named-capture lookup returns text directly and does not require shared
array storage admission.
Line splitting also counts its actual fields before checking flat-pool capacity,
so short line results from long inputs are not rejected by an input-length bound.
Missing keys use the existing typed
`IndexOutOfBounds` error rather than a sentinel value. The reference interpreter and
the bytecode facade share this representation. Maps whose key and value types are
Function and backend entrypoints validate aggregate arguments against these same
range predicates before executing or returning them, so malformed externally
assembled views cannot alias a valid flat-pool slice.
Aggregate-producing operations also validate the append span before narrowing the
flat-pool cursor to `u32`: array segments, interleaved map pairs, concatenations,
directory snapshots, and fixed-size tuple-like results all use the shared
`runtime_storage_*_u32_valid` predicates. A host `usize` pool that is already past
the serialized domain, or an append that would cross it, therefore raises the
typed overflow failure before publishing a view; this applies equally to the
reference interpreter and direct bytecode path.
The shared predicates additionally cap caller-owned runtime storage at 1,048,576
values, independently of the much larger serialized offset domain. This prevents
repeated aggregate construction from turning a valid `u32` view space into an
unbounded host allocation; the same cap is enforced while admitting existing
storage and function arguments.
Text split, line-split, and regex result builders collect views locally and
preflight their exact proven field or match count before publishing into the
shared pool. Empty-input split semantics therefore remain explicit without
rejecting a long input merely because its worst-case field count would not fit.
direct scalar/nominal representations, supported arrays, or recursively supported
nested maps use the packed path for construction, lookup, membership, equality,
updates, and key extraction. Other aggregates continue through the verified
interpreter oracle when the direct bytecode subset does not support them. `MapKeys`
materializes a stable array of keys in insertion order, allowing the existing loop
state machine to lower `for key in map` without evaluating the map expression more
than once. A two-binding read-only loop, `for key, value in map`, uses that same
key array and emits a typed `Index(map, key)` for the value binding; the map
expression is still evaluated exactly once and mutable map iteration is not
permitted. Map equality is order-insensitive but bijective: each candidate pair is
consumed at most once, including for malformed externally supplied runtime maps.

The AST-to-IR boundary reports the same mistakes as structured `TypeMismatch`
lowering issues, before a backend sees the module. This covers declared binding
initializers, mutation without type changes, unary and binary operators, boolean
conditions, conditional-expression arm agreement, returns, array indices, and
direct-call arity and parameter types. Function signatures are predeclared, so
forward calls receive the same checks as calls to earlier declarations.

Verifier pool-bound checks use saturated `usize` arithmetic: malformed `u32`/`u16`
slice starts and counts cannot wrap on a narrower host before the bounds issue is
reported. Invalid slices are clamped for diagnostic iteration, so a hostile module
cannot turn validation itself into an out-of-bounds access.
The same rule applies to interned `TypeTable` child ranges before descriptor
deduplication or recursive identity checks inspect a child id. Public child lookup
and inline-shape validation return a neutral failure (`0`/`false`) for malformed
ranges instead of relying on callers to verify first.

Direct calls also preserve algebraic-effect and `error[...]` contracts. Lowering
adds every unhandled callee effect to the caller effect row and propagates callee
error sets independently. The verifier repeats this check from IR alone: a
dynamically active handler may discharge a covered effect family, while errors
must still appear explicitly in the caller's error row.
Fallible value recovery is represented by `ErrorGuardPush`/`ErrorGuardPop`
instructions around the guarded expression. A recoverable interpreter failure
selects the nearest matching guard from innermost to outermost; nonmatching inner
variant guards are discarded before control transfers to the selected fallback
block. Recovery unwinds handlers installed inside that guard and clears the
private failure before the fallback runs. Normal execution
pops the guard and jumps to the same typed merge block, so `try f() else value`
never uses a result wrapper or an eagerly evaluated fallback. Malformed runtime
values and internal control-flow failures remain fatal and cannot be hidden by a
source-level recovery clause.
Terminating recovery (`try f() else return value`, or the corresponding `break`
and `continue` forms) uses the same guard but gives the fallback its own block;
that block must terminate, while success merges the guarded value into the
surrounding state-machine region.
Expression-position `catch f():` uses the same four-state shape (guarded call,
success arm, fallback arm, typed merge). The backend-neutral subset requires a
binding or wildcard success arm and accepts either a final wildcard/`error`
catch-all or an explicit variant guard; variant fields must match the declared
arity and lower to typed `ErrorPayload` instructions. Both arm expressions must
have the guarded call's exact type. `Raise` itself carries ordered payload
operands, and the interpreter preserves those values while unwinding. A single
error arm may instead use `return` and terminate its fallback block after normal
return-type checking, including an explicit variant arm that binds payloads.
When a guarded computation suspends at `perform`, the interpreter snapshots its
active guards with the captured frame and caller chain. A recoverable failure in
the resumed suffix searches those restored guards from the performing frame
outward through suspended callers; fatal failures still bypass recovery.
`PathExists` is the first concrete filesystem opcode. Its verified signature is
`Named(Path) -> Bool`, and verification also requires `File.Read` in the containing
function's effect row. Lowering adds that effect automatically. The interpreter
copies the path into a NUL-terminated Elisa-owned buffer before calling the
self-hosted core file-I/O layer, so a length-delimited `sview` is never passed to
libc as though it were a C string.
The shared terminated-buffer adapter rejects any payload at or above its 64 MiB
host C-string ceiling before adding the terminator or allocating. This applies
to filesystem paths, environment names/values, and process text in addition to
their operation-specific aggregate budgets. C strings returned by libc-backed
operations (`realpath`, `getenv`, and `getcwd`) and numeric formatting are
scanned with the same bounded helper before copying or iteration; an
unterminated or overlong host result becomes the operation's typed failure (or
an empty formatting result) rather than an unbounded `strlen` walk.
`IsFile` has the same verified `Named(Path) -> Bool` shape and `File.Read` effect,
but tests the POSIX mode bits and returns `false` for missing or non-regular entries.
The scripting `is_file(path)` alias and `Path.is_file()` method lower to this opcode.
`PathAccess` also verifies as `Named(Path) -> Bool` with `File.Read`; its compiler-
selected mode is one of POSIX `R_OK`, `W_OK`, or `X_OK`, backing the
`is_readable`, `is_writable`, and `is_executable` predicates without exposing a
dynamic mode integer to source programs.
The corresponding `Path.is_readable()`, `Path.is_writable()`, and
`Path.is_executable()` call spellings lower to the same opcode.
`PathGlob` and `PathRGlob` verify as `Named(Path) × Text -> Array[Text]` with
`Directory.Read` and `DirectoryError`. They join the receiver with a runtime
pattern (`PathRGlob` prefixes `**/`) and delegate to the same bounded,
symlink-safe glob walker as `ExpandGlob`, keeping Python `Path.glob` and
`Path.rglob` deterministic across interpreter and bytecode execution.
The interpreter rejects an empty, NUL-containing, or 4 KiB-and-longer path or
pattern before glob expansion scans it. Each joined directory/entry path is
also capped by the same envelope before allocation, so recursive traversal
cannot retain an oversized host pathname even when a directory entry is
hostile.
`PathIterDir` verifies as `Named(Path) -> Array[Text]` with
`Directory.Read` and `DirectoryError`. It performs one unfiltered direct scan,
includes hidden entries, skips only `.` and `..`, sorts by unsigned byte order,
and returns rooted child paths. It is lowered and executed directly by both the
interpreter and packed bytecode backends without a glob-pattern round trip.
Directory entry-name aggregation proves its existing name-byte total before
subtracting each new entry's length, and glob-brace expansion applies the same
ordering to variant bytes before allocating a variant.
`TouchPath` verifies as `Named(Path) -> Bool` with `File.Write` and `FileIoError`
for the legacy one-operand form, or `Named(Path) × Bool -> Bool` when the
optional `exist_ok` control is present. Its interpreter bridge opens-or-creates
without truncation, then refreshes timestamps through POSIX `utimes`; with
`exist_ok=false`, an already-existing entry is reported as `FileIoError`.
Packed bytecode uses the same helper and defaults the omitted control to `true`.
`ChmodPath` verifies as `Named(Path) × Int(unsigned, 64) -> Bool` with `File.Write`
and `FileIoError`; both execution engines call the POSIX `chmod` boundary directly.
`FileSize` verifies as `Named(Path) -> Int(unsigned, 64)` with `File.Read` and
`FileIoError`, returning the `st_size` field from the same POSIX `stat` bridge.
`FileMode` verifies as `Named(Path) -> Int(unsigned, 64)` with `File.Read` and
`FileIoError`, returning the `st_mode` bits from that bridge. It preserves the
file-kind and permission bits so scripts can inspect a mode before or after a
typed `ChmodPath` operation.
`FileMTime`, `FileATime`, and `FileCTime` each verify as `Named(Path) ->
Int(signed, 64)` with `File.Read` and `FileIoError`. They return the POSIX
`st_mtime`, `st_atime`, and inode-change `st_ctime` seconds from the same
length-safe `stat` bridge; Python `getmtime`, `getatime`, and `getctime` aliases
lower to the corresponding distinct opcode.
`IsSymlink` verifies as `Named(Path) -> Bool` with `File.Read`; it uses POSIX
`lstat` mode bits so the predicate observes the link itself rather than its target.
`ReadLink` verifies as `Named(Path) -> Named(Path)` with `File.Read` and
`FileIoError`; it returns the raw link target through POSIX `readlink` without
following the link. The returned target must fit the same non-empty 4 KiB Path
envelope before it is copied into owned storage. The `readlink` and `read_link`
builtins and path methods use this opcode.
`SymlinkPath` verifies as `Named(Path) × Named(Path) -> Bool` with `File.Write`
and `FileIoError`; its operands are target then link, and execution calls POSIX
`symlink` directly. The `symlink`, `create_symlink`, and `Path.symlink_to`
surfaces lower to this opcode.
`RemoveTree` verifies as `Named(Path) -> Bool` with `File.Write` and
`FileIoError`; `CopyTree` verifies as `Named(Path) × Named(Path) -> Bool` with
`File.Read`, `File.Write`, and `FileIoError`. Both execute bounded recursive
walks in the reference helper, use `lstat` to avoid following symlink entries,
and are eligible for direct bytecode dispatch. `CopyTree` normalizes the source
and destination lexically before mutation and rejects a
source-equal or descendant destination, preventing the recursive walk from
discovering its own output; the depth bound remains defense in depth. Its
canonical overlap preflight decomposes a normalized destination, so a relative
destination with no slash resolves its parent through `.` instead of passing an
empty spelling to `realpath`, and a trailing separator cannot erase the
destination leaf. `dest` and `dest/` therefore share the same pre-mutation
safety check.
`PathJoin`, `PathParent`, `PathName`, `PathExtension`, and `PathStem` are pure typed path-shape operations.
`PathJoin` verifies `Named(Path) × Text -> Named(Path)` and uses the core `Fs.join`
separator/absolute-leaf rules; `PathParent` verifies `Named(Path) -> Named(Path)`;
`PathName`, `PathExtension`, and `PathStem` verify `Named(Path) -> Text`. They do not add filesystem effects and
are eligible for the direct bytecode path. Composition allocates permanent storage
for joined paths, while parent/name preserve safe views into the existing path
payload. The scripting-profile aliases `dirname`, `basename`, `suffix`, and
`stem` lower to these same opcodes and retain source-level shadowing rules. The
`Path` members `parent`, `name`, `suffix`, and `stem`, together with
`joinpath`, `exists`, `is_file`, `is_symlink`, `readlink`, `read_link`, `symlink_to`, and `is_dir` methods, are lowered to the same operations.
`Path.with_name` lowers to one `PathParent` followed by `PathJoin`; `Path.with_suffix`
lowers to `PathParent`, `PathStem`, `Concat`, and `PathJoin`. Both return a nominal
`Path`, take one positional `Text`/`sview` argument, add no effects or errors, and
reuse the existing path operation semantics without a new runtime representation.
`PathIsAbsolute` is likewise pure and verifies `Named(Path) -> Bool`; it checks
only the first byte of the length-delimited path for `/`, adds no effect or error,
and is eligible for direct bytecode execution. The global aliases `is_absolute`
and `isabs`, plus `Path.is_absolute()`, lower to this opcode.
`PathNormalize` is pure and verifies `Named(Path) -> Named(Path)`. It performs
lexical separator, dot, and dot-dot cleanup in the core `Fs.normalize` helper,
without filesystem or working-directory access, and is eligible for direct
bytecode execution. The shared `Fs.normalize` and `Fs.relative` scanners advance
only while a byte remains, so a host-sized view cannot wrap a terminal cursor.
The `path_normalize`, `normalize_path`, and `normpath`
builtins plus `Path.normalize()` lower to this opcode.
`PathAbsolute` verifies `Named(Path) -> Named(Path)` and requires
`Directory.Read` plus `DirectoryError`. It reads the current directory through
the existing directory state machine, joins relative input, and delegates
separator/dot cleanup to `Fs.normalize`; absolute input is normalized without
changing it. The `path_absolute`, `absolute_path`, and `abspath` builtins plus
`Path.absolute()` lower to this direct-bytecode-capable operation.
`PathRelative` verifies `Named(Path) × Named(Path) -> Named(Path)` and performs
the same lexical normalization and component subtraction as `Fs.relative`, with
the target as its first operand and the base as its second. It is pure, does not
consult the filesystem, and is eligible for direct bytecode execution. The
`path_relative`, `relative_path`, and `relpath` builtins plus the scripting
convenience `Path.relative_to()` lower to this operation.
All pure path-shape operations admit their length-delimited inputs through the
same 4 KiB shape envelope before calling `Fs::join`, `Fs::normalize`, or
`Fs::relative`; empty lexical input remains valid for compatibility with
`path_normalize(path"")`. Derived `Path` results must be non-empty and stay
inside that envelope. The reference and direct-bytecode paths share the same
preflight/result checks, so an oversized nominal value cannot force a large
permanent-arena allocation or silently become an empty path sentinel.
`PathReal` verifies `Named(Path) -> Named(Path)` and requires `File.Read` plus
`FileIoError`; it follows symbolic links through the host filesystem and returns
an owned canonical absolute path bounded by the same non-empty 4 KiB Path
envelope. The `path_real`, `realpath`, and `resolve_path`
builtins plus `Path.realpath()`/`Path.resolve()` lower to this operation. It is
eligible for direct bytecode execution and is distinct from the pure lexical
`PathNormalize` operation and the non-following `ReadLink` operation.
`CreateTemporary` verifies `Text -> Named(Path)` with an instruction kind of `0`
(file) or `1` (directory), and requires `File.Write` plus `FileIoError`. The
interpreter calls POSIX `mkstemp`/`mkdtemp` under `/tmp`; `mkstemp`'s descriptor is
closed before returning the permanent generated path. `temp_file`, `mktemp`,
`temp_directory`, `temp_dir`, and `mkdtemp` are lowering aliases, and the
operation remains on the direct bytecode filesystem path.
The interpreter admits the caller prefix by length before scanning for NUL or
`/`; the fixed `/tmp/elisascript-` prefix and six placeholders leave a 4,072-byte
maximum prefix so the complete template, including its terminator, stays inside
the shared 4 KiB path envelope. Oversized prefixes fail through `FileIoError`
without allocating or invoking `mkstemp`/`mkdtemp`.
The shell-size predicate has no dedicated opcode: `is_nonempty`/`file_nonempty`
lower to `FileSize` followed by a typed `Greater` comparison against zero. This
keeps the existing `Named(Path) -> Int(unsigned, 64)` file-size contract while
retaining `File.Read` and `FileIoError` on the enclosing function.
All filesystem text and byte operations reject an empty path or a path containing
an embedded NUL before entering the POSIX boundary. This check also applies to
nominal `Path` values received from host calls or dynamic constructors; it keeps
the length-delimited source representation from being silently truncated by the
C-string adapter.
The reference interpreter admits path operands through a stricter private
4 KiB path envelope before scanning for NUL, allocating a terminator, or calling
`stat`, `fopen`, `rename`, `opendir`, and the other POSIX adapters. Oversized
paths therefore fail through the operation's existing typed file/directory or
process error path without first walking or copying a hostile 64 MiB general
C-string payload. Executable names, arguments, and environment values retain
the broader shared C-string ceiling because they are not POSIX pathname
operands.
`ReadText` extends that contract to whole-file input with verified signature
`Named(Path) -> Text`. Its function must carry both `File.Read` and `FileIoError`;
lowering supplies both and the verifier rejects either omission. The interpreter
uses Elisa's stdio bindings, checks every open/seek/read/close transition, and
returns one owned length-delimited buffer. It checks the file size against its 64 MiB
input safety ceiling before allocation; oversized files and other I/O failures become
`InterpretError.FileIo` at the reference-interpreter boundary. Empty files return
empty text. The source-file adapter retries positive short `fread` progress but
rejects a zero/over-count or sticky host `ferror` before publishing source bytes,
and still requires the exact post-read count and successful close.
The shell-shaped `cat(path)` spelling lowers to this same typed opcode and retains
the nominal `Path`, effect, and error contract.
`WriteText` has verified signature `Named(Path) × Text -> usize` and requires
`File.Write` plus `FileIoError`. Execution opens in replacement mode, verifies the
complete byte count, checks close status, and returns that count. A partial write
is retried while stdio makes progress, but a zero/over-count or host error
indicator never produces a successful result; empty text still creates or
truncates the target file deterministically. Shared exact-size reads use the
same positive-progress and `ferror` admission, so a sticky host error cannot
publish a complete-looking copy or capture.
`AppendText` has the same verified signature and effect/error requirements, but
opens in append mode so each byte is written after the existing file contents.
It is the typed IR counterpart to shell `>>` and Python append-mode writes.
`ReadBytes` verifies as `Named(Path) -> Array[Int(unsigned, 8)]` and requires
`File.Read` plus `FileIoError`. The interpreter reads exact length-delimited file
bytes, checks the size against its 64 MiB input safety ceiling and the remaining
u32 runtime-storage span before allocation, stores them as flat runtime integer
values, and preserves embedded NULs. Empty files produce an empty array. `WriteBytes` and `AppendBytes` verify as
`Named(Path) × Array[Int(unsigned, 8)] -> Int(unsigned, 64)` and require
`File.Write` plus `FileIoError`; they replace or append respectively and return the
exact byte count. Their direct bytecode path calls the same checked runtime
boundary as the reference interpreter, so binary file round trips remain
backend-parity operations.
The line-oriented helpers `read_lines(path) -> Array[Text]` and
`write_lines(path, lines) -> usize` and `append_lines(path, lines) -> usize` are
deliberately not new opcodes: lowering expands them to `ReadText` + `Split`,
`Join` + `WriteText`, and `Join` + `AppendText`, respectively. This keeps their
effect/error rows and runtime behavior identical to the primitive operations while
making empty lines and final-newline handling explicit.
The equivalent receiver forms `path.read_lines()`, `path.write_lines(lines)`, and
`path.append_lines(lines)` lower to the same instruction sequences. `path.append_text`
and `path.append_bytes` likewise reuse `AppendText` and `AppendBytes`, so the method
surface adds no interpreter or bytecode cases. The line writers lower their input
array contextually as `darray[sview]`, so an empty literal is still a statically
typed empty collection rather than an untyped escape hatch.
`RemovePath` verifies as `Named(Path) -> Bool` with `File.Write`. It calls Elisa's
core unlink wrapper using the same owned NUL-terminated path conversion as the other
filesystem operations. Missing paths produce `false`; they are not conflated with
interpreter failure or wrapped in a result value.
`CopyPath` verifies as `Named(Path) × Named(Path) -> Bool` with `File.Read` and
`File.Write`, plus `FileIoError`. It copies the complete length-delimited source
bytes into a replacement destination, including embedded NUL bytes. `MovePath` has
the same typed path pair and `FileIoError` but only requires `File.Write`; it uses
the POSIX rename boundary. Both operations are available on the direct bytecode
filesystem path as well as the reference interpreter. The interpreter rejects an
exactly identical source and destination before opening the destination for
truncating write, and also compares existing source/destination device and inode
identity so hard-link or symlink aliases cannot destroy the source bytes.
`RunProcess` verifies as `Named(Executable) × Array[Text] -> Int(signed, 64)` and
requires `Process.Run` plus `ProcessError`. The interpreter executes it directly as
a POSIX `fork`/`execvp`/`waitpid` state transition with a NUL-terminated argv. No
command string or shell expansion exists between typed IR and the operating system.
The interpreter's bounded wait state machine preserves timeout as the typed
`InterpretFailure.Time` outcome: exhausting the poll budget terminates and
reaps the private process group, then reports `Time` after giving
`OutputLimit` precedence for capture operations. Other wait, close, seek, and
reap failures remain `InterpretFailure.Process`, so callers can distinguish a
deadline from a generic host/process failure without inspecting status bits.
The termination edge also records whether the direct leader was already
reaped: even in that case it sends the forced `KILL` to the verified private
group before returning, so a surviving descendant cannot escape cleanup.
Parent-side `setpgid` treats POSIX `EACCES` as confirmed admission when the
child has already crossed `exec` after its child-side group setup; only other
non-retryable failures use the direct-child fallback.
After the direct leader is reaped, capture-capable process waits probe the
confirmed private group with signal zero for a bounded grace window before
publishing temporary-file output. A surviving group member (for example, a
background child that inherited stdout or stderr) is terminated and reported
as `InterpretFailure.Process` rather than allowing a partial regular-file
snapshot to escape. This is group-quiescence evidence only: descendants that
escape or reparent outside the group still require an authoritative host
supervisor for whole-tree containment.
`EsProcess::ProcessCommand` is the higher-level shell-free command value for
adapters that need more than the primitive opcode: it keeps the executable,
ordered argv, child working directory, ordered environment overrides, stdio
modes, explicit stdin/stdout/stderr file destinations, timeout budget, and
failure policy in one typed record. A `File` mode must carry its corresponding
path, while `Inherit`, `Capture`, and `Null` modes reject stray paths; path
payloads receive the same bounded length/NUL admission before aggregate
terminated-byte accounting, including the child working directory. Its
`validate_process_command` boundary rejects empty/NUL/oversized text, vectors
that exceed the `PROCESS_COMMAND_MAX_ARGUMENTS` one-million-argument or
64 MiB terminated-byte ceilings,
odd environment pairs (reported as `EnvironmentVectorMalformed`), empty or
`=`-containing names, duplicate overrides,
and environment vectors above the one-million name/value-pair ceiling,
unknown policy ordinals, and unsupported stdio modes with
`error[ProcessCommandError]`. The environment vector is intentionally flat so
insertion order is explicit and host adapters cannot inherit map-order or shell
assignment semantics. `resolve_process_environment` materializes an exact
child vector from a captured ambient vector: `Inherit` overlays in place order,
`Replace` discards ambient entries without inspecting them, and `Clear` emits
none without inspecting them, so malformed ambient data cannot affect a mode
that does not consume it. `Inherit` validates the captured vector before
overlaying it and revalidates the materialized child vector against the same
pair-count and terminated-byte ceilings, so combined ambient and command data
cannot bypass process bounds; no mode touches process-global state. This model is a
validated adapter boundary; fork/exec,
Windows process creation, background scheduling, and streaming callbacks remain
host integrations rather than hidden behavior in the value itself.
`EsProcess::ProcessResult` is the matching outcome boundary. Its closed
`ProcessResultKind` distinguishes normal exit, signal death, spawn failure,
timeout, cancellation, output-limit termination, and host I/O failure; a signal
kind requires a nonzero signal within the shared 1–64 signal envelope while every other kind rejects one. Only
`Exited` carries a nonzero exit status; all timeout, cancellation, spawn,
signal, output-limit, and host-I/O outcomes retain the zero status sentinel.
Captured
stdout, stderr, and adapter error text receive length-first NUL admission and a
shared terminated-byte ceiling through `error[ProcessResultError]`, so a failed
child cannot be silently reclassified as an ordinary exit status; normal exit
statuses are nonnegative at both result and session boundaries.
`ProcessJob` and `advance_process_job` define the background-supervision state
machine (`Created`, `Running`, `Cancelling`, terminal success/failure/timeout,
or cancellation). Start consumes an attempt, retry is permitted only from a
terminal failure and returns to `Created`, and cancellation requires an explicit
acknowledgement edge. Any cancelled job must also have consumed an attempt.
Invalid transitions, zero/oversized retry ceilings, and
retries beyond `max_attempts` raise `error[ProcessJobError]`; every running or
terminal attempt state also requires a consumed attempt, preventing forged
pre-launch outcomes. The scheduler, parallel-map limits, and platform signal
escalation remain host integrations.
`ProcessPipeline` extends the same shell-free boundary to multi-stage commands.
It validates every stage through `ProcessCommand`, caps stage count and
aggregate buffer policy, and records a separate lifecycle for each stage
(`Pending`, `Running`, `Exited`, `Failed`, or `Cancelled`). `Start` creates the
bounded pending-stage ledger; the adapter reports each successful launch with
`StageStart`, then may report output chunks and exits or failures in any stage
order. `StageOutput` charges each stdin/stdout/stderr byte to one bounded
aggregate stream budget, so a host cannot defer an output-limit failure until
after it has retained unbounded intermediate data. A terminal
`ProcessPipelineStageResult` must carry a validated `ProcessResult`, matching
stream counters, explicit stdin closure, and EOF on both output channels;
`CancelAck` is accepted only after every stage is terminal and every receipt is
drained. Fail-fast failure enters cancellation draining whenever another stage
remains, including the two-stage case where the failed stage is already
terminal, while aggregate failure keeps other stages running. `StageFailure` on a pending stage requires
the `SpawnFailure` outcome; on a running stage it records a post-launch process
outcome and rejects `SpawnFailure`. The stdin closure is a logical no-more-
writes acknowledgement even when a command uses inherited, null, or file
stdio; a pipeline adapter may replace direct stdio routes with connected pipes,
but must account for those logical channels through the receipt.
Duplicate terminal events, impossible stage transitions, forged receipts, and
counter mismatches raise `error[ProcessPipelineError]`. The contract is now
ready for a concurrent pipe adapter, but it is not that adapter: OS pipe
backpressure, SIGPIPE behavior, polling, launch rollback, and child reaping
remain host responsibilities.

`EsProcessOutput::ProcessOutputSession` makes shell redirection explicit. A
route contains bounded `Inherit`, `Null`, `Capture`, `TruncateFile`, or
`AppendFile` destinations; multiple destinations require an explicit tee flag.
Chunks carry monotonically increasing sequence numbers and a final marker, and
the session accounts chunk count and bytes before a host writer fans data out.
Validation reconciles `next_sequence`, chunk count, byte totals, and final-state
markers, rejecting imported sessions that bypass the streaming phase.
Duplicate destinations, missing file paths, out-of-order chunks, overflow,
premature end, failure, and cancellation use `error[ProcessOutputError]`;
the bytecode execution ledger proves both captured channel totals and the
already-charged output total before subtracting remaining output capacity;
descriptor writes and concurrent drain behavior remain host work.

EsProcessSession binds that command value to an adapter lifecycle. Spawn must
provide distinct child/stdin/stdout/stderr handle identities when capture is
requested; creation carries no pre-spawn handles or output counters, spawn
resets the result sentinel, stdout and stderr progress charge one shared output
ceiling, polls charge a bounded polling budget, and only typed exit/failure/timeout or
cancellation events may terminate the session. Exit records the adapter-supplied
status; non-exit terminal states retain a zero exit-status sentinel. Validation also requires each
terminal state to carry its matching `ProcessResultKind`, and requires a
`SpawnFailure` sentinel while still `Created`, so externally assembled records
cannot relabel a pre-spawn session or a post-spawn failure as the wrong outcome,
an exit, or a timeout. The session never performs
fork/exec or signal operations itself.

`EsProcessTermination::ProcessTerminationSession` is the process-group
cleanup ledger. A host supervisor reports the root and member identities
(including start tokens), then acknowledges a graceful group request before
polling or escalating. Member records are kept in strictly ascending PID order:
`canonicalize_process_termination_members` performs a bounded in-place sort at
admission, validation rejects unsorted or duplicate PIDs in one linear pass,
and root lookup uses binary search. Force attempts and polls are bounded;
planned and running sessions start with clean poll/force/reap accounting;
`record_process_termination_polls` records a positive count of already-completed
host polls only in `GracefulWaiting` or `Reaping`. The cumulative count spans
both phases, may reach the configured ceiling exactly, and rejects an over-limit
batch without changing the session. Empty batches are rejected, and timeout
remains a separate explicit state-machine event rather than an inferred poll
result. Hosts can aggregate multiple observations into one ledger update;
each update still performs full O(n) session validation, so frequent small poll
batches retain that cost while aggregation reduces validation frequency.
`report_process_termination_reaps` accepts a nonempty batch of full
`(pid, start_token)` identities in any input order. After readiness and size
checks, it sorts the batch in place, preflights every identity and duplicate
before mutating the session, and then commits all receipts together. Unknown
members, stale generations, and already-reaped identities are rejected without
partially changing session accounting; receipt-validation failures leave the
batch sorted. Per-member reaped flags are checked against the summary count, and
`Reaped` is impossible until every declared member is accounted for. A single
full-group batch avoids a full membership scan for every child report; repeated
small reap batches still pay the full session-validation cost per call. Phase
validation rejects impossible records that remain in
`GracefulRequested` after polls, force attempts, or reaps, or in
`GracefulWaiting` after force attempts or reaps; `ForceRequested` also requires
an attempt. The corresponding valid transitions from `GracefulWaiting` move
the state to `Reaping` or `ForceRequested`. `Cancel` records cancellation
intent without weakening the same graceful/force/reap sequence, while timeout
and failure remain distinct terminal outcomes. This module never sends signals
or calls `waitpid`: it validates host-reported identities and accounting, but
cannot prove the host inventory is complete or that a reaped flag came from an
operating-system observation rather than an externally assembled record.

`EsTask::TaskScope` and `TaskChannel` define the corresponding concurrency
boundary. A scope caps active children, records completed/failed children, and
rejects closing/failed/terminal records whose child accounting is inconsistent,
including failed scopes with unstarted children; cancellation
acknowledgement is admitted only after active children reach zero; child
completion/failure reports remain admissible while cancelling so the scheduler
can drain already-running work before that acknowledgement. A failure already
recorded before `CancelAck` wins the cancellation race and leaves the scope
`Failed`, never silently `Cancelled`. Receiving
the final message must account for all remaining buffered bytes, preventing a
zero-message/nonzero-byte state. It
requires explicit close or cancellation acknowledgement; channels cap both
message count and bytes, reject impossible zero-message/nonzero-byte (or
nonzero-message/zero-byte) snapshots, reject imported empty `Closing` states,
reject sends while closing/cancelled, and transition to `Closed` only after
queued messages drain; cancellation acknowledgement also requires queued
messages to drain. `error[TaskContractError]`
distinguishes invalid transitions, child accounting, full buffers, and empty
receives. `EsTaskTransfer::TaskTransferSession` makes cross-task ownership
explicit: copy is limited to copyable values, move changes the owner only at a
commit edge and advances the generation, and borrow is limited to copyable or
handler-context values with a bounded lease. Planned/validating/committed state
requires the corresponding item-state cardinality; the internal `Committing`
edge is not an importable session state. Admission/commit
counters are derived from the item-state vector, so forged partial accounting
is rejected.
Duplicate resources, stale
generations, mismatched owners, invalid leases, partial admission, and
mid-commit cancellation are rejected through `error[TaskTransferError]`.
Scheduler threads, event loops, and the actual message transport remain host
integrations.

`EsExecutable::ExecutableDiscoverySession` keeps shell-free command lookup
typed. A bounded PATH-entry search submits candidate observations with stable
indices within the supplied PATH entries. Each candidate path is checked against
the exact indexed entry/name derivation: an empty entry yields `name`, a trailing
`/` is not doubled, and all other entries yield `entry + "/" + name`. A mismatch
is rejected before candidate accounting advances; only a regular, executable
candidate becomes an `Executable` result.
The result is distinct from an arbitrary `Path`, while exhausted search emits
`Missing`, and invalid candidate order, names, NULs, limits, cancellation, and
premature missing results, forged selected indices, and non-exhausted terminal
states use `error[ExecutableDiscoveryError]`. PATH access,
permission checks, and platform executable rules remain host adapter work.

The argv terminator is cleared using `size_of(uintptr)`, matching the target
pointer width rather than assuming an 8-byte slot.
Before reserving argv pointers or owned argument strings, the interpreter
rejects vectors above its one-million-element process-argument budget with
`InterpretError.Process`; this bounds host allocation for malformed or hostile
runtime arrays while leaving ordinary typed argument and NUL validation intact.
It also rejects an aggregate terminated executable/argv C-string payload above
its 64 MiB process-argument byte budget before duplicating any C strings. Each
payload's trailing NUL is included. The byte guard is overflow-safe and leaves
malformed non-text elements to the existing typed validation path; a zero
configured byte budget means unlimited for embedders that deliberately opt out.
The same byte guard applies to run, stream-capture, stdin-capture, and
full-result process entrypoints. Environment names and values are checked
against the same terminated 64 MiB byte budget before their independent
C-string buffers are reserved; the `=` separator used by `setenv` is included,
and malformed entries still take the ordinary type path. The element-count budget also bounds environment override entries and
pipeline stages before their reservation or child-spawn loops.
Each individual executable, argument, environment name, and environment value
also passes a per-field length check before `text_has_nul` or delimiter scans.
This keeps a borrowed oversized view from forcing an unbounded host scan even
if a future adapter changes aggregate admission. Direct environment get/set/
unset wrappers apply the same preflight before copying their C-string operands.
Process waits use nonblocking `waitpid` polling and a 120-second deadline; a child
that exceeds the deadline is killed and reported as `ProcessError` rather than
blocking the host indefinitely. Interrupted waits and one-millisecond poll
sleeps retry through bounded `EINTR` budgets before becoming `ProcessError`.
`run_process(executable, arguments, timeout_micros)` may override that deadline
with a nonnegative `i64` microsecond value. Omitting the third argument retains
the 120-second default; zero disables the caller deadline but not the hard
poll-count safety ceiling. Negative values fail as `ProcessError`. Deadline
checks occur at poll boundaries, so termination includes the polling interval
and the bounded process-group cleanup grace.
`capture_process_stdout` and `capture_process_stderr` accept the same optional
third timeout argument. The stdin-capable
`capture_process_result(executable, arguments, input, timeout_micros)` accepts
an optional fourth timeout argument and an optional fifth `max_output_bytes`
argument. The fifth argument caps captured stdout plus stderr for that call,
and cannot widen the enclosing runtime's remaining output budget. Negative or
over-runtime-ceiling limits fail before spawn; exceeding an admitted limit
terminates the child and reports `OutputLimit`. All use the identical deadline
policy. The cwd and environment variants of `capture_process_result` accept
the same optional timeout and capture ceiling after their required directory
and/or environment arguments. Their omitted values retain the same defaults;
the ceiling still applies to combined stdout and stderr.
Stream-capture APIs with stdin and pipelines still use the default deadline;
their public timeout parameters remain future work.
The parent-side `setpgid(child, child)` admission also retries `EINTR`; any
other failure leaves `group_ready` false and retains direct-child-only cleanup.
Child stdout/stderr/stdin redirection retries interrupted `dup2` calls before
returning the typed process setup failure.
Negative-PID group signaling is attempted only
after the parent confirms `setpgid(child, child)` succeeded; if group setup
fails, cleanup signals and reaps the direct child without risking an unrelated
process group. Cleanup signaling and the blocking reap retry bounded `EINTR`
interruptions before reporting process failure.
The explicit `executable(text)` constructor adapts a runtime `Text` value to the
nominal `Executable` type for validated runner configurations. It contributes
`ProcessError` to the enclosing function's error row and rejects empty or
embedded-NUL names at execution time; every process opcode applies the same NUL
check to its executable and argument values before constructing C strings. The
run and capture entrypoints also recheck empty executable payloads at the host
boundary, so a nominal value injected by an adapter cannot reach `fork` with an
empty `argv[0]`.
The scripting-profile `run_process_with_stdin` facade lowers to a
`CaptureProcessResult` followed by `ProcessResultExitStatus`, preserving the
same typed stdin staging and one-shot child execution while exposing only the
status result.
`run_process_in_directory` lowers equivalently to
`CaptureProcessResultInDirectory` with an empty stdin snapshot followed by
`ProcessResultExitStatus`; the child-only `Path` control therefore has the same
parent-cwd isolation as the explicit capture form.
`run_process_with_environment` lowers to
`CaptureProcessResultWithEnvironment` with an empty stdin snapshot followed by
`ProcessResultExitStatus`, preserving typed child-local environment overrides.
`run_process_in_directory_with_environment` lowers to
`CaptureProcessResultInDirectoryWithEnvironment` with an empty stdin snapshot
followed by `ProcessResultExitStatus`, composing both child-only controls.
`CaptureProcessStdout` has the same operands, effect, and error row, with `Text` as
its result. Its opcode is handled by the interpreter's exhaustive Elisa dispatch
machine. Execution redirects only stdout into an anonymous temporary file, reaps
the child, and returns owned length-delimited bytes. The interpreter polls the
temporary-file size against its 64 MiB per-stream safety ceiling while the child
runs and before allocation; crossing it kills the confirmed private process
group (or only the direct child if group setup failed) and
reports `InterpretError.OutputLimit` at the host boundary. It does not reinterpret
output as a C string or capture stderr.
`CaptureProcessStderr` has the same verified signature and redirects descriptor 2
instead; descriptor 1 remains inherited. The shared stream-capture implementation
keeps byte ownership, wait behavior, and shell-free argument handling identical.
`CaptureProcessStdoutWithStdin` verifies as `Named(Executable) × Array[Text] × Text
-> Text` with the same `Process.Run` effect and `ProcessError` row. The interpreter
stages the input in a temporary file, redirects descriptors 0 and 1 in the child,
and drives input writing and process waiting through explicit state machines before
returning the owned stdout snapshot, subject to the 64 MiB process-input and
per-stream safety ceilings. Oversized input is rejected before a temporary file
or child is created.
`CaptureProcessStderrWithStdin` has the same verified signature and contract, but
redirects descriptor 2 and returns the owned stderr snapshot under the same 64 MiB
ceiling while stdout remains inherited. It shares the same state-machine input staging and shell-free argv
execution path as the stdout variant.
`CaptureProcessResult` is the differential-testing primitive: it has the same typed
 executable, argument-vector, and stdin operands but returns nominal `ProcessCapture`
data containing the exit status, stdout, and stderr from one child execution. The
child redirects descriptors 0, 1, and 2 to separate temporary files; the parent
rejects stdin snapshots above its 64 MiB process-input ceiling before staging a
temporary file, so a large caller-owned text value cannot force unbounded input
materialization. It then validates environment names as non-empty, NUL-free, and unique before `fork`, so
a host-injected map cannot make child behavior depend on last-write-wins ordering.
It then polls both streams against the interpreter's 64 MiB per-stream safety
ceiling while the child runs and before allocation; stdout and stderr are checked
independently, even when stdout remains within the ceiling. Crossing it kills the confirmed private process group
and reports `InterpretError.OutputLimit`, so a reference process is never allowed
to exhaust host memory. Any wait, polling, or stream-position failure also kills
and reaps the confirmed private group (or only the direct child if group setup
failed) before returning `InterpretError.Process`; no failed
capture path may strand a child or zombie.
Before allocating a completed stream, its `i64` file size is round-tripped
through host `usize`; a size that the target cannot represent is rejected as a
process failure instead of being truncated.
 `process_exit_status`, `process_stdout`, and `process_stderr` are typed accessors
 over that value. The capture and accessor
 opcodes are separately verified and dispatched explicitly by the interpreter.
`CaptureProcessResultInDirectory` extends the same contract with a nominal `Path`
operand. The child calls `chdir` after fork, leaving the parent cwd unchanged; a
failed child directory produces process status `126` while setup failures still
raise `ProcessError`.
`CaptureProcessResultWithEnvironment` extends the capture contract with a typed
`Map[Text, Text]` operand. The child applies each override with `setenv` before
`execvp`; no environment mutation leaks into the parent interpreter.
`CaptureProcessResultInDirectoryWithEnvironment` combines both controls. It consumes
`Executable`, `Array[Text]`, `Text`, `Path`, and `Map[Text, Text]` operands and
produces `Named(ProcessCapture)`. The directory and environment are applied only in
the forked child, preserving the parent process state for deterministic
differential-testing runs.
`CaptureProcessPipeline` and `CaptureProcessPipelinePipefail` consume
`Array[Named(Executable)]`, `Array[Array[Text]]`, and `Text`, producing the final
`ProcessCapture`. The arrays must be equal, non-empty, and contain at most 256
stages at runtime; each stage's captured stdout is staged as the next stage's
stdin through the same bounded temporary-file transport as
`CaptureProcessResult`. A non-zero stage does not skip later stages.
`CaptureProcessPipeline` reports the final stage's exit status, matching the
ordinary shell default; `CaptureProcessPipelinePipefail` reports the rightmost
non-zero stage status (or zero if all stages succeed). Both return the final
stage's stdout and the raw concatenation of all stage stderr in stage order,
with no inserted separators. This status policy is selected statically by the
builtin name and opcode, not by a runtime boolean or untyped flag. Execution is
sequential and shell-free, not a concurrent pipe, so it does not implement
OS-pipe backpressure, stderr interleaving, early-consumer/SIGPIPE behavior, or
complete concurrent child cleanup.
`Sleep` takes one signed/unsigned 64-bit integer or `f64` duration operand and
returns `Void`. Its instruction integer is `0` for seconds and `1` for
milliseconds. Verification requires `Time.Sleep` and `TimeError`; the reference
interpreter and direct bytecode path share the same bounded POSIX `usleep`
implementation, retry interrupted chunks through the bounded `EINTR` policy,
and reject negative or non-finite durations.
`GetEnvironment`, `SetEnvironment`, and `UnsetEnvironment` operate on `Text`
operands. Reads produce owned `Text` under `Environment.Read`; mutations produce
`Bool` under `Environment.Write`. All three require `EnvironmentError`, reject C
string truncation hazards and names containing `=`, admit each operand by the
shared process-text byte ceiling before scanning it, and execute through explicit
exhaustive opcode arms.
The scripting-profile `get_environment_or(name, fallback)` lowers to the same
`GetEnvironment` operation wrapped by `ErrorGuardPush`/`ErrorGuardPop` and a typed
merge block, so a missing variable follows the fallback edge without evaluating the
fallback on successful reads.

EsEnvironment provides the child-facing data boundary for those operations.
EnvironmentEntry names are validated and unique, values remain NUL-free and
bounded, and a sealed EnvironmentSnapshot can be looked up without touching
the parent process environment. Set updates an existing entry deterministically
and Unset leaves a bounded tombstone, so an adapter can apply the exact overlay
to one child without map-order or global-state leakage. New entries are
admitted against the aggregate byte ceiling before insertion, and replacing a
value accounts for only the previous value payload rather than double-counting
the name/terminator overhead.
Fresh `Ready` snapshots must be empty and zero-accounted, and `Unset` validates
the variable name before resolving tombstones.

`EsConfig` is the pure configuration precedence boundary for script-facing
defaults, files, environment overlays, and command-line overrides. Its four
`ConfigSource` layers have explicit `Defaults < File < Environment <
CommandLine` priority; a source may occur at most once, and each layer may
contain a key at most once. Keys reject empty/control/separator bytes, values
reject NUL while preserving valid line breaks, and per-layer/result counts plus aggregate
payload bytes are bounded before mutation. The resolver keeps the
highest-priority value, preserves an empty value as present, and returns
borrowed `sview` values in deterministic bytewise key order. `lookup_config_value`
therefore distinguishes an absent key from an intentionally empty value without
consulting files, process-global environment, or command-line state; adapters
must provide those observations as explicit layers and keep their storage alive
for the returned views.

`EsConfigJson::flat_json_config_layer` adapts a sealed, single-root JSON object
to the `File` layer, enforcing the layer-entry ceiling before allocating its
entry table. It requires strict duplicate-key rejection, preserves
decoded strings and exact number lexemes, and represents booleans/null with
their canonical JSON spellings. Its values borrow the `JsonDocument`; callers
must retain that document while using the layer or resolved values. Nested
arrays/objects are rejected and require the typed schema materializer instead.
This is a bounded flat-JSON slice of A06.

`EsConfigToml::parse_toml_config` adapts a bounded TOML subset to the same
owned File layer. It accepts bare/dotted keys, tables, comments, single-line
basic and literal strings, booleans, TOML decimal/hexadecimal/octal/binary/
floating-point/special numbers (with legal digit separators), and recursive
mixed arrays and inline tables across physical lines where arrays permit it.
`ConfigTomlNode` and `ConfigTomlNodeChild` retain decoded scalar values,
container kinds, ordinals, and inline-table keys in a structurally validated
bounded graph;
the format-neutral precedence view still preserves the original array/table
spelling. A compatibility projection also provides flat `items`/`fields` for
values representable by the former one-level subset. The graph is bounded to
16 MiB of source, 262,144 nodes, depth 128, and the existing aggregate array
item/table-field limits. Basic strings decode TOML's quote, backslash, control, and
Unicode scalar escapes. Simple single- or double-quoted key segments are
decoded, including `\"`, `\\`, `\uXXXX`, and `\UXXXXXXXX`; key escapes that
produce forbidden control bytes are rejected. Quoted dotted keys remain
rejected because the current flattened configuration-key view reserves dots
for path separators. Dotted keys inside inline tables, dates/times, and
multiline strings remain unsupported. A
source-only snapshot of the
observed `WasmBrowser/Cargo.toml` workspace/dependency subset has a fixture for
multiline member arrays, nested inline dependency values, and package aliases;
it has not been executed and does not establish Cargo compatibility.
Array-of-table headers are represented as zero-based numeric dotted key
segments (for example `links.user.0.name`) and a
typed row directory (`ConfigTomlArrayTableInstance`); nested regular tables are
scoped under the latest row. Nested array-of-table graphs remain unsupported.
Row count is bounded. Array item counts are
bounded per array and in aggregate; inline table fields have per-table and
aggregate limits. The text precedence layer does not do typed numeric
conversion. `resolve_toml_config_layers` composes the TOML File layer with
other explicit layers using `EsConfig::resolve_config_layers`, then restores
typed file winners and leaves environment/command-line winners as text. It
copies typed payloads and row-directory metadata; raw values still borrow the
winning layer storage.
The opt-in `parse_toml_config_layer` and
`resolve_toml_config_typed_layers` APIs also accept fully parsed TOML documents
for Defaults, File, Environment, and CommandLine sources, preserving the
winning typed value by whole-key replacement; they do not recursively merge
inline objects. Each array-of-table path is an indivisible row group: its
highest-precedence declaration replaces all rows at that path, and groups at
other paths resolve independently. A lower-precedence row never leaks through
by matching the winner's numeric index. The resolver bounds aggregate row
metadata and rejects conflicting inline-object/dotted-table or nested
array-table paths. The existing generic override path continues treating
environment and command-line values as text.
`EsConfigTomlFilePosix` reads files through the shared
stable UTF-8 reader with a 16 MiB ceiling. Source fixtures cover scalar and
array parsing plus rejection boundaries, but remain unexecuted pending
compiler-validation reauthorization. This is a deliberately small TOML slice of
A06, not full TOML compatibility.

`EsConfigJsonFilePosix::read_config_json_file` now reads a path through the
shared bounded, stable-file UTF-8 reader (16 MiB maximum), parses with the
requested JSON limits/policy, and returns a wrapper retaining the document
that owns the layer's borrowed views. It rejects a zero or over-ceiling input
budget and invalid decoder/JSON policies before opening the path. File
replacement/content-change protection is inherited from the shared reader;
the POSIX fixture asserts scalar materialization and early limit rejection but
has not been executed, so runtime qualification remains pending.

`EsConfigEnvironment::environment_config_layer` converts a validated sealed
environment snapshot to the `Environment` layer without consulting or
mutating process-global state. It omits unset tombstones so lower-priority file
values remain eligible, preserves present-empty values, and borrows snapshot
storage; the snapshot must remain alive and unchanged while its views are used.

`EsConfigCli::parse_config_cli` parses declared application options separately
from compiler-launcher flags. It builds the `CommandLine` layer, handles
`--name=value` and `--name value`, explicit empty values, boolean positive and
negative spellings, duplicate/unknown/missing-value errors, and preserves
positionals plus every argument after `--`. Its option/argument/input ceilings
are enforced before parsing; values remain borrowed from the caller's argv.
Option keys also borrow the declared schema; both inputs must remain alive
and unchanged while the result layer is used.

Declared one-character alphanumeric aliases support `-x`, `-x=value`,
`-xVALUE`, and `-x VALUE` when the option takes a value. Bundles such as
`-vj8` process boolean flags left to right; a value-taking option consumes the
rest of the bundle (with an optional leading `=`) or the next argv element.
`parse_config_cli_command` dispatches a first argv token to a declared
subcommand schema and distinguishes missing, unknown, and root-help requests.
The command parser exposes `help_requested`
for `-h`/`--help`; `config_cli_root_help` and `config_cli_command_help` render
deterministic owned bytes capped at 1 MiB. The focused model fixtures and
compiler-free source guard describe these rules, but remain unexecuted under
the explicit validation hold.

The four-source precedence path has an integration fixture that composes
explicit defaults, the strict JSON adapter, a sealed environment snapshot, and
the application CLI parser, then checks winners, source attribution, explicit
empty values, and still-defaulted/absent keys. It is source evidence only until
run on the supported local compiler under the bounded validation policy.

`EsDirectoryMutation` validates recursive copy/remove plans before a host
adapter mutates the filesystem. Source and destination containment compares
trim trailing separators (while preserving the root separator), so an equal
path or a descendant such as `/tmp/source/` → `/tmp/source/child` is always
reported as `DirectoryMutationError.DestinationCollision`; ordinary prefix
names such as `/tmp/source-old` are not treated as descendants. The same
check applies to session paths and every planned entry. Duplicate copy
destinations use the same normalized equivalence relation, and `Plan` rejects
the duplicate before mutating the session, so spellings such as `out/` and
`out` cannot leave an invalid plan behind.

`CreateDirectory`, `CreateDirectories`, `RemoveDirectory`, and `ChangeDirectory` verify as
`Named(Path) -> Bool` with `Directory.Write` and `DirectoryError`.
The legacy `CreateDirectory` form takes one path operand. `Path.mkdir` may use
the extended three-operand form `Named(Path) × Bool × Bool -> Bool`, where the
second operand is `parents` and the third is `exist_ok`, or the four-operand
form `Named(Path) × u64 × Bool × Bool -> Bool`, which adds the permission mode.
All controls remain runtime-typed and preserve the same effect/error row.
`CreateDirectories` recursively creates missing parent components and accepts
already-existing directory components, matching `mkdir -p`/`os.makedirs` while
keeping the same typed contract.
`CurrentDirectory` takes no operands, returns `Named(Path)`, and requires
`Directory.Read` plus the same error. All four have explicit opcode-machine arms;
the cwd result is copied before the POSIX allocation is released.
The shell-shaped source aliases `pwd`, `cd`, `mkdir`, `rmdir`, `rm`, `cp`, and
`mv` lower to these same verified directory and filesystem opcodes; no alias has a
separate runtime or weaker type contract.
`ListDirectory` verifies as `Named(Path) -> Array[Text]` with `Directory.Read` and
`DirectoryError`. The reference interpreter drives `readdir` through an explicit
scan machine, copies each entry before the next transition, removes dot entries,
and sorts owned names before materializing the runtime array. The current low-level
entry layout bridge is isolated and Darwin-specific; other native targets must
supply their platform `dirent` layout without changing this IR contract. The
interpreter rejects an entry length greater than the bridge's 1024-byte inline
name buffer before copying it, reporting `DirectoryError` instead of reading
beyond the ABI record.
`IsDirectory` verifies as `Named(Path) -> Bool` with `Directory.Read` and
`DirectoryError`. It has its own exhaustive dispatch arm and uses the same isolated
directory bridge that recursive glob traversal builds upon. The `is_dir` scripting
alias and `Path.is_dir()` method lower to this opcode without changing its effects
or error contract.
`ExpandGlob` verifies as `Named(Glob) -> Array[Text]` with `Directory.Read` and
`DirectoryError`. The interpreter performs component matching and recursive `**`
traversal in Elisa, filters symlink recursion, sorts and deduplicates owned matches,
and enforces a depth bound to make malformed/cyclic trees terminate deterministically.
Each directory scan is capped at 262,144 entries and 64 MiB of aggregate name
bytes; brace expansion is capped at 262,144 variants, while final glob matches
are capped at 1,048,576 items; each collection also has a 64 MiB aggregate
variant/result-byte budget. Crossing any budget fails with
`DirectoryError` before partial results are published.

`Path.iterdir()` validates every joined child path before publishing its first
runtime value; if a later child fails the path envelope, the shared flat storage
cursor is rolled back to its entry position rather than exposing a partial array.
After `readdir` reaches EOF or an error, the directory handle is closed and
cleared from the scanner before the collected entries are exposed, preventing a
closed host pointer from being reused.
Path joins and brace-variant assembly detect host-size addition wrap before
allocation; the walker reports the existing `DirectoryError` rather than
publishing a truncated match.
The recursive `path.rglob` adapter applies the same check when adding its
`**/` prefix.
Directory enumeration treats an interrupted `readdir` as a bounded retry rather
than publishing a partial snapshot; the retry budget resets after a directory
entry is observed and exhaustion becomes `DirectoryError`.
`ReadStdin` verifies as `() -> Text` with `Console.Read` and `ConsoleError`;
`ReadStdinLine` verifies as `() -> Text` with the same effect/error row and consumes
one line at a time, preserving stdin for subsequent reads. Both state machines
enforce the interpreter's 64 MiB stdin safety ceiling before materializing the
owned result. Bulk reads lower the host request to the remaining budget, while
line reads reject the next one-byte probe after exhaustion and count delimiters
against the same consumed-byte ceiling. They reject a host read count larger than
the descriptor's requested span before narrowing it to `usize`, so an invalid FFI
return cannot index past the temporary chunk. Interrupted POSIX reads are retried
through the explicit state machine up to a bounded count before becoming
`ConsoleError`; successful reads reset that retry budget. The Python-facing
`input(prompt)` lowering emits an optional `WriteStdout` for the prompt followed by
`ReadStdinLine`; EOF before a line is represented as the recoverable `Console` failure.
`WriteStdout` and `WriteStderr` verify as `Text -> Int(unsigned, 64)` with
`Console.Write` and `ConsoleError`. The reference interpreter drives input until EOF
and drives output through explicit `Data/End/Error` and `Progress/Done/Error` stream
machines, preserving partial-write semantics and owned read results. `print`
and `printr` lower their typed scalar arguments to formatting
and `Concat` instructions before one final stream write; optional `sep` and `end`
text controls are evaluated once and use the same typed concatenation path. An
optional `flush: bool` control is type-checked and accepted for Python
compatibility; because the stream backend writes directly with POSIX `write`,
the bytes are already visible and no separate buffering instruction is needed.
The shell-shaped `printf(text)` spelling lowers directly to `WriteStdout` with the
same literal-text, byte-count, effect, and error contract; it does not interpret
format directives.
Named direct-call arguments are resolved against predeclared parameter labels and
then emitted in canonical signature order. Their expressions still execute once in
source order. Missing parameters materialize their Elisa default expressions in
declaration order with earlier resolved parameters in lexical scope. Duplicate or
unknown labels, missing required parameters, positional arguments after named ones,
and exact-type mismatches are structured lowering errors.

## Reference interpreter

`interpret` is the first executable consumer of verified IR and the semantic
oracle for later bytecode, JIT, and native backends. Its initial core executes
integer and boolean scalars, text constants, homogeneous immutable arrays,
array/text indexing, length, slicing, membership, and concatenation, arithmetic
and comparisons, direct calls, branches, loops, SSA edge arguments, and returns.
`HandlerPush` and `HandlerPop` maintain a real runtime stack shared across direct-call
frames. `Perform` searches it from innermost to outermost and invokes the exact typed
operation clause of the nearest covering handler; linear clauses return one resumed
value and execution continues. Handler lookup, clause selection, and callback
invocation are explicit interpreter state-machine states. A callback may instead
issue a typed tail `Resume`, which transfers its payload back to the suspended
`Perform` through a runtime continuation frame. Handler contract metadata without
an operation clause is deliberately not treated as executable behavior. Multi-shot
policies keep that frame active during callback execution, so repeated `Resume`
instructions are ordinary callback values; full suspended-stack replay and
environment cloning are later increments.

Interpreter failures use `error[InterpretError]`, never a result wrapper. Stable
`observe` events and array elements are appended to caller-owned storage; this
gives differential testing an ordered trace and keeps region-bearing collections
out of the error-union return ABI. Flat runtime arrays validate their complete
`[array_start, array_start + array_count)` storage range before every read, so
malformed values supplied by an adapter fail deterministically instead of
becoming an unchecked host-memory access. Invalid indexing is a typed
`IndexOutOfBounds` failure. A deterministic step limit makes runaway programs a
typed `StepLimitExceeded` failure. The private failure-to-error conversion is an
exhaustive Elisa machine over `InterpretFailure`, so adding a new runtime failure
cannot silently fall through to success or a generic result value. The same
shared admission check rejects unknown `RuntimeValueKind` ordinals before
argument or resumed-frame dispatch.
The kind predicate is also a public, allocation-free IR boundary helper so
differential adapters can validate recursively materialized storage values before
their kind-specific conversion match; malformed nested values therefore fail as
typed adapter errors instead of becoming an implicit scalar.
The interpreter/bytecode admission predicate also scans the complete
caller-owned runtime pool before execution, validating every stored kind and
aggregate span so a malformed nested value cannot hide behind a valid root view.
Structural equality in both engines bounds aggregate comparison at 128 nested
levels before descending another array/map view; cyclic caller-owned views
therefore return a deterministic non-match rather than exhausting the host
stack.
Both execution engines check `steps >= step_limit` before incrementing, so even a
maximum-`u64` budget cannot wrap the counter; a budget of `N` still permits exactly
`N` ticks and fails on the next one.
Reference calls and direct-bytecode call recursion share a 4,096 active-depth
guard (including installed handlers) and report `InterpretError.OutputLimit`
before entering a deeper host frame. This is a containment policy while the
portable VM call stack is migrated fully to explicit frames; repeated dynamic
handler installation within one function applies the same bound. This does not
turn deep recursion into a fabricated value. Recoverable error-guard stacks in
both engines apply the same 4,096 bound and report `OutputLimit` before another
guard record is retained.

The interpreter's opcode dispatcher is an Elisa `machine` over the closed
`Opcode` enum. Every opcode is named explicitly—there is no wildcard arm—so
adding an instruction forces the semantic oracle to classify it at compile
time. Machine arms only drive dispatch state; typed arithmetic and value checks
live in focused helpers, respecting Elisa's machine ownership rules. Decimal
lexeme evaluation likewise uses explicit whole, fraction, exponent, and scaling
states instead of nested scanner conditionals.
Terminator selection follows the same model: `select_terminator` drives explicit
return, jump, branch, and invalid states, with branch values supplied by the
frame evaluator before transition. Edge-argument validation remains in the
surrounding interpreter loop, keeping the control machine independent of storage
and effect-handler state.

The verified bytecode facade uses the same program-counter machine for execution.
Modules containing only the currently closed scalar, text, regex, homogeneous-array,
and scalar-map subset (boolean, 64-bit integer, or 64-bit float values, text/nominal constants,
including four nested array levels,
array/map construction and key/value extraction, nominal path/glob/regex/URL constructors, typed path composition/decomposition, indexing, length, slicing, membership, concatenation, split,
join, typed integer/float parsing and formatting, regex search/replacement/splitting/extraction, indexed updates, unary/binary operators,
observations, pure direct calls, and typed filesystem/process/time operations) take a
direct packed-instruction path. Calls use recursive state-machine frames with one
shared step ledger, storage, and observation stream; child step charges remain
consumed when a recoverable error is caught by the caller, matching the
reference interpreter's budget accounting. The first filesystem operations
(`PathExists`, `ReadText`,
`WriteText`, `RemovePath`, and `MakeExecutable`) use the same typed resource
wrappers as the oracle, while retaining the packed program-counter machine. Its
value dispatcher is itself an explicit state machine, and its direct binary helper
uses a typed selection machine that separates equality, floating-point, and integer
operations before reaching a terminal value state. The packed executor wraps the
control cursor in another explicit machine for block entry, condition staging,
instruction storage, jump-edge collection, and returns, so its direct loop has no
implicit host control-flow state. The eligibility gate rejects
other widths, arrays nested deeper than six levels, handlers, and continuations.
Map values may use the inline bounded array/map layers on the packed path; nested
aggregate shapes beyond the descriptor remain reference-interpreter-only.
Error guards are eligible for the direct path: `ErrorGuardPush`/`ErrorGuardPop`
maintain a checked fallback stack, and recoverable typed failures jump to the
verified fallback block without wrapping the value in a result object.
Integer divide/remainder/shift operations validate zero divisors, signed minimum
overflow, and shift counts before entering host arithmetic, preserving the typed
interpreter failures while remaining on the direct path. Shift counts are
bounded by the declared result width (for example, shifting a `u8` by eight is
`InvalidShift`, not a narrow-value overflow), so direct-bytecode diagnostics do
not depend on the host machine width.
The direct path uses the same overflow-safe flat-array range predicates as the
interpreter for array/map indexing, slicing, membership, joining, concatenation,
indexed updates, equality, key extraction, and process argument vectors; malformed external arguments
therefore cannot diverge between engines.
`Expr.IndexN` lowers to the same `Index` opcode repeatedly from left to right,
so multi-dimensional array and map access introduces no new runtime operation or
temporary collection.
An `IndexN` assignment lowers the final replacement to `SetIndex` and then emits
one outward `SetIndex` per parent aggregate before rebinding the mutable root (or
storing a mutable module global).
Process execution and capture (`RunProcess`, stdout/stderr
capture, stdin transport, and `ProcessCapture` accessors) use the same typed argv
and stream helpers as the oracle. Unsupported modules deterministically rebuild
the verified IR and use `interpret` as the semantic oracle until their bytecode
handlers are implemented. Environment reads and writes (`GetEnvironment`,
`SetEnvironment`, and `UnsetEnvironment`) likewise share typed wrappers and are
eligible for the packed path. Directory creation/removal, current-directory
queries, directory listing, directory checks, and glob expansion are also wired
through typed wrappers. Stdio read/write operations use the same stream state
machines and typed wrappers; handlers and continuations remain oracle-only.

## Planned increments

The AST lowering now handles functions, typed parameters and returns,
integer/float/string/character/boolean constants, immutable local bindings, direct
calls, unary numeric negation and boolean negation, the core arithmetic family
(`+`, `-`, `*`, `/`, `%`), integer complement and bitwise operations (`~`, `&`, `|`, `^`) and shifts
(`<<`, `>>`), all six scalar comparisons, short-circuit `and`/`or`,
conditional expressions, returns, structured `if` branches with
fallthrough merges, and `while` loops with explicit headers/backedges/exits.
`pass` is a true lowering no-op: it advances through the surrounding structured
control-flow state without manufacturing an instruction or runtime value.
It also lowers homogeneous immutable array literals, scalar `darray[T]`/`array[T]`
type annotations, integer indexing, the `.count` field, and the Python-compatible
`len(value)` builtin. `len` is a compiler-known alias for the verified `Length`
opcode over arrays, dictionaries, and byte-oriented text, and remains shadowable
by an ordinary source function. `is_empty(value)`/`isempty(value)` and their
receiver methods lower to `Length` plus an exact zero comparison over the same
three families, without introducing general truthiness coercion. The
verifier rejects any `Length` instruction whose result is not the exact unsigned
64-bit `usize` representation. The same canonical predicate is reused by
`TextCount`, `ArrayCount`, file-size/mode queries, text/byte writes, and
standard-stream writes, so every byte/count-producing opcode has one verifier
definition of `usize` rather than a collection of subtly divergent integer
checks.
`is_nonempty`/`nonempty` forms add a typed `Not` over that comparison.
compiler-known `abs(value)` builtin lowers
to a typed comparison, branch, and merge using the existing `Less` and `Negate`
operations, so it preserves single evaluation and exact integer/float types.
The compiler-known `sorted(values)` builtin lowers to the existing `SortArray`
operation and returns its fresh owned array without mutating the source value.
It accepts only arrays whose scalar elements have a deterministic total order.
The compiler-known `reversed(values)` builtin lowers to `ReverseArray` and
returns a fresh owned array with the original element descriptor in reverse
order, without requiring a mutable binding.
The compiler-known `print(value, ...)` and `printr(value, ...)` conveniences
format each supported scalar, join arguments with one space, and lower directly
to the existing `Concat` plus `WriteStdout` operations. `print` appends a newline
by default; `printr` does not. The optional
`flush: bool` control is accepted as a typed compatibility spelling because
POSIX writes are unbuffered at this boundary. No command string or separate
stdout runtime is introduced.
The compiler-known `min(values)`/`max(values)` calls lower to `SortArray` followed
by a checked `Index` at `0` or `-1`, preserving exact scalar element types and
the normal empty-array failure path. Two or more scalar arguments are first
packed into a typed temporary array, so variadic calls share the same operation
and never evaluate an argument more than once.
The Python-shaped `sum(values, start)`/`product(values, start)` calls reuse the
integer-fold state machine with identities `start`/`1` (`sum` defaults to `0`,
`product` defaults to `1`),
while `any(values)`/`all(values)` reuse
the early-exit boolean-fold CFG. All four preserve exact element types and
short-circuit or fold without materializing a second collection. Their iterable
forms also normalize Python `range(stop)`, `range(start, stop)`, and
`range(start, stop, step)` calls to the same counter-driven fold/query CFG.
Empty literals use
their expected array type in bindings, assignments, returns, and call arguments,
so `[]` never introduces an untyped dynamic collection. Arrays may nest six levels
(`darray[darray[darray[darray[darray[darray[T]]]]]]`) using the compatibility fields; a seventh array
layer remains an explicit lowering error until the recursive table is used directly by
source typing. Dictionary values may be scalar or bounded combinations of arrays
and nested maps; shapes whose value needs a deeper descriptor are rejected at the
source boundary. The
`intern_module_types` pass records every type-bearing IR position in the shared
table, and malformed ranges or duplicate rows are verifier errors. Scalar
statement `match` alternatives such as `1 | 2` are expanded into adjacent typed
arms that share the original body and guard. The same expansion applies before
array shape lowering, so `[0, head] | [1, head]` becomes two typed shape-check
arms. Statement `match` also lowers array prefix/rest patterns such as
`[head, ...tail]`: a
typed `Length` shape check branches before `Index` extraction, and a matching
rest binding is a typed `Slice` view of the original array. Prefix bindings and the
rest suffix remain lexically scoped to the arm, while outer mutable bindings use
the same merge parameters as scalar matches. Nested aggregate subpatterns remain
explicitly rejected until the IR gains aggregate-pattern descriptors.
Source annotation lowering interns function signatures into the same structural
identity space early; the final module pass then assigns ids to all inferred
instruction and handler types before verification.
Plain single-binder `for value in array` loops lower to explicit header, body,
latch, and exit blocks. The collection is evaluated once; length and indexing stay
typed IR operations. `continue` targets the incrementing latch, `break` targets the
exit, and mutations of outer bindings travel through typed loop parameters.
Read-only dictionary loops additionally accept `for key, value in map`; the key
binding comes from `MapKeys` and the value binding from a typed map `Index` in the
body block. Arrays and text additionally accept `for index, value in collection`:
the first binding is the loop's typed `usize` cursor and the second is the
ordinary `Index` result (`char` for text), so no pair materialization is needed.
The Elisa-compatible `collection.enumerate()` suffix is sugar for the same
lowering and is only valid with the two bindings. The Python-compatible
`enumerate(collection, start)` accepts one array/text source and an optional
non-negative integer start; literals normalize to `usize`, while dynamic starts
must already be exact `usize`. The form remains shadowable by a source function
and preserves the typed `usize` cursor. The Python-compatible
`mapping.items()` suffix is likewise sugar for the existing map-pair loop: it
snapshots keys once, performs typed value indexes in the body, and never creates
pair objects.
The Python-compatible `zip(left, right)` loop form accepts exactly two positional
array or text sources. Lowering evaluates both once, emits one typed `Length` for
each, selects the smaller `usize` through a three-block merge CFG, and reuses that
limit for the indexed loop. The body emits one typed `Index` per source and binds
the two element values directly; no tuple or pair array is materialized. A source
function named `zip` shadows this loop sugar and is lowered as an ordinary call.
`sorted(values, reverse: flag)` accepts an optional statically typed boolean. A
literal `true` lowers to `SortArray` followed by `ReverseArray`; a runtime flag
branches through a typed merge CFG so only the selected ordering path executes.
`for mutable value in values` additionally requires `values` to be a named mutable
array binding. Python's `range(stop)`, `range(start, stop)`, and
`range(start, stop, step)` loop calls are normalized to the same counter-driven
range CFG, with typed steps and no temporary collection. Literal steps select a
fixed comparison direction; dynamic integer steps use `RangeCondition`, which
selects the sign-aware direction at runtime. A zero dynamic step raises
`RangeStepZero` through the function's error channel. Lowering
records a scoped element-owner relation; every successful
`value <- replacement` or compound update immediately transitions the owner through
`SetIndex`. The updated array is loop-carried state, so writes survive conditional
and match merges, nested loops, `continue`, and `break` without hidden aliasing or
deferred writeback. Temporary collections, immutable owners, and mutable text
iteration are rejected statically.
Text uses the same verified collection operations and loop CFG. In the current
Elisa-compatible `sview` model, `.count` is a byte count and `text[index]` or
`for character in text` yields one 8-bit `char`; negative array/text indices are
normalized from the end before bounds checking, while dictionary indices remain
exact keys. Invalid indices raise the same typed `IndexOutOfBounds` interpreter
error as arrays. This byte contract is explicit rather than silently pretending
to provide Unicode grapheme indexing.
Value recovery with `get collection[index] else fallback` is lowered as a lazy
state-machine branch. `IndexValid` checks array/text bounds or dictionary key
membership without raising for an ordinary miss; the success edge then performs
the ordinary checked `Index`, while the fallback edge evaluates its expression
only when needed. Both edges merge through one typed block parameter, so the
fallback cannot be eagerly evaluated and the semantics remain identical in the
reference interpreter and bytecode facade. Index and fallback types must match
exactly, and malformed runtime storage still raises the usual typed error.
For `get collection[index0, index1, …] else fallback`, lowering builds a
left-to-right chain of `IndexValid` predicates and ordinary `Index` operations.
Every predicate's miss edge targets one shared lazy fallback block, while each
success edge performs its checked index before evaluating the next index. Thus
each intermediate access keeps its exact array/map/text typing, a bounds or key
miss at any depth selects the same fallback, and malformed storage failures are
still propagated rather than recovered. The final value and fallback merge through
one typed block parameter.
The postfix `collection[index0, index1, …] else fallback` spelling is normalized
to this same lowering path by the parser's binary-`else` node.
Dynamic destructuring uses `UnpackArray(array, index)` with the required target
arity stored in the instruction integer payload. The verifier checks the array
element result type and requires `IndexOutOfBounds` in the function error row;
the interpreter and direct bytecode path reject any runtime length mismatch
before exposing an element. Lowering emits all unpack operations before applying
target updates, preserving simultaneous assignment semantics.
`collection[low:high]` lowers to the dedicated typed `Slice` operation. Either
bound may be absent: the lower default is zero and the upper default is one
`Length` evaluation of the already-evaluated collection. Slices are half-open,
preserve the exact array or text type, and require `0 <= low <= high <= count`;
violations raise typed `IndexOutOfBounds`. Immutable array slices share their
backing value storage, while text slices are byte views under the `sview` contract.
The compiler-known `split(text, separator)` operation has the exact static type
`Text × Text -> Array[Text]` and lowers to the semantic `Split` opcode. Its optional
third argument is a signed `i64` `maxsplit`, producing a three-operand bounded
split; negative values mean unlimited splitting and zero returns one unsplit field.
It preserves leading, trailing, and consecutive empty fields. An empty separator
splits a nonempty input into one-byte text views, while empty input produces an
empty array; this follows the same explicit byte model as indexing and iteration.
The interpreter stores fields in caller-owned value storage, so split results can be
indexed, compared structurally, iterated, and returned without hidden host
allocations. Both execution engines first collect source views locally and admit
the exact field count before publishing runtime text values, keeping capacity
failures atomic across whitespace, empty-separator, forward, and reverse modes.
The inverse compiler-known `join(fields, separator)` operation has type
`Array[Text] × Text -> Text` and lowers to `Join`. Verification rejects non-text
arrays before execution; the interpreter also validates each runtime element and
constructs one owned output buffer. Separator bytes and field bytes are
accumulated with checked additions before allocation. Empty arrays join to empty
text, separators appear only between fields, and empty fields remain observable.
The compiler-known `starts_with(text, prefix)` and `ends_with(text, suffix)`
predicates have type `Text × Text -> Bool` and lower to dedicated semantic
opcodes. They compare bytes under the same `sview` contract as indexing and
regex helpers; an empty prefix or suffix succeeds, while a boundary longer than
the input fails. Both are pure operations, remain shadowable by a user-defined
function of the same name, and share the packed bytecode text dispatch family.
The compiler-known `contains(collection, needle)` helper and
`collection.contains(needle)` method have type `Array[T] × T -> Bool`,
`Map[K, V] × K -> Bool`, or `Text × (Text | Char) -> Bool`. They normalize to
the same `Contains(needle, collection)` instruction used by the binary `in`
operator, preserving exact element/key typing and single evaluation of both
operands.
The compiler-known `replace(text, old, replacement)` operation has type
`Text × Text × Text -> Text` and lowers to `TextReplace`. It performs left-to-right,
non-overlapping literal replacement without interpreting `old` as a regex. An
empty `old` value follows Python's boundary rule (the replacement is emitted
before, between, and after input bytes); all output is copied into permanent
runtime storage for parity across interpreter and bytecode execution.
`TextReplace` caps output at 64 MiB in both execution paths. Each append checks
the remaining capacity before growing the buffer; exhaustion reports
`InterpretError.OutputLimit` and does not publish a partial result.
The compiler-known `strip(text)` and `trim(text)` aliases have type `Text -> Text`
and lower to `TrimText` with mode 0. The Python-shaped `text.lstrip()` and
`text.rstrip()` methods use the same opcode with modes 1 and 2 respectively.
They remove ASCII whitespace (`space`, tab, line feed,
vertical tab, form feed, and carriage return) only at the two boundaries and
return an `sview` into the existing text storage; interior whitespace is retained.
The compiler-known `lower(text)` and `upper(text)` operations, together with the
`text.lower()` and `text.upper()` method spellings, have type `Text -> Text` and
lower to `LowerText` and `UpperText`. They fold ASCII letters while preserving
all other bytes, and allocate owned output so the result remains valid across
both execution backends.
The compiler-known `split_lines(text)`/`splitlines(text)` aliases and the
`text.splitlines()`/`text.split_lines()` methods have type `Text -> Array[Text]`
and lower to `SplitLines`. LF, CR, and CRLF delimiters are recognized; a trailing
delimiter does not create an extra field, and empty input yields an empty array.
Python-shaped text method aliases lower to these existing typed operations as
well: `startswith`/`starts_with` and `endswith`/`ends_with` lower to
`StartsWith`/`EndsWith`, `replace(old, replacement)` lowers to `TextReplace`,
`strip()`/`trim()`/`lstrip()`/`rstrip()` lower to `TrimText` (modes 0/0/1/2),
and `split(separator)`/`split(separator, maxsplit)`/`split()` lower to `Split`
(modes 0/1). `rsplit()` uses whitespace mode 1, while `rsplit(separator)` and its bounded form use the same `Split`
opcode with mode 2; the runtime scans separators from the right and reverses
the materialized fields back to source order. The method forms require text receivers and exact positional arity;
the bounded method form requires a signed `i64` limit, while zero-argument
`split()` uses ASCII-whitespace runs and produces no empty fields.
The Python-compatible `separator.join(fields)` method lowers to the existing
`Join` opcode with the fields operand first and the text receiver as separator.
The Python-compatible `mapping.keys()` method is also compiler-known: it requires
zero arguments, returns `Array[K]` for `Map[K, V]`, and lowers to the existing
insertion-order `MapKeys` instruction. The set descriptor is rejected at lowering
so set membership remains the only supported key-like operation for sets.
`mapping.values()` has the same zero-argument contract, returns `Array[V]`, and
lowers to `MapValues`; nested value descriptors are retained for verifier and
backend checks, and set descriptors are rejected.
The `text.count(substring)` method has type `Text × Text -> usize` and lowers to
`TextCount`. Matching is byte-oriented and non-overlapping; an empty substring
returns one more than the input length, and both reference and direct bytecode
paths use the same deterministic scan. Both paths check that the host count
(including the empty-needle `length + 1` case) is representable by its signed
runtime result before publication and report `InterpretError.IntegerOverflow`
instead of wrapping.
The `text.find(substring)` method has type `Text × Text -> Int(signed, 64)` and
lowers to `TextFind`; it returns the first byte offset, zero for an empty needle,
and `-1` for a miss.
The matching `text.rfind(substring)` method lowers to `TextRFind` and returns the
last byte offset, the input length for an empty needle, or `-1` for a miss.
`text.index(substring)` and `text.rindex(substring)` lower to `TextIndex` and
`TextRIndex`. They return the corresponding first/last offset (including empty
needle boundaries) and raise `IndexOutOfBounds` on a miss through the function's
declared error row. Array `.index(element)` lowers to checked `ArrayIndex`, while
`array.find(element)` remains the sentinel-returning `ArrayFind` operation.
The no-argument `text.isdigit()`, `text.isalpha()`, `text.isalnum()`,
`text.isspace()`, `text.islower()`, `text.isupper()`, and `text.isascii()` methods lower to
`TextPredicate` with a compile-time mode and return `Bool`. The interpreter and
direct bytecode backend share the same non-empty ASCII rules: decimal digits,
ASCII letters, their per-byte union, the scripting profile's
space/tab/LF/VT/FF/CR whitespace set, and case predicates that ignore uncased
bytes but require at least one cased byte; `isascii` accepts the empty string.
`text.removeprefix(prefix)` and `text.removesuffix(suffix)` lower to
`TextRemoveBoundary` with mode 0/1 and return `Text`; matching uses the same
byte-oriented boundary predicates and nonmatching/empty boundaries return the
original view.
`ParseInt` has type `Text -> Int(signed, 64)` and requires `ParseError` in the
function error row. Its state-machine parser accepts only an optional sign and
ASCII decimal digits (with underscores only between adjacent digits), checks
signed 64-bit overflow before each accumulation, and
raises `InterpretError.InvalidNumber` for malformed or out-of-range input. The
compiler-known `parse_int` call lowers to this opcode. `FormatInt` has type
`Int(any width/sign) -> Text`; it uses Elisa's permanent string runtime so the
returned view remains valid after the instruction and is eligible for the direct
bytecode path without introducing a shell or host-language conversion. The
explicit `format_int` builtin remains the checked signed-`i64` spelling; broader
integer output is selected by `str`, f-strings, and `print` without changing the
value's static type.
`ParseFloat` has type `Text -> Float(64)` and shares the `ParseError` row. Its
validation machine requires a decimal mantissa and, when present, a complete
exponent before invoking the shared decimal evaluator; malformed input therefore
cannot silently become zero. Decimal text is bounded at 64 MiB. The evaluator
rescales its mantissa before applying fractional and explicit exponents, then
saturates exponent accumulation with those scales accounted for and bounds the
effective scaling walk at 4,096 steps. This prevents intermediate range loss
and unbounded exponent work, but does not specify correctly-rounded conversion.
`FormatFloat` has type `Float(32|64) -> Text` and copies
the core `%g` spelling into permanent storage before returning its view. These
opcodes are classified into the packed text dispatch family. `FormatBool` has
type `Bool -> Text` and emits canonical lowercase `true` or `false`; it is
classified in the same family and is eligible for the direct bytecode path.
`FormatNominal` has type `Path|Glob|Regex|Executable|Url -> Text`; it exposes
the underlying text representation of a text-backed nominal value for the
explicit `str(value)` facade. It is verified separately from `Copy`, so no
other implicit nominal-to-text conversion is introduced, and it is eligible
for the same interpreter and direct bytecode paths.
`FormatChar` has type `Char -> Text`; char constants use the shared text payload
and are copied into the text result without implicit widening elsewhere.
`FormatAggregate` has type `Array[T] | Map[K, V] -> Text`; it emits `[a, b]` or
`{key: value}` using insertion order and the same scalar spellings as the
corresponding `Format*` operations. The Python-compatible `str(value)` facade
selects `FormatChar`, `FormatInt`, `FormatFloat`, `FormatBool`, `FormatNominal`, or
`FormatAggregate` for the corresponding exact type and returns text unchanged
for text values; all integer widths use `FormatInt` without implicit numeric
coercion. Nominal and
aggregate conversion is explicit at this boundary rather than an implicit
coercion elsewhere. Binary ordering (`Less`, `LessEqual`, `Greater`,
`GreaterEqual`) accepts exact numeric types as before and also exact `Text`/`Char`
pairs. Text ordering is unsigned byte-lexicographic and is implemented
identically by the interpreter and direct bytecode helper; mixed families remain
verifier errors.
The `int(value)` and `float(value)` facades reuse `ParseInt`/`ParseFloat` for
text and return exact `i64`/`f64` operands unchanged; `bool(value)` is an exact
boolean identity. Lossy numeric and truthiness conversions are rejected before
emission, and all three names remain shadowable by source functions.
Exact-type `array + array` and `text + text` lower to the semantic `Concat`
operation rather than numeric `Add`. Array concatenation copies both inputs into
fresh value storage. Text concatenation copies both byte views into permanent,
length-aware Elisa runtime storage, so chained results and results involving
empty text do not borrow temporary buffers. Mixed element or collection types are
rejected statically. The same verified `Concat` operation is used internally for
`mapping.update(other)`: it copies the receiver map, replaces duplicate keys in
place, and appends new keys in source insertion order before rebinding the mutable
receiver.
Exact-type scalar arrays also support structural `==` and `!=`. The interpreter
compares lengths first and then elements deterministically from left to right;
empty arrays, slices, concatenated arrays, separate equal allocations, and shared
or copy-on-update storage therefore follow one value-semantic rule. Mixed array
element types remain static errors; nested arrays use the same recursive runtime
comparison within the supported six-level descriptor. The compact structural type
descriptor currently carries six array layers; a seventh layer is reserved for the
next migration step, where source typing will emit recursive table ids directly.
Statement-form `array.push(value)` and the Python-compatible
`array.append(value)` alias, together with `array.extend(values)`, are
ownership-safe SSA updates rather than hidden aliasing mutations. `push` constructs
a typed singleton and `append` has exactly the same contract; `extend` accepts the
receiver's exact array type; all three concatenate
into a fresh array value and rebind the receiver. Python's zero-argument
`array.pop()` and `array.pop(index)` are available in both expression and statement
position: their typed `PopArrayValue` result yields the removed element while
`PopArray` rebinds the receiver to a shortened view. The optional index is an
integer and supports Python's negative-from-the-end normalization. Both
operations reject an empty array or an out-of-range index with `IndexOutOfBounds`,
and no rebinding occurs on failure. Mutation discovery treats these calls as
assignments, so updates inside `if`, `while`, and `for` flow through the same typed
merge, header, latch, and exit parameters as explicit `<-` rebinding. Named
arguments, mismatched index types, and non-array receivers are rejected.
Mutable set bindings also accept Python's `values.discard(element)` spelling;
it lowers to the same typed `DeleteIndex` update as `values.remove(element)`,
but is restricted to set descriptors and remains a no-op when the element is
absent.
The statement-form `array.reverse()` method lowers to `ReverseArray`. It requires
a mutable array binding and zero arguments, emits an owned reversed array value,
and rebinds the receiver through the ordinary SSA state-machine path. The
interpreter and direct bytecode backend both preserve the exact element type and
leave empty arrays empty.
The statement-form `array.insert(index, value)` lowers to `InsertArray`. Its
index may use any integer type; Python-compatible negative and out-of-range
clamping is performed by the runtime, while the inserted value is checked
statically against the array element descriptor. The operation produces an
owned array and participates in the same mutation-name and CFG merge machinery.
The expression-form `array.copy()` lowers to `CopyArray`, preserves the complete
array element descriptor, and copies the flat payload into fresh runtime storage.
It is available for immutable and mutable arrays alike and has no mutation-name
side effect.
The expression-form `mapping.copy()` lowers to `CopyMap`, preserves the complete
key/value descriptor, and copies the interleaved pair payload into fresh runtime
storage. It is available for immutable and mutable maps alike and has no
mutation-name side effect.
The expression-form `array.count(element)` lowers to `ArrayCount`, returns a
`usize`, and compares elements with the same structural equality used by `==`.
The verifier requires an exact array element type and a valid `usize` result.
`array.find(element)` lowers to `ArrayFind` and returns the first matching
zero-based offset as signed `i64`, or `-1` when absent. `array.index(element)`
lowers to checked `ArrayIndex` and raises `IndexOutOfBounds` on a miss; the
verifier preserves the complete element descriptor for structural comparison.
The statement-form `array.sort(reverse: flag)` lowers to `SortArray` and, when
selected, `ReverseArray`. It requires a mutable array whose element type is a
scalar with a deterministic total order (`bool`, integer, float, `char`, or text),
copies the input into owned storage, and performs a stable insertion sort. Text
values compare by unsigned `sview` bytes. A dynamic reverse flag branches through
a typed merge before rebinding the owner; unsupported aggregate element types and
malformed instructions are rejected before execution. Both backends preflight
scalar homogeneity before copying the array, so a malformed sort cannot leave a
partial sorted copy in shared flat storage; the interpreter and bytecode backend
share the same result and failure behavior.
Dictionary values also expose Python's `mapping.get(key, default)` spelling. It
lowers to the same `IndexValid`-guarded CFG as `get mapping[key] else default`,
so the default expression is lazy and both branches merge one exact value type.
Mutable dictionaries additionally lower `mapping.pop(key)` and
`mapping.pop(key, default)` to the paired `PopMapValue`/`PopMap` operations.
`PopMapValue` returns the exact dictionary value type (or the typed default when
the key is absent), while `PopMap` removes the key into fresh map storage. A
missing key without a default raises `IndexOutOfBounds`; an absent-key `PopMap`
searches before allocating fresh storage, so a failed removal is storage-neutral.
The verifier rejects set descriptors, mismatched key/default types, and
immutable receivers before execution.
`mapping.setdefault(key, default)` lowers to the paired
`SetDefaultMapValue`/`SetDefaultMap` operations. The value operation returns the
existing value or the typed default, while the map operation rebinds the mutable
dictionary only when insertion is needed. Both operations require an exact map,
key, and default descriptor; set descriptors and mismatched types are rejected
by the verifier.
Lowering retains one mutability fact alongside every lexical binding. Plain locals,
parameters, loop variables, and match binders are immutable; `mutable` local type
markers and mutable parameters opt into SSA rebinding. `<-`, compound assignment,
`push`, `append`, and `extend` all check the same fact and produce the structured
`ImmutableBinding` issue before emitting an update. Scope truncation keeps names,
types, values, and mutability facts aligned across value blocks, match arms,
handlers, branches, and loops.
`mutable_array[index] <- value` lowers to the semantic `SetIndex` operation and
then rebinds the array's SSA name. Indexed `+=`, `-=`, `*=`, `/=`, `%=`, `&=`,
`|=`, `^=`, `<<=`, and `>>=` first enter an `Index` read state, apply the same
typed arithmetic or bitwise operation as scalar compound assignment, and finish
in `SetIndex`. The receiver must be mutable, the index must be an integer, and the
replacement must exactly match the element type. The interpreter checks bounds,
copies the source array into fresh value storage, replaces one element, and leaves
all aliases of the old array unchanged; invalid indices raise `IndexOutOfBounds`.
Membership lowers to the typed `Contains` operation. Array needles must exactly
match the element type; text accepts either an 8-bit `char` or a text substring.
Search is deterministic and linear, the empty text is contained in every text,
and `not in` remains the ordinary typed boolean `Not` of `Contains`. Consequently
membership composes with the existing branch-based short-circuit machinery.
Numeric range membership lowers to ordered control-flow states rather than
`Contains`. Ascending ranges first test `value >= low`, then test `value < high`
or `value <= high`; strict descending ranges first test `value <= start`, then
`value > end`. Each bound is evaluated exactly once, and `not in` applies the
ordinary typed boolean `Not` to the merged result. Strided range membership
accepts positive integer constants and typed integer expressions. After the
bounds states succeed, an alignment state tests `(value - start) % stride == 0`
for ascending ranges or `(start - value) % stride == 0` for descending ranges.
A dynamic stride uses `RangeCondition` for sign-aware bound tests and raises the
recoverable `RangeStepZero` error before alignment when it is zero; non-integer
strides remain type errors.
Integer ranges use the same CFG shape. `low..<high` is exclusive ascending,
`low..=high` is inclusive ascending, and `high..>low` is strict descending.
The range-owned stride spelling (`low..<high..step`) accepts a typed integer
expression; the latch adds or subtracts it according to direction, including after
`continue`. Dynamic steps use `RangeCondition` in the header to choose the
exclusive/inclusive/descending comparison mode and reject zero at runtime.
Python `range(stop)`, `range(start, stop)`, and `range(start, stop, step)` loop
forms are normalized to these same counter states; a negative literal step selects
the descending state machine, while a dynamic step selects by sign. No temporary
array or pair object is created.
Scalar statement `match` lowers to an ordered comparison-and-branch state machine.
Integer, float, boolean, character, and text literal arms are typed against the
scrutinee; pin patterns compare an existing binding, and binding/wildcard arms
form catch-alls. A guarded arm receives a distinct CFG state: a false guard resumes
the ordered pattern chain, and its pattern bindings cannot escape into later arms.
Numeric range patterns use two comparison states: the lower-bound state branches
to an upper-bound state only when `value >= low`, then `..<` or `..=` selects a
strict or inclusive upper comparison. Bounds are evaluated as typed constants,
and guards run only after both comparisons succeed.
Each arm has lexical bindings, while mutations of outer locals converge through
typed merge-block parameters. Structural patterns remain explicit errors until
structural IR values are available.
Expression-form scalar `match` uses the same ordered states but requires an
exhaustive arm set and lowers each arm's value expression through a typed
`match-result` merge parameter. Literal, pin, binding, wildcard, guard, and
ordered `|` alternatives are supported; arm bindings remain lexical. Structural
array expression matches are rejected until aggregate result merging is added,
while statement-form structural arrays use the `Length`/`Index`/`Slice` path
described above. Integer literal patterns are parsed in decimal or hexadecimal
form (including a sign), and an explicit `i8`/`u64`/other integer suffix is
accepted only when it matches the scrutinee type. Numeric range arms add a
lower-bound state followed by a strict or inclusive upper-bound state before
entering the value arm.
Unlabeled `break` and `continue` resolve through nested loop-target stacks. It produces structured
lowering issues for every unsupported construct; it never drops a statement or
expression silently.

Control-flow edges carry arguments through a function-owned flat pool. The verifier
requires each edge slice to match its target block parameters in both arity and type.
This is the backend-neutral equivalent of SSA phi nodes and is the basis for values
merged from mutable branches and loop backedges.

Logical and conditional expressions use those same CFG primitives. `and`/`or`
branch before lowering the right operand and merge through a typed block parameter,
so skipped calls, effects, and observations are genuinely not executed. Conditional
expressions likewise lower each value arm into a separate block rather than an eager
select instruction.

Array, text, integer-range, dictionary, and boolean quantifier comprehensions
use the same state-machine discipline.
The lowerer first probes the projection in a restored lexical scope to infer its
type(s) without retaining speculative instructions, then emits an empty typed
`MakeArray` or `MakeMap` as the loop-carried accumulator. Array/text iterables use
a `Length`/`Less` header that gates a checked `Index`; integer range iterables
instead carry the current typed counter, compare it with the bound in the header,
and add/subtract the typed stride in the latch. Dynamic strides use a
three-operand `RangeCondition` header (current, bound, step) with a mode stored in
`Instruction.integer`; it performs the sign-aware comparison and raises
`RangeStepZero` for zero. Range bounds and stride are lowered once, so ranges
never allocate a temporary collection. An
optional boolean filter branches to the append state or directly to the latch.
Array projections become singleton `MakeArray` values and `Concat` produces the
next accumulator. When an array projection uses two dictionary binders, the
canonical array binder comes from a `MapKeys` snapshot and the value binder is a
checked `Index` lookup before the projection executes. Dictionary projections
lower their key and value separately
and use immutable `SetIndex` copies, retaining duplicate-key replacement
semantics; range-backed dictionary projections use the same counter directly as
the key/value source. A two-binder dictionary iterable snapshots `MapKeys` once,
then performs a checked value lookup for the second binder on each iteration.
The `mapping.items()` spelling normalizes to that same source expression, so it
also snapshots keys once without materializing pair objects.
Array comprehensions may also use the Python-compatible two-binder
`zip(left, right)` iterable. The lowerer emits both source `Length` operations,
selects the shorter `usize` through a merge CFG, and performs one typed `Index`
per source in the body before projecting and concatenating the result.
They also accept the two-binder `enumerate(collection, start)` iterable. Its
header carries a zero-based source cursor for `Length`/`Index`; the body adds
the one-time, exact-`usize` start value only for the public index binder, so
non-zero starts do not alter collection bounds.
Dictionary comprehensions accept the same iterable and use the offset index as
the projected key while retaining the source element as the second binder.
Python's `range(stop)`, `range(start, stop)`, and `range(start, stop, step)`
spellings are accepted in array and dictionary comprehensions as well. They are
normalized to the same typed counter-driven CFG as explicit ranges, without
materializing an intermediate collection.
Header, latch, and exit block parameters carry both the accumulator and iteration
state through the flat edge-argument pool. Consequently the
interpreter, bytecode VM, and future native backends observe identical evaluation
order and allocation behavior. Quantifier headers carry a boolean accumulator
initialized to the identity (`false` for existential `any` / `exists`, `true` for
universal `all` / `forall`); a predicate branch targets the exit block on the
decisive result and otherwise advances to the latch. The initial shared IR
also lowers `each` queries as identity array comprehensions. It deliberately
lowers `count` queries as a `usize` accumulator with a conditional increment,
and `sum` / `product` queries as exact integer accumulators with identities 0 / 1.
Two-binder dictionary folds count entries or fold the value binder, respectively.
These folds and boolean quantifiers accept integer ranges through the same
counter-driven header/latch states, so no range collection is created. Boolean
quantifiers also accept two-binder dictionary iterables by snapshotting `MapKeys`
and looking up each value in the body state. Set literals and single-binder set
comprehensions use the same verified map storage with a canonical boolean marker and
an internal set descriptor marker that preserves source-level method typing.
Mutable set `.add` lowers to a typed `SetIndex` rebind and is duplicate-stable;
`.clear()` lowers to a typed empty `MakeMap` rebind, and `.remove(element)` lowers
to a typed `DeleteIndex` rebind with no-op missing-key behavior. A missing-key
`DeleteIndex` returns the original map before allocating replacement storage, so
the no-op is storage-neutral. Indexed access
remains outside this initial IR subset. Ordinary mutable dictionaries use the same
`.clear()` and `.remove(key)` operations with their declared key/value types, while
mutable arrays use `.clear()` to emit a typed empty `MakeArray` rebind. Query
forms with more than two binders and non-straight-line query predicates remain
explicitly rejected rather than lowered with guessed semantics.

Elisa value blocks lower their leading statements in a lexical binding scope and
then yield the tail expression. This makes the idiomatic multiline `return if ...:`
form executable while ensuring branch-local names do not leak past the value block;
mutations of already-existing outer SSA bindings remain visible as expected.
In a non-void ElisaScript function, a final expression also supplies the return
value. Earlier `return` statements still exit immediately; the final expression
is checked against the declared return type.

Elisascript also accepts the ML-style bare block spelling on binding and mutation
RHSs; no `do` introducer is required. A bare `=` introduces a fresh immutable
binding, while `<-` updates an existing mutable binding, and the final statement
is the block value:

```elisascript
foo =
    bar = 15
    baz = 25
    bar + baz

biz: mutable u8 = 25
biz <-
    bak = 25
    bok = 15
    bak + bok
```

The parser, semantic scope walk, and IR lowerer preserve those declaration versus
mutation rules, including shadowing inside nested value blocks. An annotated
assignment or mutation supplies the expected scalar type to its block: untyped
integer and floating literals in the block are checked and materialized directly
at that type, so the `u8` example does not need suffix noise. Out-of-range
literals remain compile-time type errors rather than silently truncating.

Straight-line `<-` mutation is reconstructed as an SSA name rebind: the
new expression result becomes the binding's current value and no memory slot is
introduced. Arithmetic and bitwise compound assignments use the same mechanism,
including `+=`, `-=`, `*=`, `/=`, `%=`, `&=`, `|=`, `^=`, `<<=`, and `>>=`.
Mutation across `if` fallthrough edges is reconstructed with typed
edge arguments and a fresh merge-block parameter. Loop-carried locals receive
typed header and exit parameters; initial entry, normal backedges, `continue`, and
`break` edges all pass the binding's current SSA value.

1. Add complete structural types and explicit ownership/region operations. The
   interpreter now replays the current suspended IR function frame and its active
   direct-call chain for `MultiReplay`/`MultiClone` with cloned SSA environments.
2. Define the artifact container and versioned metadata around the canonical IR
   bytes. The structural encoding and `u64` module fingerprint are already
   available for artifact correlation.
3. Continue extending the reference interpreter through the remaining structural
   and ownership operations. The initial scripting profile already executes
   verified scalar values, arrays/maps, filesystem and process primitives, error
   recovery, dynamic handlers, multi-shot continuations, and `observe` trace sites.
4. Lower the same verified modules to additional native/JIT targets and test each
   engine differentially against the interpreter. The bytecode backend already
   has typed dispatch classes, table preflight, a state-machine program counter,
   and direct guarded-recovery execution; unsupported dynamic effects continue to
   use the reference interpreter until their target lowering is defined.

## End-to-end execution boundary

`execute_elisascript_source` and `execute_elisascript_file` are the canonical
typed launch APIs. They validate the `.elisascript` suffix, parse and semantically
check the source, lower it to verified IR, lower that IR to bytecode, and execute
the bytecode with the supplied entry function, arguments, observation sink,
runtime storage, and step limit. Source failures remain
`ElisascriptSourceError`; runtime failures remain `InterpretError`, so adapters
can distinguish a malformed script from a failed invocation without introducing
a result-shaped sentinel. The bytecode engine selects direct state-machine
dispatch when supported and otherwise preserves interpreter semantics for dynamic
effects and continuations.
The file-backed boundary also rejects embedded NUL bytes before tokenization;
source cannot be silently truncated by the C-string compatibility boundary.
Source bytes are strict UTF-8 at that boundary as well: incomplete, overlong,
surrogate, and out-of-range sequences raise `ElisascriptSourceError.InvalidUtf8`
before parser allocation. The same `EsEncoding::Utf8Cursor` contract is reused
by typed text streams, while binary stream modes remain byte-preserving.
It also rejects source files larger than 4 MiB before allocating the parser arena,
keeping source-size arithmetic and compiler memory use bounded at the host
boundary. Hosts that need to process generated code should split it into several
modules and call the same loader for each file.
The filename C-string used by that boundary is likewise bounded to 4 KiB before
the `.elisascript` suffix check; unterminated or oversized host names become
`ElisascriptSourceError.InvalidExtension` instead of triggering an unbounded
scan.
The source C-string adapter permits a terminator exactly at the 4 MiB content
boundary but never probes beyond that bounded terminator position; an
unterminated input that reaches the limit is rejected as
`ElisascriptSourceError.SourceTooLarge`.
Hosts with an explicit in-memory byte span can use
`lower_elisascript_source_bytes` (or its `_with_handlers` variant), which checks
the supplied length for NUL bytes before constructing the terminated parser buffer.
`execute_elisascript_source_bytes` and
`execute_elisascript_program_source_bytes` expose the same length-delimited
guarantee at the execution boundary.
The `EsIr` source extension keeps its bounded C-string scan, extension cursor,
and semantic-error predicate private; only the size constants, extension checks,
the bounded `elisascript_source_filename_length` adapter, and source-to-IR loader
entrypoints are public. This keeps parser state and unbounded lexer scans out of
the cross-module API while preserving the `.elisascript` boundary.

The launcher-facing ABI is `main(arguments: darray[sview]) -> i64`. The program
runner appends each host argument to caller-owned runtime storage, passes one typed
array value to `main`, and returns the signed 64-bit result as the process status.
Before copying, it bounds the aggregate argument text at 64 MiB and checks the
argument vector at one million elements and the aggregate text at 64 MiB, and
checks the existing runtime `u32` storage span; exceeding any limit remains a typed
`InterpretError.ArgumentMismatch` rather than partially publishing an argv array.
`validate_elisascript_entrypoint` rejects a missing or differently typed `main`
before lowering to bytecode; source and runtime failures continue to use their
ordinary `error[...]` families.
The `EsIr` runner extension exposes request/diagnostic records and the canonical
execution entrypoints from `public:` sections, while CLI/entrypoint cursors and
diagnostic/signature helpers remain `private:` implementation state. This keeps
the launcher ABI narrow without making state-machine details part of the module
contract.
Launchers that need a host-facing message can use
`execute_elisascript_program_file_diagnostic`. It runs the same canonical
pipeline but records a stable phase (`source`, `entrypoint`, `bytecode`, or
`runtime`) and detail in `ElisascriptProgramDiagnostic`; it also preserves the
exact `ElisascriptSourceError`, `ElisascriptEntrypointError`, or `InterpretError`
variant behind a corresponding `*_error_known` flag. It does not weaken the
typed error behavior of the ordinary runner APIs. Bytecode failures retain the
first `IssueKind` plus its block, value, and trace identifiers behind
`bytecode_issue_known`; borrowed function/message views are intentionally not
stored beyond the lowered-module region. The driver renders that exact issue
kind while keeping the aggregate phase stable. Source lowering failures retain
the first `LowerIssueKind` and source line behind `source_lower_issue_known`,
with the same no-borrowed-message rule.
Parser and semantic source failures also retain their first typed kind and
bounded source coordinates before the parser region is released: parser failures
preserve `Ast::ParseErrorKind`, semantic failures preserve
`Semantic::DiagnosticKind`, and both carry line/column/end-column data. The
parser context token and semantic name/expected/actual/detail text plus typed
expected/actual counts are copied
through a 4 KiB-per-field permanent-storage bound; oversized fields set an
explicit truncation flag. A deterministic FNV payload hash is retained for
differential correlation, and the driver now renders parser context and semantic
messages from the bounded owned fields. Human-readable source-span/caret
rendering beyond the retained coordinates and exact diagnostic snapshots remain
follow-up work.

The reference command-line adapter lives in `src/driver/elisascript.elisa`. Its
only raw host boundary is `main(argc, argv)`: it drops the executable name,
constructs a `darray[sview]` without shell splitting or environment expansion,
and sends that request through `parse_elisascript_cli`. The parser requires a
`.elisascript` source path, rejects embedded NUL bytes in the source and every
typed argument, and preserves every
remaining argv element—including spaces and empty strings—as one typed value.
The reusable request record is reset before validation, including on a rejected
parse, so mode, color, strict-engine, option-boundary, source, and argument
state from an earlier invocation cannot leak into a later one.
It enforces the same public launcher budgets as the native adapter before
allocating the request (`EsIr::LauncherLimits::ARGUMENTS` script arguments and
`EsIr::LauncherLimits::ARGUMENT_BYTES` aggregate script-argument bytes), reporting
typed `TooManyArguments` or `ArgumentsTooLarge` errors instead of relying on
the host-side collector alone.
Usage failures return status `2`; allocation, source, entrypoint, bytecode, and
execution failures return status `1`; a successful script's signed `i64` result
is returned unchanged. Failure diagnostics include the source path and a phase
(`source`, `entrypoint`, `bytecode`, or `runtime`) before a stable detail. For
source, source-lowering, entrypoint, runtime, and bytecode failures, that detail
is the exact enum or verifier-issue kind spelling retained by the diagnostic
record. The underlying
library APIs continue to propagate their typed `error[...]` families. The adapter copies the borrowed source view into a NUL-terminated
buffer only at the file-I/O boundary, so the script itself never receives a
raw C string or a command-string escape hatch. The public launcher contracts
are `EsIr::LauncherLimits::ARGUMENTS` (1,048,576 script arguments),
`EsIr::LauncherLimits::ARGUMENT_BYTES` (64 MiB aggregate text), and the
derived raw-ABI ceiling `EsIr::LauncherLimits::ARGC`. The native
`main(argc, argv)` shim rejects an `argc` outside the corresponding executable
plus-script range before walking host argv storage, and rejects a source path
whose borrowed view would place its NUL terminator at or beyond the shared
`EsIr::ES_RUNTIME_DEFAULT_MAX_CSTRING_BYTES` host-string ceiling. These checks
also bound every raw host-argument C-string scan before it becomes a borrowed
view, and stop admitting script arguments once their aggregate text reaches
the same 64 MiB launcher budget. This keeps the ABI boundary subtraction-safe;
the runner still applies its own typed argv and runtime-storage checks after
parsing. Launcher stderr writes retry bounded `EINTR` interruptions and short
positive progress, resetting the interruption budget after progress; zero,
over-counted, or exhausted writes terminate the diagnostic without silently
advancing beyond its borrowed message.
The driver rejects the stricter 4 KiB filename ceiling before allocating the
terminated source path and suppresses echoing an overlong borrowed path in that
failure diagnostic. The raw `argv` collector uses the same ceiling for the
source slot, avoiding a long host-memory scan before rejection and retaining
the source-phase filename-limit detail.

EsBuildScheduler adds the execution-facing queue contract over EsBuild. It
rebuilds a deterministic ready queue from planned nodes and succeeded
dependencies, admits at most the graph's declared parallelism, records exact
fingerprint cache hits, and turns dispatch, completion, failure, and
cancellation into explicit state-machine events. Queue entries are rebuilt
after every mutation so completed or running nodes cannot remain dispatchable;
aggregate completed-node and cache-hit bounds are validated in separate
subtraction-safe steps before active-node capacity is computed;
cache hits must also consume a currently queued ready node, preventing an
out-of-order cache completion after queue corruption; validation also rejects
cache entries for unknown graph nodes, manually injected queue entries whose
dependencies are not complete, and ready queues that are not in the ascending
order emitted by graph traversal. Cancellation is
rejected once the embedded graph has already succeeded; a ready scheduler can
also be cancelled before `Begin`, which marks every planned node cancelled and
keeps the embedded graph and scheduler ledgers in sync. A ready scheduler
cannot carry a pre-injected dispatch queue (preloaded cache entries remain
valid for the first refresh). Queue membership uses binary search over that
strictly ascending invariant, and queue validation checks adjacent entries for
order and duplicates in one pass. Rebuilding readiness scans graph nodes once,
so a wide graph of independent targets does not incur a quadratic queue search.
Cache entries likewise require strict target-name order; adjacent validation
rejects duplicate or unsorted records in one pass, and cache-hit admission uses
binary search instead of scanning every prior cached target.
Incremental admission derives those entries directly from the validated
graph-aware `UpToDate` decisions, then sorts them by target name. Callers do not
need to seed a redundant scheduler cache before admitting a prior manifest.
BuildBatch applies and validates cache hits through the same logarithmic lookup,
avoiding a per-target scan of the entire cache.
The scheduler mirrors its active/completed ledger into the embedded graph and
reconciles both state machines, so a forged complete or failed scheduler cannot
hide graph progress. Cancellation acknowledgement drains the ready queue and
marks all remaining planned nodes cancelled, so the terminal scheduler and graph
ledgers contain no pending work. Failure follows the same fail-closed rule:
the failing node is recorded immediately, remaining planned nodes are
cancelled, and the scheduler enters `Failing` while active siblings stop. The
ready queue is cleared and dispatch/cache hits are blocked; sibling results may
still be accounted, or host-confirmed stop/reap acknowledgement drains them.
Only then does the scheduler reach `Failed`, preserving the original failure
instead of reporting ordinary user cancellation.

`EsLuaBundleMetadata` is the first typed seam for the W04 Lua bundle metadata
replacement. `parse_metadata_arguments` accepts exact or unambiguous argparse-
style long options, preserves repeated setting/command entries with
last-value lookup, rejects post-`--` positional data, applies argparse's exact
negative-number exception for separated values, and applies per-argument,
aggregate metadata, NUL, path, and entry-count ceilings before a host adapter
can create or replace a destination. Its pure `metadata_facts_from_processes`
seam classifies bounded
typed process outcomes, applies the Git HEAD/branch/status fallback rules, and
trims UTF-8 Unicode whitespace before `render_metadata_json` validates the
injected UTC-second shape and calendar ranges and emits bounded, deterministic, sorted
`ensure_ascii` JSON. `metadata_host_command` additionally produces validated,
shell-free `ProcessCommand` plans for `hostname`, `uname -a`, and the three
Git queries, with explicit child working-directory, locale, stdio, failure,
and bounded-timeout policy. The effectful process/clock adapter, atomic
publication, and acceptance evidence remain open; `EsLuaBundlePublication` now
provides the pure admission state machine for exclusive sibling staging,
paired parent/staging descriptor ownership, bounded writes, rename
acknowledgement, directory sync, and failure preservation. Typed parent/staging
proofs bind device, inode, opaque descriptor token, owner token,
regular/private/single-link staging, and the exact parent device/inode before
the publish edge. `Sync` reaches `Staged` only while both descriptors remain
open; `Publish` and its acknowledgement are rejected after either descriptor
has been closed, and `Close` is rejected while `Publishing` until the host
reports `PublishAck` or `OutcomeUnknown`. Close is cleanup rather than
publication authority. If rename or post-rename directory durability
acknowledgement is lost after that edge, the machine enters
`PublishedUncertain` through `OutcomeUnknown` and refuses to relabel the
publication as an ordinary failure.
