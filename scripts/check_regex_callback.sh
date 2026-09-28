#!/usr/bin/env bash

# Compiler-free audit for bounded regex replacement callbacks.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/regex_callback_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture_file="$repo_root/test/ir/elisascript_ir_test.elisa"
runtime_fixture="$repo_root/test/runtime/regex_callback_model_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"

for required_file in "$model" "$ir" "$fixture_file" "$runtime_fixture" "$docs" "$ledger"; do
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
    'pending_output_before' \
    'replaced_input_bytes: usize = 0' \
    'replacement_total_bytes: usize = 0' \
    'session.pending_output_before <- session.output_bytes' \
    'session.pending_output_before <- 0' \
    'session.pending_start <- 0' \
    'session.pending_end <- 0' \
    'session.has_last_zero <- false' \
    'session.last_zero_start <- 0' \
    'pending_prefix_bytes' \
    'expected_pending_output' \
    'accounting_position: usize = session.pending_start if session.pending else session.cursor' \
    'session.output_bytes + session.replaced_input_bytes != accounting_position + session.replacement_total_bytes' \
    'session.cursor <- session.pending_start if session.pending' \
    'has_last_zero' \
    'RegexCallbackError.NonProgress' \
    'RegexCallbackError.ReplacementNotReady' \
    'RegexCallbackError.OutputLimitExceeded' \
    'RegexCallbackError.AccountingInvalid' \
    'not session.policy.global and session.matches > 1' \
    'session.matches == 0 and (session.captures != 0 or session.replaced_input_bytes != 0 or session.replacement_total_bytes != 0 or session.has_last_zero)' \
    'not session.has_last_zero and session.last_zero_start != 0' \
    'session.has_last_zero and session.last_zero_start > session.input_bytes' \
    'session.state == RegexCallbackState.Complete and session.cursor != session.input_bytes' \
    'session.state == RegexCallbackState.Matching and session.matches == 0' \
    'session.matches != 0 and not session.pending and session.cursor == 0' \
    'at_consumed_eof: bool = session.cursor == session.input_bytes and session.last_zero_start == session.input_bytes' \
    'session.cursor <- session.input_bytes' \
    'policy.max_captures != 0' \
    'session.pending and session.state != RegexCallbackState.Matching' \
    'session.pending and session.pending_start < session.cursor' \
    'RegexCallbackEvent.Match' \
    'RegexCallbackEvent.Replace' \
    'RegexCallbackState.Complete'; do
    rg -q "$boundary" "$model"
done
rg -Fq 'regex_callback_rejects_match_count_without_span_progress' "$runtime_fixture"
rg -Fq 'regex_callback_rejects_forged_pending_prefix_accounting' "$runtime_fixture"
rg -Fq 'regex_callback_rejects_zero_width_marker_ahead_of_cursor' "$runtime_fixture"
rg -Fq 'regex_callback_accepts_empty_input_zero_width_match_at_eof' "$runtime_fixture"
rg -Fq 'regex_callback_abort_clears_unconsumed_zero_width_match' "$runtime_fixture"
rg -Fq 'regex_callback_uses_matcher_supplied_zero_width_advance' "$runtime_fixture"
rg -Fq 'regex_callback_rejects_missing_or_oversized_zero_width_advance' "$runtime_fixture"
rg -Fq 'regex_callback_rejects_forged_completed_output_accounting' "$runtime_fixture"
rg -Fq 'zero_width_advance_bytes: usize = 0' "$model"
rg -Fq 'raise RegexCallbackError.NonProgress if zero_width_advance_bytes == 0' "$model"
rg -Fq 'session.cursor <- session.pending_start + preserved' "$model"
rg -Fq 'zero_width_advance_bytes: 1' "$fixture_file"
rg -Fq 'assert zero.output_bytes == 2' "$fixture_file"

for fixture_pattern in \
    'using EsRegexCallback' \
    'typed_regex_callback_contract_accounts_spans_and_zero_width_progress' \
    'RegexCallbackEvent.Match' \
    'RegexCallbackEvent.Replace' \
    'RegexCallbackError.NonProgress' \
    'RegexCallbackError.MatchLimitExceeded' \
    'RegexCallbackError.AccountingInvalid' \
    'forged_pending' \
    'forged_matching_prefix' \
    'forged_pending_order' \
    'forged_zero_marker' \
    'forged_zero_offset' \
    'forged_complete_cursor' \
    'forged_complete_captures' \
    'forged_complete_zero_marker' \
    'forged_non_global_multiple_matches' \
    'zero_capture_policy'; do
    rg -q "$fixture_pattern" "$fixture_file"
done

rg -q 'EsRegexCallback::RegexCallbackSession' "$docs"
rg -q 'ES-SCRIPT-035' "$ledger"

printf 'regex callback audit: bounded span accounting, callback output, and zero-width progress are present\n'
