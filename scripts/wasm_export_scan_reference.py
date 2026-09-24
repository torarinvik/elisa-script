#!/usr/bin/env python3
"""Pinned process adapter for W09 scanner, build-payload, and flatten-payload parity."""

from __future__ import annotations

from collections.abc import Iterator
import importlib.util
import json
import os
import stat
import subprocess
import sys
from pathlib import Path
from types import ModuleType


PINNED_COMMIT = "0019dfcfff405b98369dd1b51562619668e29707"
MAX_SOURCE_BYTES = 8 * 1024 * 1024
MAX_JSON_BYTES = 16 * 1024 * 1024
# Expected snapshots are tiny checked-in contracts. Keep their decoded object
# graph far below the 16 MiB maximum scanner output payload.
MAX_EXPECTED_JSON_BYTES = 1 * 1024 * 1024
MAX_EXPECTED_JSON_DEPTH = 128
# Keep one byte for the final LF under the differential runner's 64 MiB cap.
MAX_CALLER_PAYLOAD_BYTES = 64 * 1024 * 1024 - 1
MAX_PATH_BYTES = 4096
MAX_PATH_COMPONENT_WORK = 131072
MAX_INCLUDE_GRAPH_BYTES = 32 * 1024 * 1024
MAX_INCLUDE_FILES = 4096
MAX_INCLUDE_DEPTH = 128
MAX_INCLUDE_DIRECTIVES = 16384
ROOT = Path(__file__).resolve().parents[1]
REFERENCE_ROOT = ROOT.parent / "Elisa-compiler"
REFERENCE_RELATIVE = Path("scripts/wasm_export_scan.py")
BUILD_PAYLOAD_OPTION = "--build-payload"
FLATTEN_PAYLOAD_OPTION = "--flatten-payload"


def load_pinned_reference() -> ModuleType:
    reference_path = REFERENCE_ROOT / REFERENCE_RELATIVE
    expected_blob = subprocess.run(
        [
            "git",
            "-C",
            str(REFERENCE_ROOT),
            "rev-parse",
            f"{PINNED_COMMIT}:{REFERENCE_RELATIVE.as_posix()}",
        ],
        check=True,
        capture_output=True,
        text=True,
        timeout=5,
    ).stdout.strip()
    current_blob = subprocess.run(
        ["git", "-C", str(REFERENCE_ROOT), "hash-object", str(reference_path)],
        check=True,
        capture_output=True,
        text=True,
        timeout=5,
    ).stdout.strip()
    if current_blob != expected_blob:
        raise RuntimeError("pinned Python scanner source differs from the recorded reference")

    spec = importlib.util.spec_from_file_location("_pinned_wasm_export_scan", reference_path)
    if spec is None or spec.loader is None:
        raise RuntimeError("unable to load the pinned Python scanner")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    if Path(module.__file__).resolve() != reference_path.resolve():
        raise RuntimeError("Python imported an unexpected scanner module")
    return module


def fail(message: str, status: int = 1) -> int:
    sys.stderr.write(f"wasm export scan: {message}\n")
    return status


def read_bounded_expected_json(path: Path) -> Any:
    """Load a small regular snapshot without an unbounded text-file read."""
    descriptor = os.open(
        path,
        os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_NONBLOCK", 0),
    )
    try:
        if not stat.S_ISREG(os.fstat(descriptor).st_mode):
            raise OSError("expected JSON is not a regular file")
        payload = bytearray()
        while len(payload) <= MAX_EXPECTED_JSON_BYTES:
            remaining = MAX_EXPECTED_JSON_BYTES + 1 - len(payload)
            chunk = os.read(descriptor, remaining)
            if not chunk:
                break
            payload.extend(chunk)
    finally:
        os.close(descriptor)
    if len(payload) > MAX_EXPECTED_JSON_BYTES:
        raise ValueError(
            f"expected JSON exceeds {MAX_EXPECTED_JSON_BYTES} byte limit"
        )
    check_expected_json_depth(payload)
    return json.loads(payload.decode("utf-8"))


