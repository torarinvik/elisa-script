# Preferred Darwin streaming backend: posix_spawn

Status: source-only private ABI/attempt layer. No spawn, attribute operation,
compiler, fixture or parity test ran. No runnable script or runtime builtin is
wired to it. The prior fork child/error-record sources stay unwired.

## Evidence and backend decision

The installed MacOSX SDK's usr/include/spawn.h declares posix_spawnattr_t and
file-actions handles as opaque void pointers. posix_spawn returns int, writes a
pid_t result and accepts pointers to the handle slots plus explicit argv/envp.
The SDK's usr/share/man/man2/posix_spawn.2 Return Values section states that a
successful call returns zero with the PID, while a nonzero error return creates
no child. Its posix_spawnattr_setpgroup.3 manual says group zero with
POSIX_SPAWN_SETPGROUP creates a new group. sys/spawn.h defines that flag as 0x0002.

That documented Darwin contract is a better fit than relying on empty error-
pipe EOF to prove an application-written fork child crossed exec. Prefer plain
posix_spawn on precomputed candidates, **not posix_spawnp**: merged-child PATH
selection, explicit environment ownership and no shell fallback stay ours.
No guessed attribute struct, child callback, global environment mutation,
post-fork allocator or private error pipe is needed for this preferred path.
This is a platform-specific decision; do not generalize its synchronous error
semantics to every POSIX implementation without that provider's qualification.

## Authored boundary

process_spawn_darwin.elisa privately declares the ABI with i32 int/pid_t, i16
short flags, opaque slot views, nullable file-actions pointer and explicit argv/
envp. Attribute initialization/destruction declare allocation/release effects;
spawn conservatively declares both, without claiming libc is allocation-free.
The single-candidate helper returns the actual API result, never TLS errno or a
guessed child wait status. Signatures, slot size/alignment and native lowering
still require qualification; the declarations are not observed ABI evidence.

The pure process_spawn_attempt_model.elisa layer admits zero plus a positive
PID greater than one as Spawned. PID/group one is rejected too: the installed
kill.2 manual documents kill(-1) as broadcast, not signaling one owned group.
Positive API errors are NoChild and discard unspecified PID
output; never signal a PID returned alongside an error. Negative return codes
or success without an admissible PID remain Unknown, not safe no-child failures.
Unknown diagnostic PID values do not confer child ownership or signaling rights.
Inconsistent public receipts stop rather than authorize adoption or retries.
Only fresh results from the separately qualified native provider are authority.

Search decisions reuse the explicit missing/not-directory/access-denied/fatal
policy. A successfully spawned program's normal 125/126/127 status is a later
wait outcome, not a spawn error. This avoids reserving those tool statuses to
encode a pre-exec pipe reporting failure. Independent pure fixtures cover API
classification and inconsistent receipts, but have not compiled or run.

## Required parent lifecycle

Prepare/retain owned buffers and admitted native tables before spawning. Own one
initialized attribute handle, set only the intended group flag/group zero and
do not copy that handle as a second owner. Configure and destroy using pointers
to its opaque handle slot, not the handle's pointee. Attribute initialization,
configuration and destruction now have a source-only private owner adapter,
described below; native qualification and parent process integration remain open.

Reserve a process resource before each admitted launch workflow. A confirmed
Spawned PID must be adopted immediately before any fallible cleanup or allocation;
do not lose it if attribute destruction fails. Retain ownership through waiting,
group checks, deadlines and failure cleanup. A NoChild attempt permits the next
candidate without creating a new child resource. Unknown API outcomes must not
release the reservation as though no child exists or signal an unowned PID.

Reuse the existing runtime process resource/group/deadline/wait/termination
machinery for the adopted child. Do not duplicate it inside this private bridge.
Plain inherited stdio includes initially closed routes; no pipe should occupy
those descriptors. Qualify signal defaults/masks, descriptor inheritance, cwd,
attribute flags, group behavior and every error transition explicitly. Native
API guarantees do not establish descendant containment, RSS or concurrency safety.

Next implement parent-spawn/PID adoption integration, then source/IR/
verifier/interpreter/bytecode entry points and UI CC/package wiring. Synchronous
spawn failure versus normal child statuses, merged PATH and inherited binary
streams need independent native probes under explicit reauthorization plus real
process-tree RSS/wall-time containment. Original scripts/callers, SSH and other
agents' changes remain untouched. No execution permission is granted here.

## Attribute ownership layer (authored, not executed)

`process_spawn_attributes_model.elisa` distinguishes initialized/group-set/
configured objects, known setup failure, uncertain setup and release outcomes.
Known configuration failure retains a destroyable initialized object. An error
plus unexpected slot state is uncertain, not safe evidence to call destroy.
Failed/uncertain destruction is terminal: never retry it against a possibly
freed native object. Slot presence is metadata, not a pointer-validity proof.

`process_spawn_attributes_darwin.elisa` privately retains the actual nullable
handle in a caller-held owner record. It reserves a NativeAttribute lease in the
shared EsResource ledger before initialization. Owner-checked canonical lookup
checks the kind and Acquired state before native configuration, destruction or
spawn; a stale copied lease is not authority. Group zero is set first, followed
by the intended group flag. Only Configured objects reach the guarded spawn
helper; all fallible ownership checks precede the call, and its PID receipt is
returned without intervening cleanup or another fallible ledger operation.

