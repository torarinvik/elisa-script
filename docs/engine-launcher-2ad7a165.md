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

## Void success arm

The classify_returned_exec success type is void. Its legacy status catch now
leaves the success binder unread, removing the invalid `_ = returned` discard;
the unreachable success fallback still returns fatal_status. With the
catch-arm repair product (source d67efe6e), this clears returned_exec_status.
The bounded build exits 2 in 4.03 seconds, peak RSS 831,488 KiB, with six
remaining declines and no executable. Artifact:
`build/validation/elisascript-d67efe6e-void-success-build.log` and JSON.
Legacy status and parent-side launch receipt behavior remain runtime-unverified.

## Acknowledgement success binding

The transport writer's acknowledgement catch now uses `state:` instead of
`ok state:`. Its state update, failure transition and error handling are
unchanged. The previous trace declined Ident(state) in the success arm;
the corrected binder clears write_output_transport_fd. With the fieldless
rethrow repair product, the bounded build exits 2 in 6.07 seconds, peak RSS
804,720 KiB, with one decline: report_test_setup_failure_machine reads a
generic payload-error binder that the backend does not declare. No executable
is produced. Artifact:
`build/validation/elisascript-ddd62fd5-ack-binding-build.log` and JSON.
Transport and report behavior remain runtime-unverified.

## Canonical kill signature

The vendored crash reporter now declares getpid and kill with i32 C scalar
types, matching the current upstream standard library and EsRuntime process
bridge. Its signal argument is converted to i32 at the kill call. This clears
the conflicting kill LLVM signature. The bounded build still exits 2 on the
named selected_names argument occupying RuntimeResourcePolicy's position;
no executable is produced. Artifact:
`build/validation/elisascript-1e64bb73-kill-abi-build.log` and JSON.
Crash re-raise behavior remains runtime-unverified.

## Source verifier diagnostics

The source loader now preserves the first IR verification message and its
function name using the existing bounded diagnostic text adapter. The launcher
renders that copied context for VerificationFailed instead of discarding it.
No verifier check is relaxed. The diagnostic build succeeds; the engine gate
reports missing caller effect coverage in run_visible. Adding Console.Write
coverage advances it to a callee-error-row finding in the same function.
Artifacts: `build/validation/elisascript-verifier-diagnostic-build.log`,
`elisascript-verifier-diagnostic-native-quick.log`, and
`elisascript-verifier-diagnostic-native-console.log`, with JSON reports.
No native gate stage executes; recovered helper error-row handling remains open.
