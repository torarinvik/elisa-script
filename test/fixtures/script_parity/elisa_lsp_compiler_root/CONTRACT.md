# Elisa-LSP compiler-root helper: typed migration contract

Real source: `../Elisa-LSP/scripts/compiler_root_env.sh` (18 lines), SHA-256
`f8035e67548592d33577988dc3315a8c9f2f423fa56daa03906b65457dd3524a`.
It is a sourced Bash function, not an executable program. The original and
`../Elisa-LSP/test/compiler_root_env_test.sh` remain unchanged.
`reference.sh` is a byte-for-byte fixture snapshot, not a rewritten function.
`reference_observe.sh` is a separate, authored Bash wrapper that sources only
that snapshot, calls the function with one explicit LSP root argument, then
prints the exported value plus LF as a projection comparable to the candidate
CLI. It must be invoked by a qualified Bash interpreter in an isolated,
pinned fixture, not as an authority to launch any live compiler. The wrapper's
output projection does not prove parent-environment equivalence.
The authored wrapper SHA-256 is
`5e6196860c40c861f1a6ecee2d1ab32a76c4b22c591d829f8ebca62ea5be4674`.
Current candidate/model source identities are respectively
`1aa632ce625dd5608de31714567c8bb9ff6d22dc699b16fcd38960eaf8d50e6c`
and `0ff7c281c690ff45c471aee003b7a8a9e17ba782d5e523782acbc1b2d5e719d1`.
These are recorded bytes, not build provenance or a completed hash gate; a
future public fixture must verify every selected artifact before and after
use and refuse concurrent dirty source revisions.

The source-only companion is
`ports/Elisa-LSP/scripts/compiler_root_env.elisascript`; its pure selection
module is `ports/Elisa-LSP/scripts/compiler_root_env_model.elisa`. The companion
includes the model by its sibling filename, so both files can be copied together
beside the real helper without changing the include path. This staging tree is
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

`test/script_parity/elisa_lsp_compiler_root_cases.elisa` separately authors
eight literal success observations without importing the candidate or model.
They cover unset/exported-empty defaults while the sibling compiler path is
missing, relative/absolute missing overrides with spaces and shell syntax, a
regular-file override, an existing directory, a directory symlink, and an
existing default sibling. The fixture root must be canonical and contain a
created `Elisa-LSP/scripts` tree; its basename should contain a space. The
relative case requires an isolated cwd with no matching directory. The
symlink must point only to a recorded directory inside the fixture. Later
setup must establish and recheck each topology before reference and candidate
runs, admit exact status/empty stderr/literal stdout against the reference
*first*, and retain a separate outside sentinel through cleanup. The case
source SHA-256 is
`7425b22b3be42266400f5610f916b75af223f7dc1e56ed0f7efc12393169f542`;
pure metadata assertions are authored but unrun. Neither this pin nor eight
data rows is an executable parity gate or observed host behavior.

Include existing real/symlink directories, missing paths, unset/empty values,
relative paths, spaces and metacharacters. Keep an outside sentinel and bounded
cleanup; never run either side against a live compiler checkout. The original
parent-export behavior is an interface difference to address by converting
callers to typed values, not by claiming subprocess parity.
