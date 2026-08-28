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

The shared IR recognizes these five compiler-known calls when no source function
shadows the prefix and the payload is a constant string. It emits a nominal
`Constant`, preserving `Path`/`Glob`/`Regex`/`Executable`/`Url` identity while the
reference runtime stores the validated payload as immutable text. Nominal values
can cross exactly typed function boundaries and use exact nominal equality; they
do not implicitly become `sview` or one another. Dynamic constructor payloads stay
explicit lowering errors until the corresponding standard-library runtime parser exists.

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
character classes remain literal members. Grouping, captures, and replacement are
reserved for the shared compiled regex engine; they are not silently delegated to
a host regex implementation.

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

## Process execution

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
