# Elisascript implementation plan: stable replacement for Python, Perl, shell, and AWK

Prepared: 2026-09-05. Baseline inspected: commit `530555f` (the current implementation tip) plus the repository layout and source history. This is a local planning document, ignored by the repository-level `.gitignore` (and the existing local `.git/info/exclude` rule). It is not a claim that the implementation described below exists or has passed validation.

Latest static increment (`d6ceca3`): registry-backed fallible builtin lowering now
records each row's declared effect/error metadata through one shared helper before
emitting the operation. `parse_int`/`parse_float` and checked text indexing retain
their `ParseError`/`IndexOutOfBounds` contracts without operation-specific metadata
pushes; lowering fixtures and the compiler-free registry audit pin the propagation
path. The registry still stores one compact family per row, so structured multi-row
effect/error IDs and compiler/runtime evidence remain open.

Follow-up static increment (`1cd1cfa`): the helper is now invoked at the common
unshadowed global-call boundary, so every future registry row inherits contract
recording automatically; receiver methods retain their receiver-specific gate.
This closes the remaining dispatch-path drift risk while compiler and runtime
validation stay suspended.

Receiver follow-up (`1138aea`): firm `Text` and `Regex` receiver dispatch now
classifies both named bindings and literal receivers before recording the same
registry contract. Unknown receivers remain conservative and source-shadowing
continues to win; execution evidence and recursive receiver inference remain open.

Latest static increment (`b75a56a`, test coverage `bd0ff62`, ledger follow-ups
`c8aadfe` and `530555f`): canonical IR serialization now checks every nested
collection count that is encoded as u32 before emitting bytes or fingerprints,
and the ESBC writer/reader test slice covers invalid metadata sentinels and the
64 KiB whole-envelope ceiling; compiler/runtime validation remains suspended.

Latest static increment (`f24b1f3`): differential owned-map comparisons now use
one checked-subtraction range predicate, and runtime/owned malformed-map
fixtures cover out-of-bounds and maximum-offset spans; map snapshot execution
and broader artifact schemas remain open.

Latest static increment: the compiler-free namespace audit now verifies that
every POSIX `@link_name`/`extern` declaration is private to an `EsRuntime`
extension and rejects higher-level calls to `_impl` ABI symbols; the runtime
bridge remains statically qualified while compiler/build and non-POSIX adapter
evidence remain open.

Latest static increment (`a8969f1`, recorded in `10ab15a`, parser-context slice `6fa8fd9`, effect closure `36d73f1`, follow-up to `aa63e90`): the phase-aware source diagnostic record now
copies the first parser `Ast::ParseErrorKind` or severity-1 semantic
`Semantic::DiagnosticKind` together with bounded line/column/end-column
coordinates before the parser arena is released, plus a deterministic payload
hash for differential correlation. The follow-up source/driver slice now copies
diagnostic context/name/type/detail fields and numeric expected/actual counts through a 4 KiB-per-field permanent
bound and renders parser context plus semantic spans without borrowed parser
views; compiler/runtime validation remains suspended.

Latest static increment (`277ce56`): parser and semantic source failures now
retain a bounded source-line excerpt with a caret before the parser arena is
released. The excerpt line and caret each cap at 1024 bytes; clipped or
multi-line spans set the existing truncation flag while numeric coordinates stay
authoritative. The runner carries the owned excerpt and the launcher renders it
on a separate line, with a regression fixture and semantics documentation;
compiler/runtime validation remains suspended.

Latest static increment (`621def7`): the phase-aware runner now exposes a
versioned diagnostic snapshot fingerprint over every host-visible field,
including phase/detail, typed error variants, coordinates, bounded payload
text/counts, lowerer/verifier identifiers, and truncation state. The typed
record remains authoritative and the fingerprint is only a compact equality key;
the regression fixture proves that phase and span changes produce distinct
fingerprints. Compiler/runtime validation remains suspended.

Latest static increment (`1e92a3e`): diagnostic fixtures now use structural
snapshot equality in addition to the compact fingerprint, comparing every
host-visible enum, coordinate, bounded payload field, count, and truncation bit.
This prevents a hash collision from being treated as an exact golden match;
compiler/runtime validation remains suspended.

Latest static increment (`cf379e8`): `scripts/check_diagnostic_snapshot.sh`
extracts every public diagnostic record field and fails if a future field is
omitted from either the fingerprint or structural equality operation. The
compiler-free audit covers 37 fields and intentionally excludes only the
execution result, which is not part of the diagnostic snapshot contract;
compiler/runtime validation remains suspended.

Latest static increment (`c7b167a`): runner fixtures now distinguish source,
entrypoint, bytecode, lowering, and runtime diagnostic records through both
structural equality and fingerprints. These are exact field-level fixtures,
not execution evidence; compiler/runtime validation remains suspended.

Latest static increment (`a2527cf`): interpreter and direct-bytecode fixtures
now exercise the Path line helpers with both an empty path and an embedded-NUL
path, recover through the declared `error[FileIoError]` boundary, and require
both engines to return the same successful recovery value. This closes the
static fixture portion of the Path line/append admission audit; execution and
host-specific filesystem evidence remain open.

Latest static increment (`ad22114`, compiler-free builtin audit):
`scripts/check_builtin_surface.sh` now extracts every global lowerer dispatch
spelling and verifies that it is present in the semantic seed row or its
`add_symbol` extensions. The audit intentionally excludes receiver methods and
does not pretend the duplicated authorities share signatures. The audit exposed
six canonical regex helpers that were lowered but not seeded; the semantic seed
row now admits them. The single typed builtin registry and generated
consistency check remain Q03 work.

Latest static increment (`023dff7`): the diagnostic excerpt regression fixture
now uses a parser failure with token-backed coordinates, avoiding semantic
diagnostics whose legacy constructors intentionally have no `Ast::Pos`; the
test still checks the owned source excerpt/caret path without compiler
execution.

Latest static increment (`bd2161f`): source-loading diagnostics now retain the
first lowering `LowerIssueKind` and source line in a region-independent summary.
The launcher renders exact lowerer variants while keeping function/message
views inside the parser arena; the compiler-free namespace audit also checks
that every lowerer variant has a renderer branch. Compiler/runtime validation
remains suspended.

Latest static increment (`34611a1`): early source-slot filename rejection now
retains a typed source-phase detail (`source path exceeds filename limit`) while
keeping the 4 KiB raw scan bound. The launcher no longer turns this specific
admission failure into a generic host C-string usage error; compiler/runtime
validation remains suspended.

Latest static increment (`dcc8049`): the native launcher's raw `argv` scan
now applies the 4 KiB filename ceiling specifically to the source slot before
the general C-string/aggregate argument walk. Overlong borrowed paths therefore
fail without a large host-memory scan; compiler/runtime validation remains
suspended.

Latest static increment (`de82262`): the namespace/assembly audit now checks
that every public verifier `IssueKind` has an exact spelling branch in the
native bytecode-diagnostic renderer. Adding a verifier variant without a
launcher diagnostic branch therefore fails the compiler-free audit;
compiler/runtime validation remains suspended.

Latest static increment (`8297597`): the compiler-free namespace audit now
resolves each literal `.elisa` include relative to its declaring file and
fails closed on missing module fragments. The manifest therefore checks both
qualified public/private namespace ownership and source assembly integrity;
compiler validation remains suspended.

Latest static increment (`806c352`): phase-aware launcher diagnostics now
retain the first bytecode verifier `IssueKind` and numeric block, value, and
trace identifiers before the lowered-module region is released. The native
driver renders the exact verifier kind alongside the already typed source,
entrypoint, and runtime variants; compiler/runtime validation remains
suspended.

Latest static increment (`f21c6a5`): the native launcher now rejects source
paths at the shared host C-string ceiling and the stricter 4 KiB filename
ceiling before allocating a terminated copy. Overlong borrowed paths are not
echoed into the diagnostic, preventing an unbounded source view from entering
the error channel; compiler/runtime validation remains suspended.

## 1. Outcome and completion contract

Latest static increment (`3586c64`): the namespace manifest audit now includes
all `extend EsIr:`/`extend EsRuntime:` files, rejects extension blocks aimed at
undeclared modules, and counts their public/private sections in the emitted
manifest. The source-of-truth check now covers the actual qualified namespace
surface rather than only root module declarations; compiler validation remains
suspended.

Latest static increment (`00f92b2`): the derived raw `argc` ceiling now lives
in the public `EsIr` launcher contract and the native driver consumes it
directly. The typed parser, host collector, and ABI shim therefore share one
source of truth for executable-plus-source-plus-script-argument admission;
compiler/runtime validation remains suspended.

Latest static increment (`d396f47`): launcher stderr diagnostics now retry
interrupted `write(2)` calls through a bounded `EINTR` budget, reset that budget
after positive progress, and stop on zero, over-counted, or exhausted writes.
The driver therefore cannot claim a complete diagnostic after an incomplete
host write, while its public error-channel behavior remains unchanged. No
compiler or runtime validation was launched.

Latest static increment (`91bba99`): the vendored whole-file convenience API
now retries positive short `fread`/`fwrite` progress from the advanced offset
and fails on zero or impossible over-counts. This keeps fixture/tooling writes
and reads consistent with the Elisascript interpreter, source loader, and
differential runner; no compiler or runtime validation was launched.

Latest static increment (`6c9595a`): the native driver now
renders the exact retained source, entrypoint, and runtime error variant in its
phase diagnostic instead of replacing every typed failure with one generic
sentence. Bytecode verification still deliberately reports its aggregate phase
until structured issue payloads are propagated. This improves CLI and
differential reproducibility without changing the underlying `error[...]`
signatures; no compiler or runtime validation was launched.

Latest static increment (`8c5ff29`): exact-size source-file, interpreter, and
differential temporary-stream reads now use bounded progress loops. Positive
short `fread` results advance the destination offset and retry; zero progress
or an impossible over-count fails closed, so a truncation or race cannot
publish a partial source/value snapshot or spin forever. This aligns read
ownership with the existing short-write helpers and remains static evidence
only while compiler/runtime validation is suspended.

Latest static increment (`f4d25bf`): the public `parse_elisascript_cli`
state machine now enforces the same launcher-wide script-argument count and
aggregate-byte ceilings as the native collector and execution runner, before
allocating the returned request. Count and byte-budget violations have
distinct typed `ElisascriptCliError` variants (`TooManyArguments` and
`ArgumentsTooLarge`), closing the library-caller bypass in which a direct
parser caller could otherwise hand an oversized vector to later stages. This
is source/documentation evidence only; compiler and runtime validation remain
suspended by the explicit host-safety gate.

Latest static increment: bounded validation wrappers now serialize lowering and
test workers through a PID-and-start-identity lease, fail closed on unverifiable
live owners, and reclaim only leases whose owner PID is no longer live. This
prevents concurrent validation workers from competing for memory; the lease and
watchdog remain unexecuted because compiler validation is suspended.

The validation wrappers now persist an emergency-stop latch whenever RSS,
timeout, or diagnostic-log limits fire. `scripts/stop_bounded_validation.sh`
verifies the lease owner's live identity before terminating only that wrapper's
process tree, and future wrapper launches fail closed until the latch is
manually reviewed and removed. This containment path is statically reviewed;
no compiler process was launched to exercise it. The latch is an atomically
created directory, rejects file/symlink substitution, and records its reason
only with a no-clobber write.

The interpreter's process argv and environment budgets now include every
trailing NUL byte required by the POSIX C-string adapter, with subtraction-safe
admission before per-field allocation. This aligns the reference interpreter's
process boundary with the differential runner's terminated-payload contract;
execution remains suspended.

The native launcher now exposes shared public argument and host-string limits,
rejects raw `argc` values outside the executable-plus-script range before
walking host argv storage, and checks the source path against the shared
64 MiB C-string ceiling before adding its terminator. This is static evidence
only; compiler validation remains disabled. Each raw host argument is now
converted through a bounded C-string scan under the same ceiling, so an
unterminated or overlong `argv` slot fails before it becomes a borrowed view.
The driver also admits script-argument text against the aggregate 64 MiB
budget while scanning, so large vectors fail before typed staging rather than
after an avoidable pass over every slot.

The interpreter now applies that same bounded scanner to C strings returned by
`realpath`, `getenv`, `getcwd`, and numeric formatting before copying or
iterating them. Overlong or unterminated host results fail through the relevant
typed operation boundary instead of reaching an unbounded `strlen` walk.

The remaining direct integer/float formatter entry points now use the same
scanner instead of `sview(..., -1)` or raw `string_len`, keeping numeric text
conversion consistent with filesystem, environment, and process adapters.

The interpreter and differential process adapters now guard negative-PID
termination behind a successful parent-side `setpgid(child, child)` result.
When group setup fails, cleanup signals and reaps only the direct child, so a
failure in process-group creation cannot target an unrelated process group.
This is a static safety increment; process execution remains suspended.

Differential in-process file/program adapters now reject source targets at the
shared 4 KiB filename ceiling before allocating terminated path buffers. This
keeps the differential boundary aligned with the canonical source-file loader;
it is static evidence only and does not authorize compiler or runtime execution.

Both execution engines now cap allocating ASCII case conversion, text
concatenation, and text joining at 64 MiB before allocation, returning the
typed output-limit failure consistently. This closes a direct-bytecode versus
reference-interpreter resource-policy gap; runtime validation remains disabled.

Filesystem writes and differential stdin staging now retry short `fwrite`
progress from the advanced byte offset, treating zero progress or a close
failure as the typed I/O error. The exact bounded payload must be completely
written before success is published, so regular-file copies and temporary
process streams cannot silently truncate data; this is static evidence only.

Migration discovery now includes a separate compiler-free signal scanner for
executable permission bits, legacy interpreter shebangs (including `/usr/bin/env`
forms), and inline Python/Perl/AWK command references. It produces review leads,
not migration decisions; ownership and per-file acceptance evidence remain open.
Its default traversal skips dependency/cache trees (`.git`, `node_modules`,
virtualenvs, `__pycache__`, `vendor`, and `third_party`) to avoid an unbounded
whole-drive scan; the candidate manifest remains the broader extension census.
The scanner now fails closed above 200,000 regular files and skips content files
larger than 8 MiB, so broad discovery must be partitioned into bounded roots.
The extension/name candidate manifest applies the same 200,000-file admission
limit and stages mutually exclusive patterns in a private temporary path list,
then reads that list through an explicit bounded state machine without a global
de-duplication buffer that could otherwise retain an unbounded path set.
This also removes the shell pipeline EOF hang observed in the narrow scanner
probe; no broad inventory run is authorized or required.

The POSIX boundary now exposes a namespaced errno accessor and shared `EINTR`
constant. Stdin reads and non-blocking child polls retry interrupted calls only
through bounded state-machine budgets, reset after progress, and preserve their
typed console/process failures after exhaustion; no runtime validation was run.
The same bounded policy covers the one-millisecond process-poll sleep, so an
interrupted delay cannot be silently ignored or turn into an unbounded retry.
Stdin chunk admission now checks the remaining input budget before appending,
so a 4 KiB descriptor read or one-byte line read cannot temporarily allocate
past the 64 MiB ceiling.

The same stream state machines now reject impossible host-returned byte counts:
reads larger than their requested descriptor span and writes larger than the
remaining owned buffer fail closed before narrowing or advancing offsets. This
protects both normal filesystem/console writes and differential stdin staging
from malformed FFI progress reports; no compiler or runtime validation was run.

The native launcher diagnostic path now retries short `write(2)` progress and
stops on zero, negative, or over-counted host returns, so an error report cannot
silently truncate or advance beyond its borrowed message view.

The POSIX symlink reader now retries interrupted `readlink` calls through the
same bounded `EINTR` budget used by stdin and process polling, resetting after
progress and failing as `FileIo` after exhaustion.

Directory enumeration now uses the platform-neutral errno accessor and retries
interrupted `readdir` calls through the same bounded budget, preventing an
ordinary signal from publishing a partial directory snapshot.

Process failure cleanup now retries both kill and blocking reap operations when
they return `EINTR`, in both the interpreter and differential runner, before
giving up and preserving the typed process failure.

Parent-side private-process-group admission now retries `setpgid` on `EINTR`
before falling back to direct-child cleanup on any other failure.

Child descriptor redirection now retries `dup2` on `EINTR` for interpreter and
differential launches; non-interrupted failures still terminate the child with
the typed process-setup status.

Child-side process-group setup now follows the same bounded retry policy and
fails before `execvp` if the private group cannot be established.

Dynamic handler coverage now has one whole-family-mask predicate in both the
verifier and interpreter: an empty clause set masks every non-empty operation
in a declared family, while non-empty clause sets remain exact-operation only.

The language-level sleep builtin now shares the bounded `usleep` retry helper
with process polling, so interrupted one-second, millisecond, and fractional
chunks preserve their requested duration or fail as `TimeError` after budget
exhaustion.

Environment aggregate accounting also includes the `=` separator materialized
by `setenv`, while malformed non-text entries are skipped by the resource probe
so their normal typed diagnostic remains authoritative.

The differential process adapter now applies the same separator accounting to
environment entries, keeping its independent C-string budget congruent with
the interpreter before a child is forked.

The same wrappers now poll a separate 64 MiB temporary-diagnostic ceiling and
terminate the owned worker tree when compiler output exceeds it. The limit is
configurable only through a positive decimal `ELISASCRIPT_LOG_LIMIT_BYTES`
override and remains a polling containment aid, not an instantaneous disk quota.

Tree termination now snapshots the complete owned PID set before signaling the
root, then applies the forced second signal to that same set. This closes the
reparenting race in which a child could disappear from a fresh descendant scan
after the root exited. The watchdog remains unexecuted.

