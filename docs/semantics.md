# Elisascript semantic layer

Elisascript retains Elisa's full semantic analyzer and adds scripting-profile
rules through focused passes and builtins. Weakening or deleting Elisa checks would
conflict with the goal of making Elisascript exceptionally strongly typed.

## Retained semantic sources

All semantic source files are retained. The directory currently contains the
`semantic.elisa` facade plus every file it includes; there are no unreachable
semantic files in the copied snapshot.

The retained analysis covers, among other areas:

- Symbol collection and name resolution
- Primitive, nominal, and structural type inference
- Generics, overloads, and interfaces
- Algebraic variants and exhaustive matching
- Error sets and error handling
- Effects and capability grants
- Regions, ownership, borrowing, affine and linear values
- Contracts, refinements, laws, and termination
- Typestates and state machines
- Concurrency and transfer safety
- Native/ABI/unsafe boundaries
- Diagnostics and source rendering

Elisascript-specific passes live beside these sources and are included explicitly
by the semantic facade.

## Initial typed-literal semantics

The parser's call-shaped typed literals resolve through compiler-owned builtins:

| Prefix | Arity | Result type |
|---|---:|---|
| `path` | 1 | `Path` |
| `glob` | 1 | `Glob` |
| `regex` | 1 | `Regex` |
| `exe` | 1 | `Executable` |
| `url` | 1 | `Url` |

These are ordinary function symbols for resolution, arity checking, and inference.
Their result types are nominal compiler-known types, which also resolve in type
annotations:

```elisa
source: Path = path"src/main.elisa"
pattern: Regex = regex"(?<name>[a-z]+)"
```

Nominal values cannot implicitly initialize primitive scalars:

```elisa
bad: i64 = path"src"  # type error: expected i64, got Path
```

Integer literals accept decimal, binary (`0b`/`0B`), hexadecimal (`0x`/`0X`),
and octal (`0o`/`0O`) spellings. Underscores may separate two digits in any base,
but may not appear immediately after a prefix, next to a decimal point, or next
to a type suffix. Binary and octal literals reject out-of-base digits during
lexing rather than silently changing value.

## Source-declared effects

Elisascript supports named algebraic effect families with bodiless operation
signatures:

```elisa
effect Writer:
    def write(value: sview) -> void

def emit(value: sview) -> void can[Writer.write]:
    signal Writer.write(value)
```

The parser records the family, each first-level operation, and its payload arity
in file metadata; semantic analysis rejects unknown `signal` and `perform`
operations and payload-count mismatches while leaving builtin and permission-only
families open to host-defined operations. Operation payload and resumption types remain governed
by the ordinary typed handler callback and IR verifier, so declaration metadata
cannot weaken static checking. Dynamic handlers may therefore intercept
user-defined operations without introducing a second AST or runtime representation.

## Module constants

Immutable, initialized module-level constants are available from every function
with their declared (or inferred) type:

```elisa
const EXIT_CODE: i64 = 7
const PREFIX: sview = "build: "
```

The IR materializes these values at function entry as typed SSA bindings. Normal
lexical shadowing still applies, so a parameter or local with the same name wins.
`global` declarations use shared module storage: reads lower to `LoadGlobal` and
writes to `StoreGlobal`, so nested calls observe the same value. Uninitialized
globals start at the type's zero value. Scalar literals and one-level literal
`darray[T]`/`dict[K, V]` initializers are materialized in the caller-owned runtime
arena; nested aggregates and non-literal initializers remain a deliberate lowering
diagnostic.

Tuple literals have a homogeneous-sequence form for Python-style ports: `(a, b,
c)` is checked element-by-element and lowered as an ordinary `darray[T]` value.
When a destination type is explicit, each element is checked against that `T`; an
empty `()` is accepted in that contextual form. Heterogeneous tuples and
unconstrained empty tuple values remain rejected until first-class recursive tuple
values are added.

Comma-separated assignment targets are supported for literal tuple/array values:

```elisa
left: mutable i64 = 1
right: mutable i64 = 2
left, right <- right, left
```

All right-hand elements are evaluated before any target is rebound, so swaps are
simultaneous. Fresh `=` targets infer their individual element types; mutation
uses `<-` (or a typed compound operator) and requires mutable bindings. Dynamic
array unpacking is also supported for homogeneous `darray[T]` values:

```elisa
def split_pair(values: darray[i64]) -> i64:
    left: mutable i64 = 0
    right: mutable i64 = 0
    left, right <- values
    return left * 10 + right
```

The lowering emits checked `UnpackArray` operations. The source array must have
exactly as many elements as targets at runtime; a short or long array raises the
typed `IndexOutOfBounds` error before any target is rebound. Repeated targets
remain rejected.

String payloads are decoded once at the IR constant boundary. Ordinary and
adjacent triple-quoted literals recognize Elisa's standard escapes (`\\n`, `\\t`,
`\\r`, `\\0`, `\\\\`, `\\"`, `\\'`, `\\xNN`, and `\\uNNNN`); unknown or malformed
escapes remain literal. Triple-quoted payloads may span lines, while a bare
`"""..."""` sequence continues to denote an Elisa block comment. The reference
interpreter and packed bytecode path call the same decoder, so differential tests
observe identical text values. In a triple-quoted payload, a closing `"""` run
preceded by an odd number of backslashes is data rather than a terminator.

The shared IR recognizes these five compiler-known calls when no source function
shadows the prefix. A constant string payload emits a nominal `Constant`; a runtime
`sview` payload emits an explicit nominal constructor (`MakePath`, `MakeGlob`,
`MakeRegex`, `MakeExecutable`, or `MakeUrl`). Both forms preserve
`Path`/`Glob`/`Regex`/`Executable`/`Url` identity while the reference runtime stores
the payload as immutable text. Nominal values can cross exactly typed function
boundaries and use exact nominal equality; they do not implicitly become `sview` or
one another. Runtime constructors currently perform the type-safe text adaptation;
the corresponding path/glob/regex/URL parsers remain shared-library increments.

## Python-compatible length

The compiler-known `len(value) -> usize` builtin is the scripting-profile
spelling for collection and text length. It accepts exactly one positional
`darray[T]`, `dict[K, V]`/`map[K, V]`, or `sview` value and lowers to the same
verified `Length` operation as `.count` and slice bounds. Text length follows
Elisa's byte-oriented `sview` contract. A source function named `len` shadows
the builtin like any other direct call, so ports can introduce a local helper
without changing resolution rules.

The compiler-known `is_empty(value) -> bool` (also `isempty`) and the matching
`value.is_empty()`/`value.isempty()` methods accept the same array, dictionary, or
text families. They compare the exact typed `Length` result with zero, making the
shell `test -z` and Python emptiness check explicit without introducing general
truthiness coercions.
The complementary `is_nonempty(value)`/`nonempty(value)` spellings and receiver
methods lower to the same check followed by typed boolean negation for arrays,
dictionaries, and text, corresponding to shell `test -n`. A nominal `Path`
argument selects the filesystem form described below (`FileSize > 0`) while
retaining the exact `File.Read`/`FileIoError` contract.

The compiler-known `abs(value)` builtin accepts a signed integer or `f64` and
returns the same exact static type. It evaluates its argument once, then uses a
typed comparison and branch to negate only negative values. The signed minimum
integer still raises the ordinary `IntegerOverflow` runtime error because its
positive magnitude is not representable; floating-point values follow the host
IEEE sign rule.

The compiler-known `sorted(values, reverse: flag)` builtin accepts a typed array of
orderable scalar values (`bool`, integer, float, `char`, or text) and returns a
fresh array with the same exact element type. The optional `reverse` bool may be a
literal or a runtime value; the input is never mutated, and sorting is stable and
byte-oriented for text. It is the expression-form counterpart to the in-place
`values.sort()` method and is shadowable by a source declaration.

The compiler-known `reversed(values)` builtin accepts any typed array and
returns a fresh array with the same exact element type in reverse order. The
input is never mutated, including for nested aggregate elements; the operation
is deterministic and is shadowable by a source declaration.

The compiler-known `min(values)` and `max(values)` builtins accept a typed array
of orderable scalar values and return its exact element type. They also accept
two or more positional scalar values of one exact orderable type. Both forms
produce the ascending minimum or maximum through a fresh sorted copy, so input
arrays remain unchanged. Empty arrays raise the ordinary checked-index
`IndexOutOfBounds` failure through `error[...]`; aggregate elements and
heterogeneous variadic arguments are rejected statically.

The Python-compatible `sum(values, start)` and `product(values, start)` forms
fold a typed integer array with identities `start` (or `0`/`1` when omitted),
preserving the array's exact integer type and evaluating the iterable once.
Both accept an optional second positional or `start:` value, which must match
the exact element type. They expose no implicit widening. `any(values)` and `all(values)`
fold a typed boolean array with the usual empty identities (`false` and `true`)
and short-circuit through the same explicit loop state machine; non-boolean
elements are rejected rather than coerced by truthiness.
The same forms accept Python's `range(stop)`, `range(start, stop)`, and
`range(start, stop, step)` spellings wherever an integer range query is allowed,
using the counter directly without constructing an intermediate array.

The compiler-known `contains(collection, needle) -> bool` helper and the
`collection.contains(needle)` method are typed membership spellings for ports
that prefer a call over Elisa's `needle in collection` operator. Arrays compare
exact elements, dictionaries inspect keys, and text accepts `sview` or `char`
needles. The collection is evaluated before the needle, each operand is
evaluated once, and both forms lower to the shared `Contains` operation; a
source declaration named `contains` still shadows the global helper.

