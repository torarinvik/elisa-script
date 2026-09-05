# Elisascript migration inventory snapshot

This is the first read-only discovery snapshot for the replacement objective. It
is deliberately separate from a migration claim: a filename count does not say
whether a file is production code, a vendored dependency, generated output, an
example, or an abandoned experiment. No script in this inventory was executed.

Snapshot date: 2026-09-05  
Scan root: `/Users/torarinvikbjarko/Documents/Coding Projects`  
Scanner: `rg --files` with extension/name filters  
Repository baseline: `238e96a`

## Raw candidate counts

The counts below include files beneath the named project roots, including
vendored and generated material. They are intentionally over-inclusive until a
per-file disposition is recorded.

| Project root | Python `.py` | Perl `.pl` | AWK `.awk` | Shell (`.sh`, `.bash`, `.zsh`, `.fish`) | Makefiles |
|---|---:|---:|---:|---:|---:|
| `C++ projects` | 606 | 9 | 4 | 212 | 68 |
| `Elisa Projects` | 1,732 | 9 | 0 | 3,592 | 22 |
| `FSharpProjects` | 4 | 0 | 0 | 4 | 2 |
| `Go projects` | 56 | 0 | 0 | 68 | 9 |
| `Haskell Projects` | 0 | 0 | 0 | 0 | 0 |
| `Java Projects` | 0 | 0 | 0 | 0 | 0 |
| `Lean Projects` | 108 | 0 | 0 | 199 | 7 |
| `Ocaml Projects` | 0 | 0 | 0 | 0 | 0 |
| `Python Projects` | 2,021 | 0 | 0 | 17 | 0 |
| `Rust Projects` | 29 | 0 | 0 | 0 | 0 |
| `Swift Projects` | 0 | 0 | 0 | 0 | 0 |
| **Subtotal of listed roots** | **4,556** | **18** | **4** | **4,092** | **108** |

The shell-family total combines 4,090 `.sh` files, one `.bash` file, and one
`.fish` file. The complete raw totals are therefore 4,556 Python files, 18 Perl
files, 4 AWK files, 4,092 shell-family files, and 108 Makefiles; overlapping
extension/name filters explain why a root subtotal must not be interpreted as a
unique-script count. There are currently no `.pm` files in the scan result.

## First disposition rules

Every candidate receives one stable record before porting or deletion:

| Field | Required value |
|---|---|
| `path` | Absolute path and repository-relative path where applicable |
| `root` | Owning project root and repository identity |
| `kind` | Production, test, build/release, example, generated, vendored, abandoned, or unknown |
| `owner` | Maintainer/team or `unassigned` |
| `entrypoint` | Direct executable, imported module, Make recipe, CI hook, generated output, or none |
| `callers` | Static callers and operational trigger |
| `inputs` | argv, stdin, files, environment, cwd, network, clock, randomness, and permissions |
| `outputs` | Return/status, stdout/stderr bytes, files, network mutations, and logs |
| `dependencies` | Imports and external executables, separated into replaceable versus retained domain tools |
| `semantics` | Quoting, globbing, regex dialect, record separators, ordering, locale, encoding, and failure behavior |
| `risk` | Pure, filesystem-read, filesystem-write, process, network, release, or destructive |
| `disposition` | Port, wrap temporarily, retain as external tool, archive, or remove after acceptance |
| `acceptance` | Fixture, oracle, resource limit, platform matrix, and owner sign-off |

The inventory must distinguish an Elisascript port from a wrapper that merely
invokes the old Python/Perl/AWK interpreter. C/C++ compilers, Git, databases,
and project executables remain legitimate external domain tools when their
behavior is explicitly modeled as typed process effects.

## Prioritized discovery waves

1. **Elisascript and toolchain projects.** Separate compiler/bootstrap tests,
   parity harnesses, generated files, and actual production helpers. The high
   shell count is not a single migration target; each workflow needs its own
   owner, resource envelope, and no-respawn validation policy.
2. **Python projects.** Start with frequently operated CLIs and data tools,
   then classify package-heavy applications (graphics, numerical, HTTP, or ML)
   whose dependencies may require maintained typed foreign adapters.
3. **C++/Lean/Go projects.** Prioritize build, packaging, code-generation,
   emulator, and differential scripts because these directly exercise the
   process, filesystem, binary, and parity capabilities.
4. **Small language roots and examples.** Use these for early syntax and
   library ports only after they have a maintainer and an explicit production or
   educational disposition.

## Reproducible read-only scan

The snapshot can be regenerated without launching a compiler or legacy script:

```sh
for pattern in '*.py' '*.pl' '*.pm' '*.awk' '*.sh' '*.bash' '*.zsh' '*.fish' 'Makefile' 'makefile'; do
    rg --files "/Users/torarinvikbjarko/Documents/Coding Projects" -g "$pattern"
done
```

The command intentionally reports paths rather than executing or parsing them.
The next inventory increment should add a machine-readable manifest generated
from this path set, classify vendored/generated content, and attach owners and
fixtures. `scripts/inventory_candidates.sh` now supplies the read-only TSV
generator and [`docs/migration-inventory-schema.md`](migration-inventory-schema.md)
defines its fields. The generated output is intentionally not checked in until
records have reviewed owners and acceptance evidence; P1 remains open and no
legacy file is eligible for deletion. The candidate generator also refuses
roots above 200,000 regular files, so large project collections must be
partitioned before path de-duplication.

Extension-only discovery is supplemented by the compiler-free
`scripts/inventory_signals.sh` scanner. It records executable permission bits,
legacy interpreter shebangs, and inline Python/Perl/AWK command references in a
separate TSV report; those signals still require per-file ownership and
disposition review. The scanner fails closed above 200,000 regular files and
skips content files larger than 8 MiB, so the declared project roots must be
scanned in bounded slices rather than as one unbounded whole-drive job.
