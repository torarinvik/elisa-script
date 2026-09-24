#!/usr/bin/env bash

# Compiler-free audit for typed configuration precedence.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/config_model.elisa"
json_model="$repo_root/src/runtime/config_json_model.elisa"
environment_model="$repo_root/src/runtime/config_environment_model.elisa"
cli_model="$repo_root/src/runtime/config_cli_model.elisa"
json_file_model="$repo_root/src/runtime/config_json_file_posix.elisa"
toml_model="$repo_root/src/runtime/config_toml_model.elisa"
toml_file_model="$repo_root/src/runtime/config_toml_file_posix.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
runtime_fixture="$repo_root/test/runtime/config_model_test.elisa"
json_fixture="$repo_root/test/runtime/config_json_model_test.elisa"
environment_fixture="$repo_root/test/runtime/config_environment_model_test.elisa"
cli_fixture="$repo_root/test/runtime/config_cli_model_test.elisa"
integration_fixture="$repo_root/test/runtime/config_precedence_integration_test.elisa"
json_file_fixture="$repo_root/test/runtime/config_json_file_posix_test.elisa"
json_file_data="$repo_root/test/runtime/config_json_file_fixture.json"
toml_fixture="$repo_root/test/runtime/config_toml_model_test.elisa"
toml_file_fixture="$repo_root/test/runtime/config_toml_file_posix_test.elisa"
toml_file_data="$repo_root/test/runtime/config_toml_file_fixture.toml"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"

for required_file in "$model" "$json_model" "$environment_model" "$cli_model" "$json_file_model" "$toml_model" "$toml_file_model" "$ir" "$fixture" "$runtime_fixture" "$json_fixture" "$environment_fixture" "$cli_fixture" "$integration_fixture" "$json_file_fixture" "$json_file_data" "$toml_fixture" "$toml_file_fixture" "$toml_file_data" "$docs" "$ledger"; do
    [[ -f "$required_file" ]] || { printf 'config audit: missing %s\n' "$required_file" >&2; exit 1; }
done
for toml_boundary in \
    'module EsConfigToml:' \
    'CONFIG_TOML_MAX_BYTES' \
    'def parse_toml_config(' \
    'ArrayTableUnsupported' \
    'UnsupportedEscape' \
    'validate_config_layers([result.layer])'; do
    rg -Fq "$toml_boundary" "$toml_model"
done
for toml_file_boundary in \
    'module EsConfigTomlFilePosix:' \
    'def read_config_toml_file(' \
    'EsBoundedText::read_utf8(input_path, maximum_bytes)' \
    'parse_toml_config(source)'; do
    rg -Fq "$toml_file_boundary" "$toml_file_model"
done
for json_file_boundary in \
    'module EsConfigJsonFilePosix:' \
    'struct ConfigJsonFileLayer:' \
    'def read_config_json_file(' \
    'JSON_CONFIG_FILE_MAX_BYTES' \
    'DataDecodeLimits{input_bytes: JSON_CONFIG_FILE_MAX_BYTES}' \
    'config_json_file_limits_valid(limits)' \
    'ConfigJsonFileError.JsonPolicyInvalid' \
    'EsBoundedText::read_utf8(input_path, limits.input_bytes)' \
    'flat_json_config_layer(document)'; do
    rg -Fq "$json_file_boundary" "$json_file_model"
done
for environment_boundary in \
    'module EsConfigEnvironment:' \
    'def environment_config_layer(' \
    'EnvironmentState.Sealed' \
    'EsConfig::Limits::ENTRIES_PER_LAYER' \
    'if entry.present:'; do
    rg -Fq "$environment_boundary" "$environment_model"
done
rg -Fq 'PROCESS_COMMAND_MAX_ENVIRONMENT_ENTRIES' "$repo_root/src/runtime/environment_model.elisa"
for cli_boundary in \
    'module EsConfigCli:' \
    'def parse_config_cli(' \
    'ConfigSource.CommandLine' \
    'ConfigCliError.UnknownOption' \
    'ConfigCliError.MissingValue' \
    'ConfigCliError.DuplicateOption' \
    'ConfigCliError.EmbeddedNul' \
    'options_enabled'; do
    rg -Fq "$cli_boundary" "$cli_model"
done

for declaration in \
    'module EsConfig:' \
    'const module Limits:' \
    'const enum ConfigSource of u8:' \
    'struct ConfigEntry:' \
    'struct ConfigLayer:' \
    'struct ConfigValue:' \
    'struct ConfigLookup:' \
    'error ConfigError:' \
    'def validate_config_layers(' \
    'def resolve_config_layers(' \
    'def lookup_config_value(' \
    'def config_entry_fits('; do
    rg -Fq "$declaration" "$model"
