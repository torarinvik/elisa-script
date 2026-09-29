# Stdin byte-limit boundaries

Status: source-only correction to the existing interpreter stdin primitives.
No compiler, fixture, descriptor read or public-launcher parity ran. Validation
remains disabled pending explicit user reauthorization. Originals are unchanged.

`EsStdinReadBudget` separates the capacity of the next descriptor read from
permission to append payload. Reads normally request the smaller of the chunk
size and remaining byte budget. At the exact byte boundary they request one
probe byte: native EOF finishes normally, while any positive payload exceeds
the limit and fails without appending or returning a partial result. Invalid
consumed counters and zero chunk sizes do not permit a native read.

Previously both whole-input and single-line reads failed before observing EOF
at the limit. Whole-input reads now admit empty EOF with a zero limit and EOF
after exactly the permitted bytes. Single-line reads also admit the final
unterminated line at the exact limit. Empty EOF still raises the existing Console
failure for `input`/line reads; it is not fabricated into an empty input line.

The line-reader budget counts raw consumed bytes, including CR and LF, not just
the text returned after terminator stripping. A newline read when the budget is
already exhausted is an extra byte and fails. This change does not redefine
that policy, change newline conversion, or over-read successful lines.

Both stdin paths reject non-native negative bridge returns before reading errno.
Only native -1 may sample errno and use the existing bounded EINTR retry count.
Positive short reads append their exact admitted byte count; impossible counts
still fail. Counter updates use subtraction-based admission before addition,
including at the u64 boundary.

The probe can consume one excess byte on failure; it is not a nondestructive peek
or replayable stream checkpoint. On a blocking descriptor it can wait for EOF or
another byte. Byte limits do not impose a wall deadline, cancellation, RSS guard,
or total lifetime input budget across repeated calls. Those controls remain
separate requirements. No concurrent mutation or native pointer/ABI safety is
proved by this pure arithmetic model.

Authored pure fixtures cover zero/exact/over limits, partial chunks, one-byte
line reads and u64 boundaries. They do not execute native reads. Qualification
must separately cover empty EOF, binary NUL/255 payloads exactly at and beyond
the limit, LF/CRLF and unterminated lines, positive short reads, native EINTR,
bridge rejection with stale EINTR, and blocking-probe containment. Each actual
whole-input result must equal the full expected bytes, and each failing read
must not publish a successful prefix. Use independently pinned native/public
artifacts and an authorized external process-tree RSS/time guard; do not
auto-build or resume a compiler from these fixtures.