Lease metadata and temporary compiler logs are now created under `umask 077`,
so the shared temporary directory cannot expose or casually rewrite ownership
records. Compiler validation is still disabled.

Earlier static increment: differential process adapters now check aggregate
terminated C-string payloads and staged stdin against independent 64 MiB
budgets before allocation, temporary-file writes, or fork. Runner validation
uses a dedicated process-bounds state and the low-level invocation repeats the
checks. Output capture limits above the same 64 MiB hard ceiling are rejected
before fork as well. Execution remains suspended; this is not runtime evidence.

Earlier static increment: literal `TextReplace` now checks each append against a
64 MiB output limit in the reference interpreter and direct bytecode path.
Empty appends at the exact limit remain valid; limit failures do not publish a
partial result. Helpers remain private to their owning modules. Execution is
still suspended. Required validation includes empty input/needle/replacement,
exact-limit output, one-byte overflow, repeated expansion, and backend error
parity. The regex matcher now has explicit group/repetition stack guards and
helper-scan accounting, but still needs an iterative control-flow rewrite for
stronger host-stack guarantees; its state counter alone does not establish
runtime safety.

Regex follow-up: exact-limit empty expansions are accepted and capture probes
stop immediately on exhaustion (`315ffd2`). Replacement delimiter scans,
named-capture comparisons, and matcher helper scans now charge the shared
operation budget. Still open: iterative host-stack elimination, configurable
run-wide accounting, and executed boundary/adversarial fixtures. No regex
completion gate is closed by these static changes.

Regression source added in `test/ir/elisascript_bytecode_test.elisa`:
`regex_pattern_limit_is_identical_in_reference_and_direct_execution` covers
five regex opcode families at 65,536 and 65,537 pattern bytes using real backing
storage. It requires the direct engine, asserts expected accepted values, and
checks the exact `InterpretError.OutputLimit` variant on both engines. This
fixture is authored but unexecuted under the compiler suspension; it provides
no passing-test evidence yet. Output-boundary and work-exhaustion fixtures remain
required in addition to these input-boundary cases.

Quantifier correctness audit found that counts were saturated to pattern length
plus one, changing `a{10}` into six repetitions. Checked exact host-sized count
parsing replaces this behavior. The bytecode test suite now includes positive
and negative fixed/ranged/open-ended repetition cases with expected values on
both engines. These tests are unexecuted. Unrepresentable counts retain the
existing literal fallback; the stable regex compilation-error contract remains
open and must replace that prototype policy where required.

Empty-group audit: the unquantified group branch loop skipped the closing
boundary, incorrectly rejecting `()` and the trailing empty arm of `(a|)`.
The loop now evaluates that boundary, charges each branch attempt, and retains
an explicit malformed-opener rejection. Added expected-value tests for nested
empty groups, leading/trailing empty alternatives with suffix backtracking,
failed suffixes, and zero-width global replacement on both execution engines.
These regression sources remain unexecuted; quantified empty-group behavior and
general capture/backtracking completeness remain separate open requirements.

Quantified zero-width increment: successful empty atoms now satisfy remaining
minimum repetitions without recursive calls at the same position. Open-ended
repetitions allow minima larger than the haystack length. Regression source
covers fixed/ranged/open-ended empty repetitions, an optional consuming atom,
failed suffixes and global replacement on reference/direct engines. Execution
remains suspended; general endpoint alternatives and capture semantics remain
open, so this does not close the regex completion gate.

Regex stack containment increment: patterns with more than 1,024 nested groups
are rejected before matching, and a single repeated atom cannot recurse beyond
8,192 repetition states. Both limits use the typed `OutputLimit` contract in
the reference and direct-bytecode facades. The new regression source exercises
both boundaries on both engines; it remains unexecuted while compiler
validation is suspended. These guards contain host-stack growth but do not
replace the still-open iterative matcher work or adversarial corpus.

Regex helper-accounting increment: expression, group, class, quantifier, and
candidate-position scans now debit the same per-operation budget by inspected
bytes. Capture-layout scans receive the same charge before probing. This closes
the previously identified uncharged-helper gap statically (`860d70c`; ledger
`0f03e9d`), while execution and adversarial complexity evidence remain open.

Fixed-width repetition increment: literal, class, dot, and non-boundary escape
atoms now use an explicit greedy/backtracking loop rather than recursive calls,
so large ordinary repetitions avoid host-stack growth. The regression fixture
keeps an 8,193-byte fixed repetition successful while using a compound group
repetition to exercise the recursive guard. Static source evidence is recorded
in `cd7b45f` (ledger `3d5d065`); runtime parity remains unexecuted.

Call-stack containment increment: reference and direct-bytecode function entry
points now reject active call or handler depth at 4,096 with
`InterpretError.OutputLimit`. Direct recursive calls propagate an explicit depth
counter; the regression fixture exercises the same boundary on both engines.
This is a host-stack guard while the fully frame-based VM call protocol remains
open (`f221bb0`; ledger `a9f8202`), not evidence that deep recursion is yet
portable or optimized.

Continuation-budget increment: each captured continuation now has a 100,000
resumption budget in addition to the existing frame/value pools and `u32`
overflow check. Exhaustion is reported as `InterpretError.InvalidContinuation`
without wrapping or silently replaying stale state (`7d3c5eb`; ledger
`21b2305`). Multi-shot clone/replay safety and executed adversarial coverage
remain open.

Capture-metadata increment: handler verification now rejects empty or duplicate
continuation-capture names and `Void` capture types before any multi-shot policy
can execute. The regression fixture covers all three malformed cases
(`ccd397b`; ledger `617e26d`). This tightens declaration integrity but does not
yet connect capture declarations to every runtime SSA snapshot, so full
MultiClone alias-safety remains open.

Multi-shot alias-safety increment: runtime continuation capture/replay now fails
closed with `InvalidContinuation` when current or active caller snapshots contain
mutable array/map views. A regression fixture supplies an array-backed caller
value and requires the typed failure. Deep storage cloning remains required for
future aggregate replay (`467c458`; ledger `629536c`).

Multi-shot capture-policy increment: both `MultiReplay` and `MultiClone` now
reject declared affine, linear, borrowed, region-bound, and opaque captures;
only `Unrestricted` metadata is accepted in the stable profile. The IR fixture
covers a borrowed replay capture (`b0c646f`; ledger `949bea6`). Runtime
aggregate alias checks remain complementary because capture declarations are
not yet linked to every SSA snapshot.

Closed continuation metadata increment: the verifier now rejects unknown
`CaptureClass` ordinals instead of allowing malformed serialized metadata to
fall through to replay policy checks. Replay-safe effect declarations are also
validated as a set: entries must be non-empty and unique. Regression source
covers empty and duplicate replay-safe entries. These checks are static and
unexecuted while compiler validation remains suspended (`2fa8c25`, `5d803e2`,
ledger `10bae0d`).

Continuation-pool integrity increment: multi-shot resume now validates the
captured replay-frame span and every saved SSA-id, runtime-value, and dynamic
handler slice against the machine-owned pools before indexing. Active caller
snapshots use the same range helper, so malformed continuation metadata fails
closed with `InvalidContinuation` instead of relying on internal pool invariants
(`92ca6e1`; ledger `8614405`). This remains static evidence only.

Dynamic-handler depth increment: every runtime `HandlerPush`, including repeated
pushes within one function, now enforces the same 4,096 depth bound used at call
entry. Exceeding it reports `InterpretError.OutputLimit` before growing the
handler stack; the contract, regression source, and ledger are updated in
`bbbca7a`, `9a207bc`, and `92d04ba`.

Recovery-stack increment: reference and direct-bytecode `ErrorGuardPush` now
share a 4,096 retained-guard bound. The reference path marks a guard-limit
failure as non-recoverable by that same guard, preserving parity with the
direct facade's typed `OutputLimit` propagation (`7449b6c`; ledger `dc026ff`).

Type-table integrity increment: recursive descriptor validation now rejects
unknown `TypeKind` ordinals before child-range traversal. This closes another
malformed-IR enum boundary without allocating or interpreting a backend-specific
kind (`9909d5b`; ledger `3e4c161`).

Inline-type integrity increment: the verifier now applies the same closed
`TypeKind` check to every legacy inline type-bearing field, including modules
without an interned table. Unknown nested element-kind ordinals therefore fail
as `InvalidTypeTable` before instruction semantics are considered (`8365d9d`;
ledger `3ccd2e4`).

Recursive type-table increment: inline-shape matching now carries a 128-level
depth guard and rejects cyclic or hostile descriptor graphs as
`InvalidTypeTable`; a regression fixture supplies a self-referential child row.
This protects the verifier's recursive compatibility bridge while general
recursive descriptor support remains a planned IR feature (`3286bc3`; ledger
`4be742e`).

Runtime-value admission increment: the shared aggregate boundary now rejects
unknown `RuntimeValueKind` ordinals before interpreter or bytecode argument and
resumed-frame dispatch, alongside the existing flat-storage span checks
(`24780ce`; ledger `9d3f840`).

Differential-value admission increment: the owned comparison state machine now
rejects unknown `DifferentialValueKind` ordinals at every pending pair, including
recursively reached array and map members, instead of falling through to the
text scalar case (`14ff501`). This is a static malformed-artifact guard;
serialized snapshot schemas, shrinkers, and executed parity evidence remain
open.

Nested runtime-value admission increment: the IR now exposes its allocation-free
`runtime_value_kind_valid` predicate to typed adapters, and differential
runtime-to-owned conversion applies it before every recursive kind match. This
rejects malformed nested runtime storage as `DifferentialRunnerError.Invalid`
(`260c277`; ledger `79f197d`); executed malformed-storage fixtures remain open.

Strict engine-metadata increment: non-ignored differential engine requirements
now fail closed when capability-known flags contradict engine identity or its
direct/fallback claim. The ordinary value comparator still ignores backend
metadata by design (`d25fffb`); forced-engine qualification and serialized
artifact evidence remain open.

Runtime-pool admission increment: `runtime_values_ranges_valid` now scans the
complete caller-owned flat storage pool, rejecting unknown kinds and invalid
array/map spans even when those values are nested behind a valid root argument
(`7c2b284`). This closes the reachable-storage gap statically; allocation and
execution evidence remain suspended.

Differential comparator termination increment: owned array/map equality now
propagates a 128-level aggregate depth and caps selected pending pairs at one
million. Cyclic array and map fixtures are authored to require deterministic
`ObservationValue` mismatches rather than an infinite loop or host-stack
overflow; execution remains suspended.

Bytecode artifact-envelope increment: persisted `ESBC` metadata now caps the
borrowed source-revision field at 4 KiB in both allocation-free byte validation
and decoded-record metadata validation (`5f27773`). Cache restart/corruption
fixtures and actual artifact persistence remain open.

Bytecode artifact admission increment: the canonical `ESBC` writer now fails
closed for version/backend/engine-directness mismatches and oversized source
revisions, invalid metadata fingerprints return an explicit zero sentinel, and
the allocation-free reader rejects envelopes above a 64 KiB whole-record bound
before scanning their fields. This keeps writer, typed-record, and borrowed
decoder admission policies aligned (`8970c8a`) while cache restart/corruption
fixtures now cover invalid writer metadata and oversized records (`bd0ff62`),
while cache restart/corruption fixtures and actual artifact persistence remain
open.

Canonical IR narrowing increment: every collection length that the version-1
canonical stream encodes as u32 is now checked recursively across type tables,
globals, handlers, and function pools before bytes or fingerprints are emitted.
An unrepresentable host count fails closed as an empty byte stream or zero hash,
preventing malformed cache identities caused by silent host-to-u32 narrowing
(`b75a56a`); serialized-reader fixtures and execution evidence remain open.

Runtime equality containment increment: reference and direct-bytecode structural
equality now carry a 128-level aggregate depth through recursive array/map
comparisons. Cyclic array fixtures cover both engines and require deterministic
non-match results rather than host-stack exhaustion; broader equality semantics
and executed evidence remain open.

IR artifact metadata increment: `artifact_metadata_valid` now rejects version
mismatches, empty backend labels, and backend/source-revision metadata over 4 KiB
before `artifact_fingerprint_matches_module` accepts a correlation claim
(`c506b26`). Artifact serialization and cache restart/corruption evidence remain
open.

Source C-string boundary increment: the bounded source adapter now accepts a
terminator exactly at the 4 MiB content boundary without probing beyond that
position, and rejects an unterminated input that reaches the limit as
`ElisascriptSourceError.SourceTooLarge` (`4927559`; ledger `2a01892`). This is
static evidence only; lexer/parser corpus execution remains suspended.

Differential process-input increment: the direct differential process adapter
now bounds the aggregate terminated C-string payload for executable, adapter
entry, arguments, working directory, and environment at 64 MiB, and bounds
staged stdin at 64 MiB. Runner validation uses an explicit `ProcessBounds` state
and the low-level invocation boundary repeats the checks before allocation or
fork (`5aac066`; ledger `32eda93`). Execution remains suspended.

Differential output-budget increment: process runners now reject caller-supplied
capture ceilings above the 64 MiB hard budget before launching a child, and the
low-level invocation path repeats that check (`cb0d47f`; ledger `171eb1e`).

Interpreter C-string increment: the shared `nul_terminated_text` adapter now
rejects payloads whose terminator would reach the 64 MiB host-string ceiling,
covering filesystem, environment, and process callers that cross POSIX C
boundaries (`d0524ec`; ledger `53c5f0e`).

Validation-wrapper increment: both checked-in bounded wrappers now reject
malformed or zero RSS/time limits and non-`.elisascript`/missing fixture paths
before launch, install signal/exit cleanup, and clear the owned child PID after
`wait` to avoid PID-reuse cleanup (`601d25e`; documentation `50e5d6c`). The
watchdog itself remains unexecuted and compiler validation remains disabled.

Launcher-argument increment: all canonical program execution entrypoints now
bound host argv to one million elements and aggregate text to 64 MiB before
copying it into runtime storage; the existing u32 storage check remains in
force and all limits fail with typed `InterpretError.ArgumentMismatch`
(`150954d`, `8cd2ce1`; ledger `24b68fc`).

CLI text-boundary increment: `parse_elisascript_cli` now scans every
non-source argument in an explicit validation state and rejects embedded NULs
before copying the request (`9e58b9d`; docs `5a7635e`; ledger `b5c5a9f`).

Runtime-pool increment: shared interpreter/bytecode storage admission now caps
caller-owned flat runtime values at 1,048,576 entries, independently of the
serialized u32 offset range, including existing storage, append spans, map
pairs, and text-field materialization (`60542e4`; ledger `4606f75`).

Build a strongly statically typed scripting language, implemented in Elisa, with Elisa-style syntax and `.elisascript` source files. Elisascript must be the practical default for scripting across the user's programming projects: build orchestration, developer tooling, automation, text processing, data transformation, and differential validation of ports. Correctness comes first, flexibility second, performance third, with measured usability and performance sufficient to remove practical incentives to keep choosing the old scripting languages.

“Replacement” means that each script and workflow in the agreed project inventory can be implemented, maintained, installed, debugged, and run in Elisascript with equivalent required behavior and acceptable cost. It does not mean accepting Python, Perl, shell, or AWK syntax verbatim. Ports may use stronger types and explicit effects, but cannot silently discard behavior or depend on invoking the old interpreter for the work supposedly replaced.

External domain tools remain legitimate dependencies: invoking a C compiler, Git, a database client, or a project executable is part of scripting. Hiding a Python/Perl/AWK program inside an external command is not a completed migration. A legacy interpreter may remain a reference oracle during differential testing; record this separately from production dependencies.

The full goal is complete only when all of the following have evidence:

- [ ] The language contract is versioned, coherent, and implemented across every supported execution mode.
- [ ] The compiler, runtime, launcher, tooling, and maintained first-party libraries are Elisa implementations; bootstrap and foreign-library dependencies are documented and reproducible.
- [ ] Every inventoried production script has a disposition and every required workflow has an accepted Elisascript implementation.
- [ ] Production workflows have no hidden dependency on Python, Perl, shell evaluation, or AWK, including build/install/test entry points under our control.
- [ ] All required libraries have typed APIs, documented effects, explicit `error[...]` behavior, and maintained dependency policies.
- [ ] Malformed source, invalid IR, failed I/O, cancellation, and resource exhaustion produce defined outcomes, not corruption, hangs, or silently successful partial work.
- [ ] Differential tests establish required behavior against legacy references and between supported Elisascript backends.
- [ ] Fresh installation and complete first-party build/test/release flows work on every declared supported platform.
- [ ] Performance and ergonomics meet thresholds agreed from the actual workload corpus; no important regression is concealed by averages.
- [ ] Documentation, editor support, diagnostics, dependency management, reproducibility, and upgrade policy are sufficient for routine use without compiler expertise.
- [ ] Release qualification and post-migration observation demonstrate stability under ordinary and adverse workloads.

Absolute absence of bugs cannot be proven. “Completely stable” is operationalized here as passing the explicit release gates, eliminating known correctness blockers, and maintaining a regression and compatibility process. Passing a narrow suite or implementing a large API list is insufficient.

## 2. Non-negotiable design constraints

