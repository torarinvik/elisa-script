# Streaming child exec kernel: Darwin

Status: source-only private kernel, not integrated, compiled or executed.
It provides no public launcher, scripting builtin or fork operation. Existing
run_process and capture/environment helpers remain unchanged. No compiler,
child, native probe, fixture or parity run was launched while authoring it.

The preferred Darwin integration is now the separate
[posix_spawn backend](process-spawn-darwin.md), based on the installed SDK's
documented synchronous no-child-on-error contract. This private fork/error-pipe
path remains unwired; do not enable both paths or claim its EOF/report-loss
ambiguity has been solved by the codec. Its source can support later bounded
fallback research without determining the preferred scripting backend.

`process_streaming_child_darwin.elisa` defines a private kernel in
EsProcessStreamingDarwin for the eventual inherited-stream executor. C int and
pid_t carriers are explicit i32; execve receives C-string and pointer-vector
views. The local SDK sys/errno.h supplied the Darwin errno constants. Native
signature/layout, compiler lowering, pointer-cast and child-path qualification
remain required before integration.

## Parent/child boundary

The future parent must prepare and retain owned launch storage plus admitted
nullable pointer tables, derive non-sentinel candidate_count, erase argv/envp
to their ABI views, and acquire the current thread's errno location before fork.
The child uses its fork-copied errno address; TLS/fork behavior must be qualified.
Raw candidate pointer indexing is bounded by the admitted non-sentinel count.
Zero/oversized counts and unexpected null entries terminate with status 126.

The child establishes its own group with setpgid(0,0), allowing one attempt plus
64 EINTR retries. It then calls execve on the precomputed candidates and explicit
envp, preserving inherited fd 0/1/2. No allocation, getenv, setenv, unsetenv,
PATH discovery, cwd change, capture, callback, formatting or shell fallback is
authored in this path. Errno is sampled immediately after failed execve. The
declared effects contain Blocking.IO and pointer casting, not Memory.Allocate
or Abort.Panic; that declaration is intent, not proof of generated async-safe
machine code. Qualify the native lowering and call graph before enabling it.

## Explicit search-failure policy

The shared pure EsProcessExecSearch policy advances on ENOENT or ENOTDIR,
advances while remembering EACCES, and stops on every other failure. Exhaustion
returns 127 if all failures were missing-path failures, or 126 if any candidate
was access-denied. Fatal errors return 126. ENOEXEC never selects a shell; E2BIG,
ENOMEM, EIO, ETXTBSY, EINTR and unknown failures do not disappear behind a later
candidate. This is an explicit kernel policy, not a claim of complete Bash or
platform execvp equivalence. Qualify actual errors and diagnostics separately.

The pure fixtures cover classifications, denied-then-missing order, exhaustion
and fatal statuses. They have not run. No native failure or successful exec is
claimed. Child-exit 126/127 is indistinguishable from a successfully launched
tool returning those statuses without a separate failure record. A source-only
record codec and child writer are now authored below, but parent pipe creation,
collection and lifecycle qualification are still needed. Do not publish this
kernel as a checked process API without those parts.

## Failure record and writer (source-only)

`process_spawn_failure_model.elisa` defines a fixed 16-byte local record: four
32-bit fields for ESF1 magic, phase, nonnegative errno and candidate ordinal.
The pure codec uses explicit little-endian bytes. The child writes a stack Frame
directly only under the future parent's qualified Darwin64 little-endian ABI
profile: 32-bit integer fields, expected offsets, sizeof(Frame)=16 and pointer
width eight. That profile is not currently enforced by a parent entry. A dormant
native-layout fixture and independent literal golden are authored but unrun.

Phases distinguish invalid preparation, group setup, a fatal exec candidate and
search exhaustion. Only a fatal exec record carries an ordinal less than the
admitted candidate count. Exhaustion reports a summary ENOENT/EACCES with the
no-candidate sentinel; it does not falsely attribute a remembered permission
denial to the last missing candidate. The parser rejects malformed magic,
phase/errno/ordinal combinations, negative wire errno, truncated records and
extra payload. The future parent reads at most 17 bytes to detect a 17th byte.

The child receives a private error-pipe write fd at least three, so no record
can overwrite inherited stdin/out/err. The parent must create it before fork,
set close-on-exec before any child can inherit it, retain the sole reader, close
the parent's writer and prevent unrelated writers/forks or fd rebinding during
setup. If initially closed stdio yields pipe fds 0/1/2, relocate them above two
and restore the original closed routes before fork. Pipe/close-on-exec creation
and owned descriptor/resource receipts are not implemented by this kernel.

The writer emits fixed stack data through write, with bounded short-write/EINTR
progress (at most 65 calls), no dynamic strings or allocations. Its ssize_t
carrier is isize. The record is below the local SDK's 512-byte PIPE_BUF, but this
does not prove pipe ownership, stack layout or runtime call-graph safety. Full
reporting failures exit 125; complete records preserve selected 126/127 statuses.
If the reader vanishes, SIGPIPE may terminate the child instead; no signal policy
is changed here. Host/report faults, partial records and asynchronous death need
typed parent handling rather than guessed success.

Empty EOF is explicitly PayloadState.Empty, **not exec confirmation**. A child
can die before reporting, and an unreported failure using status 125 collides
with a tool normally returning 125. The future parent must preserve unknown/
protocol-failure outcomes and define this conservative ambiguity explicitly;
it must not claim full status parity from EOF or reserve a tool status silently.
This source layer does not yet solve every exec-confirmation failure mode.
Pure fixtures cover record admission and goldens, not native pipe behavior.

## Remaining integration

Add the parent-side spawn/error channel and typed error ledger, pair parent and
child group admission, and reuse the existing runtime resource/deadline/wait/
termination machinery rather than writing another waiter. Preserve owned memory
and tables for the entire necessary lifetime. On every parent failure after
fork, terminate/reap the owned child and verify the chosen group cleanup policy
before releasing resources. Define descendant escape, signal propagation,
normal 126/127 statuses, exec failure diagnostics and timeout behavior explicitly.

Then implement source/IR/verifier/interpreter/bytecode contracts and wire both
UI codec stages to the same empty-exported-CC child-only overlay. The current CC
gap is not fixed by this kernel. The package builder likewise remains unwired.
ABI/snapshot/concurrency/native artifact qualification and independent inherited
binary-stream/parity fixtures require explicit user reauthorization plus real
process-tree RSS/wall-time containment. This document grants no execution
permission. Originals, callers, SSH and other agents' work remain unchanged.

## Native return/errno admission correction (source-only)

Group setup, exec and report writing now gate errno reads on exactly native -1.
Group setup captures its genuine failure in a caller-owned i32 output instead
of rereading errno after a boolean return; success or an unexpected native return
clears a prior EINTR observation. Only positive errno observations can populate
native failure frames. Unknown exec/group returns or nonpositive errno stop via
the existing unreported-failure exit, without fabricating an errno-based frame
or advancing PATH search from stale state. Unexpected negative write returns
likewise cannot retry on stale EINTR.

The shared pure observation predicate has authored boundary fixtures, all unrun.
No child kernel or C symbol was called. The unreported status 125 still collides
with a normal tool exit: empty/partial EOF and that status are not proof of exec
success or a uniquely identified failure. Parent protocol/ownership/group
handling and full generated child call-graph/ABI/async-signal qualification
remain open. The kernel remains private and unwired; neither source nor
bytecode/public launch behavior changed here. Execution remains paused.
