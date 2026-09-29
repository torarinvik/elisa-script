# Elisa package build wrapper: declarative recipe foundation

Real reference: `../elisa-pkg/scripts/build.sh` (35 lines). The unchanged
`reference.sh` snapshot has SHA-256
`08ab3b1259c44e33276970c2cb2515d8d72f213fce3f34980087986e02ad156c`.
Model: `src/runtime/elisa_pkg_build_model.elisa`, public `EsPkgBuildPlan` module.
Pure source fixtures: `test/script_parity/elisa_pkg_build_plan_test.elisascript`.
The original script and its callers are unchanged.

This is a build-plan model, **not an executable port or accepted replacement**.
No compiler, shell reference, fixture, probe or parity process has run. The
model's types, namespace visibility and syntax still require compiler validation.

## Directory and environment contract

`Inputs` takes already-resolved project root, compiler checkout and caller cwd
spellings. A future host adapter must resolve the project directory first, then
read `ELISA_COMPILER_ROOT`, then resolve that directory relative to caller cwd.
Both reference `cd` operations are command substitutions: they do not change
the parent shell's cwd. Preserve Bash `pwd` spelling and command-substitution
newline handling rather than silently replacing them with realpath semantics.
Resolution failures occur before executable/object checks; the model does not
perform these host operations or reproduce their diagnostics.

Unset or empty `ELISA_COMPILER_ROOT` yields status 2 and the exact fixed missing-
root diagnostic. Unset/empty stage1, wrapper and runtime overrides select the
compiler-root suffixes in the reference. Explicit relative overrides remain
relative to caller cwd. Do not normalize repeated slashes or expand wildcards,
shell substitutions, spaces or environment references in these values.

The command argv is exactly `-emit`, `exe`, `-o`, `<project>/build/elisapkg`,
`<project>/src/main.elisa`. Script arguments are ignored. The wrapper receives
the caller environment with only these child-local overlays:

- `ELISA_STAGE1_BIN`: selected stage1 path.
- `ELISA_ALLOW_STALE_STAGE1`: raw nonempty override, otherwise `0`. This is an
  opaque string, not a boolean validated by this script.
- `ELISA_RUNTIME_OBJ`: selected runtime path.

In particular, do not replace the inherited raw `ELISA_COMPILER_ROOT` value
with its resolved spelling. Do not temporarily modify the parent environment.
All three streams are inherited, with no script-imposed deadline. The wrapper
runs in caller cwd, not the project or compiler checkout.

## Required host workflow, not yet implemented

1. Resolve directories and construct the recipe as above.
2. Check wrapper executability, then stage1 executability, then runtime regular-
   file presence. Report only the first failing predicate, status 2; the stage1
   failure also prints its note. `Availability` supplies these facts, not file
   access. Match Bash `-x` and `-f` symlink/permission behavior; do not add a
   regular-file predicate to either executable check.
3. Run the equivalent of `mkdir -p <project>/build`. On failure, do not start
   the wrapper or print success. Existing non-directory and permission cases
   need host-specific status/diagnostic qualification.
4. Start the wrapper with the recipe's argv, cwd, environment and stream policy.
   On ordinary nonzero exit, propagate status without printing success.
5. Only on ordinary zero exit, emit `success_stdout` and return 0. That field is
   planned output, not evidence of compilation or an output-file existence check.
   Reference stdout-write failure and signal/spawn behavior remain unqualified.

The current registry implements `run_process_with_environment` and
`run_process_in_directory_with_environment` as capture operations followed by
exit-status extraction (`vendor/elisa-compiler/src/semantic/builtin_registry.elisa`).
They discard captured stdout/stderr; they are not suitable faithful executors
for this recipe. Capturing then printing later changes live streaming, stdin,
TTY and resource behavior. The current build executor's capture-only subset
also does not provide this inherited-stream execution mode. A qualified child-
environment streaming host primitive/adapter is required before adding a runnable
Elisascript wrapper. Do not hide the original shell script behind a process call.

## Bounds and authored fixtures

The model accepts at most 4,096 bytes per supplied text field and rejects NUL.
Directory contexts must be nonempty absolute spellings; the model does not
prove they exist or are normalized. This is an explicit model admission policy,
not arbitrary-input Bash parity, an OS PATH_MAX check, or an RSS guard. Derived
paths include appended suffixes and can exceed 4,096 bytes; host failures on
those paths remain the adapter's responsibility. Public recipe/fact structs
are data, not authorization to launch processes or trusted filesystem receipts.

Authored pure fixtures pin default and explicit-empty overrides, paths with
spaces/metacharacters, exact argv and overlay vectors, caller cwd, inherited
streams, no timeout, literal relative overrides, opaque stale values, first-
failure ordering and stage1 diagnostics, missing/invalid contexts, root-directory
double-slash spelling, NUL rejection and the override byte-budget boundary.
These are independent literal expectations, not observed passing tests.

## Future qualification

After explicit execution reauthorization, use isolated temporary sibling
project/compiler/caller trees and a separately qualified, pinned native dummy
wrapper. Its stage1 and runtime files must be inert fixture assets: the wrapper
must never invoke a compiler. Observe exact argv/cwd, absent-versus-empty env,
binary stdin/stdout/stderr, normal zero/nonzero statuses and before/after world
state independently for both programs. Check parent cwd/env remain unchanged.
Success and failure cases must independently verify build-directory creation
and success-message presence/order, not merely agreement between candidates.

Include each preflight combination, nonexistent/compiler-root permission errors,
relative overrides, symlinks, roots containing spaces/newlines, existing build
directories/files, mkdir failure, inherited unrelated variables and raw compiler-
root env, ignored caller args, child stream visibility and broken stdout. PWD,
Bash shell-option/echo behavior, host permissions, races, spawn and signal/job-
control semantics require separate explicit qualification.

Use explicit opt-in, bounded fixtures/captures, functioning process-tree RSS/time
containment, pinned reference/launcher/probe identities and recorded-path cleanup.
Do not build the real package, modify live compiler output or interfere with SSH
or another agent's processes. Any later compiler validation must use the approved
local checkout, never the installed or main-worktree compiler; pin its latest
explicitly selected artifact and provenance before execution. Keep the original
until executable workflow parity has actually been observed safely.
