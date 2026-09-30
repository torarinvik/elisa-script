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
unchanged. Like Bash `cd`, the candidate updates exported `OLDPWD` and `PWD`
before launching Ruff. A dedicated probe checks those values from a clean
environment. No shell, Python interpreter, or legacy wrapper is launched by
the candidate. Ruff remains an explicit lint-tool dependency, not an
orchestration language replacement target. Timeout zero deliberately disables
the process runner's default deadline, matching the reference's lack of a
deadline.

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
| RUFF_BIN bare name with spaces | One executable searched on fixture PATH, not split |
| Invoke from unrelated cwd | Probe sees fixture project root |
| Project path with spaces | Same cwd and four argv entries |
| Extra arguments containing spaces/empty strings | None forwarded to Ruff |
| Probe exits 0, 1, 2, 23, 126, 127, or 255 | Exact normal status, no wrapper-added output |
| Binary stdin/stdout/stderr, including NUL and no final newline | Exact inherited bytes, no framing or newline added |
| Inherited environment marker | Marker preserved, RUFF_BIN unchanged |
| Ruff stand-in replaces itself with a process terminated by SIGTERM | Reference is signaled (`Crash`, status 143, empty streams); candidate must match the terminal outcome, not merely complete with status 143 |

Seventeen additional isolated observations cover exported directory variables. Two
start in `/` with a replacement environment that omits `PWD` and `OLDPWD`,
then record the NUL-delimited values after entering the project via its
physical path and a symlink alias. A third starts in `/` with `PWD` set to a
symlink alias of `/` and checks that `OLDPWD` retains that valid logical
spelling. The fourth invokes both scripts through a relative source path from
the project root's parent, with `PWD` omitted, and checks the absolute new and
old directories. Each expected byte sequence is independently constructed from
the invoked root and expected old directory. A fifth combines a relative
`./scripts/...` invocation with a valid symlinked `PWD` pointing at the same
project directory. A sixth invokes the wrapper through a relative source path
with nonempty `CDPATH` set to the caller directory; Bash resolves the relative
`cd` operand there and emits the selected absolute directory before the probe's
bytes. A seventh supplies nonempty `CDPATH` with an absolute source path and
expects no `cd` output, since Bash does not search `CDPATH` for an absolute
operand. An eighth makes the first `CDPATH` entry missing and the second the
caller directory; it expects the latter selection and output. A ninth puts an
empty entry first, followed by the caller directory, and expects the current
directory selection without an output line. A tenth uses the relative `.`
entry and expects CDPATH selection/output. An eleventh searches an existing
`tools` directory that does not contain the project, then expects Bash's
ordinary relative-operand fallback without a CDPATH output line. A twelfth
searches through a symlinked `CDPATH` entry, expecting the logical alias in the
selected-directory line and exported `PWD` while the probe's physical cwd
remains the project root. A thirteenth invokes through a `./<project>/scripts`
spelling with nonempty `CDPATH`; a fourteenth starts with a `../` source
spelling and nonempty `CDPATH`. Both operands are relative, so successful
nonempty `CDPATH` matches print the resulting logical directory before the
probe's independently pinned new/old `PWD` bytes. Only `dirname` is inside
the reference's command substitution; `cd` itself runs directly and continues
to the probe. A fifteenth sets `HOME` so a `~//...` CDPATH entry resolves to
the fixture caller directory, pinning current-user expansion and preservation
of repeated suffix separators. The candidate preserves the raw source operand
separately from
normalized `Script::source_path()` through `Script::invocation_path()`, and
uses it for relative-root `CDPATH` lookup and output. These cases are authored
but uncompiled/unrun; alternate relative entries, additional no-match
conditions and other symlinked `CDPATH` shapes remain open. A sixteenth uses
`~+` with `PWD` set to the fixture caller directory; a seventeenth uses `~-`
with `OLDPWD` set there. Named-user and indexed directory-stack CDPATH tilde
forms remain open. It also
validates inherited logical `PWD` against
the physical cwd, preserves it for `OLDPWD`, and computes new logical `PWD`
lexically before verifying its physical target. Odd `//`, path-race and
complex `..` cases remain open.

