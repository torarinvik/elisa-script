# Streaming child exec kernel: Darwin

Status: source-only private kernel, not integrated, compiled or executed.
It provides no public launcher, scripting builtin or fork operation. Existing
run_process and capture/environment helpers remain unchanged. No compiler,
child, native probe, fixture or parity run was launched while authoring it.

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
tool returning those statuses: a parent-visible close-on-exec error channel is
still needed to report typed spawn failures and group-admission failure. Do not
publish this kernel as a checked process API without that distinction.

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
