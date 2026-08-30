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

## Text boundary predicates

The compiler-known `starts_with(text, prefix) -> bool` and
`ends_with(text, suffix) -> bool` operations provide the exact byte-oriented
prefix/suffix checks commonly used by shell and Python ports. Both arguments are
`sview`; an empty boundary succeeds, and a boundary longer than the input fails.
They are pure, deterministic, and shadowable by a source function with the same
name. Their dedicated IR operations are shared by the reference interpreter and
the direct bytecode backend.

The compiler-known `replace(text, old, replacement) -> sview` operation performs
literal, left-to-right, non-overlapping substitution. The `old` argument is not
parsed as a regular expression, so regex metacharacters remain ordinary bytes;
an empty `old` inserts the replacement at every input boundary, matching Python's
string behavior. It is pure, deterministic, shadowable, and returns owned text.

The compiler-known `strip(text) -> sview` and `trim(text) -> sview` names are
equivalent byte-oriented boundary operations. They remove ASCII space, tab, line
feed, vertical tab, form feed, and carriage return from the beginning and end,
preserve interior bytes, and return a view into the existing text value. Both are
pure, deterministic, and shadowable by source functions.

The compiler-known `lower(text) -> sview` and `upper(text) -> sview` operations,
as well as the Python-shaped `text.lower()` and `text.upper()` method spellings,
perform deterministic ASCII case conversion. ASCII letters are folded and all
other UTF-8 bytes pass through unchanged; this byte-oriented rule avoids locale
dependence or malformed Unicode transformations. The operations are pure,
shadowable (for the global spellings), and return owned text.

The compiler-known `split_lines(text) -> darray[sview]` (also accepted as
`splitlines(text)`) and the Python-shaped `text.splitlines()`/`text.split_lines()`
methods split on LF, CR, and CRLF boundaries. Trailing line breaks do not add an
extra empty field, while empty and consecutive lines remain observable. Empty
input returns an empty array; the operation is deterministic and byte-oriented.

Python-shaped text methods are available as statically typed aliases for the same
operations: `text.startswith(prefix)`/`text.starts_with(prefix)` and
`text.endswith(suffix)`/`text.ends_with(suffix)` return `bool`; `text.replace(old,
replacement)` returns `sview`; `text.strip()`/`text.trim()` return `sview`; and
`text.split(separator)` returns `darray[sview]`. Receivers and arguments must be
text values, method arity is checked during lowering, and `split` intentionally
requires an explicit separator rather than Python's implicit-whitespace mode.

Dictionary values expose the Python-compatible `mapping.keys()` method. It takes
no arguments, returns an insertion-ordered `darray[K]` for `dict[K, V]`, and uses
the same typed `MapKeys` operation as dictionary iteration. Set values do not
expose dictionary key views even though their first runtime representation shares
the map payload layout.
The matching `mapping.values()` method takes no arguments and returns an
insertion-ordered `darray[V]`, preserving the complete static value descriptor
through a dedicated `MapValues` operation. It is likewise unavailable on sets.

Text values also provide `text.count(substring) -> usize`. The operation counts
left-to-right non-overlapping byte matches; an empty substring counts the input
boundaries (`length + 1`). It is pure, deterministic, and rejects non-text
receivers or arguments during lowering.

The first executable regex operation is the compiler-known, strongly typed search
`matches(text, pattern) -> bool`, where `text` is `sview` and `pattern` is `Regex`:

```elisa
is_source: bool = matches("src/main.elisa", regex"^src/.*\\.elisa$")
```

Its initial runtime grammar supports literal characters, `.`, start/end anchors
`^` and `$`, escaped literals, character classes and ranges (`[abc]`, `[a-z]`,
`[^0-9]`), and the greedy quantifiers `*`, `+`, and `?`. The Perl-style shorthand
classes `\d`, `\D`, `\w`, `\W`, `\s`, and `\S` work both as atoms and inside
classes. Their meaning is deliberately ASCII and locale-independent so differential
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
complete match, `$$` emits a literal dollar, and `\&` emits a literal ampersand.
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