def check_expected_json_depth(payload: bytearray) -> None:
    """Reject excessive container nesting before the recursive JSON decoder."""
    depth = 0
    in_string = False
    escaped = False
    for byte in payload:
        if in_string:
            if escaped:
                escaped = False
            elif byte == 0x5C:  # backslash
                escaped = True
            elif byte == 0x22:  # quote
                in_string = False
        elif byte == 0x22:
            in_string = True
        elif byte == 0x5B or byte == 0x7B:  # [ or {
            depth += 1
            if depth > MAX_EXPECTED_JSON_DEPTH:
                raise ValueError(
                    f"expected JSON nesting exceeds {MAX_EXPECTED_JSON_DEPTH} levels"
                )
        elif byte == 0x5D or byte == 0x7D:  # ] or }
            depth = max(0, depth - 1)


def split_keepends(text: str) -> Iterator[str]:
    """Yield Python splitlines(keepends=True) spans without materializing a list."""
    start = 0
    cursor = 0
    while cursor < len(text):
        character = text[cursor]
        if character == "\r":
            end = cursor + 2 if cursor + 1 < len(text) and text[cursor + 1] == "\n" else cursor + 1
        elif character in "\n\v\f\x1c\x1d\x1e\x85\u2028\u2029":
            end = cursor + 1
        else:
            cursor += 1
            continue
        yield text[start:end]
        start = end
        cursor = end
    if start < len(text):
        yield text[start:]


def _same_file_identity(left: os.stat_result, right: os.stat_result) -> bool:
    return left.st_dev == right.st_dev and left.st_ino == right.st_ino


def _read_bounded_regular_file(
    path: Path, expected_stat: os.stat_result, maximum_bytes: int
) -> bytes:
    """Read at most one overflow byte from the same regular file checked by stat."""
    flags = os.O_RDONLY | getattr(os, "O_NONBLOCK", 0) | getattr(os, "O_NOFOLLOW", 0)
    descriptor = os.open(path, flags)
    try:
        opened_stat = os.fstat(descriptor)
        if not stat.S_ISREG(opened_stat.st_mode) or not _same_file_identity(
            expected_stat, opened_stat
        ):
            raise OSError("source changed while opening")

        named_after_open = os.stat(path, follow_symlinks=False)
        if not stat.S_ISREG(named_after_open.st_mode) or not _same_file_identity(
            opened_stat, named_after_open
        ):
            raise OSError("source path changed while opening")

        payload = bytearray()
        while len(payload) <= maximum_bytes:
            remaining = maximum_bytes + 1 - len(payload)
            chunk = os.read(descriptor, min(65536, remaining))
            if not chunk:
                return bytes(payload)
            payload.extend(chunk)
        return bytes(payload)
    finally:
        os.close(descriptor)


