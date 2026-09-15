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

On 2026-09-15 the newest clean compiler source available for a future isolated
refresh was `/private/tmp/elisa-compiler-debugger-c605b3fa` at commit
`c605b3faa516de7b2f4945a9ac4ccb21d78ae2e0`, two commits beyond its
`fd2cb3cf` upstream-main base. Its recent commits include shared typed scalar
CoreIR lowering for EDIR and LLVM plus removal of a duplicate EDIR fallback.
That checkout is 879 commits ahead of the vendored `e56d6f2d` snapshot and has
a substantially different source layout. The vendored tree also contains
Elisascript-specific adaptations (including runtime-size argument handling,
backend attribute guards, and the local EDIR path), so replacing it wholesale
or copying the optimizer files selectively would silently mix incompatible
compiler revisions.

The c605 snapshot is therefore the required latest-source candidate for the
next explicitly authorized compiler refresh, while this directory remains the
known-compatible adapted snapshot. Development and validation records must
name the c605 revision when referring to the latest compiler; no executable is
claimed or launched from it until an isolated build, source review, and atomic
pin update are authorized.

## Modification policy

Keep general Elisa language fixes suitable for both compilers in the upstream
Elisa compiler and refresh this snapshot deliberately. Elisascript-specific MIR,
bytecode, VM, effect-handler, scripting-library, and driver code belongs outside
`vendor/elisa`.
