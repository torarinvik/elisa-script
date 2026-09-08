#!/usr/bin/env bash

# Compiler-free audit for transactional record/regex rewrites.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/record_rewrite_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture_file="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$model" "$ir" "$fixture_file" "$docs" "$ledger" "$plan"; do
    [[ -f "$required_file" ]] || { printf 'record rewrite audit: missing %s\n' "$required_file" >&2; exit 1; }
done

rg -q '^module EsRecordRewrite:' "$model"
rg -q 'include "\.\./runtime/record_rewrite_model\.elisa"' "$ir"
for declaration in \
    'const enum RecordRewriteSymlinkMode of u8' \
    'const enum RecordRewriteState of u8' \
    'const enum RecordRewriteEvent of u8' \
    'struct RecordRewritePlan:' \
    'struct RecordRewriteSession:' \
    'error RecordRewriteError:' \
    'def validate_record_rewrite_session\(' \
    'def advance_record_rewrite\('; do
    rg -q "$declaration" "$model"
done

for boundary in \
    'RECORD_REWRITE_MAX_PATH_BYTES' \
    'RECORD_REWRITE_MAX_OUTPUT_BYTES' \
    'RECORD_REWRITE_MAX_APPENDS' \
    'record_rewrite_path_valid' \
    'record_rewrite_symlink_mode_valid' \
    'RecordRewriteError.PathCollision' \
    'RecordRewriteError.OutputLimitExceeded' \
    'session.state == RecordRewriteState.Staging' \
    'session.state == RecordRewriteState.Committed and session.plan.require_directory_sync' \
    'session.state == RecordRewriteState.Committing and session.plan.require_directory_sync' \
    'RecordRewriteEvent.Sync' \
    'RecordRewriteEvent.DirectorySync' \
    'RecordRewriteEvent.CommitAck' \
    'RecordRewriteEvent.BeginRollback' \
    'RecordRewriteEvent.RollbackAck'; do
    rg -q "$boundary" "$model"
done
rg -q 'return event in .*RecordRewriteEvent.DirectorySync' "$model"

for fixture_pattern in \
    'using EsRecordRewrite' \
    'typed_record_rewrite_contract_is_transactional_and_recoverable' \
    'RecordRewriteEvent.Sync' \
    'RecordRewriteEvent.DirectorySync' \
    'RecordRewriteEvent.CommitAck' \
    'RecordRewriteEvent.RollbackAck' \
    'RecordRewriteError.PathCollision'; do
    rg -q "$fixture_pattern" "$fixture_file"
done

rg -q 'EsRecordRewrite::RecordRewriteSession' "$docs"
rg -q 'ES-SCRIPT-025' "$ledger"
rg -q 'P11 rewrite follow-up' "$plan"

printf 'record rewrite audit: staged sync, commit, rollback, and collision checks are present\n'
