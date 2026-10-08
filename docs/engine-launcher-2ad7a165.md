# Engine launcher backend compatibility — compiler 2ad7a165

The backend trace identifies unsupported len(sview) calls in four Python text
helpers. These now use sview_len. Output catches bind successful values directly
(value/total/payload), replacing ok-prefixed binders. Four Python text functions
and output_render_record_bytes now emit: declines fall from 13 to 8. Other
output catches advance to failure-binding/expression-statement declines; their
error mapping is unchanged. The bounded build exits 2 in 5.58 seconds, peak
sampled RSS 821,360 KiB; no executable is produced. Artifact:
`build/validation/elisascript-2ad7a165-backend-forms-build.log` and JSON.
Python text and report behavior remain runtime-unverified.

## Explicit wait-status reference

The POSIX waitpid bridge now passes `&native_status` to its native mutable
i32 reference parameter. C still writes a four-byte local, and the wrapper
widens it into the caller's int only when waitpid reports a child. This clears
the waitpid backend decline without changing the status-storage ABI.
The bounded build exits 2 in 3.85 seconds, peak sampled RSS 808,192 KiB,
with seven remaining declines and no object or executable produced. Artifact:
`build/validation/elisascript-2ad7a165-waitpid-build.log` and JSON.
Wait and timeout behavior remain runtime-unverified.
