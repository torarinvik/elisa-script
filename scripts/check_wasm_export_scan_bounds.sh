#!/bin/sh

# Source-only audit for the W09 candidate's aggregate scanner work ceilings. This
# script intentionally does not compile or run Elisascript fixtures.
set -eu

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
candidate="$repo_root/scripts/wasm_export_scan.elisascript"
fixture="$repo_root/test/script_parity/wasm_export_scan_test.elisascript"
launcher_fixture="$repo_root/test/script_parity/wasm_export_scan_launcher_test.elisascript"
reference="$repo_root/scripts/wasm_export_scan_reference.py"
contract="$repo_root/test/fixtures/script_parity/wasm_export_scan/CONTRACT.md"
unicode_data="$repo_root/src/runtime/unicode16_printability.elisa"
unicode_boundary_fixture="$repo_root/test/fixtures/script_parity/wasm_export_scan/unicode16_boundary_repr.input"

for required_file in "$candidate" "$fixture" "$launcher_fixture" "$reference" "$contract" "$unicode_data" "$unicode_boundary_fixture"; do
    if [ ! -f "$required_file" ]; then
        printf 'W09 bounds audit: missing %s\n' "$required_file" >&2
        exit 1
    fi
done

unicode_fixture_bytes="$(wc -c < "$unicode_boundary_fixture" | tr -d '[:space:]')"
unicode_fixture_lines="$(wc -l < "$unicode_boundary_fixture" | tr -d '[:space:]')"
unicode_boundary_pair_count="$(rg -F -c 'scanner_pair_matches("test/fixtures/script_parity/wasm_export_scan/unicode16_boundary_repr.input")' "$fixture" || true)"
if [ "$unicode_fixture_bytes" -gt 32768 ] || [ "$unicode_fixture_lines" -ne 1 ] || [ "$unicode_boundary_pair_count" != 1 ]; then
    printf 'W09 Unicode audit: boundary parity fixture must stay one line, <=32 KiB, and run as one pair\n' >&2
    exit 1
fi

