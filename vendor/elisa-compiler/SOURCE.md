# Vendored Elisa compiler sources

This directory began as a snapshot of the reusable Elisa-language portions of the
self-hosted Elisa compiler. It is the starting point for Elisascript's shared
frontend and native backend and now carries explicitly documented Elisascript
adaptations.

## Source

- Repository: `../Elisa-compiler`
- Commit: `e56d6f2d3612a855066596f13f027926e9dea016`
- Commit date: `2026-08-27T15:25:59+02:00`
- Commit subject: `refactor: drive lexer for loops with machines`
- Source worktree status when copied: clean

## Included

- `src/lexer`: Elisa lexer
- `src/parser`: parser and AST model
- `src/semantic`: name resolution, typing, effects, ownership, contracts, and diagnostics
- `src/backend`: existing LLVM backend and EASM support
- `elisacore_std`: runtime and standard-library sources required by the frontend/backend

All `.elisa` files in these source directories were copied with their relative
layout intact. Existing relative `include` paths therefore continue to work.

## Deliberately excluded

- The existing `elisac` driver: Elisascript will have its own `.elisascript` driver.
- The complete compiler test suite and generated build output: compatibility tests
  needed by Elisascript are copied separately under `test/lexer/elisa_compat` and
  `test/parser/elisa_compat`.

Elisascript-specific additions currently include explicit shebang handling,
call-shaped typed-literal parsing, nominal typed-literal builtins, and compile-time
typed-literal validation. Their rationale and tests are documented under `docs/`.
- Shell/Python build scripts: Elisascript should replace these rather than inherit them.

## Latest upstream source observation

On 2026-09-15 the latest self-hosted Elisa compiler source visible for a future
adapted refresh was `d6a693c0f724c05f7b71418658dd8bda95ba73b3` on the clean
`main` checkout at `/Users/torarinvikbjarko/Documents/Coding Projects/Elisa Projects/Elisa-compiler`.
It merges the recent catch-binder,
value-returning-tail, module-callee, private-extern, and stage compatibility
fixes on top of the extern-resource ABI and lowering work. This source is
materially newer than the vendored `e56d6f2d` snapshot, but the differences are
too broad for an unreviewed wholesale replacement.

The separate Go Elisa-core source checkout currently visible for the guarded
validation path is clean at `3a5520d8fd56b86c430f39518a261e9030fa72ec` on its
`main` branch at `/Users/torarinvikbjarko/Documents/Coding Projects/Go projects/Elisa-core`.
Its latest source commits align stage0 with value-returning and unannotated-void
function tails. The explicitly pinned `structpy-tree/compiler/bin/elisac`
path is absent in this workspace, and the old Elisa-core executable is a
different main-worktree artifact; no executable is claimed or launched from
either path. This immutable Go commit is the source reference for a future
explicitly authorized validation build; create a clean isolated checkout,
review it, and atomically update the validation pin before building.

That source is substantially different from this vendored `e56d6f2d` snapshot.
The vendored tree contains Elisascript-specific adaptations (including
runtime-size argument handling, backend attribute guards, and the local EDIR
path), so replacing it wholesale or copying optimizer files selectively would
silently mix incompatible compiler revisions. This directory remains the
known-compatible adapted snapshot until a deliberate refresh is completed.

The current adapted fixes are tracked separately from the snapshot identity:

- `07dfa7a9` / `0d92a608`: nested-module constant ownership and use-site lowering;
- `10fdfaa6`: catch-all error binders and implicit value-returning block tails.
- `2d44a99e`: short-circuit unequal `sview` lengths before the runtime byte walk,
  with a fallback for legacy non-aggregate lowering paths.
- `a584ab52`: traverse the existing symbol-name chains for enum and unique
  function-return lookups instead of scanning the full declaration table.
- `0d92a608`: materialize `sview` constants with both their global pointer and
  decoded length at use sites.
- `df144c9c`: skip the disjointness fixed-point scan unless the no-alias
  metadata feature is enabled.
- `c7c849c7`: return completed lexer token buffers directly from ordinary and
  span tokenization, while retaining the safe copy-out for lexer comment
  side-channel results.

These changes are limited to the vendored APIs and deliberately omit newer
backend files whose supporting tables are not present in `e56d6f2d`.

## Modification policy

Keep general Elisa language fixes suitable for both compilers in the upstream
Elisa compiler and refresh this snapshot deliberately. Elisascript-specific MIR,
bytecode, VM, effect-handler, scripting-library, and driver code belongs outside
`vendor/elisa`.