1. Preserve Elisa syntax and terminology. Propose deviations with examples and rationale before spreading them through the parser or libraries. Avoid adding competing spellings solely to imitate another language.
2. Static typing remains mandatory. Do not solve an inference gap by allowing unchecked values through execution. Dynamic JSON or heterogeneous input must use explicit algebraic data types and checked decoding.
3. Use `error[...]` rows, not a language-wide `Result` convention. Effects, recoverable errors, cancellation, and runtime defects must have distinct, documented roles.
4. Dynamic handler selection is permitted; operation payloads, resumed values, handler clauses, captures, effects, and errors remain statically checked.
5. Single-shot continuations are the default direction. Multi-shot use must be explicit, constrained, and justified; never infer replay safety from a friendly operation name.
6. Use explicit state machines for complex execution, I/O, parser, scheduler, and continuation protocols. Simple predicates can remain simple; do not obscure correctness by mechanically replacing every conditional.
7. Preserve exact numeric types, nominal paths/executables, evaluation order, and source spans across the pipeline.
8. One verified shared typed IR feeds the interpreter, bytecode VM, JIT, and native backends. Backend-specific recovery must not repair invalid frontend output differently.
9. Reuse sound Elisa compiler and runtime components. Elisascript-specific semantics belong in an explicit scripting layer; track upstream fixes and local deviations.
10. Build stage0/stage1 dependencies locally in isolation from installed and unrelated working-tree compilers.
11. Existing compiler-validation suspension remains in effect until explicitly reauthorized. Writing this plan does not authorize a build, test loop, watchdog override, process termination in another project, or a migration.
12. Commit completed implementation gains in coherent increments. This ignored plan and unrelated pre-existing changes are excluded from those commits.

## 3. Evidence baseline and current uncertainty

The following was established by reading repository sources and documentation, not by running the compiler. “Present” means code is present; it does not establish conformance or release readiness.

| Area | Present evidence | What remains to prove or implement |
|---|---|---|
| Frontend reuse | Vendored lexer, parser, semantic passes, backend, and runtime snapshot; provenance in `vendor/elisa-compiler/SOURCE.md` | Audit reachable sources, profile boundaries, upstream drift, and license/dependency records |
| Syntax | Shebangs, typed literals, Elisa parser adaptations, `.elisascript` loader | Complete source grammar, invalid-input recovery, consistent source and diagnostic spans |
| Static analysis | Large Elisa semantic analyzer plus scripting builtins and inference additions | End-to-end soundness; distinguish analyzer support from executable lowering support |
| Shared IR | Flat SSA CFG, typed block arguments, verifier, nominal types, structural type table | Complete recursive aggregates, ownership operations, descriptor consistency, malformed-input robustness |
| Structural values | Arrays/maps and homogeneous tuple-shaped lowering | First-class heterogeneous tuples/records/variants; remove fixed nesting limits deliberately |
| Module state | Constants and bounded global initializers | Module graph, initialization order, arbitrary supported initializers, shared state semantics |
| Effects | Perform operations, dynamic handlers, resumption, replay/clone policies | Declaration-authoritative operation typing, exact coverage, resource cleanup, sound multi-shot restrictions |
| Interpreter | Broad scalar, aggregate, regex, filesystem, process, and control-flow support | Adverse-input reliability, Unicode/numeric contracts, streaming, resource accounting |
| Bytecode | Direct execution subset and fallback to interpreter | Explicit direct-mode coverage; dynamic effects/global state support; packed artifact compatibility |
| Native/JIT | Copied Elisa backend sources | Shared-IR lowering and proven runtime ABI; copied LLVM code is not an Elisascript backend |
| Runtime bridges | File, directory, process, environment, stdio, and time POSIX modules | Typed handles, large streaming data, async I/O, cancellation, supported-platform implementations |
| Differential testing | Typed runners, observations, comparisons, process and Elisascript execution APIs | Complete reproducible worlds, artifacts, shrinking, lockstep, reporting, CLI integration |
| Driver | Source-file launcher and typed argv/main contract | Actionable diagnostics, packaging, modes, interrupt handling, OS exit-status policy |
| Validation | Lexer/parser/semantic/IR/runtime/runner/differential test source; bounded wrapper scripts | Actual execution evidence; verified memory guard; compiler validation is suspended |

Current documented restrictions requiring explicit resolution include heterogeneous tuples, bounded nested aggregates, restricted global initializers, a 4 MiB file-source ceiling, a 64 MiB whole-file input ceiling, interpreter fallback for some bytecode modules, unsupported file-handle-oriented printing, and best-effort (polling-based) process output ceilings. Do not remove safety limits without an alternative resource policy and large-input evidence.

Recent implementation slices are present in the current tip but have only static evidence because compiler validation is suspended: Path line/append receiver APIs (`67a4114`), finite-safe differential float comparison (`6e6cbd4`), process-group and differential output bounds (`d47d950`), strict direct-bytecode execution (`965f273`), bounded interpreter process capture (`888c29a`), explicit execution-engine identity (`3c4e20c`), a pre-run bytecode capability report (`7c2836f`), differential-run engine provenance (`f20070f`), phase-aware launcher diagnostics (`b7d97e0`), capability-snapshot propagation through `Execution`/`DifferentialRun` (`83051d9`), explicit differential engine-qualification policies (`b2a3f52`), fingerprint-bound bytecode artifact metadata (`439e2b4`), typed launcher error-variant preservation (`1db8595`), operation-aware dynamic-handler coverage (`7cb64f0`, `1832f96`), invalid dynamic-path rejection (`4143079`), duplicate source-effect rejection and operation spans (`e8f683a`, `7beb87a`), allocation-free `ESBC` envelope validation (`4c32e29`), empty executable rejection across interpreter process entrypoints (`1b4abee`), duplicate host-supplied environment-key rejection before fork (`dbcf9ea`), `=`-name rejection across process and global environment host boundaries (`33117cb`), malformed handler coverage metadata rejection (`4fb3b51`), allocation-free borrowed metadata decoding for validated `ESBC` envelopes (`6d396c7`), host-`usize` representability checks at the artifact cache boundary (`ce8c03b`), independent stdout/stderr capture-limit enforcement (`609abeb`), fail-closed handling for unknown continuation-policy ordinals (`7dae8ff`), subtraction-based differential snapshot bounds with a private module helper (`5076a9`), explicit private/public boundaries for differential state machines and host adapters (`34c7d18`), private/public boundaries for bytecode dispatch and VM internals (`2bec7a6`), private/public boundaries for runner/source loader state (`21c69c5`, `51a633a`), subtraction-safe terminal handling in regex/separator scanners (`e817b58`), bounded continuation snapshot pools (`703b115`), bounded process argv/environment/pipeline allocation (`85383ea`, `88d6bad`, `9b72917`), bounded observation traces and differential snapshot conversion (`4d98dc3`, `ef3f647`, `c5b34e8`, `be07543`, `10ada57`), pre-reconstruction bytecode block-layout validation (`667bc41`), overflow-safe aggregate process argv-byte bounds (`4f32def`), overflow-safe aggregate process environment-byte bounds (`6884aa6`), pre-staging process stdin byte bounds (`8bc41e8`), checked join-length accumulation in interpreter and direct bytecode (`b417eaf`), checked direct-bytecode text-count narrowing (`11b74d6`), read-bytes runtime-storage span validation (`38d1479`), bounded directory scanner retention plus glob variant/result count caps (`c52d3d8`), and bounded glob variant/result bytes (`d863972`). Re-audit each slice for behavior, error/effect propagation, empty inputs, named arguments, temporary receivers, and fixture expectations when execution is reauthorized. In particular, line reading currently uses explicit newline splitting and preserves a final empty field; it must not be mislabeled as Python `splitlines` semantics. The `Path.write_lines` semantic fixture must be checked against what the semantic layer actually checks versus what the lowerer rejects.

The source-loading boundary also now bounds its C-string terminator scan to the
4 MiB source ceiling, accepting a terminator at the exact content boundary and
never reading past that position (`4927559`; ledger `2a01892`).

The differential process adapter now applies the same static resource discipline
to aggregate process text and staged stdin, before C-string duplication or
temporary-file writes (`5aac066`; ledger `32eda93`).

Its caller-selected output ceiling is also bounded by the same 64 MiB hard
capture policy before fork (`cb0d47f`; ledger `171eb1e`).

The reference interpreter's shared POSIX C-string adapter now applies an
individual 64 MiB payload ceiling before adding terminators or allocating,
covering filesystem and environment boundaries as well (`d0524ec`; ledger
`53c5f0e`).

The checked-in validation wrappers now fail closed on malformed limits and
fixture paths and clean up their owned temporary logs/compiler tree on signal
or exit (`601d25e`; docs `50e5d6c`).

The validation wrappers now also serialize lowering/test workers with an atomic
lease directory under `${TMPDIR:-/tmp}`. The lease records the owner PID and
`ps` start identity, refuses live owners whose identity cannot be trusted, and
reclaims only leases whose recorded PID is no longer live. A readiness marker
prevents a concurrent worker from deleting a lease while its owner metadata is
being published. This is static evidence only; compiler validation remains
suspended and the polling RSS guard is not an instantaneous hard cap.

Canonical launcher/program runners also cap aggregate argv text before staging
borrowed host views in runtime storage and reject vectors above one million
elements (`150954d`, `8cd2ce1`; ledger `24b68fc`).

The CLI parser now validates embedded NULs across the entire typed argument
vector with its own state-machine phase (`9e58b9d`; docs `5a7635e`; ledger
`b5c5a9f`).

Runtime aggregate producers and admission checks now share a 1,048,576-value
caller-owned storage ceiling in both execution engines (`60542e4`; ledger
`4606f75`).

The execution engine identity is now part of the observation contract: `ReferenceInterpreter`, `DirectBytecode`, or `BytecodeInterpreterFallback`. Any future parity report must record it and must reject fallback when the acceptance criterion requires independent engines. The process-output ceiling is enforced by polling captured-file sizes while a private process group runs; it can overshoot between polls, so it is a containment aid rather than a hard OS quota. The public host error is `InterpretError.OutputLimit`, distinct from ordinary process setup or exit failure.

The regex boundary slice now rejects haystacks above 64 MiB, patterns above 64 KiB,
and replacement payloads above 64 MiB before matching. Each complete search,
split, find, capture, or replacement operation shares a 100-million-state budget
across scanner positions, recursive matcher states, backtracking, and capture
probes (`1d960d8`; ledger update `24e7061`). Exhaustion is propagated as the
typed `InterpretError.OutputLimit` error through the reference interpreter and
direct bytecode wrappers. Replacement builders also cap aggregate output at
64 MiB before final publication (`0930035`, `9518746`; ledger update `5f8731a`).
Exact zero-width minimum accounting is recorded in `1768d07`; host-stack
group/repetition bounds are recorded in `bdd084f` (ledger `6984c86`), helper
scan accounting in `860d70c` (ledger `0f03e9d`), and iterative fixed-width
repetition in `cd7b45f` (ledger `3d5d065`). This is containment evidence only:
dstr allocator behavior and adversarial regex qualification still require
execution and independent stress evidence.
Compiler, VM, and parity execution remain suspended.

The latest static slices also include qualified private/public POSIX bridge
modules (`312624e`) and fail-closed filesystem path/copy boundaries
(`27dd2f2`). These changes are not execution evidence while compiler validation
is suspended.

The Path line/file slice now preserves exact structural result rows for
`darray[sview]` line and directory helpers and `darray[u8]` byte reads whenever
the surrounding semantic table has interned those rows (`6567080`). Line writers
also lower their arguments contextually, so empty literals are checked as
`darray[sview]` rather than rejected as untyped values; temporary Path receivers
and named-argument rejection have static lowering fixtures. Compiler and runtime
execution evidence remain blocked by the validation suspension.

Decimal parsing now saturates exponent accumulation and scaling at a 4096-step
IEEE-754 bound (`4c2fb53`), preventing integer wraparound and unbounded scaling
walks for hostile exponent text while preserving zero/infinity saturation.
Validation and cross-backend numeric parity evidence remain suspended.

Dynamic continuation snapshots now use bounded machine-owned pools for copied SSA
ids, runtime values, handler names, replay frames, and live continuation records,
with subtraction-safe admission checks (`703b115`). Ordinary direct calls reclaim
their snapshot suffix on return; dynamic callbacks reclaim replay and snapshot
suffixes after the callback completes while preserving any still-active outer
capture. Exhaustion reports `InterpretError.InvalidContinuation` before partial
pool state is published. Multi-shot policy soundness and execution evidence remain
open under the suspended validation gate.

Process entrypoints now impose a one-million-element argv budget before reserving
owned C-string and pointer storage (`85383ea`). The guard covers ordinary runs,
stdout/stderr capture, stdin capture, and full `ProcessCapture` execution; it is a
runtime allocation policy and does not replace static element typing or NUL checks.
Environment override maps and pipeline stage vectors use the same bound before
host reservations or child-spawn loops (`88d6bad`). Large-argument, large-
environment, and cross-platform process evidence remain pending.

Differential process runners now repeat this allocation policy independently of
the Elisascript interpreter (`9b72917`). Runner validation reports explicit
too-many-arguments and too-many-environment-entry issues, while the low-level
invocation API fails closed before C-string reservation or `fork`; process
input-size and cross-platform execution evidence remain pending.

Ordered `observe` traces now share a one-million-event cap across the reference
interpreter and direct-bytecode engine (`4d98dc3`). The engines raise the existing
typed `OutputLimit` before appending beyond the cap, preventing differential trace
evidence from becoming an unbounded retention channel; trace-boundary execution
and parity evidence remain pending.

The differential runtime adapter applies the same one-million-event limit to
observation snapshots supplied by external adapters (`ef3f647`). It rejects an
oversized snapshot before converting any element into the owned comparison pools,
so conversion itself cannot become an unbounded retention path; malformed-input
and boundary execution evidence remain pending.

Differential aggregate values now use a separate one-million-element owned-pool
budget (`c5b34e8`). Array/map constructors and recursive runtime conversion check
the remaining capacity before reserving or appending placeholders, returning the
typed `OutputLimit` error instead of allowing a representable-but-hostile `u32`
snapshot to consume unbounded memory; boundary execution evidence remains
pending.

The same conversion path now rejects aggregate nesting deeper than 128 levels
before recursive descent (`be07543`). The public conversion signature remains
stable while a private depth-aware helper carries the guard, preserving namespace
hygiene and preventing externally assembled snapshots from exhausting the host
call stack; boundary execution evidence remains pending.

The comparator now repeats observation and owned-pool budgets before entering its
pending-pair and map-bijection state machines (`10ada57`). Oversized manually
assembled runs therefore return a bounded typed comparison record, and value/map
equality refuses oversized backing pools before allocating matcher state; parity
and malformed-fixture execution evidence remain pending.

A read-only discovery snapshot now records raw Python, Perl, AWK, shell-family,
and Makefile candidate counts plus the required per-file disposition schema in
`docs/migration-inventory.md` (`f63d1ab`). The scan is intentionally
over-inclusive and did not execute any legacy file; owner assignment,
vendored/generated classification, machine-readable manifests, and accepted
port implementations remain open P1 work.

Bytecode preflight now validates every block's declared offset, exact instruction
coverage, cumulative u32 representability, and total function coverage before
`bytecode_to_ir` reconstructs instruction starts (`667bc41`). This closes the
malformed block-count wraparound path in both ordinary and strict direct-bytecode
entrypoints; malformed-module execution evidence remains pending.

Regex search, capture, split, find, and replacement scanners now treat the
end-of-input position as a terminal state: failed probes stop without a
wrapping increment, and a zero-width replacement at EOF terminates without a
synthetic `length + 1` cursor (`d5b3c4a`). The progress rule is documented as a
shared bound across all regex operations; execution and adversarial `usize`
boundary evidence remain blocked by the validation suspension.

Runtime array and map views now reject non-empty spans whose final addressed
element would exceed the serialized `u32` offset domain, even if the host
`usize` backing storage is wider (`d721d0a`). The private span helpers use
subtraction and `count - 1` arithmetic so malformed large-host values cannot
wrap while being validated; the public range predicates remain the single
access gate for interpreter and bytecode aggregate operations.

Direct bytecode unary and bitwise integer operations now share the interpreter's
narrow-width contract (`933a15f`): signed narrow negation rejects its minimum,
signed narrow bitwise results are range-checked, and unsigned narrow complements
are masked to the declared width. The checks occur before the value-only packed
dispatch performs host arithmetic; independent engine execution evidence remains
blocked by the validation suspension.

Interpreter and direct-bytecode step budgets now check the limit before
incrementing (`46dbc55`). This preserves the exact `N`-tick allowance while
preventing a maximum-`u64` budget from wrapping the counter; budget behavior is
documented as part of the shared execution contract.

All interpreter and differential process argv builders now clear their trailing
NULL slot using `size_of(uintptr)` rather than a hard-coded eight bytes
(`583fe58`). The shell-free process contract therefore remains valid on hosts
with either 32-bit or 64-bit pointers; cross-platform process execution evidence
is still pending while validation is suspended.

Process argv preallocation no longer adds fixed executable/terminator slack to
host-controlled argument counts (`de144fa`). Dynamic arrays grow for those two
slots after the bounded count reservation, so a 32-bit count near `usize` maximum
cannot wrap during `reserve`; process output, argument-count, and allocation
limits still require execution qualification.

Directory entry materialization now rejects an ABI-reported name length above the
1024-byte inline Darwin bridge buffer before copying (`eed6111`). This keeps
`ListDirectory` and `Path.iterdir` fail-closed on malformed platform records;
non-Darwin layout adapters and executed adverse-entry evidence remain open.

Glob path joining and brace-variant assembly now detect host-size addition wrap
before allocation (`ff8da0b`). The walker returns its established
`DirectoryError` sentinel for a wrapped path instead of creating a truncated
match; recursion-depth and adversarial path corpus execution evidence remain
pending.

