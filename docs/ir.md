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
array/text indexing, length, slicing, membership, and concatenation, arithmetic
and comparisons, direct calls, branches,
loops, SSA edge arguments, and returns. `HandlerPush` and
`HandlerPop` preserve lexical execution structure while effect dispatch and
continuation resumption remain the next interpreter increment. Correct execution
requires handler operation clauses to be represented in the module first; handler
contract metadata alone is deliberately not treated as an executable callback.

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
Plain single-binder `for value in array` loops lower to explicit header, body,
latch, and exit blocks. The collection is evaluated once; length and indexing stay
typed IR operations. `continue` targets the incrementing latch, `break` targets the
exit, and mutations of outer bindings travel through typed loop parameters.
Text uses the same verified collection operations and loop CFG. In the current
Elisa-compatible `sview` model, `.count` is a byte count and `text[index]` or
`for character in text` yields one 8-bit `char`; invalid indices raise the same
typed `IndexOutOfBounds` interpreter error as arrays. This byte contract is
explicit rather than silently pretending to provide Unicode grapheme indexing.
`collection[low:high]` lowers to the dedicated typed `Slice` operation. Either
bound may be absent: the lower default is zero and the upper default is one
`Length` evaluation of the already-evaluated collection. Slices are half-open,
preserve the exact array or text type, and require `0 <= low <= high <= count`;
violations raise typed `IndexOutOfBounds`. Immutable array slices share their
backing value storage, while text slices are byte views under the `sview` contract.
Exact-type `array + array` and `text + text` lower to the semantic `Concat`
operation rather than numeric `Add`. Array concatenation copies both inputs into
fresh value storage. Text concatenation copies both byte views into permanent,
length-aware Elisa runtime storage, so chained results and results involving
empty text do not borrow temporary buffers. Mixed element or collection types are
rejected statically.
Statement-form `array.push(value)` and `array.extend(values)` are ownership-safe
SSA updates rather than hidden aliasing mutations. `push` constructs a typed
singleton and `extend` accepts the receiver's exact array type; both concatenate
into a fresh array value and rebind the receiver. Mutation discovery treats these
calls as assignments, so updates inside `if`, `while`, and `for` flow through the
same typed merge, header, latch, and exit parameters as explicit `<-` rebinding.
Named arguments, mismatched element types, and non-array receivers are rejected.
Membership lowers to the typed `Contains` operation. Array needles must exactly
match the element type; text accepts either an 8-bit `char` or a text substring.
Search is deterministic and linear, the empty text is contained in every text,
and `not in` remains the ordinary typed boolean `Not` of `Contains`. Consequently
membership composes with the existing branch-based short-circuit machinery.
Numeric range membership lowers to ordered control-flow states rather than
`Contains`. Ascending ranges first test `value >= low`, then test `value < high`
or `value <= high`; strict descending ranges first test `value <= start`, then
`value > end`. Each bound is evaluated exactly once, and `not in` applies the
ordinary typed boolean `Not` to the merged result. Strided range membership is
defined for positive integer constant strides. After the bounds states succeed,
an alignment state tests `(value - start) % stride == 0` for ascending ranges or
`(start - value) % stride == 0` for descending ranges. This state is never entered
for an out-of-bounds needle, and zero or dynamic strides are rejected statically.
Integer ranges use the same CFG shape. `low..<high` is exclusive ascending,
`low..=high` is inclusive ascending, and `high..>low` is strict descending.
The range-owned stride spelling (`low..<high..step`) requires a positive constant;
the latch adds or subtracts it according to direction, including after `continue`.
Scalar statement `match` lowers to an ordered comparison-and-branch state machine.
Integer, float, boolean, character, and text literal arms are typed against the
scrutinee; pin patterns compare an existing binding, and binding/wildcard arms
form catch-alls. A guarded arm receives a distinct CFG state: a false guard resumes
the ordered pattern chain, and its pattern bindings cannot escape into later arms.
Numeric range patterns use two comparison states: the lower-bound state branches
to an upper-bound state only when `value >= low`, then `..<` or `..=` selects a
strict or inclusive upper comparison. Bounds are evaluated as typed constants,
and guards run only after both comparisons succeed.
Each arm has lexical bindings, while mutations of outer locals converge through
typed merge-block parameters. Structural patterns remain explicit errors until
structural IR values are available.
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