## Known gaps: do not claim full exec parity

The current `run_process` forks and waits in a separate process group instead
of replacing the wrapper process. PID identity, job control, interactive TTY
signals, cancellation, and externally observed signal termination therefore
need separate design and qualification. Returning `128 + signal` is not the
same as the wrapper itself being killed by that signal.

`signal_probe.sh` is staged as executable `RUFF_BIN` and sends SIGTERM to its
own PID. The dormant matrix admits the reference first against the literal
`Crash`/143/empty-stream contract, then requires the candidate to match that
outcome. Source inspection predicts the current child-waiting candidate returns
`Completed`/143 instead; this is an authored regression case, not an observed
run. No signal or fixture was executed while validation remains disabled.

Bash emits its own diagnostics and uses statuses 126/127 for execution
failures. The current runner's child uses 127 for any failed exec and emits no
equivalent Bash diagnostic. Directory/environment/host-runner failures have
candidate-specific diagnostics and status 1. These are not accepted as exact
reference parity. The observations cover physical and simple symlink-alias
project roots, one inherited logical cwd spelling, one relative source-path
invocation, and their relative-plus-symlink combination. These do not establish
every Bash logical-`cd` edge or symlink spelling. Launcher source-path
normalization is not proof of equivalence to `dirname "$0"`.

`test/script_parity/canonical_wrappers_launcher_test.elisascript` now authors
eleven ordinary lint cases before the test-wrapper family: unset/empty RUFF_BIN,
relative/absolute probe paths and a bare PATH-searched name with spaces, ignored
extras (including empty strings, glob/variable/semicolon literals and options),
binary streams, marker inheritance, and normal statuses 0/1/2/23/126/127/255.
The 126/127 cases are successful probe executions returning those statuses;
they do not qualify failed exec diagnostics or error classification.
Each program is checked against
independently supplied expected probe bytes, not just against the other program.
The reference must meet its independent expected observation before the
candidate is launched for that case.
The probe is checked first against literal golden stdout. A shared isolated
read-only fixture is used for these dummy-tool cases; source/probe copies are
hashed before and after the matrix. The SIGTERM case and seven actual
exec-failure cases run after ordinary cases. This does not provide independent
mutable filesystem worlds for future tools that write files.

The dormant entry now defaults to `EsCanonicalWrapperScope::Wave.LintOnly`:
the lint reference, candidate, shared invocation model, signal probe and
directory-environment probe are identity-checked and copied; three Ruff probe aliases are installed, and
exactly eleven lint cases are selected. No
canonical/campaign test wrapper or `.venv/bin/python` fixture is staged in this
wave. These eleven are ordinary argv/status cases; the matrix additionally
runs one signal-termination case, seventeen directory-environment cases, and seven
exec-failure cases, for thirty-six observations total in the lint wave.
Source/case count checks reject silently
empty or reduced selections. The wider twenty-one ordinary-case selection
remains available through an explicit
`public_launcher_parity(EsCanonicalWrapperScope::Wave.WrapperFamily)` call;
with the same signal, all seventeen directory-environment cases, and exec-failure
checks, that wave has forty-six observations. The default test does not advance to it automatically. Wave
selection does not grant execution authorization or prove that a preceding
wave passed.
Pure scope fixtures are in `test/script_parity/canonical_wrapper_scope_test.elisa`
and import no native runner. They have not been compiled or run.

Delivery order is lint first, then the nine-line environment query, then the
fourteen-line codec gate and larger wrappers. Keep working on a small script's
own blockers and shared dependencies rather than treating a source port as an
accepted replacement. Full exec parity still requires the failure/signal policy
above, not just the ordinary eleven cases.

This is a source-only candidate and authored automated fixture, not a passing
replacement or complete parity suite. Compiler, launcher, lint, and parity execution remain
disabled until explicitly reauthorized; future validation must use the pinned
local compiler and the working bounded RSS guard. Retain the original wrapper
until ordinary lint behavior and the chosen error/signal policy are qualified.
