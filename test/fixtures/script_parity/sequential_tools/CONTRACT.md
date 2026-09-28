# Sequential tool context and failure fixture (A07)

The independent POSIX shell reference and the Elisascript EsBuildExecutor
candidate run the same bounded workflow: check an explicit working directory
and exact child environment, emit and retain the text `prepared` followed by a
newline, run a command that exits nonzero, and skip its dependent sentinel. The
observable contract includes graph failure, each step's started/status/failure
fields, and captured stdout/stderr. Both reference and candidate start in
`/tmp`; the child probes explicitly switch/run in `/` with a cleared or exact
replacement environment. This makes the observations distinguish per-command
context from the parity runner's own cwd/environment. The 1 KiB per-command
output cap and five-second process timeout bound candidate subprocesses.

expected.txt is a byte-exact golden. The gated launcher test compares the
shell reference and candidate to this golden. It requires explicit validation
reauthorization, the pinned local compiler, a public-launcher hash, and the
active RSS guard. The fixture is source evidence only until run through the
bounded wrapper after the safety hold is lifted.
