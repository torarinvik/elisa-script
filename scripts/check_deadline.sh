#!/usr/bin/env bash

# Compiler-free audit for monotonic and deterministic deadline clocks.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/deadline_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture_file="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$ir" "$fixture_file" "$docs" "$ledger" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'deadline audit: missing %s\n' "$required_file" >&2; exit 1; }
done

rg -q '^module EsDeadline:' "$model"
rg -q 'include "\.\./runtime/deadline_model\.elisa"' "$ir"
for declaration in \
    'const enum DeadlineClockMode of u8' \
    'const enum DeadlineWaitState of u8' \
    'const enum DeadlineEvent of u8' \
    'struct DeadlinePolicy:' \
    'struct DeadlineWait:' \
    'struct DeadlineClock:' \
    'error DeadlineError:' \
    'def validate_deadline_clock\(' \
    'def deadline_arm\(' \
    'def deadline_advance\(' \
    'def deadline_fire\(' \
    'def deadline_cancel\('; do
    rg -q "$declaration" "$model"
done

for boundary in \
    'Limits::WAITS' \
    'Limits::ADVANCE' \
    'DeadlineClockMode.HostMonotonic' \
    'DeadlineClockMode.Virtual' \
    'DeadlineError.DeadlineInPast' \
    'DeadlineError.AdvanceLimitExceeded' \
    'DeadlineError.NoDueWait' \
    'DeadlineError.FireOrderInvalid' \
    'for candidate in clock.waits' \
    'wait.state == DeadlineWaitState.Ready and wait.deadline > clock.now' \
    'DeadlineError.AccountingInvalid'; do
    rg -q "$boundary" "$model"
done

for fixture_pattern in \
    'using EsDeadline' \
    'typed_deadline_contract_is_monotonic_and_fireable_in_virtual_time' \
    'DeadlineClockMode.Virtual' \
    'DeadlineError.NoDueWait' \
    'DeadlineError.AdvanceLimitExceeded' \
    'DeadlineError.FireOrderInvalid'; do
    rg -q "$fixture_pattern" "$fixture_file"
done

rg -q 'EsDeadline::DeadlineClock' "$docs"
rg -q 'ES-SCRIPT-048' "$ledger"
rg -q 'P12/P8 deadline follow-up' "$plan"

printf 'deadline audit: monotonic host/virtual time, bounded waits, and due-fire transitions are present\n'
