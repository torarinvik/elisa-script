# macOS deployment-target parser port

`src/runtime/macos_deployment_target_model.elisa` is a pure-source port of
`../elisa-engine/scripts/macos_deployment_target.py`. Its current boundary is
only the text parser and version formatter used by
`package_macos_app.py`; it does not replace that packaging workflow, invoke
`otool`, or inspect Mach-O binaries.

The model covers the helper's modern `LC_BUILD_VERSION` and legacy
`LC_VERSION_MIN_MACOSX` records, macOS platform spellings, first matching
deployment field, two- and three-component versions, version ordering, and
formatted output. The authored model fixture mirrors the original unit test
and adds focused lexical-boundary cases. It has not been compiled or run.

The source helper receives `otool` text, which is ASCII in the supported
workflow. The model recognizes ASCII digits and whitespace, but stores each
version component as normalized decimal text and compares components by digit
count and lexicographic order. This preserves Python's arbitrary-precision
integer behavior without narrowing large tool output to a machine integer.
Python's Unicode `\d`/whitespace matching remains a broader input domain than
the model's ASCII scanner; the adapter contract should either guarantee the
supported `otool` output domain or that difference should be addressed before
the model is integrated into the packaging entrypoint. No compiler, test,
Python reference, `otool`, packaging, or parity process was run for this
change.