BeginClose is recorded before native destroy. Success clears the local slot and
completes release; uncertainty records a Failed lease and denies further native
use. Init failure with no handle completes its unused reservation. Uncertain
init/configuration preserves a failed ownership receipt instead of guessing that
an opaque pointer is valid. The caller-held owner updates immediately after host
calls, so an unexpected post-call ledger error cannot hide its handle via a
failed constructor return. Such ledger corruption still needs typed host-failure
recovery; these functions do not claim every panic/fault is safely finalized.

One native owner/ledger pair must remain exclusively held: do not copy opaque
owners, mutate or replace the ledger concurrently, or reuse IDs as new authority.
Canonical gating prevents repeat destruction through stale records, but it does
not establish full linear types or concurrency exclusion. Failed entries remain
in the bounded ledger and its failed count; they are not proof that native memory
was freed. The eventual runtime budget/finalizer must retain unresolved native
reservations and inspect failed receipts, not just active_entries.

NativeAttribute is an additive resource kind; existing kind ordinals are retained.
The public owner-checked query returns a snapshot of the canonical lease, not a
capability that stays current after copying. Pure receipt, owner mismatch, stale
copy, once-only close and failed-release fixtures are authored but unrun. Native
slot ABI, actual init/set/destroy behavior, allocator accounting and failure
injection still need controlled qualification. No attribute object or spawn was
created here, and UI/package/source/IR/bytecode wiring remains unfinished.

## Parent candidate search and PID adoption (source-only)

`process_spawn_parent_darwin.elisa` now provides private reservation, prepared
candidate search and no-child release operations. A Process lease is acquired
under the caller's token before the workflow. The parent requires that canonical
lease and the configured attribute owner before native attempts. Storage is
readmitted and tables must bind exactly to its retained argv/environment/search
buffers, including all sentinel slots and recomputed receipts. Equal bytes in a
different buffer do not substitute for the original binding.

Each fresh native attempt is immediately observed into a caller-held
`EsProcessSpawnOwner::Owner`. A confirmed PID enters Running before any cleanup,
ledger mutation or wait call can fail. Missing/denied candidates reuse the same
reservation; fatal no-child errors and exhausted search enter NoChild. Unknown
API outcomes retain the reservation and diagnostic PID without granting signaling
rights to that PID. No search or no-child release may erase a Running receipt.
Search count is bounded to the admitted non-sentinel candidates, at most 4096.

No-child release checks the canonical Process lease and begins/completes close.
A separate rollback handles pristine reservations before any spawn attempt,
for example attribute setup failure. It rejects Running/Unknown or partially
observed search. A setup exception after only known no-child candidate returns
can still leave Reserved state; its typed coordinator must preserve and resolve
that observation rather than guess it is an unstarted reservation. This layer
does not implement a complete coordinator/finalizer or recover every panic.

Pure observation fixtures cover adoption, denial/exhaustion, unknown reports,
non-signaling diagnostic PIDs, bounded attempt fields and preservation of an
already captured PID. A dormant native fixture checks storage/table bindings.
These are uncompiled/unrun source fixtures, not observed native adoption or
launch parity. Public model records remain data, not ownership capabilities.
Only the private controller's fresh qualified API observations and canonical
ledger are relevant authority; exclusive owner/ledger/storage access is required.

The outer runtime must still acquire its process-budget counter before launch,
retain both owners and buffers, destroy attributes after PID capture, and hand
the Running child to the existing waiter with the qualified new-group contract.
Attribute cleanup failure must terminate/reap the captured child rather than
throw away its PID. No-child outcomes release the unused process budget; Unknown
outcomes must not release it as if no child could exist. Reap/group/deadline/
signal/finalization, runtime counter pairing, source/IR/bytecode integration and
actual UI/package wiring are still missing. No process ran while authoring this.

## Attribute preparation and finalization (source-only)

The private `prepare_attributes` workflow now orders init, new-group selection
and flags via an explicit state machine. A pristine owner is required; a fresh
workflow has at most three native setup calls. Failed or uncertain native returns
stop without attempting the next step. Its returned receipt must be Ready before
any spawn; returning a setup receipt is not a success assertion. Typed ledger
errors may still propagate with the caller-held owner intact, and the caller
must then resolve reservations rather than abandon them. Allocation panics and
effect cancellation do not have an implemented complete finalizer here.

`finalize_attributes` chooses destruction only for internally consistent owned
handle receipts, using the canonical owner/kind/lease checks before the host call.
Known no-handle init failures and already released slots require a Released
canonical lease. Uncertain init/configuration/destruction requires a Failed
canonical lease and returns the uncertain receipt without retrying destruction.
Failed does not mean deallocated or prove a released memory budget. Receipt/slot
presence mismatches, forged success/error fields or inconsistent canonical states
are rejected. An unreserved pristine owner has nothing to finalize and must be
handled separately by the outer coordinator, not passed to this function.

