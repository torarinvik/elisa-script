# Namespace-manifest port fixtures

Run both implementations with the same explicit source root. For the positive
case, also pass its `parser_tokens.elisa` as the second argument so neither side
uses its working-directory-relative default. Substitute the absolute
`SOURCE_ROOT` path in the expected output below. These are static expectations;
the compiler validation hold means neither implementation nor the candidate
has been executed on this matrix.

| Fixture | Status | Stdout | Stderr |
| --- | ---: | --- | --- |
| `positive` | 0 | `module\tfiles\tpublic_sections\tprivate_sections\nEsArtifactCache\t{SOURCE_ROOT}/cache.elisa;\t1\t0\nEsBytecode\t{SOURCE_ROOT}/bytecode.elisa;\t1\t0\nEsDifferential\t{SOURCE_ROOT}/differential.elisa;\t1\t0\nEsDriver\t{SOURCE_ROOT}/driver/elisascript.elisa;\t1\t0\nEsIr\t{SOURCE_ROOT}/ir/ir_model.elisa;{SOURCE_ROOT}/ir/lower_ast.elisa;{SOURCE_ROOT}/ir/runner.elisa;\t2\t1\nEsIrArtifact\t{SOURCE_ROOT}/ir_artifact.elisa;\t1\t0\nEsRuntime\t{SOURCE_ROOT}/runtime.elisa;{SOURCE_ROOT}/runtime/adapter.elisa;\t1\t1\n` | empty |
| `positive` with `positive/missing_parser_tokens.elisa` as parser source | 1 | empty | `check_namespace_manifest: parse diagnostic renderer omits ParseErrorKind.UnexpectedToken\n` |
| `duplicate` | 1 | empty | `check_namespace_manifest: duplicate module declarations:\nClash\n` |
| `missing_include` | 1 | empty | `check_namespace_manifest: missing include: {SOURCE_ROOT}/a.elisa -> missing_fragment.elisa\n` |
| `public_abi` | 1 | `{SOURCE_ROOT}/runtime/posix.elisa: POSIX ABI declaration is not private at line 3\n` | empty |

These cases cover the initial A02 acceptance surface: a successful manifest,
an omitted parser renderer variant, duplicate-module collision, missing literal
include, and public POSIX ABI declaration. The positive parser fixture uses the
same indentation structure as the vendored parser source. The full reference
additionally checks unknown imports/extensions, leaked `_impl` calls, bytecode
and lowerer renderer exhaustiveness, diagnostic reset completeness, and the
required module set; those paths are part of the source port but still need
dedicated regression fixtures before acceptance.
