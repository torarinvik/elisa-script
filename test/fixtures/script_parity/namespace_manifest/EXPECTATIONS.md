# Namespace-manifest port fixtures

Run both implementations with the same explicit source root. For the positive
case, also pass its `parser_tokens.elisa` as the second argument so neither side
depends on a parser-token default. Substitute the absolute
`SOURCE_ROOT` path and, where present, the absolute `PARSER_SOURCE` path in the
expected output below. These are static expectations; the compiler validation
hold means neither implementation nor the candidate has been executed on this
matrix.

| Fixture | Status | Stdout | Stderr |
| --- | ---: | --- | --- |
| `positive` | 0 | `module\tfiles\tpublic_sections\tprivate_sections\nEsArtifactCache\t{SOURCE_ROOT}/cache.elisa;\t1\t0\nEsBytecode\t{SOURCE_ROOT}/bytecode.elisa;\t1\t0\nEsDifferential\t{SOURCE_ROOT}/differential.elisa;\t1\t0\nEsDriver\t{SOURCE_ROOT}/driver/elisascript.elisa;\t1\t0\nEsIr\t{SOURCE_ROOT}/ir/ir_model.elisa;{SOURCE_ROOT}/ir/lower_ast.elisa;{SOURCE_ROOT}/ir/runner.elisa;\t2\t1\nEsIrArtifact\t{SOURCE_ROOT}/ir_artifact.elisa;\t1\t0\nEsRuntime\t{SOURCE_ROOT}/runtime.elisa;{SOURCE_ROOT}/runtime/adapter.elisa;\t1\t1\n` | empty |
| `positive` with `positive/missing_parser_tokens.elisa` as parser source | 1 | empty | `check_namespace_manifest: parse diagnostic renderer omits ParseErrorKind.UnexpectedToken\n` |
| `duplicate` | 1 | empty | `check_namespace_manifest: duplicate module declarations:\nClash\n` |
| `unknown_using` | 1 | empty | `check_namespace_manifest: using imports undeclared module: MissingNamespace\n` |
| `undeclared_extension` | 1 | empty | `check_namespace_manifest: extension targets undeclared module: MissingModule\n` |
| `leaked_impl` | 1 | empty | `check_namespace_manifest: private POSIX _impl call leaked outside runtime:\n{SOURCE_ROOT}/leak.elisa:1:elisascript_posix_open_impl()\n` |
| `abi_outside_runtime` | 1 | empty | `check_namespace_manifest: POSIX ABI declaration is outside EsRuntime: {SOURCE_ROOT}/runtime/posix.elisa\n` |
| `bytecode_renderer_missing` | 1 | empty | `check_namespace_manifest: bytecode diagnostic renderer omits IssueKind.Missing\n` |
| `lower_renderer_missing` | 1 | empty | `check_namespace_manifest: source diagnostic renderer omits LowerIssueKind.Missing\n` |
| `diagnostic_reset_missing` | 1 | empty | `check_namespace_manifest: diagnostic reset omits stale\n` |
| `missing_include` | 1 | empty | `check_namespace_manifest: missing include: {SOURCE_ROOT}/a.elisa -> missing_fragment.elisa\n` |
| `public_abi` | 1 | `{SOURCE_ROOT}/runtime/posix.elisa: POSIX ABI declaration is not private at line 3\n` | empty |
| nonexistent source root | 2 | empty | `check_namespace_manifest: source root does not exist: {SOURCE_ROOT}\n` |
| missing parser-token source | 1 | empty | `check_namespace_manifest: parser token source is missing: {PARSER_SOURCE}\n` |
| `missing_required_module` | 1 | empty | `check_namespace_manifest: required module is missing: EsArtifactCache\n` |
| one extra CLI operand | 2 | empty | `usage: check_namespace_manifest.sh [source-root [parser-token-source]]\n` |

These cases cover the initial A02 acceptance surface: a successful manifest,
an omitted parser renderer variant, duplicate-module collision, undeclared
import and extension, leaked private ABI call, missing literal include, and
public POSIX ABI declaration. The positive parser fixture uses the
same indentation structure as the vendored parser source. The full reference
additionally checks unknown imports/extensions, leaked `_impl` calls, bytecode
and lowerer renderer exhaustiveness, diagnostic reset completeness, and the
required module set; those paths are part of the source port but still need
dedicated regression fixtures before acceptance. The process-level harness at
`test/script_parity/namespace_manifest_launcher_test.elisascript` compares
each tuple against both programs and pins the public launcher's hash before
and after the matrix. It is source-only and remains unexecuted while compiler
validation is suspended. Each shell-reference result must satisfy its literal
or success-prefix oracle before the candidate is launched; a mismatched
reference receipt now fails closed rather than being paired with candidate
output. A pure fixture pins completed-status, exact-diagnostic, host-error,
spawn-failure, and successful-default-prefix admission behavior; it is not
runtime evidence until explicitly authorized and run. A case with neither a
golden nor a success contract is rejected instead of silently admitted.

The positive source root contains `ignored.elisa`, which redeclares
`EsRuntime`, and a local `.gitignore` that excludes it. The exact positive
manifest therefore also checks that the candidate follows the reference's
ripgrep ignore rules rather than auditing ignored source files.

The added negative fixtures also cover a POSIX ABI declaration outside
`EsRuntime`, both diagnostic renderer exhaustiveness checks, diagnostic reset
completeness, and the required-module set. Full runtime parity remains
unverified while compiler validation is held.

The shell reference and candidate also resolve omitted or empty source-root and
parser-token arguments relative to their own script directories. The launcher
matrix invokes no arguments and an empty first argument from `/`, requiring
both to produce a successful manifest with the expected header. It also passes
the positive fixture root with an omitted and with an empty parser path; both
must use the repository parser source and fail on its first unrendered variant,
`UnexpectedToken`. These cases verify defaults outside the repository working
directory without pinning checkout-dependent manifest paths.

Before allocating each complete source text, the candidate rechecks its byte
size against the aggregate-pass snapshot, then validates the loaded size again.
This narrows but does not eliminate the documented TOCTOU memory window for
concurrently modified files; concurrent-tree parity remains out of scope.
