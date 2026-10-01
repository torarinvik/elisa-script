# First replacement: canonical lint

Start with the six-line shell wrapper captured in
`test/fixtures/script_parity/canonical_lint/reference.sh`, and its companion
`ports/neural-computer-agentV2/scripts/lint_canonical.elisascript`.
Neither is an accepted replacement yet. Keep originals and callers unchanged.

## Smallest source-only check

`test/script_parity/canonical_lint_cases.elisa` owns the eleven ordinary
reference expectations in a public typed module. Its separate pure fixtures pin
every executable selection, normally returned status, ignored wrapper argument
and fixed Ruff argv. The companion and fixture now share the typed
`lint_canonical_invocation.elisa` definition for default/empty executable
selection and the four fixed command arguments; the oracle compares those values
to independent literals. This is source alignment, not observed parity. The
fixtures import neither the launcher nor the differential runner. They have not
been compiled or run.

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

The gate additionally requires seven actual exec-failure plans from
`canonical_lint_exec_failure_cases.elisa`: missing and denied targets each use
relative, absolute and PATH names, followed by an absolute directory target.
The denied target is a pinned probe copy with mode 0600, not an executable probe
alias. Missing-name absence, denied-file mode/type/nonexecutability, directory
type and absence of unintended PATH matches are checked before and after each
run. The copy belongs to the temporary root's existing cleanup ledger. These
checks are observations, not atomic protection against external mutation.

Each reference must complete with the independently specified 126/127 status,
empty host-error text, empty stdout and nonempty stderr before the candidate may run. Exact stderr
bytes then come from the pinned reference and must match without normalization;
there is no separate literal diagnostic-byte oracle. The seven plans have small
pure path/status fixtures; neither fixtures nor matrix have been compiled/run.
Both available waves include these lint failure checks. Current missing exec
diagnostics are an expected open gap, not a reason to skip these cases.

The matrix also stages `test/fixtures/script_parity/canonical_lint/signal_probe.sh`
as an executable `RUFF_BIN`. It terminates its own PID with SIGTERM. The
independent reference contract is a signaled `Crash` with status 143 and empty
streams; a candidate that completes normally with integer 143 is rejected. The
reference is admitted before the candidate. This case is authored and unrun;
source inspection predicts that today's fork/wait candidate returns a completed
status instead of replacing its process. It exposes the D11 gap without
pretending that status arithmetic proves signal parity. It runs after the
eleven ordinary lint cases. Twenty-two observations cover directory variables:
clean-environment physical and symlink-alias roots, an inherited valid logical
`PWD` alias of `/` that must become `OLDPWD`, relative script invocation from
the fixture root's parent with `PWD` omitted, relative invocation through the
project's symlink alias with inherited logical `PWD`, and relative invocation
through nonempty `CDPATH` from the fixture root's parent. Bash's reference emits
the selected logical directory before the probe output in that case. The
runtime now keeps normalized `Script::source_path()` separate from the original
`Script::invocation_path()` spelling, with interpreter and bytecode support; the
candidate derives its root from that spelling using a private shell-style
`dirname` operation rather than general `Fs::parent`, checks colon-separated
`CDPATH` entries for relative roots, and emits the selected directory line.
Pure source fixtures pin empty, slash-free, trailing-slash, repeated-slash, root,
unnormalized `..`, and command-substitution trailing-newline behavior; they are
authored but uncompiled/unrun.
Additional observations cover a missing first `CDPATH` entry followed by the
valid caller directory, an empty first entry that must select the caller
directory without printing, and a relative `.` entry. An existing `CDPATH`
directory without the project is also searched before Bash falls back to the
ordinary relative operand, without printing a selected-directory line. A
symlinked `CDPATH` entry verifies that Bash's logical `PWD` retains the alias
spelling while resolving to the physical project root. An absolute-source-path
control supplies nonempty `CDPATH` and expects no extra line, because Bash only
consults `CDPATH` for a relative `cd` operand. These implementations and
observations are source-authored and unrun; other relative `CDPATH` entries,
alternate no-match conditions, additional symlinked `CDPATH` shapes, `//`,
path-race and complex `..` semantics remain open. One isolated case expands a
`~//...` `CDPATH` entry from an explicit `HOME` value before resolving the
relative wrapper root, preserving the repeated suffix separator. Two more cases
expand `~+` and `~-` from explicit PWD and OLDPWD values. Three additional
cases exercise the current directory-stack slot through `~0`, `~+0`, and `~-0`.
One more omits HOME and guards against treating that state as an empty prefix
that selects the caller's directory. Another places a file first in CDPATH and
the valid caller directory second, checking that a failed `cd` candidate does
not stop the search. Account-home fallback when HOME is unset,
named-user, and nonzero indexed directory-stack tilde entries remain open in the
wrapper. The seven actual exec-failure cases follow, so the lint wave has forty-one
observations total.

