#!/usr/bin/env bash

# Compiler-free audit for the partitioned migration-root manifest.
# This checks metadata and declared directory boundaries only; it never runs a
# scanner, reads candidate contents, or executes a legacy workflow.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
coding_projects_root="${1:-$(CDPATH= cd -- "$script_dir/../../.." && pwd)}"
roots_file="${2:-$repo_root/docs/migration-project-roots.tsv}"
candidate_file="$script_dir/check_migration_roots.elisascript"
bounded_text_file="$script_dir/../src/runtime/bounded_text_posix.elisa"

if [[ ! -d "$coding_projects_root" ]]; then
    printf 'migration roots audit: coding-projects root does not exist: %s\n' "$coding_projects_root" >&2
    exit 2
fi
if [[ ! -f "$roots_file" ]]; then
    printf 'migration roots audit: manifest does not exist: %s\n' "$roots_file" >&2
    exit 2
fi
if [[ ! -r "$roots_file" ]]; then
    printf 'migration roots audit: unable to read manifest: %s\n' "$roots_file" >&2
    exit 1
fi

canonical_coding_projects_root="$(CDPATH= cd -- "$coding_projects_root" && pwd -P)" || {
    printf 'migration roots audit: unable to canonicalize coding-projects root\n' >&2
    exit 2
}

readonly MAX_MANIFEST_BYTES=1048576
readonly MAX_MANIFEST_ROWS=4096
readonly MAX_FIELD_BYTES=65536
readonly MAX_PATH_BYTES=4096
manifest_bytes="$(LC_ALL=C wc -c < "$roots_file")"
if (( manifest_bytes > MAX_MANIFEST_BYTES )); then
    printf 'migration roots audit: manifest exceeds audit limit\n' >&2
    exit 1
fi

# Keep the candidate's byte budget enforced at the read boundary rather than
# relying only on the metadata preflight below.
if [[ ! -f "$candidate_file" ]]; then
    printf 'migration roots audit: Elisascript candidate is missing\n' >&2
    exit 1
fi
for bounded_read_invariant in \
    'MANIFEST_BYTES: usize = 1048576' \
    'ROWS: usize = 4096' \
    'FIELD_BYTES: usize = 65536' \
    'PATH_BYTES: usize = 4096' \
    'include "../src/runtime/bounded_text_posix.elisa"' \
    'EsBoundedText::read_utf8'; do
    if ! grep -F "$bounded_read_invariant" "$candidate_file" >/dev/null 2>&1; then
        printf 'migration roots audit: candidate source read omits bounded-read invariant: %s\n' "$bounded_read_invariant" >&2
        exit 1
    fi
done
if [[ ! -f "$bounded_text_file" ]]; then
    printf 'migration roots audit: bounded text runtime module is missing\n' >&2
    exit 1
fi
for bounded_read_invariant in \
    'MAX_BYTES: usize = 16777216' \
    'READ_CHUNK_BYTES: usize = 16384' \
    'maximum_bytes - bytes.count' \
    'probe_capacity: usize = remaining + 1' \
    'DarwinOpenFlags::NONBLOCK' \
    'elisascript_posix_fstat' \
    'roots_manifest_stable_file' \
    'EsEncoding::utf8_feed'; do
    if ! grep -F "$bounded_read_invariant" "$bounded_text_file" >/dev/null 2>&1; then
        printf 'migration roots audit: shared bounded reader omits invariant: %s\n' "$bounded_read_invariant" >&2
        exit 1
    fi
done
if grep -F 'read_text(' "$bounded_text_file" >/dev/null 2>&1; then
    printf 'migration roots audit: shared bounded reader uses unbounded read_text\n' >&2
    exit 1
fi
if grep -F 'read_text(' "$candidate_file" >/dev/null 2>&1; then
    printf 'migration roots audit: candidate source read uses unbounded read_text\n' >&2
    exit 1
fi

if ! LC_ALL=C awk -F '\t' -v max_rows="$MAX_MANIFEST_ROWS" -v max_field_bytes="$MAX_FIELD_BYTES" -v max_path_bytes="$MAX_PATH_BYTES" '
    NR == 1 {
        if ($0 != "# name\trelative_path\towner\treview_status") bad = 1
        next
    }
    NF == 0 { next }
    {
        if (NF != 4 || $1 == "" || $2 == "" || $3 == "" || $4 == "") bad = 1
        for (field = 1; field <= NF; field++) if (length($field) > max_field_bytes) bad = 1
        if (length($2) >= max_path_bytes) bad = 1
        if ($2 ~ /^\// || $2 ~ /(^|\/)\.\.(\/|$)/ || $2 ~ /^\.\//) bad = 1
        if ($4 !~ /^(pending|reviewed|blocked)$/) bad = 1
        if ($4 == "reviewed" && $3 == "unassigned") bad = 1
        names[$1]++
        paths[$2]++
        rows++
        if (rows > max_rows) bad = 1
    }
    END {
        for (name in names) if (names[name] != 1) bad = 1
        for (path in paths) if (paths[path] != 1) bad = 1
        if (rows == 0 || bad) exit 1
    }
' "$roots_file"; then
    printf 'migration roots audit: malformed, duplicated, unsafe, or unowned reviewed row\n' >&2
    exit 1
fi

tab="$(printf '\t')"
while IFS="$tab" read -r root_name relative_path owner review_status; do
    [[ "$root_name" == "# name" || -z "$root_name" ]] && continue
    root_path="$coding_projects_root/$relative_path"
    if [[ ! -d "$root_path" ]]; then
        printf 'migration roots audit: declared root is missing: %s\n' "$root_path" >&2
        exit 1
    fi
    canonical_root_path="$(CDPATH= cd -- "$root_path" && pwd -P)" || {
        printf 'migration roots audit: unable to canonicalize declared root: %s\n' "$root_path" >&2
        exit 1
    }
    case "$canonical_root_path" in
        "$canonical_coding_projects_root"|"$canonical_coding_projects_root"/*)
            ;;
        *)
            printf 'migration roots audit: declared root escapes coding-projects tree through a symlink: %s\n' "$root_path" >&2
            exit 1
            ;;
    esac
done < "$roots_file"

printf 'migration roots audit: manifest shape, ownership, and declared directories are valid\n'
