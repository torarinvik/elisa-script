#!/usr/bin/env bash

# Compiler-free audit for the shared typed-builtin registry surface. This
# checks that public and private registry rows are complete and that
# semantic/lowering code consumes the same metadata for every registered
# spelling, including compiler-owned intrinsics.

set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
registry_file="$repo_root/vendor/elisa-compiler/src/semantic/builtin_registry.elisa"
semantic_file="$repo_root/vendor/elisa-compiler/src/semantic/symbols.elisa"
receiver_semantic_file="$repo_root/vendor/elisa-compiler/src/semantic/check_ufcs_unknown_method.elisa"
firm_argument_file="$repo_root/vendor/elisa-compiler/src/semantic/check_firm_arg_type_mismatch.elisa"
literal_argument_file="$repo_root/vendor/elisa-compiler/src/semantic/check_literal_arg_type_mismatch.elisa"
inference_file="$repo_root/vendor/elisa-compiler/src/semantic/resolve_types_infer.elisa"
structural_inference_file="$repo_root/vendor/elisa-compiler/src/semantic/resolve_types.elisa"
lowerer_file="$repo_root/src/ir/lower_ast.elisa"
interpreter_file="$repo_root/src/ir/interpret.elisa"
bytecode_file="$repo_root/src/bytecode/bytecode.elisa"
opcode_file="$repo_root/src/ir/ir_model.elisa"
verifier_file="$repo_root/src/ir/ir_verify.elisa"
lowering_test_file="$repo_root/test/ir/elisascript_lowering_test.elisa"
ir_test_file="$repo_root/test/ir/elisascript_ir_test.elisa"
interpreter_test_file="$repo_root/test/ir/elisascript_interpreter_test.elisa"
bytecode_test_file="$repo_root/test/ir/elisascript_bytecode_test.elisa"
semantic_test_file="$repo_root/test/semantic/elisascript_semantic_test.elisa"
surface_doc="$repo_root/docs/builtin-surface.md"
ledger_doc="$repo_root/docs/capabilities/ledger.md"

for required_file in "$registry_file" "$semantic_file" "$receiver_semantic_file" "$firm_argument_file" "$literal_argument_file" "$inference_file" "$structural_inference_file" "$lowerer_file" "$interpreter_file" "$bytecode_file" "$opcode_file" "$verifier_file" "$lowering_test_file" "$ir_test_file" "$interpreter_test_file" "$bytecode_test_file" "$semantic_test_file" "$surface_doc" "$ledger_doc"; do
    if [[ ! -f "$required_file" ]]; then
        printf 'builtin registry audit: missing file: %s\n' "$required_file" >&2
        exit 2
    fi
done

registry_names="$(sed -n '/def typed_builtin_names/,/^        def /p' "$registry_file" | rg -o '"[a-z_][a-z0-9_]*"' | tr -d '"' | sort -u)"
method_names="$(sed -n '/def typed_builtin_method_names/,/^        def typed_builtin_regex_method_names/p' "$registry_file" | rg -o '"[a-z_][a-z0-9_]*"' | tr -d '"' | sort -u)"
regex_method_names="$(sed -n '/def typed_builtin_regex_method_names/,/^        def typed_builtin_path_method_names/p' "$registry_file" | rg -o '"[a-z_][a-z0-9_]*"' | tr -d '"' | sort -u)"
if [[ -z "$registry_names" ]]; then
    printf 'builtin registry audit: typed_builtin_names is empty\n' >&2
    exit 1
fi
if [[ -z "$method_names" ]]; then
    printf 'builtin registry audit: typed_builtin_method_names is empty\n' >&2
    exit 1
fi
if [[ -z "$regex_method_names" ]]; then
    printf 'builtin registry audit: typed_builtin_regex_method_names is empty\n' >&2
    exit 1
fi

for name in $registry_names; do
    if ! rg -q "name == \"$name\"" "$registry_file"; then
        printf 'builtin registry audit: %s has no typed spec row\n' "$name" >&2
        exit 1
    fi
    if ! rg -q "callee_name == \"$name\"" "$lowerer_file"; then
        case "$name" in
            process_exit_status|process_stdout|process_stderr)
                if ! rg -q 'process_result_accessor: bool = registry_spec\.known and registry_spec\.receiver == "global" and registry_spec\.argument_types == "ProcessCapture"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven process accessor dispatch for %s\n' "$name" >&2
                    exit 1
                fi
                ;;
            capture_process_stdout|capture_process_stderr|capture_process_stdout_with_stdin|capture_process_stderr_with_stdin)
                if ! rg -q 'is_registry_process_stream_capture_spec\(registry_spec\)' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven process stream dispatch for %s\n' "$name" >&2
                    exit 1
                fi
                ;;
            capture_process_result|capture_process_result_in_directory|capture_process_result_with_environment|capture_process_result_in_directory_with_environment)
                if ! rg -q 'is_registry_process_result_capture_spec\(registry_spec\)' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven process result dispatch for %s\n' "$name" >&2
                    exit 1
                fi
                ;;
            capture_process_pipeline|capture_process_pipeline_pipefail)
                if ! rg -q 'registry_spec\.opcode == "CaptureProcessPipeline"' "$lowerer_file" || ! rg -q 'registry_spec\.opcode == "CaptureProcessPipelinePipefail"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven process pipeline dispatch for %s\n' "$name" >&2
                    exit 1
                fi
                ;;
            sleep|sleep_seconds|sleep_milliseconds|sleep_ms)
                if ! rg -q 'registry_spec\.opcode == "Sleep"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven sleep dispatch for %s\n' "$name" >&2
                    exit 1
                fi
                ;;
            get_environment|getenv|get_environment_or|getenv_or)
                if ! rg -q 'registry_spec\.opcode == "GetEnvironment"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven environment-read dispatch for %s\n' "$name" >&2
                    exit 1
                fi
                ;;
            set_environment|setenv|unset_environment|unsetenv)
                if ! rg -q 'registry_spec\.opcode == "SetEnvironment" or registry_spec\.opcode == "UnsetEnvironment"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven environment-mutation dispatch for %s\n' "$name" >&2
                    exit 1
                fi
                ;;
            write_stdout|write_stderr|printf)
                if ! rg -q 'registry_spec\.opcode == "WriteStdout" or registry_spec\.opcode == "WriteStderr"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven standard-stream dispatch for %s\n' "$name" >&2
                    exit 1
                fi
                ;;
            create_directory|mkdir|create_directories|makedirs|mkdir_p|remove_directory|rmdir|change_directory|cd|chdir)
                if ! rg -q 'directory_builtin: bool = registry_spec\.known and registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven directory-mutation dispatch for %s\n' "$name" >&2
                    exit 1
                fi
                ;;
            executable)
                if ! rg -q 'registry_spec\.opcode == "MakeExecutable"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven executable dispatch\n' >&2
                    exit 1
                fi
                ;;
            run_process)
                if ! rg -q 'registry_spec\.opcode == "RunProcess"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven process-run dispatch\n' >&2
                    exit 1
                fi
                ;;
            run_process_with_stdin|run_process_in_directory|run_process_with_environment|run_process_in_directory_with_environment)
                if ! rg -q 'registry_spec\.opcode == "ProcessResultExitStatus" and registry_spec\.lowering_steps != ""' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven composed process dispatch for %s\n' "$name" >&2
                    exit 1
                fi
                ;;
            temp_file|mktemp|temp_directory|temp_dir|mkdtemp)
                if ! rg -q 'registry_spec\.opcode == "CreateTemporary"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven temporary-path dispatch for %s\n' "$name" >&2
                    exit 1
                fi
                ;;
            is_readable|is_writable|is_executable)
                if ! rg -q 'access_builtin: bool = registry_spec\.known and registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path" and registry_spec\.opcode == "PathAccess"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven path-access dispatch for %s\n' "$name" >&2
                    exit 1
                fi
                ;;
            len)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.opcode == "Length"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven length dispatch\n' >&2
                    exit 1
                fi
                ;;
            raise)
                if ! rg -q 'registry_spec\.known and registry_spec\.opcode == "Raise"' "$lowerer_file" || \
                   rg -q 'callee_name == "raise"' "$lowerer_file" || \
                   ! rg -q 'def lower_raise_expression\(arguments: darray\[Ast::Expr\].*spec: EsBuiltin::BuiltinSpec' "$lowerer_file" || \
                   ! rg -q 'result_type: Type = typed_builtin_result_type\(spec\)' "$lowerer_file" || \
                   ! rg -q 'name: "raise".*arity_min: 1.*arity_max: 1.*argument_types: "error".*return_type: "void".*opcode: "Raise"' "$registry_file" || \
                   ! rg -q 'registry_raise_requires_one_error_constructor_argument' "$semantic_test_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven raise dispatch\n' >&2
                    exit 1
                fi
                ;;
            resume)
                if ! rg -q 'registry_spec\.known and registry_spec\.opcode == "Resume"' "$lowerer_file" || \
                   rg -q 'callee_name == "resume"' "$lowerer_file" || \
                   ! rg -q 'valid_shape: bool = builtin_call_shape\(registry_spec, arguments, argument_names\)' "$lowerer_file" || \
                   ! rg -q 'name: "resume".*arity_min: 2.*arity_max: 2.*argument_types: "text,any".*return_type: "polymorphic".*opcode: "Resume"' "$registry_file" || \
                   ! rg -q 'filesystem_alias_and_resume_intrinsics_are_known_to_the_source_semantic_pass' "$semantic_test_file" || \
                   ! rg -q 'registry_resume_requires_handler_name_and_payload' "$semantic_test_file" || \
                   ! rg -q 'registry_resume_requires_text_handler_name' "$semantic_test_file" || \
                   ! rg -q 'spec\.argument_types == "text,any"' "$receiver_semantic_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven resume dispatch\n' >&2
                    exit 1
                fi
                ;;
            contains)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.opcode == "Contains"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven contains dispatch\n' >&2
                    exit 1
                fi
                ;;
            is_empty|isempty)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.opcode == "Equal" and registry_spec\.lowering_steps == "Length,Equal"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven empty predicate dispatch for %s\n' "$name" >&2
                    exit 1
                fi
                ;;
            is_nonempty|nonempty|file_nonempty)
                if ! rg -q 'registry_spec\.receiver == "global" and \(\(registry_spec\.opcode == "Greater" and registry_spec\.lowering_steps == "Length,Greater"\) or \(registry_spec\.opcode == "FileSize" and registry_spec\.lowering_steps == "FileSize,Greater"\)\)' "$lowerer_file" || \
                   rg -q 'callee_name == "file_nonempty"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven nonempty dispatch for %s\n' "$name" >&2
                    exit 1
                fi
                ;;
            int)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.opcode == "ParseInt" and registry_spec\.lowering_steps == "ParseInt\|IdentityInt"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven integer-constructor dispatch\n' >&2
                    exit 1
                fi
                ;;
            float)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.opcode == "ParseFloat" and registry_spec\.lowering_steps == "ParseFloat\|IdentityFloat"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven float-constructor dispatch\n' >&2
                    exit 1
                fi
                ;;
            bool)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.opcode == "Copy" and registry_spec\.lowering_steps == "IdentityBool"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven bool-constructor dispatch\n' >&2
                    exit 1
                fi
                ;;
            starts_with|startswith)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.opcode == "StartsWith"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven starts-with dispatch for %s\n' "$name" >&2
                    exit 1
                fi
                ;;
            ends_with|endswith)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.opcode == "EndsWith"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven ends-with dispatch for %s\n' "$name" >&2
                    exit 1
                fi
                ;;
            replace)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.opcode == "TextReplace"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven text-replace dispatch\n' >&2
                    exit 1
                fi
                ;;
            strip|trim|lstrip|rstrip)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.opcode == "TrimText"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven trim dispatch for %s\n' "$name" >&2
                    exit 1
                fi
                ;;
            lower|upper|casefold)
                if ! rg -q 'registry_spec\.receiver == "global" and \(registry_spec\.opcode == "LowerText" or registry_spec\.opcode == "UpperText"\)' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven case dispatch for %s\n' "$name" >&2
                    exit 1
                fi
                ;;
            regex_search|regex_match|regex_fullmatch)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Regex,text" and registry_spec\.opcode == "RegexSearch"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven regex search dispatch for %s\n' "$name" >&2
                    exit 1
                fi
                ;;
            regex_findall)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Regex,text" and registry_spec\.opcode == "RegexFind"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven regex find dispatch\n' >&2
                    exit 1
                fi
                ;;
            regex_count)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Regex,text" and registry_spec\.opcode == "RegexFind" and registry_spec\.lowering_steps == "RegexFind,Length"' "$lowerer_file" || \
                   ! rg -q 'def lower_regex_namespace_count\(arguments: darray\[Ast::Expr\]' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven regex count composition\n' >&2
                    exit 1
                fi
                ;;
            regex_capture_named)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Regex,text,text" and registry_spec\.opcode == "RegexCaptureNamed"' "$lowerer_file" || \
                   ! rg -q 'def lower_regex_namespace_capture_named\(arguments: darray\[Ast::Expr\]' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven named regex capture dispatch\n' >&2
                    exit 1
                fi
                ;;
            regex_split)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Regex,text" and registry_spec\.opcode == "RegexSplit"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven regex split dispatch\n' >&2
                    exit 1
                fi
                ;;
            regex_sub)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Regex,text,text" and registry_spec\.opcode == "RegexReplace"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven regex substitution dispatch\n' >&2
                    exit 1
                fi
                ;;
            matches)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "text,Regex" and registry_spec\.opcode == "RegexSearch"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven pattern-first match dispatch\n' >&2
                    exit 1
                fi
                ;;
            replace_regex)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "text,Regex,text" and registry_spec\.opcode == "RegexReplace"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven pattern-first replacement dispatch\n' >&2
                    exit 1
                fi
                ;;
            split_regex)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "text,Regex" and registry_spec\.opcode == "RegexSplit"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven pattern-first split dispatch\n' >&2
                    exit 1
                fi
                ;;
            find_regex)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "text,Regex" and registry_spec\.opcode == "RegexFind"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven pattern-first find dispatch\n' >&2
                    exit 1
                fi
                ;;
            capture_regex|captures_regex)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "text,Regex" and registry_spec\.opcode == "RegexCapture"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven pattern-first capture dispatch for %s\n' "$name" >&2
                    exit 1
                fi
                ;;
            parse_int)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "text" and registry_spec\.opcode == "ParseInt"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven integer parse dispatch\n' >&2
                    exit 1
                fi
                ;;
            parse_float)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "text" and registry_spec\.opcode == "ParseFloat"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven float parse dispatch\n' >&2
                    exit 1
                fi
                ;;
            format_int)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "i64" and registry_spec\.opcode == "FormatInt"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven integer format dispatch\n' >&2
                    exit 1
                fi
                ;;
            format_float)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "f64" and registry_spec\.opcode == "FormatFloat"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven float format dispatch\n' >&2
                    exit 1
                fi
                ;;
            format_bool)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "bool" and registry_spec\.opcode == "FormatBool"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven bool format dispatch\n' >&2
                    exit 1
                fi
                ;;
            format_char)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "char" and registry_spec\.opcode == "FormatChar"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven char format dispatch\n' >&2
                    exit 1
                fi
                ;;
            join)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "darray\[text\],text" and registry_spec\.opcode == "Join"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven join dispatch\n' >&2
                    exit 1
                fi
                ;;
            reversed)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.opcode == "ReverseArray"' "$lowerer_file" || \
                   ! rg -q 'argument_types: "array".*return_type: "array".*opcode: "ReverseArray"' "$registry_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven reversed dispatch\n' >&2
                    exit 1
                fi
                ;;
            sorted)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.opcode == "SortArray"' "$lowerer_file" || \
                   ! rg -q 'argument_types: "array,bool".*argument_names: "reverse".*return_type: "array".*opcode: "SortArray"' "$registry_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven sorted dispatch\n' >&2
                    exit 1
                fi
                ;;
            observe)
                if ! rg -q 'registry_spec\.known and registry_spec\.opcode == "Observe"' "$lowerer_file" || \
                   ! rg -q 'result_type: Type = typed_builtin_result_type\(registry_spec\)' "$lowerer_file" || \
                   ! rg -q 'name: "observe".*argument_types: "any".*return_type: "void".*opcode: "Observe"' "$registry_file" || \
                   ! rg -q 'source_observe_declaration_takes_precedence_over_registry_trace_builtin' "$semantic_test_file" || \
                   ! rg -q 'shadowed-observe' "$lowering_test_file"; then
                    printf 'builtin registry audit: observe registry/source-shadow coverage is missing\n' >&2
                    exit 1
                fi
                ;;
            assert)
                if ! rg -q 'registry_spec\.known and registry_spec\.opcode == "Assert"' "$lowerer_file" || \
                   ! rg -q 'name: "assert".*argument_types: "bool".*return_type: "void".*errors: "AssertionError".*opcode: "Assert"' "$registry_file" || \
                   ! rg -q 'source_assert_declaration_takes_precedence_over_registry_assert_builtin' "$semantic_test_file" || \
                   ! rg -q 'shadowed-assert' "$lowering_test_file"; then
                    printf 'builtin registry audit: assert registry/source-shadow coverage is missing\n' >&2
                    exit 1
                fi
                ;;
            panic)
                if ! rg -q 'registry_spec\.known and registry_spec\.opcode == "Panic"' "$lowerer_file" || \
                   ! rg -q 'name: "panic".*arity_min: 0.*arity_max: 1.*argument_types: "any".*return_type: "void".*effects: "Abort\.Panic".*opcode: "Panic"' "$registry_file" || \
                   ! rg -q 'source_panic_declaration_takes_precedence_over_registry_panic_builtin' "$semantic_test_file" || \
                   ! rg -q 'shadowed-panic' "$lowering_test_file"; then
                    printf 'builtin registry audit: panic registry/source-shadow coverage is missing\n' >&2
                    exit 1
                fi
                ;;
            print|println|echo|eprint)
                expected_opcode="WriteStdout"
                if [[ "$name" == "eprint" ]]; then
                    expected_opcode="WriteStderr"
                fi
                if ! rg -q 'registry_spec\.known and \(registry_spec\.opcode == "WriteStdout" or registry_spec\.opcode == "WriteStderr"\) and registry_spec\.argument_types == "print"' "$lowerer_file" || \
                   ! rg -q "name: \"$name\".*arity_min: 0.*arity_max: 4294967295.*argument_types: \"print\".*return_type: \"usize\".*effects: \"Console.Write\".*errors: \"ConsoleError\".*opcode: \"$expected_opcode\"" "$registry_file" || \
                   ! rg -q 'spec\.argument_types == "print"' "$receiver_semantic_file" || \
                   ! rg -q 'source_print_declaration_takes_precedence_over_registry_console_builtin' "$semantic_test_file" || \
                   ! rg -q 'invalid_print_control_source' "$semantic_test_file" || \
                   ! rg -q 'shadowed-print' "$lowering_test_file"; then
                    printf 'builtin registry audit: console registry/source-shadow/control coverage is missing for %s\n' "$name" >&2
                    exit 1
                fi
                ;;
            abs)
                if ! rg -q 'registry_spec\.known and registry_spec\.opcode == "Negate" and registry_spec\.lowering_steps == "Compare,Negate,Select"' "$lowerer_file" || \
                   ! rg -q 'name: "abs".*arity_min: 1.*arity_max: 1.*argument_types: "i64\|f64".*return_type: "numeric".*opcode: "Negate".*lowering_steps: "Compare,Negate,Select"' "$registry_file" || \
                   ! rg -q 'numeric_polymorphic_builtin_result_types_are_preserved' "$semantic_test_file" || \
                   ! rg -q 'lowers_typed_abs_through_state_machine' "$lowering_test_file" || \
                   ! rg -q 'shadowed-abs' "$lowering_test_file"; then
                    printf 'builtin registry audit: abs registry/polymorphic/source-shadow coverage is missing\n' >&2
                    exit 1
                fi
                ;;
            min|max)
                if ! rg -q 'registry_spec\.known and registry_spec\.argument_types == "orderable\|array" and registry_spec\.opcode == "SortArray" and registry_spec\.lowering_steps == "SortArray,Index"' "$lowerer_file" || \
                   ! rg -q 'registry_spec\.name == "max"' "$lowerer_file" || \
                   rg -q 'callee_name == "max"' "$lowerer_file" || \
                   ! rg -q "name: \"$name\".*arity_min: 1.*arity_max: 4294967295.*argument_types: \"orderable\\|array\".*return_type: \"polymorphic\".*opcode: \"SortArray\".*lowering_steps: \"SortArray,Index\"" "$registry_file" || \
                   ! rg -q 'polymorphic_collection_builtins_preserve_known_element_types' "$semantic_test_file" || \
                   ! rg -q 'lowers_python_min_max_as_typed_extrema' "$lowering_test_file" || \
                   ! rg -q 'shadowed-min-max' "$lowering_test_file"; then
                    printf 'builtin registry audit: min/max registry/polymorphic/source-shadow coverage is missing for %s\n' "$name" >&2
                    exit 1
                fi
                ;;
            keys|values)
                expected_opcode="MapKeys"
                if [[ "$name" == "values" ]]; then
                    expected_opcode="MapValues"
                fi
                if ! rg -q 'registry_spec\.known and registry_spec\.argument_types == "dict" and \(registry_spec\.opcode == "MapKeys" or registry_spec\.opcode == "MapValues"\)' "$lowerer_file" || \
                   ! rg -q "name: \"$name\".*arity_min: 1.*arity_max: 1.*argument_types: \"dict\".*return_type: \"array\".*opcode: \"$expected_opcode\"" "$registry_file" || \
                   ! rg -q 'collection_and_capture_builtins_preserve_static_result_shapes' "$semantic_test_file" || \
                   ! rg -q 'lowers_python_dictionary_global_aliases' "$lowering_test_file" || \
                   ! rg -q 'shadowed-map-projections' "$lowering_test_file"; then
                    printf 'builtin registry audit: keys/values registry/result/source-shadow coverage is missing for %s\n' "$name" >&2
                    exit 1
                fi
                ;;
            sum|product)
                expected_opcode="Add"
                if [[ "$name" == "product" ]]; then
                    expected_opcode="Multiply"
                fi
                if ! rg -q 'registry_spec\.known and registry_spec\.argument_types == "iterable\|range,i64" and \(registry_spec\.opcode == "Add" or registry_spec\.opcode == "Multiply"\) and registry_spec\.lowering_steps == "Comprehension,Fold"' "$lowerer_file" || \
                   ! rg -q "name: \"$name\".*arity_min: 1.*arity_max: 2.*argument_types: \"iterable\\|range,i64\".*return_type: \"polymorphic\".*opcode: \"$expected_opcode\".*lowering_steps: \"Comprehension,Fold\".*argument_names: \"start\".*named_argument_index: 1" "$registry_file" || \
                   ! rg -q 'polymorphic_collection_builtins_preserve_known_element_types' "$semantic_test_file" || \
                   ! rg -q 'lowers_python_sum_product_any_all_as_state_machine_folds' "$lowering_test_file" || \
                   ! rg -q 'shadowed-sum-product' "$lowering_test_file"; then
                    printf 'builtin registry audit: sum/product registry/fold/source-shadow coverage is missing for %s\n' "$name" >&2
                    exit 1
                fi
                ;;
            any|all)
                expected_step="Comprehension,Any"
                if [[ "$name" == "all" ]]; then
                    expected_step="Comprehension,All"
                fi
                if ! rg -q 'registry_spec\.known and registry_spec\.argument_types == "iterable\|range" and registry_spec\.opcode == "Equal" and \(registry_spec\.lowering_steps == "Comprehension,Any" or registry_spec\.lowering_steps == "Comprehension,All"\)' "$lowerer_file" || \
                   ! rg -q "name: \"$name\".*arity_min: 1.*arity_max: 1.*argument_types: \"iterable\\|range\".*return_type: \"bool\".*opcode: \"Equal\".*lowering_steps: \"$expected_step\"" "$registry_file" || \
                   ! rg -q 'numeric_polymorphic_builtin_result_types_are_preserved' "$semantic_test_file" || \
                   ! rg -q 'lowers_python_sum_product_any_all_as_state_machine_folds' "$lowering_test_file" || \
                   ! rg -q 'shadowed-any-all' "$lowering_test_file"; then
                    printf 'builtin registry audit: any/all registry/quantifier/source-shadow coverage is missing for %s\n' "$name" >&2
                    exit 1
                fi
                ;;
            split)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.opcode == "Split"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven split dispatch\n' >&2
                    exit 1
                fi
                ;;
            split_lines|splitlines)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.opcode == "SplitLines"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven split-lines dispatch for %s\n' "$name" >&2
                    exit 1
                fi
                ;;
            partition|rpartition)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.opcode == "TextPartition"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven partition dispatch for %s\n' "$name" >&2
                    exit 1
                fi
                ;;
            str)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "any" and registry_spec\.opcode == "FormatNominal"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven string-format dispatch\n' >&2
                    exit 1
                fi
                ;;
            path_join)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path,text" and registry_spec\.opcode == "PathJoin"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven path-join dispatch\n' >&2
                    exit 1
                fi
                ;;
            path_parent|dirname)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path" and registry_spec\.opcode == "PathParent"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven path-parent dispatch for %s\n' "$name" >&2
                    exit 1
                fi
                ;;
            path_name|basename)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path" and registry_spec\.opcode == "PathName"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven path-name dispatch for %s\n' "$name" >&2
                    exit 1
                fi
                ;;
            path_extension|suffix|path_stem|stem)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path" and \(registry_spec\.opcode == "PathExtension" or registry_spec\.opcode == "PathStem"\)' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven path-component dispatch for %s\n' "$name" >&2
                    exit 1
                fi
                ;;
            path_is_absolute|is_absolute|isabs)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path" and registry_spec\.opcode == "PathIsAbsolute"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven absolute-path predicate dispatch for %s\n' "$name" >&2
                    exit 1
                fi
                ;;
            path_normalize|normalize_path|normpath)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path" and registry_spec\.opcode == "PathNormalize"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven path-normalize dispatch for %s\n' "$name" >&2
                    exit 1
                fi
                ;;
            path_absolute|absolute_path|abspath)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path" and registry_spec\.opcode == "PathAbsolute"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven absolute-path construction dispatch for %s\n' "$name" >&2
                    exit 1
                fi
                ;;
            path_relative|relative_path|relpath)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path,Path" and registry_spec\.opcode == "PathRelative"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven relative-path dispatch for %s\n' "$name" >&2
                    exit 1
                fi
                ;;
            path_real|realpath|resolve_path)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path" and registry_spec\.opcode == "PathReal"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven real-path dispatch for %s\n' "$name" >&2
                    exit 1
                fi
                ;;
            path_exists|exists)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path" and registry_spec\.opcode == "PathExists"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven existence dispatch for %s\n' "$name" >&2
                    exit 1
                fi
                ;;
            is_file|isfile)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path" and registry_spec\.opcode == "IsFile"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven file-predicate dispatch for %s\n' "$name" >&2
                    exit 1
                fi
                ;;
            touch)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path" and registry_spec\.opcode == "TouchPath"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven touch dispatch\n' >&2
                    exit 1
                fi
                ;;
            chmod)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path,u64" and registry_spec\.opcode == "ChmodPath"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven chmod dispatch\n' >&2
                    exit 1
                fi
                ;;
            file_size|getsize)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path" and registry_spec\.opcode == "FileSize"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven file-size dispatch for %s\n' "$name" >&2
                    exit 1
                fi
                ;;
            file_mode)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path" and registry_spec\.opcode == "FileMode"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven file-mode dispatch\n' >&2
                    exit 1
                fi
                ;;
            file_mtime|getmtime|file_atime|getatime|file_ctime|getctime)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path" and \(registry_spec\.opcode == "FileMTime" or registry_spec\.opcode == "FileATime" or registry_spec\.opcode == "FileCTime"\)' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven file-time dispatch for %s\n' "$name" >&2
                    exit 1
                fi
                ;;
            is_symlink|islink)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path" and registry_spec\.opcode == "IsSymlink"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven symlink-predicate dispatch for %s\n' "$name" >&2
                    exit 1
                fi
                ;;
            readlink|read_link)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path" and registry_spec\.opcode == "ReadLink"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven link-read dispatch for %s\n' "$name" >&2
                    exit 1
                fi
                ;;
            symlink|create_symlink)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path,Path" and registry_spec\.opcode == "SymlinkPath"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven symlink creation dispatch for %s\n' "$name" >&2
                    exit 1
                fi
                ;;
            read_lines|read_text|cat|read_bytes|read_binary)
                if ! rg -q 'is_path_global_unary_spec\(registry_spec\)' "$lowerer_file" && ! rg -q 'is_path_global_array_io_spec\(registry_spec\)' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven path reader dispatch for %s\n' "$name" >&2
                    exit 1
                fi
                ;;
            write_lines|append_lines|write_text|append_text|write_bytes|write_binary|append_bytes|append_binary)
                if ! rg -q 'is_path_global_binary_spec\(registry_spec\)' "$lowerer_file" && ! rg -q 'is_path_global_array_io_spec\(registry_spec\)' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven path writer dispatch for %s\n' "$name" >&2
                    exit 1
                fi
                ;;
            remove_path|rm|remove|unlink|remove_tree|rmtree)
                if ! rg -q 'is_path_global_unary_spec\(registry_spec\)' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven path removal dispatch for %s\n' "$name" >&2
                    exit 1
                fi
                ;;
            copy_path|cp|copyfile|copy_tree|copytree|move_path|mv|rename)
                if ! rg -q 'is_path_global_binary_spec\(registry_spec\)' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven path transfer dispatch for %s\n' "$name" >&2
                    exit 1
                fi
                ;;
            current_directory|pwd|getcwd|read_stdin|read_stdin_line)
                if ! rg -q 'is_registry_zero_arg_spec\(registry_spec\)' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven zero-argument dispatch for %s\n' "$name" >&2
                    exit 1
                fi
                ;;
            input)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "text" and registry_spec\.opcode == "ReadStdinLine"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven input dispatch\n' >&2
                    exit 1
                fi
                ;;
            list_directory|listdir|is_directory|isdir|is_dir)
                if ! rg -q 'is_path_global_unary_spec\(registry_spec\)' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven directory-path dispatch for %s\n' "$name" >&2
                    exit 1
                fi
                ;;
            expand_glob)
                if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Glob" and registry_spec\.opcode == "ExpandGlob"' "$lowerer_file"; then
                    printf 'builtin registry audit: lowerer has no registry-driven glob dispatch\n' >&2
                    exit 1
                fi
                ;;
            *)
                printf 'builtin registry audit: lowerer has no dispatch branch for %s\n' "$name" >&2
                exit 1
                ;;
        esac
    fi
    if rg -q "add_symbol\(\"$name\"" "$semantic_file"; then
        printf 'builtin registry audit: %s is re-seeded outside the typed registry loop\n' "$name" >&2
        exit 1
    fi
    opcode="$(sed -n "s/.*name: \"$name\".*opcode: \"\([A-Za-z0-9_]*\)\".*/\1/p" "$registry_file" | head -1)"
    if [[ -z "$opcode" ]] || ! rg -q "^[[:space:]]*$opcode$" "$opcode_file"; then
        printf 'builtin registry audit: %s has no declared IR opcode (%s)\n' "$name" "${opcode:-missing}" >&2
        exit 1
    fi
    if [[ -z "$opcode" ]] || ! rg -q "Opcode\\.$opcode" "$verifier_file"; then
        printf 'builtin registry audit: %s opcode is not verifier-covered (%s)\n' "$name" "${opcode:-missing}" >&2
        exit 1
    fi
    argument_types="$(sed -n "s/.*name: \"$name\".*argument_types: \"\([^\"]*\)\".*/\1/p" "$registry_file" | head -1)"
    arity_min="$(sed -n "s/.*name: \"$name\".*arity_min: \([0-9][0-9]*\).*/\1/p" "$registry_file" | head -1)"
    if [[ -z "$argument_types" && "${arity_min:-1}" != "0" ]]; then
        printf 'builtin registry audit: %s has no argument-type descriptor\n' "$name" >&2
        exit 1
    fi