Source review of Bash 3.2's `absolute_pathname` showed that only absolute `cd`
operands bypass `CDPATH`; relative operands beginning with `./` or `../` still
search it. The companion checks the raw spelling before normalization, and
the two native cases now expect CDPATH's selected-directory output before the
probe bytes when a nonempty entry matches. These cases are authored, not
observed. Account-home fallback when HOME is unset, named-user, and nonzero
indexed directory-stack forms in `CDPATH` remain open in the candidate.

Checksum-child, direct-probe, ordinary-wrapper and exec-failure admission now
share a private completed-status predicate requiring `Completed`, the exact
expected status, and empty `error_text`. Matching streams/status cannot admit
a contradictory host-error record. The ordinary gate still requires exact
binary probe stdout/stderr; the exec-failure gate still requires empty stdout,
nonempty stderr, separately checked failure fixtures and exact comparison with
the reference. This does not infer exec failure from a normal exit of 126/127.

Data-only assertion bodies in the launcher file cover accepted ordinary
statuses (including normal 126/127), wrong statuses, truncated/extra binary
streams, host-error text and all six non-completed outcome variants. Failure
assertions cover missing diagnostics, extra stdout and the same host/outcome
rejections. The full file also contains a gated native matrix and must not be
auto-run merely to execute these assertions. None has compiled or run.

Before switching a live caller, qualify the pinned local compiler, launcher,
probe, native ABI, ownership/reaping and external time/RSS containment under
explicit user authorization. Then observe every ordinary case through the
public launcher. Also resolve and exercise actual exec failures, signals and
descendants, cancellation, cwd/entry-path failures and wrapper-versus-exec process
identity. The companion returns a generic status 1 on a typed process error;
that must not be confused with a legacy child returning after exec failed.
No full shell equivalence or accepted migration is claimed.

The current Elisascript command-line driver lowers scripts to bytecode and runs
the bytecode engine. Ordinary calls resolve against the script's lowered module;
the internal `EsRuntime` POSIX bridge is not a script-visible bytecode operation.
An attempted direct `EsRuntime::elisascript_posix_execvp` call was therefore
removed from the candidate before qualification. The candidate remains on the
typed `run_process` operation, which can execute in the current engine but forks,
waits and returns an integer status rather than replacing the interpreter.

A script-facing, terminal `Process.Replace` capability must be added to the
source/IR/bytecode/interpreter contract before this wrapper can satisfy PID and
signal-termination parity. That operation must be guarded so embedded tests
cannot replace their runner. Exact shell lookup, ENOEXEC fallback, failed-exec
status/diagnostics and standalone qualification also remain open. No compiler,
reference, launcher, lint, or parity process ran under the standing validation
hold.

## Process replacement API prerequisite (source audit)

The canonical lint candidate stays on the typed process operation supported by
the current interpreter. It preserves the four fixed arguments and inherited
streams, but a probe terminated by SIGTERM is observed by the interpreter as a
child status rather than as the wrapper process's own signal termination. The
internal POSIX exec bridge cannot be called directly from ordinary Elisascript
bytecode, so no candidate-side workaround is accepted. A terminal process
replacement opcode and public typed surface are needed before continuing this
port's parity gate. This source audit did not run a compiler or process.

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

The prepared-spawn seam now retains a separate structured diagnostic receipt
after canonical no-child release. Setup codes, completed spawn failures and
aborted searches are distinct; the last errno of an aborted search cannot be
rendered as its failure cause. Ordinary tool exits 126/127 do not produce these
receipts. The model/default/session fixtures are unrun, and the seam remains
unwired to source/bytecode error payloads or this port. Copying a receipt into the
typed error value, rendering compatible diagnostics and observing all seven
failure cases through the public launcher remain required.

