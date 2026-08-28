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
are parsed. This gives future CLI, editor, and differential-test adapters one
consistent contract instead of each reimplementing frontend sequencing.

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

## Deferred parser work

The following features belong to later, explicitly designed changes:

- Algebraic `effect` declarations
- Source handler declarations, operation clauses, and explicit `resume` expressions
- Multiline/raw typed literals
- Script-level dependency declarations if decorators are insufficient
- CLI derivation rules for `@command`

## Verification

- `test/parser/elisascript_parser_test.elisa`: Elisascript typed-literal behavior
- `test/parser/elisa_compat/parser_ast_test.elisa`: copied Elisa AST regression suite
- `test/parser/elisa_compat/parser_smoke.elisa`: copied parser embedding/codegen surface

Current result: 103 parser tests pass—100 inherited and 3 Elisascript-specific.