Neither operation takes a child owner; attribute cleanup cannot overwrite the
captured PID. The outer coordinator must still retain/reap a Running child even
if finalization raises an error or reports DestroyUncertain, and must keep the
process budget reserved for unknown child outcomes. These wrappers do not yet
connect setup, spawn and waiter into a runnable public API. Pure fixtures cover
ordered scheduling, early stops, forged receipts and uncertain/released cleanup
decisions, but none were compiled or run. Native setup/finalization, ABI, state
machine lowering and exact UI CC environment parity remain unqualified.

## Shared process-budget pairing (source-only)

`src/ir/process_spawn_budget_model.elisa` now pairs the existing runtime Process
counter with the canonical Process reservation. Capacity is acquired before
ledger allocation and retained immediately in caller-held state. Typed ledger
admission failures roll back that counter; panics/cancellation still need the
outer finalizer. Invalid policy, over-budget usage and zero/full process capacity
are rejected before a launch. The model does not allocate a second independent
process counter or reset usage for a child invocation.

Known no-child outcomes and pristine pre-launch rollback close the canonical
reservation before releasing its paired counter. Running or Unknown child
observations cannot use those edges. A new Reaped observation preserves the PID
but requires a fresh exact-PID confirmed wait report; counter completion requires
Reaped and an acquired matching canonical lease. Copied stale receipts cannot
close an already released lease to consume another active process slot. All
records remain public data: the private coordinator must supply actual host wait
evidence and exclusive access to the same child, ledger and per-run usage.

The unwired private `src/ir/process_spawn_budget_darwin.elisa` seam retains child,
attribute and budget owners together. Attribute setup and prepared-candidate
spawn require a held matching Process reservation. Spawn immediately retains
the child result before any fallible cleanup. Attribute finalization does not
release the process budget. The portable helpers intentionally know nothing
about signals, wait status, group quiescence or OS handles; no forged model field
is signaling authority. This limit counts direct leaders, not escaped descendants,
and does not claim an RSS or opaque-attribute allocation limit.

The interpreter's existing waiter releases a process counter after confirmed
reaping. Its actual new-backend handoff, status/deadline/group cleanup, error
precedence, panic/cancellation finalization and source/bytecode/public-launcher
wiring are still absent. No runtime includes the new native seam. The authored
pure fixtures cover zero capacity, duplicate-ID rollback, live-child retention,
exact reap, stale release, unstarted release, unknown outcomes and wrong owners;
they remain uncompiled/unrun. No child, native attribute or waiter was executed.

## Existing waiter handoff and terminal-status checks (source-only)

The existing interpreter waiter had treated any positive cleanup wait result as
reaping and any exact-PID poll result as terminal. The authored correction now
requires an exact PID and a terminal status before setting reaped. Darwin traced
stop/continue reports are not reaps; cleanup keeps a bounded retry after KILL,
and nonterminal poll reports enter failed cleanup rather than publish an exit
code or release capacity. Calling live-child cleanup on an already reaped waiter
now delegates only to group cleanup, without signaling its reusable direct PID.

The small `EsProcessSpawnWait` model admits the selected Darwin UNIX03 profile:
sixteen-bit status words, ordinary exit bytes and signals 1..31 with optional
core flag. Stop/continue and malformed/unsupported encodings are not terminal.
This conservative profile is derived from the installed SDK sys/wait.h and
sys/signal.h, not claimed as universal POSIX encoding. Literal fixtures cover
tool statuses 125/126/127, signals/core, stop/continue, malformed words and PID
mismatch. They are authored, not compiled or executed.

`src/ir/process_spawn_wait_adapter.elisa` adds an unwired private EsIr handoff to
the existing poll/deadline/group/terminate helpers, not a second polling loop.
It checks the held canonical Running reservation before any signal, retains
the PID/budget on ownership failure, and forces terminate/reap after reported
attribute cleanup failure. Confirmed terminal reaping is captured before
fallible lease close. The paired counter is released exactly once; the adapter
does not also call the legacy process_resource_complete release. Unreaped or
accounting-inconsistent outcomes become Panic, preventing recoverable launches
while capacity remains held. Completed timeout/process failures are classified
after cleanup and release; normal status comes from the same strict wait model.

The adapter requires the interpreter definition context and fresh qualified
Darwin SETPGROUP/group-zero spawn evidence, not a user-supplied PID or forged
model record. No facade or public launcher includes it. The full launch/cleanup/
wait coordinator, pre-launch deadline origin, source/bytecode/UI wiring and native
qualification remain open. Existing group-quiescence and post-reap group-identity
assumptions still need host-level scrutiny; this change does not prove group-ID
reuse safety or escaped-descendant containment. Compiler/native/debugger/parity
execution remained disabled, and unrelated interpreter changes were preserved.

## Private setup/search/cleanup coordinator (source-only)

`launch_prepared_budgeted` now orders retained-binding admission, shared Process
reservation, attribute setup, candidate search and attribute cleanup through a
private state machine. Caller-held launch state retains all owners, setup's code
and separate setup/cleanup failure flags. Setup's code is saved before successful
destruction can replace an attribute receipt with Released/code zero. Native
setup failures stop without spawn. Typed setup/search errors attempt cleanup
before propagating, while preserving the caller-held child and budget.

