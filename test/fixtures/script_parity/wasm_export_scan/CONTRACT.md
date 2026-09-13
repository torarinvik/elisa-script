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
- `@link_name(...)` accepts either a quoted, possibly empty string or an ASCII
  identifier. A non-empty pending name survives blank and `#` comment lines;
  the last annotation wins. It attaches only to the next recognized export.
  Any other nonblank, non-comment line clears it. Empty quoted names are not
  emitted. Implicit `main` rows never inherit it.
- Explicit declarations match the Python `EXPORT_RE` whole-line grammar:
  `export fn IDENT(params) [-> type] [= IDENT(::IDENT)*]`. The target defaults
  to the public name and the return type defaults to `void`. Unmatched
  export-looking text is ignored. Duplicate public names fail with
  `duplicate WASM export 'NAME' on line N` before parsing that row.
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
- Parameter shape errors identify the exported function and original text.
  Invalid parameter names, nullable types, and unsupported ABI types preserve
  Python's exact message and validation order. If no export or implicit main
  remains, fail with ``WASM source has no exported function; add `export fn
  name(...) -> T = target` ``.

## `read_flat_source` observable contract

- Resolve each path before cycle/dedup checks. Detect a path already on the
  active stack before checking the global seen set. A cycle reports the full
  resolved chain; a repeated completed include contributes the empty string.
- The optional `seen` set and active `stack` list are caller-owned and mutated:
  add the resolved file to `seen`, then to `stack` before reading. Successful
  reads pop the stack; a read/decode/child error leaves those mutations in
  place because the Python implementation has no `finally` cleanup.
- Require a regular file and strict UTF-8. Relative includes resolve against
  the including file's resolved parent; absolute includes are used directly.
  Expand includes depth-first in source order, without adding a newline at the
  include site. Preserve each non-include line and ending yielded by Python's
  `splitlines(keepends=True)`.
- Python `Path.read_text` universal-newline translation converts CRLF and bare
  CR to LF before `splitlines(keepends=True)`. The Elisascript port must make
  that normalization explicit. Include directives are whole lines matching
  optional indentation and optional `#` before `include`, with a single- or
  double-quoted nonempty path and no trailing text.
- Beyond LF, Python `splitlines` also recognizes vertical tab, form feed, NEL,
  and Unicode line/paragraph separators. Their line-number and splice behavior
  must be pinned by fixtures or explicitly excluded from the supported source
  encoding contract; do not silently assume LF-only splitting is equivalent.
- Explicit failures include `missing source/include: RESOLVED` and
  `cyclic include while building WASM: CHAIN`. For any CLI/IPC adapter, map
  those failures deterministically and preserve the resolved paths.

## Required acceptance matrix

Every case must compare the pinned Python reference and Elisascript adapter on
decoded structured output or exact failure status/diagnostic. Also compare
valid source cases with `src/driver/emit_wasm_exports.elisa`; that emitter is an
AST-based implementation, so malformed-text cases are Python-vs-Elisascript
only unless they are valid Elisa programs.

| Case group | Required cases |
| --- | --- |
| Record shape | zero parameters, default/no return, explicit target, line numbers, source order, exact optional-key presence |
| ABI | every scalar mapping, `cstr`, `&`, `&&`, nullable, unsupported aggregate, modifier/whitespace normalization |
| Parameter scanner | nested delimiters including `{}`, quoted commas/equals, escapes, empty segments, missing colon, invalid name |
| Link annotation | quoted/bare, blank/comment retention, overwrite, empty, dangling, reset by ordinary text, implicit-main exclusion |
| `main` | implicit position and fields, repeated definitions, explicit-before/after behavior, duplicate line diagnostic |
| Invalid source | ignored malformed export forms and exact no-export failure |
| Include graph | nested/absolute/relative, duplicate and diamond include order, cycle chain, missing file, no-newline splice, CRLF/bare-CR normalization, empty file |
| Bounds and failure | bounded file/aggregate bytes, include depth/count, unreadable and invalid UTF-8 input, no partial success output |
| Integration | structured protocol consumed by the pinned `wasm_build.py` caller; no Python scanner on the accepted replacement path |

Existing pinned Python tests cover only a subset: selected `int`/`i64` and
`cstr` behavior, one unsupported aggregate, duplicate exports, quoted link
names, and three positive build-artifact parity examples. They do not establish
the matrix above. This document is an acceptance contract, not evidence that
the Elisascript port or parity has been implemented or run. Compiler/script
validation remains disabled until explicitly reauthorized.
