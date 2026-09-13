# Builtin-surface port fixtures

Pass the absolute fixture root as the one argument to both
`scripts/check_builtin_surface.sh` and the public Elisascript launcher using
`scripts/check_builtin_surface.elisascript`. The candidate and reference should
have the following observable results. These expectations are static and have
not been executed while compiler validation is suspended.

| Fixture | Status | Stdout | Stderr |
| --- | ---: | --- | --- |
| `positive` | 0 | `semantic_seed_count\t4\nlowerer_global_count\t1\nbuiltin surface audit: semantic seeds cover all direct global spellings; registry identity handles global lowering\n` | empty |
| `missing_registry_row` | 1 | `semantic_seed_count\t1\nlowerer_global_count\t1\n` | `missing_registry_row\tlegacy_call\n` |
| `mismatched_consumer` | 1 | `semantic_seed_count\t1\nlowerer_global_count\t1\n` | `missing_registry_row\tunregistered_call\nmissing_semantic_seed\tunregistered_call\n` |

`missing_registry_row` keeps the direct consumer in the legacy semantic seed
while removing it from `typed_builtin_names()`. This fixture proves that the
audit checks registry identity instead of passing solely because the old seed
still masks the missing row. `mismatched_consumer` adds a direct lowerer spelling
that appears in neither authority and must report both gaps.
