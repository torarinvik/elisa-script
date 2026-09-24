#!/usr/bin/env bash

# Compiler-free audit for bounded regex and replacement sessions.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/regex_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
runtime_fixture="$repo_root/test/runtime/regex_model_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"

for required_file in "$model" "$ir" "$fixture" "$runtime_fixture" "$docs" "$ledger"; do
    [[ -f "$required_file" ]] || { printf 'regex model audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsRegex:' \
    'Limits::PATTERN_BYTES' \
    'Limits::INPUT_BYTES' \
    'Limits::REPLACEMENT_BYTES' \
    'Limits::GROUPS' \
    'Limits::MATCHES' \
    'Limits::WORK' \
    'const enum RegexOperation of u8:' \
    'const enum RegexState of u8:' \
    'const enum RegexEvent of u8:' \
    'struct RegexPolicy:' \
    'struct RegexRequest:' \
    'struct RegexSession:' \
    'error RegexContractError:' \
    'def validate_regex_policy(' \
    'def validate_regex_request(' \
    'def validate_regex_session(' \
    'def advance_regex_session('; do
    rg -Fq "$declaration" "$model"
done

for boundary in \
    'regex_text_valid' \
    'PatternLimitExceeded' \
    'InputLimitExceeded' \
    'ReplacementNotAllowed' \
    'GlobalPolicyInvalid' \
    '(request.operation == RegexOperation.FindAll or request.operation == RegexOperation.Split) and not request.global' \
    '(request.operation == RegexOperation.Search or request.operation == RegexOperation.Match or request.operation == RegexOperation.FullMatch) and request.global' \
    'InvalidOperation if session.request.operation == RegexOperation.Replace' \
    'GroupLimitExceeded' \
    'MatchLimitExceeded' \
    'CaptureAccountingInvalid' \
    'WorkLimitExceeded' \
    'OutputLimitExceeded' \
    'not session.request.global and session.matches != 0' \
    'not session.request.global and session.matches > 1' \
    'work_delta != 0 and capture_delta == 0 and output_delta == 0' \
    'EndNotReady' \
    'CancelNotReady'; do
    rg -Fq "$boundary" "$model"
done
rg -Fq 'regex_request_global_policy_matches_operation_shape' "$runtime_fixture"
rg -Fq 'find_all_without_global' "$runtime_fixture"
rg -Fq 'split_without_global' "$runtime_fixture"
rg -Fq 'regex_session_rejects_forged_repeated_non_global_match_count' "$runtime_fixture"
rg -Fq 'zero_work_rejected' "$runtime_fixture"

rg -Fq 'include "../runtime/regex_model.elisa"' "$ir"
rg -Fq 'using EsRegex' "$fixture"
for fixture_pattern in \
    'typed_regex_session_contract_bounds_work_captures_and_replacements' \
    'RegexOperation.Search' \
    'RegexOperation.Replace' \
    'RegexEvent.Match' \
    'RegexEvent.Replace' \
    'RegexEvent.CancelAck' \
    'replace_match_rejected'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq 'EsRegex exposes the same limits as a public adapter contract' "$docs"
rg -Fq 'ES-SCRIPT-012 | EsRegex' "$ledger"

printf 'regex model audit: operation identity, pattern/input/replacement limits, work/capture/output accounting, and cancellation are present\n'
