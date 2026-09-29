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