def preflight_reference_input(
    scanner: ModuleType, source_path: Path, source_spelling: str | None = None
) -> str | None:
    """Bound and validate an include graph before calling the pinned unbounded loader.

    The reference's recursive read_flat_source is the oracle on accepted input.
    This preflight mirrors its graph walk but applies the candidate's resource
    ceilings first, so a parity adapter cannot accidentally read an enormous
    graph into memory before the test runner's reactive RSS guard notices.
    """
    seen: set[Path] = set()
    active: list[Path] = []
    loaded_files = 0
    loaded_bytes = 0
    include_directives = 0
    flattened_bytes = 0
    path_component_work = 0

    def visit(requested_path: Path, raw_spelling: str | None = None) -> str | None:
        nonlocal loaded_files, loaded_bytes, include_directives, flattened_bytes
        nonlocal path_component_work
        try:
            path_spelling = (
                raw_spelling if raw_spelling is not None else os.fspath(requested_path)
            )
            raw_path = os.fsencode(path_spelling)
        except (OSError, TypeError, ValueError):
            return "unable to resolve source/include path"
        if len(raw_path) >= MAX_PATH_BYTES:
            return "unable to resolve source/include path"
        if b"\0" in raw_path:
            return "unable to resolve source/include path"
        if not requested_path.is_absolute():
            try:
                current_directory = os.fsencode(os.getcwd())
            except OSError:
                return "unable to resolve source/include path"
            separator_bytes = 0 if current_directory.endswith(b"/") else 1
            joined_length = len(current_directory) + separator_bytes + len(raw_path)
            if joined_length >= MAX_PATH_BYTES:
                return "unable to resolve source/include path"
        component_count = sum(
            component != b"" for component in raw_path.split(b"/")
        )
        if component_count > MAX_PATH_COMPONENT_WORK - path_component_work:
            return "WASM path component work exceeds Elisascript scan limit"
        path_component_work += component_count
        try:
            resolved_path = requested_path.resolve()
        except (OSError, RuntimeError, ValueError):
            return "unable to resolve source/include path"
        try:
            if len(os.fsencode(os.fspath(resolved_path))) >= MAX_PATH_BYTES:
                return "unable to resolve source/include path"
        except (OSError, TypeError, ValueError):
            return "unable to resolve source/include path"

        if resolved_path in active:
            chain = " -> ".join(str(item) for item in [*active, resolved_path])
            return f"cyclic include while building WASM: {chain}"
        if resolved_path in seen:
            return None
        if len(active) >= MAX_INCLUDE_DEPTH:
            return "WASM include depth exceeds Elisascript scan limit"
        if loaded_files >= MAX_INCLUDE_FILES:
            return "WASM include file count exceeds Elisascript scan limit"
        if not resolved_path.is_file():
            return f"missing source/include: {resolved_path}"

        try:
            named_before_open = resolved_path.stat()
        except OSError:
            return f"unable to inspect source/include: {resolved_path}"
        file_size = named_before_open.st_size
        if file_size > MAX_SOURCE_BYTES:
            return "WASM source exceeds Elisascript scan limit"
        if file_size > MAX_INCLUDE_GRAPH_BYTES - loaded_bytes:
            return "WASM include graph exceeds Elisascript scan limit"

        seen.add(resolved_path)
        active.append(resolved_path)
        loaded_files += 1
        try:
            graph_remaining = MAX_INCLUDE_GRAPH_BYTES - loaded_bytes
            read_limit = min(MAX_SOURCE_BYTES, graph_remaining)
            source_bytes = _read_bounded_regular_file(
                resolved_path, named_before_open, read_limit
            )
        except OSError:
            return f"unable to read source/include: {resolved_path}"
        if len(source_bytes) > MAX_SOURCE_BYTES:
            return "WASM source exceeds Elisascript scan limit"
        if len(source_bytes) > graph_remaining:
            return "WASM include graph exceeds Elisascript scan limit"
        loaded_bytes += len(source_bytes)
        try:
            text = source_bytes.decode("utf-8")
        except UnicodeDecodeError:
            return "WASM source is not valid UTF-8"
        text = text.replace("\r\n", "\n").replace("\r", "\n")

        for line in split_keepends(text):
            match = scanner.INCLUDE_RE.match(line.rstrip("\r\n"))
            if match:
                if include_directives >= MAX_INCLUDE_DIRECTIVES:
                    return "WASM include directive count exceeds Elisascript scan limit"
                include_directives += 1
                include_path = Path(match.group(1))
                if not include_path.is_absolute():
                    include_parent = resolved_path.parent
                    parent_spelling = os.fspath(include_parent)
                    separator = "" if parent_spelling.endswith(os.sep) else os.sep
                    include_spelling = parent_spelling + separator + match.group(1)
                    include_path = include_parent / include_path
                else:
                    include_spelling = match.group(1)
                failure = visit(include_path, include_spelling)
                if failure is not None:
                    return failure
            else:
                flattened_bytes += len(line.encode("utf-8"))
                if flattened_bytes > MAX_SOURCE_BYTES:
                    return "WASM source exceeds Elisascript scan limit"

        active.pop()
        return None

    return visit(source_path, source_spelling if source_spelling is not None else os.fspath(source_path))