## Text boundary predicates

The compiler-known `starts_with(text, prefix) -> bool` and
`ends_with(text, suffix) -> bool` operations provide the exact byte-oriented
prefix/suffix checks commonly used by shell and Python ports. Both arguments are
`sview`; an empty boundary succeeds, and a boundary longer than the input fails.
They are pure, deterministic, and shadowable by a source function with the same
name. The compact global aliases `startswith` and `endswith` are equivalent typed
spellings. Their dedicated IR operations are shared by the reference interpreter
and the direct bytecode backend.

The compiler-known `replace(text, old, replacement) -> sview` operation performs
literal, left-to-right, non-overlapping substitution. The `old` argument is not
parsed as a regular expression, so regex metacharacters remain ordinary bytes;
an empty `old` inserts the replacement at every input boundary, matching Python's
string behavior. It is pure, deterministic, shadowable, and returns owned text.

The binary `+` operator concatenates two text values when both operands are
exactly text-typed. The result is an owned text value, so chained expressions and
concatenation with a computed method result remain valid across the interpreter and
bytecode backends. Other `+` operand pairs retain Elisa's numeric typing rules and
are rejected when either operand is firmly non-numeric.

The binary ordering operators (`<`, `<=`, `>`, `>=`) also accept two exactly
text-typed (or exactly `char`-typed) operands. They compare unsigned `sview` bytes
lexicographically, using the shorter common prefix as the tie-breaker. Numeric
ordering remains unchanged, and mixed text/numeric operands are rejected rather
than coerced.

The compiler-known `strip(text) -> sview` and `trim(text) -> sview` names are
equivalent byte-oriented boundary operations. They remove ASCII space, tab, line
feed, vertical tab, form feed, and carriage return from the beginning and end,
preserve interior bytes, and return a view into the existing text value. Both are
pure, deterministic, and shadowable by source functions.

The compiler-known `lower(text) -> sview` and `upper(text) -> sview` operations,
as well as the Python-shaped `text.lower()` and `text.upper()` method spellings,
perform deterministic ASCII case conversion. ASCII letters are folded and all
other UTF-8 bytes pass through unchanged; this byte-oriented rule avoids locale
dependence or malformed Unicode transformations. `casefold(text)` and
`text.casefold()` are explicit aliases for the same ASCII lowercasing operation;
they do not claim full Unicode case-folding. The operations are pure, shadowable
(for the global spellings), and return owned text.

The compiler-known `split_lines(text) -> darray[sview]` (also accepted as
`splitlines(text)`) and the Python-shaped `text.splitlines()`/`text.split_lines()`
methods split on LF, CR, and CRLF boundaries. Trailing line breaks do not add an
extra empty field, while empty and consecutive lines remain observable. Empty
input returns an empty array; the operation is deterministic and byte-oriented.

Python-shaped text methods are available as statically typed aliases for the same
operations: `text.startswith(prefix)`/`text.starts_with(prefix)` and
`text.endswith(suffix)`/`text.ends_with(suffix)` return `bool`; `text.replace(old,
replacement)` returns `sview`; `text.strip()`/`text.trim()` return `sview`;
`text.lstrip()`/`text.rstrip()` return `sview` views trimmed only on the left or
right boundary respectively; and
`text.split(separator)` and `text.split(separator, maxsplit)` and `text.split()`
return `darray[sview]`. The bounded form requires a signed `i64` `maxsplit`;
negative values mean unlimited splitting and zero returns the unsplit text.
`text.rsplit(separator)` and `text.rsplit(separator, maxsplit)` provide the
right-to-left counterpart with the same typed separator and signed `i64` bound;
the resulting fields are returned in their original left-to-right order. The
zero-argument `text.rsplit()` form uses the same ASCII-whitespace rule as
`text.split()`. The zero-length separator follows the ordinary byte-splitting
rule used by `split`.
`text.partition(separator)` and `text.rpartition(separator)` return a fixed
three-field `darray[sview]`: the text before the selected separator, the
separator itself, and the remaining text. `partition` selects the first
occurrence while `rpartition` selects the last; when no occurrence exists they
return `[text, "", ""]` (or `["", "", text]` for `rpartition`). This ordinary
array shape can be destructured with Elisa's checked multi-binding assignment.
The global `partition(text, separator)` and `rpartition(text, separator)`
spellings are equivalent.
Receivers and arguments must be text values, and method arity is checked during
lowering.
The zero-argument form splits on runs of ASCII whitespace, drops leading and
trailing whitespace, and returns an empty array for whitespace-only input.
All trim spellings remove the same ASCII whitespace set, take no arguments, and
preserve interior whitespace.
The Python-compatible `separator.join(fields)` method is also available for a
text separator and `darray[sview]` fields; it follows the same insertion and
empty-field rules as the global `join(fields, separator)` operation.

Dictionary values expose the Python-compatible `mapping.keys()` method. It takes
no arguments, returns an insertion-ordered `darray[K]` for `dict[K, V]`, and uses
the same typed `MapKeys` operation as dictionary iteration. Set values do not
expose dictionary key views even though their first runtime representation shares
the map payload layout.
The matching `mapping.values()` method takes no arguments and returns an
insertion-ordered `darray[V]`, preserving the complete static value descriptor
through a dedicated `MapValues` operation. It is likewise unavailable on sets.
The global `keys(mapping)` and `values(mapping)` spellings are equivalent typed
aliases for these receiver operations; each accepts exactly one dictionary value
and remains shadowable by a source declaration.

Text values also provide `text.count(substring) -> usize`. The operation counts
left-to-right non-overlapping byte matches; an empty substring counts the input
boundaries (`length + 1`). It is pure, deterministic, and rejects non-text
receivers or arguments during lowering.
The companion `text.find(substring) -> i64` method returns the first byte offset,
`0` for an empty substring, and `-1` when no match exists. It uses the same
byte-oriented comparison rules and is pure and deterministic.
`text.rfind(substring) -> i64` returns the last byte offset, the input length for
an empty substring, and `-1` for a miss. Both search methods require one
positional text substring and expose no implicit Unicode or locale behavior.
`text.index(substring) -> i64` and `text.rindex(substring) -> i64` use the same
byte offsets as `find`/`rfind`, but raise `IndexOutOfBounds` through the ordinary
`error[...]` channel when the substring is absent. Empty needles still return
the start or end boundary respectively. Array `.index(element)` follows the
same checked error behavior, while `.find(element)` remains the `-1` search form.

Text classification methods `text.isdigit()`, `text.isdecimal()`,
`text.isnumeric()`, `text.isalpha()`, `text.isalnum()`, `text.isspace()`,
`text.islower()`, `text.isupper()`, `text.isascii()`, and `text.isprintable()`
take no arguments and return `bool`. They use non-empty, ASCII byte-oriented
rules: digits, decimals, and numerics are `0`-`9`,
alphabetic bytes are ASCII letters, alphanumeric accepts either class, and
whitespace is space, tab, LF, VT, FF, or CR. `islower` and `isupper` ignore
uncased bytes but require at least one cased byte, then require every cased byte
to have the requested case. `isprintable` accepts visible ASCII bytes `0x20`
through `0x7e` only. Empty text returns `false` for every predicate except
`isascii()`, which returns `true` because the empty string contains no
non-ASCII bytes.

Text boundary-removal methods `text.removeprefix(prefix)` and
`text.removesuffix(suffix)` take one positional text boundary and return the
original text unchanged when it does not match. A matching boundary is removed
by byte offset; an empty boundary is a no-op. They are pure and deterministic.

The first executable regex operation is the compiler-known, strongly typed search
`matches(text, pattern) -> bool`, where `text` is `sview` and `pattern` is `Regex`:

```elisa
is_source: bool = matches("src/main.elisa", regex"^src/.*\\.elisa$")
```

Its initial runtime grammar supports literal characters, `.`, start/end anchors
`^` and `$`, escaped literals, character classes and ranges (`[abc]`, `[a-z]`,
`[^0-9]`), and the greedy quantifiers `*`, `+`, and `?`, plus bounded repetitions
`{m}`, `{m,n}`, and `{m,}`. Bounds are decimal, non-negative, and non-decreasing;
an omitted upper bound is greedy through the remaining input. The Perl-style shorthand
classes `\d`, `\D`, `\w`, `\W`, `\s`, and `\S` work both as atoms and inside
classes. Word-boundary atoms `\b` and `\B` are zero-width checks at ASCII word/non-word
transitions (including the beginning and end of text). Their meaning is deliberately
ASCII and locale-independent so differential
tests observe identical behavior on every backend. Search is unanchored unless `^`
is present. Top-level `|` alternation evaluates branches from left to right, with
`^` and `$` scoped to the branch in which they occur; escaped pipes and pipes inside
character classes remain literal members. Parenthesized groups may nest and
participate in alternation and greedy quantifiers. Group-local `^` and `$` retain
their ordinary whole-text meaning. `replace_regex(text, pattern, replacement) -> sview`
provides deterministic substitution for this grammar: it finds non-overlapping
matches from left to right and inserts the replacement text, expanding the portable
`$0` token to the complete matched span. Perl-style named group markers
(`(?<name>...)`) are accepted, and `$1` through `$9` expand for flat,
non-quantified capture groups when their spans
can be proven against the complete match (for example, `([a-z]+)=([0-9]+)`).
Nested, quantified, or top-level-alternating capture layouts remain literal rather
than selecting an ambiguous branch; unknown or unproven `$n` forms stay literal.
For uniquely named flat groups, `${name}` and `$<name>` expand to the same proven
capture span; unknown or duplicate names remain literal.

