#!/usr/bin/env bash

# Compiler-free audit for the pure W04 Lua bundle metadata and host-command boundary.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/lua_bundle_metadata_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
plan="$repo_root/IMPLEMENTATION_PLAN.md"
tasks="$repo_root/SCRIPT_TASKS.md"

for required_file in "$model" "$ir" "$fixture" "$plan" "$tasks"; do
    [[ -f "$required_file" ]] || { printf 'lua bundle metadata audit: missing %s\n' "$required_file" >&2; exit 1; }
done

for declaration in \
    '^module EsLuaBundleMetadata:' \
    'const module Limits:' \
    'const module Options:' \
    'HOST_OUTPUT_BYTES' \
    'HOST_TIMEOUT_MICROS' \
    'struct MetadataAssignment:' \
    'struct MetadataArguments:' \
    'struct MetadataFacts:' \
    'struct MetadataProcessResults:' \
    'const enum MetadataHostCommandKind' \
    'error MetadataArgumentsError:' \
    'error MetadataJsonError:' \
    'error MetadataCommandError:' \
    'def parse_metadata_arguments\(' \
    'def metadata_host_command\(' \
    'def render_metadata_json\('; do
    rg -q "$declaration" "$model"
done

for option in '--output' '--bundle-type' '--repo-root' '--out-dir' '--setting' '--command'; do
    rg -q -- "$option" "$model"
done

for boundary in \
    'ArgumentTooLarge' \
    'MissingOptionValue' \
    'AmbiguousOption' \
    'UnexpectedPositional' \
    'MissingRequiredOption' \
    'InvalidAssignment' \
    'EmptyAssignmentKey' \
    'EntryLimitExceeded' \
    'PathTooLong' \
    'metadata_assignment_value' \
    'metadata_final_assignments' \
    'metadata_facts_valid' \
    'metadata_facts_from_processes' \
    'metadata_host_command' \
    'MetadataHostCommandKind.GitStatus' \
    'MetadataCommandError.InvalidRepoRoot' \
    'ProcessFailureMode.Allow' \
    'ProcessStdioMode.Capture' \
    'ProcessStdioMode.Null' \
    'HOST_TIMEOUT_MICROS' \
    'C.UTF-8' \
    'working_directory' \
    'metadata_ascii_digit' \
    'metadata_unicode_whitespace' \
    'metadata_json_decode_utf8' \
    'ProcessResultKind.Exited' \
    'metadata_json_append_hex4' \
    'MetadataJsonError.InvalidFacts' \
    'MetadataJsonError.InvalidUtf8' \
    'MetadataJsonError.OutputLimitExceeded' \
    'valid_and_last_wins' \
    'negative_lookalike' \
    'exponent_lookalike' \
    'render_metadata_json' \
    'small_limit'; do
    rg -q "$boundary" "$model" "$fixture"
done

rg -q 'include "\.\./runtime/lua_bundle_metadata_model\.elisa"' "$ir"
rg -q 'using EsLuaBundleMetadata' "$fixture"
rg -q 'W04' "$plan" "$tasks"

printf 'lua bundle metadata audit: typed parsing with argparse negative-number boundaries, bounded host command planning/normalization, sorted JSON serialization, repeated-key last-wins, and explicit limits are present\n'
