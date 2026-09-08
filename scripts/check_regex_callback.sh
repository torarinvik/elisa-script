#!/usr/bin/env bash

# Compiler-free audit for bounded regex replacement callbacks.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/regex_callback_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture_file="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$ir" "$fixture_file" "$docs" "$ledger" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'regex callback audit: missing %s\n' "$required_file" >&2; exit 1; }
done

rg -q '^module EsRegexCallback:' "$model"
rg -q 'include "\.\./runtime/regex_callback_model\.elisa"' "$ir"
for declaration in \
    'const enum RegexCallbackState of u8' \
    'const enum RegexCallbackEvent of u8' \
    'struct RegexCallbackPolicy:' \
    'struct RegexCallbackSession:' \
    'error RegexCallbackError:' \
    'def validate_regex_callback\(' \
    'def advance_regex_callback\('; do
    rg -q "$declaration" "$model"
done

for boundary in \
    'REGEX_CALLBACK_MAX_MATCHES' \
    'REGEX_CALLBACK_MAX_CAPTURES' \
    'REGEX_CALLBACK_MAX_INPUT_BYTES' \
    'REGEX_CALLBACK_MAX_OUTPUT_BYTES' \
    'regex_callback_add_fits' \
    'pending' \
    'has_last_zero' \
    'RegexCallbackError.NonProgress' \
    'RegexCallbackError.ReplacementNotReady' \
    'RegexCallbackError.OutputLimitExceeded' \
    'RegexCallbackError.AccountingInvalid' \
    'policy.max_captures != 0' \
    'session.pending and session.state != RegexCallbackState.Matching' \
    'RegexCallbackEvent.Match' \
    'RegexCallbackEvent.Replace' \
    'RegexCallbackState.Complete'; do
    rg -q "$boundary" "$model"
done

for fixture_pattern in \
    'using EsRegexCallback' \
    'typed_regex_callback_contract_accounts_spans_and_zero_width_progress' \
    'RegexCallbackEvent.Match' \
    'RegexCallbackEvent.Replace' \
    'RegexCallbackError.NonProgress' \
    'RegexCallbackError.MatchLimitExceeded' \
    'RegexCallbackError.AccountingInvalid' \
    'forged_pending' \
    'zero_capture_policy'; do
    rg -q "$fixture_pattern" "$fixture_file"
done

rg -q 'EsRegexCallback::RegexCallbackSession' "$docs"
rg -q 'ES-SCRIPT-035' "$ledger"
rg -q 'P11 replacement-callback follow-up' "$plan"

printf 'regex callback audit: bounded span accounting, callback output, and zero-width progress are present\n'