The recursive glob adapter also checks the `3 + pattern_length` allocation for
its `**/` prefix (`e4f6702`). Overflow is reported through the same
`DirectoryError` path before the pattern is handed to the bounded walker.

Differential runtime-to-owned snapshot conversion now checks each aggregate's
new pool slice against the serialized `u32` offset domain before narrowing a
host `usize` (`608a158`). Map placeholder storage is appended per key/value
pair, eliminating a host-side `count * 2` wrap on narrower targets; malformed
or unrepresentable snapshots raise `DifferentialRunnerError.Invalid` before
comparison can index them. Full malformed-map corpus execution remains part of
the suspended qualification work.

The standalone differential process wait loop now checks its positive timeout
budget before incrementing the poll counter (`e813826`). This preserves the
existing bounded-poll semantics while preventing a maximum-width `u64` timeout
from wrapping into an unbounded wait; process cleanup and runtime validation
evidence remain suspended.

Program entrypoint runners now validate the complete caller-owned argv slice
against the runtime's serialized `u32` aggregate domain before narrowing counts
(`0502d5d`). The phase-aware diagnostic path records an
`InterpretError.ArgumentMismatch`, while ordinary source/file runners raise the
same typed error; no oversized argument vector can silently wrap into a
different runtime array. Execution and large-argv evidence remain blocked by
the validation suspension.

Structural type interning now rejects child pools beyond the descriptor's `u16`
count or serialized `u32` offset domain before narrowing (`7eb70ae`). It returns
the existing invalid-id sentinel without mutating the table, preventing an
oversized host collection from aliasing a valid type identity; compiler and
adversarial table execution evidence remain pending.

Differential executable-field NUL scanning now records an explicit found flag
instead of advancing to a `length + 1` sentinel (`0c65d98`). A maximum-width
text view therefore cannot wrap while being validated; boundary fixtures and
cross-platform execution evidence remain part of the suspended qualification
queue.

Interpreter and direct-bytecode function boundaries now validate every aggregate
argument (and continuation snapshot values) against the shared flat-pool range
predicates before body execution (`b3041fe`). Malformed externally assembled
views therefore fail with `IndexOutOfBounds` instead of being returned or
indexed as valid values; nested malformed-pool corpus execution is still open.

The interpreter and differential C-string adapters now detect a wrapped
`length + 1` terminator allocation and return their established empty/failure
sentinel before allocating (`e20c073`). This keeps process, filesystem, and
environment C-string boundaries fail-closed for maximum-width host views;
adversarial host-pointer execution remains suspended.

Multi-shot continuation dispatch now refuses to increment its `u32` resumption
counter at the maximum value (`53db210`), returning
`InterpretError.InvalidContinuation` before wraparound. Replay/clone semantics,
resource cleanup, and adversarial continuation execution remain unqualified
until validation is reauthorized.

Map insertion paths in both interpreter and direct-bytecode backends now reject
the maximum `u32` entry count before adding a new pair (`49583b2`). Their
reserve arithmetic was removed where dynamic growth is sufficient, eliminating
another `count * 2` host-wrap path; the typed failure is
`InterpretError.IntegerOverflow` and no replacement map is published.

Array insertion and array concatenation now reject `u32` count overflow before
publishing a new view, while map concatenation checks the same limit only when
a previously unseen key would be appended (`bde66ec`). Aggregate copy/pop paths
no longer use unnecessary multiplication-based reservations in this slice, so
dynamic growth cannot wrap a host `usize`; execution evidence remains pending.

Interpreter and differential process-capture readers now round-trip nonnegative
`i64` stream sizes through host `usize` before allocation (`320f78f`). A file
size representable to POSIX but not to the target host is reported as a typed
process failure rather than truncated into a smaller buffer; large-stream and
cross-platform execution evidence remain suspended.

Join operations in the interpreter and direct-bytecode backend now validate
separator multiplication and field-length additions before allocating
(`1bc8f60`). Wrapped sizes raise `InterpretError.IntegerOverflow` rather than
producing truncated text; normal empty-join behavior is unchanged.

Text `+` concatenation now performs the same checked host-size addition in both
execution backends (`bbaade8`), raising `InterpretError.IntegerOverflow` before
an overflowing buffer allocation.

The vendored Elisa string runtime now hardens its shared allocation boundaries
(`f09c05e`). Core concatenation, slicing, view-copy, and small-string interning
check length and terminator arithmetic before converting sizes to the allocator's
signed interface; f-string builders validate host representability and use
subtraction-based capacity checks before copying. Overflow therefore fails
closed through the existing panic/abort contract instead of passing a wrapped
size to allocation or memcpy. Runtime validation remains suspended.

Numeric formatting in the same runtime now rejects a failed `snprintf` length
and checks the formatted payload-plus-terminator size before allocating
(`98c6d7d`). Integer, unsigned-integer, and floating-point conversions use the
validated length for both allocation and the second formatting call, so a host
formatting failure cannot become a wrapped allocation or an undersized write.

The shared arena and collection layer now guards host-size growth
(`d2b8e41`). Arena region byte totals, alignment rounding, slot offsets,
reallocation sizes, commit rounding, and used-byte counters reject wrapping
arithmetic; dynamic arrays use checked byte-size/capacity helpers; dictionaries
and sets use subtraction-based load thresholds and checked bucket allocation;
inline-vector spills and lengths are bounded as well. Malformed or adversarial
sizes therefore fail closed before pointer arithmetic or memcpy. This remains
static evidence only until compiler validation is explicitly reauthorized.

The remaining shared view/string helpers now use the same checked byte-size
contracts (`fc2e6fc`). Generic view slicing, indexed access, equality/copy,
arena duplication, and formatted arena strings no longer multiply or add
terminator sizes unchecked; C-string scanning has an explicit terminal overflow
guard, and trusted region pointer checks reject wrapped end addresses. The
allocator substrate therefore has one consistent fail-closed policy across
builders, views, and region metadata.

Whole-file I/O and parallel slice adapters now fail closed at their host
boundaries (`22a8878`). File reads and writes round-trip POSIX `i64`/view lengths
through host `usize` before reserving or passing counts to libc, while slice
creation handles empty/malformed arrays, zero worker counts, and ceil-band
arithmetic without division, multiplication, or index wrap. These checks keep
the convenience APIs safe without changing ordinary bounded behavior.

Interpreter text and copy-path operations now apply the same `ftell`-to-host
`usize` round-trip before allocating, reading, or writing (`9bdcfa8`). All
whole-file materialization paths use one validated count for buffer capacity,
libc I/O, loop bounds, and runtime array lengths, preventing a 32-bit host from
turning a large POSIX size into a wrapped allocation or copy. Execution evidence
and low-resource behavior remain part of the suspended qualification work.

The launcher and in-process differential file runner now guard their own
NUL-terminated source-path buffers (`7d61dbd`). The source/target length is
computed once, checked for terminator wrap, then reused consistently for
allocation and append; an impossible size produces a typed diagnostic instead
of a wrapped builder capacity.

Those source-path guards now also reject sizes that do not round-trip through
the allocator's signed `i64` interface (`52d0c13`), matching the interpreter
and differential C-string adapters. This prevents a maximum-width host view
from becoming a negative allocator request even when `length + 1` itself did
not wrap.

The runtime aggregate pool now has shared, namespace-owned append predicates
(`60ac4e7`). Reference-interpreter and direct-bytecode constructors validate
u32-representable storage starts and complete append spans before publishing
array/map views, including map-pair concatenation, directory snapshots, and
fixed-size partition results. A host pool that is already outside the serialized
offset domain now fails with `IntegerOverflow` instead of silently truncating a
`usize`; the same contract is documented in `docs/ir.md` (`ab1c265`). This is
static evidence only while compiler execution remains suspended.

Differential aggregate fixture builders now use the testing module's typed error
row (`73657be`). `differential_array_value` and `differential_map_value` reject
unrepresentable pool offsets, append spans, and odd map payloads before storage
extension, so malformed snapshots cannot masquerade as comparison values. The
contract and propagation requirement are documented in
`docs/differential-testing.md`; execution evidence remains suspended.

Text split and regex result materialization now reserves the serialized pool
domain before starting (`376768d`). The shared runtime predicate accounts for
the possible empty-input field without computing a wrapping `length + 1`, and
both the reference interpreter and direct bytecode split paths use it. This is
static evidence only; compiler and runtime execution remain suspended.

The tracked capability ledger is now established at
`docs/capabilities/ledger.md` (`d719eb1`). It records requirement IDs, typed
contracts, exact source revisions, backend/workflow scope, and explicit open
issues, and provides the evidence fields required before a release claim. Its
entries intentionally distinguish static review from executed or differential
verified status while the compiler-validation stop remains active.

The module boundary policy is part of the stability plan: each subsystem owns a named module namespace, exposes only deliberate data types and entry points from an explicit `public:` section, and keeps cursor/state-machine helpers, host adapters, and representation details in `private:` sections. Cross-module calls must go through the owning module's public contract; tests that need an internal invariant should use a public inspection API rather than widening visibility. Names must remain qualified by subsystem (`EsLex`, `EsParse`, `EsIr`, `EsBytecode`, `EsRuntime`, and `EsTesting` submodules such as `EsDifferential`) and new public symbols require a collision audit before merge.

Since the previous baseline, handler clause callbacks now receive the same static capability accounting as ordinary calls: undeclared callback effects or `error[...]` entries are rejected at the enclosing `Perform` site (`a7b9ac9`).

The IR verifier now uses saturated, target-independent pool bounds for block, edge,
operand, and interned type-table child slices, clamping malformed ranges before
diagnostic iteration (`350b935`).
Public type-table child lookup and inline-shape validation now apply the same
fail-closed child-range checks before indexing (`4bba9f6`).
Canonical module bytes and fingerprints now retain any non-empty child pool while
invalid orphaned pools are rejected by verification, preventing malformed metadata
from colliding with an empty table (`477d073`).
The differential testing module now applies explicit `public:`/`private:` sections:
state-machine cursors, POSIX symbols, and comparator helpers are private while the
runner/value records and adapter/comparator entrypoints remain public (`34c7d18`).
The bytecode module follows the same boundary: preflight/execution cursors,
direct value/opcode helpers, and guard internals are private, while control
inspection, artifact/capability, lowering, and execution APIs remain public
(`2bec7a6`).
The runner extension likewise keeps CLI/entrypoint cursors and diagnostic/signature
helpers private while exposing only request/diagnostic records and canonical
execution entrypoints (`21c69c5`).
The source extension now keeps its bounded C-string scan, extension cursor, and
semantic-error predicate private while retaining the size constant, extension
checks, and source-to-IR loaders as its public contract (`51a633a`).
The interpreter's regex and separator scanners now terminate explicitly on a
zero-width match at end-of-input and use subtraction-based separator bounds;
this removes synthetic `length + 1` sentinels and wrapping `cursor + separator`
checks from malformed or host-sized text views. CRLF lookahead also checks the
remaining length before advancing (`e817b58`; compiler
validation remains suspended).
The POSIX bridge is now assembled under a canonical `EsRuntime` module: libc
declarations are private `_impl` symbols, while public forwarding operations and
Darwin layout types are qualified and imported explicitly by IR/differential
consumers. The native `@link_name` ABI is unchanged (`312624e`; compiler
validation remains suspended).
Filesystem host boundaries now fail closed for empty/embedded-NUL paths and
allocation failures, and regular-file copies enforce the same 64 MiB input
ceiling as whole-file reads (`27dd2f2`; compiler validation remains suspended).
Working-directory snapshots and directory-entry ownership now also fail closed
on host allocation failure, preserving `DirectoryError` rather than exposing
partial paths or entries (`e811488`; compiler validation remains suspended).
The native launcher now has the same qualified boundary: `EsDriver` owns private
argument/diagnostic helpers and exposes only `run`; global `main` is an ABI shim
(`4b91498`; compiler validation remains suspended).
Bytecode artifact fixtures now also mutate a serialized capability count to the
maximum-width value and assert fail-closed rejection, covering the host-`usize`
boundary without executing a compiler (`4238989`; compiler validation remains
suspended).
The direct bytecode text engine now mirrors the interpreter's subtraction-safe
count, replacement, separator, and CRLF cursor guards, preventing backend-only
wraparound reads (`a4f9613`; compiler validation remains suspended).
The interpreter's integer-literal, escape-decoding, regex-group/class, glob,
replacement, and end-anchor scanners now use the same remaining-length checks;
malformed host-sized views cannot turn lookahead into wrapped indexing
(`866ddf4`; compiler validation remains suspended).
Verifier slice sentinels now preserve an out-of-range marker for hostile starts
or counts, so opcode-specific checks cannot mistake a clamped end for a valid
operand pool and index outside it; a malformed `Copy` fixture covers the case
(`349a1a5`; compiler validation remains suspended).
The file-backed source adapter now computes its filename length once and checks
the owned path allocation before any append, preserving the typed file error on
allocation failure (`7402585`; compiler validation remains suspended).
Filename validation itself is now bounded to 4 KiB before constructing an
`sview`, so unterminated host pointers cannot drive an unbounded suffix or lexer
scan (`00258e8`; compiler validation remains suspended).
Stdin snapshots, text concatenation/formatting, regex replacement, and aggregate
formatting now check owned-buffer allocation before appending, mapping failures
to the existing typed console/empty-value contracts instead of dereferencing a
null buffer (`2e85e95`; compiler validation remains suspended).
Glob variant/path/match ownership now propagates allocation failure through the
existing walker state machine and reports `DirectoryError`, preventing partial
or null match publication (`01066c3`; compiler validation remains suspended).
The interpreter and direct bytecode text paths now also handle zero-length and
failed owned-buffer allocations explicitly for joins, concatenation, regex/text
replacement, environment snapshots, and recursive glob prefixes. This preserves
the canonical empty-text or typed-environment/directory failure contracts instead
of passing a null `dstr` into append/view helpers (`f7b05e4`; compiler validation
remains suspended).
Reference and direct-bytecode integer arithmetic now share checked overflow
contracts for signed/unsigned narrow values and the representable 64-bit range;
division by `-1` at the signed minimum and shift-left underflow are rejected as
`IntegerOverflow` rather than relying on host arithmetic behavior (`5cd0732`;
compiler validation remains suspended).
Canonical serialization now keeps field-level emitters and hash primitives
private to `EsIr`; the bytecode envelope reaches them only through qualified,
purpose-named `canonical_artifact_*` adapters (`4aac92e`; compiler validation
remains suspended).
The file-backed source adapter now obtains its filename length exclusively from
the qualified bounded `EsIr` helper. The 4 KiB filename policy includes the
terminating byte and no longer performs a one-byte-past-limit or unbounded lexer
scan (`b2bbde6`; compiler validation remains suspended).
The vendored `Fs.normalize` and `Fs.relative` path scanners now advance only
when a byte remains, eliminating terminal `usize` cursor wraparound while
preserving separator and trailing-component behavior (`e06fd80`; compiler
validation remains suspended).

## 4. Planning discipline and deliverables

Every work item below starts open unless independently evidenced. Maintain a small capability ledger separate from prose documentation, eventually under a tracked path such as `docs/capabilities/`. Suggested fields:

| Field | Required content |
|---|---|
| Requirement ID | Stable ID linking feature, workflow, tests, and release gate |
| Contract | Types, value semantics, effects, errors, ownership, evaluation order, limits |
| Status | Absent / designed / implemented / statically reviewed / executed / differential verified / release qualified |
| Source | Exact implementation paths and revision |
| Tests | Named positive, negative, boundary, fault-injection, and backend cases |
| Run evidence | Toolchain identity, command, platform, seed, result, resource metrics, revision |
| Backend | Interpreter, direct bytecode, fallback, JIT, AOT, or explicit unsupported |
| Workflow | Inventory entries this capability unblocks |
| Open issue | Known limitation, owner, next action, and dependency |

For each implementation increment:

- Write or confirm its contract first, with examples in established Elisa syntax.
- Inspect existing implementation and test coverage before adding new branches or aliases.
- Implement through the narrowest appropriate layer; avoid a new opcode for a library composition unless its semantic or performance need is established.
- Update typing, lowering, verification, runtime, serialization, diagnostics, and documentation together where applicable.
- Add meaningful tests for behavior and rejection boundaries; avoid assertions that merely copy internal implementation shape.
- Run the authorized checks with bounded resources, preserving failure evidence before retrying.
- Review the exact diff; preserve other work; commit only the completed increment.
- Mark unexecuted work unverified. A documentation statement, test count, or static diff check is not an execution result.

## 5. Phase P0 — Stabilize the development and validation environment

Dependencies: none. Purpose: reliable feedback before increasing implementation scope.

