#!/usr/bin/env bash

# Compiler-free audit for bounded typed record numeric parsing.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/record_numeric_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture_file="$repo_root/test/ir/elisascript_ir_test.elisa"
runtime_fixture="$repo_root/test/runtime/record_numeric_model_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"

for required_file in "$model" "$ir" "$fixture_file" "$runtime_fixture" "$docs" "$ledger"; do
    [[ -f "$required_file" ]] || { printf 'record numeric audit: missing %s\n' "$required_file" >&2; exit 1; }
done

rg -q '^module EsRecordNumeric:' "$model"
rg -q 'include "\.\./runtime/record_numeric_model\.elisa"' "$ir"
for declaration in \
    'const enum RecordNumericKind of u8' \
    'const enum RecordNumericPhase of u8' \
    'const enum RecordNumericEvent of u8' \
    'struct RecordNumericPolicy:' \
    'struct RecordNumericResult:' \
    'struct RecordNumericSession:' \
    'error RecordNumericError:' \
    'def validate_record_numeric_session\(' \
    'def record_numeric_result\(' \
    'def advance_record_numeric\('; do
    rg -q "$declaration" "$model"
done

for boundary in \
    'RECORD_NUMERIC_MAX_BYTES' \
    'RECORD_NUMERIC_MAX_DIGITS' \
    'RECORD_NUMERIC_MAX_EXPONENT_DIGITS' \
    'const RECORD_NUMERIC_MAX_EXPONENT_DIGITS: usize = 20' \
    'record_numeric_integer_limit' \
    'record_numeric_exponent_limit' \
    'RecordNumericError.IntegerOverflow' \
    'RecordNumericError.UnderscorePlacement' \
    'RecordNumericError.ExponentLimitExceeded' \
    'RecordNumericError.AccountingInvalid' \
    'wide_exponent' \
    'record_numeric_trailing_point_valid' \
    'trailing_point_candidate' \
    'session.digits > session.chars' \
    'session.saw_exponent and session.phase' \
    'RecordNumericState.Planned' \
    'RecordNumericEvent.Finish' \
    'RecordNumericEvent.Cancel'; do
    rg -q "$boundary" "$model"
done
rg -Fq 'underscore_decimal_rejected' "$fixture_file"
rg -Fq 'record_numeric_accepts_trailing_decimal_point_forms' "$runtime_fixture"
rg -Fq 'point_result.coefficient_digits == 1 and point_result.fraction_digits == 0' "$runtime_fixture"
rg -Fq 'exponent_result.coefficient_digits == 1 and exponent_result.fraction_digits == 0' "$runtime_fixture"
rg -Fq 'forged_trailing_point_rejected <- failure == RecordNumericError.AccountingInvalid' "$runtime_fixture"

for fixture_pattern in \
    'using EsRecordNumeric' \
    'typed_record_numeric_contract_checks_signed_unsigned_and_decimal_lexemes' \
    'RecordNumericKind.Integer' \
    'RecordNumericKind.Unsigned' \
    'RecordNumericKind.Decimal' \
    'RecordNumericError.SignNotAllowed' \
    'RecordNumericError.TrailingSeparator' \
    'RecordNumericError.IntegerOverflow' \
    'RecordNumericError.AccountingInvalid' \
    'forged'; do
    rg -q "$fixture_pattern" "$fixture_file"
done

rg -q 'EsRecordNumeric::RecordNumericSession' "$docs"
rg -q 'ES-SCRIPT-038' "$ledger"

printf 'record numeric audit: bounded signed/unsigned/decimal lexical parsing is present\n'