Replacement tokens follow familiar Perl/AWK/sed conventions while remaining
deterministic: `$0` is the complete match, `&` is an AWK/sed spelling of the
complete match, and Perl/Python-style `\0` and `\g<0>` are equivalent whole-match
tokens. `$1` through `$9` expand proven positional captures; `\1` through `\9`
and numeric `\g<1>` through `\g<9>` are equivalent spellings. For uniquely named
flat groups, `${name}`, `$<name>`, and `\g<name>` expand the same proven capture.
`$$` emits a literal dollar, and `\&` emits a literal ampersand.
`split_regex(text, pattern) -> darray[sview]` uses the same matcher for
Perl/AWK-style field boundaries. It preserves empty fields before, between, and
after non-overlapping matches. A zero-width match emits its current field, advances
the search position by one byte, and retains that byte for the next field; this
explicit progress rule makes even an empty or anchor-only pattern total. The
operation is pure and lowers to a dedicated verified `RegexSplit` instruction.

`find_regex(text, pattern) -> darray[sview]` extracts every non-overlapping match
as an owned text field, in left-to-right order. Empty matches are included and
advance one input byte (with a final zero-width match at end-of-input terminating
the scan), so even anchor-only patterns are total. The operation is pure and uses
the same deterministic ASCII matcher as search, replacement, and splitting.

For ports that keep a compiled pattern in a local, `pattern.search(text)` is a
typed receiver spelling of `matches(text, pattern)`. `pattern.match(text)`
anchors the match at the beginning while permitting a suffix, and
`pattern.fullmatch(text)` requires the entire haystack to be consumed. These
forms use the same verified `RegexSearch` opcode with a small mode (0, 1, or 2)
and retain deterministic behavior across backends. The receiver must be the
nominal `Regex` type and the haystack must be `sview`.

`pattern.findall(text)`/`pattern.find_all(text)` are receiver spellings of
`find_regex(text, pattern)` and lower to `RegexFind`.

`pattern.capture(text)`/`pattern.captures(text)` likewise spell
`capture_regex(text, pattern)`, returning the complete first match followed by
the same conservatively proven capture fields.

`pattern.split(text)` is the receiver spelling of
`split_regex(text, pattern)`, preserving empty fields and the explicit
zero-width progress rule.

`pattern.sub(replacement, text)` is the Python-shaped receiver spelling of
`replace_regex(text, pattern, replacement)`. Its replacement and haystack are
both `sview`, and capture-expansion tokens follow the same deterministic
Perl/AWK-compatible rules as the global operation.

`capture_regex(text, pattern) -> darray[sview]` returns the first match and its
proven capture groups. Element `0` is the complete match; elements `1` onward
follow positional group order, and an unmatched proven group is represented by an
empty text field. A missing match returns an empty array. Capture spans use the
same conservative proof as replacement: flat, non-quantified groups are exposed,
while nested, quantified, or top-level-alternating layouts return only the complete
match rather than guessing. `captures_regex` is an equivalent spelling for scripts
that prefer a plural verb.

## Checked indexing and value recovery

The scripting profile keeps ordinary indexing strict: `values[index]` raises a
typed `IndexOutOfBounds` error for a missing array/text element or dictionary key.
Array and text indices follow Python's negative-index rule: a negative integer is
offset from the end (`-1` denotes the final element), while dictionary integer
keys remain ordinary exact keys. The same normalization is used by indexed
assignment and the lazy validity check.
Use `get` when a local fallback is preferable:

```elisa
value: i64 = get values[index] else default_value()
```

The fallback is lazy. Lowering emits an `IndexValid` predicate and two CFG edges,
so `default_value()` runs only after a bounds or key-membership miss. The success
edge performs the same checked index as ordinary access, and both values merge at
one statically typed result. Array and text indices must be integers; dictionary
indices must match the exact key type; fallback and indexed values must have the
same type. Malformed runtime storage remains an `error[...]` failure rather than
being converted into a sentinel.

The same recovery syntax handles fallible calls declared with `error[...]`:

```elisa
number: i64 = try parse_int(text) else 0i64
```

The guarded call runs once. A declared error transfers control to the fallback
block, while success continues through a typed merge. The fallback is therefore
lazy and may itself be fallible; any error it raises propagates through the
enclosing function's ordinary `error[...]` row. Recovery does not erase the
function's static error contract or catch internal control-flow failures.

Expression-position `catch` provides the same error-first workflow when the
success value needs a small transformation:

```elisa
number: i64 = catch int(text):
    parsed:
        parsed
    error e:
        0i64
```

Elisascript accepts one success binding (or `_`) and one error arm. The error arm
may be a catch-all (`_` or `error e`) or a payload-free `Family.Tag` variant. Both
arm bodies must contain one expression whose type exactly matches the guarded
value; the error binder is intentionally not a runtime error payload. Variant
arms recover only an explicitly raised matching tag; built-in failures and other
raised variants continue through the enclosing `error[...]` contract. Payload
matching and terminating variant arms remain deferred until the IR carries error
ordinals and payloads, except that a catch-all arm may terminate with `return`
after the ordinary function return-type check. The guarded expression is evaluated
once, with a lazy fallback and a typed state-machine merge.

For early propagation, the fallback may be a terminating clause:

```elisa
number: i64 = try parse_int(text) else return 0i64
```

The recovery block must end control flow (`return`, `break`, or `continue`);
successful evaluation continues through the surrounding state-machine merge.
Void fallible operations use the same guard machinery in statement position:
`try assert(condition) else void` is an explicit no-op fallback, while
`try assert(condition) else return` may terminate on failure. Void recovery never
produces a sentinel value and is rejected when a non-void value is required.

## Typed comprehensions

Array comprehensions keep Elisa's expression-oriented syntax while making every
iteration and allocation explicit in the typed IR:

```elisa
doubled: darray[i64] = [value * 2i64 for value in values]
evens: darray[i64] = [value for value in values if value % 2i64 == 0i64]
letters: darray[char] = [character for character in text]
doubled_range: darray[i64] = [value * 2i64 for value in 0i64..<4i64]
values_only: darray[i64] = [value * 2i64 for key, value in values]
indexed: dict[i64, i64] = {value: value * 10i64 for value in values if value > 0i64}
remapped: dict[i64, i64] = {key: value * 2i64 for key, value in values}
positive_count: usize = count value in values where value > 0i64
total: i64 = sum value in values
positive_product: i64 = product value in values where value > 0i64
```

The initial lowering supports one binder over an array, text value, or integer
range and an optional boolean `if` filter. Array and dictionary comprehensions
also support two read-only binders (`key, value`) over a dictionary iterable; the
array form projects a value sequence while the dictionary form can use either
binder in its `key: value` projection. Array/text iteration uses checked
`Length`/`Index` operations; map iteration snapshots keys once and performs a
checked value lookup for the second binder. Dictionary comprehensions also accept
the Python spelling `{key: value for key, value in mapping.items()}` and use the
same one-time key snapshot/value lookup. Text iteration produces one-character
values. The Python-compatible `[left + right for left, right in zip(lefts, rights)]`
form projects two array/text sources in lockstep, evaluates both once, and stops
at the shorter source while preserving each exact element type. The same
two-binder shape accepts `[value for index, value in enumerate(values, start)]`;
the collection cursor remains zero-based for bounds and indexing while the
typed `usize` index binding is offset by `start` (which is evaluated once).
Dictionary comprehensions use the same form for typed offset keys, for example
`{index: value for index, value in enumerate(values, 1)}`.
Integer ranges stay counter-driven and do not materialize a temporary array:
`low..<high` is exclusive ascending, `low..=high` is inclusive ascending, and
`high..>low` is strict descending. The range-owned stride spelling
`low..<high..step` (and its inclusive/descending variants) accepts an integer
expression and is applied in the latch state. Bounds and stride are evaluated
once. Python's `range(stop)`, `range(start, stop)`, and
`range(start, stop, step)` spellings are accepted in `for` loops as equivalent
counter-driven ranges. A literal step selects the corresponding ascending or
descending state machine; an expression is evaluated once, and its runtime sign
selects the direction. Zero steps raise `RangeStepZero` through the function's
typed error channel. The result element type is inferred
from the projection and
must be storable, so heterogeneous results, effectful/non-straight-line
projections, and void projections are rejected statically. An empty result is a
typed empty array or map, never a sentinel. Dict comprehensions use a two-element
`key: value` projection and infer exact key/value types; dictionary projections
can use the same integer ranges without materializing them. Keys must be scalar
or nominal and values obey the same bounded aggregate-depth rule as dictionary
literals. Duplicate keys replace the prior value while preserving the runtime's
insertion order.
The accumulator is an SSA loop-carried value updated with `Concat` for arrays or
immutable `SetIndex` copies for maps, and the header, filter, append, latch, and
exit are ordinary state-machine blocks. Quantifiers use the same loop shape but
carry a `bool`: `any` exits early on the first true predicate, while `all` exits
early on the first false predicate. Empty inputs therefore produce `false` for
`any` and `true` for `all`. The verification spellings `exists x in values: predicate`
and `forall x in values: predicate` are equivalent existential and universal
forms; their ordinary query-style `where` spelling is accepted too. Quantifier
predicates must be statically boolean and straight-line; effectful quantifiers
and forms with more than two binders are rejected until their semantics are
specified. Two-binder quantifiers are restricted to dictionary iterables
(`key, value`).
`count` is a typed `usize` fold over the same array/text/range iterables and
increments its loop-carried counter only for matching elements. Two-binder
dictionary folds count entries, while `sum` and `product` fold the value binder.
`sum` and `product` are integer-only folds that carry the iterable's exact
element type (or dictionary value type), with identities `0` and `1` respectively;
no implicit widening or temporary collection is introduced.
The collection query `each x in values where predicate` is the typed identity
projection, equivalent to `[x for x in values if predicate]`. Set literals and
single-binder set comprehensions are also supported for scalar or nominal element
types. Their source-level type remains `set[T]`; the first IR represents them as a
typed map from each element to `true`, which gives deterministic membership, count,
and insertion-order iteration while preserving set deduplication. Mutable set bindings
support `.add(element)` through the same immutable SSA update used by maps; duplicate
additions leave cardinality unchanged. Mutable set bindings also support `.clear()`,
which rebinds the set to a typed empty value, and `.remove(element)`, which removes
the matching element if present and is otherwise a no-op. Python's
`.discard(element)` is an equivalent set-only spelling for the no-op-on-missing
operation. Indexed set reads remain
semantic errors until the dedicated set runtime shape is introduced. Mutable
dictionaries also support `.clear()` and `.remove(key)`, and mutable arrays support
`.clear()`, all with immutable SSA update semantics; removing a missing key is a no-op.
The lowered map descriptor retains
an internal set marker, so set-only `.add()` cannot be applied to an ordinary
`dict[T, bool]` despite the shared physical representation.

