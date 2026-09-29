# C archive packager: first typed seam

Original: `../Elisa-compiler/scripts/emit_c_archive.py` (SHA-256
`e1239989896d4a59daebdfc5bae64e2e1019a8330394bb3a6a5216adf273fa1e`).
It is 37 lines and is called by the compiler's C-archive smoke test. The
original and its callers remain unchanged.

`emit_c_archive_plan.elisa` is a pure, strongly typed plan for the ordinary
invocation: `--output`, optional `--ar`, one or more ordered objects, and `--`
to end option parsing. Explicit `--ar` wins over nonempty `AR`, which wins over
an injected PATH resolution of `ar`. It produces the exact ordinary archiver
argv shape `-rcs <temporary archive> <objects...>`. Its 4096-byte path and
4096-object limits are Elisascript safety policy, not Python `argparse` parity.
The authored model fixtures are uncompiled and unrun.

This is not a replacement CLI. In particular, no host adapter yet:

- matches argparse help/errors and all malformed argument combinations;
- checks each object's regular-file kind before any output-directory mutation;
- creates the output parent and a private `elisa-c-archive-` directory *inside*
  that parent, preserving same-filesystem atomic publication;
- resolves `ar` on PATH without a shell, captures bounded stdout/stderr and
  translates nonzero status using the Python script's error precedence;
- publishes with `os.replace`-equivalent atomic rename and cleans only its
  owned temporary directory on every path;
- compares archive bytes and status/output against the pinned Python reference
  under a qualified, externally RSS-bounded parity gate.

The repository has a pure parent-specific temporary-path template, a POSIX
`mkdtemp` bridge, process-result capture and a rename bridge. Those pieces
still need an owned, race-aware host adapter and source/bytecode qualification;
the general `temp_directory(prefix)` convenience path does not establish a
same-parent staging location. Do not run compiler or parity validation under
the current hold.
