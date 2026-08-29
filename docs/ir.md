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

Every verified module also has canonical structural bytes through
`canonical_module_bytes(module)` and a compact fingerprint through
`module_fingerprint(module)` (with `canonical_module_hash` as the explicit
algorithm name). The reference implementation uses fixed little-endian scalar
encodings and schema markers over types, source spans, trace sites, ordered SSA
pools, blocks, functions, and handlers. The module stream begins with `ES` and
format version `1`; collection lengths are included before their elements, and
hashing those exact bytes yields the module fingerprint. No pointers, allocator
addresses, padding, host word sizes, or backend instruction layout enter the
encoding. This makes the bytes and their deterministic
non-cryptographic `u64` fingerprint suitable for backend and differential-test
artifact correlation; neither is a security identity or a replacement for IR
verification.

`EsIrArtifact.ModuleArtifact` is the small typed metadata envelope used by
differential reports today. It records format version, backend label, source
revision, and fingerprint; the owned canonical byte stream is kept as the
separate `canonical_module_bytes` value so its inferred region remains with the
artifact writer. `artifact_fingerprint_matches_module` provides the corresponding
constant-time metadata check.

## Bytecode lowering

`EsBytecode.lower_bytecode` is the first backend facade. It accepts only a module
with zero verifier issues, copies the typed instruction/operand/edge pools and
handler metadata in declaration order, and adds a deterministic block-offset table
for each function. `BytecodeBlock.terminator` remains the original typed CFG
terminator, so branches and edge arguments are not rewritten into host labels or
machine addresses. A malformed module returns the verifier issues and an empty
bytecode module; no backend-specific recovery is permitted. The initial bytecode
representation deliberately preserves semantic `Opcode` values, giving a future
packed encoder and VM one checked source of truth while the reference interpreter
continues to define behavior.

Each bytecode function also carries a parallel `dispatch_classes` table. The
exhaustive `bytecode_opcode_class` state machine groups every semantic opcode into
the handler family that a packed VM will use (literal, frame, aggregate, process,
effect, continuation, and so on). `bytecode_dispatch_table_valid` walks functions
and instructions with explicit preflight states and rejects a missing, stale, or
invalid class entry before execution.

`bytecode_next_control` is the first executable packed-loop primitive. Its
program-counter cursor advances one instruction at a time and then selects a
verified `Return`, `Jump`, `Branch`, or `Invalid` action through explicit control
states. Branch selection is supplied by the value engine; this keeps control-flow
ownership separate from effects and runtime values while the remaining opcode
families are migrated.

`EsBytecode.execute_bytecode` is the bootstrap execution entry point. It rebuilds
the verified IR shape from the bytecode tables inside a scoped allocation region
and delegates to `EsIr.interpret`, so effects, dynamic handlers, errors, process
capture, and continuations have exactly the reference semantics while the packed
bytecode dispatch loop is developed. The bytecode test suite compares result,
step count, and observation trace/value against direct IR interpretation.

## Algebraic effects

`Perform` is an IR operation, not an early rewrite to a runtime function call. It
names an effect family and operation separately, carries typed operands/result,
and must be covered by the enclosing function's effect row. A backend may lower
it to an interpreter dispatch, VM opcode, continuation operation, or optimized
native handler only after semantic optimizations are complete.

Elisa's `signal Family.Operation` and `signal Family.Operation(payload, ...)`
syntax lower directly to `Perform`; payload expressions are evaluated once in
source order and become its typed operand slice.
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
`MultiReplay`, or `MultiClone`). `HandlerPush` and `HandlerPop` delimit dynamic
installation. `Resume` names the handler whose continuation it consumes and
requires one payload operand plus a typed result; the verifier rejects terminal
handlers, malformed payload/result pairs, unknown handlers, and unbalanced
handler operations.
Executable handler clauses map an exact effect family and operation to an ordinary
typed IR function. At each covered `Perform`, verification matches the performed
payload to that function's parameters and its return type to the resumed value.
Clause families must belong to the handler coverage set, callback symbols must
exist, and duplicate operation clauses are rejected. Terminal handlers cannot use
this resuming clause form; nonterminal policies select whether the captured frame
is consumed once (`Linear`/`Affine`) or remains available for repeated callback-local
resumptions (`MultiReplay`/`MultiClone`).