rg -Fq 'SOURCE_BYTES: usize = 8388608' "$candidate"
rg -Fq 'SOURCE_LINES: usize = 131072' "$candidate"
rg -Fq 'if len(source) > Limits::SOURCE_BYTES:' "$candidate"
rg -Fq 'append_text(output, frame.source[line_start:line_end], Limits::SOURCE_BYTES)' "$candidate"
rg -Fq 'def source_lines(source: sview) -> (lines: darray[sview], failure: sview)' "$candidate"
rg -Fq 'parsed_lines.failure != ""' "$candidate"
rg -Fq 'WASM source line count exceeds Elisascript scan limit' "$candidate"
rg -Fq 'PARAMETERS_PER_EXPORT: usize = 4096' "$candidate"
rg -Fq 'TOTAL_PARAMETERS: usize = 16384' "$candidate"
rg -Fq 'FLATTEN_PAYLOAD_OPTION: sview = "--flatten-payload"' "$candidate"
rg -Fq 'BUILD_COMPONENT_PAYLOAD_OPTION: sview = "--build-component-payload"' "$candidate"
rg -Fq 'COMPONENT_OPTION: sview = "--component"' "$candidate"
rg -Fq 'def split_top_level(text: sview, delimiter: u8, maximum_parts: usize) -> TopLevelSplit' "$candidate"
rg -Fq 'if parts.count >= maximum_parts:' "$candidate"
rg -Fq 'parameter_split.exceeded_limit' "$candidate"
rg -Fq 'split_top_level(header.parameters, 44u8, Limits::PARAMETERS_PER_EXPORT)' "$candidate"
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
rg -Fq 'INCLUDE_FILES: usize = 4096' "$candidate"
rg -Fq 'loaded_files >= Limits::INCLUDE_FILES' "$candidate"
rg -Fq 'WASM include file count exceeds Elisascript scan limit' "$candidate"
rg -Fq 'include "../src/runtime/file_posix.elisa"' "$candidate"
rg -Fq 'include "../src/runtime/directory_posix.elisa"' "$candidate"
rg -Fq 'include "../src/runtime/stdio_posix.elisa"' "$candidate"
rg -Fq 'SOURCE_READ_CHUNK_BYTES: usize = 16384' "$candidate"
rg -Fq 'CALLER_PAYLOAD_BYTES: usize = 67108863' "$candidate"
rg -Fq 'elif byte < 32u8:' "$candidate"
rg -Fq 'return false if not append_text(output, "\\u00", limit)' "$candidate"
rg -Fq 'SOURCE_READ_EINTR_RETRIES: usize = 4' "$candidate"
rg -Fq 'def read_bounded_source(input_path: Path, maximum_bytes: usize) -> BoundedSourceRead' "$candidate"
rg -Fq 'DarwinOpenFlags::RDONLY | DarwinOpenFlags::NONBLOCK | DarwinOpenFlags::NOFOLLOW | DarwinOpenFlags::CLOSE_ON_EXEC' "$candidate"
rg -Fq 'def open_bounded_source_descriptor(path: cstr, flags: int) -> int' "$candidate"
rg -Fq 'errno[0] == DarwinErrno::EINTR and retries < Limits::SOURCE_READ_EINTR_RETRIES' "$candidate"
rg -Fq 'errno[0] == DarwinErrno::EINTR and interrupted_reads < Limits::SOURCE_READ_EINTR_RETRIES' "$candidate"
rg -Fq 'def stat_bounded_source_path(path: cstr, result: mutable ElisascriptStat&) -> bool' "$candidate"
rg -Fq 'def fstat_bounded_source_descriptor(descriptor: int, result: mutable ElisascriptStat&) -> bool' "$candidate"
rg -Fq 'def source_file_snapshot_matches(left: ElisascriptStat, right: ElisascriptStat) -> bool' "$candidate"
rg -Fq 'left.size != right.size' "$candidate"
rg -Fq 'left.modify_time.seconds != right.modify_time.seconds or left.modify_time.nanoseconds != right.modify_time.nanoseconds' "$candidate"
rg -Fq 'left.change_time.seconds != right.change_time.seconds or left.change_time.nanoseconds != right.change_time.nanoseconds' "$candidate"
rg -Fq 'elisascript_posix_stat(path, result)' "$candidate"
rg -Fq 'elisascript_posix_fstat(descriptor, result)' "$candidate"
rg -Fq 'stat_bounded_source_path(path_pointer, named_before_open)' "$candidate"
rg -Fq 'stat_bounded_source_path(path_pointer, named_after_open)' "$candidate"
rg -Fq 'fstat_bounded_source_descriptor(descriptor, opened_stat)' "$candidate"
rg -Fq 'fstat_bounded_source_descriptor(descriptor, completed_stat)' "$candidate"
rg -Fq 'stat_bounded_source_path(path_pointer, named_completed_stat)' "$candidate"
rg -Fq 'source_file_snapshot_matches(opened_stat, completed_stat)' "$candidate"
rg -Fq 'source_file_snapshot_matches(opened_stat, named_completed_stat)' "$candidate"
eof_branch_line="$(awk '/if amount == 0:/ { print NR; exit }' "$candidate")"
eof_fstat_line="$(awk -v start="$eof_branch_line" 'NR > start && /fstat_bounded_source_descriptor\(descriptor, completed_stat\)/ { print NR; exit }' "$candidate")"
eof_descriptor_snapshot_line="$(awk -v start="$eof_branch_line" 'NR > start && /source_file_snapshot_matches\(opened_stat, completed_stat\)/ { print NR; exit }' "$candidate")"
eof_path_stat_line="$(awk -v start="$eof_branch_line" 'NR > start && /stat_bounded_source_path\(path_pointer, named_completed_stat\)/ { print NR; exit }' "$candidate")"
eof_path_snapshot_line="$(awk -v start="$eof_branch_line" 'NR > start && /source_file_snapshot_matches\(opened_stat, named_completed_stat\)/ { print NR; exit }' "$candidate")"
eof_close_line="$(awk -v start="$eof_branch_line" 'NR > start && /if elisascript_posix_close\(descriptor\) != 0:/ { print NR; exit }' "$candidate")"
eof_accept_line="$(awk -v start="$eof_branch_line" 'NR > start && /return BoundedSourceRead\{source: bytes_view\(source\)\}/ { print NR; exit }' "$candidate")"
if [ -z "$eof_branch_line" ] || [ -z "$eof_fstat_line" ] || [ -z "$eof_descriptor_snapshot_line" ] || [ -z "$eof_path_stat_line" ] || [ -z "$eof_path_snapshot_line" ] || [ -z "$eof_close_line" ] || [ -z "$eof_accept_line" ] || \
    [ "$eof_branch_line" -ge "$eof_fstat_line" ] || [ "$eof_fstat_line" -gt "$eof_descriptor_snapshot_line" ] || \
    [ "$eof_descriptor_snapshot_line" -ge "$eof_path_stat_line" ] || [ "$eof_path_stat_line" -gt "$eof_path_snapshot_line" ] || \
    [ "$eof_path_snapshot_line" -ge "$eof_close_line" ] || [ "$eof_close_line" -ge "$eof_accept_line" ]; then
    printf 'W09 bounds audit: EOF snapshot checks must precede descriptor close and source acceptance\n' >&2
    exit 1
