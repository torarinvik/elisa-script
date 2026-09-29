# Elisa-LSP compiler-root helper: typed migration contract

Real source: `../Elisa-LSP/scripts/compiler_root_env.sh` (18 lines), SHA-256
`f8035e67548592d33577988dc3315a8c9f2f423fa56daa03906b65457dd3524a`.
It is a sourced Bash function, not an executable program. The original and
`../Elisa-LSP/test/compiler_root_env_test.sh` remain unchanged.

The source-only companion is
`ports/Elisa-LSP/scripts/compiler_root_env.elisascript`; its pure selection
module is `src/runtime/compiler_root_env_model.elisa`. When deployed beside the
real helper, copy the include closure in the same relative tree or adapt the
include path intentionally. This repository's port path is a staging layout,
not an installed Elisa-LSP script. No compiler, Bash, fixture or candidate ran.

The original uses `ELISA_COMPILER_ROOT` when nonempty; unset or exported-empty
selects `<given LSP root>/../Elisa-compiler`. It resolves an existing directory
physically, following symlinks as `cd && pwd -P` does. A missing or nondirectory
override is returned verbatim, even if relative or shell-shaped. A selected
directory that fails resolution returns status 1 with a diagnostic. The function
exports the resulting value in the same Bash process; it emits no success
stdout. Relative existing directories resolve against the caller's cwd.

`EsCompilerRootEnv::select` reproduces the spelling selection without host
access. `EsLspCompilerRoot::resolve` applies the directory test and physical
resolution, returning a typed value for another Elisascript build task to put
into its own child environment. The candidate CLI prints that value plus LF;
it does **not** mutate the invoking shell's environment and is not a drop-in
replacement for `source`. The CLI ignores extra arguments and derives its
default LSP root from its own script location, so focused parity fixtures
should call `resolve` with an explicit root or stage the script beside the
original. A Bash caller must not consume this as though it had sourced it.

The companion admits selected path spellings shorter than 4,096 bytes and
rejects embedded NUL. Those are typed resource/host-path policies, not exact
arbitrary-input shell parity. It checks the default suffix budget before
concatenation. Missing/nondirectory spelling and metacharacter bytes remain
literal; no shell evaluates a constructed string. Host `is_directory` errors
follow Bash's false `-d` branch, while failure to physically resolve a
directory remains an error. `path_real` and `pwd -P` need host qualification
for symlink, permission and concurrent filesystem changes.

Pure fixtures in `test/runtime/compiler_root_env_model_test.elisa` pin
unset/empty defaulting, relative and verbatim missing overrides, trailing
separator spelling, exact 4,095-byte selected boundaries, NUL rejection and
the default-suffix overflow. They have not compiled or run. The sourced-function
contract still needs an independently admitted, isolated public-launcher
matrix: copy the unchanged Bash helper, source it in a fixed test wrapper,
print its resulting variable only as an observation, and compare to a qualified
Elisascript candidate with identical cwd/environment and exact expected bytes.
Include existing real/symlink directories, missing paths, unset/empty values,
relative paths, spaces and metacharacters. Keep an outside sentinel and bounded
cleanup; never run either side against a live compiler checkout. The original
parent-export behavior is an interface difference to address by converting
callers to typed values, not by claiming subprocess parity.
