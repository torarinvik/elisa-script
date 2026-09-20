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
    'const enum DifferentialTimeoutSide of u8' \
    'const enum DifferentialTimeoutState of u8' \
    'const enum DifferentialTimeoutEvent of u8' \
    'struct DifferentialTimeoutPolicy:' \
    'struct DifferentialTimeoutCandidate:' \
    'struct DifferentialTimeoutSession:' \
    'error DifferentialTimeoutError:' \
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
    'expected_timeout_steps: mutable u64 = session.initial_timeout_steps' \
    'candidate.timeout_steps >= expected_timeout_steps' \
    'candidate.accepted and candidate.observed_kind != session.policy.mismatch_kind' \
    'not candidate.accepted and candidate.observed_kind == session.policy.mismatch_kind' \
    'session.current_timeout_steps != expected_timeout_steps' \
    'session.candidates.push(session.pending)' \
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
    'initial_timeout_steps: 16' \
    'assert session.candidates.count == 1 and not session.candidates\[0\].accepted' \
    'invalid_reject' \
    'invalid_accept' \
    'forged_timeout_candidates'; do
    rg -q "$fixture_pattern" "$fixture_file"
done

rg -q 'EsDifferentialTimeout::DifferentialTimeoutSession' "$docs_file"
rg -q 'ES-SCRIPT-028' "$ledger_file"

printf 'differential timeout-shrink audit: accepted and rejected reruns are retained with explicit exhaustion\n'