fi
rg -Fq 'probe_capacity: usize = remaining + 1' "$candidate"
rg -Fq 'capacity: usize = probe_capacity if probe_capacity < chunk.count else chunk.count' "$candidate"
rg -Fq 'source.reserve(initial_source_capacity)' "$candidate"
rg -Fq 'elisascript_posix_read(descriptor, chunk_pointer.cast[mutable void&], capacity)' "$candidate"
rg -Fq 'if read_count > remaining:' "$candidate"
rg -Fq 'elisascript_posix_fstat(descriptor, opened_stat)' "$candidate"
rg -Fq 'source_file_identity_matches(named_before_open, opened_stat)' "$candidate"
rg -Fq 'source_file_identity_matches(opened_stat, named_after_open)' "$candidate"
rg -Fq 'elisascript_posix_close(descriptor)' "$candidate"
if rg -Fq 'FileStream' "$candidate"; then
    printf 'W09 bounds audit: source reads must not use a path-based stdio stream\n' >&2
    exit 1
fi
if rg -Fq 'read_text(current_path)' "$candidate"; then
    printf 'W09 bounds audit: include sources must not use unbounded whole-file reads\n' >&2
    exit 1
fi
rg -Fq 'def oversized_source_file_is_rejected_by_bounded_reader()' "$fixture"
rg -Fq 'for _ in 0..<8388609 |source_bytes|' "$fixture"
rg -Fq 'wasm_export_scan_bounds_oversized_source_file_reads' "$fixture"
rg -Fq 'def aggregate_include_graph_bytes_are_bounded()' "$fixture"
rg -Fq 'for _ in 0..<8388608 |child_bytes|' "$fixture"
rg -Fq 'WASM include graph exceeds Elisascript scan limit' "$fixture"
rg -Fq 'wasm_export_scan_bounds_aggregate_include_graph_reads' "$fixture"
rg -Fq 'def structured_output_overflow_is_bounded()' "$fixture"
rg -Fq 'expected_source_bytes < 8388608usize' "$fixture"
rg -Fq 'return source_written == expected_source_bytes and expected_source_bytes < 8388608usize and candidate_frame == expected_frame and removed_source and removed_root_directory' "$fixture"
rg -Fq 'append_source_text(source_bytes, "export fn overflow(value: ")' "$fixture"
rg -Fq 'for _ in 0..<6291456 |source_bytes|' "$fixture"
rg -Fq 'EsWasmExportScan::differential_build_payload_response(source_file, true)' "$fixture"
rg -Fq 'structured output exceeds Elisascript scan limit' "$fixture"
rg -Fq 'wasm_export_scan_bounds_structured_payload_output' "$fixture"
rg -Fq 'remaining_graph_bytes: usize = Limits::INCLUDE_GRAPH_BYTES - loaded_bytes' "$candidate"
rg -Fq 'if remaining_graph_bytes < read_limit:' "$candidate"
rg -Fq 'loaded_bytes <- loaded_bytes + len(raw_source)' "$candidate"
rg -Fq 'PATH_SYMLINK_HOPS: usize = 128' "$candidate"
rg -Fq 'symlink_hops > Limits::PATH_SYMLINK_HOPS' "$candidate"
rg -Fq 'WASM symlink resolution exceeds Elisascript scan limit' "$candidate"
rg -Fq 'def resolve_non_strict(input_path: Path, path_component_work: mutable usize&) -> PathResolution' "$candidate"
rg -Fq 'symbolic_link: bool = is_symlink(candidate)' "$candidate"
rg -Fq 'if not exists and symbolic_link:' "$candidate"
rg -Fq 'target_path: Path = try readlink(candidate) else err:' "$candidate"
rg -Fq 'target_components: darray[sview] = path_components(target_text)' "$candidate"
rg -Fq 'path_component_work <- path_component_work + expansion_work' "$candidate"
rg -Fq 'resolved_component: Path = try path_real(candidate) else err:' "$candidate"
rg -Fq 'def symlink_include_cases_match()' "$fixture"
rg -Fq 'symlink_parent_written: usize = write_fixture_text(source_file, "include \"alias/../child.input\"\n")' "$fixture"
rg -Fq 'def dangling_symlink_include_cases_match()' "$fixture"
rg -Fq 'resolves every existing component before processing a following `..`' "$contract"
rg -Fq 'dangling symlink, it reads the link target and prepends that' "$contract"
rg -Fq 'include "../src/runtime/unicode16_printability.elisa"' "$candidate"
rg -Fq 'EsUnicode16Printability::is_nonprintable(codepoint)' "$candidate"
rg -Fq 'UCD_VERSION: sview = "16.0.0"' "$unicode_data"
rg -Fq 'RANGE_COUNT: usize = 737' "$unicode_data"
rg -Fq 'NONPRINTABLE_STARTS: u32[737]' "$unicode_data"
rg -Fq 'NONPRINTABLE_ENDS: u32[737]' "$unicode_data"
rg -Fq 'middle <- lower + ((upper - lower) / 2)' "$unicode_data"
rg -Fq 'def range_boundary_contract() -> bool' "$unicode_data"
rg -Fq 'lookup_nonprintable(first) or not lookup_nonprintable(middle) or not lookup_nonprintable(last)' "$unicode_data"
rg -Fq 'previous_end != 1114111' "$unicode_data"
rg -Fq 'index == 0 and first != 0' "$unicode_data"
rg -Fq 'assert EsUnicode16Printability::range_boundary_contract()' "$fixture"
rg -Fq 'scanner_pair_matches("test/fixtures/script_parity/wasm_export_scan/unicode16_boundary_repr.input")' "$fixture"
rg -Fq 'source_bytes.push(0u8)' "$fixture"
rg -Fq 'source_bytes.push(1u8)' "$fixture"
rg -Fq 'source_bytes.push(15u8)' "$fixture"
rg -Fq 'source_bytes.push(31u8)' "$fixture"
rg -Fq 'source_bytes.push(127u8)' "$fixture"
rg -Fq 'append_source_text(spacing_bytes, "export fn invalid(value !~")' "$fixture"
rg -Fq 'export fn unicode_boundary(x' "$unicode_boundary_fixture"
rg -Fq 'y: int) -> void = unicode_boundary' "$unicode_boundary_fixture"
rg -Fq 'U+0378..U+0379 unassigned gap' "$fixture"
rg -Fq 'fixture now concatenates every range start, midpoint, end, and immediate' "$contract"
if rg -Fq 'python_extra_nonprintable' "$candidate"; then
    printf 'W09 Unicode audit: remove hand-maintained printability exceptions\n' >&2
    exit 1