done

if ! rg -q 'typed_builtin_method_spec\("Text", method_name\)' "$lowerer_file"; then
    printf 'builtin registry audit: lowerer has no receiver-method registry consumer\n' >&2
    exit 1
fi
if ! rg -q 'typed_builtin_method_spec\("Regex", method_name\)' "$lowerer_file" || \
   ! rg -q 'scripting_regex_builtin_available\(state, method_name\)' "$lowerer_file" || \
   ! rg -q 'is_regex_receiver_expression\(receiver_expression, state\)' "$lowerer_file"; then
    printf 'builtin registry audit: lowerer has no Regex receiver registry consumer\n' >&2
    exit 1
fi
if ! rg -q 'typed_builtin_method_spec\("Map", method_name\)' "$lowerer_file" || \
   ! rg -q 'scripting_map_builtin_available\(state, method_name\)' "$lowerer_file" || \
   ! rg -q 'is_map_receiver_expression\(receiver_expression, state\)' "$lowerer_file" || \
   ! rg -q 'typed_builtin_method_spec\("Map", method\)\.known' "$receiver_semantic_file" || \
   ! rg -q 'ufm_check_map_builtin_arity' "$receiver_semantic_file" || \
   ! rg -q 'typed_builtin_method_spec\("Map", method\)' "$inference_file" || \
   ! rg -q 'scripting_map_method_available\(table, method_name\)' "$inference_file"; then
    printf 'builtin registry audit: Map receiver dispatch, semantic checking, or inference is not registry-backed\n' >&2
    exit 1
fi
if ! rg -q 'typed_builtin_method_spec\("Set", method_name\)' "$lowerer_file" || \
   ! rg -q 'scripting_set_builtin_available\(state, method_name\)' "$lowerer_file" || \
   ! rg -q 'is_set_receiver_expression\(receiver_expression, state\)' "$lowerer_file" || \
   ! rg -q 'typed_builtin_method_spec\("Set", method\)\.known' "$receiver_semantic_file" || \
   ! rg -q 'ufm_check_set_builtin_arity' "$receiver_semantic_file" || \
   ! rg -q 'typed_builtin_method_spec\("Set", method\)' "$inference_file" || \
   ! rg -q 'scripting_set_method_available\(table, method_name\)' "$inference_file"; then
    printf 'builtin registry audit: Set receiver dispatch, semantic checking, or inference is not registry-backed\n' >&2
    exit 1
fi
if ! rg -q 'typed_builtin_method_spec\("Array", method_name\)' "$lowerer_file" || \
   ! rg -q 'scripting_array_builtin_available\(state, method_name\)' "$lowerer_file" || \
   ! rg -q 'is_array_receiver_expression\(receiver_expression, state\)' "$lowerer_file" || \
   ! rg -q 'typed_builtin_method_spec\("Array", method\)\.known' "$receiver_semantic_file" || \
   ! rg -q 'ufm_check_array_builtin_arity' "$receiver_semantic_file" || \
   ! rg -q 'typed_builtin_method_spec\("Array", method\)' "$inference_file" || \
   ! rg -q 'scripting_array_method_available\(table, method_name\)' "$inference_file"; then
    printf 'builtin registry audit: Array receiver dispatch, semantic checking, or inference is not registry-backed\n' >&2
    exit 1
fi
if ! rg -q 'scripting_text_builtin_available\(state, method_name\)' "$lowerer_file"; then
    printf 'builtin registry audit: lowerer does not guard Text dispatch against source shadowing\n' >&2
    exit 1
fi
if ! rg -q 'scripting_regex_builtin_available\(state, method_name\)' "$lowerer_file" || \
   ! rg -q 'scripting_regex_method_available\(table, method_name\)' "$inference_file"; then
    printf 'builtin registry audit: regex receiver dispatch/inference does not guard source shadowing\n' >&2
    exit 1
fi
if ! rg -q 'lowered_function_index\(state, qualified_name\) == state\.function_names\.count' "$lowerer_file"; then
    printf 'builtin registry audit: qualified builtin dispatch does not guard source shadowing\n' >&2
    exit 1
fi
if ! rg -q 'typed_builtin_method_call_shape\("Text", method_name' "$lowerer_file"; then
    printf 'builtin registry audit: lowerer has no receiver-method shape consumer\n' >&2
    exit 1
fi
if ! rg -q 'typed_builtin_method_spec\("Text", method\)\.known' "$receiver_semantic_file"; then
    printf 'builtin registry audit: semantic receiver admission does not consume the Text registry\n' >&2
    exit 1
fi
if ! rg -q 'typed_builtin_method_spec\("Regex", method\)\.known' "$receiver_semantic_file" || \
   ! rg -q 'ufm_check_regex_builtin_arity' "$receiver_semantic_file" || \
   ! rg -q 'ufm_check_regex_builtin_argument_types' "$receiver_semantic_file"; then
    printf 'builtin registry audit: semantic Regex receiver checking does not consume the registry\n' >&2
    exit 1
fi
if ! rg -q 'source_ufcs_owned: bool = ufm_has_source_function\(table, method\)' "$receiver_semantic_file" || \
   ! rg -q 'source_ufcs_available: bool = scripting_has_unique_source_function\(table, method\)' "$receiver_semantic_file" || \
   ! rg -q 'not source_ufcs_owned' "$receiver_semantic_file"; then
    printf 'builtin registry audit: semantic Text diagnostics do not guard source shadowing\n' >&2
    exit 1
fi
if ! rg -q 'symbol\.line != 0' "$receiver_semantic_file" || \
   ! rg -q 'symbol\.line != 0' "$inference_file"; then
    printf 'builtin registry audit: source-shadowing guards do not exclude line-zero builtin seeds\n' >&2
    exit 1
fi
if ! rg -q 'def scripting_has_unique_source_function' "$inference_file" || \
   ! rg -q 'def scripting_source_function_return_type' "$inference_file" || \
   ! rg -q 'def scripting_source_function_return_type_id' "$inference_file" || \
   ! rg -q 'scripting_has_unique_source_function\(table, method_name\)' "$inference_file" || \
   ! rg -q 'scripting_source_function_return_type_id\(table, method_name\)' "$structural_inference_file" || \
   ! rg -q 'def check_source_ufcs_arity' "$repo_root/vendor/elisa-compiler/src/semantic/resolve_expr.elisa" || \
   ! rg -q 'def check_source_ufcs_named_arguments' "$repo_root/vendor/elisa-compiler/src/semantic/resolve_expr.elisa" || \
   ! rg -q 'check_source_ufcs_arity\(table, method, arguments.count \+ 1' "$receiver_semantic_file" || \
   ! rg -q 'check_source_ufcs_named_arguments\(table, method, argument_names' "$receiver_semantic_file" || \
   ! rg -q 'Expr\.Field\(receiver, fn_name' "$firm_argument_file" || \
   ! rg -q 'Expr\.Field\(receiver, fn_name' "$literal_argument_file"; then
    printf 'builtin registry audit: source-owned UFCS calls lack unique-source inference or argument checks\n' >&2
    exit 1
fi
if ! rg -q 'typed_builtin_method_spec\("Text", method\)' "$inference_file"; then
    printf 'builtin registry audit: semantic receiver inference does not consume the Text registry\n' >&2
    exit 1
fi
if ! rg -q 'scripting_text_method_available\(table, method_name\)' "$inference_file"; then
    printf 'builtin registry audit: semantic receiver inference does not guard source shadowing\n' >&2
    exit 1
fi
if ! rg -q 'typed_builtin_method_spec\("Regex", method\)' "$inference_file" || \
   ! rg -q 'scripting_regex_method_available\(table, method_name\)' "$inference_file"; then
    printf 'builtin registry audit: semantic Regex receiver inference does not consume the registry\n' >&2
    exit 1
fi
if ! rg -q 'def typed_builtin_path_method_names\(\)' "$registry_file" || \
   ! rg -q 'name: "parent", receiver: "Path".*argument_types: "".*return_type: "Path".*effects: "".*opcode: "PathParent"' "$registry_file" || \
   ! rg -q 'name: "name", receiver: "Path".*argument_types: "".*return_type: "sview".*effects: "".*opcode: "PathName"' "$registry_file" || \
   ! rg -q 'name: "suffix", receiver: "Path".*argument_types: "".*return_type: "sview".*effects: "".*opcode: "PathExtension"' "$registry_file" || \
   ! rg -q 'name: "stem", receiver: "Path".*argument_types: "".*return_type: "sview".*effects: "".*opcode: "PathStem"' "$registry_file" || \
   ! rg -q 'name: "is_absolute", receiver: "Path".*argument_types: "".*return_type: "bool".*effects: "".*opcode: "PathIsAbsolute"' "$registry_file" || \
   ! rg -q 'name: "normalize", receiver: "Path".*argument_types: "".*return_type: "Path".*effects: "".*opcode: "PathNormalize"' "$registry_file" || \
   ! rg -q 'name: "absolute", receiver: "Path".*argument_types: "".*return_type: "Path".*effects: "Directory.Read".*errors: "DirectoryError".*opcode: "PathAbsolute"' "$registry_file" || \
   ! rg -q 'name: "realpath", receiver: "Path".*argument_types: "".*return_type: "Path".*effects: "File.Read".*errors: "FileIoError".*opcode: "PathReal"' "$registry_file" || \
   ! rg -q 'name: "resolve", receiver: "Path".*argument_types: "".*return_type: "Path".*effects: "File.Read".*errors: "FileIoError".*opcode: "PathReal"' "$registry_file" || \
   ! rg -q 'name: "joinpath", receiver: "Path".*argument_types: "text".*return_type: "Path".*effects: "".*opcode: "PathJoin"' "$registry_file" || \
   ! rg -q 'name: "with_name", receiver: "Path".*argument_types: "text".*return_type: "Path".*effects: "".*opcode: "PathJoin".*lowering_steps: "PathParent,PathJoin"' "$registry_file" || \
   ! rg -q 'name: "with_suffix", receiver: "Path".*argument_types: "text".*return_type: "Path".*effects: "".*opcode: "PathJoin".*lowering_steps: "PathParent,PathStem,Concat,PathJoin"' "$registry_file" || \
   ! rg -q 'name: "relative_to", receiver: "Path".*argument_types: "Path".*return_type: "Path".*effects: "".*opcode: "PathRelative"' "$registry_file" || \
   ! rg -q 'name: "iterdir", receiver: "Path".*argument_types: "".*return_type: "darray\[text\]".*effects: "Directory.Read".*errors: "DirectoryError".*opcode: "PathIterDir"' "$registry_file" || \
   ! rg -q 'name: "glob", receiver: "Path".*argument_types: "text".*return_type: "darray\[text\]".*effects: "Directory.Read".*errors: "DirectoryError".*opcode: "PathGlob"' "$registry_file" || \
   ! rg -q 'name: "rglob", receiver: "Path".*argument_types: "text".*return_type: "darray\[text\]".*effects: "Directory.Read".*errors: "DirectoryError".*opcode: "PathRGlob"' "$registry_file" || \
   ! rg -q 'name: "read_text", receiver: "Path".*argument_types: "".*return_type: "sview".*effects: "File.Read".*errors: "FileIoError".*opcode: "ReadText"' "$registry_file" || \
   ! rg -q 'name: "read_lines", receiver: "Path".*argument_types: "".*return_type: "darray\[text\]".*effects: "File.Read".*errors: "FileIoError".*opcode: "ReadText"' "$registry_file" || \
   ! rg -q 'name: "read_bytes", receiver: "Path".*argument_types: "".*return_type: "darray\[u8\]".*effects: "File.Read".*errors: "FileIoError".*opcode: "ReadBytes"' "$registry_file" || \
   ! rg -q 'name: "write_text", receiver: "Path".*argument_types: "text".*return_type: "usize".*effects: "File.Write".*errors: "FileIoError".*opcode: "WriteText"' "$registry_file" || \
   ! rg -q 'name: "write_lines", receiver: "Path".*argument_types: "darray\[text\]".*return_type: "usize".*effects: "File.Write".*errors: "FileIoError".*opcode: "WriteText"' "$registry_file" || \
   ! rg -q 'name: "write_bytes", receiver: "Path".*argument_types: "darray\[u8\]".*return_type: "usize".*effects: "File.Write".*errors: "FileIoError".*opcode: "WriteBytes"' "$registry_file" || \
   ! rg -q 'name: "append_text", receiver: "Path".*argument_types: "text".*return_type: "usize".*effects: "File.Write".*errors: "FileIoError".*opcode: "AppendText"' "$registry_file" || \
   ! rg -q 'name: "append_lines", receiver: "Path".*argument_types: "darray\[text\]".*return_type: "usize".*effects: "File.Write".*errors: "FileIoError".*opcode: "AppendText"' "$registry_file" || \
   ! rg -q 'name: "append_bytes", receiver: "Path".*argument_types: "darray\[u8\]".*return_type: "usize".*effects: "File.Write".*errors: "FileIoError".*opcode: "AppendBytes"' "$registry_file" || \
   ! rg -q 'name: "symlink_to", receiver: "Path".*argument_types: "Path".*return_type: "bool".*effects: "File.Write".*errors: "FileIoError".*opcode: "SymlinkPath"' "$registry_file" || \
   ! rg -q 'name: "unlink", receiver: "Path".*argument_types: "".*return_type: "bool".*effects: "File.Write".*errors: "FileIoError".*opcode: "RemovePath"' "$registry_file" || \
   ! rg -q 'name: "rename", receiver: "Path".*argument_types: "Path".*return_type: "bool".*effects: "File.Write".*errors: "FileIoError".*opcode: "MovePath"' "$registry_file" || \
   ! rg -q 'name: "chmod", receiver: "Path".*argument_types: "u64".*return_type: "bool".*effects: "File.Write".*errors: "FileIoError".*opcode: "ChmodPath"' "$registry_file" || \
   ! rg -q 'name: "rmdir", receiver: "Path".*argument_types: "".*return_type: "bool".*effects: "Directory.Write".*errors: "DirectoryError".*opcode: "RemoveDirectory"' "$registry_file" || \
   ! rg -q 'name: "touch", receiver: "Path".*argument_types: "bool".*return_type: "bool".*effects: "File.Write".*errors: "FileIoError".*opcode: "TouchPath".*argument_names: "exist_ok".*named_argument_index: 0' "$registry_file" || \
   ! rg -q 'name: "exists", receiver: "Path".*argument_types: "".*return_type: "bool".*effects: "File.Read".*errors: "".*opcode: "PathExists"' "$registry_file" || \
   ! rg -q 'name: "is_file", receiver: "Path".*argument_types: "".*return_type: "bool".*effects: "File.Read".*errors: "".*opcode: "IsFile"' "$registry_file" || \
   ! rg -q 'name: "is_symlink", receiver: "Path".*argument_types: "".*return_type: "bool".*effects: "File.Read".*errors: "".*opcode: "IsSymlink"' "$registry_file" || \
   ! rg -q 'name: "is_dir", receiver: "Path".*argument_types: "".*return_type: "bool".*effects: "Directory.Read".*errors: "DirectoryError".*opcode: "IsDirectory"' "$registry_file" || \
   ! rg -q 'name: "readlink", receiver: "Path".*argument_types: "".*return_type: "Path".*effects: "File.Read".*errors: "FileIoError".*opcode: "ReadLink"' "$registry_file" || \
   ! rg -q 'name: "read_link", receiver: "Path".*argument_types: "".*return_type: "Path".*effects: "File.Read".*errors: "FileIoError".*opcode: "ReadLink"' "$registry_file" || \
   ! rg -q 'name: "is_readable", receiver: "Path".*argument_types: "".*return_type: "bool".*effects: "File.Read".*opcode: "PathAccess".*lowering_mode: 4' "$registry_file" || \
   ! rg -q 'name: "is_writable", receiver: "Path".*argument_types: "".*return_type: "bool".*effects: "File.Read".*opcode: "PathAccess".*lowering_mode: 2' "$registry_file" || \
   ! rg -q 'name: "is_executable", receiver: "Path".*argument_types: "".*return_type: "bool".*effects: "File.Read".*opcode: "PathAccess".*lowering_mode: 1' "$registry_file"; then
    printf 'builtin registry audit: Path access receiver rows are incomplete\n' >&2
    exit 1
