#!/usr/bin/env bash

# Compiler-free audit for the first shared typed-builtin registry slice. This
# checks that the registry rows are complete and that semantic/lowering code
# consumes the same metadata for every registered spelling.

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
opcode_file="$repo_root/src/ir/ir_model.elisa"
verifier_file="$repo_root/src/ir/ir_verify.elisa"

for required_file in "$registry_file" "$semantic_file" "$receiver_semantic_file" "$firm_argument_file" "$literal_argument_file" "$inference_file" "$structural_inference_file" "$lowerer_file" "$opcode_file" "$verifier_file"; do
    if [[ ! -f "$required_file" ]]; then
        printf 'builtin registry audit: missing file: %s\n' "$required_file" >&2
        exit 2
    fi
done

registry_names="$(sed -n '/def typed_builtin_names/,/^        def /p' "$registry_file" | rg -o '"[a-z_][a-z0-9_]*"' | tr -d '"' | sort -u)"
method_names="$(sed -n '/def typed_builtin_method_names/,/^        def typed_builtin_regex_method_names/p' "$registry_file" | rg -o '"[a-z_][a-z0-9_]*"' | tr -d '"' | sort -u)"
regex_method_names="$(sed -n '/def typed_builtin_regex_method_names/,$p' "$registry_file" | rg -o '"[a-z_][a-z0-9_]*"' | tr -d '"' | sort -u)"
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
        printf 'builtin registry audit: lowerer has no dispatch branch for %s\n' "$name" >&2
        exit 1
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
if ! rg -q 'name: "chmod", receiver: "global".*argument_types: "Path,u64".*return_type: "bool".*effects: "File.Write".*errors: "FileIoError".*opcode: "ChmodPath"' "$registry_file" || ! rg -q 'spec\.argument_types == "Path,u64"' "$receiver_semantic_file" || ! rg -q 'expected == "u64"' "$receiver_semantic_file"; then
    printf 'builtin registry audit: chmod mixed Path/u64 row is not fully consumed\n' >&2
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
    if ! rg -q "name: \"$filesystem_name\", receiver: \"global\".*argument_types: \"Path\".*return_type: \"bool\".*effects: \"File.Write\".*errors: \"\".*opcode: \"RemovePath\"" "$registry_file"; then
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
if ! rg -q 'name: "executable", receiver: "global".*argument_types: "sview".*return_type: "Executable".*effects: "".*errors: "ProcessError".*opcode: "MakeExecutable"' "$registry_file"; then
    printf 'builtin registry audit: executable process-constructor row is incomplete\n' >&2
    exit 1
fi
if ! rg -q 'name: "run_process", receiver: "global".*argument_types: "Executable,darray\[text\]".*return_type: "i64".*effects: "Process.Run".*errors: "ProcessError".*opcode: "RunProcess"' "$registry_file"; then
    printf 'builtin registry audit: process-run row is incomplete\n' >&2
    exit 1
fi
for process_name in capture_process_stdout capture_process_stderr; do
    opcode="CaptureProcessStdout"
    [[ "$process_name" == "capture_process_stderr" ]] && opcode="CaptureProcessStderr"
    if ! rg -q "name: \"$process_name\", receiver: \"global\".*argument_types: \"Executable,darray\\[text\\]\".*return_type: \"sview\".*effects: \"Process.Run\".*errors: \"ProcessError\".*opcode: \"$opcode\"" "$registry_file"; then
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
if ! rg -q 'name: "capture_process_result", receiver: "global".*argument_types: "Executable,darray\[text\],sview".*return_type: "ProcessCapture".*effects: "Process.Run".*errors: "ProcessError".*opcode: "CaptureProcessResult"' "$registry_file"; then
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
if ! rg -q 'name: "process_exit_status", receiver: "global".*argument_types: "ProcessCapture".*return_type: "i64".*effects: "".*errors: "".*opcode: "ProcessResultExitStatus"' "$registry_file" || ! rg -q 'name: "process_stdout", receiver: "global".*argument_types: "ProcessCapture".*return_type: "sview".*effects: "".*errors: "".*opcode: "ProcessResultStdout"' "$registry_file" || ! rg -q 'name: "process_stderr", receiver: "global".*argument_types: "ProcessCapture".*return_type: "sview".*effects: "".*errors: "".*opcode: "ProcessResultStderr"' "$registry_file"; then
    printf 'builtin registry audit: process-result accessor rows are incomplete\n' >&2
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
if ! rg -q 'def registry_remove_path_requires_a_nominal_path\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa" || ! rg -q 'def registry_move_path_checks_both_nominal_paths\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa" || ! rg -q 'def registry_write_text_requires_a_nominal_path\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa" || ! rg -q 'def registry_write_lines_checks_text_array_elements\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa" || ! rg -q 'def registry_write_bytes_checks_unsigned_byte_elements\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa" || ! rg -q 'def registry_read_text_requires_a_nominal_path\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa" || ! rg -q 'def registry_read_bytes_requires_a_nominal_path\(' "$repo_root/test/semantic/elisascript_semantic_test.elisa"; then
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
if ! rg -q "typed_builtin_spec\(callee_name\)\.return_type" "$lowerer_file"; then
    printf 'builtin registry audit: lowerer has no registry return-type consumer\n' >&2
    exit 1
fi

if ! rg -q 'state\.required_errors\.push\(spec\.errors\)' "$lowerer_file" || \
   ! rg -q 'record_builtin_contract\(registry_spec, state\)' "$lowerer_file"; then
    printf 'builtin registry audit: lowerer has no registry error-row consumer\n' >&2
    exit 1
fi
if ! rg -q 'trim_mode: i64 = 1 if callee_name == "lstrip"' "$lowerer_file" || \
   ! rg -q 'callee_name == "rstrip" else 0' "$lowerer_file"; then
    printf 'builtin registry audit: global trim aliases do not preserve left/right mode metadata\n' >&2
    exit 1
fi
if ! rg -q 'def typed_builtin_result_type' "$lowerer_file" || \
   ! rg -q 'typed_builtin_result_type\(EsBuiltin::typed_builtin_spec\(callee_name\)\)' "$lowerer_file" || \
   ! rg -q 'typed_builtin_result_type\(method_spec\)' "$lowerer_file"; then
    printf 'builtin registry audit: aggregate registry rows do not share lowerer result-shape conversion\n' >&2
    exit 1
fi

if ! rg -q 'scripting_registry_direct_return_type' "$inference_file" || \
   ! rg -q 'registry_return: InferType' "$inference_file"; then
    printf 'builtin registry audit: direct-call inference has no registry return-type adapter\n' >&2
    exit 1
fi
if ! rg -q 'name == "regex"' "$inference_file" || \
   ! rg -q 'name: "Regex"' "$inference_file"; then
    printf 'builtin registry audit: regex typed-literal inference is not nominally preserved\n' >&2
    exit 1
fi

printf 'builtin registry audit: %s global, %s Text, and %s Regex receiver spellings share semantic and lowerer metadata\n' "$(printf '%s\n' "$registry_names" | awk 'NF {count += 1} END {print count + 0}')" "$(printf '%s\n' "$method_names" | awk 'NF {count += 1} END {print count + 0}')" "$(printf '%s\n' "$regex_method_names" | awk 'NF {count += 1} END {print count + 0}')"
