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
