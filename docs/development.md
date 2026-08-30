# Elisascript development builds

Use the compiler built from the local Elisa-core checkout when changing stage0 or
stage1 compiler code. From this repository, the local stage0 entry point is:

```sh
ELISA_LOCAL_COMPILER="../../Go projects/Elisa-core/compiler/bin/elisac"
"$ELISA_LOCAL_COMPILER" -emit test test/ir/elisascript_interpreter_test.elisa
```

The local binary keeps compiler changes isolated from the installed release at
`~/.elisac/elisac`; do not use the installed binary for stage0/stage1 validation.
The same `ELISA_LOCAL_COMPILER` setting should be used for the lowering,
interpreter, bytecode, source-loader, parser, lexer, semantic, and differential
test suites. Rebuild the local Elisa-core compiler first when its stage0 or stage1
sources change, then rerun the Elisascript suites from this checkout.

Elisascript source files use the `.elisascript` extension. The canonical source
loader and runner tests should be the first checks after a compiler rebuild because
they exercise parsing, semantic checking, lowering, verification, and execution
through the same local compiler path.
