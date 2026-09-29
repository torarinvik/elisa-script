# Small Skia environment-query Python port

Original: `../elisa-skia/infra/bots/recipe_modules/vars/resources/get_env_var.py`
(nine lines, including license/imports). `reference.py` is an unchanged snapshot,
SHA-256 `6233a520babc11883827118a90a532e9de6efab6294ddd038da7bd92c48e7de0`.
Its BSD license is retained in `LICENSE`, matching the original Skia license
SHA-256 `5f787c1dee3c56547f09ccc2906ab5f5293c4d8dd6c8654e573216c38e908dbd`.
Original scripts/callers are unchanged.

Candidate: `scripts/get_skia_environment.elisascript`. This source-only native
POSIX adapter candidate uses `EsEnvironmentLookup`'s typed presence value and
private libc ABI, not Python, a shell, a subprocess or the original script.
No compiler, Python reference, launcher, native adapter or fixture has run.
Compilation and public-launcher integration remain open; do not present this as
a usable interpreted-script replacement until its FFI path is qualified.

## Intended ordinary behavior

Use the first script argument as the environment key; ignore extra arguments.
Leave cwd and environment unchanged. Write only the selected value followed by
one added LF, or `None` followed by LF when the variable is absent. In particular:

| Host lookup | Exact stdout bytes |
| --- | --- |
| Absent | `None\n` |
| Present, empty | `\n` |
| Present, `None` | `None\n` |
| Present, `a` + LF | `a\n\n` |

Identical printed text does not imply identical presence. `Value.present` keeps
absence separate from empty and literal `None` values. Preserve spaces, CR/LF,
metacharacters and UTF-8 bytes without trimming, substitution or interpretation.
Under the ordinary well-formed POSIX environment contract, empty keys and keys
containing `=` cannot name entries, so the candidate skips libc lookup and prints
`None`. Embedded NUL is likewise an impossible dictionary key and cannot be
supplied by native argv; model fixtures still cover it without C truncation.
Malformed process environments with empty/duplicate keys need separate handling.

## Typed host boundary and remaining backend work

`environment_lookup_model.elisa` defines byte budgets, key/value admission and
printing independently of host access. `environment_lookup_posix.elisa` reads
libc `getenv`, distinguishes null from an empty C string, and copies bytes into
owned storage without returning the borrowed pointer. Admission/value-limit
errors remain `error[LookupError]`; they never masquerade as an absent variable.
The script reports such failures with status 2 and no `None` success output.
Allocation/panic failures are not caught as absence either.

The host must exclude concurrent `setenv`, `unsetenv` and `putenv` during the
borrow-and-copy operation. A bounds check does not make a concurrently invalidated
C pointer safe. This is not a concurrent environment snapshot API. POSIX lookup
also observes the live C environment, while Python's `os.environ` is initialized
as a mapping at interpreter startup: changes outside that mapping, duplicate keys
and embedded-host use remain outside the ordinary fresh-process contract.

The existing interpreter environment operation returns an undifferentiated
`Environment` failure for missing variables, invalid names and bounded-host-read
failures. Its fallback lowering catches that error edge, so using a default string
would hide failures as absence. This adapter intentionally does not do that.
It still needs a native build qualification and a presence-aware interpreted/
bytecode operation or equivalent qualified host bridge. Do not assume that adding
an extern declaration automatically enables the public interpreted launcher.

## Explicit differences, not accepted parity

Names admit at most 4,096 bytes and values at most 1 MiB. The copy accepts a NUL
terminator at the exact value boundary and rejects the next payload byte. These
are model policies, not an OS limit, arbitrary-input reference parity or an RSS
guard. Native platform restrictions on environment sizes still apply.

The no-argument case returns status 1 with a stable candidate diagnostic instead
of Python's version/path-dependent IndexError traceback. Output faults likewise
use candidate diagnostics rather than Python's traceback/flush behavior. These
differences remain open for acceptance, not silently declared equivalent.

The adapter copies raw non-NUL value bytes. Python on ordinary UTF-8 POSIX hosts
uses filesystem decoding with surrogateescape; stdout encoding/error settings
can change the emitted bytes or raise an encoding error. UTF-8/ASCII ordinary
output is the initial qualification target, not a claim that this handles every
locale, `PYTHONIOENCODING`, invalid-byte or Windows Unicode-environment policy.
Invalid-byte raw-copy expectations are authored model tests, not proved Python
equivalence. Case sensitivity, duplicate entries, libc behavior and stdout
buffering/TTY/pipe faults also require host qualification.

## Authored fixtures and future safe parity matrix

Pure source fixtures cover absent/empty/literal-None values, added LF, preserved
spaces/metacharacters/Unicode/raw bytes, impossible keys, NUL rejection, forged
absent values and name/value admission boundaries. They have not compiled/run
and do not prove the native adapter reads an environment correctly.

After explicit execution reauthorization, build/qualify a pinned local artifact
under working process-tree RSS/time containment. Use a separate opt-in gate for
each public-launcher/native qualification; preserve the approved local compiler
selection and newest explicitly selected artifact's path/hash provenance.
Never launch the installed or main-worktree compiler as a shortcut.

