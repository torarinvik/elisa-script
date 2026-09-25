#!/usr/bin/env bash

# Compiler-free audit for rerun-confirmed timeout shrink evidence.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
source_file="$repo_root/src/testing/timeout_shrink_model.elisa"
fixture_file="$repo_root/test/differential/elisascript_differential_test.elisa"
docs_file="$repo_root/docs/differential-testing.md"
ledger_file="$repo_root/docs/capabilities/ledger.md"

for required_file in "$source_file" "$fixture_file" "$docs_file" "$ledger_file"; do
    [[ -f "$required_file" ]] || { printf 'differential timeout-shrink audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsDifferentialTimeout:' \
    'using EsDifferential' \
    'const enum DifferentialTimeoutSide of u8' \
    'const enum DifferentialTimeoutState of u8' \
    'const enum DifferentialTimeoutEvent of u8' \
    'const enum DifferentialTimeoutDecision of u8' \
    'struct DifferentialTimeoutPolicy:' \
    'struct DifferentialTimeoutCandidate:' \
    'struct DifferentialTimeoutSession:' \
    'error DifferentialTimeoutError:' \
    'mismatch_kind: DifferentialDifferenceKind' \
    'observed_kind: DifferentialDifferenceKind' \
    'def differential_timeout_decision_valid(' \
    'def differential_timeout_comparison_kind_valid(' \
    'def validate_differential_timeout\(' \
    'def advance_differential_timeout\('; do
    rg -q "$declaration" "$source_file"
done

for boundary in \
    'Limits::CANDIDATES' \
    'CandidateNotSmaller' \
    'CandidateOrderInvalid' \
    'CandidateDecisionInvalid' \
    'MismatchCategory' \
    'MinimalityUnproven' \
    'session.exhausted and session.state != DifferentialTimeoutState.Complete' \
    'session.state == DifferentialTimeoutState.Planned and (session.current_timeout_steps != session.initial_timeout_steps or session.candidates.count != 0 or session.exhausted)' \
    'not session.has_pending and not differential_timeout_candidate_is_default(session.pending)' \
    'expected_timeout_steps: mutable u64 = session.initial_timeout_steps' \
    'candidate.timeout_steps >= expected_timeout_steps' \
    'differential_timeout_decision_valid(candidate.decision)' \
    'candidate.decision == DifferentialTimeoutDecision.Accepted and candidate.observed_kind != session.policy.mismatch_kind' \
    'candidate.decision == DifferentialTimeoutDecision.Rejected and candidate.observed_kind == session.policy.mismatch_kind' \
    'candidate.decision == DifferentialTimeoutDecision.Abandoned and (session.state != DifferentialTimeoutState.Cancelled or index + 1 != session.candidates.count)' \
    'policy.mismatch_kind != DifferentialDifferenceKind.Equal' \
    'session.current_timeout_steps != expected_timeout_steps' \
    'decision: DifferentialTimeoutDecision.Rejected' \
    'decision: DifferentialTimeoutDecision.Abandoned' \
    'session.pending.ordinal != session.candidates.count' \
    'comparison_fingerprint' \
    'DifferentialTimeoutEvent.Exhaust'; do
    rg -q "$boundary" "$source_file"
done

for fixture_pattern in \
    'include "../../src/testing/timeout_shrink_model.elisa"' \
    'using EsDifferentialTimeout' \
    'differential_timeout_shrinker_requires_monotonic_rerun_evidence' \
    'DifferentialTimeoutError.CandidateNotSmaller' \
    'DifferentialTimeoutError.CandidateDecisionInvalid' \
    'mismatch_kind: DifferentialDifferenceKind.Equal' \
    'DifferentialTimeoutError.PolicyInvalid' \
    'hidden_pending_rejected' \
    'planned_history_rejected' \
    'forged_planned_history' \
    'initial_timeout_steps: 16' \
    'assert session.candidates.count == 1 and session.candidates\[0\].decision == DifferentialTimeoutDecision.Rejected' \
    'DifferentialTimeoutDecision.Accepted' \
    'DifferentialTimeoutDecision.Abandoned' \
    'cancelled_pending.candidates\[0\].comparison_fingerprint == 96' \
    'abandoned_while_running' \
    'invalid_reject' \
    'invalid_accept' \
    'forged_timeout_candidates'; do
    rg -q "$fixture_pattern" "$fixture_file"
done

rg -q 'EsDifferentialTimeout::DifferentialTimeoutSession' "$docs_file"
rg -q 'ES-SCRIPT-028' "$ledger_file"

printf 'differential timeout-shrink audit: accepted, rejected, and abandoned attempts are retained with explicit exhaustion\n'
