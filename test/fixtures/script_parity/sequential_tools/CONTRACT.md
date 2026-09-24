# Sequential tool failure fixture (A07)

The independent POSIX shell reference and the Elisascript EsBuildExecutor
candidate run the same bounded three-step workflow: emit and retain the text
prepared followed by a newline, run a command that exits nonzero, and skip its dependent
sentinel. The observable contract includes graph failure, each step's
started/status/failure fields, and captured stdout/stderr. The 1 KiB per-command
output cap and five-second process timeout bound the candidate subprocesses.

expected.txt is a byte-exact golden. The gated launcher test compares the
shell reference and candidate to this golden. It requires explicit validation
reauthorization, the pinned local compiler, a public-launcher hash, and the
active RSS guard. The fixture is source evidence only until run through the
bounded wrapper after the safety hold is lifted.