Python-compatible dictionary defaults use `mapping.get(key, default)`. The key
must match the dictionary key type and the fallback must match its value type.
Lookup is lowered through `IndexValid`, keeping the fallback lazy while preserving
the ordinary typed merge and avoiding a result wrapper.
Mutable dictionaries also support Python's `mapping.pop(key)` and
`mapping.pop(key, default)` forms. The operation returns the exact value type and
rebinding removes the key through an owned SSA map update. A missing key raises
`IndexOutOfBounds` without a default; with a default, it returns that exact typed
fallback and leaves the dictionary unchanged. Set values and immutable
dictionaries are rejected during lowering.
`mapping.update(other)` merges another dictionary of the exact same type into a
mutable receiver. Existing keys keep their insertion position while receiving the
new value; new keys append in the source dictionary's insertion order. The update
is an owned SSA map replacement, and the method returns `void` like Python's
`dict.update`.
`mapping.setdefault(key, default)` returns the existing value for `key`, or the
typed default when the key is absent, and inserts that default into a mutable
dictionary only on a miss. The key and default must match the dictionary's exact
key/value types; the operation preserves insertion order and returns the value
type directly without a result wrapper.

Mutable arrays accept both Elisa's `values.push(element)` spelling and the
Python-compatible `values.append(element)` alias. Both require one positional
element of the exact array element type and rebind the mutable array through the
same ownership-safe SSA update; immutable arrays and mismatched elements are
rejected before execution. Python's `values.pop()` and `values.pop(index)` forms
return the exact element type and rebind the mutable array to a shortened view.
The optional index is an integer, counts from the end when negative, and raises
`IndexOutOfBounds` when the array is empty or the normalized index is outside the
array. A failing operation does not publish a new binding value.
`values.reverse()` is the Python-compatible in-place spelling for reversing a
mutable array. It takes no arguments, copies elements into a fresh array in
reverse order, and rebinds the receiver through the same ownership-safe SSA
update. Empty arrays remain empty; immutable arrays and non-array receivers are
rejected statically.
`values.insert(index, element)` is the corresponding typed insertion operation.
It requires a mutable array, an integer index, and an element of the exact array
element type. Negative indices count from the end, indices below the start clamp
to zero, and indices beyond the end append; the operation copies the array and
rebinds the receiver through SSA.
`values.copy() -> darray[T]` creates an owned shallow copy of any typed array.
It takes no arguments and does not require a mutable receiver, so subsequent
updates to either array do not alter the other's storage.
`mapping.copy() -> dict[K, V]` is the corresponding Python-compatible operation
for typed maps. It takes no arguments, preserves the complete key/value
descriptor, and copies the interleaved pair storage so top-level updates to
either map do not alter the other map.
The Python-compatible `values.count(element) -> usize` method counts exact
element matches in an array, including nested arrays under the supported
structural descriptor (including the six inline aggregate layers). It is pure, deterministic, and requires the argument to
match the array element type exactly.
The companion `values.find(element)` method returns the first matching element
offset as a signed `i64`, or `-1` when no element matches. `values.index(element)`
returns that offset but raises `IndexOutOfBounds` when absent. Both share
structural equality with `count` and require an exact element type; `index` is
an array-only spelling while `find` also remains valid for text values.
`values.remove(element)` is the Python-compatible in-place removal operation. It
requires a mutable array and an element of the exact array element type, removes
only the first matching element, and rebinds the receiver through the same
ownership-safe SSA update. If no element matches, execution raises
`InterpretError.IndexOutOfBounds` through the ordinary `error[...]` channel and
the binding remains unchanged. Structural equality is identical to `count`,
`find`, and `index`.
`values.sort(reverse: flag)` is the Python-compatible in-place sort operation. It
requires a mutable array of statically orderable scalar values (`bool`, integer,
float, `char`, or text), produces a fresh owned array, and rebinds the receiver
through SSA. Sorting is stable and deterministic; text ordering is unsigned
byte-lexicographic under the `sview` contract. The optional `reverse` bool may be
literal or dynamic and is handled through the same typed state-machine merge as
the expression form. Other aggregate element types and immutable arrays are
rejected during lowering.

## Text field processing

Elisascript provides a strongly typed compiler-known split operation for the core
shell/Python/AWK field-processing case:

```elisa
fields: darray[sview] = split("name::value", ":")
# ["name", "", "value"]
```

`split` preserves empty fields at every position. An empty separator splits a
nonempty string into byte-sized `sview` values and maps empty input to `[]`.
An explicit signed `i64` `maxsplit` bounds the number of separator matches;
negative values are unlimited and zero returns one unsplit field. These rules are
total, deterministic, and identical across the interpreter and future
bytecode, JIT, and native backends. A source function named `split` shadows the
compiler-known operation normally.

The Python-shaped `text.rsplit(separator)` method scans the same separator from
the right and then returns fields in their original order. Its optional signed
`i64` `maxsplit` limits rightmost matches; a negative value is unlimited and zero
returns one unsplit field. It uses the same empty-separator byte rule as `split`.

`join(fields, separator) -> sview` is the typed inverse for `darray[sview]` values.
It inserts the separator only between fields, preserves empty fields, and returns
empty text for an empty array. `join(split(text, separator), separator)` therefore
round-trips text under the explicit-separator rules. Like `split`, a source-defined
function with the same name takes precedence.

Line-oriented file helpers build on those same deterministic text rules:

```elisa
lines: darray[sview] = read_lines(path"config.txt")
written: usize = write_lines(path"generated.txt", lines)
```

`read_lines(path)` is equivalent to `split(read_text(path), "\n")`, so it preserves
empty lines and a trailing empty field when the file ends in a newline. It requires
`File.Read` and reports `FileIoError`. `write_lines(path, lines)` is equivalent to
`write_text(path, join(lines, "\n"))`: it writes separators between lines but does not
add an extra final newline, and reports the number of bytes written. It requires
`File.Write` and reports `FileIoError`. Both helpers are lowered to the existing
verified read/split/join/write instructions, keeping interpreter and bytecode
behavior identical.

Interpolated strings use Elisa's `f"...{expr}..."` syntax. The parser represents
them as ordered `__fstr` pieces. Elisascript accepts text, `char`, any integer width, `f32`/`f64`,
`bool`, text-backed nominal, array, and dictionary dynamic pieces and lowers the
sequence to `Concat` instructions, inserting the existing
`FormatChar`/`FormatInt`/`FormatFloat`/`FormatBool`/`FormatNominal`/`FormatAggregate`
conversion for non-text values. Integers use canonical decimal formatting,
floats use the core `%g` spelling, booleans use lowercase `true`/`false`, and
nominals expose their underlying text payload. Aggregate values use stable
bracketed forms (`[a, b]` and `{key: value}`), preserving insertion order for
dictionaries and formatting nested arrays/maps iteratively with a 64 MiB output
bound. Literal pieces use the same escape decoder as ordinary strings, and
expressions are evaluated exactly once from left to right.
`format_bool(value: bool) -> sview` remains available when a standalone boolean
conversion is clearer.
Consequently the reference
interpreter and packed bytecode path produce identical text without a hidden
formatting or shell layer.

## Typed dictionaries

Dictionary literals use Elisa's brace syntax and a two-parameter type application:

```elisa
counts: dict[sview, i64] = {"ok": 2, "failed": 1}
total: i64 = counts["ok"]
has_ok: bool = "ok" in counts
```

