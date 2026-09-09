#!/usr/bin/env bash

# Compiler-free audit for bounded recursive copy/remove planning.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/directory_mutation_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture_file="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$ir" "$fixture_file" "$docs" "$ledger" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'directory mutation audit: missing %s\n' "$required_file" >&2; exit 1; }
done

rg -q '^module EsDirectoryMutation:' "$model"
rg -q 'include "\.\./runtime/directory_mutation_model\.elisa"' "$ir"
for declaration in \
    'const enum DirectoryMutationOperation of u8' \
    'const enum DirectoryMutationSymlinkPolicy of u8' \
    'const enum DirectoryMutationFailureMode of u8' \
    'const enum DirectoryMutationEntryState of u8' \
    'struct DirectoryMutationPolicy:' \
    'struct DirectoryMutationEntry:' \
    'struct DirectoryMutationSession:' \
    'error DirectoryMutationError:' \
    'def validate_directory_mutation\(' \
    'def advance_directory_mutation\('; do
    rg -q "$declaration" "$model"
done

for boundary in \
    'DIRECTORY_MUTATION_MAX_ENTRIES' \
    'DIRECTORY_MUTATION_MAX_DEPTH' \
    'DIRECTORY_MUTATION_MAX_IDENTITIES' \
    'DIRECTORY_MUTATION_MAX_BYTES' \
    'directory_mutation_identity_index' \
    'DirectoryMutationSymlinkPolicy.Preserve' \
    'DirectoryMutationSymlinkPolicy.Follow' \
    'DirectoryMutationSymlinkPolicy.Skip' \
    'DirectoryMutationSymlinkPolicy.Reject' \
    'DirectoryMutationFailureMode.Collect' \
    'DirectoryMutationEvent.Enter' \
    'DirectoryMutationEvent.Leave' \
    'DirectoryMutationError.DuplicateIdentity' \
    'DirectoryMutationError.DestinationCollision' \
    'accounted_bytes > session.policy.max_bytes' \
    'entry.bytes > session.policy.max_bytes - accounted_bytes' \
    'directory_mutation_destination_nested' \
    'DirectoryMutationState.Planned and' \
    'DirectoryMutationState.Completed' \
    'DirectoryMutationState.Cancelled' \
    'session\.identities\[index\] != entry\.identity' \
    'DirectoryMutationError.FailureLimitExceeded' \
    'DirectoryMutationError.CancelNotReady'; do
    rg -q "$boundary" "$model"
done

for fixture_pattern in \
    'using EsDirectoryMutation' \
    'typed_directory_mutation_contract_tracks_copy_remove_and_partial_failure' \
    'DirectoryMutationOperation.Copy' \
    'DirectoryMutationOperation.Remove' \
    'DirectoryMutationError.DuplicateIdentity' \
    'DirectoryMutationEvent.Failure' \
    'DirectoryMutationEvent.Cancel' \
    'DirectoryMutationError.DestinationCollision' \
    'DirectoryMutationError.ActiveScope'; do
    rg -q "$fixture_pattern" "$fixture_file"
done
rg -Fq 'nested_destination' "$fixture_file"

rg -q 'EsDirectoryMutation::DirectoryMutationSession' "$docs"
rg -q 'ES-FS-005' "$ledger"
rg -q 'P9 recursive mutation follow-up' "$plan"

printf 'directory mutation audit: bounded copy/remove planning, symlink policy, and partial-failure accounting are present\n'