fi
if ! rg -q 'typed_builtin_method_spec\("Path", method_name\)' "$lowerer_file" || \
   ! rg -q 'def scripting_path_builtin_available\(state: LowerState&, method_name: sview\)' "$lowerer_file" || \
   ! rg -q 'def is_path_global_unary_spec\(spec: EsBuiltin::BuiltinSpec\)' "$lowerer_file" || \
   ! rg -q 'def lower_path_global_unary\(callee_name: sview' "$lowerer_file" || \
   ! rg -q 'is_path_global_unary_spec\(registry_spec\)' "$lowerer_file" || \
   ! rg -q 'opcode <- Opcode\.FileSize' "$lowerer_file" || \
   ! rg -q 'opcode <- Opcode\.FileMTime' "$lowerer_file" || \
   ! rg -q 'opcode <- Opcode\.FileATime' "$lowerer_file" || \
   ! rg -q 'opcode <- Opcode\.FileCTime' "$lowerer_file" || \
   ! rg -q 'opcode <- Opcode\.FileMode' "$lowerer_file" || \
   ! rg -q 'def is_path_global_binary_spec\(spec: EsBuiltin::BuiltinSpec\)' "$lowerer_file" || \
   ! rg -q 'def lower_path_global_binary\(callee_name: sview' "$lowerer_file" || \
   ! rg -q 'is_path_global_binary_spec\(registry_spec\)' "$lowerer_file" || \
   ! rg -q 'opcode <- Opcode\.SymlinkPath' "$lowerer_file" || \
   ! rg -q 'opcode <- Opcode\.CopyPath' "$lowerer_file" || \
   ! rg -q 'opcode <- Opcode\.MovePath' "$lowerer_file" || \
   ! rg -q 'opcode <- Opcode\.CopyTree' "$lowerer_file" || \
   ! rg -q 'opcode <- Opcode\.WriteText' "$lowerer_file" || \
   ! rg -q 'opcode <- Opcode\.AppendText' "$lowerer_file" || \
   ! rg -q 'opcode <- Opcode\.ChmodPath' "$lowerer_file" || \
   ! rg -q 'opcode <- Opcode\.ReadText' "$lowerer_file" || \
   ! rg -q 'def is_path_global_array_io_spec\(spec: EsBuiltin::BuiltinSpec\)' "$lowerer_file" || \
   ! rg -q 'def lower_path_global_array_io\(callee_name: sview' "$lowerer_file" || \
   ! rg -q 'is_path_global_array_io_spec\(registry_spec\)' "$lowerer_file" || \
   ! rg -q 'def is_path_receiver_expression\(expression: Ast::Expr, state: LowerState&\)' "$lowerer_file" || \
   ! rg -q 'scripting_path_builtin_available\(state, method_name\) or method_name == "mkdir"' "$lowerer_file" || \
   ! rg -q 'path_spec\.known and path_spec\.opcode == "PathParent"' "$lowerer_file" || \
   ! rg -q 'path_spec\.known and path_spec\.opcode == "PathIsAbsolute"' "$lowerer_file" || \
   ! rg -q 'path_spec\.known and path_spec\.opcode == "PathNormalize"' "$lowerer_file" || \
   ! rg -q 'path_spec\.known and path_spec\.opcode == "PathReal"' "$lowerer_file" || \
   ! rg -q 'path_spec\.known and path_spec\.opcode == "PathAbsolute"' "$lowerer_file" || \
   ! rg -q 'path_spec\.known and path_spec\.opcode == "PathJoin"' "$lowerer_file" || \
   ! rg -q 'path_spec\.known and path_spec\.opcode == "PathJoin" and path_spec\.lowering_steps == "PathParent,PathJoin"' "$lowerer_file" || \
   ! rg -q 'path_spec\.known and path_spec\.opcode == "PathJoin" and path_spec\.lowering_steps == "PathParent,PathStem,Concat,PathJoin"' "$lowerer_file" || \
   ! rg -q 'path_spec\.known and path_spec\.opcode == "PathRelative"' "$lowerer_file" || \
   ! rg -q 'path_spec\.known and path_spec\.opcode == "PathIterDir"' "$lowerer_file" || \
   ! rg -q 'path_spec\.known and \(path_spec\.opcode == "PathGlob" or path_spec\.opcode == "PathRGlob"\)' "$lowerer_file" || \
   ! rg -q 'opcode: Opcode = Opcode\.PathRGlob if path_spec\.opcode == "PathRGlob" else Opcode\.PathGlob' "$lowerer_file" || \
   ! rg -q 'path_spec\.known and path_spec\.opcode == "ReadText"' "$lowerer_file" || \
   rg -q 'path_spec\.known and path_spec\.opcode == "ReadText" and .*method_name' "$lowerer_file" || \
   ! rg -q 'path_spec\.known and path_spec\.opcode == "ReadBytes"' "$lowerer_file" || \
   ! rg -q 'path_spec\.known and \(path_spec\.opcode == "WriteText" or path_spec\.opcode == "AppendText"\)' "$lowerer_file" || \
   ! rg -q 'path_spec\.known and \(path_spec\.opcode == "WriteBytes" or path_spec\.opcode == "AppendBytes"\)' "$lowerer_file" || \
   ! rg -q 'opcode: Opcode = Opcode\.AppendText if path_spec\.opcode == "AppendText" else Opcode\.WriteText' "$lowerer_file" || \
   ! rg -q 'opcode: Opcode = Opcode\.AppendBytes if path_spec\.opcode == "AppendBytes" else Opcode\.WriteBytes' "$lowerer_file" || \
   ! rg -q 'path_spec\.known and path_spec\.opcode == "SymlinkPath"' "$lowerer_file" || \
   ! rg -q 'path_spec\.known and path_spec\.opcode == "RemovePath"' "$lowerer_file" || \
   ! rg -q 'path_spec\.known and path_spec\.opcode == "MovePath"' "$lowerer_file" || \
   ! rg -q 'path_spec\.known and path_spec\.opcode == "ChmodPath"' "$lowerer_file" || \
   ! rg -q 'path_spec\.known and path_spec\.opcode == "RemoveDirectory"' "$lowerer_file" || \
   ! rg -q 'path_spec\.known and path_spec\.opcode == "TouchPath"' "$lowerer_file" || \
   ! rg -q 'path_spec\.known and path_spec\.opcode == "PathExists"' "$lowerer_file" || \
   ! rg -q 'path_spec\.known and path_spec\.opcode == "IsFile"' "$lowerer_file" || \
   ! rg -q 'path_spec\.known and path_spec\.opcode == "IsSymlink"' "$lowerer_file" || \
   ! rg -q 'path_spec\.known and path_spec\.opcode == "ReadLink"' "$lowerer_file" || \
   ! rg -q 'path_spec\.known and path_spec\.opcode == "IsDirectory"' "$lowerer_file" || \
   ! rg -q 'path_spec\.known and path_spec\.opcode == "PathAccess"' "$lowerer_file" || \
   ! rg -q 'typed_builtin_method_call_shape\("Path", method_name' "$lowerer_file" || \
   ! rg -q 'instruction_integer <- path_spec\.lowering_mode' "$lowerer_file"; then
    printf 'builtin registry audit: Path receiver lowering does not consume registry metadata\n' >&2
    exit 1
fi
if ! rg -q 'def is_registry_zero_arg_spec\(spec: EsBuiltin::BuiltinSpec\)' "$lowerer_file" || \
   ! rg -q 'def lower_registry_zero_arg\(callee_name: sview' "$lowerer_file" || \
   ! rg -q 'is_registry_zero_arg_spec\(registry_spec\)' "$lowerer_file"; then
    printf 'builtin registry audit: zero-argument registry lowerers are incomplete\n' >&2
    exit 1
fi
if ! rg -q 'opcode <- Opcode\.TouchPath' "$lowerer_file" || \
   ! rg -q 'opcode <- Opcode\.ReadBytes' "$lowerer_file" || \
   ! rg -q 'opcode <- Opcode\.RemovePath' "$lowerer_file" || \
   ! rg -q 'opcode <- Opcode\.RemoveTree' "$lowerer_file" || \
   ! rg -q 'opcode <- Opcode\.CreateDirectory' "$lowerer_file" || \
   ! rg -q 'opcode <- Opcode\.CreateDirectories' "$lowerer_file" || \
   ! rg -q 'opcode <- Opcode\.RemoveDirectory' "$lowerer_file" || \
   ! rg -q 'opcode <- Opcode\.ChangeDirectory' "$lowerer_file" || \
   ! rg -q 'opcode <- Opcode\.ListDirectory' "$lowerer_file"; then
    printf 'builtin registry audit: global Path unary opcode coverage is incomplete\n' >&2
    exit 1
fi
if ! rg -q 'typed_builtin_method_spec\("Path", method\)' "$receiver_semantic_file" || \
   ! rg -q 'ufm_check_path_builtin_arity' "$receiver_semantic_file" || \
   ! rg -q 'ufm_check_path_builtin_argument_types' "$receiver_semantic_file" || \
   ! rg -q 'named_allowed: bool = argument_names\[argument_index\] == "" or \(spec\.argument_names != "" and argument_index\.u32\(\) == spec\.named_argument_index and argument_names\[argument_index\] == spec\.argument_names\)' "$receiver_semantic_file" || \
   ! rg -q '"bool" if spec\.argument_types == "bool" and argument_index == 0' "$receiver_semantic_file" || \
   ! rg -q 'scripting_path_registry_return_type' "$inference_file" || \
   ! rg -q 'scripting_path_method_available\(table, method_name\)' "$inference_file"; then
    printf 'builtin registry audit: Path access receiver semantic consumers are incomplete\n' >&2
    exit 1
fi
if ! rg -q 'argument_names: sview' "$registry_file" || \
   ! rg -q 'named_argument_index: u32' "$registry_file" || \
   ! rg -q 'builtin_named_argument_allowed' "$lowerer_file" || \
   ! rg -q 'named_argument_index' "$lowerer_file" || \
   ! rg -q 'ufm_text_named_argument_allowed' "$receiver_semantic_file" || \
   ! rg -q 'named_argument_index' "$receiver_semantic_file"; then
    printf 'builtin registry audit: named-argument metadata is not shared across registry, semantic, and lowerer layers\n' >&2
    exit 1
fi
if ! rg -q 'ufm_check_text_builtin_arity' "$receiver_semantic_file" || \
   ! rg -q 'spec\.arity_min' "$receiver_semantic_file" || \
   ! rg -q 'DiagnosticKind\.ArityMismatch' "$receiver_semantic_file" || \
   ! rg -q 'DiagnosticKind\.CallArgumentError' "$receiver_semantic_file" || \
   ! rg -q '"no_names"' "$receiver_semantic_file"; then
    printf 'builtin registry audit: semantic receiver arity/named-argument checking does not consume registry ranges\n' >&2
    exit 1
fi
if ! rg -q 'ufm_check_global_builtin_arity' "$receiver_semantic_file" || \
   ! rg -q 'ufm_check_global_builtin_argument_types' "$receiver_semantic_file" || \
   ! rg -q 'ufm_global_argument_expected' "$receiver_semantic_file" || \
   ! rg -q 'not ufm_has_source_function' "$receiver_semantic_file"; then
    printf 'builtin registry audit: global registry rows are not semantically checked with source shadowing\n' >&2
    exit 1
fi
if ! rg -q 'darray\[text\],text' "$registry_file" || \
   ! rg -q 'ufm_text_array_argument_is_text\(expression, var_types, type_names, table\)' "$receiver_semantic_file"; then
    printf 'builtin registry audit: global structural text-array descriptors are not checked through the type table\n' >&2
    exit 1
fi
if ! rg -q 'ufm_check_text_builtin_argument_types' "$receiver_semantic_file" || \
   ! rg -q 'spec\.argument_types' "$receiver_semantic_file" || \
   ! rg -q 'DiagnosticKind\.LiteralArgTypeMismatch' "$receiver_semantic_file" || \
   ! rg -q 'DiagnosticKind\.FirmArgTypeMismatch' "$receiver_semantic_file"; then
    printf 'builtin registry audit: semantic receiver argument checking does not consume registry types\n' >&2
    exit 1
fi
if ! rg -q 'darray\[text\]' "$receiver_semantic_file" || \
   ! rg -q 'structural_type_id_of' "$receiver_semantic_file" || \
   ! rg -q 'interned_elem\(' "$receiver_semantic_file"; then
    printf 'builtin registry audit: structural Text argument descriptors are not checked through the type table\n' >&2
    exit 1
fi
if ! rg -q 'text_method_spec: EsBuiltin::BuiltinSpec' "$inference_file" 2>/dev/null && \
   ! rg -q 'text_method_spec: EsBuiltin::BuiltinSpec' "$repo_root/vendor/elisa-compiler/src/semantic/resolve_types.elisa"; then
    printf 'builtin registry audit: structural Text result inference does not consume receiver registry rows\n' >&2
    exit 1
fi
if ! rg -q 'regex_method_spec: EsBuiltin::BuiltinSpec' "$repo_root/vendor/elisa-compiler/src/semantic/resolve_types.elisa"; then
    printf 'builtin registry audit: structural Regex result inference does not consume receiver registry rows\n' >&2
    exit 1
fi
if ! rg -q 'global_registry_spec: EsBuiltin::BuiltinSpec' "$repo_root/vendor/elisa-compiler/src/semantic/resolve_types.elisa"; then
    printf 'builtin registry audit: structural global result inference does not consume registry rows\n' >&2
    exit 1
fi
if ! rg -q 'return InferType\{kind: SemTypeKind.Container, name: "darray"\} if spec\.known and spec\.return_type == "darray\[u8\]"' "$inference_file" || ! rg -q 'global_registry_spec\.return_type == "darray\[u8\]"' "$structural_inference_file"; then
    printf 'builtin registry audit: byte-array reader result inference is not registry-backed\n' >&2
    exit 1
fi
if ! rg -q 'def record_builtin_contract' "$lowerer_file" || \
   ! rg -q 'record_builtin_contract\(registry_spec, state\)' "$lowerer_file" || \
   ! rg -q 'record_builtin_contract\(method_spec, state\)' "$lowerer_file" || \
   ! rg -q 'def record_receiver_builtin_contract' "$lowerer_file" || \
   ! rg -q 'is_text_receiver_expression' "$lowerer_file" || \
   ! rg -q 'record_receiver_builtin_contract\(receiver_expression, method_name, state\)' "$lowerer_file" || \
   ! rg -q 'state\.required_effects\.push\(spec\.effects\)' "$lowerer_file" || \
   ! rg -q 'state\.required_errors\.push\(spec\.errors\)' "$lowerer_file"; then
    printf 'builtin registry audit: declared effect/error rows are not centrally recorded by lowering\n' >&2
    exit 1
fi
if ! rg -q 'error_name in lowered\.module\.functions\[0\]\.errors where error_name == "ParseError"' "$repo_root/test/ir/elisascript_lowering_test.elisa" || \
   ! rg -q 'has_text\(lowered\.module\.functions\[0\]\.errors, "IndexOutOfBounds"\)' "$repo_root/test/ir/elisascript_lowering_test.elisa"; then
    printf 'builtin registry audit: fallible registry rows lack lowering fixtures\n' >&2
    exit 1
fi
for filesystem_name in path_exists exists; do
    if ! rg -q "name: \"$filesystem_name\", receiver: \"global\".*argument_types: \"Path\".*effects: \"File.Read\".*errors: \"FileIoError\".*opcode: \"PathExists\"" "$registry_file"; then
        printf 'builtin registry audit: filesystem existence row is incomplete: %s\n' "$filesystem_name" >&2
        exit 1
    fi
done
for filesystem_name in is_file isfile; do
    if ! rg -q "name: \"$filesystem_name\", receiver: \"global\".*argument_types: \"Path\".*effects: \"File.Read\".*errors: \"\".*opcode: \"IsFile\"" "$registry_file"; then
        printf 'builtin registry audit: regular-file row is incomplete: %s\n' "$filesystem_name" >&2
        exit 1
    fi
done
for filesystem_name in is_directory isdir is_dir; do
    if ! rg -q "name: \"$filesystem_name\", receiver: \"global\".*argument_types: \"Path\".*effects: \"Directory.Read\".*errors: \"DirectoryError\".*opcode: \"IsDirectory\"" "$registry_file"; then
        printf 'builtin registry audit: directory-predicate row is incomplete: %s\n' "$filesystem_name" >&2
        exit 1
    fi
done
for filesystem_name in is_symlink islink; do
    if ! rg -q "name: \"$filesystem_name\", receiver: \"global\".*argument_types: \"Path\".*effects: \"File.Read\".*errors: \"\".*opcode: \"IsSymlink\"" "$registry_file"; then
        printf 'builtin registry audit: symlink-predicate row is incomplete: %s\n' "$filesystem_name" >&2
        exit 1
    fi
done
for filesystem_name in is_readable is_writable is_executable; do
    if ! rg -q "name: \"$filesystem_name\", receiver: \"global\".*argument_types: \"Path\".*effects: \"File.Read\".*errors: \"\".*opcode: \"PathAccess\"" "$registry_file"; then
        printf 'builtin registry audit: path-access row is incomplete: %s\n' "$filesystem_name" >&2
        exit 1
    fi
done
if ! rg -q 'name: "is_readable", receiver: "global".*opcode: "PathAccess", lowering_mode: 4' "$registry_file" || \
   ! rg -q 'name: "is_writable", receiver: "global".*opcode: "PathAccess", lowering_mode: 2' "$registry_file" || \
   ! rg -q 'name: "is_executable", receiver: "global".*opcode: "PathAccess", lowering_mode: 1' "$registry_file" || \
   ! rg -q 'access_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'access_builtin: bool = registry_spec\.known and registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path" and registry_spec\.opcode == "PathAccess"' "$lowerer_file" || \
   ! rg -q 'integer: access_spec\.lowering_mode' "$lowerer_file"; then
    printf 'builtin registry audit: path-access aliases do not preserve registry POSIX modes\n' >&2
    exit 1
fi
if ! rg -q 'exists_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path" and registry_spec\.opcode == "PathExists"' "$lowerer_file" || \
   ! rg -q 'file_predicate_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path" and registry_spec\.opcode == "IsFile"' "$lowerer_file" || \
   ! rg -q 'symlink_predicate_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path" and registry_spec\.opcode == "IsSymlink"' "$lowerer_file" || \
   ! rg -q 'exists_spec\.opcode != "PathExists"' "$lowerer_file" || \
   ! rg -q 'file_predicate_spec\.opcode != "IsFile"' "$lowerer_file" || \
   ! rg -q 'symlink_predicate_spec\.opcode != "IsSymlink"' "$lowerer_file"; then
    printf 'builtin registry audit: filesystem predicates do not consume registry result/opcode metadata\n' >&2
    exit 1
fi
for filesystem_name in file_size getsize; do
    if ! rg -q "name: \"$filesystem_name\", receiver: \"global\".*argument_types: \"Path\".*return_type: \"usize\".*effects: \"File.Read\".*errors: \"FileIoError\".*opcode: \"FileSize\"" "$registry_file"; then
        printf 'builtin registry audit: file-size row is incomplete: %s\n' "$filesystem_name" >&2
        exit 1
    fi
done
for filesystem_name in file_mtime getmtime; do
    if ! rg -q "name: \"$filesystem_name\", receiver: \"global\".*argument_types: \"Path\".*return_type: \"i64\".*effects: \"File.Read\".*errors: \"FileIoError\".*opcode: \"FileMTime\"" "$registry_file"; then
        printf 'builtin registry audit: modification-time row is incomplete: %s\n' "$filesystem_name" >&2
        exit 1
    fi
done
for filesystem_name in file_atime getatime; do
    if ! rg -q "name: \"$filesystem_name\", receiver: \"global\".*argument_types: \"Path\".*return_type: \"i64\".*effects: \"File.Read\".*errors: \"FileIoError\".*opcode: \"FileATime\"" "$registry_file"; then
        printf 'builtin registry audit: access-time row is incomplete: %s\n' "$filesystem_name" >&2
        exit 1
    fi
done
for filesystem_name in file_ctime getctime; do
    if ! rg -q "name: \"$filesystem_name\", receiver: \"global\".*argument_types: \"Path\".*return_type: \"i64\".*effects: \"File.Read\".*errors: \"FileIoError\".*opcode: \"FileCTime\"" "$registry_file"; then
        printf 'builtin registry audit: change-time row is incomplete: %s\n' "$filesystem_name" >&2
        exit 1
    fi
done
if ! rg -q 'name: "file_mode", receiver: "global".*argument_types: "Path".*return_type: "u64".*effects: "File.Read".*errors: "FileIoError".*opcode: "FileMode"' "$registry_file"; then
    printf 'builtin registry audit: file-mode row is incomplete\n' >&2
    exit 1
fi
if ! rg -q 'name: "touch", receiver: "global".*argument_types: "Path".*return_type: "bool".*effects: "File.Write".*errors: "FileIoError".*opcode: "TouchPath"' "$registry_file"; then
    printf 'builtin registry audit: touch row is incomplete\n' >&2
    exit 1
fi
if ! rg -q 'touch_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path" and registry_spec\.opcode == "TouchPath"' "$lowerer_file" || \
   ! rg -q 'chmod_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path,u64" and registry_spec\.opcode == "ChmodPath"' "$lowerer_file" || \
   ! rg -q 'symlink_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path,Path" and registry_spec\.opcode == "SymlinkPath"' "$lowerer_file" || \
   ! rg -q 'remove_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'move_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'touch_spec\.opcode != "TouchPath"' "$lowerer_file" || \
   ! rg -q 'chmod_spec\.opcode != "ChmodPath"' "$lowerer_file" || \
   ! rg -q 'symlink_spec\.opcode != "SymlinkPath"' "$lowerer_file" || \
   ! rg -q 'remove_spec\.opcode != "RemovePath"' "$lowerer_file" || \
   ! rg -q 'move_spec\.opcode != "MovePath"' "$lowerer_file"; then
    printf 'builtin registry audit: exact filesystem mutation lowerers do not consume registry result/opcode metadata\n' >&2
    exit 1
fi
if ! rg -q 'name: "chmod", receiver: "global".*argument_types: "Path,u64".*return_type: "bool".*effects: "File.Write".*errors: "FileIoError".*opcode: "ChmodPath"' "$registry_file" || ! rg -q 'spec\.argument_types == "Path,u64"' "$receiver_semantic_file" || ! rg -q 'expected == "u64"' "$receiver_semantic_file"; then
    printf 'builtin registry audit: chmod mixed Path/u64 row is not fully consumed\n' >&2
    exit 1
fi
if ! rg -q 'file_size_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path" and registry_spec\.opcode == "FileSize"' "$lowerer_file" || \
   ! rg -q 'file_mode_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path" and registry_spec\.opcode == "FileMode"' "$lowerer_file" || \
   ! rg -q 'file_time_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path" and \(registry_spec\.opcode == "FileMTime" or registry_spec\.opcode == "FileATime" or registry_spec\.opcode == "FileCTime"\)' "$lowerer_file" || \
   ! rg -q 'readlink_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path" and registry_spec\.opcode == "ReadLink"' "$lowerer_file" || \
   ! rg -q 'file_size_spec\.opcode != "FileSize"' "$lowerer_file" || \
   ! rg -q 'file_mode_spec\.opcode != "FileMode"' "$lowerer_file" || \
   ! rg -q 'file_time_spec\.opcode == "FileMTime"' "$lowerer_file" || \
   ! rg -q 'readlink_spec\.opcode != "ReadLink"' "$lowerer_file"; then
    printf 'builtin registry audit: filesystem metadata lowerers do not consume registry result/opcode metadata\n' >&2
    exit 1
fi
for filesystem_name in readlink read_link; do
    if ! rg -q "name: \"$filesystem_name\", receiver: \"global\".*argument_types: \"Path\".*return_type: \"Path\".*effects: \"File.Read\".*errors: \"FileIoError\".*opcode: \"ReadLink\"" "$registry_file"; then
        printf 'builtin registry audit: readlink row is incomplete: %s\n' "$filesystem_name" >&2
        exit 1
    fi
done
for filesystem_name in symlink create_symlink; do
    if ! rg -q "name: \"$filesystem_name\", receiver: \"global\".*argument_types: \"Path,Path\".*return_type: \"bool\".*effects: \"File.Write\".*errors: \"FileIoError\".*opcode: \"SymlinkPath\"" "$registry_file"; then
        printf 'builtin registry audit: symlink-creation row is incomplete: %s\n' "$filesystem_name" >&2
        exit 1
    fi
done
for filesystem_name in remove_path rm remove unlink; do
    if ! rg -q "name: \"$filesystem_name\", receiver: \"global\".*argument_types: \"Path\".*return_type: \"bool\".*effects: \"File.Write\".*errors: \"FileIoError\".*opcode: \"RemovePath\"" "$registry_file"; then
        printf 'builtin registry audit: path-removal row is incomplete: %s\n' "$filesystem_name" >&2
        exit 1
    fi
done
for filesystem_name in move_path mv rename; do
    if ! rg -q "name: \"$filesystem_name\", receiver: \"global\".*argument_types: \"Path,Path\".*return_type: \"bool\".*effects: \"File.Write\".*errors: \"FileIoError\".*opcode: \"MovePath\"" "$registry_file"; then
        printf 'builtin registry audit: path-move row is incomplete: %s\n' "$filesystem_name" >&2
        exit 1
    fi
done
if ! rg -q 'name: "write_text", receiver: "global".*argument_types: "Path,text".*return_type: "usize".*effects: "File.Write".*errors: "FileIoError".*opcode: "WriteText"' "$registry_file" || ! rg -q 'name: "append_text", receiver: "global".*argument_types: "Path,text".*return_type: "usize".*effects: "File.Write".*errors: "FileIoError".*opcode: "AppendText"' "$registry_file"; then
    printf 'builtin registry audit: text writer rows are incomplete\n' >&2
    exit 1
fi
for filesystem_name in write_lines append_lines; do
    opcode="WriteText"
    [[ "$filesystem_name" == "append_lines" ]] && opcode="AppendText"
    if ! rg -q "name: \"$filesystem_name\", receiver: \"global\".*argument_types: \"Path,darray\[text\]\".*return_type: \"usize\".*effects: \"File.Write\".*errors: \"FileIoError\".*opcode: \"$opcode\"" "$registry_file"; then
        printf 'builtin registry audit: line writer row is incomplete: %s\n' "$filesystem_name" >&2
        exit 1
    fi
done
for filesystem_name in write_bytes write_binary append_bytes append_binary; do
    opcode="WriteBytes"
    [[ "$filesystem_name" == "append_bytes" || "$filesystem_name" == "append_binary" ]] && opcode="AppendBytes"
    if ! rg -q "name: \"$filesystem_name\", receiver: \"global\".*argument_types: \"Path,darray\[u8\]\".*return_type: \"usize\".*effects: \"File.Write\".*errors: \"FileIoError\".*opcode: \"$opcode\"" "$registry_file"; then
        printf 'builtin registry audit: byte writer row is incomplete: %s\n' "$filesystem_name" >&2
        exit 1
    fi
