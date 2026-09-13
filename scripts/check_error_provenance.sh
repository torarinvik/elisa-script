#!/usr/bin/env bash

# Compiler-free audit for typed cross-boundary error provenance.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/error_provenance_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture_file="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$ir" "$fixture_file" "$docs" "$ledger" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'error provenance audit: missing %s\n' "$required_file" >&2; exit 1; }
done

rg -q '^module EsErrorProvenance:' "$model"
rg -q 'include "\.\./runtime/error_provenance_model\.elisa"' "$ir"
for declaration in \
    'const enum ErrorOrigin of u8' \
    'const enum ErrorPhase of u8' \
    'const enum ErrorEnvelopeState of u8' \
    'struct ErrorProvenance:' \
    'struct ErrorEnvelope:' \
    'struct ErrorProvenanceLedger:' \
    'error ErrorProvenanceError:' \
    'def validate_error_provenance\(' \
    'def error_provenance_capture\(' \
    'def advance_error_provenance\('; do
    rg -q "$declaration" "$model"
done

for boundary in \
    'Limits::ENVELOPES' \
    'Limits::TEXT_BYTES' \
    'Limits::CAUSE_DEPTH' \
    'ErrorOrigin.InvalidCompilerOutput' \
    'ErrorOrigin.LimitExceeded' \
    'ErrorProvenanceEvent.Forward' \
    'ErrorProvenanceError.InvalidCause' \
    'ErrorEnvelopeState.Captured and envelope.forward_count != 0' \
    'ErrorEnvelopeState.Forwarded and envelope.forward_count == 0' \
    'ErrorProvenanceError.CauseDepthExceeded' \
    'ErrorProvenanceError.CancelNotReady'; do
    rg -q "$boundary" "$model"
done

for fixture_pattern in \
    'using EsErrorProvenance' \
    'typed_error_provenance_contract_preserves_origin_and_cause' \
    'ErrorOrigin.Host' \
    'ErrorOrigin.Script' \
    'ErrorProvenanceEvent.Handle' \
    'ErrorProvenanceError.InvalidCause' \
    'forged_forward_history'; do
    rg -q "$fixture_pattern" "$fixture_file"
done

rg -q 'EsErrorProvenance::ErrorProvenanceLedger' "$docs"
rg -q 'ES-SCRIPT-043' "$ledger"
rg -q 'P6 error-provenance follow-up' "$plan"

printf 'error provenance audit: bounded origin, phase, cause, and terminal transitions are present\n'
