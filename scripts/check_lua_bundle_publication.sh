#!/usr/bin/env bash

# Compiler-free audit for the pure W04 Lua metadata publication boundary.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/lua_bundle_publication_model.elisa"
file_bridge="$repo_root/src/runtime/file_posix.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"

for required_file in "$model" "$file_bridge" "$ir" "$fixture"; do
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

rg -q 'include "\.\./runtime/lua_bundle_publication_model\.elisa"' "$ir"
rg -q 'using EsLuaBundlePublication' "$fixture"
rg -q '@link_name\(renameat\)' "$file_bridge"
rg -q 'def elisascript_posix_renameat\(' "$file_bridge"
rg -q 'typed_lua_bundle_publication_requires_exclusive_staging' "$fixture"
rg -q 'close_cannot_publish' "$fixture"
rg -q 'parent_mismatch_rejected' "$fixture"
rg -q 'descriptor_collision_rejected' "$fixture"
rg -q 'missing_parent_descriptor_rejected' "$fixture"
rg -q 'cancelled.parent_descriptor_closed' "$fixture"

printf 'lua bundle publication audit: exclusive sibling staging, paired descriptor ownership, identity-bound publish admission, bounded writes, directory sync, and failure preservation are present\n'