Handler failures are stored in explicit error-set rows on handlers and functions.
They are not represented as `Result` values and are not merged into effect rows.
Installing a handler subtracts its handled families from the effects required at
that program point. Effects introduced by running the handler and its explicit
`error[...]` sets are propagated into the enclosing function's respective rows.
The verifier checks both sides of this contract independently.
Structured lowering emits explicit handler unwinding before `return`, `break`,
and `continue`. Loop exits unwind only handlers installed inside that loop;
handlers surrounding the loop remain active until their own lexical scope ends.

Multi-shot behavior is never inferred. The reference interpreter executes a
callback's `Resume` as a typed tail resumption for `Linear` and `Affine`: its
payload becomes the value of the suspended `Perform`, the callback frame stops
immediately, and the continuation frame is consumed exactly once. A missing,
already-consumed, or terminal continuation raises `InterpretError.InvalidContinuation`.
`MultiReplay` and `MultiClone` now retain their captured frame while the callback is
active, so each `Resume` re-enters the suspended function at the instruction after
`Perform`, with a fresh copy of its SSA environment and dynamic-handler stack. Each
payload therefore observes the same post-`Perform` computation independently; the
enclosing `Perform` receives the callback's final return value. The frame records the
resumption count and stores its flat snapshot in machine-owned pools. `MultiClone` requires every captured value to be classified
`Unrestricted`; affine, linear, borrowed, region-bound, and opaque captures are
rejected. `MultiReplay` requires every effect introduced by the handler to appear in
its statically verified replay-safe effect set. The snapshot now includes the
active direct-call chain, so a handled effect in a helper replays the helper's
post-`Perform` suffix and each caller's post-call suffix in order. A future
increment can replace this flat replay chain with a general suspended-stack
object for non-call control transfers.

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
Explicit integer suffixes (`u8`, `u16`, `u32`, `u64`, `usize`, `i8`, `i16`,
`i32`, `i64`, and `isize`) lower to their exact signedness and bit width. The
suffix is stored per AST literal rather than inferred from line metadata, so two
differently suffixed literals on the same line cannot exchange types. `char` and
`u8` are distinct IR families: characters participate in text operations, while
`u8` is an unsigned numeric type. Unsuffixed integer literals remain `i64`, and
no implicit widening occurs in arithmetic or comparisons. Narrow explicit literals
must fit their suffix range. Signed minimum spellings are lowered atomically—such
as `-128i8`—so the compiler never has to construct the invalid intermediate
positive literal `128i8`; negating an explicitly unsigned literal is rejected.
The reference interpreter applies checked fixed-width semantics to narrow integer
addition, subtraction, multiplication, division results, left shifts, and signed
negation. A result outside its declared type raises `InterpretError.IntegerOverflow`
through Elisa's `error[...]` channel. Unsigned complement masks unused host bits, so
`~1u8` is `254u8` rather than the host `i64` value `-2`. These checks happen before
the host operation wherever the host intermediate could overflow.
Compiler-known typed literals use `Named` constants with immutable text payloads;
runtime `sview` adaptation uses explicit `MakePath`, `MakeGlob`, `MakeRegex`, and
`MakeUrl` constructors (with `MakeExecutable` for the existing executable adapter).
The verifier admits both representations, and the interpreter retains the text
payload while all static compatibility decisions continue to use the nominal IR
type.
`RegexSearch` is a separate semantic opcode with the exact signature
`Text × Named(Regex) -> Bool`. The reference interpreter executes it through an
explicit search machine with greedy backtracking; future bytecode, JIT, and native
lowerings therefore share the operation contract without inheriting a host
language's regex behavior. Character ranges and Perl-style shorthand classes have
fixed ASCII definitions rather than platform locale semantics. Top-level
alternation is split only at unescaped pipes outside character classes, and each
branch runs through the same bounded matcher states. Parenthesized groups are
matched recursively, including nested alternation and quantifiers, but do not
capture values.
`RegexReplace` has signature `Text × Named(Regex) × Text -> Text`. It reuses the
same branch matcher to locate non-overlapping spans, copies unmatched and literal
replacement bytes into fresh storage, and advances after zero-width matches so an
empty pattern cannot loop forever. Capture groups and replacement interpolation are
reserved until recursive regex match values are defined.

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
`PathExists` is the first concrete filesystem opcode. Its verified signature is
`Named(Path) -> Bool`, and verification also requires `File.Read` in the containing
function's effect row. Lowering adds that effect automatically. The interpreter
copies the path into a NUL-terminated Elisa-owned buffer before calling the
self-hosted core file-I/O layer, so a length-delimited `sview` is never passed to
libc as though it were a C string.
`ReadText` extends that contract to whole-file input with verified signature
`Named(Path) -> Text`. Its function must carry both `File.Read` and `FileIoError`;
lowering supplies both and the verifier rejects either omission. The interpreter
uses Elisa's stdio bindings, checks every open/seek/read/close transition, and
returns one owned length-delimited buffer. Empty files return empty text, while any
I/O failure becomes `InterpretError.FileIo` at the reference-interpreter boundary.
`WriteText` has verified signature `Named(Path) × Text -> usize` and requires
`File.Write` plus `FileIoError`. Execution opens in replacement mode, verifies the
complete byte count, checks close status, and returns that count. A partial write
never produces a successful result, and empty text still creates or truncates the
target file deterministically.
`RemovePath` verifies as `Named(Path) -> Bool` with `File.Write`. It calls Elisa's
core unlink wrapper using the same owned NUL-terminated path conversion as the other
filesystem operations. Missing paths produce `false`; they are not conflated with
interpreter failure or wrapped in a result value.
`CopyPath` verifies as `Named(Path) × Named(Path) -> Bool` with `File.Read` and
`File.Write`, plus `FileIoError`. It copies the complete length-delimited source
bytes into a replacement destination, including embedded NUL bytes. `MovePath` has
the same typed path pair and `FileIoError` but only requires `File.Write`; it uses
the POSIX rename boundary. Both operations are available on the direct bytecode
filesystem path as well as the reference interpreter.
`RunProcess` verifies as `Named(Executable) × Array[Text] -> Int(signed, 64)` and
requires `Process.Run` plus `ProcessError`. The interpreter executes it directly as
a POSIX `fork`/`execvp`/`waitpid` state transition with a NUL-terminated argv. No
command string or shell expansion exists between typed IR and the operating system.
The explicit `executable(text)` constructor adapts a runtime `Text` value to the
nominal `Executable` type for validated runner configurations. It rejects empty or
embedded-NUL names at execution time; every process opcode applies the same NUL
check to its executable and argument values before constructing C strings.
`CaptureProcessStdout` has the same operands, effect, and error row, with `Text` as
its result. Its opcode is handled by the interpreter's exhaustive Elisa dispatch
machine. Execution redirects only stdout into an anonymous temporary file, reaps
the child, and returns owned length-delimited bytes. It does not reinterpret output
as a C string, impose a pipe-sized backpressure limit, or capture stderr.
`CaptureProcessStderr` has the same verified signature and redirects descriptor 2
instead; descriptor 1 remains inherited. The shared stream-capture implementation
keeps byte ownership, wait behavior, and shell-free argument handling identical.
`CaptureProcessStdoutWithStdin` verifies as `Named(Executable) × Array[Text] × Text
-> Text` with the same `Process.Run` effect and `ProcessError` row. The interpreter
stages the input in a temporary file, redirects descriptors 0 and 1 in the child,
and drives input writing and process waiting through explicit state machines before
returning the complete owned stdout snapshot.
`CaptureProcessResult` is the differential-testing primitive: it has the same typed
 executable, argument-vector, and stdin operands but returns nominal `ProcessCapture`
 data containing the exit status, stdout, and stderr from one child execution. The
 child redirects descriptors 0, 1, and 2 to separate temporary files; the parent
 waits before reading both complete streams, so a reference process is never run
 three times merely to compare its outputs. `process_exit_status`, `process_stdout`,
 and `process_stderr` are typed accessors over that value. The capture and accessor
 opcodes are separately verified and dispatched explicitly by the interpreter.