done
if ! rg -q 'name: "read_text", receiver: "global".*argument_types: "Path".*return_type: "sview".*effects: "File.Read".*errors: "FileIoError".*opcode: "ReadText"' "$registry_file" || ! rg -q 'name: "cat", receiver: "global".*argument_types: "Path".*return_type: "sview".*effects: "File.Read".*errors: "FileIoError".*opcode: "ReadText"' "$registry_file"; then
    printf 'builtin registry audit: text reader rows are incomplete\n' >&2
    exit 1
fi
if ! rg -q 'name: "read_lines", receiver: "global".*argument_types: "Path".*return_type: "darray\[text\]".*effects: "File.Read".*errors: "FileIoError".*opcode: "ReadText"' "$registry_file"; then
    printf 'builtin registry audit: line reader row is incomplete\n' >&2
    exit 1
fi
for filesystem_name in read_bytes read_binary; do
    if ! rg -q "name: \"$filesystem_name\", receiver: \"global\".*argument_types: \"Path\".*return_type: \"darray\[u8\]\".*effects: \"File.Read\".*errors: \"FileIoError\".*opcode: \"ReadBytes\"" "$registry_file"; then
        printf 'builtin registry audit: byte reader row is incomplete: %s\n' "$filesystem_name" >&2
        exit 1
    fi
done
for lowerer_spec in read_lines_spec read_text_spec read_bytes_spec write_lines_spec append_lines_spec write_text_spec write_bytes_spec append_text_spec append_bytes_spec; do
    if ! rg -q "${lowerer_spec}: EsBuiltin::BuiltinSpec = registry_spec" "$lowerer_file"; then
        printf 'builtin registry audit: file I/O lowerer does not consume registry metadata: %s\n' "$lowerer_spec" >&2
        exit 1
    fi
done
if ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path" and registry_spec\.return_type == "darray\[text\]" and registry_spec\.opcode == "ReadText"' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path" and registry_spec\.return_type == "sview" and registry_spec\.opcode == "ReadText"' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path" and registry_spec\.return_type == "darray\[u8\]" and registry_spec\.opcode == "ReadBytes"' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path,darray\[text\]" and registry_spec\.opcode == "WriteText"' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path,darray\[text\]" and registry_spec\.opcode == "AppendText"' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path,text" and registry_spec\.opcode == "WriteText"' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path,darray\[u8\]" and registry_spec\.opcode == "WriteBytes"' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path,text" and registry_spec\.opcode == "AppendText"' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path,darray\[u8\]" and registry_spec\.opcode == "AppendBytes"' "$lowerer_file"; then
    printf 'builtin registry audit: file I/O lowerers do not consume registry receiver/argument/result metadata\n' >&2
    exit 1
fi
if ! rg -q 'read_lines_spec\.opcode == "ReadText"' "$lowerer_file" || \
   ! rg -q 'read_text_spec\.opcode == "ReadText"' "$lowerer_file" || \
   ! rg -q 'read_bytes_spec\.opcode == "ReadBytes"' "$lowerer_file" || \
   ! rg -q 'write_lines_spec\.opcode == "WriteText"' "$lowerer_file" || \
   ! rg -q 'append_lines_spec\.opcode == "AppendText"' "$lowerer_file" || \
   ! rg -q 'write_text_spec\.opcode == "WriteText"' "$lowerer_file" || \
   ! rg -q 'write_bytes_spec\.opcode == "WriteBytes"' "$lowerer_file" || \
   ! rg -q 'append_text_spec\.opcode == "AppendText"' "$lowerer_file" || \
   ! rg -q 'append_bytes_spec\.opcode == "AppendBytes"' "$lowerer_file"; then
    printf 'builtin registry audit: file I/O lowerer does not consume registry opcode metadata\n' >&2
    exit 1
fi
for filesystem_name in current_directory pwd getcwd; do
    if ! rg -q "name: \"$filesystem_name\", receiver: \"global\".*arity_min: 0.*arity_max: 0.*argument_types: \"\".*return_type: \"Path\".*effects: \"Directory.Read\".*errors: \"DirectoryError\".*opcode: \"CurrentDirectory\"" "$registry_file"; then
        printf 'builtin registry audit: working-directory row is incomplete: %s\n' "$filesystem_name" >&2
        exit 1
    fi
done
for filesystem_name in list_directory listdir; do
    if ! rg -q "name: \"$filesystem_name\", receiver: \"global\".*argument_types: \"Path\".*return_type: \"darray\[text\]\".*effects: \"Directory.Read\".*errors: \"DirectoryError\".*opcode: \"ListDirectory\"" "$registry_file"; then
        printf 'builtin registry audit: directory-list row is incomplete: %s\n' "$filesystem_name" >&2
        exit 1
    fi
done
if ! rg -q 'name: "expand_glob", receiver: "global".*argument_types: "Glob".*return_type: "darray\[text\]".*effects: "Directory.Read".*errors: "DirectoryError".*opcode: "ExpandGlob"' "$registry_file" || ! rg -q 'expected == "Glob"' "$receiver_semantic_file"; then
    printf 'builtin registry audit: glob-expansion row is incomplete\n' >&2
    exit 1
fi
for filesystem_name in create_directory mkdir; do
    if ! rg -q "name: \"$filesystem_name\", receiver: \"global\".*argument_types: \"Path\".*return_type: \"bool\".*effects: \"Directory.Write\".*errors: \"DirectoryError\".*opcode: \"CreateDirectory\"" "$registry_file"; then
        printf 'builtin registry audit: directory-create row is incomplete: %s\n' "$filesystem_name" >&2
        exit 1
    fi
done
for filesystem_name in create_directories makedirs mkdir_p; do
    if ! rg -q "name: \"$filesystem_name\", receiver: \"global\".*argument_types: \"Path\".*return_type: \"bool\".*effects: \"Directory.Write\".*errors: \"DirectoryError\".*opcode: \"CreateDirectories\"" "$registry_file"; then
        printf 'builtin registry audit: recursive-directory-create row is incomplete: %s\n' "$filesystem_name" >&2
        exit 1
    fi
done
for filesystem_name in remove_directory rmdir; do
    if ! rg -q "name: \"$filesystem_name\", receiver: \"global\".*argument_types: \"Path\".*return_type: \"bool\".*effects: \"Directory.Write\".*errors: \"DirectoryError\".*opcode: \"RemoveDirectory\"" "$registry_file"; then
        printf 'builtin registry audit: directory-remove row is incomplete: %s\n' "$filesystem_name" >&2
        exit 1
    fi
done
for filesystem_name in change_directory cd chdir; do
    if ! rg -q "name: \"$filesystem_name\", receiver: \"global\".*argument_types: \"Path\".*return_type: \"bool\".*effects: \"Directory.Write\".*errors: \"DirectoryError\".*opcode: \"ChangeDirectory\"" "$registry_file"; then
        printf 'builtin registry audit: working-directory mutation row is incomplete: %s\n' "$filesystem_name" >&2
        exit 1
    fi
done
if ! rg -q 'directory_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'directory_list_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'directory_predicate_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'glob_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "" and registry_spec\.opcode == "CurrentDirectory"' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path" and registry_spec\.opcode == "ListDirectory"' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path" and registry_spec\.opcode == "IsDirectory"' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Glob" and registry_spec\.opcode == "ExpandGlob"' "$lowerer_file" || \
   ! rg -q 'directory_spec\.opcode != "CurrentDirectory"' "$lowerer_file" || \
   ! rg -q 'directory_list_spec\.opcode != "ListDirectory"' "$lowerer_file" || \
   ! rg -q 'directory_predicate_spec\.opcode != "IsDirectory"' "$lowerer_file" || \
   ! rg -q 'glob_spec\.opcode != "ExpandGlob"' "$lowerer_file"; then
    printf 'builtin registry audit: directory-read lowerers do not consume registry shape/result/opcode metadata\n' >&2
    exit 1
fi
if ! rg -q 'directory_mutation_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'directory_builtin: bool = registry_spec\.known and registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path"' "$lowerer_file" || \
   ! rg -q 'directory_mutation_spec\.argument_types == "Path"' "$lowerer_file" || \
   ! rg -q 'directory_mutation_spec\.opcode == "CreateDirectory"' "$lowerer_file" || \
   ! rg -q 'directory_mutation_spec\.opcode == "RemoveDirectory"' "$lowerer_file"; then
    printf 'builtin registry audit: directory-mutation lowerers do not consume registry argument/opcode metadata\n' >&2
    exit 1
fi
if ! rg -q 'name: "get_environment", receiver: "global".*arity_min: 1.*arity_max: 1.*argument_types: "text".*return_type: "sview".*effects: "Environment.Read".*errors: "EnvironmentError".*opcode: "GetEnvironment"' "$registry_file"; then
    printf 'builtin registry audit: canonical environment-read row is incomplete\n' >&2
    exit 1
fi
if ! rg -q 'name: "getenv", receiver: "global".*arity_min: 1.*arity_max: 2.*argument_types: "text,text".*return_type: "sview".*effects: "Environment.Read".*errors: "EnvironmentError".*opcode: "GetEnvironment"' "$registry_file" || ! rg -q 'name: "get_environment_or", receiver: "global".*arity_min: 2.*arity_max: 2.*argument_types: "text,text".*return_type: "sview".*effects: "Environment.Read".*errors: "EnvironmentError".*opcode: "GetEnvironment"' "$registry_file" || ! rg -q 'name: "getenv_or", receiver: "global".*arity_min: 2.*arity_max: 2.*argument_types: "text,text".*return_type: "sview".*effects: "Environment.Read".*errors: "EnvironmentError".*opcode: "GetEnvironment"' "$registry_file"; then
    printf 'builtin registry audit: environment-read alias rows are incomplete\n' >&2
    exit 1
fi
for environment_name in set_environment setenv; do
    if ! rg -q "name: \"$environment_name\", receiver: \"global\".*arity_min: 2.*arity_max: 2.*argument_types: \"text,text\".*return_type: \"bool\".*effects: \"Environment.Write\".*errors: \"EnvironmentError\".*opcode: \"SetEnvironment\"" "$registry_file"; then
        printf 'builtin registry audit: environment-write row is incomplete: %s\n' "$environment_name" >&2
        exit 1
    fi
done
for environment_name in unset_environment unsetenv; do
    if ! rg -q "name: \"$environment_name\", receiver: \"global\".*arity_min: 1.*arity_max: 1.*argument_types: \"text\".*return_type: \"bool\".*effects: \"Environment.Write\".*errors: \"EnvironmentError\".*opcode: \"UnsetEnvironment\"" "$registry_file"; then
        printf 'builtin registry audit: environment-remove row is incomplete: %s\n' "$environment_name" >&2
        exit 1
    fi
