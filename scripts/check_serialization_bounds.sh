#!/usr/bin/env bash

# Compiler-free audit for the shared serialized-slice admission invariant.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
runtime_model="$repo_root/src/ir/runtime_model.elisa"
bytecode="$repo_root/src/bytecode/bytecode.elisa"
artifact_cache="$repo_root/src/ir/artifact_cache.elisa"
verifier="$repo_root/src/ir/ir_verify.elisa"
type_table="$repo_root/src/ir/type_table.elisa"
tests="$repo_root/test/ir/elisascript_ir_test.elisa"
incremental_cache_adapter_tests="$repo_root/test/runtime/build_incremental_cache_adapter_test.elisa"

for required_file in "$runtime_model" "$bytecode" "$artifact_cache" "$verifier" "$tests" "$incremental_cache_adapter_tests"; do
    if [[ ! -f "$required_file" ]]; then
        printf 'serialization bounds audit: missing %s\n' "$required_file" >&2
        exit 1
    fi
done

rg -q 'def runtime_bounded_slice_end' "$runtime_model"
rg -q 'return false if length > bound - start' "$runtime_model"
rg -q 'runtime_bounded_slice_end\(offset, length_host, bytes.count, end\)' "$bytecode"
rg -q 'runtime_bounded_slice_end\(offset, length_host, bytes.count, end\)' "$repo_root/src/testing/differential.elisa"
rg -q 'length\.usize\(\)\.u64\(\) != length' "$bytecode"
rg -q 'length\.usize\(\)\.u64\(\) != length' "$repo_root/src/testing/differential.elisa"
rg -q 'def differential_manifest_read_u64' "$repo_root/src/testing/differential.elisa"
rg -q 'return false if offset > bytes.count' "$repo_root/src/testing/differential.elisa"
rg -q 'return false if bytes.count - offset < 8' "$repo_root/src/testing/differential.elisa"
! rg -q 'offset \+ 2 > bytes.count|offset \+ 4 > bytes.count|length > \(bytes.count - offset\)' "$repo_root/src/testing/differential.elisa"
rg -q 'bytecode_artifact_bytes_valid' "$bytecode"
rg -q 'def bytecode_artifact_envelope_status' "$bytecode"
rg -q 'def bytecode_artifact_requires_migration' "$bytecode"
rg -q 'def bytecode_artifact_byte_range_has_nul' "$bytecode"
rg -q 'def migrate_bytecode_artifact' "$bytecode"
rg -q 'def bytecode_artifact_payload_matches_module' "$bytecode"
rg -q 'return false if not bytecode_artifact_payload_matches_module\(module, bytecode\)' "$bytecode"
rg -q 'altered_payload' "$repo_root/test/ir/elisascript_bytecode_test.elisa"
rg -q 'assert not bytecode_artifact_matches_module\(artifact, module, altered_payload\)' "$repo_root/test/ir/elisascript_bytecode_test.elisa"
rg -q 'def classify_bytecode_artifact_cache' "$artifact_cache"
rg -q 'def artifact_cache_lifecycle_transition' "$artifact_cache"
rg -q 'const enum ArtifactCacheRecoveryAction of u8' "$artifact_cache"
rg -q 'def artifact_cache_recovery_action' "$artifact_cache"
rg -q 'bytecode_block_layout_valid' "$bytecode"
rg -q 'saturat|saturated|range' "$verifier"
rg -q 'def type_descriptor_child_arity_valid' "$type_table"
rg -q 'def bounded_type_child_index' "$type_table"
rg -q 'bounded_type_child_index\(row.child_start, row.child_count' "$type_table"
rg -q 'type_descriptor_child_arity_valid\(row.kind, row.child_count.usize\(\)\)' "$type_table"
rg -q 'table.rows.count > TypeTableLimits::U32_MAX or table.children.count > TypeTableLimits::U32_MAX' "$type_table"
rg -q 'child_id.usize\(\) >= index \+ 1' "$type_table"
rg -q 'scalar_children:' "$tests"
rg -q 'array_with_two_children:' "$tests"
rg -q 'map_with_one_child:' "$tests"
rg -q 'assert not type_table_valid\(cyclic_module.type_table\)' "$tests"
rg -q 'serialized_slice_bounds_use_subtraction_before_end_addition' "$tests"
rg -q 'def canonical_bytes_sha256' "$repo_root/src/ir/serialize.elisa"
rg -q 'def canonical_module_digest' "$repo_root/src/ir/serialize.elisa"
rg -q 'def canonical_digest_word' "$repo_root/src/ir/serialize.elisa"
rg -q 'def canonical_module_digest_word' "$repo_root/src/ir/serialize.elisa"
rg -q 'CanonicalLimits::SHA256_MAX_INPUT_BYTES' "$repo_root/src/ir/serialize.elisa"
rg -q 'def canonical_module_budget_valid' "$repo_root/src/ir/serialize.elisa"
rg -q 'CanonicalLimits::MODULE_TEXT_BYTES' "$repo_root/src/ir/serialize.elisa"
rg -q 'handler stack instruction must have no operands, no SSA result, and a void result type' "$verifier"
rg -q 'verifier_rejects_handler_stack_results' "$tests"
rg -q 'canonical_sha256_matches_known_vectors' "$tests"
rg -q 'canonical_module_rejects_oversized_borrowed_text_before_emission' "$tests"
rg -q 'module_digest_0' "$bytecode"
rg -q 'artifact\.module_fingerprint == 0' "$bytecode"
rg -q 'bytes\[4\] != 2' "$bytecode"
rg -q 'legacy_version' "$repo_root/test/ir/elisascript_bytecode_test.elisa"
rg -q 'bytecode_artifact_requires_migration' "$repo_root/test/ir/elisascript_bytecode_test.elisa"
rg -q 'malformed_revision' "$repo_root/test/ir/elisascript_bytecode_test.elisa"
rg -q 'migrate_bytecode_artifact' "$repo_root/test/ir/elisascript_bytecode_test.elisa"
rg -q 'digest_0' "$repo_root/src/ir/artifact.elisa"
rg -q 'format_version: u8 = 2' "$repo_root/src/ir/artifact.elisa"
rg -q 'def canonical_module_artifact_bytes' "$repo_root/src/ir/artifact.elisa"
rg -q 'def module_artifact_bytes_valid' "$repo_root/src/ir/artifact.elisa"
rg -q 'artifact\.fingerprint == 0' "$repo_root/src/ir/artifact.elisa"
rg -q 'def module_artifact_envelope_status' "$repo_root/src/ir/artifact.elisa"
rg -q 'def module_artifact_requires_migration' "$repo_root/src/ir/artifact.elisa"
rg -q 'def module_artifact_byte_range_has_nul' "$repo_root/src/ir/artifact.elisa"
rg -q 'def migrate_module_artifact' "$repo_root/src/ir/artifact.elisa"
rg -q 'def classify_module_artifact_cache' "$artifact_cache"
rg -q 'def load_module_artifact_file' "$artifact_cache"
rg -q 'def load_bytecode_artifact_file' "$artifact_cache"
rg -q 'def publish_module_artifact_file' "$artifact_cache"
rg -q 'def publish_bytecode_artifact_file' "$artifact_cache"
rg -q 'def artifact_cache_write_staging' "$artifact_cache"
rg -q 'expected_count: usize = size.usize\(\)' "$artifact_cache"
rg -q 'bytes.count != expected_count' "$artifact_cache"
rg -q 'catch artifact_cache_write_staging' "$artifact_cache"
! rg -q 'try artifact_cache_write_staging' "$artifact_cache"
rg -q 'def artifact_cache_write_descriptor_fully' "$artifact_cache"
rg -q 'def artifact_cache_read_descriptor_fully' "$artifact_cache"
rg -q 'machine over cursor.state' "$artifact_cache"
rg -q 'DarwinOpenFlags::WRONLY \| DarwinOpenFlags::CREATE \| DarwinOpenFlags::EXCLUSIVE \| DarwinOpenFlags::NOFOLLOW \| DarwinOpenFlags::CLOSE_ON_EXEC' "$artifact_cache"
rg -q 'elisascript_posix_fsync\(descriptor\)' "$artifact_cache"
rg -q 'elisascript_posix_close\(descriptor\)' "$artifact_cache"
! rg -q 'file_stream_open\(staging_path' "$artifact_cache"
rg -q 'ArtifactCacheIoError\.PublishFailed' "$artifact_cache"
rg -q 'PublishOutcomeUnknown\(path: cstr\)' "$artifact_cache"
rg -q 'rename_errno == ArtifactCacheErrno::EIO' "$artifact_cache"
rg -q 'PublishOutcomeUnknown\(destination_path\) if rename_errno == ArtifactCacheErrno::EIO' "$artifact_cache"
rg -q 'EIO: i32 = 5' "$artifact_cache"
rg -q 'struct ArtifactCacheStagingIdentity:' "$artifact_cache"
rg -q 'StagingIdentityChanged\(path: cstr\)' "$artifact_cache"
rg -q 'def artifact_cache_staging_name_matches_at\(' "$artifact_cache"
rg -q 'elisascript_posix_fstat\(descriptor, staging_info\)' "$artifact_cache"
rg -q 'artifact_cache_staging_name_matches_at\(directory_fd, destination_name, staging_identity\)' "$artifact_cache"
if ! awk '
    /def artifact_cache_publish_payload_at\(/ { in_payload_publish = 1 }
    /def artifact_cache_publish_payload_at_locked\(/ { in_payload_publish = 0 }
    in_payload_publish && /StagingIdentityChanged\(staging_name\)/ { identity_guard_line = NR }
    in_payload_publish && /catch elisascript_posix_renameat\(/ { rename_line = NR }
    END { exit !(identity_guard_line > 0 && rename_line > identity_guard_line) }
' "$artifact_cache"; then
    printf 'serialization bounds audit: staging identity is not revalidated before rename\n' >&2
    exit 1
fi
if ! awk '
    /def artifact_cache_publish_payload_at\(/ { in_payload_publish = 1 }
    /def artifact_cache_publish_payload_at_locked\(/ { in_payload_publish = 0 }
    in_payload_publish && /if artifact_cache_staging_name_matches_at\(directory_fd, staging_name, staging_identity\)/ { cleanup_guard = 1; guards++ }
    in_payload_publish && cleanup_guard && /catch elisascript_posix_unlinkat_leaf/ { cleanups++; cleanup_guard = 0 }
    END { exit !(guards == 2 && cleanups == 2) }
' "$artifact_cache"; then
    printf 'serialization bounds audit: staging cleanup lacks identity guards\n' >&2
    exit 1
fi
if ! awk '
    /def artifact_cache_publish_file\(/ { in_publish_file = 1 }
    /def artifact_cache_publish_payload_at\(/ { in_publish_file = 0 }
    in_publish_file && /PublishOutcomeUnknown\(destination_path\)/ { unknown_line = NR }
    in_publish_file && /_ = remove_file\(staging_path\)/ { cleanup_line = NR }
    END { exit !(unknown_line > 0 && cleanup_line > unknown_line) }
' "$artifact_cache"; then
    printf 'serialization bounds audit: path-based artifact publication cleans staging before classifying ambiguous rename\n' >&2
    exit 1
fi
if ! awk '
    /def artifact_cache_publish_payload_at\(/ { in_payload_publish = 1 }
    /def artifact_cache_publish_payload_at_locked\(/ { in_payload_publish = 0 }
    in_payload_publish && /elif not published:/ { in_uncertain_branch = 1 }
    in_payload_publish && in_uncertain_branch && /PublishOutcomeUnknown\(destination_name\)/ { unknown_line = NR }
    in_payload_publish && in_uncertain_branch && /elisascript_posix_unlinkat_leaf/ { cleanup_line = NR }
    in_payload_publish && in_uncertain_branch && /raise ArtifactCacheIoError\.PublishFailed\(destination_name\)/ { in_uncertain_branch = 0 }
    END { exit !(unknown_line > 0 && cleanup_line > unknown_line) }
' "$artifact_cache"; then
    printf 'serialization bounds audit: descriptor-relative artifact publication cleans staging before classifying ambiguous rename\n' >&2
    exit 1
fi
rg -q 'ArtifactCacheIoError\.DirectorySyncFailed' "$artifact_cache"
rg -q 'ArtifactCacheIoError\.PathTooLong' "$artifact_cache"
rg -q 'Limits::PATH_BYTES' "$artifact_cache"
rg -q 'def artifact_cache_path_terminated' "$artifact_cache"
rg -q 'def artifact_cache_path_equal' "$artifact_cache"
rg -q 'PathCollision\(path: cstr\)' "$artifact_cache"
rg -q 'PathCollision\(staging_path\) if artifact_cache_path_equal\(staging_path, destination_path\)' "$artifact_cache"
rg -q 'PathCollision\(lock_path\) if artifact_cache_path_equal\(lock_path, staging_path\)' "$artifact_cache"
rg -q 'return false if bytes\[0\] == 0' "$artifact_cache"
rg -q 'PathTooLong\(staging_path\) if not artifact_cache_path_terminated' "$artifact_cache"
rg -q 'PathTooLong\(destination_path\) if not artifact_cache_path_terminated' "$artifact_cache"
rg -q 'def artifact_cache_sync_directory' "$artifact_cache"
rg -q 'catch artifact_cache_sync_directory' "$artifact_cache"
! rg -q '_ = try artifact_cache_sync_directory' "$artifact_cache"
rg -q 'elisascript_posix_dirfd' "$artifact_cache"
rg -q 'directory_path: cstr = ""' "$artifact_cache"
rg -q 'ArtifactCacheIoError\.LockFailed' "$artifact_cache"
rg -q 'struct ArtifactCacheWriterLock' "$artifact_cache"
rg -q 'ArtifactCacheWriterLockEvent' "$artifact_cache"
rg -q 'def artifact_cache_writer_lock_transition' "$artifact_cache"
rg -q 'artifact_cache_writer_lock_transition\(ArtifactCacheWriterLockState\.Held, ArtifactCacheWriterLockEvent\.Acquire\)' "$tests"
rg -q 'artifact_cache_writer_lock_transition\(ArtifactCacheWriterLockState\.Released, ArtifactCacheWriterLockEvent\.Release\)' "$tests"
rg -q 'def artifact_cache_writer_lock_acquire' "$artifact_cache"
rg -q 'def artifact_cache_writer_lock_release' "$artifact_cache"
rg -q 'elisascript_posix_flock' "$artifact_cache"
rg -q 'elisascript_posix_open\(path, flags, 384u32\)' "$artifact_cache"
rg -q 'DarwinOpenFlags::WRONLY \| DarwinOpenFlags::CREATE \| DarwinOpenFlags::NONBLOCK \| DarwinOpenFlags::NOFOLLOW \| DarwinOpenFlags::CLOSE_ON_EXEC' "$artifact_cache"
! rg -q 'file_stream_open\(path, FileStreamMode\.AppendBinary' "$artifact_cache"
rg -q 'def artifact_cache_publish_locked' "$artifact_cache"
rg -q 'def publish_module_artifact_file_locked' "$artifact_cache"
rg -q 'def publish_bytecode_artifact_file_locked' "$artifact_cache"
rg -q 'PAYLOAD_BYTES: usize = EsBuildIncrementalCache::Limits::CACHE_BYTES' "$artifact_cache"
rg -q 'def read_build_incremental_cache_file' "$artifact_cache"
rg -q 'artifact_cache_read_bounded_file\(a, path, EsBuildIncrementalCache::Limits::CACHE_BYTES\)' "$artifact_cache"
rg -q 'def read_build_incremental_cache_at' "$artifact_cache"
rg -q 'def artifact_cache_read_file_at' "$artifact_cache"
rg -q 'DarwinOpenFlags::RDONLY \| DarwinOpenFlags::NONBLOCK \| DarwinOpenFlags::NOFOLLOW \| DarwinOpenFlags::CLOSE_ON_EXEC' "$artifact_cache"
rg -q 'elisascript_posix_openat\(directory_fd, cache_name, flags, 0u32\)' "$artifact_cache"
rg -q 'elisascript_posix_read\(descriptor, destination.cast\[mutable void&\], remaining\)' "$artifact_cache"
rg -q 'artifact_cache_read_descriptor_fully\(descriptor, bytes, expected_count\)' "$artifact_cache"
rg -q 'arena_da_reserve\(a, bytes, expected_count\)' "$artifact_cache"
rg -q '_ = try decode_build_incremental_cache\(bytes\)' "$artifact_cache"
rg -q 'def publish_build_incremental_cache_at_locked' "$artifact_cache"
rg -q 'incremental_cache_descriptor_io_rejects_invalid_directory_handles' "$incremental_cache_adapter_tests"
rg -q 'read_build_incremental_cache_at\(arena, -1, "cache.bin"\)' "$incremental_cache_adapter_tests"
rg -q 'publish_build_incremental_cache_at_locked\(arena, lock, -1, "cache.lock", 7, "cache.tmp", "cache.bin", bytes\)' "$incremental_cache_adapter_tests"
rg -q 'artifact_cache_publish_payload_at_locked\(a, lock, directory_fd, lock_name, owner_token, staging_name, destination_name, bytes, EsBuildIncrementalCache::Limits::CACHE_BYTES\)' "$artifact_cache"
rg -q 'unchanged: bool = false' "$artifact_cache"
rg -q 'artifact_cache_payload_matches_at\(a, directory_fd, destination_name, bytes, byte_limit\)' "$artifact_cache"
if ! awk '
    /def artifact_cache_publish_payload_at\(/ { in_payload_publish = 1 }
    /def artifact_cache_publish_payload_at_locked\(/ { in_payload_publish = 0 }
    in_payload_publish && /unchanged: true/ { noop_line = NR }
    in_payload_publish && /artifact_cache_write_staging_at\(/ { stage_line = NR }
    END { exit !(noop_line > 0 && stage_line > noop_line) }
' "$artifact_cache"; then
    printf 'serialization bounds audit: unchanged cache payload is not returned before staging\n' >&2
    exit 1
fi
if ! awk '
    /def artifact_cache_payload_matches_at\(/ { in_payload_match = 1 }
    /def artifact_cache_write_staging_at\(/ { in_payload_match = 0 }
    in_payload_match && /DarwinAtFlag::SYMLINK_NOFOLLOW/ { nofollow_line = NR }
    in_payload_match && /named_info\.mode & DarwinStatMode::MASK/ { regular_file_line = NR }
    in_payload_match && /named_info\.size\.usize\(\) > byte_limit/ { size_limit_line = NR }
    in_payload_match && /named_info\.size\.usize\(\) != bytes\.count/ { named_length_line = NR }
    in_payload_match && /existing\.count != bytes\.count/ { read_length_line = NR }
    in_payload_match && /existing\[index\] != bytes\[index\]/ { byte_compare_line = NR }
    in_payload_match && /return true/ { equal_line = NR }
    END { exit !(nofollow_line > 0 && regular_file_line > nofollow_line && size_limit_line > regular_file_line && named_length_line > size_limit_line && read_length_line > named_length_line && byte_compare_line > read_length_line && equal_line > byte_compare_line) }
' "$artifact_cache"; then
    printf 'serialization bounds audit: no-op cache comparison is not bounded, no-follow, and byte-exact\n' >&2
    exit 1
fi
if ! awk '
    /def artifact_cache_read_file_at\(/ { in_cache_read = 1 }
    /def artifact_cache_payload_matches_at\(/ { in_cache_read = 0 }
    in_cache_read && /fstatat\(directory_fd, cache_name, named_before, DarwinAtFlag::SYMLINK_NOFOLLOW\)/ { named_before_line = NR }
    in_cache_read && /openat\(directory_fd, cache_name, flags, 0u32\)/ { open_line = NR }
    in_cache_read && /info\.device != named_before\.device/ { descriptor_identity_line = NR }
    in_cache_read && /fstatat\(directory_fd, cache_name, named_after, DarwinAtFlag::SYMLINK_NOFOLLOW\)/ { named_after_line = NR }
    in_cache_read && /named_after\.inode == info\.inode/ { final_identity_line = NR }
    in_cache_read && /not name_still_matches/ { identity_reject_line = NR }
    END { exit !(named_before_line > 0 && open_line > named_before_line && descriptor_identity_line > open_line && named_after_line > descriptor_identity_line && final_identity_line >= named_after_line && identity_reject_line > final_identity_line) }
' "$artifact_cache"; then
    printf 'serialization bounds audit: no-op cache read does not bind bytes to a stable named inode\n' >&2
    exit 1
fi
if ! awk '
    /def artifact_cache_publish_payload_at\(/ { in_payload_publish = 1 }
    /def artifact_cache_publish_payload_at_locked\(/ { in_payload_publish = 0 }
    in_payload_publish && /fstatat\(directory_fd, staging_name, stage_info, DarwinAtFlag::SYMLINK_NOFOLLOW\)/ { stage_check_line = NR }
    in_payload_publish && /stage_errno\[0\] != DarwinErrno::ENOENT/ { stale_stage_reject_line = NR }
    in_payload_publish && /catch artifact_cache_payload_matches_at/ { compare_line = NR }
    in_payload_publish && /unchanged: true/ { unchanged_line = NR }
    in_payload_publish && /artifact_cache_write_staging_at\(/ { staging_write_line = NR }
    END { exit !(stage_check_line > 0 && stale_stage_reject_line > stage_check_line && compare_line > stale_stage_reject_line && unchanged_line > compare_line && staging_write_line > unchanged_line) }
' "$artifact_cache"; then
    printf 'serialization bounds audit: cache no-op bypasses stale-stage admission or occurs after staging\n' >&2
    exit 1
fi
rg -q 'def artifact_cache_write_staging_at' "$artifact_cache"
rg -q 'def artifact_cache_directory_descriptor_valid' "$artifact_cache"
rg -q 'elisascript_posix_fstat\(directory_fd, info\)' "$artifact_cache"
rg -q 'info\.mode & DarwinStatMode::MASK' "$artifact_cache"
rg -q 'elisascript_posix_openat\(directory_fd, staging_name, flags, 384u32\)' "$artifact_cache"
rg -q 'elisascript_posix_renameat\(directory_fd, staging_name, directory_fd, destination_name\)' "$artifact_cache"
rg -q 'elisascript_posix_unlinkat_leaf\(directory_fd, staging_name\)' "$artifact_cache"
rg -q 'elisascript_posix_fsync\(directory_fd\)' "$artifact_cache"
rg -q 'DirectoryDescriptorSyncFailed\(descriptor: int\)' "$artifact_cache"
rg -q 'def artifact_cache_writer_lock_acquire_at' "$artifact_cache"
rg -q 'elisascript_posix_openat\(directory_fd, lock_name, flags, 384u32\)' "$artifact_cache"
rg -q 'def artifact_cache_publish_payload_at_locked' "$artifact_cache"
rg -q 'catch artifact_cache_writer_lock_release' "$artifact_cache"
rg -q 'elisascript_posix_rename' "$artifact_cache"
rg -q 'def artifact_cache_stage' "$artifact_cache"
rg -q 'runtime_bounded_slice_end\(offset, length\.usize\(\), bytes.count, end\)' "$repo_root/src/ir/artifact.elisa"
rg -q 'def module_artifact_read_u64' "$repo_root/src/ir/artifact.elisa"
rg -q 'return false if offset > bytes.count' "$repo_root/src/ir/artifact.elisa"
rg -q 'return false if bytes.count - offset < 8' "$repo_root/src/ir/artifact.elisa"
rg -q 'return false if offset > bytes.count' "$bytecode"
rg -q 'return false if bytes.count - offset < 8' "$bytecode"
rg -q 'legacy_artifact_bytes' "$tests"
rg -q 'unknown_artifact_version' "$tests"
rg -q 'malformed_artifact_digest' "$tests"
rg -q 'malformed_metadata\.fingerprint <- 0' "$tests"
rg -q 'malformed_metadata\.module_fingerprint <- 0' "$repo_root/test/ir/elisascript_bytecode_test.elisa"
rg -q 'module_artifact_requires_migration' "$tests"
rg -q 'malformed_artifact_text' "$tests"
rg -q 'malformed_artifact_trailing' "$tests"
rg -q 'migrate_module_artifact' "$tests"
rg -q 'ArtifactCacheLifecycle.Staged' "$tests"
rg -q 'ArtifactCacheLoad' "$tests"
rg -q 'ArtifactCacheEvent.Commit' "$tests"
rg -q 'ArtifactCacheRecoveryAction.KeepPublished' "$tests"
rg -q 'ArtifactCacheRecoveryAction.RemoveStaging' "$tests"
rg -q 'ArtifactCacheRecoveryAction.RebuildPublished' "$tests"
rg -q 'ArtifactCacheRecoveryAction.Noop' "$tests"
rg -q 'artifact_cache_restart\(committed_cache\)\.state == ArtifactCacheLifecycle.Committed' "$tests"
rg -q 'artifact_cache_restart\(staged_cache\)\.state == ArtifactCacheLifecycle.Rejected' "$tests"
rg -q 'artifact_cache_restart\(ArtifactCachePublication\{state: ArtifactCacheLifecycle.Empty\}\)\.state == ArtifactCacheLifecycle.Empty' "$tests"
rg -q 'artifact_cache_restart\(ArtifactCachePublication\{state: ArtifactCacheLifecycle.Rejected\}\)\.state == ArtifactCacheLifecycle.Rejected' "$tests"
rg -q 'struct ArtifactCacheWriterLease' "$artifact_cache"
rg -q 'def artifact_cache_writer_acquire' "$artifact_cache"
rg -q 'def artifact_cache_writer_publish' "$artifact_cache"
rg -q 'def artifact_cache_writer_abort' "$artifact_cache"
rg -q 'artifact_cache_writer_acquire\(lease, 41\)' "$tests"
rg -q 'artifact_cache_writer_acquire\(aborted, 0\)' "$tests"
rg -q 'artifact_cache_writer_acquire\(aborted, 8\)' "$tests"
rg -q 'artifact_cache_writer_publish\(aborted, 8\)' "$tests"
rg -q 'module_digest_0' "$repo_root/src/testing/differential.elisa"
rg -q 'def make_differential_artifact_manifest_for_module' "$repo_root/src/testing/differential.elisa"
rg -q 'def differential_artifact_manifest_requires_migration' "$repo_root/src/testing/differential.elisa"
rg -q 'manifest.format_version != 4' "$repo_root/src/testing/differential.elisa"
rg -q 'bytes\[4\] != 4' "$repo_root/src/testing/differential.elisa" || rg -q 'bytes\[4\] != 1 and bytes\[4\] != 2 and bytes\[4\] != 3 and bytes\[4\] != 4' "$repo_root/src/testing/differential.elisa"
rg -q 'digest_manifest' "$repo_root/test/differential/elisascript_differential_test.elisa"
rg -q 'malformed_manifest_length' "$repo_root/test/differential/elisascript_differential_test.elisa"
rg -q 'differential_artifact_manifest_requires_migration' "$repo_root/test/differential/elisascript_differential_test.elisa"
printf 'serialization bounds audit: shared slice admission, TypeTable shape/order, bytecode reader, verifier, descriptor-relative cache writer, and fixtures present\n'