Every key has one exact static type and every value has one exact static type; no
implicit conversions or heterogeneous entries are accepted. Scalar values, nested
dictionaries, and bounded combinations of arrays and nested dictionaries are
supported when they fit the inline descriptor (for example,
`dict[sview, dict[sview, darray[darray[i64]]]]`). Deeper or unsupported aggregate
shapes remain an explicit lowering diagnostic. `dict[K, V]` is also
spelled `map[K, V]`. `.count` returns the number of entries, membership checks
keys, and an indexed read of a missing key raises `InterpretError.IndexOutOfBounds`
through the ordinary `error[...]` channel. Indexed assignment is immutable-update
semantics at the IR boundary: a mutable binding receives a fresh map, replacing an
existing key or inserting a new one. The reference runtime stores interleaved
key/value pairs in caller-owned flat storage, so differential observations remain
deterministic and allocation ownership is explicit. A read-only `for key in map`
loop walks a materialized key array in insertion order. `for key, value in map`
uses that same key array and performs a typed lookup for each value; both bindings
are immutable, and map mutation remains explicit through indexed assignment.
Arrays and byte-oriented text also support a two-binding indexed form:
`for index, value in values` binds `index: usize` and the element (or `char` for
text) without allocating an intermediate pair array. This is the typed
enumeration shape intended for Python-style index/value scripts; Elisa's
`for index, value in values.enumerate()` spelling is accepted as equivalent
sugar, and Python's `enumerate(values, start)` spelling is accepted with one
array or text source plus an optional non-negative integer start. Literal starts
are normalized to `usize`; dynamic starts must already have exact `usize` type.
The global form is shadowable by a source declaration and retains the same exact
`usize` index typing. Python's `for key, value in mapping.items()` spelling is accepted as
equivalent dictionary-entry sugar; it also evaluates the mapping once and does
not materialize pair objects. All forms remain explicit state-machine CFGs.
Python's `for left, right in zip(left_values, right_values)` spelling is also
accepted for exactly two positional array or text sources. Each source is
evaluated once, the element types remain exact (`char` for text), and iteration
stops at the shorter source without allocating pair objects. The builtin name
is shadowable by a source declaration, just like `enumerate`.
Mutable iteration remains restricted to arrays. Map equality is order-insensitive
but matches pairs one-to-one, so malformed duplicate entries cannot be reused to
hide a mismatch.

## Numeric text conversion

`parse_int(text) -> i64 error[ParseError]` accepts an optional leading `+` or `-`
followed by one or more ASCII decimal digits; underscores may separate adjacent
decimal digits. It rejects whitespace, empty input,
trailing characters, and values outside signed 64-bit range through `ParseError`;
the failure is never represented as a sentinel integer. `format_int(value: i64) ->
sview` produces the canonical base-10 spelling, including `-0` normalization to
`0`. Both operations are compiler-known, shadowable by a source declaration, and
share exact behavior between the reference interpreter and packed bytecode.
`parse_float(text) -> f64 error[ParseError]` accepts decimal mantissas with an
optional sign, fractional part, and `e`/`E` exponent (including an exponent sign);
underscores may separate adjacent digits in each mantissa or exponent component.
It rejects missing digits, trailing characters, and incomplete exponents. The
matching `format_float(value: f64) -> sview` uses Elisa's `%g`-style canonical
runtime spelling and keeps the returned text in permanent storage.
`format_bool(value: bool) -> sview` returns canonical lowercase `true` or `false`.
`format_char(value: char) -> sview` returns the character's byte-oriented text
payload. These formatting helpers are compiler-known and shadowable by source
declarations.
The Python-compatible `str(value) -> sview` facade accepts text (identity),
`char`, any integer width, `f32`/`f64`, `bool`, arrays, dictionaries, and the text-backed
nominals `Path`, `Glob`, `Regex`, `Executable`, and `Url`, selecting the
corresponding typed formatter. Aggregate values use the same bounded,
deterministic bracketed rendering as f-strings and `print`; integer widths remain
exact and are not implicitly widened. Nominal conversion is explicit at the
`str(...)` boundary; no other operation gains an implicit nominal-to-text
coercion. A source function named `str` shadows this compiler-known operation.
The scalar constructors `int(value) -> i64` and `float(value) -> f64` accept
their exact target scalar as an identity or parse `sview` through the checked
`ParseError` path. `bool(value) -> bool` is likewise an exact-type identity.
They reject lossy numeric coercions, truthiness conversions, aggregates, and
other integer widths; source declarations named `int`, `float`, or `bool`
shadow these compiler-known facades.

## Filesystem capability

The first executable filesystem primitive is
`path_exists(path: Path) -> bool`. It accepts the nominal `Path` type rather than
an arbitrary string and contributes `File.Read` to the enclosing function's effect
row. The reference interpreter executes it through Elisa's own
`elisacore_fileio.elisa` runtime; it does not invoke a shell or Python. A
source-defined `path_exists` function shadows the compiler-known operation.

`is_file(path: Path) -> bool` is the regular-file predicate used by shell `test -f`
and Python `Path.is_file()`. It contributes `File.Read`; missing paths and entries
that are not regular files return `false`. The `path.is_file()` method lowers to the
same typed operation, and a source-defined `is_file` shadows the compiler-known
operation.

`is_readable(path: Path)`, `is_writable(path: Path)`, and
`is_executable(path: Path)` are typed counterparts to shell `test -r/-w/-x` and
Python `os.access`. They query the current process access bits through POSIX
`access`, contribute `File.Read`, and return `false` for missing or invalid paths.
The equivalent `path.is_readable()`, `path.is_writable()`, and
`path.is_executable()` methods lower to the same checked `PathAccess` operation
and preserve the exact effect and error contract.

`touch(path: Path) -> bool error[FileIoError] can[File.Write]` creates an empty file
when it is missing and updates its timestamps without truncating an existing file.
It is the typed counterpart to shell `touch`; failures remain `FileIoError` values
rather than being hidden behind a process invocation.

`temp_file(prefix: sview) -> Path error[FileIoError] can[File.Write]` and
`temp_directory(prefix: sview) -> Path error[FileIoError] can[File.Write]` create
secure unique entries under `/tmp` through POSIX `mkstemp` and `mkdtemp`. The
prefix is optional (`temp_file()`/`temp_directory()`), must not contain `/` or an
embedded NUL, and is included only in the generated name. `mktemp`, `mkdtemp`, and
`temp_dir` are equivalent shell/Python-oriented aliases. A temporary file is
closed before the `Path` is returned; scripts explicitly remove it with
`remove_path` (or remove the directory with `remove_directory`/`remove_tree`).
Creation failures remain typed `FileIoError` values and never fall back to a
stringly shell command.

`chmod(path: Path, mode: u64) -> bool error[FileIoError] can[File.Write]` applies a
numeric POSIX mode such as `0x180u64` (octal `0600`). It is the typed counterpart to
shell `chmod` and Python `Path.chmod`; invalid paths or modes remain typed file-I/O
errors and no shell command is assembled.

`file_size(path: Path) -> usize error[FileIoError] can[File.Read]` returns the
length reported by POSIX `stat`, including regular files and directory entries.
Missing paths and invalid names raise `FileIoError`; the result is an unsigned,
64-bit byte count suitable for direct comparisons and differential tests. Python's
`os.path.getsize` spelling is a typed alias for this operation.

`file_mtime(path: Path) -> i64 error[FileIoError] can[File.Read]` returns the
POSIX modification timestamp from `stat`; Python's `os.path.getmtime` spelling
is a typed alias with the same error contract.

`file_atime(path: Path) -> i64 error[FileIoError] can[File.Read]` returns the
POSIX access timestamp from `stat`; Python's `os.path.getatime` spelling is a
typed alias. `file_ctime(path: Path) -> i64 error[FileIoError] can[File.Read]`
returns the POSIX inode-change timestamp (`st_ctime` on POSIX), and
`os.path.getctime` is its typed alias. Both remain distinct from modification
time while preserving the signed `i64`/`File.Read`/`FileIoError` contract.

`is_nonempty(path: Path) -> bool error[FileIoError] can[File.Read]` (also available
as `path.is_nonempty()`) is the typed
counterpart to shell `test -s` and the common Python `Path.stat().st_size > 0`
check. It returns `false` for an existing empty file, `true` for any entry with a
positive `st_size`, and preserves `FileIoError` for missing or invalid paths.
`file_nonempty` is an equivalent alias; lowering expands either spelling to the
verified `FileSize` plus typed unsigned `Greater` operations.

`file_mode(path: Path) -> u64 error[FileIoError] can[File.Read]` returns the
POSIX `st_mode` bits reported by `stat`, including the file-kind and permission
bits. It is the typed counterpart to shell `stat` mode queries and Python
`Path.stat().st_mode`, and pairs with `chmod` without requiring a stringly
metadata parser.

`is_symlink(path: Path) -> bool` is the shell `test -L` and Python
`Path.is_symlink()` predicate. It uses `lstat` rather than following the target,
contributes `File.Read`, and returns `false` for missing or non-symlink entries.
Python's `os.path.islink` spelling is a typed alias.

`readlink(path: Path) -> Path error[FileIoError] can[File.Read]` returns the link
target without following it, matching shell `readlink` and Python
`Path.readlink()`. `read_link` is an equivalent snake-case alias, and both
`path.readlink()` and `path.read_link()` lower to the same typed operation.

`symlink(target: Path, link: Path) -> bool error[FileIoError] can[File.Write]`
creates a symbolic link, matching shell `ln -s` and Python
`Path.symlink_to(target)`. `create_symlink` is an equivalent explicit alias;
the `link.symlink_to(target)` method uses the same typed operation.

