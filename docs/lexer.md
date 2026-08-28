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

## Deferred lexical design

Multiline and raw typed literals need an explicit design before implementation.
Bare triple quotes are currently Elisa block comments, so a future multiline form
must preserve that behavior while giving regexes, templates, SQL, and embedded
documents a readable representation.

## Verification

- `test/lexer/elisascript_lexer_test.elisa` covers shebangs and typed literal tokenization.
- `test/lexer/elisa_compat/lexer_machine_state_test.elisa` retains the copied Elisa
  machine-state regression tests and their lexer fixtures.

Run both with the current Elisa compiler:

```text
elisac -emit test test/lexer/elisascript_lexer_test.elisa
elisac -emit test test/lexer/elisa_compat/lexer_machine_state_test.elisa
```
