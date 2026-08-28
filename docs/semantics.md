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
is present. Alternation, grouping, captures, and replacement are reserved for the
shared compiled regex engine; they are not silently delegated to a host regex
implementation.

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
