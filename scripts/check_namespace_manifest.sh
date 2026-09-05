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
