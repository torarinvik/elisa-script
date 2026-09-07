#!/usr/bin/env bash

# Compiler-free audit for bounded recursive directory traversal.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/directory_tree_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture_file="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$ir" "$fixture_file" "$docs" "$ledger" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'directory tree audit: missing %s\n' "$required_file" >&2; exit 1; }
done

rg -q '^module EsDirectoryTree:' "$model"
rg -q 'include "\.\./runtime/directory_tree_model\.elisa"' "$ir"
for declaration in \
    'const enum DirectoryTreeSymlinkPolicy of u8' \
    'const enum DirectoryTreeFailureMode of u8' \
    'const enum DirectoryTreeEntryKind of u8' \
    'const enum DirectoryTreeState of u8' \
    'const enum DirectoryTreeEvent of u8' \
    'struct DirectoryTreePolicy:' \
    'struct DirectoryTreeEntry:' \
    'struct DirectoryTreeSession:' \
    'error DirectoryTreeError:' \
    'def validate_directory_tree\(' \
    'def advance_directory_tree\('; do
    rg -q "$declaration" "$model"
done

for boundary in \
    'DIRECTORY_TREE_MAX_DEPTH' \
    'DIRECTORY_TREE_MAX_ENTRIES' \
    'DIRECTORY_TREE_MAX_BYTES' \
    'DIRECTORY_TREE_MAX_IDENTITIES' \
    'directory_tree_identity_index' \
    'DirectoryTreeSymlinkPolicy.DoNotFollow' \
    'DirectoryTreeFailureMode.Collect' \
    'DirectoryTreeError.CycleDetected' \
    'DirectoryTreeError.DepthLimitExceeded' \
    'DirectoryTreeError.SymlinkTraversalDenied' \
    'DirectoryTreeEvent.Descend' \
    'DirectoryTreeEvent.Cancel' \
    'DirectoryTreeState.Complete'; do
    rg -q "$boundary" "$model"
done

for fixture_pattern in \
    'using EsDirectoryTree' \
    'typed_directory_tree_contract_bounds_depth_and_cycles' \
    'DirectoryTreeEvent.Descend' \
    'DirectoryTreeEvent.Complete' \
    'DirectoryTreeError.CycleDetected' \
    'DirectoryTreeError.NotDirectory'; do
    rg -q "$fixture_pattern" "$fixture_file"
done

rg -q 'EsDirectoryTree::DirectoryTreeSession' "$docs"
rg -q 'ES-FS-003' "$ledger"
rg -q 'P09 recursive-tree follow-up' "$plan"

printf 'directory tree audit: bounded depth, identity cycle checks, symlink policy, and cancellation are present\n'
