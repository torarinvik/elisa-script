#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
COMPILER_ROOT="${ELISA_COMPILER_ROOT:-}"
if [[ -z "$COMPILER_ROOT" ]]; then
  echo "error: set ELISA_COMPILER_ROOT to an Elisa compiler checkout" >&2
  exit 2
fi
COMPILER_ROOT="$(cd -- "$COMPILER_ROOT" && pwd)"
STAGE1="${ELISA_STAGE1_BIN:-$COMPILER_ROOT/bin/elisac-stage1}"
WRAPPER="${ELISA_COMPILER_WRAPPER:-$COMPILER_ROOT/scripts/elisac_stage1.sh}"
RUNTIME="${ELISA_RUNTIME_OBJ:-$COMPILER_ROOT/build/runtime/elisacore_runtime.o}"
OUT="$ROOT/build/elisapkg"
if [[ ! -x "$WRAPPER" ]]; then
  echo "error: compiler wrapper is not executable: $WRAPPER" >&2
  exit 2
fi
if [[ ! -x "$STAGE1" ]]; then
  echo "error: stage1 compiler is not executable: $STAGE1" >&2
  echo "note: seed the compiler first or set ELISA_STAGE1_BIN" >&2
  exit 2
fi
if [[ ! -f "$RUNTIME" ]]; then
  echo "error: Elisa runtime object is missing: $RUNTIME" >&2
  exit 2
fi

mkdir -p "$ROOT/build"

ELISA_STAGE1_BIN="$STAGE1" \
ELISA_ALLOW_STALE_STAGE1="${ELISA_ALLOW_STALE_STAGE1:-0}" \
ELISA_RUNTIME_OBJ="$RUNTIME" \
  "$WRAPPER" -emit exe -o "$OUT" "$ROOT/src/main.elisa"
echo "built $OUT"
