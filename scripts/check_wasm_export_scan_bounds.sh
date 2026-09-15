#!/bin/sh

# Source-only audit for the W09 candidate's aggregate scanner work ceilings. This
# script intentionally does not compile or run Elisascript fixtures.
set -eu

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
candidate="$repo_root/scripts/wasm_export_scan.elisascript"
fixture="$repo_root/test/script_parity/wasm_export_scan_test.elisascript"
contract="$repo_root/test/fixtures/script_parity/wasm_export_scan/CONTRACT.md"

for required_file in "$candidate" "$fixture" "$contract"; do
    if [ ! -f "$required_file" ]; then
        printf 'W09 bounds audit: missing %s\n' "$required_file" >&2
        exit 1
    fi
done

rg -Fq 'SOURCE_LINES: usize = 131072' "$candidate"
rg -Fq 'def source_lines(source: sview) -> (lines: darray[sview], failure: sview)' "$candidate"
rg -Fq 'parsed_lines.failure != ""' "$candidate"
rg -Fq 'WASM source line count exceeds Elisascript scan limit' "$candidate"
rg -Fq 'PARAMETERS_PER_EXPORT: usize = 4096' "$candidate"
rg -Fq 'TOTAL_PARAMETERS: usize = 16384' "$candidate"
rg -Fq 'parameter_slices.count > Limits::PARAMETERS_PER_EXPORT' "$candidate"
rg -Fq 'WASM export parameter count exceeds Elisascript scan limit' "$candidate"
rg -Fq 'explicit.row.parameters.count > Limits::TOTAL_PARAMETERS - total_parameters' "$candidate"
rg -Fq 'implicit.row.parameters.count > Limits::TOTAL_PARAMETERS - total_parameters' "$candidate"
rg -Fq 'WASM total export parameter count exceeds Elisascript scan limit' "$candidate"
rg -Fq 'INCLUDE_DEPTH: usize = 128' "$candidate"
rg -Fq 'frames.count >= Limits::INCLUDE_DEPTH' "$candidate"
rg -Fq 'WASM include depth exceeds Elisascript scan limit' "$candidate"
rg -Fq 'INCLUDE_DIRECTIVES: usize = 16384' "$candidate"
rg -Fq 'include_directives >= Limits::INCLUDE_DIRECTIVES' "$candidate"
rg -Fq 'WASM include directive count exceeds Elisascript scan limit' "$candidate"
rg -Fq 'PATH_SYMLINK_HOPS: usize = 128' "$candidate"
rg -Fq 'symlink_hops > Limits::PATH_SYMLINK_HOPS' "$candidate"
rg -Fq 'WASM symlink resolution exceeds Elisascript scan limit' "$candidate"
line_guard_count="$(rg -F -c 'if lines.count >= Limits::SOURCE_LINES:' "$candidate" || true)"
if [ "$line_guard_count" != 2 ]; then
    printf 'W09 bounds audit: both source-line append sites must enforce the metadata cap\n' >&2
    exit 1
fi
parameter_guard_count="$(rg -F -c 'if parameter_slices.count > Limits::PARAMETERS_PER_EXPORT:' "$candidate" || true)"
if [ "$parameter_guard_count" != 2 ]; then
    printf 'W09 bounds audit: explicit and implicit exports must enforce the parameter cap\n' >&2
    exit 1
fi

