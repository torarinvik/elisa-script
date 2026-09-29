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
configuration and destruction need explicit resource receipts, including setup
failure and uncertain destruction; no owner adapter is implemented here yet.

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

Next implement the attribute-owner/parent-spawn integration, then source/IR/
verifier/interpreter/bytecode entry points and UI CC/package wiring. Synchronous
spawn failure versus normal child statuses, merged PATH and inherited binary
streams need independent native probes under explicit reauthorization plus real
process-tree RSS/wall-time containment. Original scripts/callers, SSH and other
agents' changes remain untouched. No execution permission is granted here.
