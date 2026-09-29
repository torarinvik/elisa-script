# Owned ambient environment snapshot: Darwin native bridge

Status: source-only, unwired and unqualified. No compiler, native adapter,
environment probe, fixture or process has run. This is not an enabled scripting
builtin, execution authorization, or a working concurrency guard.

`src/runtime/environment_snapshot_darwin.elisa` adds
`EsEnvironmentSnapshot::snapshot_darwin`. It uses `_NSGetEnviron`, whose local
macOS SDK `crt_externs.h` declares a `char ***` return. Three nullable Elisa
pointer layers describe the returned slot, its environment-vector value, and
the vector's string entries. Each layer is checked before dereferencing it.
Compiler parsing, nullable-flow handling, pointer indexing and ABI agreement
still require authorized qualification. The bridge is not included by the
portable runtime or any runnable script. Do not include it on Linux/Windows.

## Borrowing and ownership

The caller must exclude **all** environment mutation throughout acquisition,
traversal, copying and sealing: setenv/unsetenv/putenv, direct writes to environ,
and mutation of buffers installed by putenv. This source supplies no mutex and
cannot enforce that precondition. Call only in the parent before fork, never
in a post-fork child that might allocate or hold an inherited lock.

Only genuine host-provided, null-terminated vectors and C strings are admitted
as borrowed memory. Budgets do not establish pointer validity; forged/truncated
or concurrently invalidated pointers can fault before a language error.
Null slot/vector values raise MissingVector; a vector whose first entry is null
produces a sealed empty snapshot.

Each complete name=value plus NUL is copied into bounded owned bytes. The pure
decoder constructs separate owned name/value arrays, returning no libc pointer
or borrowed host view. Sealed entries retain host vector order. Empty values,
extra equals in values, UTF-8 and non-shell-identifier keys remain literal.
Empty names, missing equals, interior NUL in pure input and duplicate names are
errors. Duplicates are not silently collapsed by Set. This rejects malformed
host environments rather than claiming every libc/Python ambiguity is preserved.

## Admission and receipts

Shared limits are 256 live entries and 64 MiB aggregate C-string bytes, including
equals signs and NULs. At most 257 pointers are inspected. The extra pointer is
only a sentinel probe: a 257th nonnull entry raises the count error without
reading its string. Each string read is bounded by the remaining aggregate bytes,
including its NUL; no extra byte beyond that budget is probed. Exhaustion raises
the text-limit error, never a partially sealed snapshot.

`environment_snapshot_model.elisa` provides pure decode_entry, append_entry and
from_entries operations. Appending requires a validated Building snapshot;
count, aggregate bytes, encoded shape and duplicates are checked before mutation.
Sealing uses the existing accounting validator. Receipts match serialized bytes.

These are admission rules, not OS limits or RSS containment. Copy buffers,
name/value storage, growing-array capacity, planner copies, argv/envp/search
vectors and allocator overhead all contribute to peak memory. The executor must
budget their combined live allocations, and validation needs a qualified outer
process-tree RSS/wall-time guard.

## Remaining qualification and integration

Authored pure fixtures cover first-equals decoding, ownership after source
mutation, literal keys/values, empty snapshots, malformed strings, duplicates,
exact 256-entry admission, overflow and unchanged state after a rejected append.
They have not compiled or run. Native null-layer/sentinel/byte-limit behavior,
allocator behavior and ABI lack observed evidence. Qualify with a bounded native
fixture after explicit user reauthorization; do not mutate the live project's
environment or start a compiler loop.

After ABI qualification and an enforced borrow-exclusion policy, pass the owned
snapshot to EsProcessEnvironmentPlan::prepare, build terminated pointer vectors
in the parent and add an inherited-stream execve adapter with process ledger,
group and deadline handling. Define PATH/exec errors explicitly. Then wire both
UI stages to the empty-exported-CC overlay and the package builder to its settings.
Capture/discard helpers, parent mutation and post-fork setenv are not substitutes.
The UI CC gap remains open. Originals, callers, SSH and other agents are untouched.
