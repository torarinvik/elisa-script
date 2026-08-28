# Elisascript shared typed IR

Elisascript uses one backend-neutral, verified IR between its typed frontend and
all execution engines. Bytecode, an interpreter, LLVM JIT/AOT, and Wasm are
lowerings of this IR; none receives the source AST directly.

## Initial representation

The first implementation in `src/ir` is a flat SSA control-flow graph. Functions
own flat instruction and operand pools, while blocks and instructions reference
contiguous slices; this avoids nested region ownership and is ready for canonical
serialization:

- Functions have explicit parameter and return types, effect rows, blocks, and an entry block.
- Blocks have typed parameters, ordered instructions, and exactly one terminator.
- Every nonzero value id has one definition within its function.
- Control-flow targets are block ids rather than backend labels.
- Source spans survive lowering for diagnostics and reproducible failures.
- Nominal types retain their Elisa name instead of collapsing to a machine representation.

The vocabulary intentionally contains no LLVM values, native registers, pointer
sizes, bytecode slots, or host ABI facts. Those belong to target-specific lowering.
The copied compiler's EASM remains a later machine-level representation and is
not used as the shared IR.

## Algebraic effects

`Perform` is an IR operation, not an early rewrite to a runtime function call. It
names an effect family and operation separately, carries typed operands/result,
and must be covered by the enclosing function's effect row. A backend may lower
it to an interpreter dispatch, VM opcode, continuation operation, or optimized
native handler only after semantic optimizations are complete.

Elisa's existing `signal Family.Operation` syntax lowers directly to `Perform`.
The function effect row may grant the complete operation or its family. Every
perform receives a stable source-derived trace identity.

## Differential testing

`Perform` and `Observe` require stable, nonzero trace-site ids. These ids are
frontend identities and therefore remain comparable across bytecode, JIT, AOT,
Wasm, reference, and candidate executions even when their machine instruction
layouts differ. Trace labels are descriptive only; identity does not depend on
text or source formatting.

`observe(value)` is a compiler-known, value-consuming intrinsic that lowers to
`Observe` without defining a result. It provides a typed, backend-independent
checkpoint for differential tests without depending on stdout or debug logging.

## Dynamic handlers

Elisascript uses lexically scoped, dynamically selected handlers:

```elisa
with handler sandbox:
    run_build()
```

The IR declares each handler's covered effect families, introduced effects,
`error[...]` sets, and continuation policy (`Terminal`, `Linear`, `Affine`,
`MultiReplay`, or `MultiClone`). `HandlerPush` and `HandlerPop` delimit dynamic installation. `Resume`
names the handler whose continuation it consumes; the verifier rejects resume for
a terminal handler and rejects unknown or unbalanced handler operations.

Handler failures are stored in explicit error-set rows on handlers and functions.
They are not represented as `Result` values and are not merged into effect rows.
Installing a handler subtracts its handled families from the effects required at
that program point. Effects introduced by running the handler and its explicit
`error[...]` sets are propagated into the enclosing function's respective rows.
The verifier checks both sides of this contract independently.
Structured lowering emits explicit handler unwinding before `return`, `break`,
and `continue`. Loop exits unwind only handlers installed inside that loop;
handlers surrounding the loop remain active until their own lexical scope ends.

Multi-shot behavior is never inferred. `MultiClone` requires every captured value
to be classified `Unrestricted`; affine, linear, borrowed, region-bound, and opaque
captures are rejected. `MultiReplay` re-executes from a deterministic checkpoint
and requires every effect introduced by the handler to appear in its statically
verified replay-safe effect set. This makes replay the preferred early mechanism
for search, model checking, and differential exploration while reserving cloning
for continuations whose complete captured environment is provably duplicable.

The IR verifier rejects missing/duplicate trace sites, ungranted effects,
undefined or duplicate SSA values, bad entry blocks, unknown branch targets, and
malformed terminators before a backend runs. It also validates SSA dominance, so
a value created in one branch cannot be consumed from its sibling branch. Every backend must consume only a
verified module, preventing backend-specific recovery from becoming an observable
semantic difference.

Core operation types are verified rather than delegated to a runtime engine.
Copies preserve their exact type; arithmetic requires identical numeric operands
and a matching result; remainder is integer-only; equality and ordering produce
booleans over their supported operand families. Direct calls must name a declared
function and match its parameter and return types exactly. There are no implicit
integer-width or integer/float conversions at the IR boundary.

The AST-to-IR boundary reports the same mistakes as structured `TypeMismatch`
lowering issues, before a backend sees the module. This covers declared binding
initializers, mutation without type changes, unary and binary operators, boolean
conditions, conditional-expression arm agreement, returns, array indices, and
direct-call arity and parameter types. Function signatures are predeclared, so
forward calls receive the same checks as calls to earlier declarations.

