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

On 2026-09-20 the latest self-hosted upstream `main` observed is
`a51f3dd710dccde137141a41ce67b878f1181872`. The local self-hosted checkout is
at `43f7ebed53cf34512db7b602be345d0122bdcf3b`, two commits ahead of that
upstream ref, with unrelated in-progress work left untouched. The vendored
compiler remains the adapted `e56d6f2d` snapshot; the compatible analyzer
optimization from `43f7ebed` is recorded below. Since
`5329edfdbefa27b5c1c51253da0073256ed51058`, the source adds many semantic
lookup-index optimizations and compiler correctness/diagnostic fixes. The
differences are too broad for an unreviewed wholesale replacement.

The separate Go Elisa-core source checkout was observed clean on `main` at
`c447c2ce0c68d1aacd64fa8c4a1d6deece01f344` on 2026-09-25. Its cached
`origin/main` is `d4ce4c81980f2f25d4756b24a82a36ea0ad0eaf9` (last commit dated
2026-09-23), making the local source 27 commits ahead of that cached ref. This
is a local comparison, not a claim about current remote `main`; no fetch was
performed. The checkout includes later closure/effect and captured-view
correctness work. Its compiler binary is at
`Go projects/Elisa-core/compiler/bin/elisac`, while the validation wrappers'
explicitly pinned `Go projects/structpy-tree/compiler/bin/elisac` path is absent
in this workspace. The Elisa-core binary was not executed or substituted for
that safety pin. These source revisions are reference points for a future
explicitly authorized refresh/build review, not an authorization to launch a
compiler; a clean isolated checkout and an approved validation-pin update are
still required.

That source is substantially different from this vendored `e56d6f2d` snapshot.
The vendored tree contains Elisascript-specific adaptations (including
runtime-size argument handling, backend attribute guards, and the local EDIR
path), so replacing it wholesale or copying optimizer files selectively would
silently mix incompatible compiler revisions. This directory remains the
known-compatible adapted snapshot until a deliberate refresh is completed.

The current adapted fixes are tracked separately from the snapshot identity:

- `07dfa7a9` / `0d92a608`: nested-module constant ownership and use-site lowering;
- `10fdfaa6`: catch-all error binders and implicit value-returning block tails.
- `a545f605`: apply the implicit non-void function-tail return contract in the
  semantic initializer pass, so mismatched final expressions are diagnosed
  before IR lowering.
- `26cf09a9`: carry expected types through scoped expression-block tails and
  restore their local type scope after checking; terminating block statements
  do not cause an unreachable tail to be type-checked.
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
- `187a33ef`: resolve value-block outer-name queries through the existing
  collision-safe symbol-name chain instead of scanning every collected symbol.
  The chain preserves declaration insertion order and still compares the full
  name at each row, so the original first-match behavior is retained. This
  optimization uses the already-adapted `symbol_chain_head` and
  `symbol_name_next` index; it does not import the newer compiler's additional
  semantic index structures.
- `65842568`: use the same indexed declaration lookup when enum-tag analysis
  determines whether a parameter type is a struct, replacing a recursive
  declaration-tree scan for each parameter. The exact symbol name and
  `SymbolKind.Struct` are rechecked.
- `41d1e229`: use the indexed declaration lookup for positional-construction
  checks instead of scanning the full symbol table for every call. Exact name
  and kind checks preserve the previous admission rule.
- `7e6dde06`: use the already-populated `catch_match_lines` index when the
  catch out-of-set pass distinguishes catch matches from ordinary matches,
  instead of rescanning all parser annotations for each match.
- `15c54315`: fold character literals in integer global constants through the
  vendor's existing `parse_char_literal_code` helper. The `handled` flag is
  set only when that shared decoder accepts the literal, so unsupported forms
  still decline constant folding rather than becoming a guessed integer.
- `44a9cf62`: recognize empty and positional-only structs in the shared named
  struct diagnostic predicate used by both named-type mismatch and invalid
  struct-cast checks, querying declaration symbols rather than requiring a
  struct-field row. The semantic suite now has a focused empty-struct initializer
  regression; validation was not run under the safety hold.
- `d7aead96`: mirror the WebAssembly memory-intrinsic overload correction in
  the compatible declaration backend. `memory.grow` and `memory.size` are
  overloaded by their i32 result, not by their two source parameters, so the
  declaration helper now passes exactly one overload type. The newer
  freestanding component-runtime string helper is not present in this snapshot
  and remains intentionally unmerged.
- `43f7ebed`: continue out of `cpu_check_declarations` immediately when
  `cpu_facts_unclean` says the approximate call-precondition facts are not
  modeled. The vendor already skipped `cpu_walk` in that case; this moves the
  branch before per-function fact tables and scans are allocated while
  preserving diagnostics. `test/compiler_compat/unclean_precondition_skip.elisa`
  records the expected contrast: the unclean caller is suppressed and the
  clean caller still contributes its warning. The fixture was not executed.

These changes are limited to the vendored APIs and deliberately omit newer
backend files whose supporting tables are not present in `e56d6f2d`.

## Modification policy

Keep general Elisa language fixes suitable for both compilers in the upstream
Elisa compiler and refresh this snapshot deliberately. Elisascript-specific MIR,
bytecode, VM, effect-handler, scripting-library, and driver code belongs outside
`vendor/elisa`.