rg -Fq 'HEADER_SCAN_WORK: usize = 1048576' "$candidate"
rg -Fq 'HEADER_SUFFIX_SCAN_FACTOR: usize = 8' "$candidate"
rg -Fq 'HEADER_SUFFIX_FIXED_WORK: usize = 16' "$candidate"
rg -Fq 'def header_scan_charge(work: mutable usize&, amount: usize) -> bool' "$candidate"
rg -Fq 'def header_suffix_scan_charge(work: mutable usize&, remaining_bytes: usize) -> bool' "$candidate"
rg -Fq 'def export_header(line: sview, header_work: mutable usize&) -> ExportHeader' "$candidate"
rg -Fq 'def main_header(line: sview, header_work: mutable usize&) -> MainHeader' "$candidate"
rg -Fq 'def parse_export_line(line: sview, line_number: usize, pending_link_name: sview, has_pending_link_name: bool, seen_names: darray[sview], header_work: mutable usize&, name_work: mutable usize&)' "$candidate"
rg -Fq 'def parse_implicit_main(line: sview, line_number: usize, main_seen: bool, header_work: mutable usize&)' "$candidate"
rg -Fq 'header_work: mutable usize = 0' "$candidate"
rg -Fq 'Shared across the flattened source, including all include files.' "$candidate"
rg -Fq 'amount > Limits::HEADER_SCAN_WORK - work' "$candidate"
rg -Fq 'remaining_bytes > available / Limits::HEADER_SUFFIX_SCAN_FACTOR' "$candidate"
rg -Fq 'WASM header scan work exceeds Elisascript scan limit' "$candidate"
rg -Fq 'EXPORT_NAME_COMPARE_WORK: usize = 1048576' "$candidate"
rg -Fq 'def export_name_scan_charge(work: mutable usize&, compared_bytes: usize) -> bool' "$candidate"
rg -Fq 'compared_bytes > Limits::EXPORT_NAME_COMPARE_WORK - work' "$candidate"
rg -Fq 'WASM export-name comparison work exceeds Elisascript scan limit' "$candidate"
rg -Fq 'name_work: mutable usize = 0' "$candidate"
rg -Fq 'main_seen: mutable bool = false' "$candidate"
rg -Fq 'main_seen <- true if explicit.row.name == "main"' "$candidate"
rg -Fq 'parse_implicit_main(line, line_number, main_seen, header_work)' "$candidate"
rg -Fq 'export_name_scan_charge(name_work, compared_bytes)' "$candidate"
rg -Fq 'parse_export_line(line, line_number, pending_link_name, has_pending_link_name, seen_names, header_work, name_work)' "$candidate"
rg -Fq 'Every scanned identifier is nonempty' "$candidate"
if rg -Fq 'seen_names.contains("main")' "$candidate"; then
    printf 'W09 bounds audit: main presence must not rescan the export-name vector\n' >&2
    exit 1
fi

suffix_charge_count="$(rg -F -c 'if not header_suffix_scan_charge(header_work, suffix_bytes):' "$candidate" || true)"
failure_propagation_count="$(rg -F -c 'if header.failure != "":' "$candidate" || true)"
if [ "$suffix_charge_count" != 2 ] || [ "$failure_propagation_count" != 2 ]; then
    printf 'W09 bounds audit: both explicit-export and implicit-main paths must charge and propagate the guard\n' >&2
    exit 1
fi

