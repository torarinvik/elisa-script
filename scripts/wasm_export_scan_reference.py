#!/usr/bin/env python3
"""Pinned process adapter for the W09 scanner differential tests."""

from __future__ import annotations

from collections.abc import Iterator
import importlib.util
import json
import subprocess
import sys
from pathlib import Path
from types import ModuleType


PINNED_COMMIT = "0019dfcfff405b98369dd1b51562619668e29707"
MAX_SOURCE_BYTES = 8 * 1024 * 1024
MAX_JSON_BYTES = 16 * 1024 * 1024
MAX_INCLUDE_GRAPH_BYTES = 32 * 1024 * 1024
MAX_INCLUDE_FILES = 4096
MAX_INCLUDE_DEPTH = 128
MAX_INCLUDE_DIRECTIVES = 16384
ROOT = Path(__file__).resolve().parents[1]
REFERENCE_ROOT = ROOT.parent / "Elisa-compiler"
REFERENCE_RELATIVE = Path("scripts/wasm_export_scan.py")


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


def preflight_reference_input(scanner: ModuleType, source_path: Path) -> str | None:
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

    def visit(requested_path: Path) -> str | None:
        nonlocal loaded_files, loaded_bytes, include_directives, flattened_bytes
        try:
            resolved_path = requested_path.resolve()
        except (OSError, RuntimeError):
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
            file_size = resolved_path.stat().st_size
        except OSError:
            return f"unable to inspect source/include: {resolved_path}"
        if file_size > MAX_SOURCE_BYTES:
            return "WASM source exceeds Elisascript scan limit"
        if file_size > MAX_INCLUDE_GRAPH_BYTES - loaded_bytes:
            return "WASM include graph exceeds Elisascript scan limit"

        seen.add(resolved_path)
        active.append(resolved_path)
        loaded_files += 1
        loaded_bytes += file_size
        try:
            with resolved_path.open("rb") as source_file:
                source_bytes = source_file.read(MAX_SOURCE_BYTES + 1)
        except OSError:
            return f"unable to read source/include: {resolved_path}"
        if len(source_bytes) > MAX_SOURCE_BYTES:
            return "WASM source exceeds Elisascript scan limit"
        before_read = loaded_bytes - file_size
        if len(source_bytes) > MAX_INCLUDE_GRAPH_BYTES - before_read:
            return "WASM include graph exceeds Elisascript scan limit"
        loaded_bytes = before_read + len(source_bytes)
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
                    include_path = resolved_path.parent / include_path
                failure = visit(include_path)
                if failure is not None:
                    return failure
            else:
                flattened_bytes += len(line.encode("utf-8"))
                if flattened_bytes > MAX_SOURCE_BYTES:
                    return "WASM source exceeds Elisascript scan limit"

        active.pop()
        return None

    return visit(source_path)


def main(arguments: list[str]) -> int:
    if len(arguments) not in (1, 2):
        sys.stderr.write("usage: wasm export scan [source [expected-json]]\n")
        return 2

    source_path = Path(arguments[0])
    try:
        scanner = load_pinned_reference()
    except Exception as error:  # Keep oracle failures visible rather than masking them as parity.
        return fail(f"pinned reference unavailable: {error}", 2)
    preflight_failure = preflight_reference_input(scanner, source_path)
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
    try:
        exports = scanner.parse_exports(source)
    except scanner.WasmBuildError as error:
        return fail(str(error))
    except Exception as error:
        return fail(f"pinned scanner raised an unexpected error: {error}", 2)

    if len(arguments) == 2:
        try:
            expected = json.loads(Path(arguments[1]).read_text(encoding="utf-8"))
        except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
            return fail(f"invalid checked-in expected JSON: {error}", 2)
        if exports != expected:
            return fail("pinned Python output differs from the checked-in expected JSON", 2)

    output = json.dumps(exports, ensure_ascii=False, separators=(",", ":"))
    if len(output.encode("utf-8")) > MAX_JSON_BYTES:
        return fail("structured output exceeds Elisascript scan limit")
    sys.stdout.write(output + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
