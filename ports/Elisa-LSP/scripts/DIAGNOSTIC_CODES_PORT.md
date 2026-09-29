# Diagnostic-code generator: pure projection seam

Original: `../Elisa-LSP/scripts/generate_diagnostic_codes.py` (SHA-256
`72590cfa8a4a9fb05888bd95e09b53391d5c34c30f4ec14ba4d9e9fd71cd6dbe`).
Its compiler enum source currently has SHA-256
`6b9363e40d883f83efa451a4cfd279e0ce3a76710bcf3f37f0dd157cb73a5a87`;
the checked-in LSP adapter has SHA-256
`f97fe2c6f0194c813a8aa2968121f839e6499cc8debda30a3791d35824aa8285`.
These are source identities, not observed parity. The Python original and its
callers remain unchanged.

`diagnostic_codes_model.elisa` extracts exactly twelve-space ASCII enum names
after the eight-space `const enum DiagnosticKind of u16:` declaration, stops at
the next same-level enum/extend declaration, rejects missing/duplicate member
sets, and renders the exact generated adapter format. It has explicit source,
variant-count and output budgets. Pure synthetic fixtures cover indentation,
order, stopping and duplicates. A bounded read-only fixture compares the
projection of the real compiler enum to the checked-in generated adapter.
All fixtures are authored but uncompiled and unrun.

`generate_diagnostic_codes.elisascript` is an authored CLI companion for the
ordinary `--compiler-root`, `--output` and `--check` forms. It reads the enum
with a 128 KiB UTF-8 bound, compares the checked-in output in check mode, and
otherwise writes the rendered adapter, following the Python script's direct
write behavior. Its no-option compiler root resolves from the script location
in either this `ports/Elisa-LSP/scripts` checkout or a deployed sibling LSP
checkout. The output default remains cwd-relative, as in Python. No invocation
has run.

This is not yet a qualified replacement. Python `argparse` help/error wording,
all malformed arguments, Unicode whitespace accepted by its regex, source/tool
identity qualification, exact failure status/stderr, and a bounded
Python-vs-public-launcher parity matrix remain open. The original and callers
remain unchanged. Do not run a compiler or parity validation under the current
hold.