Cleanup is attempted once, recording attempted/failed before fallible operations.
Pristine unreserved attributes need no destroy; known/uncertain acquired slots
use the canonical finalizer. Known no-child/unstarted Process reservations are
released independently of attribute cleanup success. An uncertain attribute
receipt remains retained, does not prove deallocation and must be treated as
fatal by the outer runtime even if no child was started. Running and Unknown
children keep their process capacity; any cleanup error still leaves the captured
PID for mandatory terminate/reap, not an ordinary early return by the outer layer.

A partial search interrupted by a typed pre-attempt check now has a distinct
no-child rollback. The synchronous controller captures every native return before
its next fallible check. Only Reserved state with bounded nonzero attempts, zero
owned/diagnostic PID and a last missing/not-directory/denied retry result can be
stopped this way. Its last native code and denial observation are preserved; it
is not relabeled full PATH exhaustion or a successful command. Running, Unknown,
unstarted or inconsistent receipts are rejected. Public model fields still are
not host proof; canonical close/counter guards and exclusive state are required.

Complete means the setup/search/attribute cleanup sequence was visited, not that
the tool succeeded or was reaped. Typed cleanup/accounting failures may supersede
the initial setup/search error; retained fields and phase record unresolved state.
Panic/cancellation finalization is still absent. These functions and the existing
waiter handoff remain private, uncompiled and unincluded by public launchers;
cross-namespace integration, pre-launch deadline origin, group identity/native
qualification, source/bytecode/UI wiring and real failure injection are pending.
Pure partial-abort/retained-PID/budget fixtures are authored but unrun. No native
setup, spawn, destroy, signal, compiler or parity process ran during this work.

## Completion routing and fatal cleanup precedence (source-only)

The native coordinator can now project a small completion report containing its
phase completion, typed invocation failure, setup failure/code and cleanup
attempted/failed fields. It does not expose raw attribute slots or layout. The
public report is pure data, not ownership authority; only a fresh private host
workflow and canonical ownership checks may feed the private interpreter handoff.

`finish_prepared_launch` routes a normal retained Running child to the existing
waiter, and a Running child with failed/missing/inconsistent cleanup to forced
terminate/reap followed by Panic. Reaping resolves child capacity, not uncertain
native-attribute allocation or a broken coordinator invariant. Consequently such
cleanup failures now remain fatal even after successful child cleanup, instead
of becoming recoverable Process failures that could repeatedly allocate opaque
failed slots. Unknown or unresolved Reserved outcomes retain state/capacity and
never authorize signaling a diagnostic PID. Already Reaped is not a new launch.

Known no-child outcomes are recoverable Process failures only after completed,
nonfailed cleanup, an unheld paired budget and a matching canonical Released
Process lease. A forged unheld receipt with an Acquired lease is rejected. Fresh
typed admission failures require pristine child/budget fields and no cleanup or
setup side effects. Process failure is not a tool exit code: ordinary tool
statuses 125/126/127 still flow through actual terminal wait status decoding.

Pure fixtures cover wait/fatal-cleanup/no-child/unknown/reserved/repeated-reap/
fresh-admission routing and canonical-release checks, but remain uncompiled and
unrun. The report projection and interpreter dispatcher are authored on either
side of the namespace boundary; a qualified entry still must connect them while
retaining owners and excluding mutation. No public launcher includes this seam.
Native/callback lifetime qualification, deadline origin, group identity, panic/
cancellation finalization and source/bytecode/tiny UI CC wiring remain open. No
compiler, fixture, attribute operation, spawn, signal or parity run occurred.

## Private host namespace and connected entry (source-only)

The raw Darwin bridge, opaque attribute owner, parent search and budgeted native
workflow now extend the interpreter host's private `EsIr` namespace. Their pure
models remain separate public-data modules. This resolves the former private
native-module/private-waiter boundary without exporting handles, private storage
types, callbacks carrying native slots, or guessed opaque-layout serialization.
The flag constants use the specific private `ProcessSpawnFlags` const module.
The native bridge includes the type-only IR model, not an execution facade.

`evaluate_prepared_launch` is a private connected entry: it invokes the native
coordinator with the same machine usage/policy and caller-held launch storage,
captures whether a typed error occurred, projects the retained report, and always
visits `finish_prepared_launch`. A captured child cannot be bypassed by an early
typed-error return. Failed-machine or consumed-owner reentry starts no new native
workflow; it preserves Panic and dispatches any already owned Running child for
mandatory cleanup. The helper is not a public source primitive or installed
launcher operation, and no default facade includes the seam.

The caller must retain the launch/ledger/buffers across the operation and preserve
unresolved owners after fatal return. A stack wrapper that discards an unreaped
child or uncertain opaque slot would violate this contract. Session-owned storage,
panic/cancellation finalization, pre-launch deadline origin, post-reap group
identity, host ABI and generated lifetime/effect qualification are still pending
before public source/bytecode/UI wiring. No unsafe private-type inference or
compiler visibility loophole is used as ownership authority.

A small dormant fixture includes the native ownership/model seam without the
full IR execution facade. Its public test entry runs inside EsIr and observes
private defaults/constants and public report routing only; it does not call any
native function. It remains uncompiled/unrun, as does the connected entry. No
compiler, attribute, child, waiter, signal or parity process was launched here.

