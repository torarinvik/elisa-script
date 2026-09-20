#!/usr/bin/env bash

# Compiler-free audit for bounded process-session lifecycles.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/process_session_model.elisa"
clock_model="$repo_root/src/runtime/monotonic_time_model.elisa"
time_bridge="$repo_root/src/runtime/time_posix.elisa"
process_model="$repo_root/src/runtime/process_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
execution="$repo_root/src/ir/execution.elisa"
interpreter="$repo_root/src/ir/interpret.elisa"
lowerer="$repo_root/src/ir/lower_ast.elisa"
verifier="$repo_root/src/ir/ir_verify.elisa"
execution_bytecode="$repo_root/src/bytecode/bytecode.elisa"
semantic_builtin_checker="$repo_root/vendor/elisa-compiler/src/semantic/check_ufcs_unknown_method.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
lowering_fixture="$repo_root/test/ir/elisascript_lowering_test.elisa"
interpreter_fixture="$repo_root/test/ir/elisascript_interpreter_test.elisa"
bytecode_fixture="$repo_root/test/ir/elisascript_bytecode_test.elisa"
semantic_fixture="$repo_root/test/semantic/elisascript_semantic_test.elisa"
command_policy_fixture="$repo_root/test/driver/process_session_command_limits.elisascript"
exit_deadline_fixture="$repo_root/test/driver/process_session_exit_deadline.elisascript"
clock_fixture="$repo_root/test/driver/monotonic_time_model.elisascript"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"

