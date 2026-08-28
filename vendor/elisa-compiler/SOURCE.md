# Vendored Elisa compiler sources

This directory contains the reusable Elisa-language portions of the self-hosted
Elisa compiler. The snapshot is the starting point for Elisascript's shared
frontend and native backend.

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
- Compiler tests and generated build output: Elisascript will add focused parity and
  differential tests separately.
- Shell/Python build scripts: Elisascript should replace these rather than inherit them.

## Modification policy

Keep general Elisa language fixes suitable for both compilers in the upstream
Elisa compiler and refresh this snapshot deliberately. Elisascript-specific MIR,
bytecode, VM, effect-handler, scripting-library, and driver code belongs outside
`vendor/elisa`.
