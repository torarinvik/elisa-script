# Small UI codec build-and-test shell port

Original: `../elisa-ui/scripts/check_utf8_utf16_codec.sh`, 14 lines.
`reference.sh` is an unchanged snapshot, SHA-256
`1c96c7c9e37ffad5333877fb932173e82d9553e228028ec757ccfe83514969c0`.
Candidate: `scripts/check_ui_utf8_utf16_codec.elisascript`, with pure recipe/
normal-status policy in `src/runtime/ui_codec_build_model.elisa` and authored
fixtures in `test/script_parity/ui_codec_build_model_test.elisascript`.
Original source, header, script and callers are unchanged.

This is a source-only candidate, not an accepted build-script replacement. No
compiler, sanitizer, codec executable, reference or fixture has run. Source
syntax, effects and control-flow lowering still need compilation qualification.
The candidate must not be exercised during the current execution hold.

## Intended ordinary build workflow

Resolve the neighboring `elisa-ui` project before reading `CC`. The default entry
locates it beside elisa-script from the script's resolved directory. Future
public-launcher fixtures must reproduce that sibling layout, copying the
candidate/model closure under `elisa-script` and the reference/header/test under
`elisa-ui`. Public `EsUiCodecGate::run_root(Path)` accepts an already-resolved
absolute project context for focused adapter fixtures, not a new CLI override.

Unset/empty `CC` selects `clang`; any nonempty value is one executable name.
`CC='clang -O3'` must not be split into a command plus flag. Ignore wrapper argv.
Allocate one private temporary directory, then launch the selected compiler with
exactly these eleven arguments, in order:

1. `-std=c11`
2. `-O2`
3. `-Wall`
4. `-Wextra`
5. `-Werror`
6. `-fsanitize=address,undefined`
7. `-fno-omit-frame-pointer`
8. `-I<project>/src/platform/common` (one argv item)
9. `<project>/test/utf8_utf16_codec_test.c`
10. `-o`
11. `<temporary>/utf8_utf16_codec_test`

Do not change caller cwd or the invoking parent's environment. The reference's
`CC="${CC:-clang}"` assignment has a child-environment detail: when inherited
CC is present but empty, its exported value becomes `clang` for both compiler
and test. When CC is absent, the new shell variable is not exported; nonempty
inherited CC remains exported unchanged. Preserve all unrelated environment
entries. The current candidate defaults the executable but leaves an inherited
empty CC unchanged, so this is an identified source-level parity gap. It needs a
streaming child-only environment overlay, not a global parent-env mutation or
the existing capture-and-discard environment runner. The pure child-CC policy
and parent-prepared environment/PATH layer are now authored; see
`docs/process-environment-plan.md`. A streaming host executor and candidate
wiring are still required, so this gap is not marked fixed.
The new `src/runtime/ui_codec_launch_model.elisa` composes those layers for
Compile/Run phases from one validated sealed ambient snapshot, with owned
argv/env/search buffers and no parent-env mutation. Pure composition fixtures
check empty CC for both children, absent/nonempty/tombstoned CC, exact recipe
arguments, literal executable spelling and independent storage. This data-only
composition is uncompiled/unrun and does not change the current candidate or
qualify streams, temp ownership, native launch or compiler-success admission.
Both reference root resolution and
mktemp capture happen in command substitutions, not a parent-shell `cd`.
Both compiler and test inherit stdin/stdout/stderr with no script-imposed deadline.
The candidate uses the ordinary inherited-stream process runner, not the
directory-aware capture-plus-status helper that discards child output.

On ordinary compiler nonzero exit, skip the codec executable and select that
status. On compiler zero, invoke the temporary executable with no arguments
and select its ordinary exit status. Do not invent a success message: the test
owns its own output. After either normal path, attempt cleanup and preserve the
selected status even if cleanup fails, matching EXIT-trap normal-status policy.
Typed host failures use candidate diagnostics/status 1 and still route through
cleanup after successful allocation. These diagnostics are not Bash equivalents.

## Cleanup ownership and open runtime gaps

The private cleanup helper receives only the directory allocated by this
invocation; never feed it a project root, environment value or argument-derived
path. It requires the allocator's expected generated leaf prefix before removal;
both absolute and caller-relative owned receipts are admitted.
No temporary directory, compiler or cleanup is allocated/launched by a pure
recipe fixture. The runtime recursive remover has a depth bound and is not a
descriptor-sealed, race-proof deletion primitive. Use trusted compilers and
stable owned directories; hostile/concurrent replacement requires stronger
ownership/descriptor qualification, not an assertion that a pathname is a lease.

The legacy temporary allocator still chooses `/tmp/elisascript-...` without
reading `TMPDIR`. The codec candidate now reads `TMPDIR` explicitly and uses the
new `temp_directory_in(parent, prefix)` operation, selecting `/tmp` for unset/
empty values and preserving relative parent spelling. That operation's registry,
lowering, verifier, interpreter and direct-bytecode paths are authored, not run.
The shell reference still delegates to its selected mktemp tool. Temp naming,
directory modes, relative/trailing-slash normalization, host errors and exact
TMPDIR behavior remain qualification gaps; no observed parity is claimed. Do not
accept a test that bypasses actual allocation through a mocked recipe.