for required_file in "$model" "$clock_model" "$time_bridge" "$process_model" "$ir" "$execution" "$interpreter" "$lowerer" "$verifier" "$execution_bytecode" "$semantic_builtin_checker" "$fixture" "$lowering_fixture" "$interpreter_fixture" "$bytecode_fixture" "$semantic_fixture" "$command_policy_fixture" "$exit_deadline_fixture" "$clock_fixture" "$docs" "$ledger"; do
    [[ -f "$required_file" ]] || { printf 'process session audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsProcessSession:' \
    'PROCESS_SESSION_MAX_POLLS' \
    'PROCESS_SESSION_MAX_OUTPUT_BYTES' \
    'def process_session_for_command(' \
    'def session_elapsed_state_valid(' \
    'def session_next_elapsed_micros(' \
    'elapsed_sampled: bool = false' \
    'ProcessSessionState.TimingOut' \
    'ProcessSessionEvent.TimeoutAck' \
    'ProcessSessionError.TimeoutNotReady' \
    'const enum ProcessSessionState of u8:' \
    'const enum ProcessSessionEvent of u8:' \
    'struct ProcessSession:' \
    'error ProcessSessionError:' \
    'def validate_process_session(' \
    'def advance_process_session('; do
    rg -Fq "$declaration" "$model"
done

rg -Fq 'terminal Exit receipts for finite-deadline commands must include' "$model"
rg -Fq 'next_elapsed_micros: u64 = try session_next_elapsed_micros(session, elapsed_micros_delta, elapsed_sampled)' "$model"
rg -Fq 'finite_deadline_exit_requires_a_clock_sample' "$exit_deadline_fixture"
rg -Fq 'exit_observed_at_deadline_enters_timeout_cleanup' "$exit_deadline_fixture"
rg -Fq 'exit_observed_before_deadline_preserves_exit_status' "$exit_deadline_fixture"
rg -Fq 'session.state == ProcessSessionState.TimingOut' "$exit_deadline_fixture"
rg -Fq 'CLOCK_MONOTONIC' "$time_bridge"
rg -Fq 'clock_gettime' "$time_bridge"
rg -Fq 'EsMonotonicTime::MonotonicTimestamp' "$time_bridge"
rg -Fq 'NANOSECONDS_PER_MICROSECOND' "$clock_model"
rg -Fq 'monotonic_elapsed_microseconds' "$clock_model"
rg -Fq 'fractional_microseconds: u64' "$clock_model"
rg -Fq 'include "../runtime/monotonic_time_model.elisa"' "$ir"
rg -Fq 'include "../runtime/monotonic_time_model.elisa"' "$execution"
rg -Fq 'PROCESS_DEFAULT_TIMEOUT_MICROS: u64 = 120000000u64' "$process_model"
rg -Fq 'MAX_RUNTIME_MICROS: u64 = EsProcess::PROCESS_DEFAULT_TIMEOUT_MICROS' "$interpreter"
rg -Fq 'timeout_micros: u64 = ProcessWait::MAX_RUNTIME_MICROS' "$interpreter"
rg -Fq 'timeout_micros: timeout_micros}' "$interpreter"
rg -Fq 'timeout_micros: mutable u64 = ProcessWait::MAX_RUNTIME_MICROS' "$interpreter"
rg -Fq 'evaluate_run_process(machine, storage, executable_value, arguments_value, timeout_micros)' "$interpreter"
rg -Fq 'timeout_value.integer < 0' "$interpreter"
rg -Fq 'run_process_value(storage, process_executable.text, process_arguments, process_timeout_micros)' "$execution_bytecode"
rg -Fq 'name: "run_process", receiver: "global", arity_min: 2, arity_max: 3, argument_types: "Executable,darray[text],i64"' "$repo_root/vendor/elisa-compiler/src/semantic/builtin_registry.elisa"
rg -Fq 'process_timeout_micros: mutable u64 = EsProcess::PROCESS_DEFAULT_TIMEOUT_MICROS' "$execution_bytecode"
rg -Fq 'timeout_type: Type = type_from_name("i64")' "$lowerer"
rg -Fq 'spec.argument_types == "Executable,darray[text],i64" and index == 2' "$semantic_builtin_checker"
rg -Fq 'spec.argument_types == "Executable,darray[text],sview,i64,i64" and index == 0' "$semantic_builtin_checker"
rg -Fq 'spec.argument_types == "Executable,darray[text],sview,i64,i64" and index == 1' "$semantic_builtin_checker"
rg -Fq 'spec.argument_types == "Executable,darray[text],sview,i64,i64" and index == 2' "$semantic_builtin_checker"
rg -Fq 'spec.argument_types == "Executable,darray[text],sview,i64,i64" and (index == 3 or index == 4)' "$semantic_builtin_checker"
rg -Fq 'operand_count: mutable u16 = 2' "$lowerer"
rg -Fq 'timeout_value.type.bits == 64' "$lowerer"
rg -Fq 'valid_run_process_arity: bool = instruction.operand_count == 2 or instruction.operand_count == 3' "$verifier"
rg -Fq 'timeout_type.bits == 64 and timeout_type.signed' "$verifier"
rg -Fq 'argument_type.name == "i64")) if expected == "i64"' "$semantic_builtin_checker"
rg -Fq 'process_timeout_micros <- timeout_value.integer.u64()' "$execution_bytecode"
rg -Fq 'opcode_has_operand_count(timeout_fn.instruction_pool, Opcode.RunProcess, 3)' "$lowering_fixture"
rg -Fq 'invalid_timeout_source' "$lowering_fixture"
rg -Fq 'wrong_timeout_type_source' "$lowering_fixture"
rg -Fq 'def times_out() -> i64' "$interpreter_fixture"
rg -Fq 'def negative_timeout() -> i64' "$interpreter_fixture"
rg -Fq 'assert timeout_rejected' "$interpreter_fixture"
rg -Fq 'reference_timeout_rejected and direct_timeout_rejected' "$bytecode_fixture"
rg -Fq 'negative_reference_rejected and negative_direct_rejected' "$bytecode_fixture"
rg -Fq 'def capture_times_out() -> sview' "$interpreter_fixture"
rg -Fq 'def negative_capture_timeout() -> sview' "$interpreter_fixture"
rg -Fq 'assert capture_timeout_rejected' "$interpreter_fixture"
rg -Fq 'capture_timeout_reference_rejected and capture_timeout_direct_rejected' "$bytecode_fixture"
rg -Fq 'negative_capture_reference_rejected and negative_capture_direct_rejected' "$bytecode_fixture"
rg -Fq 'evaluate_capture_process_stream(machine, storage, executable_value, arguments_value, 1, timeout_micros)' "$interpreter"
rg -Fq 'capture_process_stdout_value(storage, process_executable.text, process_arguments, process_timeout_micros)' "$execution_bytecode"
rg -Fq 'capture_process_stderr_value(storage, process_executable.text, process_arguments, process_timeout_micros)' "$execution_bytecode"
rg -Fq 'valid_process_stream_arity: bool = instruction.operand_count == 2 or instruction.operand_count == 3' "$verifier"
rg -Fq 'valid_timeout <- timeout_type.kind == TypeKind.Int and timeout_type.bits == 64 and timeout_type.signed' "$verifier"
rg -Fq 'def capture_result_times_out() -> ProcessCapture' "$interpreter_fixture"
rg -Fq 'def negative_capture_result_timeout() -> ProcessCapture' "$interpreter_fixture"
rg -Fq 'result_timeout_reference_rejected and result_timeout_direct_rejected' "$bytecode_fixture"
rg -Fq 'negative_result_timeout_reference_rejected and negative_result_timeout_direct_rejected' "$bytecode_fixture"
rg -Fq 'valid_process_result_arity: bool = instruction.operand_count >= base_process_result_arity and instruction.operand_count <= base_process_result_arity + 2' "$verifier"
rg -Fq 'capture_process_result_value(storage, process_executable.text, process_arguments, process_input.text, process_timeout_micros, process_capture_output_limit_bytes)' "$execution_bytecode"
rg -Fq 'process_capture_output_limit_bytes <- output_limit_value.integer.usize()' "$execution_bytecode"
rg -Fq 'remaining_process_output: usize = ES_RUNTIME_DEFAULT_MAX_OUTPUT_BYTES - output_bytes' "$execution_bytecode"
rg -Fq 'process_capture_output_limit_bytes <- remaining_process_output if remaining_process_output < process_capture_output_limit_bytes' "$execution_bytecode"
rg -Fq 'evaluate_capture_process_result(machine, storage, executable_value, arguments_value, input_value, runtime_void(), runtime_void(), timeout_micros, output_limit_bytes)' "$interpreter"
rg -Fq 'output_limit_value.integer.u64() > ES_RUNTIME_DEFAULT_MAX_OUTPUT_BYTES.u64()' "$interpreter"
rg -Fq 'opcode_has_operand_count(bounded_fn.instruction_pool, Opcode.CaptureProcessResult, 5)' "$lowering_fixture"
rg -Fq 'registry_process_result_timeout_requires_i64' "$semantic_fixture"
rg -Fq 'registry_process_result_output_limit_requires_i64' "$semantic_fixture"
rg -Fq 'name: "capture_process_result", receiver: "global", arity_min: 3, arity_max: 5, argument_types: "Executable,darray[text],sview,i64,i64"' "$repo_root/vendor/elisa-compiler/src/semantic/builtin_registry.elisa"
rg -Fq 'capture_output_limit: mutable u64 = process_output_remaining(machine)' "$interpreter"
rg -Fq 'output_limit: capture_output_limit' "$interpreter"
rg -Fq 'interpreter_capture_process_result_enforces_callsite_output_limit' "$interpreter_fixture"
rg -Fq 'bytecode_direct_capture_process_result_enforces_callsite_output_limit' "$bytecode_fixture"
rg -Fq 'interpreter_cwd_environment_capture_applies_callsite_policies' "$interpreter_fixture"
rg -Fq 'bytecode_direct_cwd_environment_capture_applies_callsite_policies' "$bytecode_fixture"
rg -Fq 'registry_process_capture_policy_arguments_require_i64' "$semantic_fixture"
rg -Fq 'capture_process_result_in_directory_with_environment_value(storage, process_executable.text, process_arguments, process_input.text, process_directory.text, process_environment, process_timeout_micros, process_capture_output_limit_bytes)' "$execution_bytecode"
rg -Fq 'output_limit_bytes: usize = ES_RUNTIME_DEFAULT_MAX_OUTPUT_BYTES' "$interpreter"
rg -Fq 'capture_process_result_in_directory_with_environment_value(storage: mutable darray[RuntimeValue]&, executable: sview, arguments: RuntimeValue, input: sview, directory: sview, environment: RuntimeValue, timeout_micros: u64 = ProcessWait::MAX_RUNTIME_MICROS, output_limit_bytes: usize = ES_RUNTIME_DEFAULT_MAX_OUTPUT_BYTES)' "$interpreter"
rg -Fq 'name: "capture_process_result_in_directory_with_environment", receiver: "global", arity_min: 5, arity_max: 7, argument_types: "Executable,darray[text],sview,Path,dict[sview,sview],i64,i64"' "$repo_root/vendor/elisa-compiler/src/semantic/builtin_registry.elisa"
rg -Fq 'def process_timeout_admitted(' "$interpreter"
rg -Fq 'if not process_timeout_admitted(machine, timeout_micros):' "$interpreter"
rg -Fq 'timeout_micros > EsProcess::PROCESS_COMMAND_MAX_TIMEOUT_MICROS' "$interpreter"
rg -Fq 'def process_wait_clock_start(' "$interpreter"
rg -Fq 'def process_wait_deadline_reached(' "$interpreter"
rg -Fq 'if not waiter.clock_started and not process_wait_clock_start(waiter)' "$interpreter"
rg -Fq 'return elapsed >= waiter.timeout_micros' "$interpreter"
rg -Fq 'if process_wait_deadline_reached(waiter):' "$interpreter"
rg -Fq 'waiter.timed_out <- true' "$interpreter"
rg -Fq 'process_wait_terminate_group(waiter)' "$interpreter"
rg -Fq 'elapsed_time_handles_nanosecond_borrow' "$clock_fixture"
rg -Fq 'fractional_microseconds_round_up_for_deadline_safety' "$clock_fixture"
rg -Fq 'elapsed_microsecond_conversion_is_bounded' "$clock_fixture"

for boundary in \
    'session_stream_handle_valid' \
    'session_handle_ids_distinct' \
    'stdin_resource_id' \
    'session.command.stdin_mode' \
    'OutputLimitExceeded' \
    'PollLimitExceeded' \
    'InvalidOutcome' \
    'session.state == ProcessSessionState.Exited' \
    'session.exit_status <- exit_status' \
    'session.exit_status < 0' \
    'session.state != ProcessSessionState.Exited and session.exit_status != 0' \
    'session.state == ProcessSessionState.Created' \
    'session.state == ProcessSessionState.Created and session.result_kind != ProcessResultKind.SpawnFailure' \
    'session.state == ProcessSessionState.Running or session.state == ProcessSessionState.Collecting' \
    'session.state == ProcessSessionState.Failed and session.result_kind != ProcessResultKind.HostIoFailure' \
    'session.state == ProcessSessionState.TimedOut' \
    'session.max_output_bytes > session.command.capture_output_limit_bytes' \
    'session.command.timeout_micros != 0 and session.elapsed_micros == session.command.timeout_micros' \
    'session.elapsed_micros <- next_elapsed_micros' \
    'ExitNotReady' \
    'CancelNotReady' \
    'AccountingInvalid'; do
    rg -Fq "$boundary" "$model"
done

rg -Fq 'session_inherits_the_command_capture_ceiling' "$command_policy_fixture"
rg -Fq 'session_cannot_widen_the_command_capture_ceiling' "$command_policy_fixture"
rg -Fq 'poll_elapsed_time_enforces_the_command_deadline' "$command_policy_fixture"
rg -Fq 'deadline_overshoot_saturates_at_timeout' "$command_policy_fixture"
rg -Fq 'command_can_exit_before_deadline' "$command_policy_fixture"
rg -Fq 'timeout_ack_requires_cleanup_to_be_pending' "$command_policy_fixture"
rg -Fq 'ProcessSessionError.ClockSampleMissing' "$command_policy_fixture"
rg -Fq 'ProcessSessionError.InvalidLimit' "$command_policy_fixture"

rg -Fq 'include "../runtime/process_session_model.elisa"' "$ir"
rg -Fq 'using EsProcessSession' "$fixture"
for fixture_pattern in \
    'typed_process_session_contract_bounds_streams_polls_and_outcomes' \
    'ProcessSessionEvent.Spawn' \
    'ProcessSessionEvent.Stdout' \
    'ProcessSessionEvent.Exit' \
    'ProcessSessionEvent.CancelAck' \
    'forged_active_outcome' \
    'forged_timeout_status'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq 'session.exit_status == 17' "$fixture"

rg -Fq 'EsProcessSession binds that command value to an adapter lifecycle' "$docs"
rg -Fq 'ES-SCRIPT-007 | EsProcessSession' "$ledger"

printf 'process session audit: bounded streams/polls, typed outcomes, timeout accounting, and cancellation are present\n'
