# Validation baseline

> **2026-09-15 native launcher update:** The engine task authorized bounded native
> integration work, and its check now passes. See [the validation record](engine-check-validation.md)
> for compiler fixes, installation, and test evidence. The historical pinned wrappers
> and their broader validation hold described below were not reopened.

This is a read-only identity record for the development/validation boundary.
It is intentionally separate from execution evidence: compiler and test
execution remain disabled until the explicit reauthorization gate is opened.

Initial baseline captured: 2026-09-14
Latest metadata recheck: 2026-09-16

## Elisascript worktree

- Repository revision before this baseline refresh: `44b57993b4e7fb6493855394fd3bd9712dab0bcc`
- Tracked dirty files: none
- Ignored local planning file: `IMPLEMENTATION_PLAN.md`
- Working tree policy: never commit the ignored plan or `.DS_Store` files

## Historical validation binary identity (safety-held; not the latest source)

The executable identity below is retained as the last approved wrapper baseline,
not as a claim about the bytes currently at that path. It predates the latest
committed compiler source recorded below and must not be described as a current
compiler build.

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
other than the exact canonical pinned StructPy `compiler/bin/elisac` and fail
closed unless `ELISASCRIPT_VALIDATION_REAUTHORIZED=1` is explicitly supplied.

### Current unqualified artifact observation

On 2026-09-15 the canonical path contained an ignored Mach-O executable with
SHA-256 `3624b7e4d7dc6009df5efe7e8c2ff5f8d074ad321a4b133cfd0d74ecce03933d`,
embedded binary revision `7900a37a2cdec0d8f32f90cb2d064c2ec5d41b9a`, and
`vcs.modified=true`. At the time of this observation the clean source checkout
was `e85e8282…`, so this artifact was already stale and failed the identity
checks; it is not launched or accepted for validation. A clean, immutable build
of the latest source remains required after explicit reauthorization.

## Earlier clean detached source snapshot

On 2026-09-15 a read-only audit found a clean detached compiler source snapshot
at `/private/tmp/elisa-compiler-debugger-c605b3fa`, revision
`c605b3faa516de7b2f4945a9ac4ccb21d78ae2e0`. It contains the newer shared typed
scalar lowering and duplicate-EDIR-lowering optimizations and is two commits
ahead of its `fd2cb3cf` upstream-main base. It has no built `compiler/bin/elisac`.
The pinned executable above therefore remains the only identity accepted by the
validation wrappers, but it is not claimed to represent this newest source.
Building or launching a compiler remains disabled until explicit
reauthorization and a bounded, reviewed build plan.

An earlier self-hosted source observation recorded
`565ccb2fd585d03f94457185376f526e1930b1cb` on clean `main`. Its recent history
included catch-binder and value-returning-tail fixes, nested-module constant
lowering, static-if module handling, and self-hosted extern-resource ABI support.
The vendored `e56d6f2d` tree is adapted, so this source requires a deliberate
compatibility refresh rather than a wholesale copy.

Latest self-hosted source recheck (2026-09-16; read-only): the clean `main`
checkout now resolves to merge commit
`d6a693c0f724c05f7b71418658dd8bda95ba73b3`, which adds module-callee, private
extern, catch-binder, value-tail, and stage compatibility fixes on top of the
previous ABI/lowering work. The vendored `e56d6f2d` tree remains the known-
compatible adapted snapshot; no compiler was rebuilt or launched.

An earlier Go Elisa-core source observation recorded
`e85e8282c7b8dc588ba2ba53f0912d98769b1f1a` on `codex/structpy-tree`. Its work
hardened extern boundary checks, owned native-resource contracts, and refreshed
IR artifacts on top of the earlier FFI, lowering, and region optimizations. The
immutable Go commit was the source reference for the guarded validation path;
the historical 601f7bcd executable identity is not claimed to represent it.

Latest Go source recheck (2026-09-16; read-only): the clean `main` checkout at
`/Users/torarinvikbjarko/Documents/Coding Projects/Go projects/Elisa-core`
resolves to `3a5520d8fd56b86c430f39518a261e9030fa72ec`, including stage0
alignment for value-returning and unannotated-void function tails. The
explicitly safety-pinned `structpy-tree/compiler/bin/elisac` path is absent;
the old executable in the Elisa-core main-worktree is stamped from a different
revision with `vcs.modified=true`, so it is stale and remains unlaunched. A
clean build from this revision still needs explicit reauthorization.

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
- Validation state: suspended; compiler source identities were inspected
  read-only, but the Elisa compiler itself and all tests/validation scripts
  remain unrun

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