## Durable session owners and checked reuse (source-only)

`PreparedSpawnSession` now owns the native launch slot, canonical lease history,
nonzero owner token, non-wrapping resource-ID stream and Ready/Active/Quarantined
state. `evaluate_prepared_session` uses the connected entry with the same machine
usage/policy. Fatal completion quarantines the session without dropping its PID,
budget, opaque slot or receipts. It does not clear an interpreter failure or
reset usage so a nested/repeated launch can obtain new capacity improperly.

Reuse requires no active/failed ledger entries, an unheld process budget and
internally consistent Fresh, known NoChild or confirmed Reaped state. Completed
process/attribute slots must match canonical Released leases and the session
token; missing/failed/closing leases or uncertain attribute receipts block reset.
Only then is the retired launch slot replaced with a fresh one. Released history
is retained, IDs advance by two even for a later rejected admission, and a
rewound/colliding/exhausted stream fails without unsigned wrap. The total retained
record limit still applies; this is not unbounded history or an RSS guarantee.

The generic resource validator now checks strict ID order first. Strictly
increasing IDs prove uniqueness without allocation, making that validation path
linear in record count. Unordered input keeps the original earlier-ID duplicate
scan and error ordering; kind/state/owner/accounting validation is never skipped.
The session uses monotonic IDs, so normal retained history takes the checked
ordered path. No benchmark or runtime speed claim has been qualified.

Small dormant fixtures cover model-only released reuse, retained history, unknown
child quarantine, uncertain attribute history without a child, ID exhaustion,
empty/single/ordered/unordered ledgers, nonadjacent duplicates and accounting.
They do not invoke the native process/attribute bridge and remain uncompiled/
unrun. The enclosing run/task still must retain the session and borrowed input
storage/tables across unresolved outcomes; this does not instantiate a durable
session in public runner/bytecode contexts yet. Owner/borrow/codegen lifetime,
memory accounting, panic/cancellation finalization, pre-launch deadlines, group
identity and native qualification remain open before tiny UI/public wiring.
No compiler, fixture, attribute, process, wait, signal or parity run occurred.

## Uncertain positive wait reports (source-only)

The shared waiter now distinguishes a known stopped/continued report from an
unsupported status accompanying a positive wait result. The latter may already
have consumed a child, so another direct-PID signal could target a reused PID.
A mismatched positive PID is likewise not evidence that the owned child is
still live. Polling, TERM-grace polling and final reaping mark these observations
as ownership-uncertain, fail the operation, and stop further wait/signal attempts.
Repeated termination and group cleanup also respect the uncertainty flag.
Neither ordinary resource completion nor the private spawn handoff releases
process capacity from an uncertain waiter, even if a stale reaped bit is set.

The conservative Darwin status profile rejects zero/out-of-range stop signals
and impossible stop/core combinations, while preserving ordinary exit codes,
terminal signals, SIGSTOP and the Darwin SIGCONT continuation encoding. Pure
fixtures cover malformed statuses, exact/mismatched/invalid PIDs, pending returns
with stale status bytes and known nonterminal reports. They remain uncompiled
and unrun; no wait, kill, child, compiler or parity operation was performed.

This closes one source-level unsafe branch, not full waiter qualification.
Negative wait errors (especially ownership loss/ECHILD), C-int/pid/status ABI,
post-reap group identity, external reapers, cancellation and retained owner
lifetime still need separate handling and evidence. The smallest lint wrapper
remains a candidate, not an accepted Bash exec replacement; original scripts and
callers are unchanged.

## Negative wait failure admission (source-only)

The selected Darwin error profile now distinguishes interrupted waits, ECHILD
ownership loss, EINVAL request failure and unknown errors. Only the expected
`-1`/EINTR pair preserves the existing retry assumptions. Other negative returns
mark the waiter ownership-uncertain before any cleanup or later signal attempt;
ECHILD is not converted into a terminal receipt or released process capacity.
The check applies in normal polling, TERM-grace polling and final reaping.
The errno value is copied immediately after access, before any further native
operation; nonnegative wait returns do not interpret stale errno.

Existing bounded EINTR retries remain. Exhaustion can still enter mandatory
cleanup under the exclusive-reaper assumption, but any subsequent non-EINTR
wait failure blocks further signaling. This intentionally sacrifices recoverable
progress on an unqualified host error rather than guessing a PID's ownership.
No eventual reap, orphan recovery or successful cleanup is claimed from the
quarantine state. Fatal owners and budgets still need durable task lifetime.

Pure fixtures cover ECHILD, EINVAL, valid EINTR, malformed negative returns,
zero/negative/unknown errno, and nonnegative returns with stale errno. They are
uncompiled/unrun. The legacy waitpid C-int/pid/status ABI, exclusive-reaper and
signal-disposition assumptions, post-reap group identity, retained lifetime and
cancellation remain qualification blockers for the smallest lint wrapper and
new spawn path. No compiler, fixture, child, wait, kill or parity process ran;
original scripts/callers and other agents' work remain unchanged.

## Legacy process scalar ABI correction (source-only)

