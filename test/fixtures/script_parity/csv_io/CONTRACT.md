# C05 CSV parser/encoder parity slice

The Python reference, colocated `reference.elisascript` translation and
`candidate.elisascript` consume the same bounded CSV corpus, map the header
into a two-text-field schema, and emit canonical CSV with LF records and
minimal quoting. The corpus covers an ordinary row, a quoted delimiter,
doubled quote escaping, a quoted embedded newline, an empty cell, and UTF-8.
All three also report whether an unterminated quoted record is rejected. The
golden output is the normalized CSV stream followed by that failure marker.
The Python reference ignores `sys.argv`; the reference port is checked with an
extra option-looking argument and an empty argument to preserve that behavior.
The older candidate is invoked with no arguments in this slice.

This slice does not claim full Python `csv` compatibility. Dialects, byte
encodings beyond UTF-8, field-size edge cases, blank records, BOM handling,
and all error-message differences remain separate acceptance work.

The bounded launcher matrix compares Python, the port and the candidate
independently against `expected.txt`; runtime parity remains unqualified until
that test runs under the bounded wrapper.