done
if ! rg -q 'environment_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'registry_spec\.opcode == "GetEnvironment"' "$lowerer_file" || \
   ! rg -q 'lower_environment_or\(arguments, argument_names, environment_spec' "$lowerer_file" || \
   ! rg -q 'lower_environment_read\(arguments\[0\], environment_spec' "$lowerer_file" || \
   ! rg -q 'environment_spec\.opcode == "SetEnvironment"' "$lowerer_file" || \
   ! rg -q 'expected_count: usize = environment_spec\.arity_min\.usize\(\)' "$lowerer_file"; then
    printf 'builtin registry audit: environment lowerers do not consume registry shape/result/opcode metadata\n' >&2
    exit 1
fi
if ! rg -q 'name: "executable", receiver: "global".*argument_types: "sview".*return_type: "Executable".*effects: "".*errors: "ProcessError".*opcode: "MakeExecutable"' "$registry_file"; then
    printf 'builtin registry audit: executable process-constructor row is incomplete\n' >&2
    exit 1
fi
if ! rg -q 'name: "run_process", receiver: "global".*arity_min: 2, arity_max: 3, argument_types: "Executable,darray\[text\],i64".*return_type: "i64".*effects: "Process.Run".*errors: "ProcessError".*opcode: "RunProcess"' "$registry_file"; then
    printf 'builtin registry audit: process-run row is incomplete\n' >&2
    exit 1
fi
for process_name in capture_process_stdout capture_process_stderr; do
    opcode="CaptureProcessStdout"
    [[ "$process_name" == "capture_process_stderr" ]] && opcode="CaptureProcessStderr"
    if ! rg -q "name: \"$process_name\", receiver: \"global\".*arity_min: 2, arity_max: 3, argument_types: \"Executable,darray\\[text\\],i64\".*return_type: \"sview\".*effects: \"Process.Run\".*errors: \"ProcessError\".*opcode: \"$opcode\"" "$registry_file"; then
        printf 'builtin registry audit: process stream-capture row is incomplete: %s\n' "$process_name" >&2
        exit 1
    fi
done
for process_name in capture_process_stdout_with_stdin capture_process_stderr_with_stdin; do
    opcode="CaptureProcessStdoutWithStdin"
    [[ "$process_name" == "capture_process_stderr_with_stdin" ]] && opcode="CaptureProcessStderrWithStdin"
    if ! rg -q "name: \"$process_name\", receiver: \"global\".*argument_types: \"Executable,darray\\[text\\],sview\".*return_type: \"sview\".*effects: \"Process.Run\".*errors: \"ProcessError\".*opcode: \"$opcode\"" "$registry_file"; then
        printf 'builtin registry audit: process stdin-capture row is incomplete: %s\n' "$process_name" >&2
        exit 1
    fi
done
if ! rg -q 'executable_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'registry_spec\.opcode == "MakeExecutable"' "$lowerer_file" || \
   ! rg -q 'executable_spec\.opcode == "MakeExecutable"' "$lowerer_file" || \
   ! rg -q 'run_process_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'registry_spec\.opcode == "RunProcess"' "$lowerer_file" || \
   ! rg -q 'run_process_spec\.opcode == "RunProcess"' "$lowerer_file" || \
   ! rg -q 'process_stream_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'process_stream_spec\.opcode == "CaptureProcessStdout"' "$lowerer_file" || \
   ! rg -q 'process_stream_stdin_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'process_stream_stdin_spec\.opcode == "CaptureProcessStdoutWithStdin"' "$lowerer_file" || \
   ! rg -q 'capture_result_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'capture_result_spec\.opcode == "CaptureProcessResult"' "$lowerer_file" || \
   ! rg -q 'capture_result_directory_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'capture_result_directory_spec\.opcode == "CaptureProcessResultInDirectory"' "$lowerer_file" || \
   ! rg -q 'capture_result_environment_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'capture_result_environment_spec\.opcode == "CaptureProcessResultWithEnvironment"' "$lowerer_file" || \
   ! rg -q 'capture_result_directory_environment_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'capture_result_directory_environment_spec\.opcode == "CaptureProcessResultInDirectoryWithEnvironment"' "$lowerer_file"; then
    printf 'builtin registry audit: simple process lowerers do not consume registry shape/result/opcode metadata\n' >&2
    exit 1
fi
if ! rg -q 'spec\.argument_types == "Executable,darray\[text\],i64"' "$lowerer_file" || \
   ! rg -q 'has_timeout: bool = not has_stdin and arguments\.count == 3' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Executable,darray\[text\],sview" and \(registry_spec\.opcode == "CaptureProcessStdoutWithStdin" or registry_spec\.opcode == "CaptureProcessStderrWithStdin"\)' "$lowerer_file" || \
   ! rg -q 'has_timeout: bool = spec\.opcode == "CaptureProcessResult" and arguments\.count == 4' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Executable,darray\[text\],sview,Path" and registry_spec\.opcode == "CaptureProcessResultInDirectory"' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Executable,darray\[text\],sview,dict\[sview,sview\]" and registry_spec\.opcode == "CaptureProcessResultWithEnvironment"' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Executable,darray\[text\],sview,Path,dict\[sview,sview\]" and registry_spec\.opcode == "CaptureProcessResultInDirectoryWithEnvironment"' "$lowerer_file"; then
    printf 'builtin registry audit: process capture lowerers do not consume registry receiver/argument metadata\n' >&2
    exit 1
fi
if ! rg -q 'name: "capture_process_result", receiver: "global".*arity_min: 3, arity_max: 4, argument_types: "Executable,darray\[text\],sview,i64".*return_type: "ProcessCapture".*effects: "Process.Run".*errors: "ProcessError".*opcode: "CaptureProcessResult"' "$registry_file"; then
    printf 'builtin registry audit: process-result capture row is incomplete\n' >&2
    exit 1
fi
if ! rg -q 'name: "capture_process_result_in_directory", receiver: "global".*argument_types: "Executable,darray\[text\],sview,Path".*return_type: "ProcessCapture".*effects: "Process.Run".*errors: "ProcessError".*opcode: "CaptureProcessResultInDirectory"' "$registry_file"; then
    printf 'builtin registry audit: process directory-result capture row is incomplete\n' >&2
    exit 1
fi
if ! rg -q 'name: "capture_process_result_with_environment", receiver: "global".*argument_types: "Executable,darray\[text\],sview,dict\[sview,sview\]".*return_type: "ProcessCapture".*effects: "Process.Run".*errors: "ProcessError".*opcode: "CaptureProcessResultWithEnvironment"' "$registry_file" || ! rg -q 'name: "capture_process_result_in_directory_with_environment", receiver: "global".*argument_types: "Executable,darray\[text\],sview,Path,dict\[sview,sview\]".*return_type: "ProcessCapture".*effects: "Process.Run".*errors: "ProcessError".*opcode: "CaptureProcessResultInDirectoryWithEnvironment"' "$registry_file"; then
    printf 'builtin registry audit: process environment-result capture rows are incomplete\n' >&2
    exit 1
fi
if ! rg -q 'name: "capture_process_pipeline", receiver: "global".*argument_types: "darray\[Executable\],darray\[darray\[text\]\],sview.*return_type: "ProcessCapture".*effects: "Process.Run".*errors: "ProcessError".*opcode: "CaptureProcessPipeline"' "$registry_file" || \
   ! rg -q 'name: "capture_process_pipeline_pipefail", receiver: "global".*argument_types: "darray\[Executable\],darray\[darray\[text\]\],sview.*return_type: "ProcessCapture".*effects: "Process.Run".*errors: "ProcessError".*opcode: "CaptureProcessPipelinePipefail"' "$registry_file"; then
    printf 'builtin registry audit: process-pipeline status-policy rows are incomplete\n' >&2
    exit 1
fi
if ! rg -q 'def lower_capture_process_pipeline\(arguments: darray\[Ast::Expr\].*spec: EsBuiltin::BuiltinSpec' "$lowerer_file" || \
   ! rg -q 'spec\.opcode == "CaptureProcessPipeline"' "$lowerer_file" || \
   ! rg -q 'spec\.opcode == "CaptureProcessPipelinePipefail"' "$lowerer_file" || \
   ! rg -q 'lower_capture_process_pipeline\(arguments, argument_names, registry_spec' "$lowerer_file"; then
    printf 'builtin registry audit: process-pipeline lowerer does not consume both registry status policies\n' >&2
    exit 1
fi
for stream_name in read_stdin read_stdin_line; do
    opcode="ReadStdin"
    [[ "$stream_name" == "read_stdin_line" ]] && opcode="ReadStdinLine"
    if ! rg -q "name: \"$stream_name\", receiver: \"global\".*arity_min: 0.*arity_max: 0.*argument_types: \"\".*return_type: \"sview\".*effects: \"Console.Read\".*errors: \"ConsoleError\".*opcode: \"$opcode\"" "$registry_file"; then
        printf 'builtin registry audit: stdin-read row is incomplete: %s\n' "$stream_name" >&2
        exit 1
    fi
done
if ! rg -q 'name: "input", receiver: "global".*arity_min: 0.*arity_max: 1.*argument_types: "text".*return_type: "sview".*effects: "Console.Read".*errors: "ConsoleError".*opcode: "ReadStdinLine"' "$registry_file" || \
   ! rg -q 'input_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "text" and registry_spec\.opcode == "ReadStdinLine"' "$lowerer_file" || \
   ! rg -q 'input_spec\.opcode == "ReadStdinLine"' "$lowerer_file" || \
   ! rg -q 'def registry_input_optional_prompt_requires_text\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa"; then
    printf 'builtin registry audit: input row/lowerer does not consume registry shape/result/opcode metadata\n' >&2
    exit 1
fi
if ! rg -q 'name: "write_stdout", receiver: "global".*argument_types: "text".*return_type: "usize".*effects: "Console.Write".*errors: "ConsoleError".*opcode: "WriteStdout"' "$registry_file" || ! rg -q 'name: "write_stderr", receiver: "global".*argument_types: "text".*return_type: "usize".*effects: "Console.Write".*errors: "ConsoleError".*opcode: "WriteStderr"' "$registry_file" || ! rg -q 'name: "printf", receiver: "global".*argument_types: "text".*return_type: "usize".*effects: "Console.Write".*errors: "ConsoleError".*opcode: "WriteStdout"' "$registry_file"; then
    printf 'builtin registry audit: standard-stream write rows are incomplete\n' >&2
    exit 1
fi
if ! rg -q 'stdin_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'stdin_line_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'stream_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'registry_spec\.opcode == "WriteStdout" or registry_spec\.opcode == "WriteStderr"' "$lowerer_file" || \
   ! rg -q 'typed_builtin_call_shape\(callee_name, arguments, argument_names\)' "$lowerer_file" || \
   ! rg -q 'stream_spec\.opcode == "WriteStderr"' "$lowerer_file"; then
    printf 'builtin registry audit: fixed console lowerers do not consume registry shape/result/opcode metadata\n' >&2
    exit 1
fi
if ! rg -q 'name: "process_exit_status", receiver: "global".*argument_types: "ProcessCapture".*return_type: "i64".*effects: "".*errors: "".*opcode: "ProcessResultExitStatus"' "$registry_file" || ! rg -q 'name: "process_stdout", receiver: "global".*argument_types: "ProcessCapture".*return_type: "sview".*effects: "".*errors: "".*opcode: "ProcessResultStdout"' "$registry_file" || ! rg -q 'name: "process_stderr", receiver: "global".*argument_types: "ProcessCapture".*return_type: "sview".*effects: "".*errors: "".*opcode: "ProcessResultStderr"' "$registry_file"; then
    printf 'builtin registry audit: process-result accessor rows are incomplete\n' >&2
    exit 1
fi
if ! rg -q 'process_result_accessor: bool = registry_spec\.known and registry_spec\.receiver == "global" and registry_spec\.argument_types == "ProcessCapture"' "$lowerer_file" || \
   ! rg -q 'accessor_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'accessor_spec\.argument_types == "ProcessCapture"' "$lowerer_file" || \
   ! rg -q 'accessor_spec\.opcode == "ProcessResultExitStatus"' "$lowerer_file"; then
    printf 'builtin registry audit: process-result accessors do not consume registry argument/result/opcode metadata\n' >&2
    exit 1
fi
if ! rg -q 'def is_registry_process_stream_capture_spec\(spec: EsBuiltin::BuiltinSpec\)' "$lowerer_file" || \
   ! rg -q 'def lower_registry_process_stream_capture\(callee_name: sview' "$lowerer_file" || \
   ! rg -q 'is_registry_process_stream_capture_spec\(registry_spec\)' "$lowerer_file"; then
    printf 'builtin registry audit: process stream captures do not consume shared registry dispatch\n' >&2
    exit 1
fi
if ! rg -q 'def is_registry_process_result_capture_spec\(spec: EsBuiltin::BuiltinSpec\)' "$lowerer_file" || \
   ! rg -q 'def lower_registry_process_result_capture\(callee_name: sview' "$lowerer_file" || \
   ! rg -q 'is_registry_process_result_capture_spec\(registry_spec\)' "$lowerer_file"; then
    printf 'builtin registry audit: process result captures do not consume shared registry dispatch\n' >&2
    exit 1
fi
if ! rg -q 'name: "file_nonempty", receiver: "global".*argument_types: "Path".*return_type: "bool".*effects: "File.Read".*errors: "FileIoError".*opcode: "FileSize".*lowering_steps: "FileSize,Greater"' "$registry_file" || \
   ! rg -q 'nonempty_spec\.opcode == "FileSize"' "$lowerer_file" || \
   ! rg -q 'def registry_file_nonempty_requires_a_nominal_path\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa"; then
    printf 'builtin registry audit: file-nonempty alias contract is incomplete\n' >&2
    exit 1
fi
if ! rg -q 'name: "regex_search", receiver: "global".*argument_types: "Regex,text".*return_type: "bool".*opcode: "RegexSearch".*lowering_mode: 0' "$registry_file" || \
   ! rg -q 'name: "regex_match", receiver: "global".*argument_types: "Regex,text".*return_type: "bool".*opcode: "RegexSearch".*lowering_mode: 1' "$registry_file" || \
   ! rg -q 'name: "regex_fullmatch", receiver: "global".*argument_types: "Regex,text".*return_type: "bool".*opcode: "RegexSearch".*lowering_mode: 2' "$registry_file" || \
   ! rg -q 'name: "regex_findall", receiver: "global".*argument_types: "Regex,text".*return_type: "darray\[text\]".*opcode: "RegexFind"' "$registry_file" || \
   ! rg -q 'name: "regex_count", receiver: "global".*argument_types: "Regex,text".*return_type: "usize".*opcode: "RegexFind".*lowering_steps: "RegexFind,Length"' "$registry_file" || \
   ! rg -q 'name: "regex_capture_named", receiver: "global".*argument_types: "Regex,text,text".*return_type: "sview".*opcode: "RegexCaptureNamed"' "$registry_file" || \
   ! rg -q 'name: "regex_split", receiver: "global".*argument_types: "Regex,text".*return_type: "darray\[text\]".*opcode: "RegexSplit"' "$registry_file" || \
   ! rg -q 'name: "regex_sub", receiver: "global".*argument_types: "Regex,text,text".*return_type: "sview".*opcode: "RegexReplace"' "$registry_file"; then
    printf 'builtin registry audit: regex namespace alias rows are incomplete\n' >&2
    exit 1
fi
if ! rg -q 'lowering_mode: i64' "$registry_file" || \
   ! rg -q 'def lower_regex_namespace_search\(arguments: darray\[Ast::Expr\].*spec: EsBuiltin::BuiltinSpec\)' "$lowerer_file" || \
   ! rg -q 'def lower_regex_namespace_find\(arguments: darray\[Ast::Expr\].*spec: EsBuiltin::BuiltinSpec\)' "$lowerer_file" || \
   ! rg -q 'def lower_regex_namespace_count\(arguments: darray\[Ast::Expr\].*spec: EsBuiltin::BuiltinSpec\)' "$lowerer_file" || \
   ! rg -q 'def lower_regex_namespace_capture_named\(arguments: darray\[Ast::Expr\].*spec: EsBuiltin::BuiltinSpec\)' "$lowerer_file" || \
   ! rg -q 'def lower_regex_namespace_split\(arguments: darray\[Ast::Expr\].*spec: EsBuiltin::BuiltinSpec\)' "$lowerer_file" || \
   ! rg -q 'def lower_regex_namespace_sub\(arguments: darray\[Ast::Expr\].*spec: EsBuiltin::BuiltinSpec\)' "$lowerer_file" || \
   ! rg -q 'typed_builtin_result_type\(spec\)' "$lowerer_file" || \
   ! rg -q 'typed_builtin_call_shape\(spec\.name, arguments, argument_names\)' "$lowerer_file" || \
   ! rg -q 'integer: spec\.lowering_mode' "$lowerer_file"; then
    printf 'builtin registry audit: regex namespace aliases do not consume registry result/shape/mode metadata\n' >&2
    exit 1
fi
if ! rg -q 'Regex,text' "$receiver_semantic_file" || ! rg -q 'Regex,text,text' "$receiver_semantic_file" || ! rg -q 'def registry_regex_namespace_aliases_check_pattern_first_shapes\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa" || ! rg -q 'regex_count\(pattern, value\)' "$repo_root/test/semantic/elisascript_semantic_test.elisa" || ! rg -q 'regex_capture_named' "$repo_root/test/semantic/elisascript_semantic_test.elisa"; then
    printf 'builtin registry audit: regex namespace descriptors lack semantic coverage\n' >&2
    exit 1
fi
if ! rg -q 'def lowers_registry_regex_namespace_aliases_with_modes\(' "$repo_root/test/ir/elisascript_lowering_test.elisa" || \
   ! rg -q 'def lowers_regex_named_capture_lookup\(' "$lowering_test_file" || \
   ! rg -q 'def interpreter_counts_global_regex_matches\(' "$interpreter_test_file" || \
   ! rg -q 'def interpreter_named_regex_capture_lookup\(' "$interpreter_test_file" || \
   ! rg -q 'def bytecode_direct_global_regex_count_matches_reference_interpreter\(' "$bytecode_test_file" || \
   ! rg -q 'def bytecode_direct_named_regex_capture_matches_reference_interpreter\(' "$bytecode_test_file" || \
   ! rg -q 'spec\.known and spec\.return_type == "darray\[text\]"' "$inference_file" || \
   ! rg -q 'spec\.known and spec\.return_type == "sview"' "$inference_file"; then
    printf 'builtin registry audit: regex namespace lowering/inference coverage is missing\n' >&2
    exit 1
fi
if ! rg -q 'matches_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "text,Regex" and registry_spec\.opcode == "RegexSearch"' "$lowerer_file" || \
   ! rg -q 'matches_spec\.opcode == "RegexSearch"' "$lowerer_file" || \
   ! rg -q 'replace_regex_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "text,Regex,text" and registry_spec\.opcode == "RegexReplace"' "$lowerer_file" || \
   ! rg -q 'replace_regex_spec\.opcode == "RegexReplace"' "$lowerer_file" || \
   ! rg -q 'split_regex_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "text,Regex" and registry_spec\.opcode == "RegexSplit"' "$lowerer_file" || \
   ! rg -q 'split_regex_spec\.opcode == "RegexSplit"' "$lowerer_file" || \
   ! rg -q 'find_regex_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "text,Regex" and registry_spec\.opcode == "RegexFind"' "$lowerer_file" || \
   ! rg -q 'find_regex_spec\.opcode == "RegexFind"' "$lowerer_file" || \
   ! rg -q 'capture_regex_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "text,Regex" and registry_spec\.opcode == "RegexCapture"' "$lowerer_file" || \
   ! rg -q 'capture_regex_spec\.opcode == "RegexCapture"' "$lowerer_file" || \
   ! rg -q 'integer: capture_regex_spec\.lowering_mode' "$lowerer_file"; then
    printf 'builtin registry audit: pattern-first regex lowerers do not consume registry shape/result/opcode metadata\n' >&2
    exit 1
fi
if ! rg -q 'regex_capture_named_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Regex,text,text" and registry_spec\.opcode == "RegexCaptureNamed"' "$lowerer_file" || \
   ! rg -q 'regex_capture_named_spec\.opcode == "RegexCaptureNamed"' "$lowerer_file" || \
   ! rg -q 'opcode: Opcode\.RegexCaptureNamed' "$lowerer_file"; then
    printf 'builtin registry audit: global named regex capture lowerer does not consume registry metadata\n' >&2
    exit 1
fi
if ! rg -q 'expected == "Executable"' "$receiver_semantic_file" || ! rg -q 'expected == "ProcessCapture"' "$receiver_semantic_file" || ! rg -q 'Executable,darray\[text\]' "$receiver_semantic_file" || ! rg -q 'Executable,darray\[text\],sview' "$receiver_semantic_file"; then
    printf 'builtin registry audit: process nominal argument descriptors are not consumed by semantic checks\n' >&2
    exit 1
fi
if ! rg -q 'Executable,darray\[text\],sview,Path' "$receiver_semantic_file" || ! rg -q 'Executable,darray\[text\],sview,dict\[sview,sview\]' "$receiver_semantic_file" || ! rg -q 'ufm_dictionary_argument_is_text_text' "$receiver_semantic_file"; then
    printf 'builtin registry audit: process directory-result descriptor is not consumed by semantic checks\n' >&2
    exit 1
fi
if ! rg -q 'darray\[Executable\],darray\[darray\[text\]\],sview' "$receiver_semantic_file" || ! rg -q 'ufm_executable_array_argument_is_executable' "$receiver_semantic_file" || ! rg -q 'ufm_nested_text_array_argument_is_text' "$receiver_semantic_file"; then
    printf 'builtin registry audit: process-pipeline nested descriptors are not consumed by semantic checks\n' >&2
    exit 1
fi
if ! rg -q 'spec\.argument_types == "Path,Path"' "$receiver_semantic_file"; then
    printf 'builtin registry audit: mixed Path/Path descriptor is not consumed by semantic checks\n' >&2
    exit 1
fi
for filesystem_name in path_parent dirname; do
    if ! rg -q "name: \"$filesystem_name\", receiver: \"global\".*argument_types: \"Path\".*return_type: \"Path\".*effects: \"\".*errors: \"\".*opcode: \"PathParent\"" "$registry_file"; then
        printf 'builtin registry audit: path-parent row is incomplete: %s\n' "$filesystem_name" >&2
        exit 1
    fi
done
for filesystem_name in path_name basename; do
    if ! rg -q "name: \"$filesystem_name\", receiver: \"global\".*argument_types: \"Path\".*return_type: \"sview\".*effects: \"\".*errors: \"\".*opcode: \"PathName\"" "$registry_file"; then
        printf 'builtin registry audit: path-name row is incomplete: %s\n' "$filesystem_name" >&2
        exit 1
    fi
done
for filesystem_name in path_extension suffix; do
    if ! rg -q "name: \"$filesystem_name\", receiver: \"global\".*argument_types: \"Path\".*return_type: \"sview\".*effects: \"\".*errors: \"\".*opcode: \"PathExtension\"" "$registry_file"; then
        printf 'builtin registry audit: path-extension row is incomplete: %s\n' "$filesystem_name" >&2
        exit 1
    fi
done
for filesystem_name in path_stem stem; do
    if ! rg -q "name: \"$filesystem_name\", receiver: \"global\".*argument_types: \"Path\".*return_type: \"sview\".*effects: \"\".*errors: \"\".*opcode: \"PathStem\"" "$registry_file"; then
        printf 'builtin registry audit: path-stem row is incomplete: %s\n' "$filesystem_name" >&2
        exit 1
    fi
done
for filesystem_name in path_is_absolute is_absolute isabs; do
    if ! rg -q "name: \"$filesystem_name\", receiver: \"global\".*argument_types: \"Path\".*return_type: \"bool\".*effects: \"\".*errors: \"\".*opcode: \"PathIsAbsolute\"" "$registry_file"; then
        printf 'builtin registry audit: absolute-path row is incomplete: %s\n' "$filesystem_name" >&2
        exit 1
    fi
done
if ! rg -q 'name: "path_join", receiver: "global".*argument_types: "Path,text".*return_type: "Path".*effects: "".*errors: "".*opcode: "PathJoin"' "$registry_file" || ! rg -q 'spec\.argument_types == "Path,text"' "$receiver_semantic_file"; then
    printf 'builtin registry audit: path-join mixed descriptor is incomplete\n' >&2
    exit 1
fi
for filesystem_name in path_relative relative_path relpath; do
    if ! rg -q "name: \"$filesystem_name\", receiver: \"global\".*argument_types: \"Path,Path\".*return_type: \"Path\".*effects: \"\".*errors: \"\".*opcode: \"PathRelative\"" "$registry_file"; then
        printf 'builtin registry audit: relative-path row is incomplete: %s\n' "$filesystem_name" >&2
        exit 1
    fi
done
for filesystem_name in path_normalize normalize_path normpath; do
    if ! rg -q "name: \"$filesystem_name\", receiver: \"global\".*argument_types: \"Path\".*return_type: \"Path\".*effects: \"\".*errors: \"\".*opcode: \"PathNormalize\"" "$registry_file"; then
        printf 'builtin registry audit: path-normalize row is incomplete: %s\n' "$filesystem_name" >&2
        exit 1
    fi
done
if ! rg -q 'path_join_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path,text" and registry_spec\.opcode == "PathJoin"' "$lowerer_file" || \
   ! rg -q 'path_join_spec\.opcode == "PathJoin"' "$lowerer_file" || \
   ! rg -q 'path_parent_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path" and registry_spec\.opcode == "PathParent"' "$lowerer_file" || \
   ! rg -q 'path_parent_spec\.opcode == "PathParent"' "$lowerer_file" || \
   ! rg -q 'path_name_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path" and registry_spec\.opcode == "PathName"' "$lowerer_file" || \
   ! rg -q 'path_name_spec\.opcode == "PathName"' "$lowerer_file" || \
   ! rg -q 'path_component_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path" and \(registry_spec\.opcode == "PathExtension" or registry_spec\.opcode == "PathStem"\)' "$lowerer_file" || \
   ! rg -q 'path_component_spec\.opcode == "PathExtension"' "$lowerer_file" || \
   ! rg -q 'path_absolute_predicate_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path" and registry_spec\.opcode == "PathIsAbsolute"' "$lowerer_file" || \
   ! rg -q 'path_absolute_predicate_spec\.opcode == "PathIsAbsolute"' "$lowerer_file" || \
   ! rg -q 'path_normalize_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path" and registry_spec\.opcode == "PathNormalize"' "$lowerer_file" || \
   ! rg -q 'path_normalize_spec\.opcode == "PathNormalize"' "$lowerer_file" || \
   ! rg -q 'path_relative_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path,Path" and registry_spec\.opcode == "PathRelative"' "$lowerer_file" || \
   ! rg -q 'path_relative_spec\.opcode == "PathRelative"' "$lowerer_file"; then
    printf 'builtin registry audit: pure path lowerers do not consume registry result/opcode metadata\n' >&2
    exit 1
fi
for filesystem_name in path_absolute absolute_path abspath; do
    if ! rg -q "name: \"$filesystem_name\", receiver: \"global\".*argument_types: \"Path\".*return_type: \"Path\".*effects: \"Directory.Read\".*errors: \"DirectoryError\".*opcode: \"PathAbsolute\"" "$registry_file"; then
        printf 'builtin registry audit: absolute-path construction row is incomplete: %s\n' "$filesystem_name" >&2
        exit 1
    fi
done
for filesystem_name in path_real realpath resolve_path; do
    if ! rg -q "name: \"$filesystem_name\", receiver: \"global\".*argument_types: \"Path\".*return_type: \"Path\".*effects: \"File.Read\".*errors: \"FileIoError\".*opcode: \"PathReal\"" "$registry_file"; then
        printf 'builtin registry audit: real-path row is incomplete: %s\n' "$filesystem_name" >&2
        exit 1
    fi
done
if ! rg -q 'path_absolute_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path" and registry_spec\.opcode == "PathAbsolute"' "$lowerer_file" || \
   ! rg -q 'path_absolute_spec\.opcode == "PathAbsolute"' "$lowerer_file" || \
   ! rg -q 'path_real_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path" and registry_spec\.opcode == "PathReal"' "$lowerer_file" || \
   ! rg -q 'path_real_spec\.opcode == "PathReal"' "$lowerer_file"; then
    printf 'builtin registry audit: path-resolution lowerers do not consume registry result/opcode metadata\n' >&2
    exit 1
fi
if ! rg -q 'lowers_nominal_path_existence_with_file_effect' "$repo_root/test/ir/elisascript_lowering_test.elisa" || ! rg -q 'any error_name in fn\.errors where error_name == "FileIoError"' "$repo_root/test/ir/elisascript_lowering_test.elisa"; then
    printf 'builtin registry audit: filesystem existence row lacks lowering effect/error fixture\n' >&2
    exit 1
fi
if ! rg -q 'lowers_python_os_path_predicate_aliases_with_existing_typed_opcodes' "$repo_root/test/ir/elisascript_lowering_test.elisa" || ! rg -q 'any effect in lowered\.module\.functions\[1\]\.effects where effect == "File.Read"' "$repo_root/test/ir/elisascript_lowering_test.elisa"; then
    printf 'builtin registry audit: regular-file row lacks lowering effect fixture\n' >&2
    exit 1
fi
if ! rg -q 'any error_name in lowered\.module\.functions\[2\]\.errors where error_name == "DirectoryError"' "$repo_root/test/ir/elisascript_lowering_test.elisa"; then
    printf 'builtin registry audit: directory-predicate row lacks lowering error fixture\n' >&2
    exit 1
fi
if ! rg -q 'lowers_typed_symlink_predicate_with_file_read_effect' "$repo_root/test/ir/elisascript_lowering_test.elisa" || ! rg -q 'opcode_count\(lowered\.module\.functions\[1\]\.instruction_pool, Opcode\.IsSymlink\)' "$repo_root/test/ir/elisascript_lowering_test.elisa"; then
    printf 'builtin registry audit: symlink-predicate row lacks lowering alias fixture\n' >&2
    exit 1
fi
if ! rg -q 'spec\.argument_types == "Path"' "$receiver_semantic_file" || ! rg -q 'argument_type\.name == "Path" if expected == "Path"' "$receiver_semantic_file"; then
    printf 'builtin registry audit: Path argument descriptor is not consumed by semantic global checks\n' >&2
    exit 1
fi
if ! rg -q 'def registry_path_exists_requires_a_nominal_path\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa"; then
    printf 'builtin registry audit: Path registry negative fixture is missing\n' >&2
    exit 1
fi
if ! rg -q 'def registry_is_file_requires_a_nominal_path\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa"; then
    printf 'builtin registry audit: regular-file registry negative fixture is missing\n' >&2
    exit 1
fi
if ! rg -q 'def registry_is_directory_requires_a_nominal_path\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa"; then
    printf 'builtin registry audit: directory-predicate registry negative fixture is missing\n' >&2
    exit 1
fi
if ! rg -q 'def registry_is_symlink_requires_a_nominal_path\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa"; then
    printf 'builtin registry audit: symlink-predicate registry negative fixture is missing\n' >&2
    exit 1
fi
if ! rg -q 'def registry_is_readable_requires_a_nominal_path\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa"; then
    printf 'builtin registry audit: path-access registry negative fixture is missing\n' >&2
    exit 1
fi
if ! rg -q 'lowers_typed_path_access_predicates_with_file_read_effect' "$repo_root/test/ir/elisascript_lowering_test.elisa" || \
   ! rg -q 'methods_source: static u8&' "$repo_root/test/ir/elisascript_lowering_test.elisa"; then
    printf 'builtin registry audit: Path access receiver lowering fixture is missing\n' >&2
    exit 1
fi
if ! rg -q 'def registry_file_size_requires_a_nominal_path\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa"; then
    printf 'builtin registry audit: file-size registry negative fixture is missing\n' >&2
    exit 1
fi
if ! rg -q 'def registry_file_mtime_requires_a_nominal_path\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa"; then
    printf 'builtin registry audit: file-time registry negative fixture is missing\n' >&2
    exit 1
fi
if ! rg -q 'def registry_file_mode_requires_a_nominal_path\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa"; then
    printf 'builtin registry audit: file-mode registry negative fixture is missing\n' >&2
    exit 1
fi
if ! rg -q 'def registry_touch_requires_a_nominal_path\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa"; then
    printf 'builtin registry audit: touch registry negative fixture is missing\n' >&2
    exit 1
fi
if ! rg -q 'def registry_path_touch_named_control_requires_bool\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa" || \
   ! rg -q 'def registry_path_touch_named_control_rejects_unknown_names\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa"; then
    printf 'builtin registry audit: Path.touch named-control semantic fixtures are missing\n' >&2
    exit 1
fi
if ! rg -q 'def registry_chmod_checks_the_unsigned_mode_argument\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa"; then
    printf 'builtin registry audit: chmod mixed-argument fixture is missing\n' >&2
    exit 1
fi
if ! rg -q 'def registry_readlink_requires_a_nominal_path\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa"; then
    printf 'builtin registry audit: readlink registry negative fixture is missing\n' >&2
    exit 1
fi
if ! rg -q 'def registry_symlink_checks_both_nominal_paths\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa"; then
    printf 'builtin registry audit: symlink-creation registry fixture is missing\n' >&2
    exit 1
fi
if ! rg -q 'def registry_path_parent_requires_a_nominal_path\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa"; then
    printf 'builtin registry audit: path-parent registry fixture is missing\n' >&2
    exit 1
fi
if ! rg -q 'def registry_path_join_checks_the_text_leaf\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa"; then
    printf 'builtin registry audit: path-join mixed-argument fixture is missing\n' >&2
    exit 1
fi
if ! rg -q 'def registry_path_absolute_requires_a_nominal_path\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa"; then
    printf 'builtin registry audit: absolute-path semantic fixture is missing\n' >&2
    exit 1
fi
if ! rg -q 'lowers_typed_file_mode_with_file_read_effect_and_error' "$repo_root/test/ir/elisascript_lowering_test.elisa"; then
    printf 'builtin registry audit: file-mode lowering fixture is missing\n' >&2
    exit 1
fi
if ! rg -q 'lowers_typed_chmod_with_file_write_effect_and_error' "$repo_root/test/ir/elisascript_lowering_test.elisa"; then
    printf 'builtin registry audit: chmod lowering fixture is missing\n' >&2
    exit 1
fi
if ! rg -q 'lowers_typed_readlink_with_path_result_and_file_read_effect' "$repo_root/test/ir/elisascript_lowering_test.elisa"; then
    printf 'builtin registry audit: readlink lowering fixture is missing\n' >&2
    exit 1
fi
if ! rg -q 'lowers_typed_symlink_creation_with_file_write_effect_and_error' "$repo_root/test/ir/elisascript_lowering_test.elisa"; then
    printf 'builtin registry audit: symlink-creation lowering fixture is missing\n' >&2
    exit 1
fi
if ! rg -q 'lowers_pure_typed_path_composition_and_decomposition' "$repo_root/test/ir/elisascript_lowering_test.elisa"; then
    printf 'builtin registry audit: path decomposition lowering fixture is missing\n' >&2
    exit 1
fi
if ! rg -q 'lowers_typed_path_normalization_without_filesystem_effects' "$repo_root/test/ir/elisascript_lowering_test.elisa" || ! rg -q 'lowers_typed_relative_paths_without_filesystem_effects' "$repo_root/test/ir/elisascript_lowering_test.elisa"; then
    printf 'builtin registry audit: path normalization/relative lowering fixtures are missing\n' >&2
    exit 1
fi
if ! rg -q 'lowers_typed_absolute_path_construction_with_directory_read' "$repo_root/test/ir/elisascript_lowering_test.elisa" || ! rg -q 'lowers_typed_real_paths_with_file_read_effect_and_error' "$repo_root/test/ir/elisascript_lowering_test.elisa"; then
    printf 'builtin registry audit: absolute/real path lowering fixtures are missing\n' >&2
    exit 1
fi
if ! rg -q 'lowers_typed_touch_with_file_write_effect_and_error' "$repo_root/test/ir/elisascript_lowering_test.elisa"; then
    printf 'builtin registry audit: touch lowering fixture is missing\n' >&2
    exit 1
fi
if ! rg -q 'lowers_typed_file_mtime_with_file_read_effect_and_error' "$repo_root/test/ir/elisascript_lowering_test.elisa" || ! rg -q 'lowers_python_path_access_and_change_time_aliases_to_existing_typed_opcodes' "$repo_root/test/ir/elisascript_lowering_test.elisa"; then
    printf 'builtin registry audit: file-time lowering fixtures are missing\n' >&2
    exit 1
fi
if ! rg -q 'lowers_typed_path_mutation_aliases_with_registry_contracts' "$repo_root/test/ir/elisascript_lowering_test.elisa"; then
    printf 'builtin registry audit: path mutation rows lack lowering alias fixture\n' >&2
    exit 1
fi
if ! rg -q 'lowers_nominal_text_append_with_file_effect_and_error' "$repo_root/test/ir/elisascript_lowering_test.elisa" || ! rg -q 'lowers_line_oriented_file_helpers_to_existing_text_ir' "$repo_root/test/ir/elisascript_lowering_test.elisa" || ! rg -q 'lowers_typed_binary_file_operations_with_exact_u8_arrays' "$repo_root/test/ir/elisascript_lowering_test.elisa"; then
    printf 'builtin registry audit: text/line/byte writer rows lack lowering fixtures\n' >&2
    exit 1
fi
if ! rg -q 'def registry_remove_path_requires_a_nominal_path\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa" || ! rg -q 'def registry_move_path_checks_both_nominal_paths\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa" || ! rg -q 'def registry_copy_path_checks_both_nominal_paths\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa" || ! rg -q 'def registry_copy_tree_checks_both_nominal_paths\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa" || ! rg -q 'def registry_write_text_requires_a_nominal_path\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa" || ! rg -q 'def registry_write_lines_checks_text_array_elements\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa" || ! rg -q 'def registry_write_bytes_checks_unsigned_byte_elements\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa" || ! rg -q 'def registry_read_text_requires_a_nominal_path\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa" || ! rg -q 'def registry_read_bytes_requires_a_nominal_path\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa"; then
    printf 'builtin registry audit: filesystem registry rows lack semantic negative fixtures\n' >&2
    exit 1
fi
if ! rg -q 'def registry_directory_mutation_requires_a_nominal_path\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa" || ! rg -q 'def registry_expand_glob_requires_a_nominal_glob\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa"; then
    printf 'builtin registry audit: directory registry rows lack semantic negative fixtures\n' >&2
    exit 1
fi
if ! rg -q 'def registry_environment_reads_require_text_names\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa" || ! rg -q 'def registry_environment_mutations_require_text_pairs\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa"; then
    printf 'builtin registry audit: environment registry rows lack semantic negative fixtures\n' >&2
    exit 1
fi
if ! rg -q 'def registry_process_construction_requires_text\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa" || ! rg -q 'def registry_process_accessors_require_process_captures\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa"; then
    printf 'builtin registry audit: process registry rows lack semantic negative fixtures\n' >&2
    exit 1
fi
if ! rg -q 'def registry_process_stdin_captures_require_text_input\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa"; then
    printf 'builtin registry audit: process stdin-capture rows lack semantic negative fixtures\n' >&2
    exit 1
fi
if ! rg -q 'def registry_process_result_capture_requires_text_input\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa"; then
    printf 'builtin registry audit: process-result capture semantic coverage is missing\n' >&2
    exit 1
fi
if ! rg -q 'def registry_process_directory_capture_requires_a_path\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa"; then
    printf 'builtin registry audit: process directory-result capture semantic coverage is missing\n' >&2
    exit 1
fi
if ! rg -q 'def registry_process_environment_capture_requires_text_input\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa" || ! rg -q 'def registry_process_directory_environment_capture_requires_a_path\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa"; then
    printf 'builtin registry audit: process environment-result capture semantic coverage is missing\n' >&2
    exit 1
fi
if ! rg -q 'def registry_process_status_facades_check_typed_controls\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa"; then
    printf 'builtin registry audit: process status-facade rows lack semantic negative fixtures\n' >&2
    exit 1
fi
if ! rg -q 'def registry_process_pipeline_checks_nested_argument_shapes\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa"; then
    printf 'builtin registry audit: process-pipeline row lacks semantic negative fixture\n' >&2
    exit 1
fi
if ! rg -q 'def lowers_shell_free_process_pipeline\(' "$repo_root/test/ir/elisascript_lowering_test.elisa"; then
    printf 'builtin registry audit: process-pipeline lowering fixture is missing\n' >&2
    exit 1
fi
if ! rg -q 'def registry_standard_stream_writes_require_text\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa" || ! rg -q 'def registry_standard_stream_reads_are_argument_free\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa"; then
    printf 'builtin registry audit: standard-stream registry rows lack semantic negative fixtures\n' >&2
    exit 1
fi
if ! rg -q 'def registry_temporary_paths_require_text_prefixes\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa"; then
    printf 'builtin registry audit: temporary-path registry rows lack semantic negative fixtures\n' >&2
    exit 1
fi
for temporary_name in temp_file mktemp temp_directory temp_dir mkdtemp; do
    if ! rg -q "name: \"$temporary_name\", receiver: \"global\", arity_min: 0, arity_max: 1, argument_types: \"text\", return_type: \"Path\", effects: \"File.Write\", errors: \"FileIoError\", opcode: \"CreateTemporary\"" "$registry_file"; then
        printf 'builtin registry audit: temporary-path row is incomplete for %s\n' "$temporary_name" >&2
        exit 1
    fi
done
if ! rg -q 'name: "temp_directory".*opcode: "CreateTemporary", lowering_mode: 1' "$registry_file" || \
   ! rg -q 'name: "temp_dir".*opcode: "CreateTemporary", lowering_mode: 1' "$registry_file" || \
   ! rg -q 'name: "mkdtemp".*opcode: "CreateTemporary", lowering_mode: 1' "$registry_file" || \
   ! rg -q 'temporary_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'registry_spec\.opcode == "CreateTemporary"' "$lowerer_file" || \
   ! rg -q 'temporary_spec\.opcode == "CreateTemporary"' "$lowerer_file" || \
   ! rg -q 'temporary_kind: i64 = temporary_spec\.lowering_mode' "$lowerer_file"; then
    printf 'builtin registry audit: temporary-path lowerer does not consume registry kind/opcode metadata\n' >&2
    exit 1
fi
if ! rg -q 'lowers_secure_temporary_file_and_directory_aliases' "$repo_root/test/ir/elisascript_lowering_test.elisa"; then
    printf 'builtin registry audit: temporary-path lowering fixture is missing\n' >&2
    exit 1
fi
if ! rg -q 'def registry_remove_tree_requires_a_nominal_path\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa"; then
    printf 'builtin registry audit: recursive-removal registry rows lack semantic negative fixtures\n' >&2
    exit 1
fi
for recursive_name in remove_tree rmtree; do
    if ! rg -q "name: \"$recursive_name\", receiver: \"global\", arity_min: 1, arity_max: 1, argument_types: \"Path\", return_type: \"bool\", effects: \"File.Write\", errors: \"FileIoError\", opcode: \"RemoveTree\"" "$registry_file"; then
        printf 'builtin registry audit: recursive-removal row is incomplete for %s\n' "$recursive_name" >&2
        exit 1
    fi
done
if ! rg -q 'lowers_typed_directory_lifecycle_and_working_directory_operations' "$repo_root/test/ir/elisascript_lowering_test.elisa"; then
    printf 'builtin registry audit: recursive-removal lowering coverage is missing\n' >&2
    exit 1
fi
if ! rg -q 'def registry_sleep_aliases_require_typed_durations\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa"; then
    printf 'builtin registry audit: sleep registry rows lack semantic negative fixtures\n' >&2
    exit 1
fi
for seconds_name in sleep sleep_seconds; do
    if ! rg -q "name: \"$seconds_name\", receiver: \"global\", arity_min: 1, arity_max: 1, argument_types: \"i64|f64\", return_type: \"void\", effects: \"Time.Sleep\", errors: \"TimeError\", opcode: \"Sleep\"" "$registry_file"; then
        printf 'builtin registry audit: seconds sleep row is incomplete for %s\n' "$seconds_name" >&2
        exit 1
    fi
done
for milliseconds_name in sleep_milliseconds sleep_ms; do
    if ! rg -q "name: \"$milliseconds_name\", receiver: \"global\", arity_min: 1, arity_max: 1, argument_types: \"u64\", return_type: \"void\", effects: \"Time.Sleep\", errors: \"TimeError\", opcode: \"Sleep\"" "$registry_file"; then
        printf 'builtin registry audit: millisecond sleep row is incomplete for %s\n' "$milliseconds_name" >&2
        exit 1
    fi
done
if ! rg -q 'name: "sleep_milliseconds".*opcode: "Sleep", lowering_mode: 1' "$registry_file" || \
   ! rg -q 'name: "sleep_ms".*opcode: "Sleep", lowering_mode: 1' "$registry_file" || \
   ! rg -q 'sleep_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'sleep_spec\.lowering_mode == 1' "$lowerer_file" || \
   ! rg -q 'sleep_spec\.opcode == "Sleep"' "$lowerer_file"; then
    printf 'builtin registry audit: sleep lowerer does not consume unit/opcode metadata\n' >&2
    exit 1
fi
if ! rg -q 'lowers_typed_sleep_units_and_aliases' "$repo_root/test/ir/elisascript_lowering_test.elisa"; then
    printf 'builtin registry audit: sleep lowering fixture is missing\n' >&2
    exit 1
fi
for copy_name in copy_path cp copyfile; do
    if ! rg -q "name: \"$copy_name\", receiver: \"global\", arity_min: 2, arity_max: 2, argument_types: \"Path,Path\", return_type: \"bool\", effects: \"File.Read\", effects_secondary: \"File.Write\", errors: \"FileIoError\", opcode: \"CopyPath\"" "$registry_file"; then
        printf 'builtin registry audit: file-copy row is incomplete for %s\n' "$copy_name" >&2
        exit 1
    fi
done
for remove_name in remove_path rm remove unlink; do
    if ! rg -q "name: \"$remove_name\", receiver: \"global\", arity_min: 1, arity_max: 1, argument_types: \"Path\", return_type: \"bool\", effects: \"File.Write\", errors: \"FileIoError\", opcode: \"RemovePath\"" "$registry_file"; then
        printf 'builtin registry audit: file-removal row is incomplete for %s\n' "$remove_name" >&2
        exit 1
    fi
done
for tree_copy_name in copy_tree copytree; do
    if ! rg -q "name: \"$tree_copy_name\", receiver: \"global\", arity_min: 2, arity_max: 2, argument_types: \"Path,Path\", return_type: \"bool\", effects: \"File.Read\", effects_secondary: \"File.Write\", errors: \"FileIoError\", opcode: \"CopyTree\"" "$registry_file"; then
        printf 'builtin registry audit: tree-copy row is incomplete for %s\n' "$tree_copy_name" >&2
        exit 1
    fi
done
if ! rg -q 'copy_path_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'remove_tree_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'copy_tree_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path,Path" and registry_spec\.opcode == "CopyPath"' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path" and registry_spec\.opcode == "RemoveTree"' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "Path,Path" and registry_spec\.opcode == "CopyTree"' "$lowerer_file" || \
   ! rg -q 'copy_path_spec\.opcode != "CopyPath"' "$lowerer_file" || \
   ! rg -q 'remove_tree_spec\.opcode != "RemoveTree"' "$lowerer_file" || \
   ! rg -q 'copy_tree_spec\.opcode != "CopyTree"' "$lowerer_file"; then
    printf 'builtin registry audit: copy/remove-tree lowerers do not consume registry result/opcode metadata\n' >&2
    exit 1
fi
if ! rg -q 'effects_secondary: sview' "$registry_file" || \
   ! rg -q 'def builtin_effect_at\(spec: BuiltinSpec, index: u32\)' "$registry_file" || \
   ! rg -q 'primary_effect: sview = EsBuiltin::builtin_effect_at\(spec, 0\)' "$lowerer_file" || \
   ! rg -q 'secondary_effect: sview = EsBuiltin::builtin_effect_at\(spec, 1\)' "$lowerer_file" || \
   ! rg -q 'state\.required_effects\.push\(secondary_effect\)' "$lowerer_file"; then
    printf 'builtin registry audit: secondary effect metadata is not propagated by lowering\n' >&2
    exit 1
fi
if ! rg -q 'lowers_typed_path_mutation_aliases_with_registry_contracts' "$repo_root/test/ir/elisascript_lowering_test.elisa" || ! rg -q 'lowers_typed_directory_lifecycle_and_working_directory_operations' "$repo_root/test/ir/elisascript_lowering_test.elisa"; then
    printf 'builtin registry audit: copy lowering coverage is missing\n' >&2
    exit 1
fi
if ! rg -q 'lowers_python_directory_aliases_to_existing_typed_opcodes' "$repo_root/test/ir/elisascript_lowering_test.elisa" || ! rg -q 'lowers_typed_directory_lifecycle_and_working_directory_operations' "$repo_root/test/ir/elisascript_lowering_test.elisa" || ! rg -q 'lowers_deterministic_typed_directory_listing' "$repo_root/test/ir/elisascript_lowering_test.elisa" || ! rg -q 'lowers_native_typed_glob_expansion' "$repo_root/test/ir/elisascript_lowering_test.elisa"; then
    printf 'builtin registry audit: directory registry rows lack lowering fixtures\n' >&2
    exit 1
fi
if ! rg -q 'lowers_typed_environment_operations_and_contracts' "$repo_root/test/ir/elisascript_lowering_test.elisa" || ! rg -q 'lowers_environment_default_through_error_guard' "$repo_root/test/ir/elisascript_lowering_test.elisa" || ! rg -q 'lowers_python_environment_aliases_to_existing_typed_opcodes' "$repo_root/test/ir/elisascript_lowering_test.elisa"; then
    printf 'builtin registry audit: environment registry rows lack lowering fixtures\n' >&2
    exit 1
fi
if ! rg -q 'lowers_dynamic_executable_constructor' "$repo_root/test/ir/elisascript_lowering_test.elisa" || ! rg -q 'lowers_shell_free_process_execution_with_typed_arguments' "$repo_root/test/ir/elisascript_lowering_test.elisa" || ! rg -q 'lowers_shell_free_process_stdout_capture' "$repo_root/test/ir/elisascript_lowering_test.elisa" || ! rg -q 'lowers_typed_process_result_and_accessors' "$repo_root/test/ir/elisascript_lowering_test.elisa"; then
    printf 'builtin registry audit: migrated process rows lack lowering fixtures\n' >&2
    exit 1
fi
if ! rg -q 'lowers_shell_free_process_stdout_capture_with_typed_stdin' "$repo_root/test/ir/elisascript_lowering_test.elisa" || ! rg -q 'lowers_shell_free_process_stderr_capture_with_typed_stdin' "$repo_root/test/ir/elisascript_lowering_test.elisa"; then
    printf 'builtin registry audit: process stdin-capture rows lack lowering fixtures\n' >&2
    exit 1
fi
if ! rg -q 'lowers_typed_process_result_and_accessors' "$repo_root/test/ir/elisascript_lowering_test.elisa"; then
    printf 'builtin registry audit: process-result capture lowering coverage is missing\n' >&2
    exit 1
fi
if ! rg -q 'lowers_typed_process_result_in_directory' "$repo_root/test/ir/elisascript_lowering_test.elisa"; then
    printf 'builtin registry audit: process directory-result capture lowering coverage is missing\n' >&2
    exit 1
fi
if ! rg -q 'lowers_typed_process_result_with_environment' "$repo_root/test/ir/elisascript_lowering_test.elisa" || ! rg -q 'lowers_typed_process_result_in_directory_with_environment' "$repo_root/test/ir/elisascript_lowering_test.elisa"; then
    printf 'builtin registry audit: process environment-result capture lowering coverage is missing\n' >&2
    exit 1
fi
for status_name in run_process_with_stdin run_process_in_directory run_process_with_environment run_process_in_directory_with_environment; do
    if ! rg -q "name: \"$status_name\", receiver: \"global\".*lowering_steps: \".*ProcessResultExitStatus\"" "$registry_file"; then
        printf 'builtin registry audit: composed status-facade row lacks lowering steps for %s\n' "$status_name" >&2
        exit 1
    fi
done
if ! rg -q 'lowering_steps: sview' "$registry_file" || ! rg -q 'Opcode\.ProcessResultExitStatus' "$verifier_file"; then
    printf 'builtin registry audit: composed process lowering metadata is not verifier-covered\n' >&2
    exit 1
fi
if ! rg -q 'registry_spec\.opcode == "ProcessResultExitStatus" and registry_spec\.lowering_steps != ""' "$lowerer_file" || \
   ! rg -q 'registry_spec\.lowering_steps == "CaptureProcessResult,ProcessResultExitStatus"' "$lowerer_file" || \
   ! rg -q 'registry_spec\.lowering_steps == "CaptureProcessResultInDirectory,ProcessResultExitStatus"' "$lowerer_file" || \
   ! rg -q 'registry_spec\.lowering_steps == "CaptureProcessResultWithEnvironment,ProcessResultExitStatus"' "$lowerer_file" || \
   ! rg -q 'registry_spec\.lowering_steps == "CaptureProcessResultInDirectoryWithEnvironment,ProcessResultExitStatus"' "$lowerer_file"; then
    printf 'builtin registry audit: lowerer does not consume composed process lowering metadata\n' >&2
    exit 1
fi
for status_helper in lower_run_process_with_stdin lower_run_process_in_directory lower_run_process_with_environment lower_run_process_in_directory_with_environment; do
    if ! rg -q "def ${status_helper}\\(arguments: darray\\[Ast::Expr\\].*spec: EsBuiltin::BuiltinSpec" "$lowerer_file"; then
        printf 'builtin registry audit: status helper does not accept its registry descriptor: %s\n' "$status_helper" >&2
        exit 1
    fi
done
if ! rg -q 'spec\.opcode == "ProcessResultExitStatus" and spec\.lowering_steps != "" and typed_builtin_call_shape\(spec\.name' "$lowerer_file"; then
    printf 'builtin registry audit: status helpers do not consume registry shape/opcode/sequence metadata\n' >&2
    exit 1
fi
if ! rg -q 'lowers_python_print_to_typed_stdout_state' "$repo_root/test/ir/elisascript_lowering_test.elisa" || ! rg -q 'lowers_console_print_aliases_to_explicit_stream_opcodes' "$repo_root/test/ir/elisascript_lowering_test.elisa"; then
    printf 'builtin registry audit: standard-stream registry rows lack lowering fixtures\n' >&2
    exit 1
fi

for name in $method_names; do
    if ! rg -q "known: true, name: \"$name\", receiver: \"Text\"" "$registry_file"; then
        printf 'builtin registry audit: Text.%s has no receiver-specific registry row\n' "$name" >&2
        exit 1
    fi
    if ! rg -q "method_name == \"$name\"" "$lowerer_file"; then
        printf 'builtin registry audit: lowerer has no Text method branch for %s\n' "$name" >&2
        exit 1
    fi
    if ! rg -q "name: \"$name\", receiver: \"Text\".*argument_types:" "$registry_file"; then
        printf 'builtin registry audit: Text.%s has no argument-type descriptor\n' "$name" >&2
        exit 1
    fi
    opcode="$(sed -n "s/.*name: \"$name\".*receiver: \"Text\".*opcode: \"\([A-Za-z0-9_]*\)\".*/\1/p" "$registry_file" | head -1)"
    if [[ -z "$opcode" ]] || ! rg -q "Opcode\\.$opcode" "$verifier_file"; then
        printf 'builtin registry audit: Text.%s opcode is not verifier-covered (%s)\n' "$name" "${opcode:-missing}" >&2
        exit 1
    fi
done

for name in $regex_method_names; do
    if ! rg -q "known: true, name: \"$name\", receiver: \"Regex\"" "$registry_file"; then
        printf 'builtin registry audit: Regex.%s has no receiver-specific registry row\n' "$name" >&2
        exit 1
    fi
    if ! rg -q "method_name == \"$name\"" "$lowerer_file"; then
        printf 'builtin registry audit: lowerer has no Regex method branch for %s\n' "$name" >&2
        exit 1
    fi
    if ! rg -q "name: \"$name\", receiver: \"Regex\".*argument_types:" "$registry_file"; then
        printf 'builtin registry audit: Regex.%s has no argument-type descriptor\n' "$name" >&2
        exit 1
    fi
    opcode="$(sed -n "s/.*name: \"$name\".*receiver: \"Regex\".*opcode: \"\([A-Za-z0-9_]*\)\".*/\1/p" "$registry_file" | head -1)"
    if [[ -z "$opcode" ]] || ! rg -q "Opcode\\.$opcode" "$verifier_file"; then
        printf 'builtin registry audit: Regex.%s opcode is not verifier-covered (%s)\n' "$name" "${opcode:-missing}" >&2
        exit 1
    fi
