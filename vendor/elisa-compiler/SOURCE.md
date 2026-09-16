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

On 2026-09-16 the latest self-hosted Elisa compiler source visible for a future
adapted refresh was `5329edfdbefa27b5c1c51253da0073256ed51058` on the clean
`main` checkout at `/Users/torarinvikbjarko/Documents/Coding Projects/Elisa Projects/Elisa-compiler`.
It merges the recent catch-binder,
value-returning-tail, module-callee, private-extern, and stage compatibility
fixes plus wasm intrinsic/component-runtime corrections and target-machine
optimization-level matching on top of the extern-resource ABI and lowering
work. This source is
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
- `cb333aec`: short-circuit unequal `sview` lengths before the runtime byte
  walk and inline the public context equality wrapper, preserving the same
  semantics while avoiding a redundant call on the hot path.
- `142d9b03`: avoid routing unreachable-match empty-key checks through the
  C-string `strlen` bridge and pre-index declared protocol annotations before
  repeated unknown-interface lookups. Both are semantics-preserving source
  adaptations of the latest self-hosted semantic fast paths.
- `9bf231e6`: remove a duplicate parenthesized-subtree walk in the disjointness
  proof scanner; the first expression-shape dispatch already visits `Expr.Paren`
  exactly once, so the second traversal only repeated work.
- `cad39806`: anchor the companion `BraceMembershipMisuse` diagnostic at the
  actual set/dict initializer instead of the affine element or key type. This
  is a source-location-only correction; the primary affine diagnostic remains
  anchored at the rejected type argument.
- `5329edfd`: mirror the target-machine optimization-level API in the compatible
  backend snapshot. Optimized IR now has a level-aware target-machine entry
  point, while the existing two-argument helper remains an explicit O0
  compatibility path for metadata/report callers. The excluded upstream driver
  still owns the policy that selects the level; no executable was rebuilt or
  launched here.

These changes are limited to the vendored APIs and deliberately omit newer
backend files whose supporting tables are not present in `e56d6f2d`.

## Modification policy

Keep general Elisa language fixes suitable for both compilers in the upstream
Elisa compiler and refresh this snapshot deliberately. Elisascript-specific MIR,
bytecode, VM, effect-handler, scripting-library, and driver code belongs outside
`vendor/elisa`.
