# Builtin surface and typed registry

The first Q03 vertical slice now has one shared registry at
`vendor/elisa-compiler/src/semantic/builtin_registry.elisa`. Each registered
row owns the spelling, receiver category, required/maximum arity, canonical
argument-type descriptor, return type, effect row, error row, and semantic IR
opcode name. The registry is namespaced
as `EsBuiltin` and exposes only its contract type and lookup functions; helper
implementation details remain private to the module as the registry grows.
Receiver methods use the same record through `typed_builtin_method_spec`; the
receiver-aware families are `Text` and `Regex`, covering case conversion,
boundary predicates, replacement, joining, line splitting, text predicates,
all four trim modes, and reusable Python/Perl-shaped regex matching,
capturing, splitting, and replacement.

Source declarations take precedence over registry-backed Text spellings.
Semantic receiver diagnostics and lowerer dispatch both require that no direct
source function owns the method name, and qualified `os`, `os.path`, `shutil`,
`subprocess`, and `re` normalization applies the same guard to the normalized
callable name. This keeps local or module-qualified code from being silently
rewritten into an unrelated builtin. When a source function owns the method
spelling, the lowerer forwards the receiver as its first positional argument
through the ordinary typed call path; generic UFCS calls therefore retain the
same signature, default-argument, effect, and error checks as direct calls.
The source-declaration test intentionally ignores line-zero registry seed rows;
otherwise a seeded global such as `contains` would incorrectly suppress its
receiver contract.

The compact registry currently contains 202 global spellings, 42 Text receiver,
10 Regex receiver, 9 Map receiver, 4 Set receiver, and 14 Array receiver spellings. The table below names the strict
scalar/text/regex core; filesystem, directory, process, environment, stream,
and time families use the same row format and are covered by the registry
audit.

The registry also carries a visibility marker. Public rows are source-facing
Elisascript contracts and are enumerated by `typed_builtin_names()`. Private
rows are compiler-generated intrinsics; `__fstr` is the first such row, kept
out of the public list while its seeded semantic symbol, `sview` result
inference, variadic shape, and f-string lowerer all consume the same
`visibility: "private"` contract.

| Family | Spellings | Contract shape |
|---|---|---|
| Length and predicates | `len`, `contains`, `is_empty`, `isempty`, `is_nonempty`, `nonempty` | fixed arity; `usize` or `bool` result |
| Text and scalar conversion | `str`, `int`, `float`, `bool` | one value to `sview`, checked scalar parse, or exact identity |
| Text predicates | `starts_with`, `startswith`, `ends_with`, `endswith` | two text values to `bool` |
| Text transforms | `replace`, `strip`, `trim`, `lstrip`, `rstrip`, `lower`, `upper`, `casefold` | text result; `casefold` currently reuses `LowerText` until a Unicode-aware opcode exists; trim aliases select both/left/right modes |
| Text aggregates | `partition`, `rpartition`, `split`, `split_lines`, `splitlines`, `join` | `darray[sview]` split/partition results and typed `join(darray[sview], text) -> sview`; split accepts an optional signed `i64` `maxsplit` at named slot 2 |
| Array order aggregates | `reversed`, `sorted` | one array input preserves the concrete element type; `sorted` accepts an optional positional or named `reverse: bool` and lowers through the checked array state machine |
| Trace observation | `observe` | one `any` value to `void`; emits a backend-independent `Observe` instruction only when no source declaration shadows the spelling |
| Runtime assertion | `assert` | one `bool` value to `void`; records the registry-declared `AssertionError` and emits the verified `Assert` instruction |
| Panic control | `panic` | zero or one positional `any` message; records `Abort.Panic` and emits the non-recoverable `Panic` instruction |
| Error propagation | `raise` | one declared `Error.Tag` reference or constructor; registry-owned `error -> void`/`Raise` identity combines with declaration-authoritative payload validation |
| Dynamic continuation | `resume` | literal handler `text` plus one `any` payload; registry-owned exact arity and callback-shape metadata combines with enclosing return-type equality |
| Console output | `print`, `println`, `echo`, `eprint` | variadic typed values with `sep: sview`, `end: sview`, and `flush: bool` controls; registry rows select `WriteStdout` or `WriteStderr` and the shared `Console.Write`/`ConsoleError` contract |
| Numeric absolute value | `abs` | one signed integer or float to the same exact numeric family; registry identity is the verified `Negate` primitive with `Compare,Negate,Select` lowering, while polymorphic inference preserves the operand type |
| Polymorphic extrema | `min`, `max` | one orderable array or two-or-more orderable values; registry rows select the verified `SortArray`/`Index` composition while inference preserves the element family |
| Map projections | `keys`, `values` | one dictionary to a concrete key/value array; registry rows select `MapKeys` or `MapValues` while structural inference preserves descriptors |
| Numeric folds | `sum`, `product` | one iterable/range plus optional typed `start`; registry rows select `Add` or `Multiply` inside the state-machine fold while polymorphic inference preserves the accumulator family |
| Boolean quantifiers | `any`, `all` | one iterable/range with short-circuit state-machine lowering; registry rows select the `Equal` result primitive and preserve boolean output |
| Numeric parsing/formatting | `parse_int`, `format_int`, `parse_float`, `format_float` | checked `i64`/`f64` conversions; parsers require `ParseError` |
| Scalar formatting | `format_bool`, `format_char` | one scalar to `sview` |
| Regex facades | `matches`, `replace_regex`, `split_regex`, `find_regex`, `capture_regex`, `captures_regex` | text/`Regex` operands; `bool`, `sview`, or `darray[sview]` result |