done

path_method_names="$(sed -n '/def typed_builtin_path_method_names/,/^        def typed_builtin_map_method_names/p' "$registry_file" | rg -o '"[a-z_][a-z0-9_]*"' | tr -d '"' | sort -u)"
if [[ -z "$path_method_names" ]]; then
    printf 'builtin registry audit: typed_builtin_path_method_names is empty\n' >&2
    exit 1
fi
for name in $path_method_names; do
    if ! rg -q "known: true, name: \"$name\", receiver: \"Path\"" "$registry_file"; then
        printf 'builtin registry audit: Path.%s has no receiver-specific registry row\n' "$name" >&2
        exit 1
    fi
    if ! rg -q "name: \"$name\", receiver: \"Path\".*argument_types:" "$registry_file"; then
        printf 'builtin registry audit: Path.%s has no argument-type descriptor\n' "$name" >&2
        exit 1
    fi
    opcode="$(sed -n "s/.*name: \"$name\".*receiver: \"Path\".*opcode: \"\([A-Za-z0-9_]*\)\".*/\1/p" "$registry_file" | head -1)"
    path_opcode_pattern="path_spec\\.known and path_spec\\.opcode == \"$opcode\""
    if [[ "$opcode" == "PathGlob" || "$opcode" == "PathRGlob" ]]; then
        path_opcode_pattern='path_spec\.known and \(path_spec\.opcode == "PathGlob" or path_spec\.opcode == "PathRGlob"\)'
    elif [[ "$opcode" == "WriteText" || "$opcode" == "AppendText" ]]; then
        path_opcode_pattern='path_spec\.known and \(path_spec\.opcode == "WriteText" or path_spec\.opcode == "AppendText"\)'
    elif [[ "$opcode" == "WriteBytes" || "$opcode" == "AppendBytes" ]]; then
        path_opcode_pattern='path_spec\.known and \(path_spec\.opcode == "WriteBytes" or path_spec\.opcode == "AppendBytes"\)'
    fi
    if [[ -z "$opcode" ]] || ! rg -q "$path_opcode_pattern" "$lowerer_file"; then
        printf 'builtin registry audit: lowerer has no Path metadata branch for %s (%s)\n' "$name" "${opcode:-missing}" >&2
        exit 1
    fi
    if [[ -z "$opcode" ]] || ! rg -q "Opcode\\.$opcode" "$verifier_file"; then
        printf 'builtin registry audit: Path.%s opcode is not verifier-covered (%s)\n' "$name" "${opcode:-missing}" >&2
        exit 1
    fi
done

map_method_names="$(sed -n '/def typed_builtin_map_method_names/,/^        def typed_builtin_set_method_names/p' "$registry_file" | rg -o '"[a-z_][a-z0-9_]*"' | tr -d '"' | sort -u)"
if [[ -z "$map_method_names" ]]; then
    printf 'builtin registry audit: typed_builtin_map_method_names is empty\n' >&2
    exit 1
fi
for name in $map_method_names; do
    if ! rg -q "known: true, name: \"$name\", receiver: \"Map\"" "$registry_file"; then
        printf 'builtin registry audit: Map.%s has no receiver-specific registry row\n' "$name" >&2
        exit 1
    fi
    if ! rg -q "name: \"$name\", receiver: \"Map\".*argument_types:" "$registry_file"; then
        printf 'builtin registry audit: Map.%s has no argument-type descriptor\n' "$name" >&2
        exit 1
    fi
    if ! rg -q "scripting_map_builtin_available\(state, method_name\) and method_name == \"$name\"" "$lowerer_file"; then
        printf 'builtin registry audit: lowerer has no Map method branch for %s\n' "$name" >&2
        exit 1
    fi
    if [[ "$name" == "keys" ]] && ! rg -q 'map_keys: darray\[sview\] = mapping\.keys\(\)' "$semantic_test_file"; then
        printf 'builtin registry audit: Map.keys semantic fixture is missing\n' >&2
        exit 1
    fi
    if [[ "$name" == "values" ]] && ! rg -q 'map_values: darray\[i64\] = mapping\.values\(\)' "$semantic_test_file"; then
        printf 'builtin registry audit: Map.values semantic fixture is missing\n' >&2
        exit 1
    fi
    if [[ "$name" == "copy" ]] && ! rg -q 'copied: dict\[sview, i64\] = mapping\.copy\(\)' "$semantic_test_file"; then
        printf 'builtin registry audit: Map.copy semantic fixture is missing\n' >&2
        exit 1
    fi
    if [[ "$name" == "get" ]] && ! rg -Fq 'looked_up: i64 = mapping.get(\"key\", 0)' "$semantic_test_file"; then
        printf 'builtin registry audit: Map.get semantic fixture is missing\n' >&2
        exit 1
    fi
    if [[ "$name" == "pop" ]] && ! rg -Fq 'popped: i64 = mapping.pop(\"key\", 0)' "$semantic_test_file"; then
        printf 'builtin registry audit: Map.pop semantic fixture is missing\n' >&2
        exit 1
    fi
    if [[ "$name" == "setdefault" ]] && ! rg -Fq 'defaulted: i64 = mapping.setdefault(\"key\", 0)' "$semantic_test_file"; then
        printf 'builtin registry audit: Map.setdefault semantic fixture is missing\n' >&2
        exit 1
    fi
    if [[ "$name" == "update" ]] && ! rg -q 'def lowers_python_dictionary_update_as_owned_rebinding\(' "$lowering_test_file"; then
        printf 'builtin registry audit: Map.update lowering fixture is missing\n' >&2
        exit 1
    fi
    if [[ "$name" == "pop" ]] && ! rg -q 'def lowers_python_dictionary_pop_with_optional_default\(' "$lowering_test_file"; then
        printf 'builtin registry audit: Map.pop lowering fixture is missing\n' >&2
        exit 1
    fi
    if [[ "$name" == "setdefault" ]] && ! rg -q 'def lowers_python_dictionary_setdefault_as_typed_value_and_rebinding\(' "$lowering_test_file"; then
        printf 'builtin registry audit: Map.setdefault lowering fixture is missing\n' >&2
        exit 1
    fi
    if [[ "$name" == "remove" || "$name" == "clear" ]] && ! rg -q 'def lowers_mutable_dictionary_remove_and_clear\(' "$lowering_test_file"; then
        printf 'builtin registry audit: Map.%s lowering fixture is missing\n' "$name" >&2
        exit 1
    fi
    if [[ "$name" == "remove" || "$name" == "clear" ]] && ! rg -q 'def map_mutation_receiver_registry_shapes_are_static\(' "$semantic_test_file"; then
        printf 'builtin registry audit: Map.%s semantic fixture is missing\n' "$name" >&2
        exit 1
    fi
    if [[ "$name" == "remove" || "$name" == "clear" ]] && ! rg -q 'def source_collection_mutation_declarations_take_precedence_over_registry_rows\(' "$semantic_test_file"; then
        printf 'builtin registry audit: Map.%s source-shadow semantic fixture is missing\n' "$name" >&2
        exit 1
    fi
    if [[ "$name" == "remove" || "$name" == "clear" ]] && ! rg -q 'def lowers_collection_mutation_source_functions_before_registry_rows\(' "$lowering_test_file"; then
        printf 'builtin registry audit: Map.%s source-shadow lowering fixture is missing\n' "$name" >&2
        exit 1
    fi
    opcode="$(sed -n "s/.*name: \"$name\".*receiver: \"Map\".*opcode: \"\([A-Za-z0-9_]*\)\".*/\1/p" "$registry_file" | head -1)"
    if [[ -z "$opcode" ]] || ! rg -q "Opcode\\.$opcode" "$verifier_file"; then
        printf 'builtin registry audit: Map.%s opcode is not verifier-covered (%s)\n' "$name" "${opcode:-missing}" >&2
        exit 1
    fi