def main(arguments: list[str]) -> int:
    build_component_payload = bool(arguments) and arguments[0] == "--build-component-payload"
    build_payload = bool(arguments) and (arguments[0] == BUILD_PAYLOAD_OPTION or build_component_payload)
    flatten_payload = bool(arguments) and arguments[0] == FLATTEN_PAYLOAD_OPTION
    component_mode = bool(arguments) and (arguments[0] == "--component" or build_component_payload)
    expected_json_argument: str | None = None
    if component_mode and not build_component_payload:
        if len(arguments) not in (2, 3):
            sys.stderr.write(
                "usage: wasm export scan <source> [expected-json] "
                "| --component <source> [expected-json] "
                "| --build-payload <source> | --build-component-payload <source> "
                "| --flatten-payload <source>\n"
            )
            return 2
        source_argument = arguments[1]
        if len(arguments) == 3:
            expected_json_argument = arguments[2]
    elif build_payload or flatten_payload:
        if len(arguments) != 2:
            sys.stderr.write(
                "usage: wasm export scan <source> [expected-json] "
                "| --component <source> [expected-json] "
                "| --build-payload <source> | --build-component-payload <source> "
                "| --flatten-payload <source>\n"
            )
            return 2
        source_argument = arguments[1]

    else:
        if len(arguments) not in (1, 2):
            sys.stderr.write(
                "usage: wasm export scan <source> [expected-json] "
                "| --component <source> [expected-json] "
                "| --build-payload <source> | --build-component-payload <source> "
                "| --flatten-payload <source>\n"
            )
            return 2
        source_argument = arguments[0]
        if len(arguments) == 2:
            expected_json_argument = arguments[1]

    source_path = Path(source_argument)
    try:
        scanner = load_pinned_reference()
    except Exception as error:  # Keep oracle failures visible rather than masking them as parity.
        return fail(f"pinned reference unavailable: {error}", 2)
    preflight_failure = preflight_reference_input(
        scanner, source_path, source_argument
    )
    if preflight_failure is not None:
        return fail(preflight_failure)
    try:
        # Exercise the pinned build caller's include expansion, not just its
        # flattened-source scanner. read_flat_source also performs Python's
        # strict UTF-8 decoding and universal-newline conversion per file.
        source = scanner.read_flat_source(source_path)
    except scanner.WasmBuildError as error:
        return fail(str(error))
    except UnicodeDecodeError:
        return fail("WASM source is not valid UTF-8")
    except Exception as error:
        return fail(f"pinned source loader raised an unexpected error: {error}", 2)

    if len(source.encode("utf-8")) > MAX_SOURCE_BYTES:
        return fail("WASM source exceeds Elisascript scan limit")
    exports = []
    if not flatten_payload:
        try:
            exports = scanner.parse_exports(source, component=component_mode)
        except scanner.WasmBuildError as error:
            return fail(str(error))
        except Exception as error:
            return fail(f"pinned scanner raised an unexpected error: {error}", 2)

    if not build_payload and not flatten_payload and expected_json_argument is not None:
        try:
            expected = read_bounded_expected_json(Path(expected_json_argument))
        except OSError:
            return fail("invalid checked-in expected JSON: unable to read regular file", 2)
        except (UnicodeDecodeError, ValueError) as error:
            return fail(f"invalid checked-in expected JSON: {error}", 2)
        if exports != expected:
            return fail("pinned Python output differs from the checked-in expected JSON", 2)

    if flatten_payload:
        output_value = {"version": 1, "flattened_source": source}
    elif build_payload:
        output_value = {"version": 1, "flattened_source": source, "exports": exports}
    else:
        output_value = exports
    output = json.dumps(output_value, ensure_ascii=False, separators=(",", ":"))
    output_limit = MAX_CALLER_PAYLOAD_BYTES if build_payload or flatten_payload else MAX_JSON_BYTES
    if len(output.encode("utf-8")) > output_limit:
        return fail("structured output exceeds Elisascript scan limit")
    sys.stdout.buffer.write(output.encode("utf-8") + b"\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
