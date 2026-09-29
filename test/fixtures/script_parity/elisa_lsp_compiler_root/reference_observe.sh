#!/usr/bin/env bash
# Projection only: the original is a sourced function, while Elisascript
# callers consume a typed return value. Never treat this as a replacement for
# the original Bash caller's parent-environment mutation.
set -euo pipefail

source "${BASH_SOURCE[0]%/*}/reference.sh"
normalize_elisa_compiler_root "$1"
printf '%s\n' "$ELISA_COMPILER_ROOT"
