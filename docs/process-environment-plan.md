# Parent-prepared streaming environment overlays

Status: source-only preparation layer, not an enabled process primitive.
`src/runtime/process_environment_plan.elisa` introduces the pure
`EsProcessEnvironmentPlan::prepare` boundary needed by a streaming child-only
overlay runner. No snapshot of the live environment, fork/exec, host mutation,
compiler, native probe or runtime fixture has been executed for this layer.

The current `run_process_with_environment` family still lowers through capture
and discards captured streams. It is not a streaming replacement. The existing
capture implementation applies `setenv` after fork; the new streaming runner
must not copy that path. In a potentially multithreaded host, allocation or
environment mutation between fork and exec can be unsafe. Instead, prepare all
owned environment, argv and executable-search bytes in the parent, then pass
explicit vectors to execve without changing the ambient environment.

## Implemented data boundary

The caller supplies a validated, sealed `EsEnvironment::EnvironmentSnapshot`,
a set-only overlay of `EnvironmentEntry` records, and an executable name/path.
Ambient records are never modified. A separate snapshot is constructed from
live entries, preserves their order, replaces matching values in place, and
appends new names in overlay order. Inactive ambient tombstones are excluded.
Duplicate overlay names and requested unsets are errors, not coalesced or ignored.
Existing name/NUL, entry-count and aggregate-byte rules remain authoritative.

Every emitted environment entry owns a fresh `name=value` byte array with one
terminal NUL. No emitted field borrows a libc environment pointer or aliases the
ambient entry array. `Prepared.environment_bytes` includes equals signs and C
terminators and is checked against the merged snapshot's accounting receipt.
The future host still constructs a pointer vector with an extra null pointer.

Executables containing `/` yield one literal path candidate without consulting
PATH. Bare names use the **merged child's PATH**, never the original PATH after
an override. Colon-component order and empty components are preserved, including
leading/trailing/repeated colons and present-empty PATH (caller-cwd search).
Relative directories, spaces and lexical spelling remain data; no shell quoting,
expansion, stat call, cwd change or permission check happens here.

Absent PATH requires an explicitly provided `AbsentPath` policy. The planner
does not silently invent the platform's default or confuse absence with empty
PATH. The future host must qualify and supply its default-search policy in the
parent (for example a separately validated platform query), or report an error.
Forged absent-policy payloads and NUL/oversized policy values are rejected.

Candidate C strings are owned and bounded to 4,096 bytes including terminator;
PATH text admits 65,536 bytes, at most 4,096 search candidates and 1 MiB total
candidate C-string storage. Environment limits come from the shared snapshot
contract (256 entries and 64 MiB terminated text). These are explicit admission
policies, not OS limits, arbitrary-input shell parity or a working RSS guard.
The host must also budget snapshot + environment + argv + search allocations
together; individual ceilings do not establish an aggregate memory bound.

## CC policy for the fourteen-line UI gate

`EsUiCodecBuild::compiler_environment(configured, present)` now models the
reference's exported-variable behavior. Inherited empty CC needs one child-only
set operation, `CC=clang`, for **both** compiler and test. Absent CC stays absent
in child env; nonempty inherited CC stays unchanged. Forged absent/nonempty
input and NUL/oversized configured values are errors. Executable defaulting and
child-environment defaulting are separate decisions.

The candidate has not been wired to this policy yet: it still leaves inherited
empty child CC empty. Do not globally mutate parent CC or switch to the existing
capture-and-discard helper just to conceal this discrepancy. The independent
UI probe intentionally observes it. Package builds need the same streaming
overlay capability for their child-only compiler/build settings.

## Authored fixtures and remaining integration

Pure fixtures cover ambient immutability, owned emitted bytes, replacement/new
entry order, embedded equals in values, merged PATH selection, empty/relative
PATH components, direct executables without PATH, explicit absent-PATH policy,
unsealed/forged inputs, duplicates/unsets, invalid names and path/search limits.
Separate CC fixtures distinguish absent, empty and literal executable values.
They have not compiled or run and do not qualify a native environment snapshot
or process launch.

Next required integration is a bounded, owned native ambient-snapshot bridge
with concurrent setenv/unsetenv/putenv excluded for its entire borrow/copy. Then
build argv/envp/candidate pointer vectors in the parent and implement the narrow
streaming executor with inherited fd 0/1/2, no output capture/discard and no
parent-environment mutation. Keep the normal process resource/group/deadline
ledger, validate all shapes/limits before fork, and prohibit allocation,
setenv/unsetenv, callbacks, formatting and implicit shell fallback in the child.
Permission/missing/ENOEXEC/PATH/default-search, signal and exec-status policies
must be qualified explicitly rather than inferred from planned strings.

Only then add source builtin/IR/verifier/interpreter/bytecode contracts and wire
both UI stages to the same selected overlay. Qualify native/compiler dependency
closures, parent-state receipts and inherited binary stream behavior with the
independent prebuilt probes under explicit user reauthorization and real
process-tree RSS/wall-time containment. No compiler or parity run is authorized
by this document. Originals, SSH and other agents' pending work remain untouched.
