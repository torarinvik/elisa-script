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
shadows the prefix. A constant string payload emits a nominal `Constant`; a runtime
`sview` payload emits an explicit nominal constructor (`MakePath`, `MakeGlob`,
`MakeRegex`, `MakeExecutable`, or `MakeUrl`). Both forms preserve
`Path`/`Glob`/`Regex`/`Executable`/`Url` identity while the reference runtime stores
the payload as immutable text. Nominal values can cross exactly typed function
boundaries and use exact nominal equality; they do not implicitly become `sview` or
one another. Runtime constructors currently perform the type-safe text adaptation;
the corresponding path/glob/regex/URL parsers remain shared-library increments.

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
participate in alternation and greedy quantifiers, but are matching-only groups:
captures are not exposed. Group-local `^` and `$` retain their ordinary whole-text
meaning. `replace_regex(text, pattern, replacement) -> sview`
provides deterministic substitution for this grammar: it finds non-overlapping
matches from left to right and inserts the replacement text literally. Empty matches
advance one input byte (while retaining that byte) so replacement always terminates;
capture interpolation such as `$1` is intentionally not implied by the literal
replacement argument.

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

## Numeric text conversion

`parse_int(text) -> i64 error[ParseError]` accepts an optional leading `+` or `-`
followed by one or more ASCII decimal digits. It rejects whitespace, empty input,
trailing characters, and values outside signed 64-bit range through `ParseError`;
the failure is never represented as a sentinel integer. `format_int(value: i64) ->
sview` produces the canonical base-10 spelling, including `-0` normalization to
`0`. Both operations are compiler-known, shadowable by a source declaration, and
share exact behavior between the reference interpreter and packed bytecode.

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

`copy_path(source: Path, destination: Path) -> bool error[FileIoError]
can[File.Read, File.Write]` copies one regular file by length-delimited bytes and
replaces the destination. `move_path(source: Path, destination: Path) -> bool
error[FileIoError] can[File.Write]` performs an atomic POSIX rename within the
filesystem. Both operations reject arbitrary text at compile time and report
operating-system failures through `error[...]`; neither constructs a shell command.

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
