#!/usr/bin/env python3
"""Pinned process adapter for the W09 scanner differential tests."""

from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
from pathlib import Path
from types import ModuleType


PINNED_COMMIT = "0019dfcfff405b98369dd1b51562619668e29707"
MAX_SOURCE_BYTES = 8 * 1024 * 1024
MAX_JSON_BYTES = 16 * 1024 * 1024
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


def main(arguments: list[str]) -> int:
    if len(arguments) not in (1, 2):
        sys.stderr.write("usage: wasm export scan [flattened-source [expected-json]]\n")
        return 2

    source_path = Path(arguments[0])
    if not source_path.is_file():
        return fail("missing source file")
    try:
        source_size = source_path.stat().st_size
    except OSError:
        return fail("unable to inspect source file")
    if source_size > MAX_SOURCE_BYTES:
        return fail("source exceeds Elisascript scan limit")

    try:
        with source_path.open("rb") as source_file:
            source_bytes = source_file.read(MAX_SOURCE_BYTES + 1)
    except OSError:
        return fail("unable to read source file")
    if len(source_bytes) > MAX_SOURCE_BYTES:
        return fail("source exceeds Elisascript scan limit")
    try:
        source = source_bytes.decode("utf-8")
    except UnicodeDecodeError:
        return fail("WASM source is not valid UTF-8")
    source = source.replace("\r\n", "\n").replace("\r", "\n")

    try:
        scanner = load_pinned_reference()
    except Exception as error:  # Keep oracle failures visible rather than masking them as parity.
        return fail(f"pinned reference unavailable: {error}", 2)
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
