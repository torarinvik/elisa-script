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
workflow. The model currently recognizes ASCII digits and whitespace and
stores version components as `u64`; Python's regex/integer operations accept a
wider Unicode and arbitrary-precision input domain. Those differences are not
qualified as parity and should either be eliminated or explicitly bounded by
the adapter contract before this helper is integrated into the packaging
entrypoint. No compiler, test, Python reference, `otool`, packaging, or parity
process was run for this change.