The global regex facades `matches`, `replace_regex`, `split_regex`,
`find_regex`, `capture_regex`, and `captures_regex` are registry-backed as
well. Their descriptors distinguish text haystacks, nominal `Regex` patterns,
and replacement text; the aggregate forms preserve a `darray[sview]` result
through structural inference.

The receiver-aware `Text` rows currently cover `len`, `lower`, `upper`, `casefold`,
`starts_with`/`startswith`, `ends_with`/`endswith`, `replace`, `strip`,
`trim`, `lstrip`, `rstrip`, `join`, `splitlines`/`split_lines`, and the
zero-argument character-class predicates `isdigit`, `isdecimal`, `isnumeric`,
`isalpha`, `isalnum`, `isspace`, `islower`, `isupper`, `isascii`, and
`isprintable`, plus the one-argument `removeprefix` and `removesuffix`. The
one-argument `contains` method is also registry-backed. Their arities exclude
the receiver and are checked separately from the global; `count` likewise
requires one text needle and returns `usize`; `find` and `rfind` each accept
one text needle and return `i64` with `-1` for a miss; `index` and `rindex`
also accept one text needle, return `i64`, and require `IndexOutOfBounds` on a
miss; `partition` and `rpartition` accept one text separator and return a
three-element `darray[sview]`; `is_empty`/`isempty` and
`is_nonempty`/`nonempty` are zero-argument boolean predicates; `len()` is a
zero-argument text-length method returning `usize` and lowers to the same
verified `Length` operation as global `len(text)`; `split` and
`rsplit` accept an optional text separator and signed `i64` `maxsplit`, with
`maxsplit:` permitted only for the second argument.
`join` requires one `darray[sview]` argument and returns `sview`,
while both line-splitting aliases take no arguments and return `darray[sview]`.

The receiver-aware `Regex` rows cover `search`, `match`, `fullmatch`,
`findall`/`find_all`, `capture`/`captures`, `capture_names`, `split`, and `sub`.
Matching, finding, capturing, and splitting take one positional text haystack
and return `bool` or `darray[sview]` as declared; `capture`/`captures` preserve
empty slots for proven `?`-optional groups, and `capture_names` returns the
first match's positional group-name descriptors (empty text for unnamed
groups), while `sub` takes positional replacement and haystack text and returns
`sview`. Regex rows exclude the receiver from arity, reject named arguments,
reuse the existing `RegexSearch`, `RegexFind`, `RegexCapture`, `RegexSplit`,
and `RegexReplace` opcodes, and preserve the same source-declaration precedence
in semantic checking, inference, and lowering.