Primary compiler source `backend/codegen_env.elisa::scalar_type_of_name` models
Elisa `int` as signed 64-bit and `i32` as signed 32-bit. Extern declaration
lowering uses those declared scalar widths; a linker name does not infer a libc
signature. The installed Darwin SDK declares `__darwin_pid_t` as `__int32_t`,
`waitpid` as `pid_t (pid_t, int *, int)`, and the process/error/status scalars
in fork/exec/kill/setpgid/dup2/fileno/_exit as C int or pid_t. The legacy bridge
previously declared these using Elisa `int`, including its borrowed wait status.

`process_posix.elisa` now uses private i32 native signatures for these scalars,
explicitly widens signed results to preserve the existing public int API, and
passes waitpid a fresh mutable i32 status slot. A positive result copies the
complete native status into the caller's int; zero/negative results leave the
caller status unchanged and the waiter does not decode it as a fresh receipt.
This avoids exposing the low half of an eight-byte slot to a four-byte C write.

The raw-handle-free `EsProcessScalarAbi` model admits scalar arguments within
the selected signed-32-bit range before narrowing. Outside-range arguments
return bridge sentinel -2 without a native call or errno update, rather than
silently targeting a wrapped PID/descriptor. This is not a libc return code:
callers must treat it as admission failure and must not interpret stale errno.
The wait-error model already quarantines -2 even if stale errno says EINTR.
Exit inputs are reduced to their low eight bits before the native C-int call,
preserving POSIX status behavior for negative and large Elisa values.

Pure fixtures cover boundaries, signed widening, rejection versus stale EINTR,
and exit-bit reduction. They contain no process bridge/native declaration and
remain uncompiled/unrun. These source changes do not qualify generated native
ABI, status-slot lifetime, platform symbol aliases, pointer tables, async-safety,
exclusive reaping, signal handling or post-reap group identity. Native return/
status-slot probes and smallest-wrapper public-launcher parity still require
explicitly reauthorized contained validation. No compiler, native operation,
fixture or parity process ran; originals, SSH and others' changes are untouched.

## Bridge rejection versus native errno (source-only)

The ordinary interpreter and independent differential runner now use the same
pure `native_errno_failure` predicate for kill/setpgid/dup2 results. Only native
-1 admits an errno lookup. Bridge -2 rejection (or another unexpected return)
stops signal retries and fails group setup/descriptor duplication without
consulting stale EINTR/EACCES. In particular, a rejected out-of-range setpgid
input can no longer appear successfully grouped because a prior call left
EACCES in errno. A rejected group-membership probe remains conservatively
"possibly present", never proof that captured output has become quiescent.

This applies to parent and child setup helpers in both runners; no helper loses
its existing bounded retry policy for genuine native -1/EINTR. Pure fixtures
distinguish native -1, bridge -2, other negative returns and success. They remain
uncompiled/unrun, and this does not qualify actual errno access, post-fork safety,
generated ABI, group identity, external reaping or differential waiter ownership.
No compiler, fixture, signal, process or parity operation ran. Only these isolated
helper changes are committed; concurrent errno/clock edits remain unstaged.

## Differential wait and binary receipt admission (source-only)

The differential process loop now requires an exact terminal child report before
finishing. Known stopped/continued reports trigger best-effort owned cleanup and
reject the observation; malformed or mismatched positive reports reject without
further PID/group signaling. Non-EINTR negative reports likewise reject without
guessed cleanup. TERM-grace and final-reap helpers share the pure uncertainty and
exact-terminal checks; they no longer treat any positive PID or a nonterminal
exact-PID report as confirmed reaping. Bounded EINTR handling remains.

`EsProcessWaitResult` now decodes the selected terminal status into a separate
bounded binary observation receipt. The former adapter sent differential bytes
through `validate_process_result`, whose general text-only schema rejects NUL
and requires signaled results to have no ordinary exit code. The independent
parity probe contains NUL bytes, while DifferentialRun represents signals as
Crash with normalized `128 + signal`; that former adapter was incompatible with
both contracts. The new receipt preserves arbitrary stream bytes and normalized
signal observations without loosening the general ProcessResult schema. It
rejects nonterminal/malformed statuses and bounds combined stream lengths by
the existing process capture ceiling using subtraction-before-addition checks.
The invocation's own tighter output budget still applies during capture.

Pure receipt fixtures cover normal/reserved-looking exits, signals/core reports,
binary bytes, exact stream preservation, rejected status forms and combined-byte
boundaries. They import no differential facade or native bridge and remain
uncompiled/unrun. These changes are not proof of a safe supervisor: the existing
differential helper has no durable unresolved-child owner/session receipt, and
fatal error recovery must not silently launch replacement children. Native ABI,
exclusive reaping, group identity, child async-safety, capture/world quiescence,
retained fatal ownership and external containment still need qualification
before smallest-script parity execution. No compiler, fixture, child, wait,
signal or parity operation ran; other agents' errno edits remain unstaged.

## Dormant independent scalar ABI fixture

`test/fixtures/native/process_scalar_abi/` now contains a small synthetic C
oracle, its separately linked Elisa qualification source and an admission
contract. The C object defines only uniquely prefixed fixture symbols, never
interposing fork/waitpid/kill. It uses no allocation, I/O, process creation,
wait or signal call. C static assertions select signed 32-bit int/pid_t and
64-bit pointers. An independent C-to-C control checks literal results and guards.

