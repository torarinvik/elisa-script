#!/usr/bin/env bash

# Compiler-free audit for the partitioned, read-only migration inventory.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
roots_file="$repo_root/docs/migration-project-roots.tsv"
schema_file="$repo_root/docs/migration-inventory-schema.md"
coordinator="$repo_root/scripts/inventory_project_roots.sh"
review_file="$repo_root/docs/migration-review-current.tsv"
review_audit="$repo_root/scripts/check_migration_review.sh"
roots_audit="$repo_root/scripts/check_migration_roots.sh"

walker_file="$repo_root/scripts/inventory_walk.elisascript"
walker_test="$repo_root/test/script_parity/inventory_walk_test.elisascript"
candidate_file="$repo_root/scripts/inventory_candidates.elisascript"
candidate_fixture="$repo_root/test/fixtures/script_parity/inventory_candidates/EXPECTATIONS.md"

for required_file in "$roots_file" "$schema_file" "$review_file" "$review_audit" "$roots_audit" "$coordinator" "$walker_file" "$walker_test" "$candidate_file" "$candidate_fixture" "$repo_root/scripts/inventory_candidates.sh" "$repo_root/scripts/inventory_signals.sh"; do
    if [[ ! -f "$required_file" ]]; then
        printf 'migration inventory audit: missing %s\n' "$required_file" >&2
        exit 1
    fi
done

if [[ ! -x "$coordinator" ]]; then
    printf 'migration inventory audit: coordinator is not executable\n' >&2
    exit 1
fi
if [[ ! -x "$roots_audit" ]]; then
    printf 'migration inventory audit: root-manifest audit is not executable\n' >&2
    exit 1
fi
if ! rg -q '^# name[[:space:]]+relative_path[[:space:]]+owner[[:space:]]+review_status$' "$roots_file"; then
    printf 'migration inventory audit: root manifest header is invalid\n' >&2
    exit 1
fi

