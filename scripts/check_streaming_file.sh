#!/usr/bin/env bash

# Compiler-free audit for the typed, bounded POSIX file-stream contract.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
stream="$repo_root/src/runtime/stream_posix.elisa"
ir="$repo_root/src/ir/ir.elisa"
tests="$repo_root/test/ir/elisascript_ir_test.elisa"
docs="$repo_root/docs/ir.md"
plan="$repo_root/IMPLEMENTATION_PLAN.md"

for required_file in "$stream" "$ir" "$tests" "$docs" "$plan"; do
    if [[ ! -f "$required_file" ]]; then
        printf 'streaming file audit: missing %s\n' "$required_file" >&2
        exit 1
    fi
done

rg -q 'include "\.\./runtime/stream_posix\.elisa"' "$ir"
rg -q '^error FileStreamError:' "$stream"
rg -q '^    OpenFailed\(path: cstr\)$' "$stream"
rg -q '^    ReadFailed\(path: cstr\)$' "$stream"
rg -q '^    WriteFailed\(path: cstr\)$' "$stream"
rg -q '^    SyncFailed\(path: cstr\)$' "$stream"
rg -q '^    CloseFailed\(path: cstr\)$' "$stream"
rg -q '^    CleanupStateInvalid\(path: cstr\)$' "$stream"
rg -q '^    Closed\(path: cstr\)$' "$stream"
rg -q '^    WrongMode\(path: cstr\)$' "$stream"
rg -q '^    LimitExceeded\(path: cstr\)$' "$stream"
rg -q '^    PathTooLong\(path: cstr\)$' "$stream"
rg -q '^    LineTooLong\(path: cstr\)$' "$stream"
rg -q 'const FILE_STREAM_DEFAULT_MAX_BYTES: usize = ES_RUNTIME_DEFAULT_MAX_MEMORY_BYTES' "$stream"
rg -q '^        const enum FileStreamMode of u8:' "$stream"
rg -q '^        const enum FileStreamState of u8:' "$stream"
rg -q '^        struct FileStreamRead:' "$stream"
rg -q '^        struct FileStreamWrite:' "$stream"
rg -q '^        struct FileStream:' "$stream"
rg -q 'def file_stream_open\(' "$stream"
rg -q 'const FILE_STREAM_MAX_PATH_BYTES: usize = 4096' "$stream"
rg -q 'def file_stream_path_terminated\(' "$stream"
rg -q 'return false if bytes\[0\] == 0' "$stream"
rg -q 'PathTooLong\(path\) if not file_stream_path_terminated\(path\)' "$stream"
rg -q 'def file_stream_read_chunk\(' "$stream"
rg -q 'def file_stream_write_chunk\(' "$stream"
rg -q 'def file_stream_sync\(' "$stream"
rg -q 'def file_stream_read_line\(' "$stream"
rg -q 'def file_stream_close\(' "$stream"
rg -q 'const enum FileStreamCleanupState of u8:' "$stream"
rg -q 'struct FileStreamCleanupGuard:' "$stream"
rg -q 'def file_stream_cleanup_begin\(' "$stream"
rg -q 'def file_stream_cleanup_commit\(' "$stream"
rg -q 'def file_stream_cleanup_abort\(' "$stream"
rg -q 'guard\.state != FileStreamCleanupState\.Armed' "$stream"
rg -q 'stream\.state == FileStreamState\.Closed and stream\.handle != null' "$stream"
rg -q 'stream\.state == FileStreamState\.Closed$' "$stream"
rg -q 'stream\.handle == null' "$stream"
rg -q 'capacity > stream\.byte_budget - stream\.bytes_read' "$stream"
rg -q 'capacity > stream\.byte_budget - stream\.bytes_written' "$stream"
rg -q 'machine over fread\(' "$stream"
rg -U -q 'raise FileStreamError\.LimitExceeded\(stream\.path\) if stream\.bytes_read >= stream\.byte_budget\n            machine over fread' "$stream"
rg -q 'stream\.state <- FileStreamState\.Closed' "$stream"
rg -q 'typed_file_stream_contract_is_bounded_and_stateful' "$tests"
rg -q 'typed_file_stream_close_rejects_open_without_handle' "$tests"
rg -q 'FileStreamCleanupGuard' "$tests"
rg -q 'file_stream_cleanup_transition' "$tests"
rg -q 'file_stream_cleanup_transition\(FileStreamCleanupState\.Closed, FileStreamCleanupEvent\.Commit\)' "$tests"
rg -q 'file_stream_cleanup_transition\(FileStreamCleanupState\.Closed, FileStreamCleanupEvent\.Abort\)' "$tests"
rg -q 'file_stream_cleanup_transition\(FileStreamCleanupState\.Aborted, FileStreamCleanupEvent\.Commit\)' "$tests"
rg -q 'file_stream_cleanup_transition\(FileStreamCleanupState\.Aborted, FileStreamCleanupEvent\.Abort\)' "$tests"
rg -q 'typed streaming file handles|FileStream|file_stream_read_line' "$docs"
rg -q 'Q06:.*FileStream|Q06:.*typed streaming' "$plan"

printf 'streaming file audit: typed modes, bounded chunk/line operations, and close-state contract present\n'