`remove_tree(path: Path) -> bool error[FileIoError] can[File.Write]` recursively
removes a file, symbolic link, or directory tree without following symlink
directories. `rmtree` is an equivalent shell/Python-oriented alias. Traversal is
bounded to 128 levels and failures remain typed `FileIoError` values.

`copy_tree(source: Path, destination: Path) -> bool error[FileIoError]
can[File.Read, File.Write]` recursively copies files, directories, and symbolic
links while preserving link identity. `copytree` is an equivalent alias; the
destination root must not already exist, and traversal is bounded to 128 levels.

`read_text(path: Path) -> sview error[FileIoError]` reads a whole file without
discarding embedded bytes, subject to the interpreter's 64 MiB file-input safety
ceiling. It contributes the same `File.Read` effect and adds `FileIoError` to the
enclosing error row. Open, seek, read, and close failures, including an oversized
file, remain errors; a failed read is never confused with a successfully read empty file.
The shell-oriented `cat(path)` spelling is a typed alias for the same operation.

`write_text(path: Path, contents: sview) -> usize error[FileIoError]` replaces or
creates a file and returns the exact byte count written. It contributes `File.Write`
and `FileIoError`; partial writes and close failures are errors rather than apparent
success. Together, `path_exists`, `read_text`, and `write_text` form the first
complete filesystem round trip without shell or Python.

`read_bytes(path: Path) -> darray[u8] error[FileIoError] can[File.Read]` reads a
whole file as its exact bytes, including embedded NULs, subject to the interpreter's
64 MiB file-input safety ceiling, and returns an empty array for an empty file.
`read_binary` is an equivalent alias. The byte array is
strongly typed: arbitrary integer arrays are not accepted by the write operations.

`write_bytes(path: Path, bytes: darray[u8]) -> usize error[FileIoError]
can[File.Write]` replaces or creates a file and returns the exact number of bytes
written. `append_bytes` opens in append mode with the same typed contract, and
`write_binary`/`append_binary` are equivalent aliases. Invalid byte values cannot
be constructed through a well-typed `u8` array; runtime values are still checked
at the filesystem boundary, and partial writes or close failures remain
`FileIoError` errors.

`remove_path(path: Path) -> bool` removes a filesystem entry and contributes
`File.Write`. It returns `true` only when removal succeeded; a missing or otherwise
unremovable path returns `false`, following the core Elisa `remove_file` contract.
The nominal operand prevents accidental deletion through an arbitrary text value.
Python's `os.remove` and `os.unlink` spellings are typed aliases with the same
boolean result and `File.Write` effect.

Pure path-shape helpers keep path plumbing nominal without invoking the host OS:
`path_join(base: Path, leaf: sview) -> Path` inserts one `/` separator and lets an
absolute leaf replace the base, `path_parent(path: Path) -> Path` returns the
directory component (or empty `Path` when there is none), and
`path_name(path: Path) -> sview` returns the final component. `path_extension`
returns the final suffix including its dot (or empty text), while `path_stem`
returns the final component without that suffix. Their results are views over
permanent or input-owned bytes and are identical in the interpreter and packed
bytecode.

`Path.with_name(name: sview) -> Path` and `Path.with_suffix(suffix: sview) -> Path`
are pure pathlib-shaped rewrites built from those same operations. `with_name`
keeps the original parent and joins the supplied final component; `with_suffix`
keeps the parent, removes the final suffix through `path_stem`, and joins the
stem with the supplied suffix. They do not inspect or mutate the filesystem and
their arguments are statically checked as `sview`. The scripting profile keeps
the core path helpers permissive: an empty suffix therefore removes the final
suffix, and unusual component text follows the existing `path_join` rules
rather than introducing a new runtime error family.

`path_is_absolute(path: Path) -> bool` is the pure lexical counterpart to shell
absolute-path tests and Python `os.path.isabs`/`Path.is_absolute()`. It returns
`true` only when the path is non-empty and begins with `/`; it does not consult
the filesystem, resolve symlinks, or depend on the process working directory.
`is_absolute` and `isabs` are equivalent aliases, and `path.is_absolute()` lowers
to the same typed operation.

`path_normalize(path: Path) -> Path` performs lexical POSIX path cleanup without
consulting the filesystem. It collapses repeated `/` separators and `.`
components, removes a preceding component for `..` when possible, preserves
leading `..` components on relative paths, and keeps an absolute path rooted at
`/`. An empty relative path becomes `.`. The operation never resolves symlinks,
consults the current directory, or changes the filesystem. `normalize_path` and
`normpath` are equivalent aliases, and `path.normalize()` lowers to the same
pure typed operation.

`path_absolute(path: Path) -> Path error[DirectoryError] can[Directory.Read]`
constructs a cwd-aware absolute path using the lexical equivalent of Python
`os.path.abspath`: it joins a relative path to the current directory and then
applies the same normalization rules, while an already absolute path is simply
normalized. The current directory is read once through the typed directory
boundary; the parent process and filesystem are otherwise unchanged. The
`absolute_path` and `abspath` aliases, plus `path.absolute()`, lower to the same
typed operation.

`path_relative(target: Path, base: Path) -> Path` computes a normalized lexical
path from `base` to `target`, matching the common `os.path.relpath` porting shape
without touching the filesystem. Shared path components are removed, each
remaining base component contributes `..`, and an otherwise empty result is `.`.
Rooted and relative operands have different roots; for that case the normalized
target is returned unchanged. The `relative_path` and `relpath` aliases, plus
`target.relative_to(base)` as a scripting convenience, lower to the same pure
typed operation.

`path_real(path: Path) -> Path error[FileIoError] can[File.Read]` resolves a path
through the host filesystem, following symbolic links and returning the
canonical absolute path. It matches the common `readlink -f`,
`os.path.realpath`, and `Path.resolve()` porting shape; the `realpath` and
`resolve_path` aliases are equivalent, and `path.realpath()`/`path.resolve()`
are method forms. Unlike `path_normalize`, this operation consults the
filesystem and reports `FileIoError` when the input is empty, contains an
embedded NUL, or cannot be resolved.

`copy_path(source: Path, destination: Path) -> bool error[FileIoError]
can[File.Read, File.Write]` copies one regular file by length-delimited bytes and
replaces the destination. `move_path(source: Path, destination: Path) -> bool
error[FileIoError] can[File.Write]` performs an atomic POSIX rename within the
filesystem. Both operations reject arbitrary text at compile time and report
operating-system failures through `error[...]`; neither constructs a shell command.
Python's `shutil.copyfile` and `os.rename` spellings are typed aliases for
`copy_path` and `move_path`.

`append_text(path: Path, text: sview) -> usize error[FileIoError]
can[File.Write]` opens or creates the file in append mode and writes every supplied
byte after its existing contents. It returns the exact byte count and keeps the
same typed path, effect, and error contract as `write_text`; it is the explicit
counterpart to shell `>>` redirection and Python append-mode writes.
`append_lines(path: Path, lines: darray[sview]) -> usize` joins the supplied
lines with LF and delegates to the same append primitive, preserving the exact
line bytes and `File.Write`/`FileIoError` contract.

For direct shell-script and Python `pathlib` ports, the same typed operations
have short aliases: `dirname(path)`/`basename(path)`/`suffix(path)`/`stem(path)`
map to the corresponding path decomposition helpers, and `is_dir(path)` is an
alias for the directory predicate. A `Path` also exposes the common `pathlib`
shape members `path.parent`, `path.name`, `path.suffix`, and `path.stem`, plus
`path.joinpath(leaf)`, `path.exists()`, `path.is_file()`, `path.is_symlink()`,
`path.is_absolute()`,
`path.readlink()`, `path.read_link()`, `path.symlink_to(target)`, and
`path.is_dir()`; each lowers to the
same typed opcode as its free-function counterpart. For direct shell scripts and
Python `os.path` ports, `exists(path)`, `isfile(path)`, and `isdir(path)` are
typed aliases for `path_exists`, `is_file`, and `is_directory`; they retain the
nominal `Path` argument and the same effect/error contract. For direct shell scripts, the mutation aliases are:
`pwd()` is `current_directory()`, `cd(path)` is `change_directory(path)`,
`mkdir(path)`/`rmdir(path)` are single-level directory creation/removal;
`makedirs(path)`/`mkdir_p(path)` create missing parents, and
`rm(path)`, `cp(source, destination)`, and `mv(source, destination)` map to
`remove_path`, `copy_path`, and `move_path`. The aliases retain nominal `Path`
arguments, exact return types, effect rows, and error contracts; they do not add
shell flags or recursive/stringly behavior.
Python `os.getcwd()` and `os.chdir(path)` are typed aliases for the working-directory
operations, and `os.listdir(path)` is spelled `listdir(path)`.