- [x] Record the current Elisascript revision, dirty files, compiler source revision, compiler executable hash, host architecture, dependency revisions, and supported bootstrap chain in `docs/validation-baseline.md`; refresh it whenever any identity changes.
- [x] Resolve the unfinished Path method increment as its own change. Commit `67a4114` adds the typed `Path.read_lines`, `write_lines`, `append_lines`, `append_text`, and `append_bytes` receiver forms with semantic/lowering fixtures; compiler execution remains suspended.
- [ ] Establish a dedicated local compiler checkout/build directory and output directories keyed by compiler revision and configuration. Preserve the currently documented compiler pin until a replacement is explicitly approved.
- [x] Audit `scripts/run_bounded_lowering.sh` and `scripts/run_bounded_test.sh`: fail closed, reject unintended executables, preserve quoting, identify the actual launched process tree, clean up descendants, and propagate exit status. Static audit is recorded in `docs/development.md` and enforced by `scripts/check_validation_wrappers.sh`; execution remains suspended.
- [ ] Demonstrate the watchdog using a synthetic bounded memory consumer before running a compiler. Cover child spawning, rapid growth, timeout, cancellation, process exit between samples, watchdog failure, and PID reuse.
- [ ] Measure resident memory across the entire launched tree. Document sampling overshoot and limitations; a polling RSS guard is not an instantaneous hard cap. Use OS-enforced constraints or isolated workers where needed.
- [x] Add a validation concurrency lease scoped to this project's workers. Detect a stale lease using live process identity, not a lock file alone. Do not terminate unrelated project processes merely because they run an Elisa compiler. Static implementation is in the bounded wrappers; race execution remains suspended.
- [x] Keep the explicit user reauthorization gate until permission is granted. Never set the override as a side effect of “continue.”
- [ ] Split huge compilation fixtures into small independently compilable groups where practical. Preserve a full integration suite without forcing it into every edit cycle.
- [ ] Cache only with complete compiler/source/options/dependency identities; stale artifacts must never masquerade as new validation.
- [ ] Record peak RSS, elapsed time, compiler output size, and test count for each validation shard; identify compiler growth regressions separately from language failures.
- [x] Provide an emergency stop for owned workers and disable automatic respawning after resource failures via `scripts/stop_bounded_validation.sh` and the persistent validation-disabled latch; exercise it only in an isolated synthetic harness after reauthorization.
- [ ] Later migrate first-party validation orchestration to Elisascript; retain a documented bootstrap mechanism until the language can build and validate itself.

Exit gate G0: the smallest source can traverse the authorized pipeline under demonstrated resource control; failures are reproducible, owned children terminate, and the installed compiler remains isolated. Until G0 is open, source review and planning can proceed but executable correctness stays unproven.

## 6. Phase P1 — Inventory real scripts and define compatibility targets

Dependencies: read-only inventory can begin before G0. Do not port or delete scripts as part of discovery.

- [ ] Identify and agree project roots; enumerate tracked scripts, executable files, shebangs, Makefile recipes, package task definitions, CI steps, hooks, generated scripts, notebooks used operationally, and embedded command snippets.
- [ ] Scan extensions and content: `.py`, `.pl`, `.pm`, `.awk`, `.sh`, shell variants, extensionless tools, inline `python -c`, `perl -e`, AWK programs, shell pipelines, and scripts generated by build systems.
- [ ] Distinguish user-maintained code from vendored upstream tooling and generated artifacts. Record which dependencies can be replaced versus wrapped or retained as external domain tools.
- [ ] For every entry record purpose, owner/project, entry point, callers, inputs, output schema, stdout/stderr, exit conventions, files touched, permissions, environment, cwd, locale, time/random dependencies, signals, concurrency, and platforms.
- [ ] Record library imports and external executables. Classify Python ecosystem needs such as HTTP, structured formats, plotting, numerical arrays, databases, package APIs, and system integration.
- [ ] Capture shell details: globbing, quoting, word splitting, redirections, substitutions, pipelines, traps, functions, positional arguments, sourcing, `set -e`, `pipefail`, and platform-dependent utility flags.
- [ ] Capture Perl/AWK details: record/field separators, regex dialect, replacement rules, match captures, encodings, locale, implicit variables, associative-array ordering, formatting, and in-place edits.
- [ ] Classify risk: pure transformation; read-only filesystem; local mutation; process supervision; network mutation; release/deployment. Design safe fixtures for each.
- [ ] Rank workflows by frequency, dependency fan-out, operational importance, complexity, and migration risk. Prioritize capabilities that unblock several real scripts.
- [ ] Preserve representative input/output fixtures and reference environments without executing destructive or remote side effects.
- [ ] Establish minimum corpus categories: tiny CLI, build graph, test runner, binary transformer, recursive file tool, large log aggregation, regex rewrite, JSON/CSV tool, HTTP client, package/release helper, concurrent supervisor, and port differential harness.
- [ ] Produce a dependency graph and migration matrix with explicit acceptance criteria per workflow.
- [x] Add a read-only machine-readable candidate manifest generator and schema (`scripts/inventory_candidates.sh`, `docs/migration-inventory-schema.md`); full per-file ownership, caller, fixture, and acceptance review remains open.

Gate G1: no known production scripting entry point lacks a disposition; the first migration wave and its blockers are concrete. Do not invent a universal “Python replacement” API list while ignoring the projects' actual libraries.

## 7. Phase P2 — Freeze a coherent scripting language contract

Dependencies: baseline frontend audit and G1 requirements. Deliver versioned language specification and conformance categories.

- [ ] Define the relationship between Elisa and Elisascript: shared grammar/features, scripting defaults, rejected constructs, and version compatibility. Separate library conveniences from language syntax.
- [ ] Specify source encoding, shebangs, indentation/tabs, newline handling, comments, identifiers, escapes, typed literals, interpolation, and precise source locations.
- [ ] Specify lexical scope, shadowing, forward references, imports, initialization order, visibility, overload resolution, generics, and module cycles.
- [ ] Specify evaluation order for operands, calls, named arguments, assignment targets, comparisons, short-circuit operators, comprehensions, matches, and interpolations.
- [ ] Decide closure capture semantics and callable types; specify mutation through captures, lifetime, ownership, and effects of higher-order calls.
- [ ] Define integers: fixed widths, checked arithmetic, shifts, division/remainder with negative operands, overflow, parsing, and explicit conversion rules. Add arbitrary-precision integers for Python/Perl workloads without silently widening fixed-width arithmetic.
- [ ] Define floats: rounding, NaN/infinity, signed zero, comparisons, formatting, parse round trips, and checked float-to-int conversion. Add decimal/rational types when inventory requires exact arithmetic.
- [ ] Define text versus bytes. Choose Unicode scalar/code-unit/grapheme APIs explicitly; existing byte-oriented text operations must be audited before claiming Python string parity.
- [ ] Define truth conditions: explicit booleans or a documented static protocol. Never adopt accidental runtime coercion from another language.
- [ ] Define equality, ordering, hashing, iteration order, mutation during iteration, and key admissibility for collections.
- [ ] Specify empty values and optional values separately from errors. Specify exhaustive matching and structured error handling with multiple variants and payloads.
- [ ] Define `can[...]` inference versus explicit public rows, row polymorphism, handler subtraction, and error propagation across functions/modules.
- [ ] Write a continuation policy decision record: `docs/continuation-policy.md` now records the default policy, tail versus ordinary resumption boundary, dynamic handler/reentrancy semantics, callback outcomes, escape restrictions, cancellation/cleanup, and budgets. Executed backend evidence and stable-profile enablement remain open.
- [ ] Review existing MultiReplay/MultiClone semantics against correctness-first constraints. Reject unsound captures even if this removes a previously accepted prototype behavior.
- [ ] Separate language semantics from operational limits. Identify which limits are configurable, platform-specific, or language-visible.
- [ ] Publish deliberate incompatibilities and porting idioms: tuples, numeric conversions, regex modes, byte/text handling, process statuses, and shell expansion.

Gate G2: every supported construct has an unambiguous contract and every important migration incompatibility has a documented typed alternative.

## 8. Phase P3 — Make frontend checking complete and trustworthy

Primary paths: `vendor/elisa-compiler/src/{lexer,parser,semantic}`, `src/ir/source.elisa`, `src/ir/source_file.elisa`, corresponding frontend tests.

- [ ] Build a feature matrix from parser acceptance through semantic checking and lowering. Reject unsupported executable constructs explicitly; never silently drop a statement or fabricate a default result.
- [ ] Consolidate compiler-known builtin signatures into a declarative typed registry shared by name resolution, inference, call checking, documentation, and lowering lookup where feasible.
- [ ] Preserve source shadowing and module qualification. Avoid recognizing a builtin from its spelling when a local callable or source declaration owns the name.
- [ ] Make nominal literals and their validation compositional; reject invalid encoding/NUL paths, malformed patterns, and inappropriate implicit conversions at the correct boundary.
- [ ] Ensure generic/container inference carries exact recursive descriptors, not only coarse “Container” categories. Cover method returns, indexing, higher-order calls, empty literals, and overloaded calls.
- [ ] Check builtin and method arity, argument names, duplicates, ordering, payload types, return types, effect rows, and error rows before execution.
- [ ] Type effect operations from declarations even when no handler is installed. An expected result type cannot be the sole authority for what an operation resumes with.
- [ ] Diagnose unhandled operations, missing capability grants, incompatible handler clauses, introduced effects, and error propagation across indirect calls.
- [ ] Complete definite assignment, mutation, borrowing, affine/linear usage, escape, and ownership checks for newly supported values and control flow.
- [ ] Implement exhaustive structured matches and multi-arm error recovery; define unreachable-arm diagnostics and evaluate the recovered expression only once.
- [ ] Stress error recovery with malformed indentation, truncated files, invalid UTF encodings, huge literals, deep nesting, and many errors; bound parser/diagnostic work.
- [ ] Improve diagnostics: original source path, span, caret, expected/actual type, related declaration, effect/error explanation, and actionable fix guidance.
- [ ] Produce deterministic structured diagnostics for tooling; retain human-readable output without exposing compiler internals as the only error message.
- [ ] Track general Elisa fixes upstream and scripting-specific passes locally; document every vendored semantic deviation.

Gate G3: negative programs are rejected consistently by the public loader, accepted programs have complete type/effect/error information, and unsupported behavior cannot slip through an Unknown inference result.

## 9. Phase P4 — Complete structural IR and value representation

Primary paths: `src/ir/{ir_model,type_table,lower_ast,ir_verify,serialize,runtime_model}.elisa`.

- [ ] Promote the recursive TypeTable to the authoritative type identity. During migration verify agreement with legacy inline fields; remove dual representations only after all consumers migrate.
- [ ] Support nested arrays, maps, sets, records, heterogeneous tuples, algebraic variants, optionals, callable values, and required recursive types without fixed-depth ad hoc fields.
- [ ] Define value layouts independently of host pointers; distinguish logical type identity from target layout and runtime handles.
- [ ] Add typed field/index/variant operations, construction, destructuring, exhaustive switches, and checked dynamic indexing with specified failures.
- [ ] Model closure environments, indirect calls, captured lifetimes, and ownership explicitly.
- [ ] Complete globals and module initialization: once-only initialization, ordering, failure propagation, recursion detection, cleanup, and deterministic shared-state behavior.
- [ ] Make moves, borrows, resource acquisition/release, and unwind obligations explicit enough for all backends to preserve.
- [ ] Verify SSA dominance, block argument arity/types, control targets, call signatures, globals, descriptor references, ownership state, handler balance, and every operand slice before execution.
- [ ] Harden all count arithmetic and index conversion against overflow and out-of-bounds access on malformed modules.
- [ ] Verify handler/error stacks across every CFG edge, including exceptional exits and joins with different nesting histories.
- [ ] Define versioned serialization and decoding for all structures. Validate lengths and recursion before allocating; reject unknown required features and truncated/trailing malformed data.
- [ ] Keep canonical byte identity deterministic. Use a cryptographic content digest for trust/cache identity; preserve the existing non-cryptographic fingerprint as correlation metadata only.
- [ ] Make optimizations preserve observable ordering, errors, cleanup, and effects; begin with simple rewrites validated against the interpreter.

Gate G4: supported source values have complete verified IR representations; malformed IR cannot cause unchecked memory access; serialization round trips preserve semantics and identity.

## 10. Phase P5 — Correct dynamic effects and resource lifetimes

Dependencies: G2 operation/continuation contract, G3 typing, G4 representation.

- [ ] Define typed effect-operation IDs and handler IDs independent of incidental function names. Support polymorphic operations only with explicit checking and representation rules.
- [ ] Represent a suspended computation as a runtime-owned stack/frame structure with explicit handler delimiters, caller state, error guards, cleanup obligations, and source provenance.
- [ ] Implement dynamic lookup and lexical installation correctly across nested calls, recursion, reentrant handlers, callback effects, and same-family shadowing.
- [ ] Implement the chosen default continuation policy exactly: zero resumes, one resume, duplicate resume, missing resume, resume after scope exit, and handler abort must all have defined results.
- [ ] If ordinary resumption is supported, execute callback code after resume correctly; if only tail resumption is supported initially, reject non-tail forms and document the limit.
- [ ] Specify introduced effects/error propagation and exact-operation coverage. A handler for one operation must not incorrectly discharge every operation in that family.
- [ ] Implement cleanup on success, recoverable error, abort, cancellation, timeout, return, break, and continue, including failures raised during cleanup.
- [ ] Establish a resource ledger for files, sockets, processes, locks, and temporary artifacts; ownership must prevent double close and use after close.
- [ ] For MultiClone, require recursively clone-safe captures; verified IR now rejects top-level array/map captures as `UnsafeMultiShot` while runtime legacy-descriptor checks remain fail-closed. Extend this to recursive descriptors and explicit clone protocols; reject aliases to mutable external state, borrowed/linear resources, and opaque handles unless sound cloning exists.
- [ ] For MultiReplay, define recording and replay of observations, mutable state, external I/O, clock, and randomness. A cloned SSA environment alone is not proof of replay safety.
- [ ] Test nested and recursive multi-shot use, handlers inside resumed continuations, partial replay failure, call-chain reconstruction, and cancellation during replay.
- [ ] Impose observable budgets on retained snapshots, resume count, trace growth, and recursion. Return structured exhaustion errors rather than leaking or hanging.
- [ ] Keep unsafe or unproven multi-shot forms experimental and unavailable in the stable profile until proofs and adversarial tests justify them.

Gate G5: dynamic handlers preserve static guarantees and resource cleanup under all exits; multi-shot capability is either soundly implemented or explicitly rejected for unsupported cases. Any restrictions still blocking an inventoried workflow remain open goal requirements.

## 11. Phase P6 — Runtime reliability and execution budgets

Status note: `RuntimeResourcePolicy` and `RuntimeResourceUsage` now define a
shared per-run budget shape for steps, optional elapsed time, memory, open
handles, processes, output bytes, regex work, retained traces, and concurrent
tasks. Reference-interpreter and direct-bytecode execution return the inherited
step policy and usage snapshot, and `scripts/check_resource_policy.sh` audits
the contract without launching a compiler. This is only the accounting
boundary: explicit `interpret_with_resource_policy`,
`execute_bytecode_with_resource_policy`, and strict direct-only counterparts
now admit a caller-owned policy and enforce its step budget; the bytecode loop
receives the retained-trace limit before `Observe` appends, and the interpreter
rejects retained observation traces above that policy; host-bridge
enforcement, nested-budget propagation, cancellation, wall-clock/memory
measurement, and
adverse-resource evidence remain required before the P6 checklist item can be
checked.

- [ ] Define runtime value ownership, arena boundaries, reclamation, aliasing, and mutation semantics. Prevent a long-running script from retaining every temporary value indefinitely.
- [ ] Audit all POSIX/FFI bridges for length, NUL termination, signedness, partial operations, EINTR, errno preservation, close failures, and host ABI assumptions.
- [ ] Distinguish script errors, host errors, invalid compiler output, cancellation, and limits. Keep original error payload/source when crossing runner and driver boundaries.
- [ ] Introduce a per-run resource policy: steps, elapsed time, memory, open handles, processes, output bytes, regex work, retained traces, and concurrent tasks.
- [ ] Carry accounting across calls, callbacks, nested runs, handlers, and replay; child work must not reset the parent budget silently.
- [ ] Make cancellation cooperative inside the VM and enforceable at blocking host boundaries. Add safe polling points without changing ordinary value semantics.
- [ ] Replace host-stack recursion with explicit frames where script depth could exhaust the host stack.
- [ ] Validate limit behavior at zero, one, exact boundary, and one-over; classify policy failures consistently across backends.
- [ ] Test repeated runs, large allocations, low-memory conditions, descriptor exhaustion, interrupted system calls, and cleanup after failure.
- [ ] Provide lightweight metrics and tracing that users can disable; avoid unbounded observability overhead.

Gate G6: supported programs terminate or can be cancelled predictably, release resources, and report operational failures accurately under sustained and adversarial use.

## 12. Phase P7 — Finish bytecode, then JIT/native execution

### P7a. Bytecode as the dependable scripting engine

- Status note: strict direct-bytecode rejection and `Execution.engine` identity are implemented in `src/bytecode/bytecode.elisa` and `src/ir/runtime_model.elisa` and covered by source fixtures, but remain statically reviewed only until the validation gate is reopened.
- [ ] Expose execution mode in user diagnostics and persisted test artifacts. Keep the strict direct-bytecode mode that rejects fallback, so differential tests can prove two distinct engines ran.
- [ ] Complete direct execution of globals, recursive values, closures, handlers, continuations, and error recovery on the same runtime contracts as the interpreter.
- [ ] Define explicit frames and operand storage with correct lifetimes; remove whole-module reconstruction where direct execution no longer needs it.
- [ ] Introduce a packed portable bytecode artifact only with a specified schema, verifier, feature negotiation, compiler identity, and corruption handling.
- [ ] Cache verified artifacts using content/dependency/toolchain/options identities; handle concurrent writers and interrupted writes atomically.
- [ ] Preserve breakpoints, source maps, trace IDs, and typed error stacks after packing or optimization.
- [ ] Measure cold startup, warm cache startup, instruction dispatch, allocations, and peak memory on the migration corpus.

Gate G7a: the stable language profile executes directly with parity; fallback remains explicitly labeled for experimental features and cannot count as independent backend evidence.

### P7b. Shared-IR native and LLVM JIT backends

