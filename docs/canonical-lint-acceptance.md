# First replacement: canonical lint

Start with the six-line shell wrapper captured in
`test/fixtures/script_parity/canonical_lint/reference.sh`, and its companion
`ports/neural-computer-agentV2/scripts/lint_canonical.elisascript`.
Neither is an accepted replacement yet. Keep originals and callers unchanged.

## Smallest source-only check

`test/script_parity/canonical_lint_cases.elisa` owns the eleven ordinary
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

The gate additionally requires seven actual exec-failure plans from
`canonical_lint_exec_failure_cases.elisa`: missing and denied targets each use
relative, absolute and PATH names, followed by an absolute directory target.
The denied target is a pinned probe copy with mode 0600, not an executable probe
alias. Missing-name absence, denied-file mode/type/nonexecutability, directory
type and absence of unintended PATH matches are checked before and after each
run. The copy belongs to the temporary root's existing cleanup ledger. These
checks are observations, not atomic protection against external mutation.

Each reference must complete with the independently specified 126/127 status,
empty stdout and nonempty stderr before the candidate may run. Exact stderr
bytes then come from the pinned reference and must match without normalization;
there is no separate literal diagnostic-byte oracle. The seven plans have small
pure path/status fixtures; neither fixtures nor matrix have been compiled/run.
Both available waves include these lint failure checks. Current missing exec
diagnostics are an expected open gap, not a reason to skip these cases.

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

Apple's published Bash sources separate `exec` lookup/path expansion from native
failure handling. The exec builtin uses command lookup and full-path conversion;
the lookup implementation uses filesystem status and an executable-preferred
fallback. Native failure handling has a distinct directory branch, while error
prefixes include script and executing-line context. See Apple's
[exec builtin](https://github.com/apple-oss-distributions/bash/blob/main/bash-3.2/builtins/exec.def),
[command lookup](https://github.com/apple-oss-distributions/bash/blob/main/bash-3.2/findcmd.c),
[execution](https://github.com/apple-oss-distributions/bash/blob/main/bash-3.2/execute_cmd.c)
and [error prefix](https://github.com/apple-oss-distributions/bash/blob/main/bash-3.2/error.c)
sources. These links are mutable source references, not an immutable source/build
provenance chain for our pinned `/bin/bash` hash or an observed byte oracle.

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

Finish this contract first; then take the nine-line Skia environment query,
followed by the fourteen-line UI codec gate. Larger wrappers, generators and
build drivers remain later work. Compiler, native and parity execution remains
paused; SSH and other agents' processes are outside this work.