For each fixture, launch both reference and candidate in fresh isolated children
with identical explicit environment and argv. Do not mutate the parent's env.
Use only uniquely named fixture keys, not credentials or live project state.
Independently expect exact stdout/stderr/status for absence, empty, literal None,
spaces, LF/CR, metacharacters, UTF-8, first-argument selection and ignored extras.
Also verify caller cwd and inherited unrelated env remain unchanged. Comparing
only the programs to each other is insufficient.

Separately qualify admission failures, exact value-terminator boundary, locale/
encoding/raw-byte policies, no-argument diagnostics, short/broken stdout and
concurrent mutation exclusion. Hash source/reference/license/launcher/compiler
identities before and after use; clean up only recorded isolated fixture paths.
Do not touch SSH or other agents' processes. No adoption until observed workflow
parity and the public execution path are actually demonstrated.

## Dormant native qualification matrix (authored, not executed)

`test/script_parity/skia_environment_cases.elisa` supplies ten independent
literal ordinary cases; it imports no candidate lookup/printing implementation.
`skia_environment_cases_test.elisa` checks that fixture surface without launching
anything. `skia_environment_native_parity_test.elisascript` is a gated process
matrix for a separately qualified, prebuilt native candidate. It never compiles
the candidate, starts a compiler, or invokes the interpreted public launcher.
That launcher still needs its own presence-aware host integration and tests.

The public `EsSkiaEnvironmentNativeParity::native_parity` entry requires all of:

- `ELISASCRIPT_VALIDATION_REAUTHORIZED=1` and
  `ELISASCRIPT_BOUNDED_TEST_RSS_GUARD=active` from an authorized outer guard.
- `ELISASCRIPT_SKIA_ENV_NATIVE_QUALIFIED=1`, with absolute nonsymlink executable
  paths and SHA-256 identities supplied through `ELISASCRIPT_SKIA_ENV_NATIVE_BIN`,
  `ELISASCRIPT_SKIA_ENV_NATIVE_SHA256`, `ELISASCRIPT_PARITY_PYTHON_BIN` and
  `ELISASCRIPT_PARITY_PYTHON_SHA256`.
- Both compiler selectors pinned to the approved local StructPy compiler path,
  and `ELISASCRIPT_LOCAL_COMPILER_SHA256` matching its selected local artifact.
  The compiler is identity-checked, never executed by this fixture.
- Candidate source/model/adapter pairing assertions through
  `ELISASCRIPT_SKIA_ENV_SOURCE_SHA256`, `ELISASCRIPT_SKIA_ENV_MODEL_SHA256` and
  `ELISASCRIPT_SKIA_ENV_ADAPTER_SHA256`, matching the fixed source hashes in the
  matrix. The reference, license, independent cases and hash-tool identities are
  pinned too.

These markers and source-pairing assertions are not proof of artifact provenance
or a working RSS guard. Separate qualification must establish the exact native
build, compiler/options, dependency closure (including runtime libraries), test
harness/runner build and actual whole-process-tree memory/time containment. The
shared differential runner currently has concurrent worktree edits: do not assume
its included sources match an earlier qualified artifact. No gate is permission
to resume execution without explicit user reauthorization.

The fixture constructs a private temporary directory containing only a copied
reference and copied native candidate, checks their hashes and modes, and uses
that directory as cwd for both programs. Each child receives a fresh replacement
environment containing only explicit fixture values and `LC_ALL=C`; it does not
inherit credentials, PATH, HOME or validation/compiler variables. A binary stdin
sentinel is supplied to both but the program has no reason to read it. Python is
invoked with `-I -S -B -X utf8`: isolated startup, no site hooks, no bytecode writes,
and explicit UTF-8 mode. This deliberately qualifies ordinary UTF-8 behavior,
not ambient Python encoding/locale configuration.

For each case, the reference must match literal status 0/stdout/empty stderr before
the native candidate starts. The candidate must match that same independent
expectation as well as the reference. Absent/empty/None, metacharacters, CR/LF,
UTF-8, case sensitivity, empty/equals keys and ignored extra args are covered.
Input identities are rechecked even after setup/matrix failure; fixture filename
membership, file bytes and modes are checked around each ordinary run. This is
not a full mutable-world or parent-environment receipt: inode/timestamps, out-of-
tree writes, TTY/stream timing, concurrent mutation and parent-state observation
are still separate qualification requirements. The harness is not a sandbox for
untrusted binaries.

Captured output has a 64 KiB combined budget and every subprocess has 10,000
bounded wait polls, not a promised 10,000 milliseconds. The external RSS/time
guard remains required. Cleanup removes only recorded temporary file paths in
reverse order and then attempts the empty root directory; unexpected files are
not recursively erased, and cleanup failure reports the recoverable root path.
Partial setup is cleaned too. All matrix/gate/cleanup paths are source-only and
still require compilation and execution qualification.
