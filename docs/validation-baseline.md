# Validation baseline

This is a read-only identity record for the development/validation boundary.
It is intentionally separate from execution evidence: compiler and test
execution remain disabled until the explicit reauthorization gate is opened.

Captured: 2026-09-14

## Elisascript worktree

- Repository revision before this baseline refresh: `f4128b6a0d9b955048dabd4a87cc7a179bfc17d2`
- Tracked dirty files: none
- Ignored local planning file: `IMPLEMENTATION_PLAN.md`
- Working tree policy: never commit the ignored plan or `.DS_Store` files

## Pinned compiler identity

- Compiler source checkout: `/Users/torarinvikbjarko/Documents/Coding Projects/Go projects/structpy-tree`
- Compiler source revision: `601f7bcd3de62877723ab7f5c5f9a502fb6ef9ae`
- Compiler source dirty files: none
- Compiler source branch: `codex/structpy-tree` (8 commits ahead of the checked remote `origin/main`, with no behind commits)
- Relevant optimizer commit: `f2e9e1b0` (`Lower identity-yielding state blocks without aggregate copies`)
- Compiler executable: `/Users/torarinvikbjarko/Documents/Coding Projects/Go projects/structpy-tree/compiler/bin/elisac`
- Compiler executable SHA-256: `51f5f5f1f33c65f71bb6a17acae8fcc45c74009ff27f6209a93a06ecd3d39b62`
- Compiler binary VCS revision: `601f7bcd3de62877723ab7f5c5f9a502fb6ef9ae`
- Compiler binary `vcs.modified`: `false`
- Compiler build toolchain: `go1.27.1`
- Executable format: Mach-O 64-bit arm64

The installed `~/.elisac` compiler and the Elisa-core main-worktree binary are
not permitted validation targets. The bounded wrappers refuse any executable
other than the exact canonical pinned StructPy `compiler/bin/elisac` and fail closed unless
`ELISASCRIPT_VALIDATION_REAUTHORIZED=1` is explicitly supplied.

## Vendored dependency and bootstrap chain

- Vendored Elisa frontend/runtime snapshot: `vendor/elisa-compiler/SOURCE.md`
- Vendored source commit: `e56d6f2d3612a855066596f13f027926e9dea016`
- Vendored source status at copy time: clean
- Bootstrap chain: vendored Elisa frontend and runtime sources → pinned local
  StructPy compiler executable → Elisascript source/IR/bytecode/interpretation
  pipeline
- No package lockfile or generated compiler artifact is part of this worktree;
  those identities must be added before a release-qualified reproducible build.

## Host

- Operating system: macOS `26.6.2` (Darwin `25.6.0`)
- Architecture: `arm64`
- Validation state: suspended; the local compiler was rebuilt from the clean
  source checkout and its embedded metadata was inspected, but the Elisa
  compiler itself and all tests/validation scripts remain unrun

The checked-in wrappers require an absolute `setsid` helper, launch each future
compiler in a private process group, sample aggregate RSS across the process group
and currently discoverable descendants, and retain descendant snapshot cleanup
as a fallback. This is best-effort observation, not containment: a double-forked
process that leaves the group and reparents may evade both snapshots. The scoped
emergency stopper signals only private child groups found in its verified
snapshot. Per-identity compiler logs and sidecar run manifests are retained under
the ignored `.validation/` root with a 1 GiB sampled per-identity log budget.
This is a static contract change only; no wrapper or compiler process was
launched for this record, and synthetic watchdog coverage remains outstanding.

This record must be refreshed after any compiler-source, executable, vendored
snapshot, host-platform, or Elisascript revision change. It is metadata, not a
claim that the G0 execution gate has passed.