## Checked indexing and value recovery

The scripting profile keeps ordinary indexing strict: `values[index]` raises a
typed `IndexOutOfBounds` error for a missing array/text element or dictionary key.
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

For early propagation, the fallback may be a terminating clause:

```elisa
number: i64 = try parse_int(text) else return 0i64
```

The recovery block must end control flow (`return`, `break`, or `continue`);
successful evaluation continues through the surrounding state-machine merge.

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
checked value lookup for the second binder. Text iteration produces one-character
values.
Integer ranges stay counter-driven and do not materialize a temporary array:
`low..<high` is exclusive ascending, `low..=high` is inclusive ascending, and
`high..>low` is strict descending. The range-owned stride spelling
`low..<high..step` (and its inclusive/descending variants) requires a positive
integer constant and is applied in the latch state. Bounds and stride are
evaluated once. The result element type is inferred from the projection and
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
the matching element if present and is otherwise a no-op. Indexed set reads remain
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

Mutable arrays accept both Elisa's `values.push(element)` spelling and the
Python-compatible `values.append(element)` alias. Both require one positional
element of the exact array element type and rebind the mutable array through the
same ownership-safe SSA update; immutable arrays and mismatched elements are
rejected before execution. Python's zero-argument `values.pop()` returns the
exact element type and rebinds the mutable array to a shortened view. Empty
arrays raise `IndexOutOfBounds`; the failing operation does not publish a new
binding value. `pop` is intentionally zero-argument for now, keeping indexed
removal explicit through existing typed array operations.

## Text field processing

Elisascript provides a strongly typed compiler-known split operation for the core
shell/Python/AWK field-processing case:

```elisa
fields: darray[sview] = split("name::value", ":")
# ["name", "", "value"]
```

`split` preserves empty fields at every position. An empty separator splits a
nonempty string into byte-sized `sview` values and maps empty input to `[]`. These
rules are total, deterministic, and identical across the interpreter and future
bytecode, JIT, and native backends. A source function named `split` shadows the
compiler-known operation normally.

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
them as ordered `__fstr` pieces. Elisascript accepts text, signed `i64`, and `f64`
dynamic pieces and lowers the sequence to `Concat` instructions, inserting the
existing `FormatInt`/`FormatFloat` conversion for numeric values. Integers use
canonical decimal formatting and floats use the core `%g` spelling. Literal
pieces use the same escape decoder as ordinary strings, and expressions are
evaluated exactly once from left to right. Booleans and aggregates are rejected
until an explicit formatting operation is used. `format_bool(value: bool) ->
sview` provides canonical lowercase `true`/`false` text for boolean values.
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
sugar. The collection is still evaluated once and the loop remains an explicit
state-machine CFG.
Mutable iteration remains restricted to arrays. Map equality is order-insensitive
but matches pairs one-to-one, so malformed duplicate entries cannot be reused to
hide a mismatch.

## Numeric text conversion

`parse_int(text) -> i64 error[ParseError]` accepts an optional leading `+` or `-`
followed by one or more ASCII decimal digits. It rejects whitespace, empty input,
trailing characters, and values outside signed 64-bit range through `ParseError`;
the failure is never represented as a sentinel integer. `format_int(value: i64) ->
sview` produces the canonical base-10 spelling, including `-0` normalization to
`0`. Both operations are compiler-known, shadowable by a source declaration, and
share exact behavior between the reference interpreter and packed bytecode.
`parse_float(text) -> f64 error[ParseError]` accepts decimal mantissas with an
optional sign, fractional part, and `e`/`E` exponent (including an exponent sign).
It rejects missing digits, trailing characters, and incomplete exponents. The
matching `format_float(value: f64) -> sview` uses Elisa's `%g`-style canonical
runtime spelling and keeps the returned text in permanent storage.
`format_bool(value: bool) -> sview` returns canonical lowercase `true` or `false`.

