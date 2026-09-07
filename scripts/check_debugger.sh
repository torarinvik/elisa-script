#!/usr/bin/env bash

# Compiler-free audit for bounded debugger sessions.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/debugger_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture_file="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$ir" "$fixture_file" "$docs" "$ledger" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'debugger audit: missing %s\n' "$required_file" >&2; exit 1; }
done

rg -q '^module EsDebugger:' "$model"
rg -q 'include "\.\./runtime/debugger_model\.elisa"' "$ir"
for declaration in \
    'const enum DebuggerState of u8' \
    'const enum DebuggerEvent of u8' \
    'struct DebuggerPolicy:' \
    'struct DebuggerBreakpoint:' \
    'struct DebuggerFrame:' \
    'struct DebuggerBranch:' \
    'struct DebuggerSession:' \
    'error DebuggerError:' \
    'def validate_debugger_session\(' \
    'def debugger_set_breakpoint\(' \
    'def debugger_push_frame\(' \
    'def advance_debugger\('; do
    rg -q "$declaration" "$model"
done

for boundary in \
    'DEBUGGER_MAX_BREAKPOINTS' \
    'DEBUGGER_MAX_FRAMES' \
    'DEBUGGER_MAX_BRANCHES' \
    'DebuggerEvent.SelectBranch' \
    'DebuggerEvent.Step' \
    'DebuggerError.InvalidTransition' \
    'DebuggerError.BranchSelectionInvalid' \
    'DebuggerError.InvalidDepth'; do
    rg -q "$boundary" "$model"
done

for fixture_pattern in \
    'using EsDebugger' \
    'typed_debugger_contract_controls_breakpoints_frames_and_replay' \
    'DebuggerEvent.SelectBranch' \
    'DebuggerEvent.Step' \
    'DebuggerError.InvalidTransition'; do
    rg -q "$fixture_pattern" "$fixture_file"
done

rg -q 'EsDebugger::DebuggerSession' "$docs"
rg -q 'ES-SCRIPT-049' "$ledger"
rg -q 'P14 debugger follow-up' "$plan"

printf 'debugger audit: bounded breakpoints, frames, replay selection, and terminal states are present\n'
