# C05 CSV parser/encoder parity slice

The Python reference and Elisascript candidate consume the same bounded CSV
corpus, map the header into a two-text-field schema, and emit canonical CSV
with LF records and minimal quoting. The corpus covers an ordinary row, a
quoted delimiter, doubled quote escaping, a quoted embedded newline, an empty
cell, and UTF-8. Both sides also report whether an unterminated quoted record
is rejected. The golden output is the normalized CSV stream followed by that
failure marker.

This slice does not claim full Python `csv` compatibility. Dialects, byte
encodings beyond UTF-8, field-size edge cases, blank records, BOM handling,
and all error-message differences remain separate acceptance work.