`GetEnvironment`, `SetEnvironment`, and `UnsetEnvironment` operate on `Text`
operands. Reads produce owned `Text` under `Environment.Read`; mutations produce
`Bool` under `Environment.Write`. All three require `EnvironmentError`, reject C
string truncation hazards, and execute through explicit exhaustive opcode arms.
`CreateDirectory`, `RemoveDirectory`, and `ChangeDirectory` verify as
`Named(Path) -> Bool` with `Directory.Write` and `DirectoryError`.
`CurrentDirectory` takes no operands, returns `Named(Path)`, and requires
`Directory.Read` plus the same error. All four have explicit opcode-machine arms;
the cwd result is copied before the POSIX allocation is released.
`ListDirectory` verifies as `Named(Path) -> Array[Text]` with `Directory.Read` and
`DirectoryError`. The reference interpreter drives `readdir` through an explicit
scan machine, copies each entry before the next transition, removes dot entries,
and sorts owned names before materializing the runtime array. The current low-level
entry layout bridge is isolated and Darwin-specific; other native targets must
supply their platform `dirent` layout without changing this IR contract.
`IsDirectory` verifies as `Named(Path) -> Bool` with `Directory.Read` and
`DirectoryError`. It has its own exhaustive dispatch arm and uses the same isolated
directory bridge that recursive glob traversal builds upon.
`ExpandGlob` verifies as `Named(Glob) -> Array[Text]` with `Directory.Read` and
`DirectoryError`. The interpreter performs component matching and recursive `**`
traversal in Elisa, filters symlink recursion, sorts and deduplicates owned matches,
and enforces a depth bound to make malformed/cyclic trees terminate deterministically.
`ReadStdin` verifies as `() -> Text` with `Console.Read` and `ConsoleError`;
`WriteStdout` and `WriteStderr` verify as `Text -> Int(unsigned, 64)` with
`Console.Write` and `ConsoleError`. The reference interpreter drives input until EOF
and drives output through explicit `Data/End/Error` and `Progress/Done/Error` stream
machines, preserving partial-write semantics and owned read results.
Named direct-call arguments are resolved against predeclared parameter labels and
then emitted in canonical signature order. Their expressions still execute once in
source order. Missing parameters materialize their Elisa default expressions in
declaration order with earlier resolved parameters in lexical scope. Duplicate or
unknown labels, missing required parameters, positional arguments after named ones,
and exact-type mismatches are structured lowering errors.

