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

On 2026-09-15 the latest committed compiler source visible for a future isolated
refresh was `e85e8282c7b8dc588ba2ba53f0912d98769b1f1a` on
`codex/structpy-tree`. Its latest work hardens extern boundary checks, owned
native-resource contracts, and refreshed IR artifacts on top of the earlier FFI,
lowering, and region optimizations. The adjacent checkout is clean and has no
`compiler/bin/elisac`, so no executable is claimed or launched from it. This
immutable commit is the source reference for the next explicitly authorized
refresh; create a clean isolated checkout, review it, and atomically update the
validation pin before building.

That source is substantially different from this vendored `e56d6f2d` snapshot.
The vendored tree contains Elisascript-specific adaptations (including
runtime-size argument handling, backend attribute guards, and the local EDIR
path), so replacing it wholesale or copying optimizer files selectively would
silently mix incompatible compiler revisions. This directory remains the
known-compatible adapted snapshot until a deliberate refresh is completed.

## Modification policy

Keep general Elisa language fixes suitable for both compilers in the upstream
Elisa compiler and refresh this snapshot deliberately. Elisascript-specific MIR,
bytecode, VM, effect-handler, scripting-library, and driver code belongs outside
`vendor/elisa`.