Cause snapshots now have a checked primitive-carrier encoder/decoder and a
private retired-session accessor; authored fixtures check that a copied value
survives session reuse. This does not publish a script error variant or change
catch behavior. Executable-context publication, typed frame publication
and diagnostic rendering are still open, and all new fixtures remain unrun.

The parent-held spawn owner also retains one-based first/last access-denied
attempt numbers, without allocating or borrowing candidate paths after a native
return. Later missing candidates, exhaustion or a successful launch do not erase
these observations. Admission, accounting, retirement and failure projection
reject inconsistent histories. Pure fixtures cover multiple denials and invalid
history without releasing a live child's capacity; they are uncompiled/unrun.
This is evidence for future diagnostic context, not a choice of which candidate
the shell reports. Intermediate denial indices are not retained, paths still
need host-checked invocation provenance, and the primitive cause payload is
unchanged.

An owned diagnostic snapshot now copies the original argv[0] spelling, last
attempted candidate and first/last denied candidates as byte arrays without
their terminal NULs. It validates storage shapes and byte receipts, cause/history
agreement, indices and complete-search counts before copying. Its four text
copies have an aggregate 16,380-byte limit checked before allocation; no
environment values, live PID or opaque handle are exported. Non-NUL bytes are
preserved without UTF-8 decoding, expansion or normalization. The private
session accessor first requires Ready/retired canonical ownership and reprojection
of the retained cause. Authored budget, malformed-input, early-fatal/interrupted,
byte-preservation and storage/session-reuse fixtures remain uncompiled/unrun.

These structural checks cannot prove that arbitrary supplied storage belongs to
the invocation: the exclusive private host coordinator must supply the same
unchanged prepared input before storage reuse. No default host dispatch,
default-source error variant, diagnostic-candidate selection or renderer is wired. The
16,380-byte copy limit is a payload bound, not an RSS guard or qualification of
allocation-failure/cancellation recovery. Lint failure parity remains open.

## Typed launch-error publication (dormant seam)

The private prepared-session adapter now accepts the enclosing run's runtime
value pool. After Ready/retired settlement, a retained launch receipt can replace
the invocation's generic Process failure with `ProcessError.LaunchFailure` using
the existing Raised/error-payload mechanism and matching operation identity.
The opt-in declaration is `src/runtime/process_errors.elisascript`, not a default
prelude. Its twelve ordered fields are stage, code, attempts, saw-denied,
requested bytes, last-attempted bytes, first-denied bytes, last-denied bytes,
first-denied attempt, last-denied attempt, candidate count and context byte count.
Scalar fields are i64 except the boolean; path fields are darray[u8].

The codec revalidates public snapshot metadata before checking the full append
span against runtime-pool/u32 bounds. It copies bytes into Int cells in the
caller-owned run-long pool and publishes Array carriers, not dangling Text views.
The complete local payload replaces stale handled-error payloads before the
raised identity is published. Panic, malformed metadata, active/quarantined
sessions and publication capacity failures cannot become recoverable launch
variants. Ordinary tool exits and reaped-child wait failures have no launch
receipt and do not enter this publication path. Same-invocation storage and
run-pool provenance remain exclusive host-caller obligations; allocation panic,
cancellation and resource-memory accounting are still unqualified.

Small codec and synthetic source-catch fixtures are authored but uncompiled/unrun.
A separate opt-in `test/fixtures/process_launch_error/publication.elisa` uses the
real Machine/guard helpers to model admission publication, typed extraction,
reuse, reentry rejection and quarantine. It includes the full IR facade: it is
not an execution authorization or a lightweight compiler qualification, and must
remain dormant pending explicit authorization and external RSS/time containment.
The public launcher, default interpreter/bytecode dispatch and lint port still
do not include the prepared-spawn seam. No diagnostic text or shell-equivalence
claim follows from this private publication step.

