# Elisascript continuation policy

This record is the semantic contract for dynamic effect handlers and captured
continuations. It is deliberately independent of a particular interpreter,
bytecode layout, JIT, or native ABI. A backend may reject a form that it cannot
implement, but it must not assign a different meaning to a form it accepts.

## Policy selection

- A handler is `Terminal`, `Linear`, `Affine`, `MultiReplay`, or `MultiClone`.
- Source handlers default to `Linear` unless an explicit policy is written in
  the handler declaration. Hosts must provide the same policy in a verified
  descriptor; policy is never inferred from an operation name or callback type.
- `Terminal` handlers cannot resume. `Linear` permits at most one resume;
  `Affine` permits zero or one resume. `MultiReplay` and `MultiClone` permit
  repeated resumes only when every capture is statically `Unrestricted` and the
  verifier/runtime continuation budgets are available.
- Multi-shot aggregate captures are currently rejected: declared array/map
  captures produce `UnsafeMultiShot` during IR verification, and legacy
  descriptors are rejected with `InvalidContinuation` at runtime. A future deep
  clone protocol must be explicit, recursively typed, and versioned before this
  restriction is relaxed.

## Resumption semantics

The initial stable resumption is typed tail resumption. The callback's return
value becomes the value of the suspended `perform`; callback instructions after
`resume` are not implicitly executed as a second continuation. A future
ordinary-resumption form must be separately typed and cannot change the meaning
of existing tail-resume source.

| Event | Terminal | Linear | Affine | MultiReplay/MultiClone |
|---|---|---|---|---|
| zero resumes | handler result/abort | suspended computation is abandoned after cleanup | callback completes without resuming | callback completes; retained snapshot is reclaimed |
| first resume | `InvalidContinuation` | enters the suspended suffix once | enters the suspended suffix once | enters a fresh bounded replay/clone suffix |
| duplicate resume | `InvalidContinuation` | `InvalidContinuation` | `InvalidContinuation` | allowed until the per-continuation budget is exhausted |
| missing callback return | handler error/abort | callback failure propagates | callback failure propagates | callback failure propagates and private replay state is reclaimed |
| resume after scope exit | `InvalidContinuation` | `InvalidContinuation` | `InvalidContinuation` | `InvalidContinuation` |

The callback payload and resumed value must match the operation declaration. A
handler cannot resume an operation with a value selected only from the expected
expression type, and a clause for `Family.Operation` never handles another
operation in the same family.

## Handler stack, reentrancy, and cleanup

Handlers are dynamically installed on the call stack. Lookup searches the most
recent compatible exact-operation clause; an empty-clause handler is an explicit
whole-family mask. Reentrant effects from a callback search the callback's
current dynamic stack, so an inner handler can shadow an outer handler without
mutating the outer descriptor.

The suspended frame owns its handler delimiters, error guards, active call-chain
suffix, captured values, and cleanup obligations. Cleanup runs exactly once on
normal return, handled error, abort, cancellation, timeout, `break`, and
`continue`. A cleanup failure replaces a successful result with the declared
cleanup error; it never silently resumes a consumed continuation. Retained
multi-shot snapshots are reclaimed after the callback and all private replay
suffixes return.

Each captured frame also retains a bounded snapshot of its active error guards,
including the handler depth at which each guard was installed. If a resumed
suffix raises a recoverable failure, its own restored guards are searched first;
when none match, the failure remains active while replay advances through
suspended callers from nearest to outermost. The first matching caller guard
unwinds to its saved handler depth and transfers to its recovery block. Fatal
failures bypass this search. Guard spans and handler depths are validated before
replay, and every guard-pool suffix is reclaimed with the other frame storage.

## Cancellation, escape, and budgets

Cancellation is cooperative inside the VM and enforceable at blocking host
boundaries. It unwinds handlers and resources before reporting the cancellation
error. A continuation cannot escape its owning dynamic handler scope, be resumed
from another run, or be resumed after its resource ledger has closed.

The stable profile bounds copied values, replay frames, handler names, active
call/handler depth, and resumes per captured continuation. Counter arithmetic is
checked before increment; malformed spans are validated before indexing; budget
exhaustion is `InvalidContinuation`, not a wraparound or a successful partial
resume. Each saved frame carries independent starts and counts for its SSA-id
and runtime-value pools; the counts must agree, but either pool may have a
different prefix length. Cleanup truncates each pool to its own saved start, so
reclamation cannot expose or retain a suffix merely because two pools happened
to have equal lengths. The current limits are implementation policy and may be
lowered by a run resource policy, never raised implicitly by a backend.

## Compatibility and evidence

The reference interpreter and direct-bytecode facade must share these outcomes.
JIT/native backends must either implement the same contract or reject the
unsupported policy before execution. Required evidence includes zero/one/
duplicate/missing/late resumes, nested and recursive handlers, reentrant callback
effects, cleanup during cancellation, partial replay failure, and exhaustion at
zero, one, exact-limit, and one-over boundaries. Until that evidence exists,
multi-shot policies remain experimental and are unavailable in the stable
release profile even though their verified IR/runtime guards are present.