- [ ] Audit reusable Elisa LLVM/EASM components and define the adapter boundary. Do not lower Elisascript AST directly into the copied backend.
- [ ] Specify target layout, runtime ABI, calling conventions, errors, closures, globals, dynamic handlers, stack maps, and cleanup.
- [ ] Bring up constants/control flow/calls first, then structural values, resources, effects, continuations, and optimization levels.
- [ ] For JIT, define executable memory ownership, code lifetime, cache invalidation, module unload, runtime symbol resolution, and thread safety.
- [ ] For native artifacts, implement runtime linking, dependency embedding/discovery, relocation, debug symbols, version checks, and reproducible builds.
- [ ] Validate debug and optimized builds against the same interpreter semantics; test optimizer interactions with effects, error paths, and replay.
- [ ] Add hot-path compilation only after measurements justify it; startup cost must remain suitable for small scripts.
- [ ] Keep WebAssembly as a separately tracked target with host capability adapters if required. It is not proof of POSIX process/filesystem parity.

Gate G7b: advertised JIT and native modes execute the supported profile with independent differential evidence. A stable VM release may precede this gate, but the agreed multi-backend objective remains open until delivered.

## 13. Phase P8 — Core standard library and Python-scale data handling

Library layout below is proposed, not an assertion that these directories exist. Establish `stdlib/` modules with a narrow compiler intrinsic boundary.

| Package | Required work | Acceptance examples |
|---|---|---|
| `core`, `collections` | Recursive typed arrays/maps/sets/tuples; iterators, slices, sorting with keys, stable ordering, grouping, counters, heaps, deques, copying and equality | Port grouping, deduplication, lookup, worklist, and sorting scripts without stringly types |
| `numbers`, `math` | Checked fixed-width arithmetic, BigInt, float contracts, conversions, rounding, statistics; exact decimal when required | Large integer calculations and edge-case parity with the declared numeric policy |
| `text`, `bytes`, `encoding` | Validated UTF-8, byte views, Unicode transformations, normalization, indexing policies, builders, binary parsing, explicit replacement/strict decoding | Non-ASCII names, combining marks, embedded NUL, malformed input, binary round trips |
| `iter`, `stream` | Lazy map/filter/fold/flat-map/chunk/window/zip, backpressure, cancellation, deterministic closing | Transform input larger than RAM with bounded working memory |
| `format`, `cli` | Stable formatting, typed argument parser, help, subcommands, completions, config/env precedence, human and machine output | Replace ordinary argparse-style project CLIs |
| `time`, `random` | Monotonic/wall clocks, durations, calendar/timezone needs, seeded RNG, explicit secure randomness | Deterministic tests and correct timeout calculations |
| `json`, `csv`, `toml` | Streaming decoding/encoding, typed schema conversion, errors with paths/offsets, stable output options | Round-trip configs and multi-gigabyte CSV/JSONL processing |
| `yaml`, `xml`, `binary` | Required format subsets and maintained adapters; XML entity/resource policy, YAML schema clarity | Match the actual config/data formats found in P1 |
| `hash`, `compression`, `archive` | Cryptographic hashes, base encodings, gzip/zstd as needed, tar/zip streaming and extraction policy | Checksums, release bundles, bounded extraction, reproducible archives |
| `database` | Typed SQLite and inventory-required drivers, transactions, prepared parameters, streaming rows | Port local metadata and report scripts without SQL string interpolation |
| `http`, `network` | See P11; typed requests and data decoding | Replace requests-like API tools with complete error handling |
| `testing` | Assertions, fixtures, generators, shrinking, differential execution, reports | First-party tests and real port validation use public APIs |

- [ ] For every API document complexity, allocation behavior, order, lifetime, effects, errors, cancellation, and serialization if relevant.
- [ ] Specify optional/default arguments without making the compiler maintain many inconsistent receiver/global aliases.
- [ ] Design ergonomic typed record decoding so external data does not force unchecked casts or hundreds of repetitive manual checks.
- [ ] Inventory numerical, plotting, scientific, and application-specific Python packages separately. Supply Elisa-native libraries or maintained typed foreign adapters where needed; do not claim those workflows are replaced merely because the base language runs.
- [ ] Declare third-party native dependencies, supported versions, build methods, licensing, and update responsibility.

Gate G8: the libraries required by the complete inventory exist and pass their contracts. A broad general-purpose core is delivered even when a particular early migration does not use every module.

## 14. Phase P9 — Filesystem, streaming I/O, and transactional edits

- [ ] Introduce typed owned file handles with explicit read/write/append modes and structured lifetimes. Define seekability, buffering, flushing, closing, and double-close behavior.
- [ ] Implement streaming byte/text reads, line/record iterators, chunked writes, partial-write recovery, and cancellation. Whole-file helpers should be convenient bounded wrappers.
- [ ] Preserve newline semantics explicitly: literal LF splitting, universal newline records, retained separators, CRLF, lone CR, trailing newline, empty file, and missing final newline.
- [ ] Define text encoding policy per stream; provide exact byte operations for invalid UTF-8 paths/content where supported by the OS.
- [ ] Implement metadata, permissions, timestamps, symlinks, hardlinks where needed, directory traversal, globbing, and predictable sort/iteration modes.
- [ ] Define cwd handling with per-invocation context where possible; concurrent code must not race on process-global directory changes.
- [ ] Implement atomic replacement using a sibling temporary file and rename; specify permissions, fsync/durability options, cleanup, and cross-filesystem failure.
- [ ] Support in-place transformation with backup policy and symlink behavior; do not truncate the input before transformation succeeds.
- [ ] Add file locking where workflows require coordination. Document advisory versus mandatory behavior and portability.
- [ ] Handle recursive copies/removal with deliberate symlink policy, cycle detection, depth/resource limits, partial-failure reports, and cancellation.
- [ ] Test long paths, empty names, inaccessible directories, missing parents, concurrent rename/removal, disk full, read-only filesystems, and broken links in isolated fixtures.

Gate G9: every file workflow can process large inputs safely, with predictable cleanup and no data loss on a failed transform.

## 15. Phase P10 — Shell replacement and process supervision

Primary paths: `src/runtime/process_posix.elisa`, interpreter/VM process operations, proposed `stdlib/process` and `stdlib/task`.

- [ ] Build typed command values: Executable, argv, cwd, environment policy, stdin source, stdout/stderr destinations, timeout, and cancellation. No implicit shell splitting or substitution.
- [ ] Distinguish spawn failure, normal exit, signal death, timeout, cancellation, output limit, and host I/O failure. Decide how script `main -> i64` maps to OS status ranges.
- [ ] Drain stdout and stderr concurrently while feeding stdin; prove absence of pipe deadlocks when all three exceed pipe capacity.
- [ ] Treat the current polling output ceiling as an interim containment layer. Replace or supplement it with an OS-enforced quota/isolated worker when the product requires a hard memory/output bound, and test the documented sampling overshoot.
- [ ] Support binary streams, inherited descriptors, files, captures, streaming callbacks, merged output, and explicit ordering guarantees. Separate stdout/stderr streams cannot promise an unknowable total order.
- [ ] Implement multi-stage pipelines with bounded buffers, per-stage status, configurable failure aggregation, early-consumer exit, SIGPIPE behavior, and complete child reaping.
- [ ] Implement process groups/sessions and cancellation escalation: cooperative signal, grace period, forced termination, descendants, reap. Scope all termination to the launched job.
- [ ] Provide background jobs, bounded parallel maps, fan-out/fan-in, deadlines, retries, and resource-aware scheduling with typed results/errors.
- [ ] Make environment inheritance explicit, including empty and unset values. Preserve argv with spaces, quotes, Unicode, empty strings, and leading dashes exactly.
- [ ] Define executable discovery and missing-command diagnostics without conflating a Path with an Executable.
- [ ] Map common shell idioms to typed APIs: redirection, append, tee, pipelines, command capture, traps/cleanup, file predicates, globs, loops, argument forwarding, and exit checking.
- [ ] Provide task/build graphs with dependencies, failure propagation, incremental fingerprints, parallelism, and logs for workflows currently in shell recipes.
- [ ] Evaluate terminal/PTY, interactive subprocesses, and signal forwarding against inventory; implement them where required rather than leaving interactive workflows permanently in shell.
- [ ] Document shell semantics intentionally not inherited: word splitting, implicit globbing, `set -e` surprises, eval, and environment leakage.

Gate G10: build/test orchestration and process-heavy corpus scripts are fully ported with exact required I/O, status, and cancellation behavior; no embedded shell program is doing the orchestration.

## 16. Phase P11 — Perl/AWK-grade text and record processing

### Regex contract and implementation

- [ ] Inventory patterns before choosing the stable engine/dialect. Document literal versus runtime compilation, Unicode mode, byte mode, multiline/dotall, anchors, captures, and replacement syntax.
- [ ] Audit the current interpreter regex implementation and work accounting. A backtracking implementation needs an explicit budget and adversarial complexity tests.
- [ ] Implement a predictable core dialect with bounded matching behavior where possible. If inventory requires backreferences/lookbehind or other expensive features, expose their capabilities and costs explicitly.
- [ ] Define compilation errors and source offsets. Compile literal patterns early; dynamic patterns produce typed errors and can be cached under a bounded policy.
- [ ] Provide typed Match, Capture, span, named-capture lookup, optional unmatched groups, find-all iteration, anchored match, full match, substitution, count, and split.
- [ ] Implement zero-width progress correctly for empty patterns, repeated matches, end anchors, Unicode boundaries, split, and global replacement.
- [ ] Support replacement functions and literal replacement quoting. Avoid interpreting user text as replacement syntax accidentally.
- [ ] Validate greediness, alternation ordering, nested groups, escapes, character classes, flags, and Unicode tables against the chosen contract and applicable Perl/Python references.

### Record and field engine

- [ ] Introduce a typed record stream with input source, record number, file-local record number, filename, byte offset, and raw record data.
- [ ] Support literal/regex record separators, line records, paragraph/multiline modes where required, and final partial records.
- [ ] Support whitespace, literal, regex, fixed-width, and schema-based field extraction. CSV quoting is a format parser, not regex field splitting.
- [ ] Define field numbering, missing fields, numeric parsing, field mutation, record reconstruction, output separators, and formatting explicitly.
- [ ] Provide begin/per-file/per-record/end lifecycle hooks using existing Elisa functions/state machines where possible. Specify behavior on early exit or failure.
- [ ] Support pattern-action filtering, ranges of records, next-record/next-file controls, grouping, keyed aggregation, counting, joins, rolling windows, and sorting.
- [ ] Add external sort/spill-to-disk aggregation when input cardinality can exceed RAM. Include cleanup and disk-space accounting.
- [ ] Offer concise CLI use and reusable modules; assess whether an expression mode improves one-liners without creating a second weakly typed language.
- [ ] Implement transactional in-place substitution through P9 APIs and safe multi-file traversal.
- [ ] Benchmark large logs, many tiny files, Unicode records, long single records, pathological regexes, and high-cardinality aggregation.

Gate G11: representative Perl/AWK scripts remain concise and streaming, have complete documented match/record semantics, and produce reference-equivalent results under bounded resources.

## 17. Phase P12 — Network, concurrency, and service-facing scripts

- [ ] Define socket/TLS/HTTP capability boundaries and typed errors for name resolution, connection, handshake, timeout, protocol, status policy, and decoding.
- [ ] Implement streaming requests/responses, redirects, headers, cookies where needed, multipart, compression, proxy configuration, and cancellation.
- [ ] Distinguish HTTP non-success status from transport failure. Require explicit retry policy for non-idempotent operations; honor backoff/deadlines.
- [ ] Validate TLS certificates/hostnames using a maintained implementation; provide test certificate roots and deterministic local test servers.
- [ ] Use monotonic deadlines and structured task scopes. Define child failure propagation, cancellation shielding for cleanup, and join behavior.
- [ ] Add typed channels/queues, bounded concurrency, and backpressure; prevent unbounded spawning and buffer growth.
- [ ] Define transfer safety for values and handler contexts across tasks; borrowed and linear resources must retain valid ownership.
- [ ] Provide deterministic scheduler/clock/network adapters for tests where possible, while acknowledging that effect rows alone are not an OS security sandbox.
- [ ] Address platform-specific event loops and blocking adapters without freezing the entire runtime on one slow process or socket.
- [ ] Port inventory-required API clients and integration tools with recorded/synthetic responses before any live mutation.

Gate G12: network and concurrent workflows handle failures, cancellation, retries, and resource usage predictably, with no dependency on an old scripting interpreter.

## 18. Phase P13 — Differential testing as a first-class product

Primary starting point: `src/testing/differential.elisa`, `docs/differential-testing.md`, and differential test fixtures. The document's proposed APIs and artifact layout require implementation evidence individually.

- [ ] Define a Case containing reference/candidate runners, input schema, observation schema, world, comparator, limits, seeds, and artifact policy.
- [ ] Support external Python/Perl/AWK/C/C++/Elisa executables as references, and interpreter/direct bytecode/JIT/AOT candidates. Build commands and compiler identities must be explicit and reproducible.
- [ ] Preserve compile failure, spawn failure, crash, timeout, normal error, and behavioral mismatch as distinct outcomes; do not report infrastructure failure as equivalence.
- [ ] Materialize separate equivalent fixture worlds for both sides: cwd, files, permissions, stdin, argv, selected environment, locale, timezone, seeds, and dependency identities.
- [ ] Prevent order contamination: reset/snapshot world state and verify that swapping reference/candidate execution order does not change comparison outcomes.
- [ ] Compare return/status, typed errors and payloads, stdout/stderr bytes, observations, file trees, and resource cleanup according to the case contract.
- [ ] Default to exact comparisons; enable float tolerances, canonicalization, unordered collections, path rewriting, and timestamp normalization only explicitly. Record all policies in artifacts.
- [ ] Define NaN, infinities, signed zero, absolute/relative tolerance combination, map ordering, binary values, and nested type identity in the comparator.
- [ ] Produce cryptographically identified artifacts containing inputs, outputs, differences, source and executable identities, compiler/backend options, world configuration, seeds, logs, and a reproduction entry point.
- [ ] Version and validate artifact manifests; handle incomplete artifact writes atomically. Restrict environment capture to necessary fields and permit explicit secret redaction.
- [ ] Implement deterministic generators and shrinking that preserve input validity and the same mismatch category. Record shrink steps, budgets, and the minimality criterion.
- [ ] Implement stateful sequences, lockstep execution, checkpoints, first-divergence localization, and trace windows for emulators, parsers, compilers, and protocol ports.
- [ ] Handle nondeterminism explicitly: repeat policies, allowed variability, flaky classification, and schedule seeds. Never normalize away an unexplained difference.
- [ ] Add human reports plus stable JSON/JUnit-style CI output and machine-readable failure categories.
- [ ] Use the public harness for Elisascript backend comparisons; include negative programs and errors, not only successful scalar results.
- [ ] Prove backend independence with forced modes and execution identity; interpreter fallback must not create a false parity pass.

Gate G13: a deliberately introduced mismatch in a real port yields a self-contained artifact that reproduces on a fresh qualified environment and shrinks without losing the original failure meaning.

## 19. Phase P14 — Modules, packages, CLI, and developer experience

- [ ] Implement a public launcher with run/check/test/fmt/doc/version/help modes and a deliberate option boundary before script arguments. Document any proposed short executable alias separately.
- [ ] Preserve source, semantic, lowering, verifier, and runtime diagnostics through the driver. Replace generic “non-integer status” reporting when the underlying failure was actually compilation or execution.
- [ ] Provide stable process exit conventions for usage, source errors, test failures, script errors, cancellation, and successful user statuses.
- [ ] Implement module resolution relative to module/package roots, canonical identity, cycle diagnostics, visibility, reproducible dependency graphs, and source maps across files.
- [ ] Define package manifests, lockfiles, version constraints, offline builds, dependency integrity, cache invalidation, and native dependency declarations.
- [ ] Support local/workspace packages and a coherent publishing/install workflow. A registry can be staged, but required distribution workflows must not depend on ad hoc path copying.
- [ ] Provide formatting, syntax highlighting, language-server diagnostics, completion, go-to-definition, rename, hover types/effects/errors, and documentation navigation.
- [ ] Add debugger support for source breakpoints, step/continue, stack inspection, variables, errors, and handler/continuation context. Make replay branches visible in traces.
- [ ] Add profiling for startup, compilation, allocations, regex work, I/O waits, and effect dispatch; expose enough evidence to fix performance bottlenecks.
- [ ] Design REPL/expression mode around the same typed frontend and runtime; preserve explicit state and error semantics between evaluations.
- [ ] Write language introduction, typed scripting cookbook, shell/Python/Perl/AWK migration guides, differential-testing guide, and API reference from reviewed signatures.
- [ ] Supply templates for a one-file script, multi-module tool, test suite, process pipeline, streaming transform, and differential case.

Gate G14: a fresh user can install, write, check, debug, test, package, and run a useful script using documented tools and actionable diagnostics.

## 20. Phase P15 — Self-hosting, portability, and reproducible delivery

- [ ] Establish the supported platform matrix from actual hosts. Start with the current macOS/architecture environment and add Linux/Windows/other targets according to inventory; do not claim untested portability.
- [ ] Separate platform-independent runtime contracts from POSIX and other host adapters. Specify path representation, executable lookup, permissions, signals, terminal behavior, and filesystem differences.
- [ ] Ensure compiler/VM/first-party libraries are built from Elisa source in a clean environment with pinned dependencies and a documented minimal bootstrap artifact.
- [ ] Demonstrate a second-generation rebuild: bootstrap builds toolchain A, A builds B, B builds/runs the conformance corpus. Compare outputs semantically and bitwise where determinism permits.
- [ ] Replace first-party shell/Python/Perl/AWK build and test orchestration with Elisascript once the necessary facilities exist; retain only an explicitly justified irreducible bootstrap mechanism.
- [ ] Make release artifacts relocatable, versioned, checksummed, signed where applicable, and installable without a development checkout or legacy interpreter.
- [ ] Define update/rollback behavior, runtime/artifact compatibility, and offline installation.
- [ ] Audit vendored dependencies, licenses, exported ABI, and update cadence; track the upstream Elisa revision and refresh procedure.
- [ ] Build/test every declared target with a recorded toolchain and reproducible configuration.