Python `pathlib` file methods are also available on nominal `Path` values:
`path.read_text()`, `path.read_bytes()`, `path.write_text(text)`,
`path.write_bytes(bytes)`, `path.unlink()`, and `path.rename(destination)`.
They lower to the existing typed read, write, remove, and move operations, so
their effects, errors, and exact result types remain visible to every backend.
`path.glob(pattern)` and `path.rglob(pattern)` accept one `sview` pattern and
return deterministic `darray[sview]` matches rooted at the receiver; `rglob`
adds a recursive `**/` component. Both use the same bounded, symlink-safe glob
walker as `expand_glob` and carry `Directory.Read`/`DirectoryError`.
`path.iterdir()` takes no arguments and returns a deterministic `darray[sview]`
of rooted direct children. It performs no pattern filtering, includes dotfiles,
skips only the synthetic `.` and `..` entries, does not recurse, and carries the
same `Directory.Read`/`DirectoryError` contract as `list_directory`; each child
is represented as a nominal-path string rooted at the receiver.
The corresponding metadata and directory mutations are available as
`path.touch()`, `path.chmod(mode)`, `path.mkdir()`, and `path.rmdir()`;
these retain the same `File.Write` or `Directory.Write` effects and typed error
contracts as `touch`, `chmod`, `create_directory`, and `remove_directory`.
`path.touch(exist_ok: bool)` also accepts the Python-compatible named control:
the default is `true`, while `false` reports a `FileIoError` when any entry
already exists. Touch never truncates an existing file.
`path.mkdir(mode: u64, parents: bool, exist_ok: bool)` accepts Python-compatible
named controls. `mode` defaults to 493 (the conventional `0o755` permission)
and is restricted to the permission bits `0..4095` (`0o7777`); `parents` creates
missing ancestors like `mkdir -p`, while `exist_ok` succeeds when the final path
is already a directory. All three
controls default to their documented values, and invalid control types or modes
raise the ordinary `DirectoryError` rather than being silently ignored.

## Process execution

`executable(text) -> Executable error[ProcessError]` is the dynamic counterpart
to the `exe"..."` literal. It validates the runtime name before any process is
started; empty names and embedded NUL bytes are rejected through the ordinary
`error[...]` channel. A literal `exe"..."` is validated at compile time.

Assertions are typed runtime checks rather than a result wrapper:
`assert(condition) -> void error[AssertionError]`. The condition must be exactly
`bool`; integers, text, and other values are rejected during lowering instead of
being coerced through shell/Python-style truthiness. A true condition continues,
while false raises `AssertionError` through the ordinary `error[...]` channel, so
an enclosing `try ... else` or dynamic handler can recover it just like another
recoverable runtime error. The compiler-known intrinsic is shadowable by a user
function named `assert`, preserving normal Elisa name resolution.

`panic([message])` is the non-recoverable `Abort.Panic` effect. Its optional
message expression is evaluated exactly once, then the computation exits through
the checked execution boundary as `InterpretError.Panic`; ordinary `try ... else`
error recovery does not intercept it. This keeps programmer-assertion failures
distinct from declared `error[...]` variants while retaining a typed effect row
for callers and future native/JIT backends. The compiler-known intrinsic is
shadowable by a user function named `panic`.

Declared error families can be raised directly with `raise Family.Tag` inside a
function whose signature includes that family in `error[...]` (for example,
`def fail() -> void error[UserError]: raise UserError.Bad`). The operation has no
result and does not use a result wrapper: an enclosing `try ... else` recovers it,
and an uncaught raise exits through the ordinary checked error channel as
`InterpretError.Raised`. A payload-free `Family.Tag` catch arm selects the matching
raised identity; wildcard and `error` arms remain catch-all. Payload extraction is
left for the later error-payload runtime extension.

`run_process(executable: Executable, arguments: darray[sview]) -> i64
error[ProcessError] can[Process.Run]` starts a process from an explicitly typed
executable and argument vector. It never inserts a shell: spaces, wildcard characters,
quotes, and other shell syntax in an argument remain ordinary argument bytes.

`run_process_with_stdin(executable: Executable, arguments: darray[sview],
input: sview) -> i64 error[ProcessError] can[Process.Run]` is the status-only
counterpart for commands that consume standard input. It stages the exact
length-delimited input in a temporary file, executes the same shell-free argv,
and returns the child's exit status while discarding the captured output. It
shares the one-shot `ProcessCapture` implementation used by the explicit result
API, so stdin transport and status behavior remain identical across the
interpreter and bytecode backend.

`run_process_in_directory(executable: Executable, arguments: darray[sview],
directory: Path) -> i64 error[ProcessError] can[Process.Run]` is the status-only
working-directory counterpart. The child changes directory after `fork`, while
the parent interpreter's current directory is unchanged; an invalid child
directory produces the same setup status (`126`) as the explicit capture API.

`run_process_with_environment(executable: Executable, arguments: darray[sview],
environment: dict[sview, sview]) -> i64 error[ProcessError] can[Process.Run]`
applies the supplied name/value overrides only in the forked child and returns
its status. Environment names are validated with the same nonempty, NUL-free,
no-`=` and duplicate-name rules as the explicit capture API; the parent
environment remains unchanged.

`run_process_in_directory_with_environment(executable: Executable,
arguments: darray[sview], directory: Path, environment: dict[sview, sview]) -> i64
error[ProcessError] can[Process.Run]` composes both controls. The child changes
directory and applies overrides after `fork`; the parent world is unchanged and
setup failures retain the explicit capture API's status behavior.

The return value is the process exit status. Normal exits produce `0` through `255`;
signal termination produces `128 + signal`. Failure to create or wait for the process
raises `ProcessError`; waits poll without blocking indefinitely and terminate the
child after the interpreter's 120-second process deadline. If the executable cannot
be resolved, the child exits with status `127`.

`capture_process_stdout(executable: Executable, arguments: darray[sview]) -> sview
error[ProcessError] can[Process.Run]` uses the same shell-free argv contract and
returns the bytes written to standard output, up to the interpreter's 64 MiB
per-stream safety ceiling. Standard error remains inherited. The child redirects
stdout to an anonymous temporary file, avoiding pipe backpressure deadlocks; an
oversized capture raises `ProcessError` before allocation. Process creation,
redirection, seek, read, close, and wait failures raise `ProcessError`. Exit status is deliberately
orthogonal to captured bytes; a missing executable therefore yields empty output,
while `run_process` exposes its status `127` when status is the required observation.

`capture_process_stderr(executable: Executable, arguments: darray[sview]) -> sview
error[ProcessError] can[Process.Run]` is the descriptor-2 counterpart: it captures
bytes written to standard error under the same 64 MiB per-stream ceiling, while
standard output remains inherited. Both capture operations use the same typed argv
and temporary-file behavior, so selecting which stream to observe is explicit in
the function name and effect contract.

`capture_process_stdout_with_stdin(executable: Executable, arguments: darray[sview],
input: sview) -> sview error[ProcessError] can[Process.Run]` uses the same argv
contract while feeding an owned text snapshot through the child's standard input.
Input is staged in a temporary file before the child starts, so the operation has no
pipe-size deadlock or input truncation behavior. Captured output remains subject to
the 64 MiB per-stream ceiling. The child sees exactly the supplied bytes;
wildcards, spaces, and quotes in both arguments and input remain ordinary bytes.

`capture_process_stderr_with_stdin(executable: Executable, arguments: darray[sview],
input: sview) -> sview error[ProcessError] can[Process.Run]` is the descriptor-2
counterpart. It uses the same typed argv and temporary-file input staging, but returns
the child's stderr snapshot under the same 64 MiB ceiling while stdout remains
inherited.

`capture_process_result_in_directory(executable: Executable, arguments: darray[sview],
input: sview, directory: Path) -> ProcessCapture error[ProcessError] can[Process.Run]`
is the differential-testing variant with an explicit child working directory. The
directory is changed after fork and before descriptor setup/exec, so the parent
interpreter's current directory is never changed. It captures exit status, stdout,
and stderr with the same one-shot semantics as `capture_process_result`; an invalid
child directory is reported by the child as status `126`.

`capture_process_result_with_environment(executable: Executable, arguments: darray[sview],
input: sview, environment: dict[sview, sview]) -> ProcessCapture
error[ProcessError] can[Process.Run]` applies the supplied name/value overrides only
in the forked child before `exec`. The parent process environment is unchanged, and
the returned snapshot includes the child's status, stdout, and stderr, each stream
bounded by the 64 MiB interpreter ceiling. Environment names must be non-empty text
without NUL bytes; an invalid child `setenv` operation is reported as status `126`.

`capture_process_result_in_directory_with_environment(executable: Executable,
arguments: darray[sview], input: sview, directory: Path,
environment: dict[sview, sview]) -> ProcessCapture error[ProcessError]
can[Process.Run]` composes both child-only controls. The child changes to `directory`
and applies the environment overrides after `fork` and before descriptor setup or
`exec`; neither operation mutates the parent. Invalid directory or environment setup
is reported by the child as status `126`, while the returned snapshot keeps the same
exit-status, stdout, and stderr contract under the 64 MiB per-stream ceiling.

`capture_process_pipeline(executables: darray[Executable], arguments:
darray[darray[sview]], input: sview) -> ProcessCapture error[ProcessError]
can[Process.Run]` provides a shell-free pipeline for differential scripts. The two
arrays must have the same non-zero length; stage `i` receives `executables[i]`
and `arguments[i]`, and its captured stdout becomes the next stage's stdin.
Stages run sequentially through the same bounded temporary-file transport as
`capture_process_result`, so shell quoting, pipe backpressure, and inherited
working-directory changes are absent. The returned snapshot is the final stage's
status/stdout/stderr; a stage's non-zero exit status does not suppress later
stages, keeping status observation explicit through `process_exit_status`.

`ProcessCapture` also supports typed field access for ports that naturally model a
completed subprocess as a record: `result.returncode`, `result.exit_status`, and
`result.status` are aliases for `process_exit_status(result)`, while `result.stdout` and
`result.stderr` alias `process_stdout(result)` and `process_stderr(result)`.
The explicit `process_*` field spellings are accepted as well. All forms
lower to the same checked IR operations and require a nominal `ProcessCapture`
receiver; an unknown field is rejected statically.

