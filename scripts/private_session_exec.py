#!/usr/bin/python3
"""Create a private session, then replace this process with its command."""

import errno
import os
import stat
import sys
import time


def write_ready_file(path: str, process_id: int) -> None:
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0)
    descriptor = os.open(path, flags, 0o600)
    try:
        payload = f"{process_id}\n".encode("ascii")
        offset = 0
        while offset < len(payload):
            written = os.write(descriptor, payload[offset:])
            if written <= 0:
                raise OSError("short write while publishing session readiness")
            offset += written
    finally:
        os.close(descriptor)


def wait_for_release_file(path: str, process_id: int) -> bool:
    expected = f"{process_id}\n".encode("ascii")
    deadline = time.monotonic() + 10.0
    flags = os.O_RDONLY | getattr(os, "O_NONBLOCK", 0) | getattr(os, "O_NOFOLLOW", 0)
    while time.monotonic() < deadline:
        try:
            descriptor = os.open(path, flags)
        except FileNotFoundError:
            time.sleep(0.01)
            continue
        except OSError:
            # A symlink, unreadable path, or other open failure is not a
            # valid release token; fail closed with the same status as bad
            # file contents instead of leaking a traceback.
            return False

        read_ok = False
        received = b""
        try:
            metadata = os.fstat(descriptor)
            if stat.S_ISREG(metadata.st_mode) and metadata.st_size <= 32:
                received = os.read(descriptor, 33)
                read_ok = True
        except OSError:
            pass
        finally:
            try:
                os.close(descriptor)
            except OSError:
                read_ok = False
        if not read_ok:
            return False
        if received == expected:
            return True
        time.sleep(0.01)
    return False


def main(arguments: list[str]) -> int:
    if len(arguments) < 2:
        print("private_session_exec: expected a command", file=sys.stderr)
        return 2

    try:
        os.setsid()
    except OSError as error:
        print(f"private_session_exec: setsid failed: {error}", file=sys.stderr)
        return 1

    process_id = os.getpid()
    if os.getsid(0) != process_id or os.getpgid(0) != process_id:
        print("private_session_exec: new session does not own its process group", file=sys.stderr)
        return 1

    ready_file = os.environ.pop("ELISASCRIPT_SESSION_READY_FILE", "")
    release_file = os.environ.pop("ELISASCRIPT_SESSION_RELEASE_FILE", "")
    if bool(ready_file) != bool(release_file):
        print("private_session_exec: incomplete session handshake paths", file=sys.stderr)
        return 1
    if ready_file:
        try:
            write_ready_file(ready_file, process_id)
        except OSError as error:
            print(f"private_session_exec: cannot publish session readiness: {error}", file=sys.stderr)
            return 1
        if not wait_for_release_file(release_file, process_id):
            print("private_session_exec: session release was missing or invalid", file=sys.stderr)
            return 125

    try:
        os.execvp(arguments[1], arguments[1:])
    except OSError as error:
        print(f"private_session_exec: cannot execute {arguments[1]!r}: {error}", file=sys.stderr)
        return 127 if error.errno == errno.ENOENT else 126


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