Gate G15: fresh supported machines can obtain and rebuild/run Elisascript reproducibly, and first-party development workflows are dogfooded in Elisascript.

## 21. Phase P16 — Reliability, conformance, and performance qualification

### Test layers

| Layer | Required evidence |
|---|---|
| Lexer/parser | Golden source/spans, round trips where meaningful, invalid-source recovery, bounded fuzzing |
| Static checking | Positive and negative typing, effects/errors, ownership, shadowing, generics, operation declarations |
| IR | Valid construction plus malicious/malformed operands, descriptors, CFG, handlers, and serialized artifacts |
| Interpreter | All value and control contracts, deterministic traces, errors, cleanup, and budgets |
| Direct bytecode/JIT/AOT | Forced execution mode, parity with independent reference, optimized/unoptimized comparisons |
| Runtime adapters | Partial I/O, interrupted calls, process floods, cancellation, disk/descriptor/memory exhaustion |
| Libraries | Published contract, randomized inputs, large inputs, encoding boundaries, known-format conformance |
| Differential product | Injected mismatches, crash/timeout classification, artifact replay, shrinking, nondeterminism |
| End-to-end | Fresh install, real CLI invocations, package resolution, complete migrated workflows |
| Long-running | Resource plateau, many invocations, concurrent jobs, repeated cancellation, sustained record streams |

- [ ] Create a grammar/type-directed generator for valid programs and targeted invalid programs. Preserve seeds and minimized failures.
- [ ] Fuzz parser, regex compiler/matcher, structured data decoders, artifact decoder, verifier, and protocol adapters independently with bounded resources.
- [ ] Use metamorphic properties: serialization round trip, pure expression equivalence, chunked/whole-stream equivalence under the same contract, and compilation-mode invariance.
- [ ] Test every cross-layer feature interaction: errors inside handlers, cancellation during pipeline I/O, cleanup after replay, nested aggregates across calls, and module globals under concurrency.
- [ ] Record platform/compiler/optimization coverage and prevent “skipped” or fallback cases from appearing as supported passes.
- [ ] Define representative performance baselines per workflow: cold latency, warm latency, throughput, memory, compile time, file descriptors, child count, and binary/cache size.
- [ ] Agree numeric budgets from measurements before optimization work. Include tail latency and worst important case, not only aggregate means.
- [ ] Optimize measured bottlenecks while preserving contracts. Verify regex complexity, streaming memory proportionality, and compilation scaling.
- [ ] Add soak and cancellation schedules with agreed duration and run count; retain resource trends and failure artifacts.
- [ ] Run a clean release qualification against the exact release candidate. Any relevant fix requires rerunning affected gates plus dependency-sensitive integration checks.

Gate G16: zero unresolved release-blocking correctness defects; all promised capabilities qualified; meaningful performance budgets met; reproducibility and resource behavior demonstrated.

## 22. Phase P17 — Migrate projects and remove old production paths

For each inventory entry, follow this lifecycle:

1. Freeze the reference contract, fixtures, dependency versions, and safe execution environment.
2. Identify semantic differences explicitly: encoding, arithmetic, ordering, regex, status, locale, timestamps, and mutable external state.
3. Implement an idiomatic typed Elisascript port using public libraries. Missing capabilities become library/compiler work, not hidden legacy-language calls.
4. Run exact or explicitly configured differential comparisons over fixtures, generated edge cases, and representative production-size inputs.
5. Validate failures and operational behavior: missing files, permission errors, malformed input, partial network failures, cancellation, and interrupted writes.
6. Compare performance and ergonomics. Simplify repetitive port code by improving typed APIs rather than weakening checks.
7. Update callers, CI recipes, docs, package commands, shebangs, and editor tasks in a reviewed migration change.
8. Run both versions in a controlled observation period when appropriate; prevent duplicate external side effects.
9. Switch the production entry point with a recoverable rollback path. Retain legacy source as a test oracle or archived history when useful.
10. Remove the old production runtime dependency only after dependency scans and clean-environment runs prove it unnecessary.
11. Record accepted evidence and close the inventory entry. Update every downstream workflow that used the old entry point.

Migration waves:

- Wave A: pure text/data transformations, argument utilities, generated-file helpers, deterministic local checks.
- Wave B: file operations, build/test orchestration, pipelines, bounded parallel tools, log/record processing.
- Wave C: network/database/package/release tools, complex dependencies, large inputs, concurrent supervision.
- Wave D: remaining ecosystem-specific programs, interactive tools, all first-party bootstrap/test/release orchestration.

Gate G17: every production inventory entry is migrated or has an explicitly agreed exclusion; no unresolved required exclusion can be counted as full completion. Fresh environments without the old scripting runtimes run all migrated production workflows.

## 23. Phase P18 — Stable release and maintenance

- [ ] Publish a supported language/library/backend/platform matrix with evidence, known limitations, and version policy.
- [ ] Freeze stable syntax, errors, effect identities, library APIs, package behavior, and artifact compatibility rules. Experimental features must be visibly separated.
- [ ] Define deprecation windows, migration tooling, compatibility fixtures, security/bug response, and patch-release criteria.
- [ ] Run release candidate qualification, installation/upgrade/rollback checks, and the full project migration corpus.
- [ ] Observe real usage for an agreed interval and workflow count; resolve crashes, data corruption, hangs, unsound typing, and major regressions before stable promotion.
- [ ] Make every discovered production bug a minimized regression case, ideally through the public differential framework.
- [ ] Maintain upstream Elisa compatibility and local patch provenance; avoid unreviewed bulk vendor refreshes.
- [ ] Reaudit the scripting inventory after adoption so newly introduced legacy-language dependencies are visible.

Final gate G18: G0–G17 obligations applicable to the agreed full goal are proven, no required feature remains hidden behind an experimental label, and stability is supported by release and production evidence.

## 24. Dependency order and practical sequencing

Critical correctness path: P0 validation recovery → P2 language contract → P3 static checking → P4 structural IR → P5 effects/lifetimes → P6 reliable runtime → P7a complete VM.

Practical replacement path: P1 inventory → P8 libraries + P9 files + P10 processes + P11 record/regex tools → P12 network/concurrency as required → P13 differential acceptance → P17 migration.

Delivery path: P14 developer tools + P15 bootstrap/portability → P16 qualification → P18 stable release. P7b JIT/native progresses after the shared contracts are stable and joins backend qualification before those modes are declared complete.

Useful independent work includes inventory, contract writing, diagnostics design, library schemas, and static audits while validation remains suspended. Parallel execution is subject to explicit collaboration authorization and host resource limits; independent tasks do not justify concurrent compiler loops.

Do not put calendar estimates on phases until P1 provides workload scope and P0 provides compilation/test feedback costs. Estimate vertical slices, record actual time and blockers, and revise priorities based on migration value.

## 25. Immediate implementation queue

These are concrete next actions, not authorization to execute prohibited validation or change another repository.

- [ ] Q01: Re-audit the committed Path line/append increment; verify newline and append boundaries, wrong receivers, empty collections, exact element types, temporary receivers, effects/errors, and fixture expectations. Static lowering now contextually types empty line arrays, and semantic structural rows distinguish `darray[sview]` from `darray[u8]` (`6567080`); static fixtures cover temporary receivers, named-argument rejection, and interpreter/direct-bytecode recovery from empty or embedded-NUL paths (`a2527cf`). Execution evidence is still required.
- [ ] Q02: Persist the `BytecodeCapabilityReport` beside each backend artifact and record the current direct-bytecode versus fallback capability matrix from `bytecode_direct_supported` and direct dispatch. The report API, strict entrypoint, engine identity, backend-neutral capability snapshot propagation (`83051d9`), fingerprint- and SHA-256-bound `BytecodeArtifact` metadata, deterministic version-2 `ESBC` metadata encoding, allocation-free envelope/metadata validation, allocation-free borrowed metadata decoding, and aligned writer/reader admission with a 64 KiB whole-envelope bound now exist; version-1 unbound envelopes are rejected pending explicit cache migration. `bytecode_artifact_envelope_status` and `bytecode_artifact_requires_migration` now classify the known legacy envelope separately from malformed current metadata, so a future cache can migrate deliberately without weakening fail-closed admission. Validation at every cache boundary, all backend adapters, and forced-mode execution evidence are still required before reporting new backend parity. The validator now rejects capability counters that cannot round-trip through the host `usize`, keeping cache admission and decoding consistent on 32-bit targets. Keep the decoder's borrowed text views tied to the input byte storage, reject malformed envelopes before pointer construction, and add cache read/write/restart/corruption tests before treating this as artifact compatibility.
- [ ] Q02a: Carry the target-independent bounds invariant through every serialized IR and bytecode reader. The verifier now saturates block, edge, operand, and interned type-table child ranges before diagnostic iteration (`350b935`); public type-table readers fail closed (`4bba9f6`), and canonical bytes/fingerprints preserve non-empty malformed child pools instead of omitting them (`477d073`). The shared public `runtime_bounded_slice_end` helper now applies checked subtraction-before-addition to ESIA, ESBC, and all differential artifact text readers, while fixed-width ESPS/ESVP/ESCR lookahead checks use subtraction admission (`1d96bfa`). `scripts/check_serialization_bounds.sh` and IR/differential boundary/known-vector fixtures audit the invariant. A bounded portable SHA-256 primitive now covers canonical bytes, and version-2 digest-bound ESIA/ESBC plus digest-aware ESDF version-4 metadata bind all four digest words; ESIA/ESBC legacy status predicates and ESDF digest-upgrade detection now expose explicit migration signals while keeping malformed bytes invalid. ESIA/ESBC metadata writers and readers also reject embedded NUL bytes before host-string boundaries. Legacy cache/manifest migration, every future packed reader, and malformed-module execution evidence remain open. Artifact/cache decoders must use the same pattern and must never inspect a child or operand before validation.
- [ ] Q03: Audit builtin typing across source symbols, receiver dispatch, inference, lowering, and verifier. The shared namespaced `EsBuiltin` registry (`vendor/elisa-compiler/src/semantic/builtin_registry.elisa`) now covers 37 global scalar/text/regex facades with receiver category, fixed arity, canonical argument-type descriptors, return type, effects, errors, and IR opcode metadata; seeded semantic symbols preserve the full row; global typed lowering uses one registry-backed arity/named-argument gate; and receiver-aware `Text` and `Regex` families cover text transforms/predicates, aggregate text results, reusable matching/capture/split/substitution, and source-shadowing precedence. The global `strip`/`trim`/`lstrip`/`rstrip` aliases share `TrimText` with explicit both/left/right mode metadata. Fixed global text aggregate aliases are registry-driven, global `split` carries an explicit named-argument slot for `maxsplit` distinct from the receiver method slot (`b15968c`), and global `join` carries a structural `darray[text],text` descriptor checked through the interned type table (`5a57864`). Semantic unknown-method admission, direct-call inference, structural result inference, receiver diagnostics, and lowerer shape checks consume the same registry while preserving compatibility fallbacks for unmigrated collection/path methods. The old duplicate `contains` and untyped capture-regex seeds were removed; `scripts/check_builtin_registry.sh` verifies all global/receiver rows, lowerer branches, opcode names, verifier coverage, argument metadata, semantic preservation, receiver admission, source-shadowing, inference, arity/argument/named-call checking, and structural result consumers. Keep this item open until remaining text methods, aggregate/variadic signatures, generic/container descriptors, structured effect/error IDs, verifier compatibility, recursive inference, richer capture-group descriptors, and runtime evidence are complete; add negative fixtures and execution evidence only after compiler validation is explicitly reauthorized.
- [ ] Q03a: Preserve builtin precedence boundaries. Registry-backed Text diagnostics and lowerer dispatch now require that no direct source function owns the method name, and normalized qualified builtins apply the same guard to their normalized callable name. Generic UFCS lowering for a shadowing source function remains open; compiler validation is deferred until the resource-safety gate is reauthorized.
- [ ] Q03b: Extend registry argument descriptors through the existing interned type table. `Text.join` now rejects firm annotated `darray`/`array` arguments whose element row is not text while retaining conservative behavior for unknown expressions and untyped array literals; full recursive container inference and literal element checking remain open.
- [ ] Q03c: Preserve registry aggregate result descriptors through structural inference. Text split, line-split, and partition methods now recover the canonical `darray[sview]` TypeId when available, so indexed results and subsequent `Text.join` checks retain text element identity; recursive inference for uninterned literals and generic containers remains open.
- [ ] Q03d: Keep source-shadowing checks distinct from builtin seed symbols. Registry rows seeded at line zero are ambient contracts, not user declarations; receiver diagnostics and structural result inference must ignore those rows while honoring a collected source function with a nonzero declaration line. Generic UFCS lowering remains open.
- [ ] Q03e: Apply registry metadata to global semantic calls. The 37 typed global rows now receive arity, named-argument, and conservative scalar/text/collection descriptor checks before lowering, while unknown expressions remain unflagged and source functions shadow line-zero seeds; aggregate/generic descriptors and execution evidence remain open. Global trim aliases are seeded through the same registry loop and preserve their lowerer mode metadata; global `split` accepts `maxsplit` only at its explicit third-argument slot, and global `join` checks declared text-array element identity through the interned type table.
- [ ] Q03f: Apply source-shadowing precedence to receiver inference as well as semantic checking and lowering. Registry rows and legacy Text return fallbacks now require a real source-declaration absence, ignoring line-zero seed symbols; generic UFCS inference and execution evidence remain open.
- [ ] Q03g: Extend source-shadowing precedence to regex receivers. Lowering and return-type inference now guard `search`, `match`, `fullmatch`, find/capture aliases, `split`, and `sub` against source callables; the nine Regex receiver spellings now have namespaced registry rows for arity, text arguments, result shape, and opcode, with semantic diagnostics, structural result inference, lowerer call-shape checks, and compiler-free audit coverage. Generic UFCS resolution, richer capture-group descriptors, and execution evidence remain open.
- [ ] Q03h: Registry-drive the canonical global regex facades. `matches`, `replace_regex`, `split_regex`, `find_regex`, `capture_regex`, and `captures_regex` now carry typed text/Regex argument contracts, registry-backed lowerer shape/result metadata, semantic Regex checks, and structural `darray[text]` result recovery; richer capture-group element descriptors and execution evidence remain open.
- [ ] Q04: Audit effect declaration payload/resumption types and handler coverage subtraction, then prioritize any soundness gap before additional syntax conveniences. Dynamic handler coverage is now operation-aware: clause-bearing handlers forward unmatched operations to outer handlers while empty-clause handlers remain explicit family masks; lowerer, verifier, and runtime dispatch agree (`7cb64f0`, `1832f96`). Duplicate source operation names are rejected because dispatch identity is `(family, operation)` (`e8f683a`), operation metadata carries token columns for precise diagnostics (`7beb87a`), externally assembled handlers reject empty or repeated coverage metadata (`4fb3b51`), unknown continuation-policy ordinals fail verifier/runtime closed (`7dae8ff`), and the parser now preserves borrowed payload-list/result-type source spans through semantic operation lookup (`cae711b`) with a compiler-free bridge audit. Bare primitive/nominal result spans and one-positional-payload bare types now constrain value-producing `perform` and statement `signal` during lowering (`d9a4d7b`, `56f4b28`, `eb201b0`); lowering now also rejects exact payload-arity mismatches for source-declared operations while leaving builtin/open families extensible (`7c8aeb7`). Generic/structural and multi-parameter type spans remain conservative. Resolve all spans into typed operation/resumption IDs and add declaration/handler conformance checks; payload/resumption execution evidence remains open.
- [ ] Q04a: Extend the handler contract audit to callback-owned `can[...]` effects and `error[...]` rows. The verifier must require callback effects to be covered by the active operation-aware handler stack or the enclosing function row, and callback errors to appear in the enclosing function row; do not let executable clauses create an implicit untyped call boundary. The verifier and regression fixture now enforce this (`a7b9ac9`); execution evidence and callback payload/resumption declaration audits remain open.
- [ ] Q05: Audit TypeTable consumers and define the migration to heterogeneous tuples/records/variants, with one end-to-end structural-value slice first.
- [ ] Q06: Design typed streaming file handles and scoped cleanup, then implement an error-safe line iterator as the first large-file vertical slice.
- [ ] Q07: Audit process capture for simultaneous stdin/stdout/stderr progress, timeout behavior, descendant cleanup, exact status reporting, and the documented polling/output-limit overshoot. Private groups, bounded capture, paired post-exit stream cleanup (`dbd3c9f`), parent-side failure termination/reaping (`23937ae`), interpreter wait-failure termination/reaping (`58dd4a5`), empty-executable defense-in-depth (`1b4abee`), duplicate host-supplied environment-key rejection before fork (`dbcf9ea`), `=`-name rejection across process and global environment host boundaries (`33117cb`), and independent stdout/stderr limit checks (`609abeb`) exist; deadlock and adverse-resource execution evidence is still required.
- [ ] Q08: Inventory real project scripts with a read-only report and choose representative migration acceptance cases. A bounded current-repository scan records 9 shell candidates, 8 executable-file signals, 9 legacy-shebang signals, 7 inline Python/Perl/AWK signals, and five representative workflow contracts in `docs/migration-inventory-current.md`; no candidate is executed. `docs/migration-project-roots.tsv` plus `scripts/inventory_project_roots.sh` now provide a partitioned, fail-closed coordinator that runs the bounded candidate/signal scanners per declared root, preserves owner/review metadata, and treats candidate filename traversal, signal traversal, and content-search errors as failures rather than silently dropping rows. Per-file owner/disposition review, generated/vendored classification, accepted ports, and representative cases across all roots remain open.
- [ ] Q09: Implement a complete differential artifact/reproduce slice for one real port, including wrong output, crash, timeout, and controlled filesystem fixtures.
- [ ] Q10: Extend the committed phase-aware launcher diagnostics to preserve exact error variants and source spans. The launcher now preserves source, entrypoint, and runtime error variants (`1db8595`), token-backed parser failures carry end coordinates (`519775d`), source effect operation metadata carries token columns for duplicate-operation diagnostics (`7beb87a`), source lowering retains the first `LowerIssueKind` and line (`bd2161f`), the bytecode phase retains the first verifier `IssueKind` plus numeric block/value/trace identifiers (`806c352`), and the source phase now retains the first parser or semantic diagnostic kind, bounded coordinates, deterministic payload hash, bounded owned text/count fields, parser context, and a bounded source-line caret excerpt (`aa63e90`, `4a9c864`, `277ce56`). The runner now exposes a versioned fingerprint and structural equality operation over the complete host-visible diagnostic record (`621def7`, `1e92a3e`), a compiler-free field-coverage guard keeps future fields synchronized (`cf379e8`), and fixtures cover source/entrypoint/bytecode/lowering/runtime variants (`c7b167a`). Exact external snapshots and execution evidence remain open; the excerpt is capped at 1024 bytes per line/caret component, sets the truncation flag for clipped or multi-line spans, and never replaces the authoritative numeric coordinates.
- [ ] Q11: Demonstrate watchdog behavior and request reauthorization only when the validation setup is concrete and reviewable. Keep all compiler launches disabled until then.
- [ ] Q12: After authorized qualification, commit each reviewed implementation slice with evidence and update the capability ledger.
- [ ] Q13: Keep differential snapshot adapters fail-closed on malformed offsets and lengths. Runtime-to-owned conversion and owned comparison now validate array ranges with checked subtraction (`5076a9a`) and owned-map comparison shares the same checked-subtraction predicate with dedicated malformed-map fixtures (`f24b1f3`); add equivalent record/byte-buffer checks whenever new snapshot kinds are introduced, and cover all malformed forms with structured mismatch/error fixtures before execution evidence is collected.
- [ ] Q14: Migrate the remaining global POSIX bridge declarations into the qualified `EsRuntime` namespace. Preserve `elisascript_posix_*` link names as private implementation symbols, expose only typed host operations from explicit public sections, add `using EsRuntime` at the IR boundary, and audit every include/call site for collisions before changing visibility. Static implementation is present in `312624e`; the namespace audit now verifies private ABI sections and rejects leaked `_impl` calls; compiler/build evidence and non-POSIX adapter qualification remain open.

