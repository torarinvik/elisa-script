#!/usr/bin/env bash

# Compiler-free audit for ordered, budgeted output rendering.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/output_renderer_model.elisa"
transport="$repo_root/src/runtime/output_transport_model.elisa"
output_model="$repo_root/src/runtime/output_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$transport" "$output_model" "$ir" "$fixture" "$docs" "$ledger" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'output renderer audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsOutputRender:' \
    'const module Limits:' \
    'Limits::CHUNKS' \
    'CHUNKS: usize = EsOutput::Limits::RECORDS + 2' \
    'const enum OutputRenderState of u8:' \
    'const enum OutputRenderEvent of u8:' \
    'const enum OutputRenderFrameKind of u8:' \
    'struct OutputRenderFrame:' \
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

for declaration in \
    'module EsOutputTransport:' \
    'const module Limits:' \
    'const enum OutputTransportState of u8:' \
    'const enum OutputTransportEvent of u8:' \
    'struct OutputTransportPolicy:' \
    'struct OutputTransport:' \
    'error OutputTransportError:' \
    'def validate_output_transport(' \
    'def begin_output_transport(' \
    'def peek_output_transport_frame(' \
    'def advance_output_transport('; do
    rg -Fq "$declaration" "$transport"
done

for boundary in \
    'FrameMismatch' \
    'FrameOrderInvalid' \
    'FrameTooLarge' \
    'ShortWrite' \
    'max_frame_bytes' \
    'output_transport_frame_matches' \
    'OutputTransportState.Cancelling' \
    'OutputTransportState.Cancelled'; do
    rg -Fq "$boundary" "$transport"
done

rg -Fq 'include "../runtime/output_renderer_model.elisa"' "$ir"
rg -Fq 'include "../runtime/output_transport_model.elisa"' "$ir"
rg -Fq 'using EsOutputRender' "$fixture"
rg -Fq 'using EsOutputTransport' "$fixture"
for fixture_pattern in \
    'typed_output_renderer_contract_is_ordered_escaped_and_cancelable' \
    'OutputRenderEvent.Emit' \
    'OutputRenderEvent.Finish' \
    'OutputRenderEvent.CancelAck' \
    'OutputRenderState.Complete' \
    'render_budget_rejected' \
    'forged_emitted_rejected' \
    'typed_output_transport_binds_frames_to_exact_host_acknowledgements' \
    'OutputTransportEvent.Emit' \
    'OutputTransportError.FrameMismatch'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq 'EsOutputRender adds the renderer-side state machine' "$docs"
rg -Fq '`EsOutputTransport` wraps that renderer' "$docs"
rg -Fq 'ES-SCRIPT-003 | EsOutputRender' "$ledger"
rg -Fq 'explicit EsOutputRender contract' "$plan"

printf 'output renderer audit: sealed admission, ordered records, escaping budgets, framing, and cancellation are present\n'