done

for boundary in \
    'ConfigSource.Defaults' \
    'ConfigSource.File' \
    'ConfigSource.Environment' \
    'ConfigSource.CommandLine' \
    'config_source_priority' \
    'Limits::LAYER_BYTES' \
    'Limits::OUTPUT_BYTES' \
    'ConfigError.DuplicateLayer' \
    'ConfigError.DuplicateKey' \
    'ConfigError.InvalidKey' \
    'ConfigError.InvalidValue' \
    'ConfigError.LayerBytesExceeded' \
    'ConfigError.OutputBytesExceeded' \
    'ConfigError.OutputLimitExceeded' \
    'config_values_valid'; do
    rg -Fq "$boundary" "$model"
done
rg -Fq 'return not sview_contains_byte(value, 0)' "$model"
for json_boundary in \
    'module EsConfigJson:' \
    'def flat_json_config_layer(' \
    'JsonDuplicateKeyPolicy.Reject' \
    'EsConfig::Limits::ENTRIES_PER_LAYER' \
    'JsonNodeKind.Number' \
    'ConfigJsonError.StructuredValueUnsupported'; do
    rg -Fq "$json_boundary" "$json_model"
done

rg -Fq 'include "../runtime/config_model.elisa"' "$ir"
rg -Fq 'include "../runtime/config_json_model.elisa"' "$ir"
rg -Fq 'include "../runtime/config_toml_model.elisa"' "$ir"
rg -Fq 'include "../runtime/config_environment_model.elisa"' "$ir"
rg -Fq 'include "../runtime/config_cli_model.elisa"' "$ir"
rg -Fq 'include "../runtime/config_json_file_posix.elisa"' "$ir"
rg -Fq 'include "../runtime/config_toml_file_posix.elisa"' "$ir"
rg -Fq 'using EsConfig' "$fixture"
for fixture_check in \
    'typed_config_precedence_is_explicit_and_deterministic' \
    'ConfigSource.CommandLine' \
    'ConfigError.DuplicateLayer' \
    'ConfigError.DuplicateKey' \
    'ConfigError.InvalidKey' \
    'ConfigError.InvalidValue'; do
    rg -Fq "$fixture_check" "$fixture"
done
rg -Fq 'config_values_preserve_line_breaks_and_reject_only_nul' "$runtime_fixture"
rg -Fq 'flat_json_configuration_preserves_scalar_contracts' "$json_fixture"
rg -Fq 'flat_json_configuration_rejects_structures_and_duplicate_tolerant_policy' "$json_fixture"
rg -Fq 'environment_config_layer_keeps_present_values_and_omits_tombstones' "$environment_fixture"
rg -Fq 'environment_config_layer_requires_sealed_snapshot' "$environment_fixture"
rg -Fq 'environment_snapshot_uses_the_environment_entry_limit' "$environment_fixture"
rg -Fq 'declared_config_cli_options_preserve_empty_and_passthrough_values' "$cli_fixture"
rg -Fq 'declared_config_cli_options_reject_unknown_missing_and_duplicate_values' "$cli_fixture"
rg -Fq 'ConfigCliError.EmbeddedNul' "$cli_fixture"
rg -Fq 'config_precedence_composes_all_four_explicit_sources' "$integration_fixture"
rg -Fq 'bounded_json_configuration_file_retains_layer_document_storage' "$json_file_fixture"
rg -Fq 'bounded_json_configuration_file_rejects_over_limit_before_reading' "$json_file_fixture"
rg -Fq 'toml_configuration_parses_bounded_scalar_subset' "$toml_fixture"
rg -Fq '0xDEAD_BEEF' "$toml_fixture"
rg -Fq '+1_000' "$toml_fixture"
rg -Fq 'toml_configuration_rejects_unsupported_values_and_escapes' "$toml_fixture"
rg -Fq 'quoted_key_rejected' "$toml_fixture"
rg -Fq '123.name' "$toml_fixture"
rg -Fq 'bounded_toml_configuration_file_returns_owned_layer' "$toml_file_fixture"
rg -Fq 'bounded_toml_configuration_file_rejects_invalid_budget_before_reading' "$toml_file_fixture"
rg -Fq 'mode = "release"' "$toml_file_data"
rg -Fq '"name":"ElisaScript","count":23,"enabled":true' "$json_file_data"

rg -Fq '`EsConfig` is the pure configuration precedence boundary' "$docs"

printf 'config audit: bounded precedence, aggregate payload ceilings, and deterministic lookup are present\n'
