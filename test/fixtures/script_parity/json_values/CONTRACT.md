# C06 JSON value-semantics parity slice

The Python reference and Elisascript candidate load the same bounded JSON
object and emit a deterministic projection. It covers an integer larger than
64 bits, nested object/array access, Unicode strings, booleans, null versus a
missing member, and Python's default last-value-wins behavior for duplicate
object keys. Both process output and a checked-in golden are compared.

This is a deliberately narrow behavior slice, not a claim of full Python
`json` compatibility. Numeric conversion/formatting beyond the exact integer
lexeme, custom decoder hooks, non-finite numbers, error wording, and streaming
JSONL behavior remain separate acceptance work.
