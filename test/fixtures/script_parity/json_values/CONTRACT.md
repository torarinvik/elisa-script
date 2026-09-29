# C06 JSON value-semantics parity slice

The Python reference and Elisascript candidate load the same bounded JSON
object, emit a deterministic projection, and serialize the loaded object as
compact UTF-8 JSON. It covers an integer larger than
64 bits, nested object/array access, Unicode strings, booleans, null versus a
missing member, and Python's default last-value-wins behavior for duplicate
object keys. The output check also verifies duplicate normalization, insertion
order, no-whitespace separators, exact integer spelling, and unescaped UTF-8.
The JSON Lines slice parses multiple records in memory, including an
unterminated final record, and compares compact serialization in record order.
A second path reads a checked-in `.jsonl` file through the bounded file-stream
adapter and compares the same per-record output against Python. Both process
outputs and the checked-in golden are compared.

This is a deliberately narrow behavior slice, not a claim of full Python
`json` compatibility. Numeric conversion/formatting beyond the exact integer
lexeme, custom decoder hooks, non-finite numbers, and error wording remain
separate acceptance work.