Similarly, ordinary state-machine cleanup is not an EXIT trap on runtime panic,
cancellation, process termination or every signal edge. Those paths require a
qualified finalization/unwinding primitive before cleanup parity can be claimed.
In particular, a machine `Cleanup` state alone does not prove panic safety.
Interpreter fork/wait process-group and shell job-control/spawn diagnostics,
permission-denied 126 versus missing-command 127, PWD/logical-symlink spelling,
environment lookup failure versus absence, TTY behavior and cleanup diagnostics
remain unqualified. The native backend's host behavior must be qualified too.

The model admits at most 4,096 bytes per input text, rejects NUL, and requires
an absolute project context but permits a nonempty relative generated temp path.
Before constructing derived arguments, it also requires each complete include,
source and output pathname to fit 4,096 bytes **including** a C terminator.
The compiler spelling must likewise be shorter than 4,096 bytes, agreeing with
the prepared launcher rather than accepting a compiler in the recipe that its
launch preparation must reject. Input envelopes are checked before byte scans;
suffix admission uses subtraction, not unchecked added path lengths. The `-I`
option prefix is not part of its pathname budget. These policies do not split,
normalize or expand any path, and do not probe whether it exists.
The new allocator
separately bounds its complete parent/prefix/random-suffix/C-terminator template
to 4,096 bytes before invoking POSIX allocation.
These are explicit admission policies, not OS PATH_MAX validation, arbitrary-
input reference parity or a process RSS guard. A failure to remove an owned
directory is reported with its path; cleanup failure may leave recoverable
temporary files and deliberately does not overwrite the original normal status.

## Authored evidence and required qualification

Pure source fixtures independently pin all eleven flags/path argv items, empty
CC defaulting, literal CC values/paths with spaces/metacharacters, zero deadline,
compile-failure skip policy, cleanup status preservation and invalid/NUL inputs.
They have not compiled/run; they do not prove compiler invocation, skip behavior,
cleanup execution or codec correctness.

`test/runtime/ui_codec_path_budget_test.elisa` adds independent literal boundary
checks: a 4,066-byte project root yields a 4,095-byte source pathname; a
4,073-byte absolute or relative temporary receipt yields a 4,095-byte output
pathname; and a 4,095-byte compiler spelling is admitted by recipe and child-CC
policy. One additional payload byte produces the corresponding typed recipe
error. These are string-model assertions, not real host path admission or proof
of atomic temp ownership. A separate pure composition assertion checks that
both prepared launch phases serialize the boundary output path as 4,095
payload bytes plus one terminal NUL, and that the run phase has exactly one
absolute executable candidate. They have not compiled/run.

For source-only provenance, the reviewed real codec inputs currently hash to:

- `test/utf8_utf16_codec_test.c`:
  `74783e17178722beb90829366144b9edd0e21f6b690c48def6ddcef2fa17c2c3`.
- `src/platform/common/utf8_utf16.h`:
  `8dffc5774e61facd4f7c684ff965428abed439e3c601b51f802f6d71317d1373`.

After explicit reauthorization, first use a separately qualified, prebuilt inert
compiler probe that records exact argv/cwd/environment/streams and materializes
a pinned inert test executable only at a validated `-o` fixture path. It must
not run a real compiler, shell script, sanitizer or project code. The existing
read-only process probe cannot materialize an output and is insufficient here.
The source-only two-role foundation is now authored in `probe.c`, with an
independent Elisa packet oracle and pure fixtures. See `PROBE_CONTRACT.md` for
its descriptor-relative output admission, prebuilt payload policy and remaining
qualification/integration requirements. Neither artifact, oracle nor an
integrated UI public-launcher matrix has compiled/run.
Independently observe these workflow cases, not just reference/candidate equality:

- Compile zero/test zero; compile zero/test nonzero; several compile failures
  that start no test; empty/unset/relative/absolute/literal-space CC choices.
- Caller cwd different from project root; project/temp paths with spaces;
  binary streams from each stage; environment preserved without parent mutation.
- Temporary allocation failure before compilation; failed compiler validation
  after allocation; missing/nonexecutable test output; cleanup after all failures.
- Owned temporary-tree removal on both ordinary paths; extra compiler outputs,
  nested files and symlinks; a cleanup failure preserves the selected status.
- Actual TMPDIR/default allocation, directory modes, unwinding/cancellation,
  spawn/signal and broken-stream behavior, with explicit policies for differences.

Use explicit process-entry opt-in, pinned local compiler/launcher/probe/reference/
source/header/tool identities, bounded captures and functioning process-tree RSS/
time containment. Keep fixtures in isolated trees and compare file/mode/link
worlds before/after, including owned temporary roots. Record cleanup paths;
never delete live build directories or interfere with SSH/other agents.

Only after probe-backed orchestration and actual temp/finalization policies are
qualified, separately authorize the real isolated C build with a pinned C
compiler/sanitizer toolchain. Run identical pinned header/test copies for both
scripts and independently require the real codec's expected success output and
zero status. Probe parity alone does not prove that the codec compiles or runs.
Never use the installed/main-worktree Elisa compiler for fixture validation.
