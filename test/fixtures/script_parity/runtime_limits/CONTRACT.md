# Runtime-limit source audit parity slice

`scripts/check_runtime_limits.sh` is the independent POSIX-shell reference;
`scripts/check_runtime_limits.elisascript` is the candidate. Both inspect the
same five repository-relative files without launching a compiler or another
search utility. The candidate resolves the repository root from its own source
path, so a parity runner must place the copied candidate at
`scripts/check_runtime_limits.elisascript` within each isolated repository
fixture.

For inputs within the candidate's read bounds and valid UTF-8, compare exact
exit status, stdout bytes, and stderr bytes. The ordered checks are:

1. Missing required path: status 2 and the path-specific missing-file message.
2. Shared runtime constants, backend-local constant leaks, interpreter and
   bytecode consumers, width-aware shift guard, shift regression markers, and
   documentation contract: status 1 with the matching first diagnostic.
3. Ordered runtime budget guards: status 1 with the first missing guard.
4. A valid source tree: status 0 and the shared-depth success line on stdout.

The parity matrix should include a clean tree and one mutation for each
diagnostic above. It should also include multi-defect fixtures that prove the
first diagnostic follows the listed order. Exact bytes matter, including the
newline on every diagnostic and the success message. A runner must isolate
fixture roots; it must not mutate the checkout's live compiler/runtime files.

The Elisascript candidate fails closed before analysis if any source exceeds
1 MiB or if the five sources exceed 2 MiB total. These are candidate safety
bounds, not part of the reference shell script's contract. Within those bounds,
it reads all five files before content checks, so unreadable, invalid-UTF-8, or
over-limit inputs are currently outside diagnostic-precedence parity. The
current source set is about 1.74 MB, leaving roughly 0.34 MiB aggregate
headroom; if ordinary repository growth reaches the bound, adjust the explicit
limits and contract together rather than silently removing bounded reads.

This document defines acceptance work; it does not record a parity result.
Compiler execution, fixture execution, and audit execution remain disabled
until explicitly reauthorized.
