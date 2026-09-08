#!/usr/bin/env bash

# Compiler-free audit for stable human/machine output records.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/output_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$ir" "$fixture" "$docs" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'output model audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsOutput:' \
    'OUTPUT_MAX_RECORDS' \
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
    'FailedRecordAccountingInvalid' \
    'RecordLimitExceeded' \
    'InvalidColorMode' \
    'OutputLimitInvalid' \
    'AppendNotReady' \
    'SealNotReady' \
    'failed_records'; do
    rg -Fq "$boundary" "$model"
done

rg -Fq 'include "../runtime/output_model.elisa"' "$ir"
for fixture_pattern in \
    'typed_output_document_contract_is_stable_and_bounded' \
    'OutputFormat.Json' \
    'OutputStatus.Fail' \
    'OutputDocumentEvent.Seal' \
    'OutputContractError.OutputLimitInvalid'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq '`EsOutput` gives launcher, test, and differential renderers' "$docs"
rg -Fq 'P14 output follow-up' "$plan"

printf 'output model audit: bounded human/JSON/JUnit records and sealed document accounting are present\n'
