# Profiler-hook fallback generator companion

Original: `../Elisa-compiler/scripts/write_profiler_hook_fallbacks.sh` (SHA-256
`2aef7f050a1f216ef769f2f33242ae789f71172237602739fdb8a7301480587c`).
The original and its build/test callers remain unchanged. The companion
`write_profiler_hook_fallbacks.elisascript` has no filesystem or process effect:
it writes the generated C text to stdout. The pure model keeps the C lines in a
private namespace and adds one LF to each, matching the two quoted Bash
here-documents. Independent `base.c` and `host_callbacks.c` file goldens pin
the two emitted blocks; an authored bounded-read fixture compares the model
against those exact bytes. Only the **first** argument selects `--host-callbacks`; any
other first argument and all later arguments are ignored, as in the Bash script.
The golden SHA-256 digests are `e8d4c7fe5118a52a5f9c007404601967c7130b070875a2e93ad5ed4b75466c5d`
for `base.c` and `64fe483989e56cbcc61c68298b5290b2c94892ef68cdbe86e253b60e81435d22`
for `host_callbacks.c`; these record fixture identity, not observed execution.

This is authored source, not accepted parity. The shape and file-golden fixtures
are uncompiled and unrun. A dormant public-launcher matrix now pins the live
Bash source, candidate/model, goldens, shared runner/reader/gate sources and
tool identities. Its four cases cover default, host callbacks, an ignored first
argument and an ignored trailing argument. A replacement child environment
contains only PATH and LC_ALL. Each Bash observation must first complete with
status zero, empty stderr/host-error text and exact independent golden bytes;
only then can the candidate start and be compared exactly. Capture and wait
polling are bounded. The entry fails closed without explicit reauthorization,
an external active RSS-guard marker, a separately qualified native launcher,
the pinned StructPy compiler selection and distinct executable digests. Native
container headers are checked before any hash-tool child. The current dirty
differential runner deliberately fails its committed-source pin.

No Bash, candidate, compiler, hash-tool child or test fixture has been run for
this port. Compiler provenance, executable dependency closure, a real outer
memory cap, and source/bytecode runtime qualification remain external admission
requirements. The matrix is not proof of any of those, and no caller should
switch under the current validation hold.