## Reference interpreter

`interpret` is the first executable consumer of verified IR and the semantic
oracle for later bytecode, JIT, and native backends. Its initial core executes
integer and boolean scalars, text constants, homogeneous immutable arrays,
array/text indexing, length, slicing, membership, and concatenation, arithmetic
and comparisons, direct calls, branches, loops, SSA edge arguments, and returns.
`HandlerPush` and `HandlerPop` maintain a real runtime stack shared across direct-call
frames. `Perform` searches it from innermost to outermost and invokes the exact typed
operation clause of the nearest covering handler; linear clauses return one resumed
value and execution continues. Handler lookup, clause selection, and callback
invocation are explicit interpreter state-machine states. A callback may instead
issue a typed tail `Resume`, which transfers its payload back to the suspended
`Perform` through a runtime continuation frame. Handler contract metadata without
an operation clause is deliberately not treated as executable behavior. Multi-shot
policies keep that frame active during callback execution, so repeated `Resume`
instructions are ordinary callback values; full suspended-stack replay and
environment cloning are later increments.

Interpreter failures use `error[InterpretError]`, never a result wrapper. Stable
`observe` events and array elements are appended to caller-owned storage; this
gives differential testing an ordered trace and keeps region-bearing collections
out of the error-union return ABI. Flat runtime arrays validate their complete
`[array_start, array_start + array_count)` storage range before every read, so
malformed values supplied by an adapter fail deterministically instead of
becoming an unchecked host-memory access. Invalid indexing is a typed
`IndexOutOfBounds` failure. A deterministic step limit makes runaway programs a
typed `StepLimitExceeded` failure. The private failure-to-error conversion is an
exhaustive Elisa machine over `InterpretFailure`, so adding a new runtime failure
cannot silently fall through to success or a generic result value.

The interpreter's opcode dispatcher is an Elisa `machine` over the closed
`Opcode` enum. Every opcode is named explicitly—there is no wildcard arm—so
adding an instruction forces the semantic oracle to classify it at compile
time. Machine arms only drive dispatch state; typed arithmetic and value checks
live in focused helpers, respecting Elisa's machine ownership rules. Decimal
lexeme evaluation likewise uses explicit whole, fraction, exponent, and scaling
states instead of nested scanner conditionals.
Terminator selection follows the same model: `select_terminator` drives explicit
return, jump, branch, and invalid states, with branch values supplied by the
frame evaluator before transition. Edge-argument validation remains in the
surrounding interpreter loop, keeping the control machine independent of storage
and effect-handler state.

