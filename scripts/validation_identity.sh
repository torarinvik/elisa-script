#!/bin/sh

# Resolve the local validation identity and create output directories keyed by
# compiler revision, executable bytes, and validation configuration. This file
# never launches a compiler.
set -eu
umask 077

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
default_compiler="$(CDPATH= cd -- "$script_dir/../../../Go projects/structpy-tree/compiler/bin" && pwd)/elisac"
compiler="${ELISA_LOCAL_COMPILER:-${ELISACORE_BIN:-$default_compiler}}"

case "$compiler" in
    *"/Go projects/structpy-tree/compiler/bin/elisac") ;;
    *)
        echo "validation_identity: refusing compiler outside the pinned StructPy checkout" >&2
        exit 2
        ;;
esac

if [ ! -f "$compiler" ] || [ ! -x "$compiler" ]; then
    echo "validation_identity: compiler is not an executable regular file: $compiler" >&2
    exit 2
fi

compiler_root="$(CDPATH= cd -- "$(dirname -- "$compiler")/../.." && pwd)"
compiler_revision="$(git -C "$compiler_root" rev-parse HEAD 2>/dev/null || true)"
case "$compiler_revision" in
    ''|*[!0-9a-fA-F]*)
        echo "validation_identity: unable to resolve compiler checkout revision" >&2
        exit 125
        ;;
esac

compiler_sha256="$(shasum -a 256 "$compiler" | awk '{print $1}')"
case "$compiler_sha256" in
    ''|*[!0-9a-fA-F]*)
        echo "validation_identity: unable to hash compiler executable" >&2
        exit 125
        ;;
esac

optimization="${ELISASCRIPT_VALIDATION_OPT_LEVEL:-O0}"
target="${ELISASCRIPT_VALIDATION_TARGET:-native}"
mode="${ELISASCRIPT_VALIDATION_MODE:-lowered}"
case "$optimization:$target:$mode" in
    *[!A-Za-z0-9_.:/-]*)
        echo "validation_identity: configuration contains unsupported characters" >&2
        exit 2
        ;;
esac

identity_input="compiler=$compiler_revision\nsha256=$compiler_sha256\nopt=$optimization\ntarget=$target\nmode=$mode"
configuration_key="$(printf '%b' "$identity_input" | shasum -a 256 | awk '{print $1}')"
output_root="${ELISASCRIPT_VALIDATION_OUTPUT_ROOT:-$repo_root/.validation}"
output_dir="$output_root/$configuration_key"
mkdir -p "$output_dir/logs" "$output_dir/artifacts"

printf 'compiler_root=%s\n' "$compiler_root"
printf 'compiler=%s\n' "$compiler"
printf 'compiler_revision=%s\n' "$compiler_revision"
printf 'compiler_sha256=%s\n' "$compiler_sha256"
printf 'optimization=%s\n' "$optimization"
printf 'target=%s\n' "$target"
printf 'mode=%s\n' "$mode"
printf 'configuration_key=%s\n' "$configuration_key"
printf 'output_dir=%s\n' "$output_dir"
printf 'log_dir=%s\n' "$output_dir/logs"
printf 'artifact_dir=%s\n' "$output_dir/artifacts"
