# Dormant Darwin64 process-scalar ABI qualification fixture

Status: authored source only. Neither source has been compiled or executed.
This fixture is a prerequisite candidate for the smallest lint wrapper's
process bridge, not passing evidence or authorization to run validation.

`probe.c` exports four uniquely prefixed synthetic functions. It has no main,
constructor, mutable global, allocation, I/O, environment access, process
creation, wait or signal operation. It does not define/interpose fork, waitpid,
kill or any libc symbol. The only externally supplied write target is the
four-byte scalar status slot; the pointer-table oracle is read-only.
Static assertions select a 32-bit C int/pid_t and 64-bit pointer profile.

The independent C-to-C control checks the synthetic function against literals
before any Elisa-side observations are admitted. The synthetic calls return
-1, INT_MIN and INT_MAX and write three independent status patterns. Invalid
requests/options preserve the slot; the C control also checks its null guard.
These are ABI scratch patterns, **not** claims about real waitpid error/status
behavior (real failed waits do not supply a usable status).

`qualification.elisa` declares the functions privately with i32 scalar types,
checks the C control, checks the twelve-byte little-endian guard layout, then
passes the mutable i32 field. It independently checks signed widening to
Elisa int and both neighboring u32 guards after each write. Binary layout
expectations are literal bytes, not computed by the C function or shared model.
No raw function is exported from the fixture namespace.

The third test constructs launch storage and tables with the real
`EsProcessLaunchVectors` builder: argv is `./tool`, an empty argument and NULL;
environment is `X=` and NULL; candidates are a separately owned `./tool` buffer
and NULL. The C oracle reads fixed three/two/two pointer slots, checks identity
against four separately supplied owned buffers, then reads at most eighteen
literal bytes from those buffers. It has no unbounded string scan. This checks
the exercised C pointer stride/view and NULL encoding, not just equal sizeof.
The independent C control rejects a NULL substituted for the empty argument,
a missing environment sentinel and an incorrectly aliased candidate. The Elisa
fixture independently checks one invalidation/restoration between calls. No
buffer/table is mutated while C is reading it, and all storage stays retained.

## Future admission requirements

Execution remains disabled until the user explicitly reauthorizes validation.
Then first qualify external RSS/time containment and the selected local
compiler, without replacing or invoking the main-worktree/installed compiler.
Build the C object separately as C11 against the selected Darwin64 SDK, record
its tool/source/object identities, and link it only into this explicitly selected
fixture. No fixture should build its own dependencies or silently discover an
unqualified object/library. Keep the selected SDK/target/compiler/link closure
in the qualification receipt and require all three tests to pass; a compiler/link
failure or one missing test is not ABI qualification.

Record these exact test entries, not merely a successful test-runner exit:

- `native_scalar_c_known_answers_are_admitted_first`
- `native_scalar_status_slot_preserves_guards_and_signed_results`
- `native_builder_tables_have_the_independent_c_view`

This file deliberately is not named `*_test.elisa` and lives under fixtures:
ordinary source-only/unit-test discovery must not acquire a new native link
dependency or launch it automatically. The separately linked entry is a narrow
native fixture, not an interpreted source-parity test.

Passing it would establish only the exercised scalar-call/status-slot/table
cases for that exact build. Actual process bridge symbols/aliases, generated
wrapper declarations, native wait semantics/errno, larger/malformed pointer tables,
lifetimes/effects, child async-safety, external reapers, process groups and
durable unresolved-child ownership still require independent qualification.
Do not mark smallest-script parity accepted or switch/delete original scripts
because this fixture passes. No SSH or other agent run is part of this fixture.
