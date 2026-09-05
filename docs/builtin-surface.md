# Builtin surface audit

Elisascript currently has two builtin authorities: the vendored semantic seed
table and the scripting lowerer's typed dispatch ladder. They are intentionally
kept separate until Q03 can replace them with one typed registry carrying
spelling, receiver shape, argument/return types, effects, errors, and backend
opcode mapping.

Until that refactor lands, run the compiler-free audit:

```sh
bash scripts/check_builtin_surface.sh
```

The audit extracts every `callee_name == "..."` global dispatch spelling from
`src/ir/lower_ast.elisa`, extracts both the large semantic seed row and its
`add_symbol("...")` extensions, and fails closed if any lowerer spelling is not
seeded. Receiver `method_name` strings are deliberately excluded because they
are selected after receiver type checking rather than by bare-name lookup.
This check catches one class of frontend drift but does not claim that the
duplicated authorities have identical signatures; the typed registry and its
generated semantic/lowering/verifier consistency check remain required.
