#!/usr/bin/env bash

# Compiler-free audit for atomic file publication state and receipts.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/file_atomic_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture_file="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$ir" "$fixture_file" "$docs" "$ledger" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'file atomic audit: missing %s\n' "$required_file" >&2; exit 1; }
done

rg -q '^module EsFileAtomic:' "$model"
rg -q 'using EsHash' "$model"
rg -q 'include "\.\./runtime/file_atomic_model\.elisa"' "$ir"
for declaration in \
    'const module Limits:' \
    'const enum AtomicFileState of u8' \
    'const enum AtomicFileEvent of u8' \
    'struct AtomicFileIdentity:' \
    'struct AtomicFilePlan:' \
    'struct AtomicFileSession:' \
    'error AtomicFileError:' \
    'def validate_atomic_file_session\(' \
    'def advance_atomic_file\('; do
    rg -q "$declaration" "$model"
done

for boundary in \
    'CONTENT_BYTES' \
    'OBSERVED_BYTES' \
    'APPENDS' \
    'expected_destination: AtomicFileIdentity' \
    'volume_id: u64' \
    'object_id: u64' \
    'owner_token: u64' \
    'parent_identity: u64' \
    'stage_close_acknowledged: bool' \
    'atomic_file_trim_trailing_separators' \
    'atomic_file_identity_equal' \
    'AtomicFileState.Unchanged' \
    'AtomicFileState.UnchangedPendingCleanup' \
    'AtomicFileState.PublishedUncertain' \
    'AtomicFileState.RolledBackPendingCleanup' \
    'AtomicFileState.RolledBack' \
    'AtomicFileState.FailedPendingCleanup' \
    'AtomicFileState.CancelledPendingCleanup' \
    'AtomicFileEvent.StageReady' \
    'AtomicFileEvent.Compare' \
    'AtomicFileEvent.PublishUncertain' \
    'AtomicFileEvent.BeginRestore' \
    'AtomicFileEvent.RestoreAck' \
    'AtomicFileEvent.CleanupAck' \
    'AtomicFileError.DestinationChanged' \
    'AtomicFileError.EmbeddedNul' \
    'AtomicFileError.RestoreNotProven' \
    'AtomicFileError.PathCollision' \
    'AtomicFileError.ParentInvalid' \
    'identity.size != session.staged_bytes' \
    'exact_contents_equal' \
    'session.contents_equal <- exact_contents_equal' \
    'published_identity <- identity' \
    'session.state <- AtomicFileState.UnchangedPendingCleanup if session.contents_equal' \
    'session.state == AtomicFileState.Committing' \
    'session.plan.require_directory_sync and not session.directory_sync_acknowledged' \
    'session.state <- AtomicFileState.PublishedUncertain' \
    'session.state <- AtomicFileState.RolledBack'; do
    rg -q "$boundary" "$model"
done

for fixture_pattern in \
    'using EsFileAtomic' \
    'typed_file_atomic_contract_preserves_noop_and_uncertain_recovery' \
    'destination_race_rejected' \
    'restore_proof_rejected' \
    'embedded_nul' \
    'unchanged_commit_rejected' \
    'CleanupAck' \
    'empty_plan' \
    'forged_ready' \
    'AtomicFileState.Unchanged' \
    'AtomicFileState.PublishedUncertain' \
    'AtomicFileState.RolledBack'; do
    rg -q "$fixture_pattern" "$fixture_file"
done

rg -q 'EsFileAtomic::AtomicFileSession' "$docs"
rg -q 'ES-FS-007' "$ledger"
rg -q 'Atomic publication boundary' "$plan"

printf 'file atomic audit: bounded staging, unchanged no-op, destination identity, and uncertain publication receipts are present\n'
