# Smallest real-project port: canonical lint wrapper

Reference: `../neural-computer-agentV2/scripts/lint_canonical.sh` (six lines).
Its unmodified snapshot is `reference.sh` in this directory, with SHA-256
`fd013f06d3575ed426f1c464fb8b4fb7378fe71deb982cef4a2ae8b4c353fa35`.
Candidate: `ports/neural-computer-agentV2/scripts/lint_canonical.elisascript`.
No original script or caller has been changed.

The `ports/<project>/` hierarchy mirrors the target project's layout. Before
testing, copy the candidate to an isolated project's
`scripts/lint_canonical.elisascript` and the reference to
`scripts/lint_canonical.sh`. Do not launch the candidate directly from its
storage location: that tree is not the neural-computer project. Once qualified,
the companion can be installed beside the live original, without removing it.

## Intended ordinary lint behavior

Enter the project root based on the script's source path, irrespective of the
caller's working directory. Unset and empty `RUFF_BIN` both select `ruff` on
the inherited PATH. A nonempty value is a single executable name/path; it is
not split on spaces or interpreted as a command string. Relative executable
paths are resolved after entering the project root. Arguments are exactly:

```text
check
src
tests
experiments/brainworkshop_canonical
```

Extra wrapper arguments are ignored. Stdin, stdout, stderr, and the environment
are inherited rather than captured; normal Ruff exit statuses are returned
unchanged. No shell, Python interpreter, or legacy wrapper is launched by the
candidate. Ruff remains an explicit lint-tool dependency, not an orchestration
language replacement target. Timeout zero deliberately disables the process
runner's default deadline, matching the reference's lack of a deadline.

## Required differential cases (not executed)

Use the same deterministic executable probe for both wrappers in isolated
temporary project trees. Record exact argv as length-prefixed bytes, physical
cwd, selected environment values, stdin bytes, stdout/stderr bytes, and status.
Do not test by actually linting or altering the live training project.

The authored native probe source/protocol is in
`test/fixtures/script_parity/process_probe/`, with an independent Elisa
expected-frame model in `test/script_parity/process_probe_model.elisa`.
Qualification and wrapper-launcher integration remain unexecuted. Its complete
binary frame needs more than a 64 KiB capture budget at the largest admitted
input; use the protocol's combined-stream bound.

| Case | Required observation |
| --- | --- |
| RUFF_BIN unset | Probe named `ruff` on fixture PATH is selected |
| RUFF_BIN empty | Same default as unset, not an empty executable |
| RUFF_BIN absolute path with spaces | One executable, no word splitting |
| RUFF_BIN relative path with spaces | Resolved in project root, not caller cwd |
| Invoke from unrelated cwd | Probe sees fixture project root |
| Project path with spaces | Same cwd and four argv entries |
| Extra arguments containing spaces/empty strings | None forwarded to Ruff |
| Probe exits 0, 1, 2, or 23 | Exact status, no wrapper-added output |
| Binary stdin/stdout/stderr, including NUL and no final newline | Exact inherited bytes, no framing or newline added |
| Inherited environment marker | Marker preserved, RUFF_BIN unchanged |

## Known gaps: do not claim full exec parity

The current `run_process` forks and waits in a separate process group instead
of replacing the wrapper process. PID identity, job control, interactive TTY
signals, cancellation, and externally observed signal termination therefore
need separate design and qualification. Returning `128 + signal` is not the
same as the wrapper itself being killed by that signal.

Bash emits its own diagnostics and uses statuses 126/127 for execution
failures. The current runner's child uses 127 for any failed exec and emits no
equivalent Bash diagnostic. Directory/environment/host-runner failures have
candidate-specific diagnostics and status 1. These are not accepted as exact
reference parity. Bash's logical `cd`/PWD handling and symlink spelling also
need dedicated cases; launcher source-path normalization is not proof of
equivalence to `dirname "$0"`.

`test/script_parity/canonical_wrappers_launcher_test.elisascript` now authors
four ordinary lint cases alongside the test-wrapper family: unset/empty RUFF_BIN,
relative/absolute probe paths with spaces, ignored extras, binary streams,
marker inheritance, and statuses 0/1/2/23. Each program is checked against
independently supplied expected probe bytes, not just against the other program.
The probe is checked first against literal golden stdout. A shared isolated
read-only fixture is used for these dummy-tool cases; source/probe copies are
hashed before and after the matrix. This does not provide independent mutable
filesystem worlds for future tools that write files.

This is a source-only candidate and authored automated fixture, not a passing
replacement or complete parity suite. Compiler, launcher, lint, and parity execution remain
disabled until explicitly reauthorized; future validation must use the pinned
local compiler and the working bounded RSS guard. Retain the original wrapper
until ordinary lint behavior and the chosen error/signal policy are qualified.
