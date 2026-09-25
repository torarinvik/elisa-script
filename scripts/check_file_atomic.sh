#!/usr/bin/env bash

# Compiler-free audit for atomic file publication state and receipts.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/file_atomic_model.elisa"
adapter="$repo_root/src/runtime/file_atomic_posix.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture_file="$repo_root/test/ir/elisascript_ir_test.elisa"
runtime_fixture="$repo_root/test/runtime/file_atomic_model_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"

for required_file in "$model" "$adapter" "$ir" "$fixture_file" "$runtime_fixture" "$docs" "$ledger"; do
    [[ -f "$required_file" ]] || { printf 'file atomic audit: missing %s\n' "$required_file" >&2; exit 1; }
done

rg -q '^module EsFileAtomic:' "$model"
rg -q 'using EsHash' "$model"
rg -q 'include "\.\./runtime/file_atomic_model\.elisa"' "$ir"
rg -q '^module EsFileAtomicPosix:' "$adapter"
rg -q 'include "\.\./runtime/file_atomic_posix\.elisa"' "$ir"
rg -q 'def observe_atomic_file_at\(' "$adapter"
rg -q 'def atomic_file_bytes_equal_at\(' "$adapter"
rg -q 'atomic_file_posix_bytes_equal\(observed, expected\)' "$adapter"
rg -q 'left\[index\] != right\[index\]' "$adapter"
rg -q 'parent_info.device != stage_info.device' "$adapter"
rg -q 'parent_matches\(parent_info, parent_after\)' "$adapter"
rg -q 'StageIdentityChanged if not atomic_file_posix_same_inode\(stage_info, stage_after\)' "$adapter"
rg -q 'read_regular_file_at\(a, parent_fd, leaf_name, byte_limit\)' "$adapter"
rg -q 'canonical_bytes_sha256\(bytes\)' "$adapter"
rg -q 'parent_descriptor_token: u64' "$adapter"
rg -q 'atomic_file_posix_parent_matches\(parent_before, parent_after\)' "$adapter"
rg -q 'ENOENT: i32 = 2' "$adapter"
rg -q 'DarwinAtFlag::SYMLINK_NOFOLLOW' "$adapter"
rg -q 'before.size.usize\(\) > byte_limit' "$adapter"
rg -q 'destination <- AtomicFileIdentity' "$adapter"
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

for payload_rule in \
    'def atomic_file_identity_is_default(' \
    'def atomic_file_event_payload_valid(' \
    'AtomicFileError.InvalidEventPayload' \
    'not atomic_file_event_payload_valid(event, identity, exact_contents_equal, appended_bytes)'; do
    rg -Fq "$payload_rule" "$model"
done

for boundary in \
    'CONTENT_BYTES' \
    'OBSERVED_BYTES' \
    'APPENDS' \
    'expected_destination: AtomicFileIdentity' \
    'restore_source_identity: AtomicFileIdentity' \
    'volume_id: u64' \
    'object_id: u64' \
    'owner_token: u64' \
    'parent_identity: u64' \
    'stage_close_acknowledged: bool' \
    'atomic_file_trim_trailing_separators' \
    'atomic_file_paths_share_parent' \
    'atomic_file_path_leaf_valid' \
    'ParentPathMismatch' \
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

rg -Fq 'return sview_at(path, length - 1) != 47' "$model"

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

rg -Fq 'atomic_file_events_reject_irrelevant_payloads_without_mutation' "$runtime_fixture"
rg -Fq 'atomic_file_paths_must_name_file_entries' "$runtime_fixture"
rg -Fq 'atomic_file_stage_and_backup_must_be_siblings' "$runtime_fixture"
rg -Fq 'atomic_file_commit_ack_requires_directory_sync_receipt' "$runtime_fixture"
rg -Fq 'atomic_file_restore_requires_a_known_current_destination' "$runtime_fixture"
rg -Fq 'atomic_file_posix_observation_rejects_invalid_parent' "$runtime_fixture"
rg -Fq 'append_identity_rejected' "$runtime_fixture"
rg -Fq 'begin_bytes_rejected' "$runtime_fixture"
rg -Fq 'premature_ack_rejected' "$runtime_fixture"

printf 'file atomic source audit: transition model and destination observation seam are present; publication adapter and runtime parity remain open\n'
