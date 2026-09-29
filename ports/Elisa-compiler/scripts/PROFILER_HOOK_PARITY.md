# Profiler-hook fallback generator companion

Original: `../Elisa-compiler/scripts/write_profiler_hook_fallbacks.sh` (SHA-256
`2aef7f050a1f216ef769f2f33242ae789f71172237602739fdb8a7301480587c`).
The original and its build/test callers remain unchanged. The companion
`write_profiler_hook_fallbacks.elisascript` has no filesystem or process effect:
it writes the generated C text to stdout. The pure model keeps the C lines in a
private namespace and adds one LF to each, matching the two quoted Bash
here-documents. Only the **first** argument selects `--host-callbacks`; any
other first argument and all later arguments are ignored, as in the Bash script.

This is authored source, not accepted parity. The pure shape fixtures are
uncompiled and unrun. Before switching any caller, a separately authorized,
RSS-bounded public-launcher matrix must pin the live Bash source and tool
identities, run default/host-callbacks/ignored-argument cases with bounded
stdout and stderr capture, admit independent expected status and bytes for the
reference first, then compare the candidate exactly. Compiler provenance,
artifact closure, runtime memory bound and cleanup remain open. Do not launch
that matrix or a compiler under the current validation hold.
