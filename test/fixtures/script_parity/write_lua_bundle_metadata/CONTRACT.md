# Lua bundle metadata parity contract

This fixture binds W04 to the real Python manifest writer at
`compiler/scripts/write_lua_bundle_metadata.py` in the pinned reference
checkout (currently observed under `Go projects/effect-worktree/`). The
machine-specific checkout path is deliberately not part of the contract. The
reference is inspected as source only; no Python process is launched by this
contract. The eventual Elisascript replacement must produce the same
observable metadata for the accepted fixture matrix without importing or
calling the Python file.

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
shape and status 2.

The reference uses Python `argparse`: long options accept both the separated
form (`--output PATH`) and the `--output=PATH` form, and unambiguous long-option
abbreviations are accepted. `--` ends option parsing, so a value beginning
with a dash must be passed with the equals form or after an explicit value
position as appropriate. Repeated `--setting` and `--command` occurrences are
accepted in argv order. The replacement must document any deliberate
compatibility boundary around abbreviations, because silently accepting an
ambiguous abbreviation would not match argparse.

The replacement must parse argv as typed values. It must never concatenate the
options into a shell command or reinterpret setting/command values as shell
syntax. A `--` argument is handled by the launcher contract, not by this
script's argparse surface, and must be covered explicitly before adoption.

## Metadata shape and ordering

The output is UTF-8 JSON followed by exactly one LF. `json.dumps(...,
indent=2, sort_keys=True)` gives the canonical byte shape: two-space nested
indentation, lexicographically sorted object keys, no trailing spaces, and the
Python default `ensure_ascii=True` escaping for non-ASCII characters. The
top-level object has exactly these keys:

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
formatted `YYYY-MM-DDTHH:MM:SSZ`; parity fixtures replace the clock with a
deterministic host seam rather than comparing a live timestamp.

## Host observations

The reference runs `hostname` and `uname -a` with captured text and uses
`unknown` when either command cannot be started, exits nonzero, or emits no
usable text after `.strip()`. On the POSIX reference host, the captured
subprocess text is decoded by Python's text-mode locale rules and the final
JSON is written with UTF-8 encoding and the platform's normal LF newline.
Fixtures use valid UTF-8 text and must pin any non-ASCII host output before
comparing bytes. It then gathers Git metadata under `repo_root`:

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
replacement must add a bounded process adapter: the initial fixture profile is
an 8 MiB combined stdout/stderr limit and a finite per-command deadline. A
limit or deadline failure is a typed host-observation failure and must resolve
to `unknown` without waiting indefinitely or allocating unbounded output.

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
commands per kind, 64 MiB aggregate metadata bytes, and 4,096-byte path
operands. Larger values fail with a typed diagnostic and no destination
mutation. These are replacement safety requirements, not claims about the
unbounded Python reference.

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