fi
line_guard_count="$(rg -F -c 'if lines.count >= Limits::SOURCE_LINES:' "$candidate" || true)"
if [ "$line_guard_count" != 2 ]; then
    printf 'W09 bounds audit: both source-line append sites must enforce the metadata cap\n' >&2
    exit 1
fi
split_guard_count="$(rg -F -c 'if parts.count >= maximum_parts:' "$candidate" || true)"
if [ "$split_guard_count" != 2 ]; then
    printf 'W09 bounds audit: separator and final parameter slices must be rejected before append\n' >&2
    exit 1
fi
split_call_count="$(rg -F -c 'split_top_level(header.parameters, 44u8, Limits::PARAMETERS_PER_EXPORT)' "$candidate" || true)"
if [ "$split_call_count" != 2 ]; then
    printf 'W09 bounds audit: explicit and implicit exports must use the per-export split limit\n' >&2
    exit 1
fi
parameter_guard_count="$(rg -F -c 'if parameter_split.exceeded_limit:' "$candidate" || true)"
if [ "$parameter_guard_count" != 2 ]; then
    printf 'W09 bounds audit: explicit and implicit exports must enforce the parameter cap before slice materialization\n' >&2
    exit 1
fi

rg -Fq 'HEADER_SCAN_WORK: usize = 1048576' "$candidate"
rg -Fq 'HEADER_SUFFIX_SCAN_FACTOR: usize = 8' "$candidate"
rg -Fq 'HEADER_SUFFIX_FIXED_WORK: usize = 16' "$candidate"
rg -Fq 'def header_scan_charge(work: mutable usize&, amount: usize) -> bool' "$candidate"
rg -Fq 'def header_suffix_scan_charge(work: mutable usize&, remaining_bytes: usize) -> bool' "$candidate"
rg -Fq 'def export_header(line: sview, header_work: mutable usize&) -> ExportHeader' "$candidate"
rg -Fq 'def main_header(line: sview, header_work: mutable usize&) -> MainHeader' "$candidate"
rg -Fq 'def parse_export_line(line: sview, line_number: usize, pending_link_name: sview, has_pending_link_name: bool, seen_names: darray[sview], header_work: mutable usize&, name_work: mutable usize&, component: bool)' "$candidate"
rg -Fq 'def parse_implicit_main(line: sview, line_number: usize, main_seen: bool, header_work: mutable usize&, component: bool)' "$candidate"
rg -Fq 'if component:' "$candidate"
rg -Fq 'return AbiBinding{binding: "scalar", wasm_type: "i32", failure: ""}' "$candidate"
rg -Fq 'scanner.parse_exports(source, component=component_mode)' "$reference"
rg -Fq 'MAX_EXPECTED_JSON_BYTES = 1 * 1024 * 1024' "$reference"
rg -Fq 'MAX_EXPECTED_JSON_DEPTH = 128' "$reference"
rg -Fq 'MAX_REFERENCE_SOURCE_BYTES = 1 * 1024 * 1024' "$reference"
rg -Fq 'reference_source = _read_bounded_regular_file(' "$reference"
rg -Fq '"hash-object", "--stdin"' "$reference"
rg -Fq 'input=reference_source' "$reference"
rg -Fq 'exec(compile(reference_source, str(reference_path), "exec"), module.__dict__)' "$reference"
rg -Fq 'def read_bounded_expected_json(path: Path) -> Any:' "$reference"
rg -Fq 'os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_NONBLOCK", 0)' "$reference"
rg -Fq 'stat.S_ISREG(os.fstat(descriptor).st_mode)' "$reference"
rg -Fq 'chunk = os.read(descriptor, remaining)' "$reference"
rg -Fq 'def _read_bounded_regular_file(' "$reference"
rg -Fq 'flags = os.O_RDONLY | getattr(os, "O_NONBLOCK", 0) | getattr(os, "O_NOFOLLOW", 0)' "$reference"
rg -Fq 'opened_stat = os.fstat(descriptor)' "$reference"
rg -Fq 'named_after_open = os.stat(path, follow_symlinks=False)' "$reference"
rg -Fq 'chunk = os.read(descriptor, min(65536, remaining))' "$reference"
rg -Fq 'graph_remaining = MAX_INCLUDE_GRAPH_BYTES - loaded_bytes' "$reference"
rg -Fq 'read_limit = min(MAX_SOURCE_BYTES, graph_remaining)' "$reference"
rg -Fq 'source_bytes = _read_bounded_regular_file(' "$reference"
rg -Fq 'def check_expected_json_depth(payload: bytearray) -> None:' "$reference"
rg -Fq 'check_expected_json_depth(payload)' "$reference"
rg -Fq 'if depth > MAX_EXPECTED_JSON_DEPTH:' "$reference"
rg -Fq 'expected = read_bounded_expected_json(Path(expected_json_argument))' "$reference"
rg -Fq 'invalid checked-in expected JSON: unable to read regular file' "$reference"
if rg -Fq 'Path(expected_json_argument).read_text' "$reference"; then
    printf 'W09 bounds audit: expected JSON snapshots must not use an unbounded text read\n' >&2
    exit 1