## Program entry point

The launcher-facing program ABI is deliberately strict: a runnable script must
declare `main(arguments: darray[sview]) -> i64`. The runtime packs the process
arguments into one typed text array, so indexing, counting, and iteration use the
same checked array rules as every other value. The returned signed 64-bit integer
is the process exit status; effects and declared `error[...]` rows remain those of
the source function. `validate_elisascript_entrypoint` rejects a missing or
non-conforming `main` before bytecode execution, and
`execute_elisascript_program_source/file` provide the corresponding source and
file launch APIs. Hosts that need dynamic effect interception can use the
`*_with_handlers` variants and pass a typed `darray[Handler]`; the ordinary
APIs install no handlers.

The bundled driver (`src/driver/elisascript.elisa`) converts host `argv` into a
typed `darray[sview]` request. It performs no shell quoting, splitting, globbing,
or environment interpolation. `parse_elisascript_cli` requires the first value
to name a `.elisascript` file, rejects embedded NUL bytes, and preserves all
following values exactly; usage errors use process status `2`, while source or
execution failures use status `1`.

Source loading rejects `.elisascript` inputs larger than 4 MiB before parser-arena
allocation. This keeps the source boundary's size arithmetic bounded; generated
programs should be split into multiple modules rather than bypassing the limit.

## Standard streams

Standard streams are explicit typed operations rather than shell behavior. The
Python-shaped `print(value, ...) -> usize` convenience is compiler-known: it
formats text, `char`, any integer width, `f32`/`f64`, `bool`, text-backed nominal, array, and
dictionary arguments,
joins them with the typed text control `sep` (default `" "`), appends the typed
text control `end` (default `"\n"`), and delegates to the same stdout operation.
`echo` and
`println` are equivalent stdout aliases, while `eprint` writes the same typed
line to stderr. All four accept positional value arguments followed by at most
one `sep: sview`, one `end: sview`, and one `flush: bool` control. `flush` is a
typed compatibility spelling: stream writes use POSIX `write` directly, so
bytes are visible immediately and no additional user-space flush operation is
needed. The unsupported Python `file` control remains statically rejected:

- `read_stdin() -> sview error[ConsoleError] can[Console.Read]` reads bytes from file
  descriptor 0 until EOF, up to the interpreter's 64 MiB stdin safety ceiling, and
  returns an owned text snapshot. Read failures and oversized input are errors; an
  empty stream is a successful empty value.
- `read_stdin_line() -> sview error[ConsoleError] can[Console.Read]` reads exactly one
  line from file descriptor 0, up to the same 64 MiB ceiling, removes its LF (and an
  optional preceding CR), and returns an owned text snapshot. Repeated calls consume
  successive lines; reaching EOF before any bytes is a `ConsoleError`.
- `input()` and `input(prompt: sview)` are Python-compatible line reads. The optional
  prompt is written to stdout before the read, so the prompted form carries both
  `Console.Write` and `Console.Read`; both forms return `sview` and report
  `ConsoleError` at EOF, on I/O failure, or when the line exceeds the 64 MiB stdin
  safety ceiling. Prompt arguments are positional and must be text, and the prompt
  is not followed by an implicit newline.
- `write_stdout(text: sview) -> usize error[ConsoleError] can[Console.Write]` writes
  every byte to file descriptor 1 and returns the exact byte count.
- The shell-oriented `printf(text)` spelling is a typed no-newline alias for
  `write_stdout(text)`; it treats the argument as literal bytes and does not add
  an untyped format-string or shell-expansion layer.
- `write_stderr(text: sview) -> usize error[ConsoleError] can[Console.Write]` has the
  same contract for file descriptor 2.

Writes retry partial progress through the explicit stream state machine, so a short
POSIX write is never reported as successful completion. Neither operation parses or
constructs a command string, keeping stream data independent from shell quoting.

## Time and sleeping

Sleeping is a typed blocking effect rather than a shell command. The scripting
profile provides `sleep(seconds: f64) -> void error[TimeError] can[Time.Sleep]`
and the integer-precise `sleep_milliseconds(milliseconds: u64)` spelling. The
aliases `sleep_seconds` and `sleep_ms` preserve the same contracts. Integral
64-bit values are also accepted by the seconds forms for convenient ports of
shell `sleep`; negative values, NaN, and infinity raise `TimeError`.

The operation is lowered to one unit-tagged IR instruction. Both execution
backends call the POSIX `usleep` bridge in bounded chunks, so long waits and
fractional seconds have the same behavior without invoking a shell.

## Process environment

Environment access is explicit and typed rather than implicit global string magic:

- `get_environment(name: sview) -> sview error[EnvironmentError]
  can[Environment.Read]` returns an owned snapshot of the value. A missing or invalid
  name raises `EnvironmentError`, so it cannot be confused with a present empty value.
- `get_environment_or(name: sview, fallback: sview) -> sview` performs the same
  lookup but recovers a missing or invalid name with `fallback`. The fallback is
  evaluated lazily on the `EnvironmentError` edge, and the operation still records
  `Environment.Read`/`EnvironmentError` in the enclosing function's contract.
- Python `os.getenv` ports may use `getenv(name)` for the fallible lookup or
  `getenv(name, fallback)`/`getenv_or(name, fallback)` for lazy fallback behavior;
  these aliases preserve the same typed `sview` contract.
- `set_environment(name: sview, value: sview) -> bool error[EnvironmentError]
  can[Environment.Write]` replaces the process-global value and returns `true`.
- `unset_environment(name: sview) -> bool error[EnvironmentError]
  can[Environment.Write]` removes the key and returns `true`, including when absent.
  Python-style `setenv` and `unsetenv` are typed aliases for these mutations.

Names must be non-empty and neither names nor values may contain embedded NUL bytes.
These mutations intentionally affect later child processes and therefore make the
environment dependency visible in the inferred effect row.

## Directories and working directory

Directory operations use nominal `Path` values and structured `DirectoryError`:

- `create_directory(path: Path) -> bool can[Directory.Write]`
- `create_directories(path: Path) -> bool can[Directory.Write]`
- `remove_directory(path: Path) -> bool can[Directory.Write]`
- `change_directory(path: Path) -> bool can[Directory.Write]`
- `current_directory() -> Path can[Directory.Read]`

All four include `error[DirectoryError]`. Successful mutations return `true`;
operating-system failures are errors rather than ambiguous `false` values. Creation
uses mode `0755` before the process umask is applied. `current_directory` returns an
owned nominal snapshot, so a later directory change cannot mutate the saved path.
Empty paths and embedded NUL bytes are rejected before entering the POSIX boundary.
`create_directories` (also `makedirs` and `mkdir_p`) creates missing parents like
shell `mkdir -p` or Python `os.makedirs`, succeeds when each existing component is
a directory, and reports a typed error when a component is not one.

`list_directory(path: Path) -> darray[sview] error[DirectoryError]
can[Directory.Read]` returns owned entry basenames. It omits the synthetic `.` and
`..` entries and sorts remaining names by unsigned byte order, making discovery
deterministic rather than dependent on filesystem enumeration order. Opening,
enumeration, and close failures remain structured errors. Returned names do not
borrow the operating system's reusable directory-entry buffer.
The Python `listdir(path)` spelling is an equivalent typed alias.

`is_directory(path: Path) -> bool error[DirectoryError] can[Directory.Read]`
tests whether a path can be opened as a directory. Missing paths and ordinary files
return `false`; successful opens are closed before returning `true`, and close
failures remain errors. This predicate is also the traversal gate for native `**`
glob expansion, preventing ordinary files from becoming recursive scan nodes.

`expand_glob(pattern: Glob) -> darray[sview] error[DirectoryError]
can[Directory.Read]` expands path components with `*`, `?`, bracket classes and
backslash escapes. A component beginning with a wildcard does not match a leading
dot, matching shell glob behavior; an explicit leading dot does. A component exactly
equal to `**` recursively traverses directories to a bounded depth of 128, does not
follow symlink directories, and can match files at the terminal position. Results
are relative or absolute in the same form as the pattern, sorted by unsigned byte
order, deduplicated, and empty when there are no matches.

## Compile-time validation

`check_typed_literals.elisa` validates constant string payloads during the existing
recursive expression-resolution walk. It currently establishes the inexpensive
outer constraints available before the actual standard-library engines exist:

- Non-regex literals that require content reject empty payloads.
- Glob literals check character classes, braces, and incomplete escapes.
- Regex literals check character classes, parentheses, and incomplete escapes.
- Executable literals accept executable names rather than filesystem paths.
- URL literals require `scheme://authority` structure.

Failures use `DiagnosticKind.InvalidTypedLiteral` and retain the prefix, payload,
source position, and reason. These structural checks are a foundation, not the final
regex/glob/URL specification. Once the real parsers exist, compile-time validation
must call the same implementation used at runtime so the two cannot disagree.

## Verification

`test/semantic/elisascript_semantic_test.elisa` verifies:

- All five prefixes resolve without undefined-name diagnostics.
- Each prefix has its expected nominal result type.
- Malformed constant payloads produce compile-time diagnostics.
- Nominal literal results participate in assignment type checking.
- Shell/Python-compatible `sleep` aliases resolve as known builtins for the
  typed lowering pass.

Current result: 11/11 Elisascript semantic tests pass. Compiling this suite also
compiles the complete retained semantic layer and its exhaustive diagnostic tables.