done

set_method_names="$(sed -n '/def typed_builtin_set_method_names/,/^        def typed_builtin_array_method_names/p' "$registry_file" | rg -o '"[a-z_][a-z0-9_]*"' | tr -d '"' | sort -u)"
if [[ -z "$set_method_names" ]]; then
    printf 'builtin registry audit: typed_builtin_set_method_names is empty\n' >&2
    exit 1
fi
for name in $set_method_names; do
    if ! rg -q "known: true, name: \"$name\", receiver: \"Set\"" "$registry_file"; then
        printf 'builtin registry audit: Set.%s has no receiver-specific registry row\n' "$name" >&2
        exit 1
    fi
    if ! rg -q "name: \"$name\", receiver: \"Set\".*argument_types:" "$registry_file"; then
        printf 'builtin registry audit: Set.%s has no argument-type descriptor\n' "$name" >&2
        exit 1
    fi
    if [[ "$name" == "discard" ]]; then
        if ! rg -q 'scripting_set_builtin_available\(state, method_name\)' "$lowerer_file" || ! rg -q 'typed_builtin_method_spec\("Set", "discard"\)' "$lowerer_file"; then
            printf 'builtin registry audit: lowerer has no Set method branch for %s\n' "$name" >&2
            exit 1
        fi
    elif ! rg -q "scripting_set_builtin_available\(state, method_name\) and method_name == \"$name\"" "$lowerer_file"; then
        printf 'builtin registry audit: lowerer has no Set method branch for %s\n' "$name" >&2
        exit 1
    fi
    if [[ "$name" == "add" ]] && ! rg -q 'def lowers_set_mutations_through_branch_merge\(' "$lowering_test_file"; then
        printf 'builtin registry audit: Set.add lowering fixture is missing\n' >&2
        exit 1
    fi
    if [[ "$name" == "remove" ]] && ! rg -q 'def lowers_mutable_set_remove_to_typed_delete\(' "$lowering_test_file"; then
        printf 'builtin registry audit: Set.remove lowering fixture is missing\n' >&2
        exit 1
    fi
    if [[ "$name" == "discard" ]] && ! rg -q 'values\.discard\(' "$lowering_test_file"; then
        printf 'builtin registry audit: Set.discard lowering fixture is missing\n' >&2
        exit 1
    fi
    if [[ "$name" == "clear" ]] && ! rg -q 'def lowers_mutable_set_clear_to_typed_empty_map\(' "$lowering_test_file"; then
        printf 'builtin registry audit: Set.clear lowering fixture is missing\n' >&2
        exit 1
    fi
    if ! rg -q 'def set_mutation_receiver_registry_shapes_are_static\(' "$semantic_test_file"; then
        printf 'builtin registry audit: Set.%s semantic fixture is missing\n' "$name" >&2
        exit 1
    fi
    if ! rg -q 'def source_set_mutation_declarations_take_precedence_over_registry_rows\(' "$semantic_test_file"; then
        printf 'builtin registry audit: Set.%s source-shadow semantic fixture is missing\n' "$name" >&2
        exit 1
    fi
    if ! rg -q 'def lowers_set_source_functions_before_registry_rows\(' "$lowering_test_file"; then
        printf 'builtin registry audit: Set.%s source-shadow lowering fixture is missing\n' "$name" >&2
        exit 1
    fi
    if [[ "$name" == "discard" ]]; then
        if ! rg -q 'def discard\(values: mutable set\[' "$semantic_test_file" || ! rg -q 'values\.discard\(' "$semantic_test_file"; then
            printf 'builtin registry audit: Set.discard source-shadow semantic fixture is missing\n' >&2
            exit 1
        fi
        if ! rg -q 'def discard\(values: mutable set\[' "$lowering_test_file" || ! rg -q 'values\.discard\(' "$lowering_test_file"; then
            printf 'builtin registry audit: Set.discard source-shadow lowering fixture is missing\n' >&2
            exit 1
        fi
    fi
    opcode="$(sed -n "s/.*name: \"$name\".*receiver: \"Set\".*opcode: \"\([A-Za-z0-9_]*\)\".*/\1/p" "$registry_file" | head -1)"
    if [[ -z "$opcode" ]] || ! rg -q "Opcode\\.$opcode" "$verifier_file"; then
        printf 'builtin registry audit: Set.%s opcode is not verifier-covered (%s)\n' "$name" "${opcode:-missing}" >&2
        exit 1
    fi
done

array_method_names="$(sed -n '/def typed_builtin_array_method_names/,$p' "$registry_file" | rg -o '"[a-z_][a-z0-9_]*"' | tr -d '"' | sort -u)"
if [[ -z "$array_method_names" ]]; then
    printf 'builtin registry audit: typed_builtin_array_method_names is empty\n' >&2
    exit 1
fi
for name in $array_method_names; do
    if ! rg -q "known: true, name: \"$name\", receiver: \"Array\"" "$registry_file"; then
        printf 'builtin registry audit: Array.%s has no receiver-specific registry row\n' "$name" >&2
        exit 1
    fi
    if ! rg -q "name: \"$name\", receiver: \"Array\".*argument_types:" "$registry_file"; then
        printf 'builtin registry audit: Array.%s has no argument-type descriptor\n' "$name" >&2
        exit 1
    fi
    if ! rg -q 'scripting_array_builtin_available\(state, method_name\)' "$lowerer_file" || ! rg -q "method_name == \"$name\"" "$lowerer_file"; then
        printf 'builtin registry audit: lowerer has no Array method branch for %s\n' "$name" >&2
        exit 1
    fi
    if [[ "$name" == "copy" ]] && ! rg -q 'values: darray\[i64\] = \[1, 2\].*return values\.copy\(\)' "$lowering_test_file"; then
        printf 'builtin registry audit: Array.copy lowering fixture is missing\n' >&2
        exit 1
    fi
    if [[ "$name" == "count" ]] && ! rg -q 'count: usize = values\.count\(1\)' "$semantic_test_file"; then
        printf 'builtin registry audit: Array.count semantic fixture is missing\n' >&2
        exit 1
    fi
    if [[ "$name" == "find" ]] && ! rg -q 'found: i64 = values\.find\(1\)' "$semantic_test_file"; then
        printf 'builtin registry audit: Array.find semantic fixture is missing\n' >&2
        exit 1
    fi
    if [[ "$name" == "index" ]] && ! rg -q 'def lowers_python_array_index_method\(' "$lowering_test_file"; then
        printf 'builtin registry audit: Array.index lowering fixture is missing\n' >&2
        exit 1
    fi
    if [[ "$name" == "contains" ]] && ! rg -q 'array_present: bool = values\.contains\(1\)' "$semantic_test_file"; then
        printf 'builtin registry audit: Array.contains semantic fixture is missing\n' >&2
        exit 1
    fi
    if [[ "$name" == "pop" ]] && ! rg -q 'def lowers_python_pop_as_typed_array_value_and_rebinding\(' "$lowering_test_file"; then
        printf 'builtin registry audit: Array.pop lowering fixture is missing\n' >&2
        exit 1
    fi
    if [[ "$name" == "reverse" ]] && ! rg -q 'def lowers_python_reverse_as_typed_array_rebinding\(' "$lowering_test_file"; then
        printf 'builtin registry audit: Array.reverse lowering fixture is missing\n' >&2
        exit 1
    fi
    if [[ "$name" == "sort" ]] && ! rg -q 'def lowers_python_array_sort_method\(' "$lowering_test_file"; then
        printf 'builtin registry audit: Array.sort lowering fixture is missing\n' >&2
        exit 1
    fi
    if [[ "$name" == "insert" ]] && ! rg -q 'def lowers_python_insert_as_typed_array_rebinding\(' "$lowering_test_file"; then
        printf 'builtin registry audit: Array.insert lowering fixture is missing\n' >&2
        exit 1
    fi
    if [[ "$name" == "remove" ]] && ! rg -q 'def lowers_python_array_remove_method\(' "$lowering_test_file"; then
        printf 'builtin registry audit: Array.remove lowering fixture is missing\n' >&2
        exit 1
    fi
    if [[ "$name" == "push" || "$name" == "extend" ]] && ! rg -q 'def lowers_array_push_and_extend_as_control_flow_visible_ssa_rebinding\(' "$lowering_test_file"; then
        printf 'builtin registry audit: Array.%s lowering fixture is missing\n' "$name" >&2
        exit 1
    fi
    if [[ "$name" == "append" ]] && ! rg -q 'def lowers_python_append_as_typed_array_growth\(' "$lowering_test_file"; then
        printf 'builtin registry audit: Array.append lowering fixture is missing\n' >&2
        exit 1
    fi
    if [[ "$name" == "clear" ]] && ! rg -q 'def lowers_mutable_array_clear_to_typed_empty_array\(' "$lowering_test_file"; then
        printf 'builtin registry audit: Array.clear lowering fixture is missing\n' >&2
        exit 1
    fi
    if [[ "$name" == "reverse" || "$name" == "sort" ]] && ! rg -q 'def array_mutation_receiver_registry_shapes_are_static\(' "$semantic_test_file"; then
        printf 'builtin registry audit: Array mutation semantic fixture is missing\n' >&2
        exit 1
    fi
    if [[ "$name" == "reverse" || "$name" == "sort" ]] && ! rg -q 'def source_collection_mutation_declarations_take_precedence_over_registry_rows\(' "$semantic_test_file"; then
        printf 'builtin registry audit: Array.%s source-shadow semantic fixture is missing\n' "$name" >&2
        exit 1
    fi
    if [[ "$name" == "reverse" || "$name" == "sort" ]] && ! rg -q 'def lowers_collection_mutation_source_functions_before_registry_rows\(' "$lowering_test_file"; then
        printf 'builtin registry audit: Array.%s source-shadow lowering fixture is missing\n' "$name" >&2
        exit 1
    fi
    opcode="$(sed -n "s/.*name: \"$name\".*receiver: \"Array\".*opcode: \"\([A-Za-z0-9_]*\)\".*/\1/p" "$registry_file" | head -1)"
    if [[ -z "$opcode" ]] || ! rg -q "Opcode\\.$opcode" "$verifier_file"; then
        printf 'builtin registry audit: Array.%s opcode is not verifier-covered (%s)\n' "$name" "${opcode:-missing}" >&2
        exit 1
    fi
done

for regex_search_pair in search:0 match:1 fullmatch:2; do
    regex_search_name="${regex_search_pair%%:*}"
    regex_search_mode="${regex_search_pair##*:}"
    if ! rg -q "name: \"$regex_search_name\", receiver: \"Regex\".*argument_types: \"text\".*return_type: \"bool\".*effects: \"\".*errors: \"\".*opcode: \"RegexSearch\".*lowering_mode: $regex_search_mode" "$registry_file"; then
        printf 'builtin registry audit: Regex search row lacks mode metadata: %s\n' "$regex_search_name" >&2
        exit 1
    fi
done
if ! rg -q 'name: "capture_names", receiver: "Regex".*argument_types: "text".*return_type: "darray\[text\]".*effects: "".*errors: "".*opcode: "RegexCapture".*lowering_mode: 1' "$registry_file" || \
   ! rg -q 'def evaluate_regex_capture\(machine: mutable Machine&.*mode: i64 = 0' "$interpreter_file" || \
   ! rg -q 'if mode not in \{0, 1\}' "$interpreter_file" || \
   ! rg -q 'mode == 1' "$interpreter_file" || \
   ! rg -q 'regex_capture_value\(storage, regex_text\.text, regex_pattern\.text, instruction\.integer\)' "$bytecode_file" || \
   ! rg -q 'valid_mode: bool = instruction\.integer in \{0, 1\}' "$verifier_file" || \
   ! rg -q 'def verifier_rejects_unknown_regex_capture_mode\(' "$ir_test_file" || \
   ! rg -q 'def interpreter_preserves_optional_regex_capture_slots\(' "$interpreter_test_file" || \
   ! rg -q 'def bytecode_direct_optional_regex_capture_matches_reference_interpreter\(' "$bytecode_test_file"; then
    printf 'builtin registry audit: Regex.capture_names mode contract is incomplete\n' >&2
    exit 1
fi
if ! rg -q 'name: "capture_named", receiver: "Regex".*argument_types: "text,text".*return_type: "sview".*effects: "".*errors: "".*opcode: "RegexCaptureNamed"' "$registry_file" || \
   ! rg -q 'def lower_regex_capture_named_method\(receiver_expression: Ast::Expr' "$lowerer_file" || \
   ! rg -q 'method_spec\.known and method_spec\.opcode == "RegexCaptureNamed"' "$lowerer_file" || \
   ! rg -q 'is_regex_receiver_expression\(Expr\.Ident\(receiver_name, receiver_pos\), state\).*method_name == "capture_named"' "$lowerer_file" || \
   ! rg -q 'is_regex_receiver_expression\(receiver_expression, state\).*method_name == "capture_named"' "$lowerer_file" || \
   ! rg -q 'regex_capture_named_value\(storage, regex_text\.text, regex_pattern\.text, regex_capture_name\.text\)' "$bytecode_file" || \
   ! rg -q 'Opcode\.RegexCaptureNamed' "$verifier_file"; then
    printf 'builtin registry audit: Regex.capture_named contract is incomplete\n' >&2
    exit 1
fi
if ! rg -q 'def lower_regex_method\(receiver_expression: Ast::Expr, method_name: sview, arguments:' "$lowerer_file" || \
   ! rg -q 'method_spec\.known and \(method_spec\.opcode == "RegexSearch" or method_spec\.opcode == "RegexFind" or method_spec\.opcode == "RegexCapture"\)' "$lowerer_file" || \
   ! rg -q 'mode: i64 = method_spec\.lowering_mode' "$lowerer_file" || \
   rg -q '1 if method_name == "match"' "$lowerer_file"; then
    printf 'builtin registry audit: Regex receiver search lowerer does not consume registry mode metadata\n' >&2
    exit 1
fi
if ! rg -q 'name: "sub", receiver: "Regex".*argument_types: "text,text".*return_type: "sview".*effects: "".*errors: "".*opcode: "RegexReplace"' "$registry_file" || \
   ! rg -q 'def lower_regex_sub_method\(receiver_expression: Ast::Expr' "$lowerer_file" || \
   ! rg -q 'method_spec\.known and method_spec\.opcode == "RegexReplace"' "$lowerer_file" || \
   ! rg -q 'opcode: Opcode = Opcode\.RegexReplace if method_spec\.opcode == "RegexReplace"' "$lowerer_file" || \
   ! rg -q 'typed_builtin_result_type\(method_spec\)' "$lowerer_file"; then
    printf 'builtin registry audit: Regex sub receiver lowerer does not consume registry result/opcode metadata\n' >&2
    exit 1
fi
if ! rg -q 'name: "split", receiver: "Regex".*argument_types: "text".*return_type: "darray\[text\]".*effects: "".*errors: "".*opcode: "RegexSplit"' "$registry_file" || \
   ! rg -q 'def lower_regex_split_method\(receiver_expression: Ast::Expr' "$lowerer_file" || \
   ! rg -q 'method_spec\.known and method_spec\.opcode == "RegexSplit"' "$lowerer_file"; then
    printf 'builtin registry audit: Regex split receiver lowerer does not consume registry opcode metadata\n' >&2
    exit 1
fi
if ! rg -q 'name: "count", receiver: "Regex".*argument_types: "text".*return_type: "usize".*effects: "".*errors: "".*opcode: "RegexFind".*lowering_steps: "RegexFind,Length"' "$registry_file" || \
   ! rg -q 'def lower_regex_count_method\(receiver_expression: Ast::Expr' "$lowerer_file" || \
   ! rg -q 'method_spec\.opcode == "RegexFind" and method_spec\.lowering_steps == "RegexFind,Length"' "$lowerer_file" || \
   ! rg -q 'opcode: Opcode\.RegexFind' "$lowerer_file" || \
   ! rg -q 'opcode: Opcode\.Length' "$lowerer_file" || \
   ! rg -q 'def scripting_regex_registry_return_type\(method: sview\)' "$inference_file" || \
   ! rg -q 'return type_of_name\("usize"\) if spec\.known and spec\.return_type == "usize"' "$inference_file" || \
   ! rg -q 'is_regex_receiver_expression\(Expr\.Ident\(receiver_name, receiver_pos\), state\) and scripting_regex_builtin_available\(state, method_name\) and method_name == "count"' "$lowerer_file" || \
   ! rg -q 'is_regex_receiver_expression\(receiver_expression, state\) and scripting_regex_builtin_available\(state, method_name\) and method_name == "count"' "$lowerer_file" || \
   ! rg -q 'def lowers_regex_receiver_count_as_find_then_length\(' "$lowering_test_file" || \
   ! rg -q 'def regex_count_receiver_preserves_usize_result_shape\(' "$semantic_test_file"; then
    printf 'builtin registry audit: Regex count composition is incomplete\n' >&2
    exit 1
fi

if ! rg -q 'typed_builtin_spec\(builtin_name\)' "$semantic_file"; then
    printf 'builtin registry audit: semantic seed table does not consume typed_builtin_spec\n' >&2
    exit 1
fi
if ! rg -q 'EsBuiltin::typed_builtin_names\(\)' "$semantic_file" || ! rg -q 'registry_names: darray\[sview\]' "$semantic_file"; then
    printf 'builtin registry audit: semantic seed table does not extend from typed_builtin_names\n' >&2
    exit 1
fi

if ! rg -q 'argument_types: builtin_spec\.argument_types' "$semantic_file" || \
   ! rg -q 'effects: builtin_spec\.effects' "$semantic_file" || \
   ! rg -q 'errors: builtin_spec\.errors' "$semantic_file" || \
   ! rg -q 'opcode: builtin_spec\.opcode' "$semantic_file"; then
    printf 'builtin registry audit: semantic symbols do not preserve full builtin metadata\n' >&2
    exit 1
fi

# The strict scalar/text rows must source their result types from the registry;
# this prevents a lowerer branch from silently drifting from semantic metadata.
if ! rg -q 'typed_builtin_result_type\([a-z_]+_spec\)' "$lowerer_file"; then
    printf 'builtin registry audit: lowerer has no registry return-type consumer\n' >&2
    exit 1
fi

if ! rg -q 'state\.required_errors\.push\(spec\.errors\)' "$lowerer_file" || \
   ! rg -q 'record_builtin_contract\(registry_spec, state\)' "$lowerer_file"; then
    printf 'builtin registry audit: lowerer has no registry error-row consumer\n' >&2
    exit 1
fi
# Fixed global text aliases must derive their result shape, opcode, and any
# alias-specific mode from the same registry rows used by semantic checking.
if ! rg -q 'name: "len", receiver: "global".*argument_types: "collection\|text".*return_type: "usize".*effects: "".*errors: "".*opcode: "Length"' "$registry_file" || \
   ! rg -q 'len_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.opcode == "Length"' "$lowerer_file" || \
   ! rg -q 'len_spec\.opcode == "Length"' "$lowerer_file"; then
    printf 'builtin registry audit: global len lowerer does not consume registry shape/result/opcode metadata\n' >&2
    exit 1
fi
if ! rg -q 'name: "contains", receiver: "global".*argument_types: "collection,any".*return_type: "bool".*effects: "".*errors: "".*opcode: "Contains"' "$registry_file" || \
   ! rg -q 'contains_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.opcode == "Contains"' "$lowerer_file" || \
   ! rg -q 'contains_spec\.opcode == "Contains"' "$lowerer_file" || \
   ! rg -q 'def lower_collection_contains_expression\(collection_expression: Ast::Expr.*spec: EsBuiltin::BuiltinSpec' "$lowerer_file" || \
   ! rg -q 'opcode: Opcode = Opcode.Contains if spec\.opcode == "Contains"' "$lowerer_file"; then
    printf 'builtin registry audit: global/receiver contains lowerers do not consume registry shape/result/opcode metadata\n' >&2
    exit 1
fi
if ! rg -q 'name: "str", receiver: "global".*argument_types: "any".*return_type: "sview".*effects: "".*errors: "".*opcode: "FormatNominal".*lowering_steps: "FormatChar|FormatNominal|FormatBool|FormatInt|FormatFloat|FormatAggregate"' "$registry_file" || \
   ! rg -q 'str_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "any" and registry_spec\.opcode == "FormatNominal"' "$lowerer_file" || \
   ! rg -q 'str_spec\.opcode == "FormatNominal" and str_spec\.lowering_steps != ""' "$lowerer_file"; then
    printf 'builtin registry audit: str lowerer does not consume registry formatter metadata\n' >&2
    exit 1
fi
for empty_name in is_empty isempty; do
    if ! rg -q "name: \"$empty_name\", receiver: \"global\".*argument_types: \"collection\\|text\".*return_type: \"bool\".*effects: \"\".*errors: \"\".*opcode: \"Equal\".*lowering_steps: \"Length,Equal\"" "$registry_file" || \
       ! rg -q "name: \"$empty_name\", receiver: \"Text\".*argument_types: \"\".*return_type: \"bool\".*effects: \"\".*errors: \"\".*opcode: \"Equal\".*lowering_steps: \"Length,Equal\"" "$registry_file"; then
        printf 'builtin registry audit: is-empty row lacks Length,Equal lowering sequence: %s\n' "$empty_name" >&2
        exit 1
    fi
done
if ! rg -q 'empty_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.opcode == "Equal" and registry_spec\.lowering_steps == "Length,Equal"' "$lowerer_file" || \
   ! rg -q 'empty_spec\.lowering_steps == "Length,Equal"' "$lowerer_file" || \
   ! rg -q 'def lower_collection_is_empty_expression\(receiver_expression: Ast::Expr.*spec: EsBuiltin::BuiltinSpec' "$lowerer_file" || \
   ! rg -q 'spec\.opcode != "Equal" or spec\.lowering_steps != "Length,Equal"' "$lowerer_file"; then
    printf 'builtin registry audit: is-empty lowerers do not consume registry sequence metadata\n' >&2
    exit 1
fi
for nonempty_name in is_nonempty nonempty; do
    if ! rg -q "name: \"$nonempty_name\", receiver: \"global\".*argument_types: \"collection\\|text\\|Path\".*return_type: \"bool\".*effects: \"\".*errors: \"\".*opcode: \"Greater\".*lowering_steps: \"Length,Greater\"" "$registry_file" || \
       ! rg -q "name: \"$nonempty_name\", receiver: \"Text\".*argument_types: \"\".*return_type: \"bool\".*effects: \"\".*errors: \"\".*opcode: \"Greater\".*lowering_steps: \"Length,Greater\"" "$registry_file"; then
        printf 'builtin registry audit: is-nonempty row lacks Length,Greater lowering sequence: %s\n' "$nonempty_name" >&2
        exit 1
    fi
done
if ! rg -q 'nonempty_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and \(\(registry_spec\.opcode == "Greater" and registry_spec\.lowering_steps == "Length,Greater"\) or \(registry_spec\.opcode == "FileSize" and registry_spec\.lowering_steps == "FileSize,Greater"\)\)' "$lowerer_file" || \
   ! rg -q 'def lower_collection_nonempty_expression\(receiver_expression: Ast::Expr.*spec: EsBuiltin::BuiltinSpec' "$lowerer_file" || \
   ! rg -q 'spec\.opcode != "Greater" and spec\.opcode != "FileSize"' "$lowerer_file"; then
    printf 'builtin registry audit: is-nonempty lowerers do not consume registry opcode metadata\n' >&2
    exit 1
fi
for text_name in starts_with startswith; do
    if ! rg -q "name: \"$text_name\", receiver: \"global\".*argument_types: \"text,text\".*return_type: \"bool\".*effects: \"\".*errors: \"\".*opcode: \"StartsWith\"" "$registry_file"; then
        printf 'builtin registry audit: starts-with row is incomplete: %s\n' "$text_name" >&2
        exit 1
    fi
done
for text_name in ends_with endswith; do
    if ! rg -q "name: \"$text_name\", receiver: \"global\".*argument_types: \"text,text\".*return_type: \"bool\".*effects: \"\".*errors: \"\".*opcode: \"EndsWith\"" "$registry_file"; then
        printf 'builtin registry audit: ends-with row is incomplete: %s\n' "$text_name" >&2
        exit 1
    fi