The verified bytecode facade uses the same program-counter machine for execution.
Modules containing only the currently closed scalar, text, regex, and homogeneous-array
subset (boolean, 64-bit integer, or 64-bit float values, text/nominal constants,
including one nested array level,
array construction, nominal path/glob/regex/URL constructors, indexing, length, slicing, membership, concatenation, split,
join, typed integer parsing/formatting, regex search/replacement, indexed updates, unary/binary operators,
observations, pure direct calls, and typed filesystem/process operations) take a
direct packed-instruction path. Calls use recursive state-machine frames with one
shared step budget, storage, and
observation stream, so helper functions remain behaviorally identical to the
reference interpreter. The first filesystem operations (`PathExists`, `ReadText`,
`WriteText`, `RemovePath`, and `MakeExecutable`) use the same typed resource
wrappers as the oracle, while retaining the packed program-counter machine. Its
value dispatcher is itself an explicit state machine, and its direct binary helper
uses a typed selection machine that separates equality, floating-point, and integer
operations before reaching a terminal value state. The packed executor wraps the
control cursor in another explicit machine for block entry, condition staging,
instruction storage, jump-edge collection, and returns, so its direct loop has no
implicit host control-flow state. The eligibility gate rejects
other widths, arrays nested deeper than two levels, handlers, and continuations.
Integer divide/remainder/shift operations validate zero divisors, signed minimum
overflow, and shift counts before entering host arithmetic, preserving the typed
interpreter failures while remaining on the direct path.
The direct path uses the same overflow-safe flat-array range predicate as the
interpreter for indexing, slicing, membership, joining, concatenation, indexed
updates, equality, and process argument vectors; malformed external arguments
therefore cannot diverge between engines.
Process execution and capture (`RunProcess`, stdout/stderr
capture, stdin transport, and `ProcessCapture` accessors) use the same typed argv
and stream helpers as the oracle. Unsupported modules deterministically rebuild
the verified IR and use `interpret` as the semantic oracle until their bytecode
handlers are implemented. Environment reads and writes (`GetEnvironment`,
`SetEnvironment`, and `UnsetEnvironment`) likewise share typed wrappers and are
eligible for the packed path. Directory creation/removal, current-directory
queries, directory listing, directory checks, and glob expansion are also wired
through typed wrappers. Stdio read/write operations use the same stream state
machines and typed wrappers; handlers and continuations remain oracle-only.

## Planned increments