Direct calls also preserve algebraic-effect and `error[...]` contracts. Lowering
adds every unhandled callee effect to the caller effect row and propagates callee
error sets independently. The verifier repeats this check from IR alone: a
dynamically active handler may discharge a covered effect family, while errors
must still appear explicitly in the caller's error row.

## Reference interpreter

`interpret` is the first executable consumer of verified IR and the semantic
oracle for later bytecode, JIT, and native backends. Its initial core executes
integer and boolean scalars, text constants, homogeneous immutable arrays,
indexing, array length, arithmetic and comparisons, direct calls, branches,
loops, SSA edge arguments, and returns. `HandlerPush` and
`HandlerPop` preserve lexical execution structure while effect dispatch and
continuation resumption remain the next interpreter increment.

Interpreter failures use `error[InterpretError]`, never a result wrapper. Stable
`observe` events and array elements are appended to caller-owned storage; this
gives differential testing an ordered trace and keeps region-bearing collections
out of the error-union return ABI. Invalid indexing is a typed
`IndexOutOfBounds` failure. A deterministic step limit makes runaway programs a
typed `StepLimitExceeded` failure.

The interpreter's opcode dispatcher is an Elisa `machine` over the closed
`Opcode` enum. Every opcode is named explicitly—there is no wildcard arm—so
adding an instruction forces the semantic oracle to classify it at compile
time. Machine arms only drive dispatch state; typed arithmetic and value checks
live in focused helpers, respecting Elisa's machine ownership rules. Decimal
lexeme evaluation likewise uses explicit whole, fraction, exponent, and scaling
states instead of nested scanner conditionals.

## Planned increments

The AST lowering now handles functions, typed parameters and returns,
integer/float/string/character/boolean constants, immutable local bindings, direct
calls, unary numeric negation and boolean negation, the core arithmetic family
(`+`, `-`, `*`, `/`, `%`), integer complement and bitwise operations (`~`, `&`, `|`, `^`) and shifts
(`<<`, `>>`), all six scalar comparisons, short-circuit `and`/`or`,
conditional expressions, returns, structured `if` branches with
fallthrough merges, and `while` loops with explicit headers/backedges/exits.
It also lowers homogeneous immutable array literals, scalar `darray[T]`/`array[T]`
type annotations, integer indexing, and the `.count` field. Empty literals use
their expected array type in bindings, assignments, returns, and call arguments,
so `[]` never introduces an untyped dynamic collection. Nested array literals
remain explicit lowering errors until recursive IR type descriptors are defined.
Unlabeled `break` and `continue` resolve through nested loop-target stacks. It produces structured
lowering issues for every unsupported construct; it never drops a statement or
expression silently.

Control-flow edges carry arguments through a function-owned flat pool. The verifier
requires each edge slice to match its target block parameters in both arity and type.
This is the backend-neutral equivalent of SSA phi nodes and is the basis for values
merged from mutable branches and loop backedges.

Logical and conditional expressions use those same CFG primitives. `and`/`or`
branch before lowering the right operand and merge through a typed block parameter,
so skipped calls, effects, and observations are genuinely not executed. Conditional
expressions likewise lower each value arm into a separate block rather than an eager
select instruction.

Elisa value blocks lower their leading statements in a lexical binding scope and
then yield the tail expression. This makes the idiomatic multiline `return if ...:`
form executable while ensuring branch-local names do not leak past the value block;
mutations of already-existing outer SSA bindings remain visible as expected.

Straight-line `<-` mutation is reconstructed as an SSA name rebind: the
new expression result becomes the binding's current value and no memory slot is
introduced. Arithmetic and bitwise compound assignments use the same mechanism,
including `+=`, `-=`, `*=`, `/=`, `%=`, `&=`, `|=`, `^=`, `<<=`, and `>>=`.
Mutation across `if` fallthrough edges is reconstructed with typed
edge arguments and a fresh merge-block parameter. Loop-carried locals receive
typed header and exit parameters; initial entry, normal backedges, `continue`, and
`break` edges all pass the binding's current SSA value.

1. Add complete structural types, handler installation, resume,
   and explicit ownership/region operations.
2. Define canonical serialization and hashing for artifacts and trace-site ids.
3. Extend the reference interpreter from its current scalar/control-flow core
   through effects, errors, structural values, and ownership operations. The
   interpreter already executes verified integer/boolean/text constants,
   arithmetic and comparisons, direct calls, SSA block arguments, branches,
   loops, returns, handler installation/uninstallation, and `observe` trace sites.
4. Lower the same verified modules to bytecode and LLVM, then test all engines
   differentially against the interpreter.
