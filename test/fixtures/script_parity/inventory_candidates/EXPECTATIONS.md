# Candidate inventory parity expectations

`test/script_parity/inventory_candidates_launcher_test.elisascript` creates a
private temporary tree and passes its canonical absolute path to both
`inventory_candidates.sh` and the public Elisascript launcher. The generated
tree includes hidden and ignored-by-`.gitignore` files, spaces, a UTF-8 name,
every recognized suffix family, root and nested Makefiles, classified risk and
generated paths, all six pruned directory names, a file symlink, a directory
symlink, and a shell-looking file that would create a marker if executed.
Neither scanner may execute candidate contents.

For the successful fixture both processes must exit 0, write an empty stderr,
and produce the exact header and records in the test's independently specified
golden manifest. The golden is globally bytewise sorted and includes
`ignored.py`, but excludes symlink aliases and every file under the six pruned
directories. It pins these risk/disposition rules: release/deploy/publish/install
path components are `release`; test/tests/fixture-prefixed parent components
are `test`; build/target/.github/.gitlab/.circleci are `build`; build/target/
dist/generated dispositions are `classify-generated`; other records are
`classify`.

Failure cases pin exact status and diagnostics with no stdout header:

| Case | Status | Stderr |
| --- | ---: | --- |
| Missing root | 2 | `inventory_candidates: scan root does not exist: <absolute-missing-path>\n` |
| Extra operand | 2 | `usage: inventory_candidates.sh [CODING_PROJECTS_ROOT]\n` |
| Tab in a requested root | 2 | `inventory_candidates: unsupported scan root contains a TSV delimiter or line break\n` |
| Tab in an entry path | 3 | `inventory_candidates: unsupported path contains a TSV delimiter or line break\n` |
| Newline in an entry path | 3 | `inventory_candidates: unsupported path contains a TSV delimiter or line break\n` |
| CR in an entry path | 3 | `inventory_candidates: unsupported path contains a TSV delimiter or line break\n` |

Traversal failures and entry-ceiling failures use status 3 and the shared
canonical-root diagnostic `inventory_candidates: traversal failed or exceeded
a traversal limit for <root>\n`; the runtime adapter does not expose which
traversal condition failed. Resource boundaries have not been executed under
the current validation hold.

The test also asserts that the candidate-looking shell file did not create its
marker. The source pins the public launcher path and digest before and after
the comparisons and passes both compiler-selection environment variables as
the required pinned local compiler to each child process. It has not run under
the current validation hold. Large resource-ceiling boundaries, unreadable
subtrees, unusual permission states, and non-UTF-8 filesystem names remain
unqualified. Default-root parity from arbitrary working directories also
remains open; all parity cases pass the same explicit canonical root.
