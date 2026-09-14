#!/bin/sh

# Source-only audit for the W09 candidate's greedy-header work ceiling. This
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

rg -Fq 'HEADER_SCAN_WORK: usize = 1048576' "$candidate"
rg -Fq 'HEADER_SUFFIX_SCAN_FACTOR: usize = 8' "$candidate"
rg -Fq 'HEADER_SUFFIX_FIXED_WORK: usize = 16' "$candidate"
rg -Fq 'def header_scan_charge(work: mutable usize&, amount: usize) -> bool' "$candidate"
rg -Fq 'def header_suffix_scan_charge(work: mutable usize&, remaining_bytes: usize) -> bool' "$candidate"
rg -Fq 'def export_header(line: sview, header_work: mutable usize&) -> ExportHeader' "$candidate"
rg -Fq 'def main_header(line: sview, header_work: mutable usize&) -> MainHeader' "$candidate"
rg -Fq 'def parse_export_line(line: sview, line_number: usize, pending_link_name: sview, has_pending_link_name: bool, seen_names: darray[sview], header_work: mutable usize&)' "$candidate"
rg -Fq 'def parse_implicit_main(line: sview, line_number: usize, main_seen: bool, header_work: mutable usize&)' "$candidate"
rg -Fq 'header_work: mutable usize = 0' "$candidate"
rg -Fq 'Shared across the flattened source, including all include files.' "$candidate"
rg -Fq 'amount > Limits::HEADER_SCAN_WORK - work' "$candidate"
rg -Fq 'remaining_bytes > available / Limits::HEADER_SUFFIX_SCAN_FACTOR' "$candidate"
rg -Fq 'WASM header scan work exceeds Elisascript scan limit' "$candidate"

suffix_charge_count="$(rg -F -c 'if not header_suffix_scan_charge(header_work, suffix_bytes):' "$candidate" || true)"
failure_propagation_count="$(rg -F -c 'if header.failure != "":' "$candidate" || true)"
if [ "$suffix_charge_count" != 2 ] || [ "$failure_propagation_count" != 2 ]; then
    printf 'W09 bounds audit: both explicit-export and implicit-main paths must charge and propagate the guard\n' >&2
    exit 1
fi

rg -Fq 'def header_scan_work_cases_reject_pathologically_expensive_suffixes()' "$fixture"
rg -Fq 'def header_scan_work_aggregates_across_source_headers()' "$fixture"
rg -Fq 'def wasm_export_scan_aggregates_header_scan_work_across_source()' "$fixture"
rg -Fq 'def append_source_text(output: mutable darray[u8]&, value: sview)' "$fixture"
rg -Fq 'def append_repeated_source_text(output: mutable darray[u8]&, value: sview, repetitions: usize)' "$fixture"
rg -Fq 'for _ in 0..<512 |export_header_bytes|' "$fixture"
rg -Fq 'for _ in 0..<512 |implicit_main_bytes|' "$fixture"
rg -Fq 'append_repeated_source_text(source_bytes, "x", 600000)' "$fixture"
rg -Fq 'return export_frame == expected_frame and implicit_main_frame == expected_frame' "$fixture"
rg -Fq 'assert EsWasmExportScanParity::header_scan_work_aggregates_across_source_headers()' "$fixture"
rg -Fq '1,048,576' "$contract"
rg -Fq 'aggregate weighted work ceiling' "$contract"
rg -Fq 'multiple' "$contract"

printf 'W09 bounds audit: explicit and implicit greedy-header scans have candidate-only aggregate bounded-work coverage\n'