The paired payload decoder now validates exact arity and runtime kinds, signed
count/code bounds before narrowing, pool ranges, non-NUL u8 cells, aggregate
bytes and denial/search consistency before allocating owned byte copies. A
returned snapshot survives later payload/pool reuse and never contains a view
into that pool. It reuses cause validation, so an interrupted search still has
no native failure cause. Authored malformed-field/range/byte/identity and reuse
fixtures remain uncompiled/unrun. Decoding accepts structurally valid explicitly
raised data too; it is not evidence of host execution or native ownership.

## Diagnostic source investigation, not a qualified renderer

The Apple OSS Bash 3.2 source separates `exec` lookup/path expansion from
native failure handling. A command containing `/` bypasses PATH lookup; a
slashless lookup with no PATH candidate reports command-not-found and selects
status 127. PATH lookup prefers an executable non-directory even when an
earlier entry is an existing non-executable file, and remembers the first
existing entry as a fallback. It ultimately rejects that fallback if it is a
directory; a leading directory can therefore shadow a later non-executable
file when no executable candidate exists. After `execve` returns, the builtin
has a distinct non-executable diagnostic/status-126 branch; other failures use
`file_error`.
The error prefix can contain the script name and executing line. See Apple's
[exec builtin, lookup and failure branches](https://github.com/apple-oss-distributions/bash/blob/main/bash-3.2/builtins/exec.def#L863-L983),
[PATH candidate preference](https://github.com/apple-oss-distributions/bash/blob/main/bash-3.2/findcmd.c#L2108-L2197),
[command lookup](https://github.com/apple-oss-distributions/bash/blob/main/bash-3.2/findcmd.c#L1817-L1924),
and [error name/line prefix](https://github.com/apple-oss-distributions/bash/blob/main/bash-3.2/error.c#L1208-L1278).
These are mutable upstream links, not an immutable source/build provenance
chain for the local `/bin/bash` hash or an observed byte oracle.

`src/runtime/bash_exec_lookup_model.elisa` models candidate preference from
ordered filesystem observations, separately from native `execvp` retries. It
also models the non-AFS Bash 3.2 permission-bit check from a stat mode and an
explicit credential snapshot: effective UID, real/effective GIDs and
supplementary groups. This preserves Bash's owner, group, other, and root
execute-bit cases; Bash's `group_member` checks both real and effective GIDs
before its supplementary list ([Apple Bash 3.2 `general.c`](https://github.com/apple-oss-distributions/bash/blob/main/bash-3.2/general.c#L3577-L3724)).
This intentionally does not substitute `access(X_OK)` or claim ACL behavior.
Its bounded PATH planner preserves direct-name bypass, empty/interior component
behavior, and source-observed omission of a trailing empty component. Named
directories are retained as owned PATH byte spans and mark leading-tilde
components. The pure model resolves current-user `~`/`~/...` using an explicit
HOME snapshot, `~+`/`~-` using explicit PWD/OLDPWD snapshots, and indexed
`~N`/`~+N`/`~-N` using explicit pushed entries in `dirs -l` order after the
current directory. `join_search_candidate` then matches Bash's
`sh_makepath` joining after tilde expansion: an empty directory means `.`, a
separator is added only when needed, and existing slash spelling is preserved
without normalization ([Apple Bash 3.2 `makepath.c`](https://github.com/apple-oss-distributions/bash/blob/main/bash-3.2/lib/sh/makepath.c#L490-L613)).
Inputs over 64 KiB PATH or 4,096 components fail explicitly, so those bounds
are runtime policy, not a claim about unrestricted Bash behavior. The pure
model byte-concatenates `~` and `~/...` from an explicit HOME snapshot, and
`~+`/`~-` from explicit PWD/OLDPWD snapshots, preserving suffix separator
bytes. It supports `~N`, `~+N`, and `~-N` from a caller-supplied snapshot of
pushed entries in `dirs -l` order after the current directory; index zero and
the current slot from the right use the explicit PWD value. Bash 3.2 installs
numeric stack expansion when `PUSHD_AND_POPD` is enabled and delegates indexing
to its directory-stack implementation ([Apple Bash `general.c`](https://github.com/apple-oss-distributions/bash/blob/main/bash-3.2/general.c#L3306-L3343),
[Apple Bash `pushd.def`](https://github.com/apple-oss-distributions/bash/blob/main/bash-3.2/builtins/pushd.def#L2582-L2668)). The pure resolver accepts an explicit current-user
account-home snapshot as the fallback for bare `~`/`~/...` only when HOME is
absent; an explicitly empty HOME still wins. It also accepts a per-name lookup
snapshot: a supplied home expands, a confirmed miss preserves the original
tilde spelling, and a missing/unavailable snapshot fails closed. These are
model features of the explicit-snapshot observer.
Bash's `tilde_expand_word` copies the original spelling when `getpwnam` returns
no entry, and uses the account database for bare `~`/`~/...` only when HOME is
unset ([Apple Bash `tilde.c`](https://github.com/apple-oss-distributions/bash/blob/main/bash-3.2/lib/tilde/tilde.c)). The Darwin process-environment adapter now performs bounded lazy `getpwnam_r` lookup for a reached named user and `getpwuid_r` only when bare `~` needs the account-home fallback; a missing named user retains its original spelling. The returned passwd fields are copied only from their caller-owned result buffer. These native layouts/lookups remain uncompiled and unqualified. The explicit-snapshot observer still requires caller-provided account/name facts. Unavailable or out-of-range stack indexes fail explicitly. Pure fixtures cover selection, permission classification, invalid
directory-as-executable observations, PATH planning, tilde byte preservation
(including HOME fallback, PWD/OLDPWD, indexed stack, and named-user
snapshots), forged-plan rejection, and joining; they are uncompiled and unrun.
A renderer and local Bash source/build qualification remain open.

An opt-in Darwin adapter, `src/runtime/bash_exec_lookup_posix.elisa`, now
captures effective UID, real and effective GIDs, and the supplementary group
list, then converts one caller-supplied candidate pathname plus that snapshot
into the model's filesystem observation. A failed supplementary-group query
leaves that list empty, preserving Bash's fallback to real/effective GIDs;
counts above the 1,024-entry bound fail explicitly. The stat adapter follows
symlinks, maps every stat failure to absence, and treats directories as present
but non-executable, matching the inspected non-AFS Bash 3.2 `file_status` path.
`observe_search_plan` now validates the owned plan. Direct-name mode observes
the exact slash-containing command spelling once without applying PATH
candidate preference. A slashless command with an empty PATH is retained as an
unsearched literal name, matching Bash's early return without stat. PATH mode
validates the plan, joins and observes components in order, retaining exact
spellings, and stops after the first executable candidate just as Bash does.
The explicit-snapshot observer resolves current-user `~`/`~/...` from HOME or
account-home data, `~+`/`~-` from PWD/OLDPWD, and indexed/named-user forms from
caller snapshots. The process-environment observer lazily reads exported HOME,
PWD, and OLDPWD, and queries passwd only for a reached named user or missing
HOME fallback; indexed directory-stack forms still require caller state.
unsupported tilde forms are rejected only when reached, before their stat
query, so an earlier executable can end the search without needing that
expansion. `resolve_reached_path_directory_from_process_environment` resolves
one already-reached directory and reads only the exported process `HOME`,
`PWD`, or `OLDPWD` value its tilde form needs. Unused environment values cannot
block an earlier executable. `observe_search_plan_with_process_environment`
uses that resolver in the ordered candidate loop and still stops at the first
A checked `invocation_path_from_observation` projection now copies a selected
candidate into owned bytes, revalidates the selection against all observed
candidate facts, and leaves NotFound unavailable. Pure fixtures cover executable
selection, non-executable fallback, independent ownership, direct-name handoff,
and rejection of a forged selection index. This runtime-side handoff is not yet
used by the lint port: importing `src/runtime` by a checkout-relative path would
make the companion depend on this repository layout instead of a stable public
process API. The port still passes the configured name to `run_process`, whose
legacy `execvp` lookup can differ from Bash. The process-environment observer
does not capture shell-only variables or directory-stack state; the explicit-
snapshot observer requires those shell facts from its caller. Both require
concurrent environment mutation to be excluded during each lookup.
If all reached components are supported and none is executable, it applies the
selector after exhausting PATH. The adapter has not been compiled or exercised;
the caller must keep credential and shell-directory snapshots stable during
capture.

`test/runtime/bash_exec_lookup_posix_test.elisa` now authors a narrow adapter
check that individual process-environment snapshots copy the same exported
values as the environment adapter, plus reached-directory tilde resolution
from those values and early termination before an unreached tilde suffix, plus
a search with no `bash` candidate in its
private first PATH directory and `/bin` second, and unvisited `/usr/bin` and
tilde-expansion suffixes. It verifies retained candidate spellings and
selection using stat/credential observations only; separate cases cover
refusal of reached unsupported tilde forms and snapshot-based tilde expansion
before joining. Pure invocation-path fixtures also pin executable selection,
non-executable fallback, copied-path ownership, direct-name behavior, and
malformed selection rejection. No case launches Bash or the selected
executable. The tests are uncompiled and unrun, so source integration does not
qualify this adapter or the lint wrapper.

Consequently, retained access-denied attempt numbers alone do not identify a
shell-selected pathname or distinguish a directory from a nonexecutable file.
Before implementing exact lint diagnostics, qualify the pinned shell's source,
patch/build profile and observations, then supply appropriate filesystem facts,
physical-cwd/full-path behavior and wrapper/line context. Do not substitute a
hardcoded errno message or silently change the matrix's authored status
expectations based on an unmatched source checkout. The seven failure plans
retain exact reference/candidate comparison, without normalization, and remain
unrun. Execution authorization and external RSS/time containment are still required.

## Bounded failure evidence from the dormant matrix

Actual-exec failures now report the case and failed phase: fixture admission,
reference run/contract, candidate run/contract, post-run fixture checks or exact
comparison. A failed reference contract still prevents candidate execution.
Available run receipts print outcome, expected status and actual status only for
Completed outcomes; other statuses are explicitly unavailable. stdout, stderr
and error-text evidence uses retained byte counts, lowercase hex of at most the
first and last 64 bytes each, and explicit per-window truncation flags. A tail
keeps the useful message visible after a long path prefix. Windows may overlap;
a window-truncated flag means each window alone omits bytes. A thrown runner error
is reported as no receipt, not synthesized into a DifferentialRun observation.

The small reusable preview model never decodes/normalizes text, and only scans
the admitted windows. Its binary/control-byte, zero-budget and 63/64/65-byte
fixtures are authored but uncompiled/unrun. Logs contain no raw observed stream
bytes that could control a terminal; case/phase labels are fixed fixture data.
Hex is reversible and does not redact secrets: this harness uses controlled,
authorized fixture streams, and this preview must not be treated as a general
redaction policy. Counts describe retained input spans, not proof of complete
capture when a runner outcome indicates failure or output exhaustion.

The preview model's source hash is also checked with the matrix's other pinned
inputs, before and after the suite. Log headers and individual stream lines carry
case/phase labels so interleaving does not silently relabel their evidence.
These log previews are diagnostic aids, not artifacts, hashes, source provenance
or equality oracles. They neither weaken the seven authored status expectations
nor replace full exact comparison. A difference beyond the prefix can still fail
comparison even when both windows look identical. Cleanup and all existing
authorization/identity/containment prerequisites remain unchanged; no matrix,
console diagnostic, fixture setup or native operation was executed by this work.

Ordinary probe cases and the initial literal probe-golden check now use the same
bounded evidence path. Ordinary labels contain the pinned reference filename
and matrix index, distinguishing otherwise similar unset/empty selections.
When the reference or direct probe fails its independent admission, expected
stdout/stderr frame previews are labeled separately from observed streams.
Runner errors have no fabricated receipt; candidate failures retain the admitted
reference alongside candidate evidence. The reference still runs first, must
match the independent status and full probe byte frame, and prevents candidate
execution if it fails. Both ordinary observations and full comparison must pass;
normally returned 126/127 still do not replace actual-exec failure coverage.
At that evidence-formatting step the literal golden bytes, original eight-case
model, wider-wave selection, limits, pins and execution order were unchanged.
That extension was source-only and unrun.

## Literal executable-name cases (source-only)

Three additional ordinary lint cases set RUFF_BIN to relative, absolute and PATH
spellings of the same probe filename containing `$HOME`, a semicolon, a quoted
glob, double quotes and a backslash. These characters belong to the filename:
they must not trigger shell expansion, token splitting, globbing or reparsing.
The earlier shell-shaped *ignored wrapper arguments* did not exercise this
contract. Each new reference/candidate still receives the fixed four Ruff
arguments, and must independently match the full binary observation frame and
its normal exit status (31, 32 or 33), before exact pair comparison.

The temporary root owns one extra pinned executable probe copy. The existing
scope provides that alias to both waves, requires no Python-shaped fixture tree
for lint, and registers it for existing nonrecursive cleanup. The case count is
now eleven for lint, seventeen for the explicit wider wave. All seven actual
exec failures remain mandatory: these successful launches are not substitutes
for missing/denied exec diagnostics. Both the case model and the fixture-scope
source are SHA-256 checked before and after the suite. These checks are not
atomic protection against external source or file mutation.

Pure fixtures pin the added selections, statuses, empty ignored argv and exact
literal alias. They and the expanded matrix are authored only, uncompiled/unrun.
No source/native probe, public launcher, script or compiler was executed. This
does not qualify native path-byte handling or establish shell equivalence, and
no original script/caller was changed.

## Exact checksum records for literal filenames (source-only correction)

The checksum admission helper previously compared stdout with a raw
`digest + two spaces + pathname + LF` record. Local `/usr/bin/shasum` 6.02's
installed source escapes backslashes and LF in filenames and prefixes the
entire record with a backslash when either occurs. Thus the literal probe alias
above would have failed fixture setup, before exercising wrapper behavior.
The source's output loop and mode selection were inspected without running
the matrix or checksum tool against any fixture.

The helper now requests explicit text mode and separates options from the
literal target with `--`. A small public `EsChecksumRecord` pure model compares
the complete observed record against that exact format without allocating,
decoding UTF-8, unescaping arbitrary input or accepting a digest-prefix match.
It validates a lowercase 64-byte digest and nonempty/non-NUL filename of at
most 4096 bytes before inspecting observed bytes. The worst escaped record is
8260 bytes. Full length, escape marker/order, digest, two spaces, exact filename
bytes and final LF must all match. Other bytes, including CR and non-UTF-8,
are unchanged. Binary-mode markers, trailing records and wrong filenames fail.

Pure fixtures cover plain/escaped records, invalid inputs, binary/CR byte
preservation and maximum expansion; all are authored, uncompiled/unrun. The
model source is also pinned before and after the suite. This fixes checksum
record interpretation, not checksum computation or tool provenance: the host
tool, Perl runtime/dependencies and filesystem/process ABI still need explicit
qualification. No formatting match proves digest correctness, atomic file
identity, source execution or parity. Original scripts and callers remain
unchanged; validation and native/process execution remain disabled.

The same checksum-record bug also affected both dormant Skia environment-query
harnesses. Their native/public-launcher pin and copied-fixture checks now reuse
the bounded exact matcher with explicit text mode and `--`, preflight filename
bounds/non-NUL bytes and reject the special stdin name `-`. The matcher source
is included in each existing before/after pin set. An additional pure gate
fixture admits unchanged literal-backslash launcher/Python paths while retaining
newline/CR/NUL rejection; path admission does not prove those artifacts exist.
Existing compiler/source/artifact pins and all explicit qualification gates
are unchanged, including intentionally stale engine pins that still need
fresh qualification. No Skia compiler, native or launcher test ran, and no
script was accepted or live caller switched. This infrastructure repair does
not advance the smallest-first acceptance order.

## Environment-query raw-byte coverage (source-only)

Both dormant Skia query matrices already select Python's isolated `-I -S -B
-X utf8` profile and a replaced fixture environment. They now require seventeen
ordinary cases, adding an undecodable value (invalid UTF-8 lead/continuation
and surrogate-sequence bytes), an undecodable key with an undecodable value,
and an exact key containing LF/tab. None contains NUL or `=` in its key.
Independent literal expectations retain the raw bytes and append exactly one
LF; they are not constructed by the candidate's lookup/renderer.

Python documents Unix environment decoding with surrogateescape and UTF-8
mode's matching stdout encoding/error handling, which supports these round-trip
expectations for the existing profile. See the official
[environment and UTF-8 mode contract](https://docs.python.org/3/library/os.html#python-utf-8-mode).
This is a source-based expectation, not proof of our pinned reference executable
or an arbitrary locale/PYTHONIOENCODING profile. The reference must still match
the independent full stdout/status/empty-stderr oracle before any candidate
runs; a reference mismatch closes the case rather than changing its expectation.

Both matrices now reject a missing/subset ordinary case list through an explicit
seventeen-case guard and pin the updated oracle source before/after execution.
Pure fixtures check the raw bytes, literal names, exact LF and unchanged original
cases. All remain authored only, uncompiled/unrun. Candidate sources, existing
qualification gates and earlier source/artifact pins were not relaxed. No
compiler, Python, native adapter or launcher ran; lint remains the first
acceptance target and originals/callers remain unchanged.

## Cleanup parent observations (source-only correction)

The canonical wrapper harness previously removed recorded file paths without
rechecking their directory parents. Replacing a fixture parent with a symlink
could redirect that cleanup. It now checks that the owned temporary root and
all recorded directory parents remain non-symlink directories before each file
removal. The reverse directory loop checks only the remaining prefix of its
parent-first ledger, then checks the root again before removing it. Missing,
symlinked or non-directory parents stop cleanup and report failure, leaving the
unresolved root for inspection rather than guessing a new deletion target.

A path registered before a failed copy may legitimately be absent. Cleanup
now skips that absent file, while checking final symlinks explicitly so a
dangling link does not masquerade as absence. File unlink failures and unknown
extra files/nonempty directories still fail cleanup. No recursive deletion,
source-script deletion or broad temporary-directory sweep was introduced.

This is an observation fence, not atomic identity protection: same-kind parent
replacement and mutation between checks remain possible. Descriptor-relative
cleanup, exclusive directory ownership/mutation exclusion and native semantics
still require qualification. Future isolated tests must cover unchanged roots,
failed-copy/absent-file cleanup, dangling final links, nested reverse retirement,
replaced-parent symlinks, missing parents and unexpected retained files. No
cleanup fixture, directory operation, compiler, process or parity test ran;
only source inspection and git diff checks were performed. Originals, callers,
SSH and other agents' work remain unchanged.

## Prebuilt role admission (source-only hardening)

The dormant first-wrapper gate now also requires explicit declarations
`ELISASCRIPT_CANONICAL_LAUNCHER_QUALIFIED=1` and
`ELISASCRIPT_PROCESS_PROBE_QUALIFIED=1`, in addition to explicit execution
reauthorization and the bounded-guard marker. The pure
`canonical_wrapper_gate.elisa` model binds the exact local/core compiler path,
validates lowercase SHA-256 identities and bounded absolute launcher/probe
paths, and rejects compiler-versus-role and launcher-versus-probe path or digest
aliases before file/hash/probe launches. Literal metacharacters/backslashes are
retained; root-only, relative, NUL/LF/CR and oversized identity paths fail.

Before launching any checksum process, the authorized harness checks all three
prebuilt artifacts (compiler, launcher, probe) as non-symlink executable regular
files within the existing byte bound. It reads/closes a four-byte header and
requires recognized native container magic. This rejects obvious text/shell
wrappers that might otherwise auto-build, but does not prove that an arbitrary
native artifact cannot invoke a compiler. The gate model's source is pinned
before and after the suite. Tiny pure fixtures cover missing declarations,
aliases, malformed identity data and basic native/script header recognition;
they and the file preflight remain uncompiled/unrun.

Declarations, matching hashes and container magic are not execution authority,
build provenance, compiler freshness, a functioning guard or native/dependency
qualification. An operator still needs the explicitly authorized qualification
record binding artifacts, source/options/dependency closure, local compiler,
no-auto-build launcher behavior and external process-tree time/RSS containment.
Path spelling/digest checks are observational, not inode-sealed admission or
atomic protection against mutation. No artifact, compiler, header preflight,
probe, test or parity run occurred, and no caller/original was changed.

Finish this contract first; then take the nine-line Skia environment query,
followed by the fourteen-line UI codec gate. Larger wrappers, generators and
build drivers remain later work. Compiler, native and parity execution remains
paused; SSH and other agents' processes are outside this work.
