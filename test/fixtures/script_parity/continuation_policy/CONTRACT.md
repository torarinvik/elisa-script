# Continuation-policy source audit parity slice

`scripts/check_continuation_policy.sh` is the shell reference and
`scripts/check_continuation_policy.elisascript` is the candidate. Each checks a
fixed four-file repository-relative input set: the policy decision record,
continuation verifier, source lowerer, and IR test fixture. The candidate finds
the root from its own source path; parity fixtures must preserve the
`scripts/check_continuation_policy.elisascript` location.

For an ordinary readable repository tree, compare exit status and exact stdout
and stderr bytes. A missing input exits 1 and prints the first missing path in
reference order. A missing policy term exits 1 and prints
`continuation policy audit: policy omits <term>` for the first missing term in
the shell's declared order. If all policy terms exist, the remaining verifier,
lowerer, and test predicates run in reference order. Their shell reference
uses quiet `rg` under `set -e`, so any failed predicate exits 1 with no output.
The successful case exits 0 and prints the exact completion line plus newline.

The parity matrix should cover the clean tree, each of the 15 policy terms,
each of the eight silent source predicates, missing paths in every preflight
position, and multi-defect cases that pin first-failure ordering. Run each case
against an isolated copied repository; do not mutate live compiler sources.

`test/script_parity/continuation_policy_audit_launcher_test.elisascript` is a
gated public-launcher smoke seed, not that complete matrix: it checks the clean
case, one policy-term diagnostic, and one silent verifier-predicate failure.
Expand it before claiming full acceptance.

The candidate adds fail-closed UTF-8 read bounds of 1.5 MiB per source and 3
MiB total. Those limits are not part of the shell reference contract. Invalid
UTF-8, unreadable files, and over-limit sources are therefore outside parity
acceptance until their behavior is explicitly specified. This contract records
required comparisons, not a test result. Compiler, fixture, and audit
execution remain disabled until explicitly reauthorized.
