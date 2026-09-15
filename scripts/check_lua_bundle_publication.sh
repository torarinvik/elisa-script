#!/usr/bin/env bash

# Compiler-free audit for the pure W04 Lua metadata publication boundary.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/lua_bundle_publication_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
plan="$repo_root/IMPLEMENTATION_PLAN.md"
tasks="$repo_root/SCRIPT_TASKS.md"

for required_file in "$model" "$ir" "$fixture" "$plan" "$tasks"; do
    [[ -f "$required_file" ]] || { printf 'lua bundle publication audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    '^module EsLuaBundlePublication:' \
    'const module Limits:' \
    'const enum PublicationState' \
    'const enum PublicationEvent' \
    'struct PublicationRequest:' \
    'struct PublicationSession:' \
    'error PublicationError:' \
    'def validate_publication' \
    'def advance_publication'; do
    rg -q "$declaration" "$model"
done

for boundary in \
    'StageAdmissionMissing' \
    'DescriptorOwnershipMissing' \
    'WriteLimitExceeded' \
    'DirectorySyncMissing' \
    'DestinationNotPreserved' \
    'PublicationEvent.StageCreated' \
    'PublicationEvent.PublishAck'; do
    rg -q "$boundary" "$model" "$fixture"
done

rg -q 'include "\.\./runtime/lua_bundle_publication_model\.elisa"' "$ir"
rg -q 'using EsLuaBundlePublication' "$fixture"
rg -q 'typed_lua_bundle_publication_requires_exclusive_staging' "$fixture"
rg -q 'W04' "$plan" "$tasks"

printf 'lua bundle publication audit: exclusive sibling staging, descriptor ownership, bounded writes, directory sync, and failure preservation are present\n'