The Elisa fixture checks literal initial guard bytes, then calls private i32
declarations and checks -1/INT_MIN/INT_MAX widening, status patterns, neighboring
mutable guards and rejected request/option behavior. The scratch status patterns
are not real waitpid receipts. This is future native evidence for the exercised
scalar call/slot layout, not a replacement for actual bridge symbol/errno,
pointer/lifetime/effect, process-group/reaper and retained-owner qualification.

The source is deliberately outside ordinary *_test discovery. A future operator
must first obtain explicit execution reauthorization, qualify the external
RSS/time guard and local compiler, separately build/admit the C object and link
only this selected fixture with recorded SDK/target/tool/source identities.
Neither source has been compiled or run. No fixture, compiler, native call,
process or parity operation was launched, and smallest lint parity remains open.

## Generated pointer/opaque-slot width admission (source-only)

The launch table builder and binding validator now derive their width through
`native_pointer_bytes`, which checks both `size_of(uintptr)` and the generated
`size_of(u8&?)`. Only supported four/eight-byte pointers with equally sized
nullable entries pass. A future tagged optional representation cannot silently
retain a raw-pointer table budget or reach the private spawn binding checks.
This is actual target-derived admission, not a caller-supplied marker.

Private attribute initialization now checks the selected Darwin64 pointer,
optional void-reference slot, reference, C-int/pid and short widths before lease
acquisition or native initialization. Existing owner checks apply the same gate
before native group/flag setters, destruction and configured spawning; a layout
failure does not authorize native cleanup of a guessed opaque slot.
The compiler source currently niche-optimizes reference optionals to a bare
pointer (`optional_is_niche` and `llvm_type_of`), but that source fact does not
qualify the selected installed/local compiler or generated runtime representation.

Pure fixtures reject unsupported/tagged widths and each wrong Darwin scalar/
slot width. The existing dormant native table fixture also calls the generated
width gate before constructing tables. All fixtures remain uncompiled/unrun.
Equal size is necessary, not sufficient: alignment, pointer encoding, physical
array stride, raw NULL sentinels, opaque-slot writes, borrowed lifetime and the
native C view still need independent contained qualification. No compiler,
fixture, attribute, child, native wait/signal or parity run occurred. Public
source/bytecode/UI wiring and smallest-script acceptance remain open.

## Independent C view of real builder tables (dormant)

The separately linked scalar fixture now includes a fixed-size read-only C
pointer-table oracle and independent C controls. Its third Elisa test uses the
actual storage/table builder for argv `./tool` plus an empty argument, environment
`X=`, and a separately owned direct candidate. C admits the three/two/two slots
by expected pointer identity and NULL sentinels before reading eighteen known
buffer bytes. This exercises the real nullable-entry stride/C view rather than
constructing a parallel pointer-table implementation solely for the fixture.

The C control rejects substituted empty-argument NULL, missing environment NULL
and aliased candidate entries. The Elisa test also substitutes/restores its empty
argument between calls and checks rejection/reacceptance. No buffer or table is
mutated during a native call. Raw fixture functions remain private, exported C
symbols remain uniquely prefixed, and no process/environment/stdio/signal/native
attribute operation is present in the oracle. Its only reads are bounded fixture
tables/buffers; invalid pointers still require external crash/time/RSS containment.

The admission contract now names all three required test entries. Neither C nor
Elisa source has been compiled/run, and the fixture stays outside ordinary
*_test discovery. Passing it later would qualify only the exercised table/scalar
cases for the recorded build; broad lifetime/alignment/malformed/maximum-table,
native spawn, errno, reaper/group and unresolved-owner qualifications remain open.
No compiler, fixture, child, wait, signal or parity operation ran here.

## Clock ABI prerequisite for launch-wide deadlines (source-only)

Inspection of the installed Darwin `_time.h`/`unistd.h` and `timespec` headers
shows C-int returns for clock_gettime/usleep, a C-width clockid_t enum with
MONOTONIC value six, and Darwin64 time_t/long fields for seconds/nanoseconds.
The clock bridge previously used Elisa int (64-bit) for returns and clock ID.
It now declares signed i32 returns and emits only the selected positive enum
value through a u32 carrier, explicitly widening native returns to preserve
the public int API. This keeps native -1 negative for existing failure checks.

Before a native clock write, the bridge checks the selected pointer/i64/timestamp/
result/clock-ID widths. Unsupported shapes return bridge -2 without a clock call
or errno update. Existing clock consumers reject any nonzero return; they do not
interpret errno for that admission failure. A pure profile fixture and dormant
literal timestamp-layout fixture cover wrong widths and the expected two-field
Darwin64 byte order, with no clock/sleep call. Both remain uncompiled/unrun.

This is a prerequisite correction, not launch-wide timeout integration. The
private spawn path still starts its deadline in the existing waiter after setup;
carrying a pre-setup origin through reservation/setup/spawn/cleanup/wait and
classifying clock errors without losing an owned child remain next. Native enum/
timespec writes, field alignment/lifetime, clock behavior and generated ABI still
need independent contained qualification. No compiler, fixture, clock, sleep,
child, wait/signal or parity process ran; originals and others' work are unchanged.

