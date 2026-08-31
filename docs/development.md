# Elisascript development builds

Use the compiler built from the local Elisa-core checkout when changing stage0 or
stage1 compiler code. From this repository, the local stage0 entry point is:

```sh
ELISA_LOCAL_COMPILER="../../Go projects/structpy-tree/compiler/bin/elisac"
run_bounded() {
  source_file="$1"
  log_file="$(mktemp -t elisascript-compiler.XXXXXX)"
  "$ELISA_LOCAL_COMPILER" -emit lowered "$source_file" >"$log_file" 2>&1 &
  compiler_pid=$!
  started_at="$(date +%s)"
  rss_guard=0
  timeout_guard=0
  while kill -0 "$compiler_pid" 2>/dev/null; do
    rss_kb="$(ps -o rss= -p "$compiler_pid" 2>/dev/null | tr -d ' ')"
    if [ -n "$rss_kb" ] && [ "$rss_kb" -gt 1800000 ]; then
      kill -KILL "$compiler_pid" 2>/dev/null || true
      rss_guard=1
      break
    fi
    now="$(date +%s)"
    if [ $((now - started_at)) -gt 120 ]; then
      kill -KILL "$compiler_pid" 2>/dev/null || true
      timeout_guard=1
      break
    fi
    sleep 1
  done
  wait "$compiler_pid"
  compiler_exit=$?
  cat "$log_file"
  unlink "$log_file"
  [ "$rss_guard" -eq 0 ] && [ "$timeout_guard" -eq 0 ] && return "$compiler_exit"
  return 125
}

# Start with a lowering-only or small one-function fixture.  Run the larger
# executable test suites only after this guard remains below the RSS ceiling.
run_bounded test/ir/elisascript_interpreter_test.elisa
```

The local StructPy checkout keeps compiler changes isolated from the installed
release at `~/.elisac/elisac` and the Elisa-core main-worktree binary; do not use
either installed or main-worktree binaries for stage0/stage1 validation. Keep
validation bounded with an RSS-and-time watchdog that terminates the compiler
before its RSS exceeds the host-safe ceiling; a virtual-memory limit alone is not
sufficient. The wrapper above deliberately uses `-emit lowered` first; do not
relaunch the full interpreter fixture after an RSS incident until a smaller
bounded repro has stayed under the guard.
The same `ELISA_LOCAL_COMPILER` setting should be used for the lowering,
interpreter, bytecode, source-loader, parser, lexer, semantic, and differential
test suites. Rebuild the local Elisa-core compiler first when its stage0 or stage1
sources change, then rerun the Elisascript suites from this checkout.

For a reusable guard instead of an inline shell function, run
`scripts/run_bounded_lowering.sh test/ir/elisascript_lowering_test.elisa` from
this repository. It accepts one or more small fixtures, refuses any compiler
path outside the pinned StructPy checkout, and uses the same 1,800,000 KB RSS and
120-second defaults. The limits can only be changed explicitly with
`ELISASCRIPT_RSS_LIMIT_KB` and `ELISASCRIPT_TIME_LIMIT_SECONDS`.

Elisascript source files use the `.elisascript` extension. The canonical source
loader and runner tests should be the first checks after a compiler rebuild because
they exercise parsing, semantic checking, lowering, verification, and execution
through the same local compiler path.
