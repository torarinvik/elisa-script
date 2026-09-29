#!/bin/sh

# Static namespace audit for Elisascript-owned source. This does not invoke the
# compiler; it checks the declaration surface that must remain qualified before
# a build manifest or compiler validation run is assembled.

set -u

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
if [ "$#" -gt 2 ]; then
    echo "usage: check_namespace_manifest.sh [source-root [parser-token-source]]" >&2
    exit 2
fi

source_root="${1:-$script_dir/../src}"
parser_tokens_file="${2:-$script_dir/../vendor/elisa-compiler/src/parser/parser_tokens.elisa}"
candidate_file="$script_dir/check_namespace_manifest.elisascript"
bounded_reader="$script_dir/../src/runtime/bounded_text_posix.elisa"
if [ ! -d "$source_root" ]; then
    echo "check_namespace_manifest: source root does not exist: $source_root" >&2
    exit 2
fi

# Pin the shared reader's memory-safety contract independently of runtime
# parity: the size preflight is not a substitute for an actually bounded read.
if [ ! -f "$candidate_file" ]; then
    echo "check_namespace_manifest: Elisascript candidate is missing" >&2
    exit 1
fi
if [ ! -f "$bounded_reader" ]; then
    echo "check_namespace_manifest: shared bounded text reader is missing" >&2
    exit 1
fi
if ! grep -F 'include "../src/runtime/bounded_text_posix.elisa"' "$candidate_file" >/dev/null 2>&1 || ! grep -F 'EsBoundedText::read_utf8(input_path, maximum_bytes)' "$candidate_file" >/dev/null 2>&1; then
    echo "check_namespace_manifest: candidate does not use the shared bounded text reader" >&2
    exit 1
fi
for bounded_read_invariant in \
    'MAX_BYTES: usize = 16777216' \
    'Limits::READ_CHUNK_BYTES' \
    'maximum_bytes - bytes.count' \
    'probe_capacity: usize = remaining + 1' \
    'DarwinOpenFlags::NONBLOCK' \
    'elisascript_posix_fstat' \
    'stable_file(opened, final_opened)' \
    'text_is_valid_utf8'; do
    if ! grep -F "$bounded_read_invariant" "$bounded_reader" >/dev/null 2>&1; then
        echo "check_namespace_manifest: shared source reader omits bounded-read invariant: $bounded_read_invariant" >&2
        exit 1
    fi
done
if grep -F 'read_text(' "$candidate_file" "$bounded_reader" >/dev/null 2>&1; then
    echo "check_namespace_manifest: source read uses unbounded read_text" >&2
    exit 1
fi
if ! grep -F 'capture_process_result_with_environment(exe"rg", file_list_arguments' "$candidate_file" >/dev/null 2>&1; then
    echo "check_namespace_manifest: candidate does not use the bounded ripgrep file-list process" >&2
    exit 1
fi
for source_discovery_invariant in \
    '["--files", "--null", "--glob", "*.elisa", root_text]' \
    'FILES: usize = 4096' \
    'discovered_paths.count >= Limits::FILES' \
    'FILE_LIST_BYTES: usize = 16777216' \
    'ENUMERATION_TIMEOUT_MICROS: i64 = 30000000' \
    'Limits::FILE_LIST_BYTES.i64()' \
    'file_list.status != 0 and file_list.status != 1' \
    'sview_at(file_list_output, cursor) == 0u8' \
    'record_start != len(file_list_output)'; do
    if ! grep -F "$source_discovery_invariant" "$candidate_file" >/dev/null 2>&1; then
        echo "check_namespace_manifest: source discovery omits bounded NUL-list invariant: $source_discovery_invariant" >&2
        exit 1
    fi
done
if grep -F '.iterdir()' "$candidate_file" >/dev/null 2>&1; then
    echo "check_namespace_manifest: source discovery bypasses ripgrep ignore rules" >&2
    exit 1
fi

module_names="$(rg --no-filename '^module [A-Za-z_][A-Za-z0-9_]*:' "$source_root" -g '*.elisa' 2>/dev/null | awk '{name=$2; sub(/:$/, "", name); print name}' | sort)"
duplicate_names="$(printf '%s\n' "$module_names" | awk 'seen[$0]++ {print $0}' | sort -u)"
if [ -n "$duplicate_names" ]; then
    echo "check_namespace_manifest: duplicate module declarations:" >&2
    printf '%s\n' "$duplicate_names" >&2
    exit 1
fi

extension_names="$(rg --no-filename '^extend [A-Za-z_][A-Za-z0-9_]*:' "$source_root" -g '*.elisa' 2>/dev/null | awk '{name=$2; sub(/:$/, "", name); print name}' | sort -u)"
for extension in $extension_names; do
    if ! printf '%s\n' "$module_names" | grep -F -x "$extension" >/dev/null 2>&1; then
        echo "check_namespace_manifest: extension targets undeclared module: $extension" >&2
        exit 1
    fi
