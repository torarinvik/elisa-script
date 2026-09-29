# First replacement: canonical lint

Start with the six-line shell wrapper captured in
`test/fixtures/script_parity/canonical_lint/reference.sh`, and its companion
`ports/neural-computer-agentV2/scripts/lint_canonical.elisascript`.
Neither is an accepted replacement yet. Keep originals and callers unchanged.

## Smallest source-only check

`test/script_parity/canonical_lint_cases.elisa` owns the eight ordinary
reference expectations in a public typed module. Its separate pure fixtures pin
every executable selection, normally returned status, ignored wrapper argument
and fixed Ruff argv. They import neither the port nor the differential runner.
This permits a small compilation target when compilation is explicitly
reauthorized; the fixtures have not been compiled or run.

The dormant launcher consumes those same expectations, pins the model's SHA-256
before and after the matrix, and defaults to lint only. It does not construct
canonical/campaign test cases in that wave. Each reference observation must match
the independent probe expectation before its candidate is launched. Choosing a
wave does not authorize execution or advance to the next script.

## Acceptance remains closed

The ordinary matrix checks unset/empty/default, relative/absolute/PATH executable
selection, fixed literal arguments, project cwd, binary stdin/stdout/stderr and
normal exit statuses. These are authored cases, not observed results.
Normal probe exits 126/127 do not qualify missing/denied executable behavior.

Before switching a live caller, qualify the pinned local compiler, launcher,
probe, native ABI, ownership/reaping and external time/RSS containment under
explicit user authorization. Then observe every ordinary case through the
public launcher. Also resolve and exercise actual exec failures, signals and
descendants, cancellation, cwd/entry-path failures and wrapper-versus-exec process
identity. The companion returns a generic status 1 on a typed process error;
that must not be confused with a legacy child returning after exec failed.
No full shell equivalence or accepted migration is claimed.

## Returned exec failures (source-only correction)

The legacy interpreter previously exited 127 after every returned execvp call,
including access denial. Its four launch paths now share a private helper that
uses a C-width errno pointer borrowed in the parent before fork. Only a native
-1 return admits the immediate errno sample: ENOENT/ENOTDIR select 127; access
denial and other returned failures select 126. Unexpected/bridge returns select
126 without consulting stale errno. Small pure fixtures cover the classification
and invalid-return boundaries; they remain uncompiled/unrun.

This does not publish launch-error receipts or emit Bash-compatible diagnostics.
The parent still cannot distinguish exec failure from a tool normally returning
126/127. libc execvp's text-file shell fallback, async-signal safety of the
generated child call graph, inherited errno-pointer lifetime and native ABI also
remain unqualified. The preferred explicit parent-prepared spawn path remains
unwired; this narrow legacy correction neither enables it nor closes acceptance.

Finish this contract first; then take the nine-line Skia environment query,
followed by the fourteen-line UI codec gate. Larger wrappers, generators and
build drivers remain later work. Compiler, native and parity execution remains
paused; SSH and other agents' processes are outside this work.
