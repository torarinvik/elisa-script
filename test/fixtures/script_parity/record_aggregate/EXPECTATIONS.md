# Record-aggregate audit parity contract

This contract specifies future differential acceptance cases for
`scripts/check_record_aggregate.sh` and
`scripts/check_record_aggregate.elisascript`. It is a specification, not
evidence that either program or any fixture has run. The compiler-validation
hold remains active.

For every comparison, give both implementations the same explicit,
canonicalized repository-root path. Use a stable checkout or generated root
with no symlink components: the shell reference uses `pwd` while the candidate
uses `path_real`, so symlink spelling is not part of this contract. The
generated root must contain a copy of the candidate at
`scripts/check_record_aggregate.elisascript`, since the shell reference
preflights that path. Keep that candidate file intact while mutating one of
the five shared input files below.

Compare exit status and stdout/stderr bytes independently. For expected output,
`{ROOT}` means the same canonical absolute path passed to both implementations;
`{INPUT}` means `{ROOT}/` followed by the listed relative path. `\n` denotes
one final LF byte. Unless listed otherwise, stdout and stderr are empty.

## Stable checkout cases

| Case | Status | Stdout | Stderr |
| --- | ---: | --- | --- |
| Unmodified repository root | 0 | `record aggregate audit: bounded insertion-ordered groups and sealed lookup are present\n` | empty |
| Nonexistent repository root | 1 | empty | `record aggregate audit: missing repository root\n` |
| Two script operands | 2 | empty | `usage: record aggregate audit [repository-root]\n` |

The positive case is the only current stable-checkout semantic assertion. It
does not establish that the source patterns are complete or that the port is
correct for other source trees.

## Isolated input failures

Create a generated root containing all five valid, bounded inputs and the
candidate copy. In each row, make exactly the named file absent while leaving
all other files valid. Missing-file parity is checked in the
reference's declared order:

| Missing input | Status | Stdout | Stderr |
| --- | ---: | --- | --- |
| `src/runtime/record_aggregate_model.elisa` | 1 | empty | `record aggregate audit: missing {INPUT}\n` |
| `src/ir/ir.elisa` | 1 | empty | `record aggregate audit: missing {INPUT}\n` |
| `test/ir/elisascript_ir_test.elisa` | 1 | empty | `record aggregate audit: missing {INPUT}\n` |
| `docs/ir.md` | 1 | empty | `record aggregate audit: missing {INPUT}\n` |
| `docs/capabilities/ledger.md` | 1 | empty | `record aggregate audit: missing {INPUT}\n` |

Substitute the row's relative path for `{INPUT}`. Do not remove the candidate
itself: the shell reference needs it as a source precondition, and without it
the candidate cannot be launched for comparison.

## Aggregate byte boundary

Starting from a valid generated root, add harmless trailing ASCII spaces to
`docs/ir.md` so that the sum of the five shared input sizes is exactly
4,194,304 bytes. The candidate and reference must both accept this root with
the same success tuple as the unmodified root. Add one more byte, leaving all
other bytes unchanged; both must then return status 2, no stdout, and exactly
`record aggregate audit: source exceeds audit limit: {ROOT}/docs/ir.md\n` on
stderr.

The candidate and shell also declare a 16,777,216-byte per-file ceiling, but
the 4,194,304-byte aggregate ceiling is stricter: no input can reach the
per-file ceiling without already violating the aggregate ceiling. The
per-file check therefore has no distinct observable boundary under the
current constants and is not a separate parity claim. Keep generated inputs
valid UTF-8 and stable for the full run; concurrent mutation and read/size
TOCTOU behavior are explicitly outside this matrix.

## Semantic rejection cases

Starting with the valid input set, remove or alter all matches of exactly one
required source needle at a time in one of the five shared inputs, preserving
the other required needles. For every mutation, both programs must return
status 1 with empty stdout and stderr. Include one isolated failure for every
required needle in these categories:

- model module declaration, include edge, and each required model declaration;
- every aggregate bound/state/accounting/order/event boundary;
- every IR-fixture contract token;
- the model-name reference in `docs/ir.md`;
- the capability identifier in `docs/capabilities/ledger.md`.

These should be generated as isolated source mutations, not maintained as
large copied source trees. Keep each file below the aggregate ceiling and
valid UTF-8. Do not mutate the candidate's own self-audit needles as part of
this parity matrix: the candidate is the executable under test, whereas the
shell reference separately preflights that artifact.

The shell checks all required paths before checking sizes, whereas the
candidate checks each shared input's path and size as it proceeds. Therefore,
combine neither a missing input with an oversized input nor multiple
simultaneous faults in a single expected tuple; precedence for conflicting
errors is not currently claimed as parity.

## Invocation differences and execution status

Always pass the same explicit root. With no operand, the shell reference
defaults to its own repository while the candidate defaults to the process
working directory; this convenience behavior is intentionally excluded from
parity. The matrix requires a future bounded launcher that compares both
process results against the tuples here. No compiler, launcher, shell audit,
or parity case has been run for this contract, and the record-aggregate port
is not accepted until that validation is explicitly reauthorized and safely
completed.