done
if ! rg -q 'name: "replace", receiver: "global".*argument_types: "text,text,text".*return_type: "sview".*effects: "".*errors: "".*opcode: "TextReplace"' "$registry_file" || \
   ! rg -q 'name: "partition", receiver: "global".*argument_types: "text,text".*return_type: "darray\[text\]".*effects: "".*errors: "".*opcode: "TextPartition".*lowering_mode: 0' "$registry_file" || \
   ! rg -q 'name: "rpartition", receiver: "global".*argument_types: "text,text".*return_type: "darray\[text\]".*effects: "".*errors: "".*opcode: "TextPartition".*lowering_mode: 1' "$registry_file" || \
   ! rg -q 'name: "split_lines", receiver: "global".*argument_types: "text".*return_type: "darray\[text\]".*effects: "".*errors: "".*opcode: "SplitLines"' "$registry_file" || \
   ! rg -q 'name: "splitlines", receiver: "global".*argument_types: "text".*return_type: "darray\[text\]".*effects: "".*errors: "".*opcode: "SplitLines"' "$registry_file" || \
   ! rg -q 'name: "join", receiver: "global".*argument_types: "darray\[text\],text".*return_type: "sview".*effects: "".*errors: "".*opcode: "Join"' "$registry_file"; then
    printf 'builtin registry audit: fixed global text operation rows are incomplete\n' >&2
    exit 1
fi
if ! rg -q 'starts_with_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.opcode == "StartsWith"' "$lowerer_file" || \
   ! rg -q 'starts_with_spec\.opcode == "StartsWith"' "$lowerer_file" || \
   ! rg -q 'ends_with_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.opcode == "EndsWith"' "$lowerer_file" || \
   ! rg -q 'ends_with_spec\.opcode == "EndsWith"' "$lowerer_file" || \
   ! rg -q 'replace_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.opcode == "TextReplace"' "$lowerer_file" || \
   ! rg -q 'replace_spec\.opcode == "TextReplace"' "$lowerer_file" || \
   ! rg -q 'split_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.opcode == "Split"' "$lowerer_file" || \
   ! rg -q 'split_spec\.opcode == "Split"' "$lowerer_file" || \
   ! rg -q 'name: "split", receiver: "global".*opcode: "Split", lowering_mode: 0' "$registry_file" || \
   ! rg -q 'integer: split_spec\.lowering_mode' "$lowerer_file" || \
   ! rg -q 'lower_text_partition_builtin\(arguments, argument_names, registry_spec' "$lowerer_file" || \
   ! rg -q 'def lower_text_partition_builtin\(arguments: darray\[Ast::Expr\].*spec: EsBuiltin::BuiltinSpec' "$lowerer_file" || \
   ! rg -q 'spec\.opcode == "TextPartition" and typed_builtin_call_shape\(spec\.name' "$lowerer_file" || \
   ! rg -q 'integer: spec\.lowering_mode' "$lowerer_file" || \
   ! rg -q 'split_lines_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.opcode == "SplitLines"' "$lowerer_file" || \
   ! rg -q 'split_lines_spec\.opcode == "SplitLines"' "$lowerer_file" || \
   ! rg -q 'join_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "darray\[text\],text" and registry_spec\.opcode == "Join"' "$lowerer_file" || \
   ! rg -q 'join_spec\.opcode == "Join"' "$lowerer_file"; then
    printf 'builtin registry audit: fixed global text lowerers do not consume registry shape/result/opcode metadata\n' >&2
    exit 1
fi
for trim_name in strip trim lstrip rstrip; do
    if ! rg -q "name: \"$trim_name\", receiver: \"global\".*argument_types: \"text\".*return_type: \"sview\".*effects: \"\".*errors: \"\".*opcode: \"TrimText\".*lowering_mode:" "$registry_file"; then
        printf 'builtin registry audit: trim row lacks lowering mode: %s\n' "$trim_name" >&2
        exit 1
    fi
    if ! rg -q "name: \"$trim_name\", receiver: \"Text\".*argument_types: \"\".*return_type: \"sview\".*effects: \"\".*errors: \"\".*opcode: \"TrimText\".*lowering_mode:" "$registry_file"; then
        printf 'builtin registry audit: Text trim row lacks lowering mode: %s\n' "$trim_name" >&2
        exit 1
    fi
done
if ! rg -q 'trim_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.opcode == "TrimText"' "$lowerer_file" || \
   ! rg -q 'trim_spec\.opcode == "TrimText"' "$lowerer_file" || \
   ! rg -q 'trim_mode: i64 = trim_spec\.lowering_mode' "$lowerer_file" || \
   ! rg -q 'case_spec: EsBuiltin::BuiltinSpec = registry_spec' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and \(registry_spec\.opcode == "LowerText" or registry_spec\.opcode == "UpperText"\)' "$lowerer_file" || \
   ! rg -q 'case_spec\.opcode == "LowerText"' "$lowerer_file" || \
   ! rg -q 'lower_text_case_value_with_spec\(text_value\.value, case_spec' "$lowerer_file"; then
    printf 'builtin registry audit: global case/trim lowerers do not consume registry mode metadata\n' >&2
    exit 1
fi
if ! rg -q 'def lower_text_trim_expression\(receiver_expression: Ast::Expr.*state: mutable LowerState&\)' "$lowerer_file" || \
   ! rg -q 'method_spec\.opcode == "TrimText"' "$lowerer_file" || \
   ! rg -q 'integer: method_spec\.lowering_mode' "$lowerer_file" || \
   rg -q 'trim_mode: i64 = 1 if method_name == "lstrip"' "$lowerer_file"; then
    printf 'builtin registry audit: Text trim receiver lowerers do not consume registry mode metadata\n' >&2
    exit 1
fi
if ! rg -q 'name: "replace", receiver: "Text".*argument_types: "text,text".*return_type: "sview".*effects: "".*errors: "".*opcode: "TextReplace"' "$registry_file" || \
   ! rg -q 'def lower_text_replace_expression\(receiver_expression: Ast::Expr, method_name: sview' "$lowerer_file" || \
   ! rg -q 'method_spec\.known and method_spec\.opcode == "TextReplace"' "$lowerer_file" || \
   ! rg -q 'opcode: Opcode = Opcode\.TextReplace if method_spec\.opcode == "TextReplace"' "$lowerer_file" || \
   ! rg -q 'typed_builtin_result_type\(method_spec\)' "$lowerer_file"; then
    printf 'builtin registry audit: Text replace receiver lowerer does not consume registry result/opcode metadata\n' >&2
    exit 1
fi
if ! rg -q 'name: "join", receiver: "Text".*argument_types: "darray\[text\]".*return_type: "sview".*effects: "".*errors: "".*opcode: "Join"' "$registry_file" || \
   ! rg -q 'def lower_text_join_expression\(receiver_expression: Ast::Expr, method_name: sview' "$lowerer_file" || \
   ! rg -q 'method_spec\.known and method_spec\.opcode == "Join"' "$lowerer_file" || \
   ! rg -q 'opcode: Opcode = Opcode\.Join if method_spec\.opcode == "Join"' "$lowerer_file"; then
    printf 'builtin registry audit: Text join receiver lowerer does not consume registry result/opcode metadata\n' >&2
    exit 1
fi
if ! rg -q 'name: "splitlines", receiver: "Text".*argument_types: "".*return_type: "darray\[text\]".*effects: "".*errors: "".*opcode: "SplitLines"' "$registry_file" || \
   ! rg -q 'def lower_text_split_lines_expression\(receiver_expression: Ast::Expr, method_name: sview' "$lowerer_file" || \
   ! rg -q 'method_spec\.known or method_spec\.opcode != "SplitLines"' "$lowerer_file" || \
   ! rg -q 'def lower_text_split_lines_value\(value: u32, method_spec: EsBuiltin::BuiltinSpec' "$lowerer_file" || \
   ! rg -q 'result_type: Type = typed_builtin_result_type\(method_spec\)' "$lowerer_file"; then
    printf 'builtin registry audit: Text splitlines receiver lowerer does not consume registry result/opcode metadata\n' >&2
    exit 1
fi
if ! rg -q 'def lower_text_case_value_with_spec\(value: u32, method_spec: EsBuiltin::BuiltinSpec' "$lowerer_file" || \
   ! rg -q 'method_spec\.known or \(method_spec\.opcode != "LowerText" and method_spec\.opcode != "UpperText"\)' "$lowerer_file" || \
   ! rg -q 'result_type: Type = typed_builtin_result_type\(method_spec\)' "$lowerer_file"; then
    printf 'builtin registry audit: Text case lowerer does not consume registry result/opcode metadata\n' >&2
    exit 1
fi
if ! rg -q 'name: "len", receiver: "Text".*argument_types: "".*return_type: "usize".*effects: "".*errors: "".*opcode: "Length"' "$registry_file" || \
   ! rg -q 'def lower_text_length_expression\(receiver_expression: Ast::Expr, method_name: sview' "$lowerer_file" || \
   ! rg -q 'method_spec\.known or method_spec\.opcode != "Length"' "$lowerer_file" || \
   ! rg -q 'typed_builtin_result_type\(method_spec\)' "$lowerer_file"; then
    printf 'builtin registry audit: Text length receiver lowerer does not consume registry result/opcode metadata\n' >&2
    exit 1
fi
for predicate_pair in isdigit:0 isalpha:1 isalnum:2 isspace:3 islower:4 isupper:5 isascii:6 isdecimal:7 isnumeric:8 isprintable:9; do
    predicate_name="${predicate_pair%%:*}"
    predicate_mode="${predicate_pair##*:}"
    if ! rg -q "name: \"$predicate_name\", receiver: \"Text\".*argument_types: \"\".*return_type: \"bool\".*effects: \"\".*errors: \"\".*opcode: \"TextPredicate\".*lowering_mode: $predicate_mode" "$registry_file"; then
        printf 'builtin registry audit: Text predicate row lacks mode metadata: %s\n' "$predicate_name" >&2
        exit 1
    fi
done
if ! rg -q 'method_spec\.opcode != "TextPredicate"' "$lowerer_file" || \
   ! rg -q 'mode: i64 = method_spec\.lowering_mode' "$lowerer_file"; then
    printf 'builtin registry audit: Text predicate lowerer does not consume registry mode metadata\n' >&2
    exit 1
fi
for boundary_pair in removeprefix:0 removesuffix:1; do
    boundary_name="${boundary_pair%%:*}"
    boundary_mode="${boundary_pair##*:}"
    if ! rg -q "name: \"$boundary_name\", receiver: \"Text\".*argument_types: \"text\".*return_type: \"sview\".*effects: \"\".*errors: \"\".*opcode: \"TextRemoveBoundary\".*lowering_mode: $boundary_mode" "$registry_file"; then
        printf 'builtin registry audit: Text boundary-removal row lacks mode metadata: %s\n' "$boundary_name" >&2
        exit 1
    fi
done
for boundary_opcode_pair in starts_with:StartsWith startswith:StartsWith ends_with:EndsWith endswith:EndsWith; do
    boundary_name="${boundary_opcode_pair%%:*}"
    boundary_opcode="${boundary_opcode_pair##*:}"
    if ! rg -q "name: \"$boundary_name\", receiver: \"Text\".*argument_types: \"text\".*return_type: \"bool\".*effects: \"\".*errors: \"\".*opcode: \"$boundary_opcode\"" "$registry_file"; then
        printf 'builtin registry audit: Text boundary-predicate row is incomplete: %s\n' "$boundary_name" >&2
        exit 1
    fi
done
if ! rg -q 'def lower_text_boundary_expression\(receiver_expression: Ast::Expr, method_name: sview, arguments:' "$lowerer_file" || \
   ! rg -q 'method_spec\.known and \(method_spec\.opcode == "StartsWith" or method_spec\.opcode == "EndsWith"\)' "$lowerer_file" || \
   ! rg -q 'typed_builtin_method_call_shape\("Text", method_name, arguments, argument_names\)' "$lowerer_file" || \
   ! rg -q 'typed_builtin_result_type\(method_spec\)' "$lowerer_file"; then
    printf 'builtin registry audit: Text boundary-predicate lowerer does not consume registry result/opcode metadata\n' >&2
    exit 1
fi
if ! rg -q 'def lower_text_remove_boundary_expression\(receiver_expression: Ast::Expr, method_name: sview, arguments:' "$lowerer_file" || \
   ! rg -q 'not method_spec\.known or method_spec\.opcode != "TextRemoveBoundary"' "$lowerer_file" || \
   ! rg -q 'mode: i64 = method_spec\.lowering_mode' "$lowerer_file" || \
   rg -q 'lower_text_remove_boundary_expression\([^\n]*, (true|false),' "$lowerer_file" || \
   rg -q '0 if starts else 1' "$lowerer_file"; then
    printf 'builtin registry audit: Text boundary-removal lowerer does not consume registry mode metadata\n' >&2
    exit 1
fi
for partition_pair in partition:0 rpartition:1; do
    partition_name="${partition_pair%%:*}"
    partition_mode="${partition_pair##*:}"
    if ! rg -q "name: \"$partition_name\", receiver: \"Text\".*argument_types: \"text\".*return_type: \"darray\[text\]\".*effects: \"\".*errors: \"\".*opcode: \"TextPartition\".*lowering_mode: $partition_mode" "$registry_file"; then
        printf 'builtin registry audit: Text partition row lacks mode metadata: %s\n' "$partition_name" >&2
        exit 1
    fi
done
if ! rg -q 'def lower_text_partition_expression\(receiver_expression: Ast::Expr, method_name: sview, arguments:' "$lowerer_file" || \
   ! rg -q 'method_spec\.known and method_spec\.opcode == "TextPartition"' "$lowerer_file" || \
   ! rg -q 'integer: method_spec\.lowering_mode' "$lowerer_file" || \
   rg -q 'lower_text_partition_expression\([^\n]*, (true|false),' "$lowerer_file" || \
   rg -q '1 if reverse else 0' "$lowerer_file"; then
    printf 'builtin registry audit: Text partition lowerer does not consume registry mode metadata\n' >&2
    exit 1
fi
for split_pair in split:0 rsplit:2; do
    split_name="${split_pair%%:*}"
    split_mode="${split_pair##*:}"
    if ! rg -q "name: \"$split_name\", receiver: \"Text\".*argument_types: \"text,i64\".*return_type: \"darray\[text\]\".*effects: \"\".*errors: \"\".*opcode: \"Split\".*lowering_mode: $split_mode" "$registry_file"; then
        printf 'builtin registry audit: Text split row lacks mode metadata: %s\n' "$split_name" >&2
        exit 1
    fi
done
if ! rg -q 'def lower_text_split_expression\(receiver_expression: Ast::Expr, method_name: sview, arguments:' "$lowerer_file" || \
   ! rg -q 'method_spec\.known and method_spec\.opcode == "Split"' "$lowerer_file" || \
   ! rg -q 'mode: i64 = 1 if arguments\.count == 0 else method_spec\.lowering_mode' "$lowerer_file" || \
   rg -q 'lower_text_split_expression\([^\n]*, (true|false),' "$lowerer_file" || \
   rg -q '2 if reverse else 0' "$lowerer_file"; then
    printf 'builtin registry audit: Text split lowerer does not consume registry direction metadata\n' >&2
    exit 1
fi
if ! rg -q 'name: "rfind", receiver: "Text".*argument_types: "text".*return_type: "i64".*effects: "".*errors: "".*opcode: "TextRFind"' "$registry_file" || \
   ! rg -q 'def lower_text_rfind_expression\(receiver_expression: Ast::Expr, arguments:.*method_name: sview' "$lowerer_file" || \
   ! rg -q 'method_spec\.known and method_spec\.opcode == "TextRFind"' "$lowerer_file" || \
   ! rg -q 'typed_builtin_result_type\(method_spec\)' "$lowerer_file"; then
    printf 'builtin registry audit: Text rfind lowerer does not consume registry result/opcode metadata\n' >&2
    exit 1
fi
if ! rg -q 'name: "index", receiver: "Text".*argument_types: "text".*return_type: "i64".*effects: "".*errors: "IndexOutOfBounds".*opcode: "TextIndex"' "$registry_file" || \
   ! rg -q 'name: "rindex", receiver: "Text".*argument_types: "text".*return_type: "i64".*effects: "".*errors: "IndexOutOfBounds".*opcode: "TextRIndex"' "$registry_file" || \
   ! rg -q 'def lower_collection_index_expression\(receiver_expression: Ast::Expr, arguments:.*method_name: sview\)' "$lowerer_file" || \
   ! rg -q 'method_spec\.known and \(method_spec\.opcode == "TextIndex" or method_spec\.opcode == "TextRIndex"\)' "$lowerer_file" || \
   ! rg -q 'method_spec\.opcode == "TextRIndex" and collection\.type\.kind != TypeKind\.Text' "$lowerer_file" || \
   rg -q 'lower_collection_index_expression\([^\n]*, (true|false)\)' "$lowerer_file" || \
   rg -q 'method_name: sview, reverse: bool' "$lowerer_file"; then
    printf 'builtin registry audit: Text index/rindex lowerer does not consume registry opcode metadata\n' >&2
    exit 1
fi
if ! rg -q 'name: "count", receiver: "Text".*argument_types: "text".*return_type: "usize".*effects: "".*errors: "".*opcode: "TextCount"' "$registry_file" || \
   ! rg -q 'def lower_collection_count_expression\(receiver_expression: Ast::Expr' "$lowerer_file" || \
   ! rg -q 'method_spec\.known and method_spec\.opcode == "TextCount" and typed_builtin_method_call_shape\("Text", "count"' "$lowerer_file" || \
   ! rg -q 'typed_builtin_result_type\(method_spec\)' "$lowerer_file"; then
    printf 'builtin registry audit: Text/array count lowerer does not consume registry result/opcode metadata\n' >&2
    exit 1
fi
if ! rg -q 'name: "find", receiver: "Text".*argument_types: "text".*return_type: "i64".*effects: "".*errors: "".*opcode: "TextFind"' "$registry_file" || \
   ! rg -q 'def lower_collection_find_expression\(receiver_expression: Ast::Expr' "$lowerer_file" || \
   ! rg -q 'method_spec\.known and method_spec\.opcode == "TextFind" and typed_builtin_method_call_shape\("Text", "find"' "$lowerer_file" || \
   ! rg -q 'typed_builtin_result_type\(method_spec\)' "$lowerer_file"; then
    printf 'builtin registry audit: Text/array find lowerer does not consume registry result/opcode metadata\n' >&2
    exit 1
fi
if ! rg -q 'def typed_builtin_result_type' "$lowerer_file" || \
   ! rg -q 'typed_builtin_result_type\([a-z_]+_spec\)' "$lowerer_file" || \
   ! rg -q 'typed_builtin_result_type\(method_spec\)' "$lowerer_file"; then
    printf 'builtin registry audit: aggregate registry rows do not share lowerer result-shape conversion\n' >&2
    exit 1
fi
if ! rg -q 'name: "int", receiver: "global".*argument_types: "text\|i64".*return_type: "i64".*errors: "ParseError".*opcode: "ParseInt".*lowering_steps: "ParseInt\|IdentityInt"' "$registry_file" || \
   ! rg -q 'name: "float", receiver: "global".*argument_types: "text\|f64".*return_type: "f64".*errors: "ParseError".*opcode: "ParseFloat".*lowering_steps: "ParseFloat\|IdentityFloat"' "$registry_file" || \
   ! rg -q 'name: "bool", receiver: "global".*argument_types: "bool".*return_type: "bool".*errors: "".*opcode: "Copy".*lowering_steps: "IdentityBool"' "$registry_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.opcode == "ParseInt" and registry_spec\.lowering_steps == "ParseInt\|IdentityInt"' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.opcode == "ParseFloat" and registry_spec\.lowering_steps == "ParseFloat\|IdentityFloat"' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.opcode == "Copy" and registry_spec\.lowering_steps == "IdentityBool"' "$lowerer_file" || \
   ! rg -q 'spec\.argument_types == "text\|i64"' "$receiver_semantic_file" || \
   ! rg -q 'spec\.argument_types == "text\|f64"' "$receiver_semantic_file" || \
   ! rg -q 'expected == "text\|i64"' "$receiver_semantic_file" || \
   ! rg -q 'expected == "text\|f64"' "$receiver_semantic_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "text" and registry_spec\.opcode == "ParseInt"' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "text" and registry_spec\.opcode == "ParseFloat"' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "i64" and registry_spec\.opcode == "FormatInt"' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "f64" and registry_spec\.opcode == "FormatFloat"' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "bool" and registry_spec\.opcode == "FormatBool"' "$lowerer_file" || \
   ! rg -q 'registry_spec\.receiver == "global" and registry_spec\.argument_types == "char" and registry_spec\.opcode == "FormatChar"' "$lowerer_file" || \
   ! rg -q 'parse_spec\.opcode == "ParseInt"' "$lowerer_file" || \
   ! rg -q 'parse_spec\.opcode == "ParseFloat"' "$lowerer_file" || \
   ! rg -q 'format_int_spec\.opcode == "FormatInt"' "$lowerer_file" || \
   ! rg -q 'format_float_spec\.opcode == "FormatFloat"' "$lowerer_file" || \
   ! rg -q 'format_bool_spec\.opcode == "FormatBool"' "$lowerer_file" || \
   ! rg -q 'format_char_spec\.opcode == "FormatChar"' "$lowerer_file"; then
    printf 'builtin registry audit: scalar parse/format lowerers do not consume registry opcode metadata\n' >&2
    exit 1
fi

if ! rg -q 'scripting_registry_direct_return_type' "$inference_file" || \
   ! rg -q 'registry_return: InferType' "$inference_file" || \
   ! rg -q 'spec\.known and spec\.return_type == "Path"' "$inference_file"; then
    printf 'builtin registry audit: direct-call inference has no registry return-type adapter\n' >&2
    exit 1
fi
if ! rg -q 'visibility: sview = "public"' "$registry_file" || \
   ! rg -q 'name: "__fstr", receiver: "global".*arity_min: 1.*arity_max: 4294967295.*argument_types: "any".*return_type: "sview".*opcode: "".*lowering_steps: "FString".*visibility: "private"' "$registry_file" || \
   ! rg -q 'registry_spec\.known and registry_spec\.visibility == "private" and registry_spec\.receiver == "global" and registry_spec\.lowering_steps == "FString"' "$lowerer_file" || \
   rg -q 'callee_name == "__fstr"' "$lowerer_file" || \
   rg -q '^[[:space:]]*return \[.*"__fstr"' "$registry_file" || \
   ! rg -q '"__fstr"' "$semantic_file" || \
   ! rg -q 'compiler_owned_fstring_intrinsic_is_semantically_text_typed' "$semantic_test_file" || \
   ! rg -q 'f-string' "$lowering_test_file"; then
    printf 'builtin registry audit: compiler-owned __fstr intrinsic is not registry-driven\n' >&2
    exit 1
fi
if ! rg -q 'name == "regex"' "$inference_file" || \
   ! rg -q 'name: "Regex"' "$inference_file"; then
    printf 'builtin registry audit: regex typed-literal inference is not nominally preserved\n' >&2
    exit 1
fi

global_count="$(printf '%s\n' "$registry_names" | awk 'NF {count += 1} END {print count + 0}')"
text_count="$(printf '%s\n' "$method_names" | awk 'NF {count += 1} END {print count + 0}')"
regex_count="$(printf '%s\n' "$regex_method_names" | awk 'NF {count += 1} END {print count + 0}')"
map_count="$(printf '%s\n' "$map_method_names" | awk 'NF {count += 1} END {print count + 0}')"
set_count="$(printf '%s\n' "$set_method_names" | awk 'NF {count += 1} END {print count + 0}')"
array_count="$(printf '%s\n' "$array_method_names" | awk 'NF {count += 1} END {print count + 0}')"
if ! rg -q "${global_count} global spellings" "$surface_doc" || \
   ! rg -q "${global_count} global rows" "$ledger_doc" || \
   ! rg -q "${text_count} Text receiver" "$surface_doc" || \
   ! rg -q "${regex_count} Regex receiver" "$surface_doc" || \
   ! rg -q "${map_count} Map receiver" "$surface_doc" || \
   ! rg -q "${map_count} Map receiver" "$ledger_doc" || \
   ! rg -q "${set_count} Set receiver" "$surface_doc" || \
   ! rg -q "${set_count} Set receiver" "$ledger_doc" || \
   ! rg -q "${array_count} Array receiver" "$surface_doc" || \
   ! rg -q "${array_count} Array receiver" "$ledger_doc"; then
    printf 'builtin registry audit: documentation counts do not match registry rows\n' >&2
    exit 1
fi
for fixture in lowers_python_reversed_as_fresh_typed_array lowers_python_sorted_as_fresh_typed_array lowers_python_sorted_reverse_argument_through_typed_cfg; do
    if ! rg -q "def ${fixture}\(" "$lowering_test_file"; then
        printf 'builtin registry audit: aggregate lowering fixture is missing: %s\n' "$fixture" >&2
        exit 1
    fi
done
if ! rg -q 'polymorphic_collection_builtins_preserve_known_element_types' "$semantic_test_file" || \
   ! rg -q 'bad-array-reversed' "$lowering_test_file" || \
   ! rg -q 'bad-array-sorted' "$lowering_test_file"; then
    printf 'builtin registry audit: aggregate malformed-call coverage is missing\n' >&2
    exit 1
fi

printf 'builtin registry audit: %s global, %s Text, %s Regex, %s Map, %s Set, and %s Array receiver spellings share semantic and lowerer metadata\n' "$global_count" "$text_count" "$regex_count" "$map_count" "$set_count" "$array_count"