## 26. Cross-cutting risk register

| Risk | Detection | Required response |
|---|---|---|
| Compiler memory growth prevents feedback | RSS/time trends by small fixture and revision | Minimize compiler repro, fix upstream/local compiler in isolation, retain guard |
| Parser acceptance mistaken for support | Source-to-execution feature matrix | Reject unsupported cases or complete all layers |
| Coarse inference masks type mismatch | Negative tests for nested/receiver/polymorphic values | Preserve exact descriptors and declaration-authoritative signatures |
| Multi-shot duplicates external side effects | Adversarial capture/replay tests | Enforce policy, record/replay worlds, reject unsound forms |
| Backend parity compares one engine twice | Forced modes and recorded engine identity | Fail on fallback during independent parity qualification |
| Whole-file APIs fail large workloads | Corpus input sizes and memory trends | Streaming handles, backpressure, external aggregation |
| Regex stalls on adversarial input | Complexity corpus and match budget telemetry | Bounded engine/work, explicit expensive features, cancellation |
| Process pipeline deadlocks/leaks | Pipe-saturation and cancellation tests | Concurrent I/O progress, explicit ownership, complete reaping |
| Unicode/number mismatches invalidate ports | Cross-language edge-case corpus | Explicit contracts and adapters; no blanket normalization |
| Python library dependency remains hidden | Import/command scans and clean environments | Maintained native/typed adapter or mark workflow incomplete |
| More aliases amplify compiler complexity | Signature drift and duplicate dispatch changes | Public library design and shared builtin registry |
| Documentation overstates readiness | Capability ledger vs run artifacts | Downgrade status until end-to-end evidence exists |
| Existing work accidentally committed | Exact staged diff review | Commit only scoped completed changes |
| Local plan treated as proof of progress | Artifact and revision audit | Require implementation and executed evidence per gate |

## 27. Requirement traceability and final audit

| User requirement | Work packages | Completion evidence |
|---|---|---|
| Elisa syntax and Elisa implementation | P2, P3, P14, P15 | Grammar conformance, source/bootstrap audit, documented deviations |
| Extremely strong static typing | P2–P5 | Negative conformance, exact IR descriptors, ownership/effect/error checking |
| Dynamic handlers, correctness before flexibility | P2, P5, P6 | Nested/recursive/error/cancellation conformance and capture restrictions |
| `error[...]` rather than Result-style language API | P2, P3, P5, P8, P14 | Public signatures, propagation tests, payload-preserving diagnostics |
| State-machine-oriented control flow | P4–P7, P10–P12 | Explicit protocol states/transitions and transition coverage |
| Shared IR for VM/JIT/native | P4, P7 | Verified shared input, forced engine identity, independent parity |
| Python replacement | P1, P8–P10, P12, P14, P17 | Complete library/workflow inventory and accepted ports |
| Shell replacement | P9, P10, P14, P15, P17 | Exact argv/I/O/status tests and no production shell evaluation |
| Perl/AWK replacement | P8, P9, P11, P17 | Regex/record contracts, streaming corpus, accepted ports |
| Excellent differential testing | P13, P16, P17 | Real reproducible mismatches, shrinking, lockstep, backend comparisons |
| `.elisascript` extension | P3, P14, P15 | Loader, launcher, shebang/editor/package/install evidence |
| Local isolated compiler work | P0, P15 | Pinned toolchain provenance, independent outputs, demonstrated guard |
| Commit implementation gains | All implementation phases | Coherent commits with verification notes; ignored plan remains local |
| Completely stable final system | P16–P18 | Full gate audit, fresh installs, migration corpus, production observation |

For final completion, inspect the exact release revision and all required artifacts. Each requirement must be classified as proven, contradicted, incomplete, or evidence missing. Treat unexecuted tests, stale logs, fallback execution, partial platform coverage, and undocumented exceptions as missing proof. Resolve every required open item before declaring the full goal achieved.
### P13 differential-case increment (static, compiler validation suspended)

`EsDifferential` now has a typed `DifferentialCase` boundary binding reference and
candidate runners to a hermetic `DifferentialWorld` (fixture files, cwd, ordered
environment, argv, stdin, locale/timezone, and seed), plus explicit comparator,
engine, timeout/output, and artifact policies. `validate_differential_case`
validates both nested runner contracts and rejects NULs, duplicate world paths,
oversized world data, and invalid policy ordinals; `make_differential_artifact_manifest`
records case/runner identities, seeds, engine/artifact policy, and optional module
fingerprints. Static fixtures and `scripts/check_differential_case.sh` cover the
valid, duplicate-path, and traversal/absolute-path boundaries. Fixture paths are
now restricted to relative, non-empty, non-dot segments before materialization
(`29b9738`);
case admission also rejects negative, NaN, and infinite float tolerances before
launch, preserving exact-by-default comparison policy (`5120613`);
adapter materialization, cryptographic output
artifacts, world snapshot/restore, shrinking, and execution evidence remain open.
This boundary is implemented in `src/testing/differential.elisa`, with valid and
duplicate-world fixtures plus a compiler-free audit (`ee8d217`).
The manifest now emits bounded versioned `ESDF` sidecar bytes and a deterministic
fingerprint, with fixture coverage for seed-sensitive fingerprints; version 2 also
binds a deterministic fingerprint of the complete validated world while retaining
version-1 borrowed-read compatibility (`a7b9031`); full artifact
readback and cryptographic identity remain open.
Manifest text-size admission uses checked subtraction before encoding, preserving
the bounded sidecar contract on narrow hosts (`3978039`).
The `ESDF` sidecar now has bounded borrowed readback with magic/version, length,
enum, and trailing-byte validation plus truncation fixtures (`4a704e8`).
Comparison results now have a separate bounded version-2 `ESCR` sidecar: it binds the
first mismatch report to the manifest fingerprint, preserves mismatch kind/index,
engine identities, typed run outcomes (including signal crashes), top-level value kinds, and length-delimited textual evidence,
and rejects malformed ordinals, lengths, and trailing bytes on borrowed readback.
Static fixtures and the differential audit cover round-trip, fingerprint mutation,
outcome mismatch, and truncation (`60bfca2`). Bounded `ESPS` process-stream
sidecars now persist each side's manifest binding, signed exit status, outcome,
error text, stdout, and stderr with borrowed validation, enum/truncation/trailing
byte fixtures, and a deterministic correlation fingerprint (`adc9024`). Bounded
`ESVP` value-pool sidecars now persist each side's run outcome/status,
root value, checked flat array/map storage, exact float bits, and observations
with bounded allocation-on-read decoding and malformed/truncation/trailing-byte
fixtures (`cc3b9da`). A bounded `ESRP` reproduction sidecar now
binds a shell-free launcher target and typed entry point to the manifest,
rejecting empty/NUL/oversized/unknown-version/truncated/trailing payloads with
borrowed readback fixtures and a deterministic correlation fingerprint
(`37f34ee`).
The bounded `ESIX` publication index now binds all sidecar fingerprints and
admits `Prepared` versus `Complete` states, rejecting complete indexes with any
missing sidecar and malformed/trailing bytes (`a7f31e1`).
Replay admission now uses an explicit state machine that requires a `Complete`
index, recomputes the manifest identity, validates every sidecar, enforces
reference/candidate side identity, and compares all six index fingerprints before
an adapter may launch a reproduction (`ec49be5`). Atomic
directory publication now has a typed `Staging → Ready → Published` plan with
bounded parent/component names, traversal/NUL/collision rejection, and index
state ordering, plus single-edge transition enforcement (`0e4d000`). A bounded,
validity-preserving world shrinker now emits deterministic typed reductions for
fixtures, argv, environment, and stdin (`0794004`). A run-level shrinker now
clears bounded stdout/stderr channels and removes observations only when the
original first-difference kind survives, with deterministic order and the same
candidate cap (`e116ba8`). Actual aggregate-value simplification, process
termination/timeout shrinking, replaying candidates, mkdir/write/fsync/rename
operations, crash recovery, reproduction commands, and execution evidence remain
open. A typed two-root world materialization lifecycle now binds separate
reference/candidate absolute roots to the validated snapshot and authorizes only
`Planned → Materialized → Running → Restoring → Restored` edges without doing
host I/O (`8fc30b1`). Actual fixture creation, cwd/environment setup, cleanup,
and restoration still remain open.
Independent oracle metadata now has a closed source-language identity and
runner-compatibility admission for Python, Perl, AWK, shell, C/C++, and native
references (`b4b7604`). Actual adapter implementations, oracle normalization,
and executed parity evidence remain open.
World snapshot identity now has a typed `DifferentialWorldSnapshot` and
state-machine validation for reset/order contamination (`d127a31`). Host
filesystem materialization and restoration remain open.
Comparator policy now has a typed, validated boundary for exact versus
single-final-newline-trimmed text, ordered versus unordered maps, and explicit
float tolerance, with policy-aware comparison entrypoints and fixtures
(`216b15b`). ESDF format 3 now persists those policy fields as exact float bits
while retaining version-1/2 default-policy read compatibility (`3968a82`). The
legacy tolerance API remains source-compatible; path, timestamp, field-ignore,
unordered-array, and flaky-run policies remain open.

### Q04 effect-signature increment (static, compiler validation suspended)

The lowering bridge now resolves nested `array`/`darray`, `set`, and `dict`/`map`
result and one-payload spellings from borrowed effect declaration spans using
allocation-free bracket/comma scanning. Malformed, function-type, refinement, and
multi-parameter signatures remain conservative until the shared type interner
and operation-parameter ABI are complete (`c12c4f8`).

The same bridge now parses top-level operation parameters and checks every ordered
payload for multi-parameter `perform` and `signal` operations; the existing IR,
verifier, handler callback ABI, and interpreter already carry arbitrary operand
counts, so no new runtime representation is required (`dc122b3`); static lowering
fixtures cover matching and mismatched two-parameter effects (`066d585`).
Statement-form `signal` now rejects a source-declared non-void result, preserving
the distinction between fire-and-forget signals and value-producing `perform`
(`93befcb`).
The semantic metadata pass now rejects the same non-void `signal` contract before
lowering, with a focused negative fixture (`9d59c51`).
Same-file `@handler` decorators now check declared operation arity, payload types,
and resumed result types before handler clauses enter the IR (`88756ff`).
The source-to-IR bridge now also copies each callback's declared `can[...]` effects
and `error[...]` families into the derived handler descriptor, so `with handler`
propagates the same capability/error rows as host-supplied descriptors. Static
lowering coverage asserts both rows survive derivation (`f668b00`); verifier/runtime
evidence and declaration-authoritative effect IDs remain open.

The reference interpreter and direct-bytecode facade now consume the shared
`ES_RUNTIME_DEFAULT_MAX_EXECUTION_CALL_DEPTH` runtime-model constant for ordinary
call, handler, and error-guard depth rather than maintaining backend-local copies.
An IR fixture and compiler-free audit pin the common 4,096 boundary (`a31deba`);
boundary execution evidence and fully frame-based calls remain open.
The same shared runtime model now owns the 128-level aggregate equality recursion
boundary, and both engines consume it for cyclic/hostile flat-storage comparisons;
malformed-input execution evidence and a fully iterative comparator remain open.
Recoverable error-guard nesting is now a separate shared 4,096-entry runtime
contract consumed by both engines; adversarial recovery execution evidence and
full cleanup/unwind qualification remain open.

The parser now assigns a stable FNV-1a `u64` identity to each captured
`(effect-family, operation)` pair, and semantic lookup preserves it through its
operation record (`3d00fda`). Lowered handler clauses and operation-bearing
`Perform`, `Raise`, `Panic`, and error-guard instructions carry the same identity;
the compiler-free verifier rejects populated ids that disagree with their readable
names while retaining zero as a legacy-fixture compatibility value. Static fixtures
cover lowered ids and a stale handler-clause id. Runtime dispatch still compares
names and typed runtime/continuation IDs remain open, as does compiler validation.
The interpreter now consumes populated operation IDs for handler-clause dispatch and
raised-error guard matching, while treating zero as a compatibility wildcard for
older hand-authored modules (`9436171`). Runtime continuation IDs and full execution
evidence remain open.
`Resume` instructions and captured continuation frames now carry a handler-derived
resumption token; the verifier and interpreter reject populated token mismatches
while preserving zero as a legacy wildcard (`2223897`). Richer continuation
provenance and execution evidence remain open.
Canonical IR emission and hashing now include operation and resumption IDs, plus
handler-clause operation IDs, so artifact fingerprints cannot silently discard typed
dispatch metadata (`e71a54c`). Bytecode capability/evidence qualification remains
open.
The canonical-hash fixture now changes an instruction identity and asserts the
module fingerprint changes as well (`c498cc7`); execution and artifact restart
evidence remain open.
Semantic documentation now distinguishes open-family zero IDs from deterministic
IDs assigned to rejected unknown operations (`28b4835`).
Verifier coverage selection now consumes populated instruction operation IDs as well
as names, retaining name-only fallback for legacy effect references (`d90ca32`).

### Q03 typed-builtin increment (static, compiler validation suspended)

The global typed registry now includes Python-compatible `lstrip` and `rstrip`
aliases alongside `strip` and `trim` (`7135146`). Semantic seeding, registry
return inference, lowerer dispatch, and source fixtures cover all four spellings;
the lowerer records `TrimText` mode 0/1/2 for both/left/right trimming, and the
compiler-free registry audit checks that mode metadata is preserved. The fixed
text aggregate aliases `partition`/`rpartition` and `split_lines`/`splitlines`
now likewise use registry arity, result, and opcode metadata with typed
`darray[sview]` results (`ab1c328`). Global `split` now shares the registry
named-argument contract, including its distinct `maxsplit` slot, with semantic
and lowering checks (`b15968c`). Global `join` now carries and enforces a
structural `darray[text],text` descriptor through the semantic type table while
sharing lowerer result/opcode metadata (`5a57864`). No compiler or runtime validation was run
because the resource-safety gate remains closed.

The lowerer now centralizes registry-declared effect/error propagation in
`record_builtin_contract`, and the parse/index fixtures assert that the declared
families survive into the enclosing IR function (`d6ceca3`). This closes a
metadata-drift gap for the current one-family-per-row registry shape; structured
effect/error IDs, generic descriptors, and execution evidence remain open.
The common global-call boundary now invokes the helper for every unshadowed
registry row, including future rows, while receiver dispatch keeps its own
classification gate (`1cd1cfa`).
Firm Text/Regex receiver expressions now enter that same helper before method
dispatch (`1138aea`), closing the parallel receiver metadata drift path without
granting speculative contracts to unknown UFCS receivers.
