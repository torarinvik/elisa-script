#!/usr/bin/env bash

# Compiler-free audit for ordered, budgeted output rendering.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/output_renderer_model.elisa"
output_model="$repo_root/src/runtime/output_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$output_model" "$ir" "$fixture" "$docs" "$ledger" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'output renderer audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsOutputRender:' \
    'const module Limits:' \
    'Limits::CHUNKS' \
    'CHUNKS: usize = EsOutput::Limits::RECORDS + 2' \
    'const enum OutputRenderState of u8:' \
    'const enum OutputRenderEvent of u8:' \
    'struct OutputRender:' \
    'error OutputRenderError:' \
    'def validate_output_render(' \
    'def advance_output_render('; do
    rg -Fq "$declaration" "$model"
done

for boundary in \
    'output_render_json_escaped_bytes' \
    'output_render_xml_escaped_bytes' \
    'output_render_accumulate' \
    'output_render_expected_emitted_bytes' \
    'output_render_header_bytes' \
    'output_render_footer_bytes' \
    'DocumentNotSealed' \
    'render.document.state != OutputDocumentState.Sealed' \
    'RecordOrderInvalid' \
    'AccountingInvalid' \
    'RenderLimitExceeded' \
    'Incomplete' \
    'CancelNotReady'; do
    rg -Fq "$boundary" "$model"
done

rg -Fq 'include "../runtime/output_renderer_model.elisa"' "$ir"
rg -Fq 'using EsOutputRender' "$fixture"
for fixture_pattern in \
    'typed_output_renderer_contract_is_ordered_escaped_and_cancelable' \
    'OutputRenderEvent.Emit' \
    'OutputRenderEvent.Finish' \
    'OutputRenderEvent.CancelAck' \
    'OutputRenderState.Complete' \
    'render_budget_rejected' \
    'forged_emitted_rejected'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq 'EsOutputRender adds the renderer-side state machine' "$docs"
rg -Fq 'ES-SCRIPT-003 | EsOutputRender' "$ledger"
rg -Fq 'explicit EsOutputRender contract' "$plan"

printf 'output renderer audit: sealed admission, ordered records, escaping budgets, framing, and cancellation are present\n'
