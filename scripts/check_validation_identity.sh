#!/bin/sh

# Compiler-free audit for the keyed local validation identity boundary.
set -eu

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
helper="$script_dir/validation_identity.sh"
docs="$script_dir/../docs/development.md"
baseline="$script_dir/../docs/validation-baseline.md"

[ -x "$helper" ]
rg -q 'ELISA_LOCAL_COMPILER:-\$\{ELISACORE_BIN:-\$expected_compiler_path\}' "$helper"
rg -q 'Go projects/structpy-tree/compiler/bin/elisac' "$helper"
rg -Fq 'expected_compiler_path="/Users/torarinvikbjarko/Documents/Coding Projects/Go projects/structpy-tree/compiler/bin/elisac"' "$helper"
rg -Fq 'if [ "$compiler" != "$expected_compiler_path" ]; then' "$helper"
rg -q 'suffix match is insufficient' "$helper"
rg -q 'compiler symlinks are not accepted' "$helper"
rg -q 'git -C "\$compiler_root" rev-parse HEAD' "$helper"
rg -q 'git -C "\$compiler_root" status --porcelain --untracked-files=normal' "$helper"
rg -Fq 'go version -m "$compiler"' "$helper"
rg -Fq 'compiler_binary_revision" != "$compiler_revision"' "$helper"
rg -Fq 'compiler_binary_modified" != "false"' "$helper"
rg -Fq 'compiler_binary_modified=%s\n' "$helper"
rg -q 'shasum -a 256 "\$compiler"' "$helper"
rg -Fq 'compiler_binary_revision=%s\n' "$helper"
rg -q 'configuration_key=' "$helper"
rg -q 'output_dir=' "$helper"
rg -q 'ELISASCRIPT_VALIDATION_OUTPUT_ROOT' "$helper"
rg -q 'configuration_key|keyed' "$docs"
rg -q 'Compiler executable SHA-256' "$baseline"
printf '%s\n' 'validation identity audit: clean pinned source, matching embedded binary revision, executable hash, and keyed outputs are present'
