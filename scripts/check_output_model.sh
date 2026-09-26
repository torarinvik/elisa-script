#!/usr/bin/env bash

# Compiler-free audit for stable human/machine output records.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/output_model.elisa"
human_model="$repo_root/src/runtime/output_human_model.elisa"
json_model="$repo_root/src/runtime/output_json_model.elisa"
junit_model="$repo_root/src/runtime/output_junit_model.elisa"
renderer="$repo_root/src/runtime/output_renderer_model.elisa"
transport="$repo_root/src/runtime/output_transport_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
execution="$repo_root/src/ir/execution.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"

for required_file in "$model" "$human_model" "$json_model" "$junit_model" "$renderer" "$transport" "$ir" "$execution" "$fixture" "$docs"; do
    [[ -f "$required_file" ]] || { printf 'output model audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsOutput:' \
    'const module Limits:' \
    'Limits::RECORDS' \
    'Limits::TEXT_BYTES' \
    'Limits::NAME_BYTES' \
    'const enum OutputFormat of u8:' \
    'const enum OutputStatus of u8:' \
    'const enum OutputDocumentState of u8:' \
    'struct OutputOptions:' \
    'struct OutputRecord:' \
    'struct OutputDocument:' \
    'error OutputContractError:' \
    'def validate_output_options(' \
    'def validate_output_document(' \
    'def advance_output_document('; do
    rg -Fq "$declaration" "$model"
done

for boundary in \
    'TextLimitExceeded' \
    'TextAccountingInvalid' \
    'accounted_text' \
    'FailedRecordAccountingInvalid' \
    'RecordLimitExceeded' \
    'InvalidColorMode' \
    'OutputLimitInvalid' \
    'AppendNotReady' \
    'SealNotReady' \
    'OutputStatus.Flaky' \
    'output_record_is_empty_payload' \
    'failed_records'; do
    rg -Fq "$boundary" "$model"
done

rg -Fq 'include "../runtime/output_model.elisa"' "$ir"
for human_boundary in \
    'module EsOutputHuman:' \
    'def render_output_document_human(' \
    'def render_output_human_header_frame(' \
    'def render_output_human_record_frame(' \
    'def render_output_human_footer_frame(' \
    'def measure_output_human_record_frame(' \
    'output_human_append_footer(' \
    'output_human_append_escaped_text(' \
    'output_human_append_hex_byte(' \
    'InvalidColorMode' \
    'count_only'; do
    rg -Fq "$human_boundary" "$human_model"
done
for json_boundary in \
    'module EsOutputJson:' \
    'output_json_append_string(' \
    'output_json_append_footer(' \
    'def render_output_document_json(' \
    'def render_output_json_header_frame(' \
    'def render_output_json_record_frame(' \
    'def render_output_json_footer_frame(' \
    'def measure_output_json_header_frame(' \
    'def measure_output_json_record_frame(' \
    'def measure_output_json_footer_frame(' \
    'summary' \
    'InvalidUtf8' \
    'count_only'; do
    rg -Fq "$json_boundary" "$json_model"
done

for junit_boundary in \
    'def render_output_document_junit(' \
    'def render_output_junit_header_frame(' \
    'def render_output_junit_record_frame(' \
    'def render_output_junit_footer_frame(' \
    'def measure_output_junit_header_frame(' \
    'def measure_output_junit_record_frame(' \
    'def measure_output_junit_footer_frame(' \
    'count_only'; do
    rg -Fq "$junit_boundary" "$junit_model"
done

rg -Fq 'using EsOutputJson' "$renderer"
rg -Fq 'using EsOutputHuman' "$renderer"
rg -Fq 'measure_output_json_record_frame' "$renderer"
rg -Fq 'measure_output_junit_record_frame' "$renderer"
rg -Fq 'output_render_expected_document_bytes' "$renderer"
rg -Fq 'def measure_output_render_document_bytes(' "$renderer"
rg -Fq 'FrameLimitExceeded' "$renderer"
rg -Fq 'struct OutputTransportPayload:' "$transport"
rg -Fq 'using EsOutputHuman' "$transport"
rg -Fq 'def peek_output_transport_payload(' "$transport"
rg -Fq 'def acknowledge_output_transport_payload(' "$transport"
rg -Fq 'output_transport_payload_bytes_equal' "$transport"
rg -Fq 'FramePayloadMismatch' "$transport"
rg -Fq 'include "../runtime/output_json_model.elisa"' "$ir"
rg -Fq 'include "../runtime/output_human_model.elisa"' "$ir"
rg -Fq 'include "../runtime/output_junit_model.elisa"' "$ir"
rg -Fq 'include "../runtime/output_human_model.elisa"' "$execution"
rg -Fq 'include "../runtime/output_json_model.elisa"' "$execution"
rg -Fq 'include "../runtime/output_junit_model.elisa"' "$execution"
for fixture_pattern in \
    'typed_output_document_contract_is_stable_and_bounded' \
    'typed_output_human_frames_are_exact_bounded_and_color_aware' \
    'invalid_text' \
    'typed_output_json_frames_match_schema_and_bounded_document_serialization' \
    'typed_output_junit_frames_match_bounded_document_serialization' \
    'altered_payload_rejected' \
    'transport_limit_rejected' \
    'transport_frame_limit_rejected' \
    'transport_chunk_limit_rejected' \
    'render_budget_rejected' \
    'OutputFormat.Json' \
    'OutputStatus.Fail' \
    'OutputDocumentEvent.Seal' \
    'OutputContractError.OutputLimitInvalid' \
    'OutputContractError.TextAccountingInvalid' \
    'extraneous_begin_payload_rejected' \
    'text_accounting_rejected'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq '`EsOutput` gives launcher, test, and differential renderers' "$docs"
rg -Fq '`EsOutputHuman`' "$docs"
rg -Fq '`EsOutputJson`' "$docs"
rg -Fq '`EsOutputJunit`' "$docs"

printf 'output model audit: bounded Human/JSON/JUnit serializers, frames, and sealed document accounting are present\n'