Semantic builtin seeding consults `EsBuiltin::typed_builtin_spec` and stores
the row's `arity_min`, `arity_max`, `return_type`, `effects`, `errors`, and
`argument_types`, `effects`, `errors`, and `opcode` on the qualified semantic
symbol. This removes the former untyped
`contains` duplicate and lets direct-call arity checking see the registry
contract. Receiver unknown-method admission and the text/regex method return-type
inference adapters also consult `EsBuiltin::typed_builtin_method_spec`, while legacy
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
Regex receiver checks apply the same literal and firm text contract to haystacks
and replacement arguments, while structural descriptors such as `darray[text]`
remain deferred until their element IDs are available to inference.

Global registry rows now also receive semantic arity, named-argument, and
conservative scalar/text/collection descriptor checks before lowering. The
checker ignores unknown expressions and line-zero seed symbols, and source
functions with the same spelling retain precedence.

Receiver return-type inference applies the same source guard, including its
legacy Text fallback rows, so a shadowing source UFCS function cannot inherit a
registry result type merely from its spelling.

Regex receiver dispatch (`search`, `match`, `fullmatch`, find/capture aliases,
`split`, and `sub`) now applies the same source-callable guard in lowering and
return-type inference; a source function with one of those names is not silently
rewritten as a regex operation.

Map receiver dispatch covers `keys()`, `values()`, `copy()`, `get(key, default)`,
`pop(key, default?)`, `setdefault(key, default)`, `update(other)`, `remove(key)`, and
`clear()`. The projections and copy
take no arguments, while the mutating accessors use exact positional shapes and
preserve the dictionary's concrete descriptor in the lowerer. They emit the
verified `MapKeys`/`MapValues`/`CopyMap`/`IndexValid`/`PopMapValue`/
`SetDefaultMapValue`/`Concat`/`DeleteIndex`/`MakeMap` identities and retain
source-function shadowing precedence.

Set receiver dispatch covers `add(value)`, `remove(value)`, `discard(value)`,
and `clear()`. These rows preserve the set marker in the IR's map-shaped
storage while selecting the verified `SetIndex`, `DeleteIndex`, and `MakeMap`
identities; `discard(value)` is a typed set-only `DeleteIndex` row with
no-op-on-missing semantics.

Array receiver dispatch currently covers `copy()`, `pop(index?)`, `reverse()`,
`sort(reverse?)`, `insert(index, value)`, `remove(value)`, `count(value)`,
`find(value)`, `index(value)`, and `contains(value)`, plus `push(value)`,
`append(value)`, `extend(array)`, and `clear()`. These rows preserve
source shadowing and element-typed checking while selecting the verified
`CopyArray`, `PopArrayValue`, `ReverseArray`, `SortArray`, `InsertArray`, `RemoveArray`,
`Concat`, `MakeArray`, `ArrayCount`,
`ArrayFind`, `ArrayIndex`, and `Contains` paths;
recursive element descriptors remain in the existing lowerer type wall.

Run the compiler-free audits:

```sh
bash scripts/check_builtin_surface.sh
bash scripts/check_builtin_registry.sh
```

`check_builtin_surface.sh` still protects the complete legacy seed/lowerer
surface, including temporary append-only seed spellings during migration.
`check_builtin_registry.sh` verifies every registry row has a lowerer branch,
an existing IR opcode, verifier coverage, semantic metadata preservation, and a lowerer
return/error consumer. It also verifies the receiver-aware `Text` method rows
and their method-dispatch branches; boundary, replacement, trim, and regex helpers
now consume receiver-specific result/opcode and call-shape rows, while the
receiver semantic checker consumes the registry arity range and rejects named
arguments for rows that intentionally expose no parameter names. Both checks are static by design while
compiler execution remains suspended by the resource-safety gate.

The `Text.join` `darray[text]` argument is now checked against the interned
container element row when the argument has a firm annotated array type. Unknown
expressions and untyped array literals remain conservative until recursive
container inference can preserve their element descriptors.

The same structural channel now preserves the registry's `darray[text]` result
row for `split`, `rsplit`, both line-splitting aliases, and both partition
aliases whenever the `darray[sview]` row is interned. This lets later indexing
and `join` calls consume the precise element type without widening every result
to an unparameterized container.

The remaining Q03 work is intentionally explicit: migrate aggregate and
variadic signatures, receiver method families, generic/container result
descriptors, effect and error sets with structured IDs, and verifier-side
opcode/type compatibility. New builtins must not be added to the legacy seed
list alone; add a registry row and extend the static audit first.
