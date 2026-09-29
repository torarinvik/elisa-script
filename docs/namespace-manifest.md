# Namespace manifest and collision audit

Elisascript-owned implementation is divided into qualified namespaces:

| Namespace | Responsibility | Public surface | Private surface |
|---|---|---|---|
| `EsArtifactCache` | Bounded ESIA/ESBC admission and publication-state contracts | Cache classification, migration admission, and staged/committed/restart transitions | Envelope-size policy and representation details |
| `EsFileAtomicPosix` | Descriptor-relative observations for atomic file sessions | Parent descriptor and destination identity snapshots | Metadata stability checks and digest construction |
| `EsFileReadAtPosix` | Bounded descriptor-relative regular-file reads | `read_regular_file_at` with no-follow name/descriptor identity checks | EINTR retry state and read cursor |
| `EsIr` | Source, typed IR, runtime model, interpreter, verification, serialization, and runner extensions | Contracts, runtime values, loader/runner entry points, verified operations | Cursors, dispatch state, pool predicates, host adapters, representation details |
| `EsIrArtifact` | Artifact metadata helpers | Artifact construction and fingerprint correlation | Metadata validation internals |
| `EsBytecode` | Direct bytecode lowering and execution | Capability reports, artifact envelope APIs, execution entry points | Dispatch cursors, packed-layout checks, VM frames and helpers |
| `EsRuntime` | POSIX host bridge | Typed forwarding operations and host layout records | `@link_name` declarations and ABI symbols |
| `EsProcessScalarAbi` | Selected 32-bit process scalar ABI admission | Range/errno-admission predicates, grouped limits/rejection sentinel and low-eight-bit exit conversion | No native symbols or handles |
| `EsDriver` | Native CLI boundary | `EsDriver::run` | Argument collection, diagnostics, and parsing helpers |
| `EsDifferential` | External-oracle and backend parity harness | Case/run/comparison APIs | Process staging, snapshot ownership, comparator state machines |

`scripts/check_namespace_manifest.sh` performs a compiler-free collision and
assembly audit of the Elisascript-owned `src/` tree. It rejects duplicate
top-level module declarations, rejects `extend` blocks targeting undeclared
modules, verifies every literal include resolves relative to its declaring
file, requires the seven expected qualified modules, and emits a TSV summary of
every module and extension file together with its explicit `public:`/`private:`
sections. It also checks that every public `IssueKind` variant appears in the
driver's bytecode-diagnostic renderer, so verifier additions cannot silently
fall back to an unknown diagnostic spelling, and applies the same exhaustiveness
check to `LowerIssueKind` source-lowering diagnostics.
Parser diagnostics are checked in the same way for every `Ast::ParseErrorKind`
branch. Semantic wording remains delegated to the exhaustive vendored
`Semantic::diagnostic_message` renderer; the launcher supplies it only a
region-independent diagnostic kind and bounded coordinates.
The audit also walks every `src/runtime` extension: each `@link_name`/`extern`
ABI declaration must be inside an `EsRuntime` extension and a `private:`
section, and no higher-level source may call an `_impl` ABI symbol directly.
This keeps libc names and platform-specific signatures behind the typed runtime
forwarders while still preserving their stable link names.
The vendored `Semantic` and standard-library namespaces are intentionally
outside this check and remain governed by `vendor/elisa-compiler/SOURCE.md`.

`scripts/check_namespace_manifest.elisascript` is the Elisascript port candidate.
It implements these same declaration, import, include, runtime visibility,
renderer/reset, required-module, and TSV-manifest checks. It accepts an optional
source root and parser-token source so both implementations can inspect the
same fixtures. For byte-for-byte comparison, pass both paths explicitly: the
shell script defaults relative to its own location, while the Elisascript
candidate defaults to `src` and `vendor/elisa-compiler/src/parser/parser_tokens.elisa`
relative to the caller's working directory.

The candidate bounds its input to 4,096 source files, 4,096 directories,
65,536 visited entries, 16,384 entries in any one directory, 2 MiB per source
file, 16 MiB aggregate source bytes, and 2 MiB for the separately supplied
parser-token file. It walks iteratively through `Path.iterdir`, skips hidden
components and symlinks, and does not apply ripgrep ignore-file rules; parity is
therefore currently scoped to tracked, visible source roots without ignored
`.elisa` files. The runtime materializes one directory listing before the
candidate can apply its 16,384-entry policy; that individual listing is itself
capped by the filesystem API at 262,144 entries / 64 MiB of names. The source
must remain stable during the run: `file_size` preflights and `read_text` is
checked afterward, but a concurrent replacement can still exceed the intended
peak allocation before that post-read check. These differences and the fixtures
are documented but not runtime-qualified; the candidate is not yet accepted as
a replacement until its status/stdout/stderr and fixture matrix are executed
through the public launcher after compiler validation is reauthorized.

Every new public symbol must be added to its owning namespace deliberately and
documented at the boundary. Tests should use public inspection APIs rather than
making cursor, state-machine, or host-ABI representation details public.
