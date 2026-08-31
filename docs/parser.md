# Elisascript parser

Elisascript retains Elisa's complete parser and AST. Scripting features should
prefer desugaring into ordinary Elisa nodes so every later compiler stage can
reuse existing traversal, typing, ownership, and code-generation machinery.

## Retained parser

All 36 files under `vendor/elisa-compiler/src/parser` are retained. Every file is
in the `parser.elisa` include closure, and each belongs to syntax Elisascript keeps:

- `parser_tokens.elisa`: AST node, annotation, error, and side-table model
- `parser_core*`: parser state, token cursor, blocks, and recovery
- `parser_expr*`: primary, postfix, unary, binary, query, and literal expressions
- `parser_stmt*`: assignments, control flow, matching, effects, machines, and patterns
- `parser_decl*`: modules, decorators, implementations, laws, and typestates
- `parser_types*`: functions, structs, enums, errors, externs, and signatures
- `preprocess_static_generate.elisa`: Elisa static-generation preprocessing
- `parser.elisa`: the complete parser facade and public entry points

Removing a parser file would remove part of Elisa rather than merely remove
compiler-product tooling. Driver and backend reduction therefore happens outside
this directory.

## Canonical source loading

File-based callers should use `EsIr.lower_elisascript_source` as the single
typed source boundary. It accepts a NUL-terminated filename and source buffer,
requires the filename to end in `.elisascript`, and performs the stages in a
fixed order inside one caller-owned region:

```elisa
module: EsIr::Module = EsIr::lower_elisascript_source(
    "tools/build.elisascript",
    source,
    "build"
)
```

The boundary runs tokenization, parsing, the copied `Semantic::check`, IR
lowering, and target-independent verification. Parse, semantic, lowering, and
verification failures are raised through `ElisascriptSourceError`; there is no
fallback module or `Result` sentinel. The extension predicate is itself an
explicit state machine, so a wrong suffix is rejected before any source bytes
are parsed. This gives the CLI, editor, and differential-test adapters one
consistent contract instead of each reimplementing frontend sequencing.
Semantic warnings remain visible to callers but do not make a valid source file
unloadable; only severity-1 semantic diagnostics stop the pipeline.

When the source already lives on disk, `EsIr.lower_elisascript_file` performs the
same pipeline after reading the file. It validates the suffix before opening the
path, copies both the filename and source bytes into permanent runtime storage,
and raises `ElisascriptSourceError.FileIo` for open, seek, read, or close
failures. Embedded NUL bytes are rejected as `ElisascriptSourceError.EmbeddedNul`
before parsing, rather than silently truncating a C-string source. The permanent
backing keeps source spans and text constants valid after the loader returns.

Hosts that install dynamic effect handlers can use
`lower_elisascript_source_with_handlers` and
`lower_elisascript_file_with_handlers`. These entry points keep the typed
handler table outside parsing and semantic analysis, then attach it before IR
verification; the no-handler APIs remain the default for ordinary scripts.

## Typed literal desugaring

An identifier immediately adjacent to a string literal is parsed as a one-argument
ordinary Elisa call:

```elisa
path"src/main.elisa"
regex"(?<name>[a-z]+)"
glob"src/**/*.elisa"
```

becomes the same AST shape as:

```elisa
path("src/main.elisa")
regex("(?<name>[a-z]+)")
glob("src/**/*.elisa")
```

The shorthand also accepts a triple-quoted payload, so `regex"""..."""` and
similar forms have the same AST shape while allowing embedded newlines. Bare
triple-quoted text remains a block comment at the lexer boundary. An escaped
closing delimiter is retained as payload, so quote runs can be embedded without
changing the desugared call shape.

Explicit integer suffixes are carried on the literal AST node itself. For example,
`1u8 + 2u8` contains two `IntLitTyped` nodes, each with its own suffix. This avoids
the old line-keyed metadata ambiguity when several differently typed literals occur
on one source line; unsuffixed literals retain the compact `IntLit` representation.

The representation is:

```text
Expr.Call(
    Expr.Ident(prefix),
    [Expr.StringLit(payload)],
    [""]
)
```

No `TypedLiteral` AST variant and no prefix-specific variants are introduced.
This provides several useful properties:

- Literal families are added by libraries and semantic validators, not parser edits.
- Existing expression visitors already understand the result.
- Name resolution determines which prefixes are in scope.
- Static validation can specialize a known literal call later.
- A normal user-defined function can participate in the syntax.

Only direct byte adjacency enables the shorthand. Whitespace separates the
identifier from the literal and does not trigger desugaring.

## Interpolated strings

Elisa f-strings retain their normal syntax and desugar to the compiler-owned
`__fstr` call:

```elisa
message: sview = f"hello {name}!"
```

The result is an ordered sequence of literal and expression pieces. Elisascript's
IR accepts text, `char`, every integer width, `f32`/`f64`, `bool`, text-backed
nominals, arrays, and dictionaries. Numeric, boolean, character, nominal, and
aggregate pieces are converted through the existing `FormatInt`/`FormatFloat`/
`FormatBool`/`FormatChar`/`FormatNominal`/`FormatAggregate` operations, then
lowered to ordinary typed `Concat` operations, so conversion, evaluation order,
and allocation behavior remain visible to every backend.

## Effect payloads

Elisa's contextual signal statement accepts an optional ordinary argument list:

```elisa
signal Progress.Tick(current + 1, "compile")
```

The existing call-suffix parser handles positional payload expressions, so evaluation
order and expression syntax are identical to Elisa calls. Named payloads are rejected
until operation declarations provide authoritative parameter labels. Until the recursive AST
ABI gains a dedicated signal node, the arguments are stored as ordered expression
statements in `Stmt.Block("signal", ...)`; existing semantic block visitors therefore
resolve and type-check them without a parallel traversal.
Lowering requires the clause to use exactly one non-empty `Family.Operation`
separator; bare families and multi-dot references are diagnosed instead of
becoming implicit synthetic operations.

Value-producing effects remain ordinary call-shaped parser nodes. The IR lowerer
recognizes `perform("Family.Operation", payload)` only where an expected result
type is available, preserving Elisa's expression grammar while keeping the
effect reference and result type statically visible.

Error-family declarations use the same enum-shaped AST metadata as Elisa:
`error UserError:` records its variants without requiring a runtime declaration.
`raise UserError.Bad` is parsed as a `raise` call with one `Field` operand, while
`raise UserError.Bad(value, ...)` wraps that field in a constructor call and preserves
the positional payload expressions. Lowering keeps the family/tag identity for
checked propagation and evaluates constructor payloads in source order.

## Effect declarations

Elisascript accepts algebraic effect-family declarations using Elisa's declaration
shape. A family may contain bodiless operation signatures:

```elisa
effect Writer:
    def write(value: sview) -> void
```

An effect with no operations may use the compact marker form `effect Marker: pass`.

The parser keeps the existing declaration ABI and records the family plus its
first-level operation names and payload arities in file metadata. Semantic analysis
uses that registry to make both `signal Writer.write(...)` and value-producing
`perform("Writer.write", payload)` statically checkable;
operations on builtin or permission-only families remain host-defined. Operation
parameter/return contracts are still checked at handler clauses and performed
values by the IR verifier, so a source effect declaration never weakens callback
typing.

Script-level dependency declarations remain deferred if decorators prove
insufficient.

Source operation handlers use the existing decorator syntax alongside the
declaration metadata above. A top-level callback can declare one exact
operation clause with `@handler("name", "Family.Operation")`; an optional third
argument selects `Linear`, `Affine`, `MultiReplay`, or `MultiClone`. Multiple callbacks
may contribute clauses to the same handler, and their ordinary typed parameters and
return types are checked against performed payloads and resumed values by the IR
verifier. Callback bodies may use `resume("name", payload)` for value-producing
operations. Host-supplied `Handler` descriptors remain supported for applications that
need captures, introduced effects, or explicit error rows.

The launcher does not depend on deferred `@command` derivation: the current
driver uses the explicit `main(arguments: darray[sview]) -> i64` program ABI and
the typed `parse_elisascript_cli` boundary described in the semantics guide.

## Verification

- `test/parser/elisascript_parser_test.elisa`: Elisascript typed-literal behavior
- `test/parser/elisa_compat/parser_ast_test.elisa`: copied Elisa AST regression suite
- `test/parser/elisa_compat/parser_smoke.elisa`: copied parser embedding/codegen surface

Current result: 103 parser tests pass—100 inherited and 3 Elisascript-specific.