rg -Fq 'def header_scan_work_cases_reject_pathologically_expensive_suffixes()' "$fixture"
rg -Fq 'def header_scan_work_aggregates_across_source_headers()' "$fixture"
rg -Fq 'def wasm_export_scan_aggregates_header_scan_work_across_source()' "$fixture"
rg -Fq 'def export_name_comparison_work_is_bounded()' "$fixture"
rg -Fq 'def wasm_export_scan_bounds_unique_export_name_comparison_work()' "$fixture"
rg -Fq 'def main_seen_order_cases_match_python()' "$fixture"
rg -Fq 'def wasm_export_scan_preserves_main_seen_ordering()' "$fixture"
rg -Fq 'repeated_implicit_matches <- scanner_pair_matches' "$fixture"
rg -Fq 'def source_line_descriptor_count_is_bounded()' "$fixture"
rg -Fq 'def wasm_export_scan_bounds_line_descriptor_count()' "$fixture"
rg -Fq 'def parameter_count_is_bounded()' "$fixture"
rg -Fq 'def wasm_export_scan_bounds_parameter_count()' "$fixture"
rg -Fq 'def total_parameter_count_is_bounded()' "$fixture"
rg -Fq 'def wasm_export_scan_bounds_total_parameter_count()' "$fixture"
rg -Fq 'WASM total export parameter count exceeds Elisascript scan limit' "$fixture"
rg -Fq 'for index in 0..<4097 |source_bytes, index|' "$fixture"
rg -Fq 'WASM export parameter count exceeds Elisascript scan limit' "$fixture"
rg -Fq 'def include_depth_is_bounded()' "$fixture"
rg -Fq 'def wasm_export_scan_bounds_include_depth()' "$fixture"
rg -Fq 'for index in 0..<129 |temporary_root, attempted_files, all_written, index|' "$fixture"
rg -Fq 'WASM include depth exceeds Elisascript scan limit' "$fixture"
rg -Fq 'def include_directive_count_is_bounded()' "$fixture"
rg -Fq 'append_repeated_source_text(include_source' "$fixture"
rg -Fq '16385)' "$fixture"
rg -Fq 'WASM include directive count exceeds Elisascript scan limit' "$fixture"
rg -Fq 'def wasm_export_scan_bounds_include_directive_count()' "$fixture"
rg -Fq 'def dangling_symlink_include_cases_match()' "$fixture"
rg -Fq 'def dangling_symlink_cycle_is_bounded()' "$fixture"
rg -Fq 'def wasm_export_scan_bounds_dangling_symlink_cycles()' "$fixture"
rg -Fq 'def dangling_symlink_expansion_work_is_bounded()' "$fixture"
rg -Fq 'def wasm_export_scan_bounds_dangling_symlink_expansion_work()' "$fixture"
rg -Fq 'assert EsWasmExportScanParity::dangling_symlink_expansion_work_is_bounded()' "$fixture"
rg -Fq 'for index in 0..<60 |temporary_root, all_links_created, link_paths, index|' "$fixture"
rg -Fq 'append_repeated_source_text(target_bytes, "./", 400)' "$fixture"
rg -Fq 'WASM path component work exceeds Elisascript scan limit' "$fixture"
rg -Fq 'wasm export scan: WASM path component work exceeds Elisascript scan limit' "$fixture"
rg -Fq 'links/parent-tail-link/../child.input' "$fixture"
rg -Fq 'links/nested-link/child.input' "$fixture"
rg -Fq 'relative_link: Path = links_directory.joinpath("relative-link")' "$fixture"
rg -Fq 'create_fixture_symlink(path("../missing/../actual"), relative_link)' "$fixture"
rg -Fq 'create_fixture_symlink(path("../missing/../actual/subdir"), parent_tail_link)' "$fixture"
rg -Fq 'absolute_target: sview = f"{temporary_root}/missing/../actual"' "$fixture"
rg -Fq 'wasm export scan: WASM symlink resolution exceeds Elisascript scan limit' "$fixture"
rg -Fq 'def append_source_text(output: mutable darray[u8]&, value: sview)' "$fixture"
rg -Fq 'def append_repeated_source_text(output: mutable darray[u8]&, value: sview, repetitions: usize)' "$fixture"
rg -Fq 'for _ in 0..<512 |export_header_bytes|' "$fixture"
rg -Fq 'for _ in 0..<512 |implicit_main_bytes|' "$fixture"
rg -Fq 'append_repeated_source_text(source_bytes, "x", 600000)' "$fixture"
rg -Fq 'return export_frame == expected_frame and implicit_main_frame == expected_frame' "$fixture"
rg -Fq 'assert EsWasmExportScanParity::header_scan_work_aggregates_across_source_headers()' "$fixture"
rg -Fq 'for index in 0..<1024 |source_bytes, index|' "$fixture"
rg -Fq 'assert EsWasmExportScanParity::export_name_comparison_work_is_bounded()' "$fixture"
rg -Fq 'assert EsWasmExportScanParity::main_seen_order_cases_match_python()' "$fixture"
rg -Fq 'for _ in 0..<131072 |source_bytes|' "$fixture"
rg -Fq 'source_bytes.push(10u8)' "$fixture"
rg -Fq 'expected_limit_frame' "$fixture"
rg -Fq 'expected_over_limit_frame' "$fixture"
rg -Fq 'assert EsWasmExportScanParity::source_line_descriptor_count_is_bounded()' "$fixture"
rg -Fq '1,048,576' "$contract"
rg -Fq 'aggregate weighted work ceiling' "$contract"
rg -Fq 'multiple' "$contract"
rg -Fq 'case chains 60 relative links whose targets each contain 400 `./` components' "$contract"

printf 'W09 bounds audit: include depth/directives, symlink expansion, parameter counts, source lines, header scans, and export-name scans have bounded-resource coverage\n'
