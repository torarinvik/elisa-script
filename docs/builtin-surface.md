# Builtin surface and typed registry

The first Q03 vertical slice now has one shared registry at
`vendor/elisa-compiler/src/semantic/builtin_registry.elisa`. Each registered
row owns the spelling, receiver category, required/maximum arity, canonical
argument-type descriptor, return type, effect row, error row, and semantic IR
opcode name. The registry is namespaced
as `EsBuiltin` and exposes only its contract type and lookup functions; helper
implementation details remain private to the module as the registry grows.
Receiver methods use the same record through `typed_builtin_method_spec`; the
first receiver-aware family is `Text`, covering case conversion, boundary
predicates, replacement, joining, line splitting, text predicates, and all four
trim modes.

The current strict scalar/text slice contains these 23 spellings:

| Family | Spellings | Contract shape |
|---|---|---|
| Length and predicates | `len`, `contains`, `is_empty`, `isempty`, `is_nonempty`, `nonempty` | fixed arity; `usize` or `bool` result |
| Text conversion | `str` | one value to `sview` |
| Text predicates | `starts_with`, `startswith`, `ends_with`, `endswith` | two text values to `bool` |
| Text transforms | `replace`, `strip`, `trim`, `lower`, `upper`, `casefold` | text result; `casefold` currently reuses `LowerText` until a Unicode-aware opcode exists |
| Numeric parsing/formatting | `parse_int`, `format_int`, `parse_float`, `format_float` | checked `i64`/`f64` conversions; parsers require `ParseError` |
| Scalar formatting | `format_bool`, `format_char` | one scalar to `sview` |

The receiver-aware `Text` rows currently cover `lower`, `upper`, `casefold`,
`starts_with`/`startswith`, `ends_with`/`endswith`, `replace`, `strip`,
`trim`, `lstrip`, `rstrip`, `join`, `splitlines`/`split_lines`, and the
zero-argument character-class predicates `isdigit`, `isdecimal`, `isnumeric`,
`isalpha`, `isalnum`, `isspace`, `islower`, `isupper`, `isascii`, and
`isprintable`, plus the one-argument `removeprefix` and `removesuffix`. Their
arities exclude the receiver and are checked separately from the global
spellings; `join` requires one `darray[sview]` argument and returns `sview`,
while both line-splitting aliases take no arguments and return `darray[sview]`.

Semantic builtin seeding consults `EsBuiltin::typed_builtin_spec` and stores
the row's `arity_min`, `arity_max`, `return_type`, `effects`, `errors`, and
`argument_types`, `effects`, `errors`, and `opcode` on the qualified semantic
symbol. This removes the former untyped
`contains` duplicate and lets direct-call arity checking see the registry
contract. Receiver unknown-method admission and the text-method return-type
inference adapter also consult
`EsBuiltin::typed_builtin_method_spec("Text", method)`, while legacy
collection/path names remain in a compatibility list until their structural
descriptors migrate. The lowerer obtains arity/named-argument shape, result
types, and parser error requirements from the same row before selecting the
existing IR opcode; the shared text-case helper also uses the registry
result/opcode metadata for global and receiver forms. Firmly inferred `Text`
receivers additionally use the row's receiver-excluded arity range at the
semantic boundary and emit the same structured `ArityMismatch` form as direct
calls; unknown receivers remain conservative and continue through ordinary
UFCS resolution. Unknown names continue to use the legacy seed path until
their richer signatures are migrated. The same receiver check validates the
registry's positional `text` argument slots for literal and firmly inferred
values, emitting the existing literal/firm argument mismatch diagnostics;
structural descriptors such as `darray[text]` remain deferred until their
element IDs are available to inference.

Run the compiler-free audits:

```sh
bash scripts/check_builtin_surface.sh
bash scripts/check_builtin_registry.sh
```

`check_builtin_surface.sh` still protects the complete legacy seed/lowerer
surface, including temporary append-only seed spellings during migration.
`check_builtin_registry.sh` verifies every registry row has a lowerer branch,
an existing IR opcode, semantic metadata preservation, and a lowerer
return/error consumer. It also verifies the receiver-aware `Text` method rows
and their method-dispatch branches; boundary, replacement, and trim helpers
now consume receiver-specific result/opcode and call-shape rows, while the
receiver semantic checker consumes the registry arity range. Both checks are static by design while
compiler execution remains suspended by the resource-safety gate.

The remaining Q03 work is intentionally explicit: migrate aggregate and
variadic signatures, receiver method families, generic/container result
descriptors, effect and error sets with structured IDs, and verifier-side
opcode/type compatibility. New builtins must not be added to the legacy seed
list alone; add a registry row and extend the static audit first.