done

# `using` is a namespace import, not a spelling escape hatch. Every imported
# Elisascript module must be declared in this source tree; only the two
# vendored frontend namespaces are allowed as external dependencies. This
# catches typoed imports before they can silently bind a global or a private
# implementation fragment.
using_names="$(rg --no-filename '^using [A-Za-z_][A-Za-z0-9_]*$' "$source_root" -g '*.elisa' 2>/dev/null | awk '{print $2}' | sort -u)"
for using_name in $using_names; do
    if printf '%s\n' "$module_names" | grep -F -x "$using_name" >/dev/null 2>&1; then
        continue
    fi
    case "$using_name" in
        Ast|Lexer)
            continue
            ;;
        *)
            echo "check_namespace_manifest: using imports undeclared module: $using_name" >&2
            exit 1
            ;;
    esac
done

# POSIX ABI declarations are implementation details of the qualified runtime
# namespace. Keep every link-name/extern pair inside an `EsRuntime` extension
# and its `private:` section, and reject direct `_impl` calls from higher-level
# source. This is deliberately lexical: it catches namespace leakage before a
# compiler or platform linker is involved.
runtime_root="$source_root/runtime"
if [ -d "$runtime_root" ]; then
    if ! rg --files "$runtime_root" -g '*.elisa' 2>/dev/null | sort | while IFS= read -r runtime_file; do
        if rg -q '^\s*(extern|@link_name)' "$runtime_file" && ! rg -q '^extend EsRuntime:' "$runtime_file"; then
            echo "check_namespace_manifest: POSIX ABI declaration is outside EsRuntime: $runtime_file" >&2
            exit 1
        fi
        if ! awk '
            /^[[:space:]]+private:/ { in_private=1; next }
            /^[[:space:]]+public:/ { in_private=0; next }
            /^[[:space:]]*(extern|@link_name)/ && !in_private {
                print FILENAME ": POSIX ABI declaration is not private at line " FNR
                bad=1
            }
            END { exit bad ? 1 : 0 }
        ' "$runtime_file"; then
            exit 1
        fi
    done; then
        exit 1
    fi
    leaked_impls="$(rg -n --glob '*.elisa' 'elisascript_posix_[A-Za-z0-9_]+_impl\(' "$source_root" 2>/dev/null | awk -F: '$1 !~ /\/runtime\//' || true)"
    if [ -n "$leaked_impls" ]; then
        echo "check_namespace_manifest: private POSIX _impl call leaked outside runtime:" >&2
        printf '%s\n' "$leaked_impls" >&2
        exit 1
    fi
fi

