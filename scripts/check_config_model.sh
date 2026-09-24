#!/usr/bin/env bash

# Compiler-free audit for typed configuration precedence.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
model="$repo_root/src/runtime/config_model.elisa"
ir="$repo_root/src/ir/ir.elisa"
fixture="$repo_root/test/ir/elisascript_ir_test.elisa"
runtime_fixture="$repo_root/test/runtime/config_model_test.elisa"
docs="$repo_root/docs/ir.md"
ledger="$repo_root/docs/capabilities/ledger.md"

for required_file in "$model" "$ir" "$fixture" "$runtime_fixture" "$docs" "$ledger"; do
    [[ -f "$required_file" ]] || { printf 'config audit: missing %s\n' "$required_file" >&2; exit 1; }
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

rg -Fq 'include "../runtime/config_model.elisa"' "$ir"
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

rg -Fq '`EsConfig` is the pure configuration precedence boundary' "$docs"

printf 'config audit: bounded precedence, aggregate payload ceilings, and deterministic lookup are present\n'
