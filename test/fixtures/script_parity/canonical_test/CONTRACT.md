# Canonical/campaign test-wrapper family

Real references are `../neural-computer-agentV2/scripts/test_canonical.sh` and
`../neural-computer-agentV2/scripts/test_campaign.sh`. Unchanged snapshots in
this directory have these SHA-256 identities:

| Reference | SHA-256 |
| --- | --- |
| test_canonical.sh | c81db16fcb7662ae88161d167247d8705aa0cdfb090dd4ecfb184ae045b9ef07 |
| test_campaign.sh | 7d2178ce4729f88835bf283aa4a265cdc6c1b859daab0a8de41883e8409c83dc |

The candidate family is stored under
`ports/neural-computer-agentV2/scripts/`: `test_canonical.elisascript` and
`test_campaign.elisascript` both include `canonical_test.elisascript`, which
contains the namespaced implementation with no main function. Copy all three
companions beside the originals in an isolated project before launcher tests.
Their storage tree is not itself the live training project. Neither original
script nor its callers are changed.

This replaces shell orchestration, not the repository's Python test suite.
The selected Python executable runs the purpose-built pytest tool. No candidate
calls an original shell wrapper, a Python automation script, or a shell command
string. Replacing Python tests themselves is outside this port's scope.

## Ordinary invocation semantics

Resolve the source directory, then enter its parent project root. Select
`PYTHON_BIN` as one executable name/path; unset and empty values both select
`.venv/bin/python`. Relative paths are evaluated after the cwd change. Neither
executable names nor caller arguments are word-split, globbed, expanded, or
evaluated. Stdin/stdout/stderr and the environment are inherited. Normal child
status is returned unchanged, with no default deadline.

Canonical mode consumes the first wrapper argument, if present. Missing or
empty mode means fast. Only exact lowercase `fast`, `campaign`, and `all` are
accepted. Every remaining argument is preserved, including empty arguments,
spaces, literal shell metacharacters, `--`, and additional pytest options.

| Mode | Python argv prefix before caller extras |
| --- | --- |
| fast (also absent/empty) | `-m`, `pytest`, `-q`, `-m`, `not campaign` |
| campaign | `-m`, `pytest`, `-q`, `-m`, `campaign` |
| all | `-m`, `pytest`, `-q` |

The campaign companion forces campaign mode without consuming any caller
argument. For example, its caller's `all` is forwarded as a pytest operand,
not reinterpreted as a mode. Repeated `-m` options are preserved in order; the
wrapper does not second-guess pytest's own precedence rules.

The shared runner explicitly progresses through cwd change, environment
selection, mode decoding, and tool launch. An invalid canonical mode produces
status 2 and usage on stderr without launching the tool, even if the configured
Python executable does not exist. An inaccessible root fails before mode
decoding, matching the shell's order on ordinary inputs. Usage includes the
unmodified invocation spelling (`$0`), not the compiler's normalized source
path; pure source fixtures pin relative spellings, but launcher-level
diagnostic-byte observations remain required.

## Authored pure fixtures and required launcher cases

`test/script_parity/canonical_test_arguments_test.elisascript` contains pure
typed-error/argv assertions for default/empty modes, all three explicit modes,
case-sensitive invalid modes, empty and space-containing arguments,
metacharacters, `--`, and campaign forwarding. Those tests do not execute a
tool. They are authored, not passing runtime evidence.

For gated public-launcher cases, use the same deterministic native executable
probe in isolated temporary project trees, not actual pytest.

The authored probe source/protocol and independent Elisa expected-frame model
are under `test/fixtures/script_parity/process_probe/` and
`test/script_parity/process_probe_model.elisa`. They are not yet qualified
binaries or passing tests. Budget captures for the complete binary frame, not
just the human-readable argv prefix.

`test/script_parity/canonical_wrappers_launcher_test.elisascript` authors 21
ordinary cases across this family and lint (10 test-wrapper cases plus 11 lint
cases): all three canonical modes, absent
and empty mode, forced-campaign forwarding, unset/empty PYTHON_BIN, relative/
absolute paths with spaces, literal caller arguments, nonzero statuses, and
binary streams. The same isolated read-only dummy-tool project is used for the
reference and candidate, so physical cwd bytes can be compared exactly. Copied
scripts/probes are hashed before and after the matrix; cleanup rejects unknown
remaining files instead of recursively sweeping them. This does not replace
independent mutable worlds for tools with filesystem side effects.

`test/script_parity/canonical_test_cases.elisa` owns the ten independent
test-wrapper expectations and imports only the data-only lint case types, not
the candidate's argument builders or a host/process implementation. Its six
existing cases are retained, with four additions: campaign without arguments
and unset Python selection; campaign with empty Python selection, empty/CRLF/
Unicode arguments and a normal 255 exit; all mode with a literal metacharacter
executable and normal 126 exit; and campaign mode with a literal PATH name,
repeated `-m`, LF/Unicode arguments and normal 127 exit. These normal statuses
are not exec-failure provenance. Data-only fixture assertions pin the new
vectors and metadata; the separate pure argument-builder fixture compares the
actual builders against all ten literal vectors. No fixtures have run.