## Filesystem capability

The first executable filesystem primitive is
`path_exists(path: Path) -> bool`. It accepts the nominal `Path` type rather than
an arbitrary string and contributes `File.Read` to the enclosing function's effect
row. The reference interpreter executes it through Elisa's own
`elisacore_fileio.elisa` runtime; it does not invoke a shell or Python. A
source-defined `path_exists` function shadows the compiler-known operation.

`read_text(path: Path) -> sview error[FileIoError]` reads a whole file without
discarding embedded bytes. It contributes the same `File.Read` effect and adds
`FileIoError` to the enclosing error row. Open, seek, read, and close failures
remain errors; a failed read is never confused with a successfully read empty file.

`write_text(path: Path, contents: sview) -> usize error[FileIoError]` replaces or
creates a file and returns the exact byte count written. It contributes `File.Write`
and `FileIoError`; partial writes and close failures are errors rather than apparent
success. Together, `path_exists`, `read_text`, and `write_text` form the first
complete filesystem round trip without shell or Python.

`remove_path(path: Path) -> bool` removes a filesystem entry and contributes
`File.Write`. It returns `true` only when removal succeeded; a missing or otherwise
unremovable path returns `false`, following the core Elisa `remove_file` contract.
The nominal operand prevents accidental deletion through an arbitrary text value.

Pure path-shape helpers keep path plumbing nominal without invoking the host OS:
`path_join(base: Path, leaf: sview) -> Path` inserts one `/` separator and lets an
absolute leaf replace the base, `path_parent(path: Path) -> Path` returns the
directory component (or empty `Path` when there is none), and
`path_name(path: Path) -> sview` returns the final component. `path_extension`
returns the final suffix including its dot (or empty text), while `path_stem`
returns the final component without that suffix. Their results are views over
permanent or input-owned bytes and are identical in the interpreter and packed
bytecode.

`copy_path(source: Path, destination: Path) -> bool error[FileIoError]
can[File.Read, File.Write]` copies one regular file by length-delimited bytes and
replaces the destination. `move_path(source: Path, destination: Path) -> bool
error[FileIoError] can[File.Write]` performs an atomic POSIX rename within the
filesystem. Both operations reject arbitrary text at compile time and report
operating-system failures through `error[...]`; neither constructs a shell command.

## Process execution

`executable(text) -> Executable error[ProcessError]` is the dynamic counterpart
to the `exe"..."` literal. It validates the runtime name before any process is
started; empty names and embedded NUL bytes are rejected through the ordinary
`error[...]` channel. A literal `exe"..."` is validated at compile time.

`run_process(executable: Executable, arguments: darray[sview]) -> i64
error[ProcessError] can[Process.Run]` starts a process from an explicitly typed
executable and argument vector. It never inserts a shell: spaces, wildcard characters,
quotes, and other shell syntax in an argument remain ordinary argument bytes.

The return value is the process exit status. Normal exits produce `0` through `255`;
signal termination produces `128 + signal`. Failure to create or wait for the process
raises `ProcessError`. If the executable cannot be resolved, the child exits with
status `127`.

`capture_process_stdout(executable: Executable, arguments: darray[sview]) -> sview
error[ProcessError] can[Process.Run]` uses the same shell-free argv contract and
returns every byte written to standard output. Standard error remains inherited.
The child redirects stdout to an anonymous temporary file, avoiding both pipe
backpressure deadlocks and fixed capture limits. Process creation, redirection,
seek, read, close, and wait failures raise `ProcessError`. Exit status is deliberately
orthogonal to captured bytes; a missing executable therefore yields empty output,
while `run_process` exposes its status `127` when status is the required observation.

`capture_process_stderr(executable: Executable, arguments: darray[sview]) -> sview
error[ProcessError] can[Process.Run]` is the descriptor-2 counterpart: it captures
every byte written to standard error, while standard output remains inherited. Both
capture operations use the same typed argv and temporary-file behavior, so selecting
which stream to observe is explicit in the function name and effect contract.