The AST lowering now handles functions, typed parameters and returns,
integer/float/string/character/boolean constants, immutable local bindings, direct
calls, unary numeric negation and boolean negation, the core arithmetic family
(`+`, `-`, `*`, `/`, `%`), integer complement and bitwise operations (`~`, `&`, `|`, `^`) and shifts
(`<<`, `>>`), all six scalar comparisons, short-circuit `and`/`or`,
conditional expressions, returns, structured `if` branches with
fallthrough merges, and `while` loops with explicit headers/backedges/exits.
`pass` is a true lowering no-op: it advances through the surrounding structured
control-flow state without manufacturing an instruction or runtime value.
It also lowers homogeneous immutable array literals, scalar `darray[T]`/`array[T]`
type annotations, integer indexing, and the `.count` field. Empty literals use
their expected array type in bindings, assignments, returns, and call arguments,
so `[]` never introduces an untyped dynamic collection. Arrays may nest one level
(`darray[darray[T]]`) using the flat descriptor's bounded structural fields; deeper
nesting remains an explicit lowering error until fully recursive IR descriptors are
defined.
Plain single-binder `for value in array` loops lower to explicit header, body,
latch, and exit blocks. The collection is evaluated once; length and indexing stay
typed IR operations. `continue` targets the incrementing latch, `break` targets the
exit, and mutations of outer bindings travel through typed loop parameters.
`for mutable value in values` additionally requires `values` to be a named mutable
array binding. Lowering records a scoped element-owner relation; every successful
`value <- replacement` or compound update immediately transitions the owner through
`SetIndex`. The updated array is loop-carried state, so writes survive conditional
and match merges, nested loops, `continue`, and `break` without hidden aliasing or
deferred writeback. Temporary collections, immutable owners, and mutable text
iteration are rejected statically.
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
The compiler-known `split(text, separator)` operation has the exact static type
`Text × Text -> Array[Text]` and lowers to the semantic `Split` opcode. It preserves
leading, trailing, and consecutive empty fields. An empty separator splits a
nonempty input into one-byte text views, while empty input produces an empty array;
this follows the same explicit byte model as indexing and iteration. The interpreter
stores fields in caller-owned value storage, so split results can be indexed,
compared structurally, iterated, and returned without hidden host allocations.
The inverse compiler-known `join(fields, separator)` operation has type
`Array[Text] × Text -> Text` and lowers to `Join`. Verification rejects non-text
arrays before execution; the interpreter also validates each runtime element and
constructs one owned output buffer. Empty arrays join to empty text, separators
appear only between fields, and empty fields remain observable.
`ParseInt` has type `Text -> Int(signed, 64)` and requires `ParseError` in the
function error row. Its state-machine parser accepts only an optional sign and
ASCII decimal digits, checks signed 64-bit overflow before each accumulation, and
raises `InterpretError.InvalidNumber` for malformed or out-of-range input. The
compiler-known `parse_int` call lowers to this opcode. `FormatInt` has type
`Int(signed, 64) -> Text`; it uses Elisa's permanent string runtime so the returned
view remains valid after the instruction and is eligible for the direct bytecode
path without introducing a shell or host-language conversion.
Exact-type `array + array` and `text + text` lower to the semantic `Concat`
operation rather than numeric `Add`. Array concatenation copies both inputs into
fresh value storage. Text concatenation copies both byte views into permanent,
length-aware Elisa runtime storage, so chained results and results involving
empty text do not borrow temporary buffers. Mixed element or collection types are
rejected statically.
Exact-type scalar arrays also support structural `==` and `!=`. The interpreter
compares lengths first and then elements deterministically from left to right;
empty arrays, slices, concatenated arrays, separate equal allocations, and shared
or copy-on-update storage therefore follow one value-semantic rule. Mixed array
element types remain static errors; nested arrays use the same recursive runtime
comparison within the supported one-level descriptor.
Statement-form `array.push(value)` and `array.extend(values)` are ownership-safe
SSA updates rather than hidden aliasing mutations. `push` constructs a typed
singleton and `extend` accepts the receiver's exact array type; both concatenate
into a fresh array value and rebind the receiver. Mutation discovery treats these
calls as assignments, so updates inside `if`, `while`, and `for` flow through the
same typed merge, header, latch, and exit parameters as explicit `<-` rebinding.
Named arguments, mismatched element types, and non-array receivers are rejected.
Lowering retains one mutability fact alongside every lexical binding. Plain locals,
parameters, loop variables, and match binders are immutable; `mutable` local type
markers and mutable parameters opt into SSA rebinding. `<-`, compound assignment,
`push`, and `extend` all check the same fact and produce the structured
`ImmutableBinding` issue before emitting an update. Scope truncation keeps names,
types, values, and mutability facts aligned across value blocks, match arms,
handlers, branches, and loops.
`mutable_array[index] <- value` lowers to the semantic `SetIndex` operation and
then rebinds the array's SSA name. Indexed `+=`, `-=`, `*=`, `/=`, `%=`, `&=`,
`|=`, `^=`, `<<=`, and `>>=` first enter an `Index` read state, apply the same
typed arithmetic or bitwise operation as scalar compound assignment, and finish
in `SetIndex`. The receiver must be mutable, the index must be an integer, and the
replacement must exactly match the element type. The interpreter checks bounds,
copies the source array into fresh value storage, replaces one element, and leaves
all aliases of the old array unchanged; invalid indices raise `IndexOutOfBounds`.
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

1. Add complete structural types and explicit ownership/region operations. The
   interpreter now replays the current suspended IR function frame and its active
   direct-call chain for `MultiReplay`/`MultiClone` with cloned SSA environments.
2. Define the artifact container and versioned metadata around the canonical IR
   bytes. The structural encoding and `u64` module fingerprint are already
   available for artifact correlation.
3. Extend the reference interpreter from its current scalar/control-flow core
   through effects, errors, structural values, and ownership operations. The
   interpreter already executes verified integer/boolean/text constants,
   arithmetic and comparisons, direct calls, SSA block arguments, branches,
   loops, returns, handler installation/uninstallation, and `observe` trace sites.
4. Lower the same verified modules to bytecode and LLVM, then test all engines
   differentially against the interpreter. The bytecode backend now has typed
   dispatch classes, table preflight, and a state-machine program-counter step;
   the next increment is wiring opcode-family handlers into that loop.