# Resolve every literal include relative to the file that declares it. This
# remains compiler-free, but prevents a copied source tree from silently
# depending on a missing or accidentally renamed module fragment.
if ! rg --files "$source_root" -g '*.elisa' 2>/dev/null | sort | while IFS= read -r source_file; do
    source_dir="$(dirname -- "$source_file")"
    includes="$(sed -n 's/^[[:space:]]*include[[:space:]]*"\([^"]*\)".*/\1/p' "$source_file")"
    if [ -n "$includes" ]; then
        printf '%s\n' "$includes" | while IFS= read -r include_path; do
            [ -n "$include_path" ] || continue
            include_target="$source_dir/$include_path"
            if [ ! -f "$include_target" ]; then
                echo "check_namespace_manifest: missing include: $source_file -> $include_path" >&2
                exit 1
            fi
        done
        include_status=$?
        [ "$include_status" -eq 0 ] || exit "$include_status"
    fi
done; then
    exit 1
fi

# Keep the host diagnostic renderer exhaustive when the verifier adds a new
# issue kind. The enum and renderer intentionally live in different modules,
# so this source-level check prevents a new variant from silently collapsing
# to `UnknownBytecodeIssue`.
issue_kinds="$(sed -n '/^[[:space:]]*const enum IssueKind of u8:/,/^[[:space:]]*struct Issue:/p' "$source_root/ir/ir_model.elisa" | sed -n 's/^[[:space:]]*\([A-Za-z_][A-Za-z0-9_]*\)[[:space:]]*$/\1/p')"
issue_renderer="$(sed -n '/^[[:space:]]*def bytecode_issue_detail/,/^[[:space:]]*def runtime_error_detail/p' "$source_root/driver/elisascript.elisa")"
for issue_kind in $issue_kinds; do
    if ! printf '%s\n' "$issue_renderer" | grep -F "IssueKind.$issue_kind" >/dev/null 2>&1; then
        echo "check_namespace_manifest: bytecode diagnostic renderer omits IssueKind.$issue_kind" >&2
        exit 1
    fi
done

lower_issue_kinds="$(sed -n '/^[[:space:]]*const enum LowerIssueKind of u8:/,/^[[:space:]]*struct LowerIssue:/p' "$source_root/ir/lower_ast.elisa" | sed -n 's/^[[:space:]]*\([A-Za-z_][A-Za-z0-9_]*\)[[:space:]]*$/\1/p')"
lower_issue_renderer="$(sed -n '/^[[:space:]]*def lower_issue_detail/,/^[[:space:]]*def entrypoint_error_detail/p' "$source_root/driver/elisascript.elisa")"
for lower_issue_kind in $lower_issue_kinds; do
    if ! printf '%s\n' "$lower_issue_renderer" | grep -F "LowerIssueKind.$lower_issue_kind" >/dev/null 2>&1; then
        echo "check_namespace_manifest: source diagnostic renderer omits LowerIssueKind.$lower_issue_kind" >&2
        exit 1
    fi
done

# Diagnostic records are reused by the launcher; require one complete reset
# operation before the file-backed pipeline so stale phase/payload fields
# cannot leak between invocations.
runner_source="$source_root/ir/runner.elisa"
if [ ! -f "$runner_source" ]; then
    echo "check_namespace_manifest: runner source is missing: $runner_source" >&2
    exit 1
fi
if ! rg -q '^        def elisascript_program_diagnostic_reset\(' "$runner_source" || ! rg -q 'elisascript_program_diagnostic_reset\(result\)' "$runner_source"; then
    echo "check_namespace_manifest: diagnostic pipeline is missing its complete reset operation" >&2
    exit 1
fi
diagnostic_fields="$(awk '
    /^        struct ElisascriptProgramDiagnostic:/ { inside=1; next }
    inside && /^[[:space:]]*$/ { exit }
    inside && /^            [a-z_][a-z0-9_]*:/ {
        field=$1
        sub(/:$/, "", field)
        print field
    }
' "$runner_source")"
reset_start="$(rg -n '^        def elisascript_program_diagnostic_reset' "$runner_source" | cut -d: -f1)"
reset_end="$(rg -n '^        # Parse argv after the launcher name' "$runner_source" | cut -d: -f1)"
reset_body="$(sed -n "${reset_start},${reset_end}p" "$runner_source")"
for diagnostic_field in $diagnostic_fields; do
    if ! printf '%s\n' "$reset_body" | grep -Eq "result\\.${diagnostic_field}([[:space:]]|<-|:)"; then
        echo "check_namespace_manifest: diagnostic reset omits $diagnostic_field" >&2
        exit 1
    fi
done

# Parser diagnostics are rendered by the host driver rather than flattened to
# one generic parse failure. Keep this small frontend enum exhaustive so a new
# parser failure category cannot silently lose its typed spelling.
if [ ! -f "$parser_tokens_file" ]; then
    echo "check_namespace_manifest: parser token source is missing: $parser_tokens_file" >&2
    exit 1
fi
parse_error_kinds="$(sed -n '/^[[:space:]]*enum ParseErrorKind:/,/^[[:space:]]*struct ParseError:/p' "$parser_tokens_file" | sed -n 's/^[[:space:]]*\([A-Za-z_][A-Za-z0-9_]*\)[[:space:]]*$/\1/p')"
parse_error_renderer="$(sed -n '/^[[:space:]]*def parse_error_detail/,/^[[:space:]]*def report_program_failure/p' "$source_root/driver/elisascript.elisa")"
for parse_error_kind in $parse_error_kinds; do
    if ! printf '%s\n' "$parse_error_renderer" | grep -F "ParseErrorKind.$parse_error_kind" >/dev/null 2>&1; then
        echo "check_namespace_manifest: parse diagnostic renderer omits ParseErrorKind.$parse_error_kind" >&2
        exit 1
    fi
done

for expected in EsArtifactCache EsBytecode EsDifferential EsDriver EsIr EsIrArtifact EsRuntime; do
    if ! printf '%s\n' "$module_names" | grep -F -x "$expected" >/dev/null 2>&1; then
        echo "check_namespace_manifest: required module is missing: $expected" >&2
        exit 1
    fi
done

printf 'module\tfiles\tpublic_sections\tprivate_sections\n'
for module in $module_names; do
    files="$(rg -l "^(module|extend) $module:" "$source_root" -g '*.elisa' 2>/dev/null | sort | tr '\n' ';')"
    public_count="$(rg -l "^(module|extend) $module:" "$source_root" -g '*.elisa' 2>/dev/null | while IFS= read -r namespace_file; do if rg -q '^[[:space:]]+public:' "$namespace_file"; then printf '%s\n' x; fi; done | wc -l | tr -d '[:space:]')"
    private_count="$(rg -l "^(module|extend) $module:" "$source_root" -g '*.elisa' 2>/dev/null | while IFS= read -r namespace_file; do if rg -q '^[[:space:]]+private:' "$namespace_file"; then printf '%s\n' x; fi; done | wc -l | tr -d '[:space:]')"
    printf '%s\t%s\t%s\t%s\n' "$module" "$files" "$public_count" "$private_count"
done
