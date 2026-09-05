# Namespace manifest and collision audit

Elisascript-owned implementation is divided into qualified namespaces:

| Namespace | Responsibility | Public surface | Private surface |
|---|---|---|---|
| `EsIr` | Source, typed IR, runtime model, interpreter, verification, serialization, and runner extensions | Contracts, runtime values, loader/runner entry points, verified operations | Cursors, dispatch state, pool predicates, host adapters, representation details |
| `EsIrArtifact` | Artifact metadata helpers | Artifact construction and fingerprint correlation | Metadata validation internals |
| `EsBytecode` | Direct bytecode lowering and execution | Capability reports, artifact envelope APIs, execution entry points | Dispatch cursors, packed-layout checks, VM frames and helpers |
| `EsRuntime` | POSIX host bridge | Typed forwarding operations and host layout records | `@link_name` declarations and ABI symbols |
| `EsDriver` | Native CLI boundary | `EsDriver::run` | Argument collection, diagnostics, and parsing helpers |
| `EsDifferential` | External-oracle and backend parity harness | Case/run/comparison APIs | Process staging, snapshot ownership, comparator state machines |

`scripts/check_namespace_manifest.sh` performs a compiler-free collision and
assembly audit of the Elisascript-owned `src/` tree. It rejects duplicate
top-level module declarations, rejects `extend` blocks targeting undeclared
modules, verifies every literal include resolves relative to its declaring
file, requires the six expected qualified modules, and emits a TSV summary of
every module and extension file together with its explicit `public:`/`private:`
sections. It also checks that every public `IssueKind` variant appears in the
driver's bytecode-diagnostic renderer, so verifier additions cannot silently
fall back to an unknown diagnostic spelling, and applies the same exhaustiveness
check to `LowerIssueKind` source-lowering diagnostics.
Parser diagnostics are checked in the same way for every `Ast::ParseErrorKind`
branch. Semantic wording remains delegated to the exhaustive vendored
`Semantic::diagnostic_message` renderer; the launcher supplies it only a
region-independent diagnostic kind and bounded coordinates.
The vendored `Semantic` and standard-library namespaces are intentionally
outside this check and remain governed by `vendor/elisa-compiler/SOURCE.md`.

Every new public symbol must be added to its owning namespace deliberately and
documented at the boundary. Tests should use public inspection APIs rather than
making cursor, state-machine, or host-ABI representation details public.
