#!/usr/bin/env bash

# Compiler-free audit for explicit module visibility and resolution state.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/module_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"

for required_file in "$model" "$ir" "$fixture" "$docs"; do
    [[ -f "$required_file" ]] || { printf 'module model audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    'module EsModule:' \
    'MODULE_MAX_NAME_BYTES' \
    'MODULE_MAX_PATH_BYTES' \
    'MODULE_MAX_IMPORTS' \
    'MODULE_MAX_SYMBOLS' \
    'MODULE_MAX_MODULES' \
    'const enum ModuleVisibility of u8:' \
    'const enum ModuleResolutionState of u8:' \
    'const enum ModuleResolutionEvent of u8:' \
    'struct ModuleImport:' \
    'struct ModuleDescriptor:' \
    'struct ModuleGraph:' \
    'struct ModuleResolutionStack:' \
    'error ModuleContractError:' \
    'def validate_module_descriptor(' \
    'def validate_module_graph(' \
    'def module_graph_acyclic(' \
    'def advance_module_resolution(' \
    'def module_resolution_stack_push(' \
    'def module_resolution_stack_pop('; do
    rg -Fq "$declaration" "$model"
done

for boundary in \
    'module_visibility_valid' \
    'module_resolution_state_valid' \
    'DuplicateImport' \
    'DuplicateModule' \
    'ModuleNotFound' \
    'module_graph_acyclic' \
    'DuplicateSymbol' \
    'PublicPrivateCollision' \
    'ResolutionCycle' \
    'ResolutionNotReady' \
    'module.state == ModuleResolutionState.Resolved' \
    'ModuleResolutionEvent.ImportResolved'; do
    rg -Fq "$boundary" "$model"
done

rg -Fq 'include "../runtime/module_model.elisa"' "$ir"
for fixture_pattern in \
    'typed_module_graph_contract_is_private_by_default_and_cycle_safe' \
    'ModuleVisibility.Public' \
    'ModuleContractError.ResolutionCycle' \
    'ModuleContractError.PublicPrivateCollision' \
    'ModuleContractError.ModuleNotFound'; do
    rg -Fq "$fixture_pattern" "$fixture"
done

rg -Fq '`EsModule`' "$docs"

printf 'module model audit: explicit visibility, bounded imports, resolution states, and cycle rejection are present\n'
