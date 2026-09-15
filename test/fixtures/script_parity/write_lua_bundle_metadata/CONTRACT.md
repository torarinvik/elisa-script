# Lua bundle metadata parity contract

This fixture binds W04 to the real Python manifest writer at
`compiler/scripts/write_lua_bundle_metadata.py` in the pinned reference
checkout (currently observed under `Go projects/effect-worktree/`). The
machine-specific checkout path is deliberately not part of the contract. The
current source pin is effect-worktree commit
`5284109ca5805560a488c3b0a5d8cd4a1a45e317` and blob
`3e5db6a091ea9b25af60deec5216d80e02674ef1`; a launcher must verify the pin
before using the reference. The reference is inspected as source only; no
Python process is launched by this contract. The eventual Elisascript
replacement must produce the same observable metadata for the accepted
fixture matrix without importing or calling the Python file.

## Command surface

The reference accepts these required options, in any order:

```text
--output PATH
--bundle-type LABEL
--repo-root PATH
--out-dir PATH
```

`--setting KEY=VALUE` and `--command KEY=VALUE` may each be repeated. An entry
without `=` fails before filesystem mutation with status 1 and the Python
`invalid <label> entry <repr>; expected key=value` diagnostic. An empty key
also fails with the corresponding `key must not be empty` diagnostic. Values
may be empty and may contain additional `=` bytes. Repeated keys use the last
value, matching assignment into a Python dictionary; JSON key sorting makes
their final order independent of insertion order. Unknown options, missing
option values, and missing required options use the reference argparse failure
shape and status 2. The four scalar options (`--output`, `--bundle-type`,
`--repo-root`, and `--out-dir`) also use argparse's last-occurrence-wins
behavior.

The reference uses Python `argparse`: long options accept both the separated
form (`--output PATH`) and the `--output=PATH` form, and unambiguous long-option
abbreviations are accepted because `allow_abbrev=True` is the default.
Ambiguous abbreviations are rejected as status-2 parse errors. `--` ends
option parsing; because this parser has no positional operands, options after
`--` are not accepted. A separate token that looks like a normal option (for
example `-tmp`) is treated as option syntax and is not a value, while
argparse's negative-number special case accepts a token such as `-1`; an
attached form such as `--out-dir=-tmp` is a value. Repeated
`--setting`/`--command` occurrences are preserved in argv order before their
last-key-wins dictionary materialization. These forms, repeated scalar
options, and `--` before/after required options must be explicit launcher
fixtures. The launcher invokes the reference with the pinned basename
`write_lua_bundle_metadata.py`; diagnostics compare stable status and message
class without embedding a machine-specific absolute `argv[0]`.

The replacement must parse argv as typed values. It must never concatenate the
options into a shell command or reinterpret setting/command values as shell
syntax. Its public launcher must preserve the reference `--` boundary and
reject post-boundary positional tokens in the same status-2 class; this must
be covered explicitly before adoption.

## Metadata shape and ordering

The output is UTF-8 JSON followed by exactly one LF. The reference call is
`json.dumps(..., indent=2, sort_keys=True)` with the Python default
`ensure_ascii=True`. The canonical output is therefore ASCII JSON encoded as
UTF-8: non-ASCII code points are escaped as `\uXXXX`, and astral code points
use two UTF-16 surrogate escapes. Two-space nested indentation,
lexicographically sorted object keys, no trailing spaces, and the final LF are
significant; a raw-UTF-8 JSON encoder does not match. The top-level object has
exactly these keys:

```text
bundle_type
commands
generated_at_utc
git
hostname
out_dir
repo_root
settings
uname
```

`settings` and `commands` are JSON objects whose string values are the parsed
right-hand sides. `generated_at_utc` is the UTC wall clock at second precision,
formatted `YYYY-MM-DDTHH:MM:SSZ` with valid calendar and clock ranges; parity
fixtures replace the clock with a deterministic host seam rather than comparing
a live timestamp.

## Host observations

The reference runs `hostname` and `uname -a` with captured text and uses
`unknown` when either command cannot be started, exits nonzero, or emits no
usable text after Unicode `.strip()`. Because `subprocess.run(text=True)`
inherits the process locale, the acceptance launcher pins a UTF-8 locale
(`LC_ALL=C.UTF-8`, with `LANG=C.UTF-8` where needed) and fixtures use valid
UTF-8 command output. The replacement must preserve Unicode-whitespace
trimming rather than byte-only trimming. It then gathers Git metadata under
`repo_root`:

1. `git rev-parse HEAD` failure or empty output makes `head`, `branch`, and
   `status` all `unknown`.
2. If `HEAD` succeeds, `git rev-parse --abbrev-ref HEAD` independently fills
   `branch`, falling back to `unknown` on failure/empty output.
3. `git status --short --untracked-files=no` independently fills `status` as
   `dirty` for nonempty stripped output, `clean` for empty output, or
   `unknown` when the command fails.

The replacement must use an argv-vector process effect with an explicit
working directory for Git and must preserve spaces, empty values, and newline
trimming exactly. It must not treat a failed status query as a clean tree.
Because the Python reference has unbounded `capture_output=True`, the
replacement must add a bounded process adapter before retaining or decoding
output: the initial fixture profile admits at most 64 KiB per captured text
value and a finite per-command deadline. A limit or deadline failure is a
typed host-observation failure and must resolve to `unknown` without waiting
indefinitely or allocating unbounded output.

## Filesystem and failure behavior

The reference creates `output.parent` with `parents=True, exist_ok=True`, then
writes the JSON directly with UTF-8 text mode. A write or mkdir exception is a
failure; the reference does not promise atomic replacement, fsync, or recovery
of a partially written destination. The Elisascript port must improve this
workflow before adoption: write to a private sibling, flush/sync as supported,
and atomically rename only after bounded output admission. A failed staging
write must leave any previous destination unchanged.

The port must impose explicit ceilings before allocating untrusted data. The
initial fixture profile is 64 KiB per argv text value, 4,096 settings and
commands per kind, 64 MiB aggregate metadata bytes, and a strict 4,096-byte
path operand ceiling. Embedded NUL bytes are rejected at the typed argv
boundary before any host string or filesystem adapter sees them. Larger values
fail with a typed diagnostic and no destination mutation. These are replacement
safety requirements, not claims about the unbounded Python reference.

The replacement is designed around pure deterministic seams first:
`MetadataArguments`, `HostFacts`, and `ClockFacts` are constructible without
filesystem, process, hostname, or wall-clock access. A typed host adapter then
supplies Git/hostname/uname results and an injected clock value. The serializer
must manually or equivalently emit sorted, two-space JSON with
`ensure_ascii=True`. For atomic publication, the caller must securely create a
private sibling staging file and retain its owned descriptor before invoking a
descriptor-aware publication adapter; the existing path-only
`file_stream_publish_staged` helper cannot consume these proofs. A path-only
helper call is not sufficient to prove exclusive staging or crash-safe
replacement. The typed publication seam
must also retain parent/staging device and inode identities under one owner
token, retain both owned descriptors through the publish edge, prove a
directory parent and regular private single-link staging file, and reject
publication after either descriptor has been closed. A close edge is cleanup
only; it is also rejected while rename is in flight until the host reports
success or an uncertain outcome. The seam must enter an explicit
uncertain-publication state if rename or post-rename directory durability
acknowledgement is lost after the publish edge.

## Acceptance matrix

The eventual source-level and launcher fixtures must cover:

| Case | Required observation |
| --- | --- |
| Minimal valid metadata | Exact JSON field set and sorted byte output |
| Repeated setting/command key | Last value wins; no duplicate JSON keys |
| Empty value and embedded `=` | Value is preserved byte-for-byte |
| Spaces/metacharacters in paths and values | No shell splitting or evaluation |
| Git clean, dirty, detached, and command failure | Exact three-field fallback behavior |
| Hostname/uname success, empty, and failure | `unknown` fallback without aborting metadata |
| Missing/invalid option | Argparse-compatible status and diagnostic class |
| Parent creation and existing destination | Successful replacement leaves one final LF |
| Staging write/rename failure | Previous destination remains unchanged |
| Output/path/entry ceilings | Typed bounded failure before mutation |
| Clock seam | Deterministic UTC second formatting |

Execution, differential comparison, and adoption remain disabled until the
compiler safety hold is explicitly reauthorized and a bounded launcher can
invoke both the reference and candidate in isolated temporary directories.
