#!/bin/sh

# Compiler-free audit for the keyed local validation identity boundary.
set -eu

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
helper="$script_dir/validation_identity.sh"
docs="$script_dir/../docs/development.md"
baseline="$script_dir/../docs/validation-baseline.md"

[ -x "$helper" ]
rg -q 'ELISA_LOCAL_COMPILER:-\$\{ELISACORE_BIN:-\$default_compiler\}' "$helper"
rg -q 'Go projects/structpy-tree/compiler/bin/elisac' "$helper"
rg -q 'git -C "\$compiler_root" rev-parse HEAD' "$helper"
rg -q 'shasum -a 256 "\$compiler"' "$helper"
rg -q 'configuration_key=' "$helper"
rg -q 'output_dir=' "$helper"
rg -q 'ELISASCRIPT_VALIDATION_OUTPUT_ROOT' "$helper"
rg -q 'configuration_key|keyed' "$docs"
rg -q 'Compiler executable SHA-256' "$baseline"
printf '%s\n' 'validation identity audit: pinned compiler, revision/hash identity, and keyed outputs are present'
