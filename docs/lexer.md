# Elisascript lexer

Elisascript deliberately retains Elisa's complete lexical grammar. The scripting
profile adds source-file behavior without turning shell, Python, or Perl syntax
into new language syntax.

## Retained source files

All eight files under `vendor/elisa-compiler/src/lexer` are required:

- `lexer.elisa`: facade and shared cursor operations
- `tokens.elisa`: token and lexer state model
- `lexer_core.elisa`: indentation, identifiers, Unicode, and suffix primitives
- `lexer_identifiers.elisa`: keyword classification
- `lexer_numbers.elisa`: integer, float, hexadecimal, and numeric suffix scanning
- `lexer_strings.elisa`: strings, characters, and interpolated strings
- `lexer_comments.elisa`: comments, line directives, and Elisascript shebangs
- `lexer_tokens.elisa`: token dispatch, operators, and public tokenization entry points

No lexer source was removed during the initial reduction because every file is in
the `lexer.elisa` include closure and each owns language behavior Elisascript keeps.

## Elisascript adaptation

A `#!` sequence at byte zero is consumed as source metadata. Its newline is
consumed, physical line numbering is preserved, and the shebang is not reported
as a source comment to tooling. A `#!` elsewhere remains an ordinary Elisa `#`
comment.

## Typed literals

The lexer does not hard-code scripting literal names. These forms:

```elisa
path"src/main.elisa"
glob"src/**/*.elisa"
regex"(?<name>[a-z]+)"
exe"git"
url"https://example.com"
```

remain an adjacent `Ident` and `StringLit`. The parser and semantic layer will
interpret the prefix, validate the payload, and assign the result type. This keeps
literal namespaces extensible without expanding `TokenKind` for every library.

## Multiline typed literals

An adjacent identifier may also prefix a triple-quoted string:

```elisa
regex"""^src/.*\\.elisa$
"""
sql"""select *
from files
"""
```

The lexer emits the same adjacent `Ident` and `StringLit` pair as for an ordinary
typed literal, and the parser applies the same one-argument call desugaring. The
payload may span physical lines; its source bytes (including newlines and unknown
backslash escapes) are preserved until the shared literal decoder runs. Elisa's
known escapes (`\\n`, `\\t`, `\\r`, `\\0`, `\\\\`, `\\"`, `\\'`, `\\xNN`, and `\\uNNNN`)
are decoded consistently by the reference interpreter and bytecode engine.
The closing delimiter is escape-aware: a `"""` run preceded by an odd number of
backslashes stays in the payload, allowing embedded quote runs; an even run closes
the literal normally.

Bare `"""..."""` remains an Elisa block comment. Triple-quoted literal mode is
therefore only selected when the opening delimiter is directly adjacent to an
identifier (including identifiers whose final character is a digit), keeping
existing comments source-compatible.

## Verification

- `test/lexer/elisascript_lexer_test.elisa` covers shebangs, typed literal tokenization,
  multiline payloads, and preservation of bare triple-quoted comments.
- `test/lexer/elisa_compat/lexer_machine_state_test.elisa` retains the copied Elisa
  machine-state regression tests and their lexer fixtures.

Run both with the current Elisa compiler:

```text
elisac -emit test test/lexer/elisascript_lexer_test.elisa
elisac -emit test test/lexer/elisa_compat/lexer_machine_state_test.elisa
```