## Retained launch failure causes (source-only)

The private budgeted owner now retains a handle/PID-free diagnostic receipt.
The finish adapter publishes it only on recoverable launch failure, after
checking canonical released no-child ownership (or pristine unreserved admission
state). Admission, setup, aborted search and completed spawn failure remain
distinct. Setup's saved native code survives attribute destruction; an aborted
search retains the last observed code but cannot expose it as the failure cause.
In particular, a partial search interrupted after ENOENT does not establish
completed PATH exhaustion or command-not-found.

The pure model rejects inconsistent attempt counts, setup-plus-exec reports,
negative/zero completed spawn codes, lost denial history and unnormalized
completed ENOTDIR. Native cause access is a typed error for admission, typed
setup errors without a native code, and aborted search. Normal Running/Reaped
children never produce launch-error receipts: tool exits 126/127 remain exits.
This metadata does not establish PID/resource authority or native evidence.

Receipts remain in the existing per-run session after failure. Reentry/Panic
does not overwrite them, and only the existing checked retired-session reset
starts with an empty receipt again. A stale receipt on a live-child wait edge
forces mandatory cleanup and fatal classification, not an early child discard.
Small pure/default/session-reuse fixtures are authored, all uncompiled/unrun.

The seam is still unwired: source/bytecode typed error payloads and copying the
receipt into the caller's error value before session reuse remain next, followed
by diagnostic rendering and actual smallest lint failure parity. No Bash-style
diagnostic, public process API change or native qualification is claimed here.
Pre-setup deadline, ownership/group/reaper/lifetime/cancellation qualification
and external containment remain open. No compiler, fixture or native operation
ran; originals, SSH and other agents' work remain unchanged.

## Primitive cause snapshots before session reuse (source-only)

The cause model now provides a value snapshot with three i64 fields and a bool,
matching the primitive carriers supported by existing IR error payloads. Its
explicit version-one stage codes do not depend on enum ordinal conversion.
Encoding rejects an empty receipt; decoding checks code width, nonnegative
bounded attempts and known stage codes before narrowing, then validates the
same cause invariants. An aborted search remains without a native failure cause
after a round trip.

The private session accessor requires Ready plus checked retired owners/ledger
and reprojects the retained coordinator/child metadata before copying. Active,
quarantined, empty and mismatched diagnostic state is not exportable. The returned
primitive value does not reference the session, so the next checked prepare can
reset the old launch without altering a caller's captured snapshot.

Pure payload and extended session fixtures cover copying/reuse, mismatch,
active/quarantined rejection, empty receipts and wide aliases; all are unrun.
This is cause transport, not a full diagnostic/error-message schema or a new
bytecode format. Follow-up source now retains bounded owned executable-context
snapshots and provides an opt-in ProcessError.LaunchFailure declaration. The
dormant private session adapter encodes twelve scalar/byte-array fields into the
enclosing run's existing RuntimeValue pool after canonical retirement, then
publishes Raised metadata matching a named error guard. This private path does
not turn ordinary exits or reaped-child wait failures into launch failures.
See canonical-lint-acceptance.md for the field order and remaining provenance,
allocation/resource-memory/cancellation and compiler qualification obligations.
The default interpreter/bytecode/public launcher and lint port remain unwired;
diagnostic selection/rendering and observed parity are still open. No new runtime
value kind or generic catch rule was introduced. Codec/source-catch and separate
opt-in real-Machine fixture bodies are authored only, uncompiled/unrun. No compiler,
fixture, native operation or parity ran; originals and other agents' work are unchanged.

## Setup-inclusive clock handoff (source-only)

The dormant private prepared-launch entry now initializes its waiter clock
before process reservation, attribute setup, executable search and spawn.
Completion carries the original timestamp and the unchanged timeout into the
owned child's waiter. It does not subtract elapsed time into a remaining-zero
value, because zero means disabled, not expired. Missing clock initialization
on the normal Wait route instead requires canonical cleanup and fatal return;
it cannot silently restart the timer. Clock initialization failure also visits
the fatal completion dispatcher, rather than skipping potentially stale child
ownership or fabricating a native launch cause. The session is quarantined.

Zero timeout still takes the existing no-clock branch, preserving the smallest
lint wrapper's policy. The origin covers this private launch entry onward, not
earlier caller-side environment/vector preparation or session preparation.
Synchronous setup/spawn cannot be interrupted by this waiter: overrun is only
detected once those operations return. This is not a hard wall-clock bound.
Setup/search failures retain their launch cause; this change does not invent a
timeout-precedence rule for failed launches that never create a child.

The opt-in `test/fixtures/process_launch_error/clock_handoff.elisa` models a
finite deadline already expired during setup, the disabled-zero sentinel and
preservation of cleanup/missing-clock state. Its bodies make no native calls,
but its full-facade include requires separate compiler/RSS qualification.
It is authored only, uncompiled/unrun. Native timing, actual cleanup and public
launcher parity remain unqualified; no default facade was wired or original
script/caller changed. Compiler/process validation remains disabled.
