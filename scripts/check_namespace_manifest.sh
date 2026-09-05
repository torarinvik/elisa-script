#!/bin/sh

# Static namespace audit for Elisascript-owned source. This does not invoke the
# compiler; it checks the declaration surface that must remain qualified before
# a build manifest or compiler validation run is assembled.

set -u

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
source_root="${1:-$script_dir/../src}"
if [ ! -d "$source_root" ]; then
    echo "check_namespace_manifest: source root does not exist: $source_root" >&2
    exit 2
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

# Parser diagnostics are rendered by the host driver rather than flattened to
# one generic parse failure. Keep this small frontend enum exhaustive so a new
# parser failure category cannot silently lose its typed spelling.
parser_tokens_file="$script_dir/../vendor/elisa-compiler/src/parser/parser_tokens.elisa"
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

for expected in EsBytecode EsDifferential EsDriver EsIr EsIrArtifact EsRuntime; do
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