fi
if rg -Fq 'resolved_path.open("rb")' "$reference"; then
    printf 'W09 bounds audit: reference preflight must read through a checked descriptor\n' >&2
    exit 1
fi
if rg -Fq '"hash-object", str(reference_path)' "$reference" || rg -Fq 'spec.loader.exec_module(module)' "$reference"; then
    printf 'W09 bounds audit: the pinned oracle must hash and execute the same source snapshot\n' >&2
    exit 1
fi
rg -Fq 'def python_expected_json_failure(source_path: sview, expected_json_path: sview, expected_stderr: sview)' "$fixture"
rg -Fq 'def python_expected_json_bounds_match()' "$fixture"
rg -Fq 'for _ in 0..<1048577 |oversized_bytes|' "$fixture"
rg -Fq 'for _ in 0..<129 |deep_bytes|' "$fixture"
rg -Fq 'create_fixture_symlink(deep_path, symlink_path)' "$fixture"
rg -Fq 'symlink_matches: bool = python_expected_json_failure' "$fixture"
rg -Fq 'expected JSON exceeds 1048576 byte limit' "$fixture"
rg -Fq 'expected JSON nesting exceeds 128 levels' "$fixture"
rg -Fq 'unable to read regular file' "$fixture"
rg -Fq 'def wasm_export_scan_matches_component_scalar_enum_mode()' "$fixture"
rg -Fq 'def launcher_payload_pair_matches(launcher: sview, source_path: sview, component: bool = false)' "$launcher_fixture"
rg -Fq 'wasm_export_scan/component_enum.input' "$launcher_fixture"
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
rg -Fq 'parse_implicit_main(line, line_number, main_seen, header_work, component)' "$candidate"
rg -Fq 'export_name_scan_charge(name_work, compared_bytes)' "$candidate"
rg -Fq 'parse_export_line(line, line_number, pending_link_name, has_pending_link_name, seen_names, header_work, name_work, component)' "$candidate"
rg -Fq 'Every scanned identifier is nonempty' "$candidate"
rg -Fq 'U+070F SYRIAC ABBREVIATION MARK' "$candidate"
rg -Fq 'U+070F SYRIAC ABBREVIATION MARK' "$fixture"
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
rg -Fq 'def encode_flatten_payload(source: sview) -> JsonEncodeResult' "$candidate"
rg -Fq 'def flatten_payload_path_response(input_path: Path) -> SourceResponse' "$candidate"
rg -Fq 'def differential_flatten_payload_response(input_path: Path) -> sview' "$candidate"
rg -Fq 'def flatten_payload_preserves_include_expansion_order()' "$fixture"
rg -Fq 'def wasm_export_scan_flatten_payload_preserves_include_order()' "$fixture"
rg -Fq 'FLATTEN_PAYLOAD_OPTION: sview = "--flatten-payload"' "$launcher_fixture"
rg -Fq 'launcher_flatten_payload_pair_matches' "$launcher_fixture"
rg -Fq 'FLATTEN_PAYLOAD_OPTION = "--flatten-payload"' "$reference"
rg -Fq 'if not build_payload and not flatten_payload and len(arguments) == 2:' "$reference"
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
rg -Fq 'def include_file_count_is_bounded()' "$fixture"
rg -Fq 'for index in 0..<4096 |temporary_root, include_source, all_written, attempted_files, index|' "$fixture"
rg -Fq 'WASM include file count exceeds Elisascript scan limit' "$fixture"
rg -Fq 'def wasm_export_scan_bounds_include_file_count()' "$fixture"
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
rg -Fq 'append_utf8_scalar(source_bytes, 917504u64)' "$fixture"
rg -Fq 'append_utf8_scalar(source_bytes, 917506u64)' "$fixture"
rg -Fq 'append_utf8_scalar(source_bytes, 917535u64)' "$fixture"
rg -Fq 'def unsupported_nonprintable_unicode_type_repr_matches_python()' "$fixture"
rg -Fq 'U+E0000, U+E0002, and U+E001F' "$contract"
rg -Fq 'PINNED_PYTHON_VERSION = (3, 14, 7)' "$reference"
rg -Fq 'PINNED_UNICODE_DATA_VERSION = "16.0.0"' "$reference"
rg -Fq 'tuple(sys.version_info[:3]) != PINNED_PYTHON_VERSION' "$reference"
rg -Fq 'unicodedata.unidata_version != PINNED_UNICODE_DATA_VERSION' "$reference"
rg -Fq 'reference requires Python 3.14.7 with Unicode 16.0.0' "$reference"
rg -Fq 'fails closed unless it runs Python 3.14.7 with' "$contract"
runtime_guard_lines="$(awk '
    /^def main\(arguments:/ { in_main = 1; main_line = NR }
    in_main && /tuple\(sys\.version_info\[:3\]\) != PINNED_PYTHON_VERSION/ { python_line = NR }
    in_main && /unicodedata\.unidata_version != PINNED_UNICODE_DATA_VERSION/ { unicode_line = NR }
    in_main && /return fail\("reference requires Python 3\.14\.7 with Unicode 16\.0\.0", 2\)/ {
        if (!python_fail_line) python_fail_line = NR
        else unicode_fail_line = NR
    }
    in_main && /build_component_payload = bool\(arguments\)/ { argument_line = NR }
    END { print main_line, python_line, python_fail_line, unicode_line, unicode_fail_line, argument_line }
' "$reference")"
set -- $runtime_guard_lines
if [ "$#" -ne 6 ] || [ "$1" -ge "$2" ] || [ "$2" -ge "$3" ] || [ "$3" -ge "$4" ] || [ "$4" -ge "$5" ] || [ "$5" -ge "$6" ]; then
    printf 'W09 bounds audit: both runtime guards must fail with status 2 before CLI mode handling\n' >&2
    exit 1
fi

printf 'W09 source audit: bounded scanner work and component ABI paths have source-level coverage; runtime parity remains unverified\n'
