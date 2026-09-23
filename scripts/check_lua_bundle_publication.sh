#!/usr/bin/env bash

# Compiler-free audit for the pure W04 Lua metadata publication boundary.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/lua_bundle_publication_model.elisa"
file_bridge="$repo_root/src/runtime/file_posix.elisa"
posix_adapter="$repo_root/src/runtime/lua_bundle_publication_posix.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
rename_failure_fixture="$repo_root/test/driver/lua_bundle_publication_rename_failure.elisascript"
close_uncertain_fixture="$repo_root/test/driver/lua_bundle_publication_close_uncertain.elisascript"
write_failure_fixture="$repo_root/test/driver/lua_bundle_publication_write_failure.elisascript"
stage_remove_uncertain_fixture="$repo_root/test/driver/lua_bundle_publication_stage_remove_uncertain.elisascript"

for required_file in "$model" "$file_bridge" "$posix_adapter" "$ir" "$fixture" "$rename_failure_fixture" "$close_uncertain_fixture" "$write_failure_fixture" "$stage_remove_uncertain_fixture"; do
    [[ -f "$required_file" ]] || { printf 'lua bundle publication audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    '^module EsLuaBundlePublication:' \
    'const module Limits:' \
    'const enum PublicationState' \
    'const enum PublicationEvent' \
    'struct PublicationRequest:' \
    'struct PublicationParentProof:' \
    'struct PublicationStagingProof:' \
    'struct PublicationSession:' \
    'error PublicationError:' \
    'def validate_publication' \
    'def advance_publication'; do
    rg -q "$declaration" "$model"
done

for boundary in \
    'StageAdmissionMissing' \
    'DescriptorOwnershipMissing' \
    'ParentIdentityMissing' \
    'StagingIdentityMissing' \
    'StagingIdentityInvalid' \
    'OwnerMismatch' \
    'ParentMismatch' \
    'DescriptorCollision' \
    'parent_device' \
    'parent_inode' \
    'descriptor_token' \
    'parent_descriptor_owned' \
    'parent_descriptor_closed' \
    'publication_parent_proof_empty' \
    'publication_identity_proofs_valid' \
    'WriteLimitExceeded' \
    'StageRemovalMissing' \
    'DirectorySyncMissing' \
    'DestinationNotPreserved' \
    'PublishedUncertain' \
    'PublicationEvent.OutcomeUnknown' \
    'PublicationUncertain' \
    'PublicationEvent.StageCreated' \
    'PublicationEvent.Close' \
    'session.state != PublicationState.Publishing' \
    'PublicationError.PublishNotReady' \
    'PublicationEvent.PublishAck'; do
    rg -q "$boundary" "$model" "$fixture"
done

rg -q 'PublicationEvent.PublishFailed' "$rename_failure_fixture"
rg -q 'confirmed_rename_failure_is_retryable_as_failure' "$rename_failure_fixture"
rg -q 'session.destination_preserved_on_failure' "$rename_failure_fixture"
rg -q 'PublicationState.CleanupUncertain' "$model" "$close_uncertain_fixture"
rg -q 'parent_descriptor_close_uncertain' "$close_uncertain_fixture"
rg -q 'stage_close_succeeded: true, parent_close_succeeded: false' "$close_uncertain_fixture"
rg -q 'session.descriptor_owned or session.parent_descriptor_owned or session.parent_descriptor_closed' "$close_uncertain_fixture"
rg -q 'PublicationError.CleanupUncertain' "$close_uncertain_fixture"
rg -q 'PublicationEvent.CloseOutcomeUnknown' "$close_uncertain_fixture"
rg -q 'InvalidEvent if not stage_close_succeeded or not parent_close_succeeded' "$model"
rg -q 'PublicationState.StageWriteFailed' "$model" "$write_failure_fixture"
rg -q 'PublicationEvent.WriteFailed' "$write_failure_fixture"
rg -q 'retry_rejected' "$write_failure_fixture"
rg -q 'PublicationEvent.StageRemoveOutcomeUnknown' "$stage_remove_uncertain_fixture"
rg -q 'PublicationState.CleanupUncertain' "$stage_remove_uncertain_fixture"

rg -q 'include "\.\./runtime/lua_bundle_publication_model\.elisa"' "$ir"
rg -q 'include "\.\./runtime/lua_bundle_publication_posix\.elisa"' "$ir"
rg -q 'using EsLuaBundlePublication' "$fixture"
rg -q '@link_name\(renameat\)' "$file_bridge"
rg -q 'def posix_renameat_leaf_valid\(' "$file_bridge"
rg -q '0\.\.<4096 \|bytes\|' "$file_bridge"
rg -q 'return false if index == 0' "$file_bridge"
rg -q 'return false if index == 1 and bytes\[0\] == 46u8' "$file_bridge"
rg -q 'return false if index == 2 and bytes\[0\] == 46u8 and bytes\[1\] == 46u8' "$file_bridge"
rg -q 'return false if byte == 47u8' "$file_bridge"
rg -q 'if byte == 0u8:' "$file_bridge"
rg -q 'PosixFileAtError\.InvalidLeafName' "$file_bridge"
rg -q 'def elisascript_posix_renameat\(' "$file_bridge"
rg -q '@link_name\(unlinkat\)' "$file_bridge"
rg -q 'def elisascript_posix_unlinkat_leaf\(' "$file_bridge"
rg -q 'elisascript_posix_unlinkat_leaf_impl\(directory_fd, leaf_name, 0\)' "$file_bridge"
rg -q 'InvalidDescriptor if directory_fd < 0' "$file_bridge"
rg -q 'def elisascript_posix_leaf_name_valid\(' "$file_bridge"
rg -q 'def elisascript_posix_openat_private_file\(' "$file_bridge"
rg -q 'DarwinOpenFlags::WRONLY \| DarwinOpenFlags::CREATE \| DarwinOpenFlags::EXCLUSIVE \| DarwinOpenFlags::NOFOLLOW \| DarwinOpenFlags::CLOSE_ON_EXEC' "$file_bridge"
rg -q 'flags, 384u32' "$file_bridge"
rg -q '^module EsLuaBundlePublicationPosix:' "$posix_adapter"
rg -q 'STAT_EINTR_RETRIES: usize = 8' "$posix_adapter"
rg -q 'DarwinErrno::EINTR' "$posix_adapter"
rg -q 'def capture_publication_host_proof\(' "$posix_adapter"
rg -q 'def revalidate_publication_host_proof\(' "$posix_adapter"
rg -q 'def close_publication_descriptors\(' "$posix_adapter"
rg -q 'def remove_publication_stage\(' "$posix_adapter"
rg -q 'elisascript_posix_unlinkat_leaf\(parent_fd, leaf_name\)' "$posix_adapter"
rg -q 'PublicationEvent.StageRemoveOutcomeUnknown' "$posix_adapter"
rg -q 'DarwinPublicationErrno::ENOENT' "$posix_adapter"
rg -q 'DarwinPublicationErrno::EIO' "$posix_adapter"
rg -q 'elisascript_posix_close\(staging_fd\)' "$posix_adapter"
rg -q 'elisascript_posix_close\(parent_fd\)' "$posix_adapter"
rg -q 'PublicationEvent.CloseOutcomeUnknown' "$posix_adapter"
rg -q 'PublicationPosixError\.IdentityChanged' "$posix_adapter"
rg -q 'publication_host_proof_equal\(expected, observed\)' "$posix_adapter"
rg -q 'WRITE_CALLS: usize = 1048576' "$posix_adapter"
rg -q 'def write_publication_stage_fully\(' "$posix_adapter"
rg -q 'def write_publication_stage\(' "$posix_adapter"
rg -q 'PublicationEvent.WriteFailed' "$posix_adapter"
rg -q 'advance_publication\(session, PublicationEvent.Write, written\)' "$posix_adapter"
rg -q 'cursor\.calls >= Limits::WRITE_CALLS' "$posix_adapter"
rg -q 'errno\[0\] == DarwinErrno::EINTR and cursor\.eintr_retries < Limits::IO_EINTR_RETRIES' "$posix_adapter"
rg -q 'amount == 0 or amount\.usize\(\) > remaining' "$posix_adapter"
rg -q 'PublicationPosixError\.WriteLimitExceeded' "$posix_adapter"
rg -q 'def sync_publication_stage\(' "$posix_adapter"
rg -q 'def sync_publication_descriptor\(' "$posix_adapter"
rg -q 'advance_publication\(session, PublicationEvent.Sync\)' "$posix_adapter"
rg -q 'elisascript_posix_fsync\(fd\)' "$posix_adapter"
rg -q 'retries < Limits::IO_EINTR_RETRIES' "$posix_adapter"
rg -q 'PublicationPosixError\.SyncFailed' "$posix_adapter"
rg -q 'def publish_staged\(' "$posix_adapter"
rg -q 'DarwinPublicationErrno::EIO' "$posix_adapter"
rg -q 'PublicationEvent.PublishFailed' "$posix_adapter"
rg -q 'PublicationEvent.OutcomeUnknown' "$posix_adapter"
rg -q 'PublicationEvent.PublishAck' "$posix_adapter"
rg -q 'PublicationPosixError.DirectorySyncFailed' "$posix_adapter"
rg -q 'EIO: i32 = 5' "$posix_adapter"
rg -q 'parent_fd < 0 or staging_fd < 0' "$posix_adapter"
rg -q 'descriptor_token: parent_fd\.u64\(\) \+ 1u64' "$posix_adapter"
rg -q 'descriptor_token: staging_fd\.u64\(\) \+ 1u64' "$posix_adapter"
rg -q 'publication_posix_stat_descriptor\(parent_fd, parent_info\)' "$posix_adapter"
rg -q 'publication_posix_stat_descriptor\(staging_fd, staging_info\)' "$posix_adapter"
rg -q 'publication_posix_stat_name\(parent_fd, leaf_name, named_info\)' "$posix_adapter"
rg -q 'elisascript_posix_fstat\(descriptor, result\)' "$posix_adapter"
rg -q 'elisascript_posix_fstatat\(parent_fd, leaf_name, result, DarwinAtFlag::SYMLINK_NOFOLLOW\)' "$posix_adapter"
rg -q 'StagingNameMismatch' "$posix_adapter"
rg -q 'typed_lua_bundle_publication_requires_exclusive_staging' "$fixture"
rg -q 'close_cannot_publish' "$fixture"
rg -q 'parent_mismatch_rejected' "$fixture"
rg -q 'descriptor_collision_rejected' "$fixture"
rg -q 'missing_parent_descriptor_rejected' "$fixture"
rg -q 'cancelled.parent_descriptor_closed' "$fixture"

printf 'lua bundle publication audit: exclusive sibling staging, paired descriptor ownership, identity-bound publish admission, bounded writes, directory sync, and failure preservation are present\n'