The family expectation source is pinned before/after an explicitly selected
family wave. The default lint wave remains eleven ordinary cases plus seven
actual lint exec-failure cases; it neither constructs nor executes test-wrapper
cases. A broader source fixture is not authorization to advance acceptance.

The public entry gates hash tools and all program launches on explicit opt-in,
the outer RSS marker, pinned local compiler path/hash, launcher path/hash, and
`ELISASCRIPT_PROCESS_PROBE` / `ELISASCRIPT_PROCESS_PROBE_SHA256`. It starts no
compiler itself and requires a separately qualified prebuilt native probe.
Bash, wrapper snapshots, candidates/helper, probe source and expected-frame
model have recorded pins; tool/source identities are checked again after
cleanup. A probe run from `/` must match literal golden stdout bytes before any
wrapper run; wrapper expectations use declared literal argv vectors, never
the candidate's argument builders.

Process captures are bounded to 256 KiB and 10,000 wait polls per invocation.
Source copies are preflighted at 512 KiB each/2 MiB total; the qualified probe
is at most 16 MiB and has four isolated copies in the family wave (three in
the default lint wave). Underlying copy/runtime bounds
and the outer time/RSS guard still apply; preflight size checks do not prove a
descriptor-level bound against racing source changes. The RSS environment
marker is a prerequisite, not proof of an OS hard cap. No probe compilation or
qualification has happened, so none of these cases is passing evidence.

Invalid-mode usage text, spawn failures, signals, TTYs, symlinks/PWD and separate
mutable-world assertions remain outside this ordinary-case fixture. Do not
report the fixture as complete exec/error parity if its ordinary cases pass.

- Record exact length-framed argv, physical cwd, selected environment values,
  stdin bytes, stdout/stderr bytes, and status for all pure cases above.
- Test PYTHON_BIN unset/empty with the probe installed at `.venv/bin/python`,
  and explicit relative/absolute executable paths containing spaces.
- Invoke each wrapper from an unrelated cwd and a project path with spaces.
- Probe statuses 0, 1, 2, and 23; output without a final newline; binary stdin
  and both output streams; preserve an inherited environment marker.
- Verify invalid mode starts no probe; invalid mode plus a missing executable
  still returns usage/status 2. Cwd failure must happen first.
- Preserve executable mode on the reference canonical snapshot: the campaign
  reference execs that sibling script directly, rather than running Bash on it.
- Pin the two references, three candidate files, probe, launcher, and local
  compiler identities. Gate process launches in the fixture's public entry,
  use the existing RSS/time guard, bounded captures and explicit opt-in, and
  clean up only isolated recorded paths, including partial setup failures.

Compare independently expected observations, not just reference/candidate
agreement. Campaign may not be implemented by calling its original shell
wrapper or by routing the candidate to the reference.

The default three-case `CampaignOnly` wave isolates the smallest wrapper's
forced-mode and argument-forwarding behavior. It stages both unchanged shell
scripts because the reference campaign shim execs its sibling canonical wrapper,
but stages only the campaign Elisascript entry point and shared implementation.
It does not run lint ordinary, signal, or exec-failure cases. The broader
`WrapperFamily` wave remains unchanged and explicit.

The seven-case `CanonicalOnly` wave separately exercises the mode parser,
forwarded pytest argv, and Python selection for the shared 26-line runner. It
stages the canonical shell reference and its Elisascript entry/helper, without
the campaign shim or lint assets. It also skips lint signal and exec-failure
cases.

Each wrapper wave hashes the live shell reference or references it uses against
the unchanged snapshots before setup and after cleanup. `CanonicalOnly` checks
`test_canonical.sh`; `CampaignOnly` and `WrapperFamily` check both the canonical
and campaign wrappers. This prevents a stale fixture snapshot from silently
standing in for a changed real reference. Hashing is observational, not an atomic
lock against concurrent edits; no live script is executed by the check.

## Open parity gaps

The current runner forks/waits instead of Bash exec, so PID identity,
interactive job control/signals, cancellation, and signal termination remain
unqualified. Bash's 126/127 execution failures/diagnostics are not reproduced
by the runner; host/cwd/environment failures use candidate-specific messages.
Logical PWD and symlink spelling also need dedicated qualification.

Usage text uses the candidate's absolute source path; Bash uses the invocation's
raw `$0`. Besides the different `.elisascript` filename, these may differ in
relative/symlink spelling. Status 2, usage shape, and no-launch behavior can be
specified now, but exact invalid-mode stderr equality is not claimed. Do not
silently normalize this difference in an exact comparator. A future language
invocation-path API or explicitly approved diagnostic policy must resolve it.

No compiler, pytest, pure fixture, or public launcher ran for this change.
Validation remains disabled until explicitly reauthorized. Keep both originals
until the public-launcher matrix and chosen error/signal policy are qualified.