`capture_process_stdout_with_stdin(executable: Executable, arguments: darray[sview],
input: sview) -> sview error[ProcessError] can[Process.Run]` uses the same argv
contract while feeding an owned text snapshot through the child's standard input.
Input is staged in a temporary file before the child starts, so the operation has no
pipe-size deadlock or truncation behavior. The child sees exactly the supplied bytes;
wildcards, spaces, and quotes in both arguments and input remain ordinary bytes.

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
the returned snapshot includes the child's status, stdout, and stderr. Environment
names must be non-empty text without NUL bytes; an invalid child `setenv` operation
is reported as status `126`.

`capture_process_result_in_directory_with_environment(executable: Executable,
arguments: darray[sview], input: sview, directory: Path,
environment: dict[sview, sview]) -> ProcessCapture error[ProcessError]
can[Process.Run]` composes both child-only controls. The child changes to `directory`
and applies the environment overrides after `fork` and before descriptor setup or
`exec`; neither operation mutates the parent. Invalid directory or environment setup
is reported by the child as status `126`, while the returned snapshot keeps the same
exit-status, stdout, and stderr contract.

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

## Standard streams

Standard streams are explicit typed operations rather than implicit print or shell
behavior:

- `read_stdin() -> sview error[ConsoleError] can[Console.Read]` reads all bytes from
  file descriptor 0 until EOF and returns an owned text snapshot. Read failures are
  errors; an empty stream is a successful empty value.
- `write_stdout(text: sview) -> usize error[ConsoleError] can[Console.Write]` writes
  every byte to file descriptor 1 and returns the exact byte count.
- `write_stderr(text: sview) -> usize error[ConsoleError] can[Console.Write]` has the
  same contract for file descriptor 2.

Writes retry partial progress through the explicit stream state machine, so a short
POSIX write is never reported as successful completion. Neither operation parses or
constructs a command string, keeping stream data independent from shell quoting.

## Process environment

Environment access is explicit and typed rather than implicit global string magic:

- `get_environment(name: sview) -> sview error[EnvironmentError]
  can[Environment.Read]` returns an owned snapshot of the value. A missing or invalid
  name raises `EnvironmentError`, so it cannot be confused with a present empty value.
- `set_environment(name: sview, value: sview) -> bool error[EnvironmentError]
  can[Environment.Write]` replaces the process-global value and returns `true`.
- `unset_environment(name: sview) -> bool error[EnvironmentError]
  can[Environment.Write]` removes the key and returns `true`, including when absent.

Names must be non-empty and neither names nor values may contain embedded NUL bytes.
These mutations intentionally affect later child processes and therefore make the
environment dependency visible in the inferred effect row.

## Directories and working directory

Directory operations use nominal `Path` values and structured `DirectoryError`:

- `create_directory(path: Path) -> bool can[Directory.Write]`
- `remove_directory(path: Path) -> bool can[Directory.Write]`
- `change_directory(path: Path) -> bool can[Directory.Write]`
- `current_directory() -> Path can[Directory.Read]`

All four include `error[DirectoryError]`. Successful mutations return `true`;
operating-system failures are errors rather than ambiguous `false` values. Creation
uses mode `0755` before the process umask is applied. `current_directory` returns an
owned nominal snapshot, so a later directory change cannot mutate the saved path.
Empty paths and embedded NUL bytes are rejected before entering the POSIX boundary.

`list_directory(path: Path) -> darray[sview] error[DirectoryError]
can[Directory.Read]` returns owned entry basenames. It omits the synthetic `.` and
`..` entries and sorts remaining names by unsigned byte order, making discovery
deterministic rather than dependent on filesystem enumeration order. Opening,
enumeration, and close failures remain structured errors. Returned names do not
borrow the operating system's reusable directory-entry buffer.

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

Current result: 3/3 Elisascript semantic tests pass. Compiling this suite also
compiles the complete retained semantic layer and its exhaustive diagnostic tables.
