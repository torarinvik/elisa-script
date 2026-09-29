# Output-materializing UI gate probe — authored, not qualified

`probe.c` is an independent C test oracle, not a C automation port or an
Elisascript implementation dependency. It runs no child, shell, compiler,
sanitizer or project code. Qualify two prebuilt artifacts from the same source:
the compiler role normally, and the read-only run payload with
`UI_GATE_RUN_PROBE` defined. No build or probe was launched while authoring this.

Source SHA-256:
`35e479382f86e84f56d04819bd443a59d06e773eb24ca0d031f7c36a1279b672`.
Independent Elisa oracle `test/script_parity/ui_codec_probe_model.elisa`:
`7cfc2598460d0334c736818232e23684003c49595b9045ebbe961b25dc878853`.
Its separate tests pin literal golden bytes, argc/endian framing, absent/empty
CC, output-component admission, binary stdin bounds and typed failures. They
import no candidate recipe and have not compiled/run. No passing evidence is
claimed for either native artifact or the Elisa oracle.

## Fixture authority and output creation

Every invocation requires `ELISASCRIPT_UI_PROBE_AUTHORIZED=1` and an absolute,
canonical `ELISASCRIPT_UI_PROBE_ROOT` identifying a newly allocated private
fixture, never a project, workspace or home directory. Root must be a directory
owned by the effective user with no group/other permission bits. The fixture
layout includes private `tmp` and `tools` directories, a `work` caller cwd,
and the copied sibling `elisa-ui` project. `TMPDIR` must be exactly `<root>/tmp`;
physical cwd must be `<root>/work`. This first probe policy deliberately does
not yet admit default `/tmp`, relative/trailing-slash TMPDIR, symlinked contexts,
or Windows hosts. Those remain required qualification work, not omitted goals.

The compiler role admits exactly the eleven literal arguments in the main
contract. It does not read the codec source/header. `-o` must identify
`<root>/tmp/<one-component>/utf8_utf16_codec_test`. The component is 1..255
ASCII letters/digits/dot/underscore/hyphen, excluding `.` and `..`; no extra
directory or alternate filename is allowed. The directory must already exist,
be private and owned by the effective user. Actual mktemp/mkdtemp allocation
must still occur in the script; this is not a mocked directory recipe.

Root's named/opened device/inode are compared, then descendants are opened
relative to held descriptors with `O_DIRECTORY`, `O_NOFOLLOW` and `O_CLOEXEC`.
Compiler status zero copies only `tools/ui-codec-run-probe`, a separately pinned
prebuilt native artifact, to an exclusively created output. No existing file is
overwritten. Payload must be owned, regular, executable, not group/other-writable,
4..1,048,576 bytes, and have a recognized native container header. Reads/writes
are bounded in 16 KiB chunks; file identity/size/mode/owner/timestamps and the
named payload are rechecked after copying. Output mode is explicitly 0700.
The header is not proof of a genuine or trusted executable: the future harness
must independently hash/qualify the complete copied payload before/after cases.

On selected nonzero compiler status, the owned output parent is validated but
no payload is opened and no output is created. No compiler role consumes stdin.
The run role requires zero arguments, writes no file, launches no child, and
reads bounded stdin to EOF, allowing the fixture to detect compile-stage input
consumption and test-stage stdin loss. Both roles select status 0 by default;
`ELISASCRIPT_UI_COMPILE_STATUS` and `ELISASCRIPT_UI_RUN_STATUS` respectively
accept 1..3 decimal digits in 0..255, including leading zeros.

## Independent binary observations

Stdout is nine ASCII bytes `ESUIGATE1`, one role byte (`C` or `R`), one selected
status byte, and an unsigned big-endian u32 argument count (11 or 0). Each
argument is u32 length + raw bytes, followed by cwd in the same field format.
Then come CC, TMPDIR and `ELISASCRIPT_UI_PROBE_MARKER`: each has a presence byte;
present values also have u32 length + bytes. Finally stdin is u32 length + raw
bytes, followed by `00 ff`. There is no newline or UTF-8 coercion. No whole
environment, argv[0], PID or timing is dumped.

Only the admitted output argument is emitted as
`<owned-temp>/utf8_utf16_codec_test`, because the two real allocators choose
different nonces. Raw output spelling is validated before normalization and
materialization; the future harness must separately observe the owned temp
tree and check it is empty before/after each wrapper run. This normalization
does not prove directory naming/mode/default-TMPDIR parity. All other argv,
cwd/environment bytes and binary stdin remain exact. Status/role are observable.
Expected CC must follow the reference's export semantics: inherited empty CC
becomes exported `clang`, absent CC stays absent, and nonempty CC stays unchanged.
The current candidate preserves empty CC instead; the future matrix must expose
that discrepancy, not suppress it by sharing a caller-env expectation for both.

Normal stderr is `ui-compile-stderr` or `ui-run-stderr` followed by `00 ff`, no
newline. The combined wrapper stream is compiler frame then run frame only on
compiler success; compiler failure must emit no run frame. Each stage's selected
status must independently match the wrapper's expected final status.

Root, cwd, original (not normalized) argv and recorded environment values share
a 65,536-byte text budget, excluding C terminators. Paths/cwd have 4,096-byte
buffers. Run stdin admits 65,536 bytes plus one overflow probe; compiler stdin
is neither consumed nor framed. Use at least 256 KiB combined capture for a
full two-stage workflow. These limits are not RSS or wall-time containment.

Preflight/materialization failures return 125, emit no normal stdout packet,
and report `ui codec probe: invalid fixture or host I/O failure` plus LF. Stream
failures may leave a partial packet and return 125 without delivering a full
diagnostic. Partial materialization may leave the newly created owned output;
all acquired descriptors are closed, but the probe deliberately does not delete
anything. Receipt-based outer cleanup must account for partial construction.

## Qualification before integration

Explicit reauthorization plus a functioning whole-process-tree RSS/deadline
guard is required before any compiler/probe/parity run. Build each artifact once
in isolation with a pinned C toolchain; record source/options/binary/dependency
closure identities. Pin the newest explicitly selected approved local Elisa
compiler for oracle/harness qualification; never substitute the installed or
main-worktree compiler. Markers and container headers are not authorization or
provenance evidence on their own. Do not touch SSH or other agents' runs.

Directly qualify native packets against independent literal/oracle bytes before
using the pair for wrappers. Exercise wrong argc/flags/context/status, escaped
or symlink parents, existing output/no-overwrite, missing/oversized/changed
payload, permissions, partial/failed I/O, binary input/overflow and stream faults.
The current path-based root admission plus descriptor-relative descendants are
not a sandbox against a hostile owner/concurrent rename; exclude concurrent
fixture/payload mutation and separately establish stronger threat-model needs.

Next integrate a gated isolated public-launcher/reference matrix, including
success/failure/skip/status, literal CC selection, inherited streams, actual
temp allocation and cleanup worlds. No such integrated UI matrix is claimed
by this foundation. Temp defaults/finalization/signals, real isolated C builds
and actual codec correctness remain separate required evidence. Originals and
the real codec inputs/callers remain unchanged.