# Validate the complete manifest shape without touching any declared project
# root. Duplicate names/paths would make a combined report ambiguous, and an
# unknown review state would be impossible for downstream migration tooling to
# interpret deterministically.
if ! awk -F '\t' '
    NR == 1 { next }
    NF == 0 { next }
    {
        if (NF != 4) { bad = 1; next }
        if ($1 == "" || $2 == "" || $3 == "" || $4 == "") bad = 1
        if ($2 ~ /^\// || $2 ~ /(^|\/)\.\.(\/|$)/ || $2 ~ /^\.\//) bad = 1
        if ($4 !~ /^(pending|reviewed|blocked)$/) bad = 1
        names[$1]++
        paths[$2]++
        rows++
    }
    END {
        for (name in names) if (names[name] != 1) bad = 1
        for (path in paths) if (paths[path] != 1) bad = 1
        if (rows == 0 || bad) exit 1
    }
' "$roots_file"; then
    printf 'migration inventory audit: manifest rows are malformed, unsafe, duplicated, or use an unknown review state\n' >&2
    exit 1
fi

tab="$(printf '\t')"
for root_name in 'C++ projects' 'Elisa Projects' 'FSharpProjects' 'Go projects' 'Haskell Projects' 'Java Projects' 'Lean Projects' 'Ocaml Projects' 'Python Projects' 'Rust Projects' 'Swift Projects'; do
    if ! rg -Fq "${root_name}${tab}" "$roots_file"; then
        printf 'migration inventory audit: missing declared root %s\n' "$root_name" >&2
        exit 1
    fi
done

if ! rg -q 'inventory_candidates\.sh' "$schema_file" || ! rg -q 'inventory_signals\.sh' "$schema_file" || ! rg -q 'inventory_project_roots\.sh' "$schema_file"; then
    printf 'migration inventory audit: schema omits one of the read-only scanners\n' >&2
    exit 1
fi

# Candidate traversal and signal traversal must inspect the same bounded tree;
# otherwise a dependency directory can bypass the census budget and reappear
# in the emitted candidate stream. The candidate scanner uses `find -name`
# pruning while the signal scanner uses `find -path` pruning; check both
# contracts, plus the shared Elisascript walker's typed exclusion list. Keep
# root-level Makefile classification explicit because a shell case pattern
# containing `*/Makefile` alone misses a Makefile directly at the scan root.
signals_shell="$repo_root/scripts/inventory_signals.sh"
walker_elisascript="$repo_root/scripts/inventory_walk.elisascript"
for excluded_tree in '.git' 'node_modules' '.venv' '__pycache__' 'vendor' 'third_party'; do
    if ! rg -Fq -- "-name '${excluded_tree}'" "$script_dir/inventory_candidates.sh" || \
       ! rg -Fq -- "-path '*/${excluded_tree}'" "$signals_shell" || \
       ! rg -Fq -- "name == \"${excluded_tree}\"" "$walker_elisascript"; then
        printf 'migration inventory audit: candidate scanner does not exclude %s consistently\n' "$excluded_tree" >&2
        exit 1
    fi
done
if ! rg -q 'Makefile\|makefile\|\*/Makefile\|\*/makefile' "$script_dir/inventory_candidates.sh"; then
    printf 'migration inventory audit: candidate scanner misses root-level Makefiles\n' >&2
    exit 1
fi

# Both Elisascript inventories share the descriptor-relative walker. Do not
# quietly reintroduce a buffered `find` path stream into either candidate.
for candidate in "$repo_root/scripts/inventory_candidates.elisascript" "$repo_root/scripts/inventory_signals.elisascript"; do
    if ! rg -Fq 'include "./inventory_walk.elisascript"' "$candidate"; then
        printf 'migration inventory audit: %s does not include the shared native walker\n' "$candidate" >&2
        exit 1
    fi
    if rg -q 'exe"find"|find_base_arguments|find -print0' "$candidate"; then
        printf 'migration inventory audit: %s reintroduces a find-backed path capture\n' "$candidate" >&2
        exit 1
    fi
done
for walker_invariant in 'openat' 'fstatat' 'DarwinStatMode::SYMLINK' 'DIRECTORY_ENTRIES' 'DIRECTORY_DEPTH' 'PATH_BYTES' 'elisascript_posix_closedir' 'Phase.Unwind'; do
    if ! rg -Fq "$walker_invariant" "$walker_file"; then
        printf 'migration inventory audit: shared walker is missing invariant %s\n' "$walker_invariant" >&2
        exit 1
    fi
done
for walker_case in 'RegularFileLimitExceeded' 'DirectoryLimitExceeded' 'EntryLimitExceeded' 'DepthExceeded' 'PathBytesExceeded' 'SelectedPathBytesExceeded' 'InvalidPolicy'; do
    if ! rg -Fq "DirectoryWalkFailure::$walker_case" "$walker_test"; then
        printf 'migration inventory audit: shared walker tests omit policy case %s\n' "$walker_case" >&2
        exit 1
    fi
done
if ! rg -q 'required_mode_bits' "$repo_root/scripts/inventory_signals.elisascript" || ! rg -q 'suffixes: \[' "$repo_root/scripts/inventory_candidates.elisascript"; then
    printf 'migration inventory audit: scanners do not configure the shared walker's typed selectors\n' >&2
    exit 1
fi

# The Bash oracle uses `sort -u`, so a native walker must not merely sort the
# selected paths: a future backend or duplicated dirent must not duplicate a
# manifest row. Require a bounded sort-then-adjacent-scan implementation and
# pin the same invariant in the source-only fixture contract.
for candidate_invariant in \
    'def sorted_unique_paths' \
    'ordered: darray[sview] = sorted(values)' \
    'unique: mutable darray[sview] = []' \
    'unique[unique.count - 1] != value' \
    'ordered_paths <- sorted_unique_paths(candidate_paths)'; do
    if ! rg -Fq "$candidate_invariant" "$candidate_file"; then
        printf 'migration inventory audit: candidate is missing sorted adjacent-dedup invariant %s\n' "$candidate_invariant" >&2
        exit 1
    fi
done
if ! rg -Fq 'bounded adjacent-dedup' "$candidate_fixture" || ! rg -Fq 'sort -u' "$candidate_fixture"; then
    printf 'migration inventory audit: candidate fixture does not pin sort -u uniqueness semantics\n' >&2
    exit 1
fi

bash -n "$coordinator" "$script_dir/inventory_candidates.sh" "$script_dir/inventory_signals.sh" "$review_audit" "$roots_audit"
if ! rg -q 'check_migration_roots\.sh' "$roots_audit" "$schema_file"; then
    printf 'migration inventory audit: root ownership audit is not documented\n' >&2
    exit 1
fi
for containment_file in "$coordinator" "$roots_audit"; do
    if ! rg -q 'pwd -P' "$containment_file" || ! rg -q 'canonical_root_path' "$containment_file" || ! rg -q 'escapes coding-projects tree' "$containment_file"; then
        printf 'migration inventory audit: %s lacks canonical root containment checks\n' "$containment_file" >&2
        exit 1
    fi
done
if ! rg -q 'NR == 1' "$coordinator" || ! rg -q 'names\[\$1\]\+\+' "$coordinator" || ! rg -q 'paths\[\$2\]\+\+' "$coordinator" || ! rg -q 'reviewed.*unassigned' "$coordinator"; then
    printf 'migration inventory audit: coordinator lacks fail-closed manifest preflight\n' >&2
    exit 1
fi
printf 'migration inventory audit: partition manifest and bounded read-only scanners present\n'
