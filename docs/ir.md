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

Immutable, initialized module-level `const` declarations are lowered into typed
SSA constants at each function entry. They are ordinary lexical bindings, so a
parameter or local with the same name shadows the module constant. Scalar
`global` declarations live in `Module.globals`; `LoadGlobal` and `StoreGlobal`
provide shared storage across calls, with zero values for uninitialized bindings.
Scalar literals and one-level literal arrays/maps are encoded as flat global
payloads and materialized in the runtime arena. Nested aggregates and non-literal
initializers remain outside this lowering subset.

Tuple syntax `(a, b, ...)` is lowered through the same `MakeArray` operation after
each element is checked against one homogeneous `T`. In an explicit `darray[T]`
context this is also how `()` provides a typed empty array initializer. The IR does
not yet claim a first-class heterogeneous tuple representation, so heterogeneous
and unconstrained empty tuple values remain lowering diagnostics.

Destructuring assignment over literal tuple/array values evaluates all source
elements first and then performs typed SSA rebinds. Fresh `=` targets infer their
individual types, while `<-` and compound forms require mutable existing bindings;
dynamic homogeneous-array unpacking uses checked `UnpackArray` operations and
requires the runtime array length to equal the target count.

Aggregate `Type` fields remain bounded for compatibility with the first lowering,
but every lowered module also carries a pointer-free `TypeTable`. Its one-based
`TypeDescriptor` rows refer to child rows through a flat `u32` pool; interning
deduplicates `(kind, name, width, signedness, children)` structurally. This is the
recursive descriptor seam for future tuples, records, and arbitrarily nested
containers, without putting recursive values or allocator addresses in the IR.
Legacy inline fields stay populated while verifier and backend consumers migrate.

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

When a module has an interned `TypeTable`, the canonical stream appends tagged
descriptor-row and child-pool records before the function collection. Empty tables
are omitted so hand-built legacy modules retain their original version-1 encoding;
the table records are still included in the fingerprint whenever present.

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

`EsBytecode.execute_bytecode` selects the packed loop whenever all instructions
belong to the direct subset, including guarded error recovery. It rebuilds the
verified IR shape and delegates to `EsIr.interpret` only for modules that still
contain dynamic effects, handlers, continuations, shared module globals, or
another unsupported family. Global-bearing bytecode modules retain their global
table and use the interpreter fallback until the packed frame owns a global arena.
Both paths are checked against the same result, step count, and observation
trace/value contract in the bytecode tests.

## Algebraic effects

`Perform` is an IR operation, not an early rewrite to a runtime function call. It
names an effect family and operation separately, carries typed operands/result,
and must be covered by the enclosing function's effect row. A backend may lower
it to an interpreter dispatch, VM opcode, continuation operation, or optimized
native handler only after semantic optimizations are complete.

Elisa's `signal Family.Operation` and `signal Family.Operation(payload, ...)`
syntax lower directly to `Perform`; payload expressions are evaluated once in
source order and become its typed operand slice.
Source `effect Family:` declarations register their first-level operation names
and payload arities in parser metadata. Semantic analysis uses that registry to
reject unknown operations and payload-count mismatches for both `signal` and
value-producing `perform` requests in user-declared families;
builtin and permission-only families keep their host-defined operation sets.
The source reference must contain exactly one non-empty `Family.Operation`
separator. Bare families and multi-dot names are rejected during lowering rather
than being reinterpreted as a synthetic operation, so handler clause lookup and
effect-row coverage cannot silently diverge from the source spelling.
The function effect row may grant the complete operation or its family. Every
perform receives a stable source-derived trace identity.

Value-producing effect requests use the compiler-known
`perform("Family.Operation", payload)` intrinsic in an expected-type position,
for example `return perform("Process.Run", command)`. The lowerer requires a
string-literal `Family.Operation` reference, uses the surrounding destination
type as the resumed result type, and emits a result-bearing `Perform` with the
optional typed payload. The referenced operation is added to the function's
effect row unless an active dynamic handler covers its family; malformed or
untyped uses are lowering diagnostics rather than implicit dynamic values.

## Differential testing

`Perform` and `Observe` require stable, nonzero trace-site ids. These ids are
frontend identities and therefore remain comparable across bytecode, JIT, AOT,
Wasm, reference, and candidate executions even when their machine instruction
layouts differ. Trace labels are descriptive only; identity does not depend on
text or source formatting.

`observe(value)` is a compiler-known, value-consuming intrinsic that lowers to
`Observe` without defining a result. It provides a typed, backend-independent
checkpoint for differential tests without depending on stdout or debug logging.

`assert(condition)` lowers to `Assert` with one boolean operand, a void result,
and the containing function's `AssertionError` error row entry. The reference
interpreter and direct bytecode path both evaluate the operand once, continue on
`true`, and raise the typed assertion failure on `false`; no result sentinel or
implicit truthiness conversion is involved. Because assertion failure is a
recoverable runtime error, verified error guards may transfer to their fallback
block and clear the failure before resuming normal state-machine execution.
Void-producing operations can use the statement form `try operation() else void`
(or another void fallback); the guard and fallback merge without a value parameter.
Terminating recovery also accepts a void operation, for example `try assert(x) else
return`, when the recovery clause ends control flow.

Source `raise Error.Tag` (or `raise Error.Tag(payload, ...)`) lowers to a void
`Raise` instruction whose
`effect_family` and `effect_operation` fields preserve the declared error
identity. The lowerer requires the declared family in the function's `error[...]`
row and rejects unknown family/tag pairs; the verifier repeats the row check for
hand-built IR.
`Raise` is recoverable by the same error guards as built-in failures, while an
uncaught raise is reported as `InterpretError.Raised`. Catch expressions may use an
explicit `Family.Tag` arm; the lowerer records that identity on the guard and the
reference interpreter recovers only a matching explicit raise. Positional fields
must match the declared payload arity and lower to typed `ErrorPayload` instructions
for bindings (wildcards discard the corresponding value). Wildcard and `error`
arms remain catch-all for built-in failures and any raised variant. A raised
constructor may carry zero or more ordered SSA operands; the reference interpreter
snapshots those runtime values in its failure channel while unwinding. Variant
arms may terminate their fallback block after normal return-type checking.

`panic([message])` lowers to a void `Panic` instruction with `Abort.Panic` effect
metadata and zero or one evaluated operand. Unlike `Raise`, `Panic` is not an
error-set variant and is deliberately excluded from error-guard recovery; an
uncaught panic reports `InterpretError.Panic` on both the reference interpreter
and direct bytecode path.

F-strings are parser sugar for the compiler-owned `__fstr` call. Lowering accepts
text, `char`, any integer width, `f32`/`f64`, `bool`, text-backed nominal, array, and
dictionary expressions, converting non-text pieces with the existing
`FormatChar`/`FormatInt`/`FormatFloat`/`FormatBool`/`FormatNominal`/`FormatAggregate`
operations before emitting a left-to-right chain of ordinary `Concat`
instructions; literal chunks remain `Constant` values. `FormatAggregate` uses
an explicit stack to render nested arrays and dictionaries in stable bracketed
form with a 64 MiB output bound. This
keeps interpolation visible in the verified IR and gives the interpreter,
bytecode, JIT, and native backends one ownership and evaluation-order contract.

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

Source callbacks may spell a typed resumption as `return resume("echo", payload)`.
The lowerer requires a compile-time string-literal handler name, a non-void callback
return type, and an exact payload/return type match, then emits `Opcode.Resume`.
Source files may derive operation clauses with `@handler("name", "Family.Operation"[, "Policy"])`
on ordinary callback functions. The source lowerer aggregates callbacks
with the same handler name, preserves host-supplied descriptors, and leaves payload /
resume typing to the callback signature plus the verifier. Host configuration remains
the escape hatch for captures, introduced effects, and explicit `error[...]` rows.

Handler failures are stored in explicit error-set rows on handlers and functions.
They are not represented as `Result` values and are not merged into effect rows.
Installing a handler subtracts its handled families from the effects required at
that program point. Effects introduced by running the handler and its explicit
`error[...]` sets are propagated into the enclosing function's respective rows.
The verifier checks both sides of this contract independently.
Structured lowering emits explicit handler unwinding before `return`, `break`,
and `continue`. Loop exits unwind only handlers installed inside that loop;
handlers surrounding the loop remain active until their own lexical scope ends.
The canonical source boundary exposes this same configuration through
`lower_elisascript_source_with_handlers`/`lower_elisascript_file_with_handlers`
and the matching `execute_elisascript_*_with_handlers` entry points. The default
loader and launcher pass an empty handler table, while hosts that need dynamic
effect interception can provide the verified handler descriptors explicitly.

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
Text and nominal constants pass through the shared literal escape decoder before
runtime materialization. This keeps ordinary and adjacent triple-quoted literals
consistent across the reference interpreter and bytecode backends: standard Elisa
escapes decode, while unknown or malformed escapes remain source bytes. Triple-
quoted payloads can contain newlines; bare triple quotes are still lexed as block
comments.
`TextPartition` has signature `Text × Text -> Array[Text]`. Its two text operands
are the haystack and separator; `Instruction.integer` mode 0 selects the first
separator and mode 1 the last. The result always contains exactly three fields
(before, separator, after), using an empty separator field when no occurrence
exists. Both global and receiver partition spellings lower to this verified
operation.
`RegexSearch` is a separate semantic opcode with the exact signature
`Text × Named(Regex) -> Bool`. The reference interpreter executes it through an
explicit search machine with greedy backtracking; future bytecode, JIT, and native
lowerings therefore share the operation contract without inheriting a host
language's regex behavior. Character ranges and Perl-style shorthand classes have
fixed ASCII definitions rather than platform locale semantics. Zero-width word
boundaries (`\b`/`\B`) detect ASCII word/non-word transitions, and bounded
repetitions (`{m}`, `{m,n}`, `{m,}`) use decimal, non-decreasing limits. Top-level
alternation is split only at unescaped pipes outside character classes, and each
branch runs through the same bounded matcher states. Parenthesized groups are
matched recursively, including nested alternation and quantifiers. Perl-style
named group markers (`(?<name>...)`) are accepted for matching; replacement
captures use their positional `$1` through `$9` references, plus `${name}` and
`$<name>` when a flat group has one unique name.
`RegexReplace` has signature `Text × Named(Regex) × Text -> Text`. It reuses the
same branch matcher to locate non-overlapping spans, copies unmatched and replacement
bytes into fresh storage, expands `$0` to each complete matched span, and advances
after zero-width matches so an empty pattern cannot loop forever. `$1` through `$9`
also expand when the pattern contains a flat sequence of non-quantified capture groups
whose spans can be proven against the complete match (for example,
`([a-z]+)=([0-9]+)`). Nested, quantified, or top-level-alternating capture layouts
remain literal rather than guessing a branch; this conservative fallback keeps
replacement behavior deterministic until recursive regex match values are defined.
The replacement language also accepts AWK/sed's `&` whole-match token, Perl/Python
whole-match spellings `\0` and `\g<0>`, positional `\1` through `\9` and
numeric `\g<1>` through `\g<9>` aliases for `$1` through `$9`, and named
`\g<name>` aliases for `${name}`/`$<name>`. Perl's
`$$` literal-dollar token and `\&` literal-ampersand token remain available; each
token is consumed atomically and unknown forms remain literal. Named references
with unknown or duplicate names are also kept literal rather than selecting an
ambiguous capture.
`RegexSplit` has signature `Text × Named(Regex) -> Array[Text]`. It uses those same
spans as field boundaries, preserves empty fields, and applies an explicit one-byte
advance for zero-width matches. The result is materialized in caller-owned flat
storage, so indexing, iteration, and structural equality remain ordinary verified
array operations.
`RegexFind` has the same operands and returns an `Array[Text]` containing each
non-overlapping matched span. Zero-width matches advance explicitly, matching the
termination rule used by `RegexSplit` and `RegexReplace`.

Compiled `Regex` values also expose `search(text)`, `match(text)`, and
`fullmatch(text)`, plus `findall(text)` (with `find_all(text)` as a spelling
alias). `search` is unanchored, `match` anchors at the beginning while
permitting a suffix, and `fullmatch` requires the entire haystack to be
consumed. These receiver forms lower to the same `RegexSearch` contract; its
`Instruction.integer` mode is 0, 1, or 2 respectively. `findall` lowers to
`RegexFind`; no backend-specific regex state is introduced.

`RegexCapture` has the same `Text × Named(Regex)` operands and returns an
`Array[Text]` for the first match. Element zero is the complete matched span;
subsequent elements are proven positional capture groups. If no match exists the
result is empty. Unsupported capture layouts conservatively return only the full
match, preserving deterministic behavior across the interpreter and bytecode
facade.

`Map` is the closed aggregate counterpart to `Array`. Its `Type` descriptor carries
one exact scalar key type and one recursively represented value type within the
inline descriptor limit; `MakeMap` consumes an even key/value
operand sequence and produces the corresponding map. `Index`, `IndexValid`, `Contains`,
`Length`, and `SetIndex` accept maps with typed key/value contracts. Runtime map payloads are
interleaved key/value pairs in caller-owned flat storage and validate their complete
pair range before access. Missing keys use the existing typed
`IndexOutOfBounds` error rather than a sentinel value. The reference interpreter and
the bytecode facade share this representation. Maps whose key and value types are
direct scalar/nominal representations, supported arrays, or recursively supported
nested maps use the packed path for construction, lookup, membership, equality,
updates, and key extraction. Other aggregates continue through the verified
interpreter oracle when the direct bytecode subset does not support them. `MapKeys`
materializes a stable array of keys in insertion order, allowing the existing loop
state machine to lower `for key in map` without evaluating the map expression more
than once. A two-binding read-only loop, `for key, value in map`, uses that same
key array and emits a typed `Index(map, key)` for the value binding; the map
expression is still evaluated exactly once and mutable map iteration is not
permitted. Map equality is order-insensitive but bijective: each candidate pair is
consumed at most once, including for malformed externally supplied runtime maps.

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
Fallible value recovery is represented by `ErrorGuardPush`/`ErrorGuardPop`
instructions around the guarded expression. A recoverable interpreter failure
transfers to the guard's fallback block, unwinds handlers installed inside the
guard, and clears the private failure before the fallback runs. Normal execution
pops the guard and jumps to the same typed merge block, so `try f() else value`
never uses a result wrapper or an eagerly evaluated fallback. Malformed runtime
values and internal control-flow failures remain fatal and cannot be hidden by a
source-level recovery clause.
Terminating recovery (`try f() else return value`, or the corresponding `break`
and `continue` forms) uses the same guard but gives the fallback its own block;
that block must terminate, while success merges the guarded value into the
surrounding state-machine region.
Expression-position `catch f():` uses the same four-state shape (guarded call,
success arm, fallback arm, typed merge). The backend-neutral subset requires a
binding or wildcard success arm and accepts either a final wildcard/`error`
catch-all or an explicit variant guard; variant fields must match the declared
arity and lower to typed `ErrorPayload` instructions. Both arm expressions must
have the guarded call's exact type. `Raise` itself carries ordered payload
operands, and the interpreter preserves those values while unwinding. A single
error arm may instead use `return` and terminate its fallback block after normal
return-type checking, including an explicit variant arm that binds payloads.
`PathExists` is the first concrete filesystem opcode. Its verified signature is
`Named(Path) -> Bool`, and verification also requires `File.Read` in the containing
function's effect row. Lowering adds that effect automatically. The interpreter
copies the path into a NUL-terminated Elisa-owned buffer before calling the
self-hosted core file-I/O layer, so a length-delimited `sview` is never passed to
libc as though it were a C string.
`IsFile` has the same verified `Named(Path) -> Bool` shape and `File.Read` effect,
but tests the POSIX mode bits and returns `false` for missing or non-regular entries.
The scripting `is_file(path)` alias and `Path.is_file()` method lower to this opcode.
`PathAccess` also verifies as `Named(Path) -> Bool` with `File.Read`; its compiler-
selected mode is one of POSIX `R_OK`, `W_OK`, or `X_OK`, backing the
`is_readable`, `is_writable`, and `is_executable` predicates without exposing a
dynamic mode integer to source programs.
The corresponding `Path.is_readable()`, `Path.is_writable()`, and
`Path.is_executable()` call spellings lower to the same opcode.
`PathGlob` and `PathRGlob` verify as `Named(Path) × Text -> Array[Text]` with
`Directory.Read` and `DirectoryError`. They join the receiver with a runtime
pattern (`PathRGlob` prefixes `**/`) and delegate to the same bounded,
symlink-safe glob walker as `ExpandGlob`, keeping Python `Path.glob` and
`Path.rglob` deterministic across interpreter and bytecode execution.
`PathIterDir` verifies as `Named(Path) -> Array[Text]` with
`Directory.Read` and `DirectoryError`. It performs one unfiltered direct scan,
includes hidden entries, skips only `.` and `..`, sorts by unsigned byte order,
and returns rooted child paths. It is lowered and executed directly by both the
interpreter and packed bytecode backends without a glob-pattern round trip.
`TouchPath` verifies as `Named(Path) -> Bool` with `File.Write` and `FileIoError`
for the legacy one-operand form, or `Named(Path) × Bool -> Bool` when the
optional `exist_ok` control is present. Its interpreter bridge opens-or-creates
without truncation, then refreshes timestamps through POSIX `utimes`; with
`exist_ok=false`, an already-existing entry is reported as `FileIoError`.
Packed bytecode uses the same helper and defaults the omitted control to `true`.
`ChmodPath` verifies as `Named(Path) × Int(unsigned, 64) -> Bool` with `File.Write`
and `FileIoError`; both execution engines call the POSIX `chmod` boundary directly.
`FileSize` verifies as `Named(Path) -> Int(unsigned, 64)` with `File.Read` and
`FileIoError`, returning the `st_size` field from the same POSIX `stat` bridge.
`FileMode` verifies as `Named(Path) -> Int(unsigned, 64)` with `File.Read` and
`FileIoError`, returning the `st_mode` bits from that bridge. It preserves the
file-kind and permission bits so scripts can inspect a mode before or after a
typed `ChmodPath` operation.
`FileMTime`, `FileATime`, and `FileCTime` each verify as `Named(Path) ->
Int(signed, 64)` with `File.Read` and `FileIoError`. They return the POSIX
`st_mtime`, `st_atime`, and inode-change `st_ctime` seconds from the same
length-safe `stat` bridge; Python `getmtime`, `getatime`, and `getctime` aliases
lower to the corresponding distinct opcode.
`IsSymlink` verifies as `Named(Path) -> Bool` with `File.Read`; it uses POSIX
`lstat` mode bits so the predicate observes the link itself rather than its target.
`ReadLink` verifies as `Named(Path) -> Named(Path)` with `File.Read` and
`FileIoError`; it returns the raw link target through POSIX `readlink` without
following the link. The `readlink` and `read_link` builtins and path methods use
this opcode.
`SymlinkPath` verifies as `Named(Path) × Named(Path) -> Bool` with `File.Write`
and `FileIoError`; its operands are target then link, and execution calls POSIX
`symlink` directly. The `symlink`, `create_symlink`, and `Path.symlink_to`
surfaces lower to this opcode.
`RemoveTree` verifies as `Named(Path) -> Bool` with `File.Write` and
`FileIoError`; `CopyTree` verifies as `Named(Path) × Named(Path) -> Bool` with
`File.Read`, `File.Write`, and `FileIoError`. Both execute bounded recursive
walks in the reference helper, use `lstat` to avoid following symlink entries,
and are eligible for direct bytecode dispatch.
`PathJoin`, `PathParent`, `PathName`, `PathExtension`, and `PathStem` are pure typed path-shape operations.
`PathJoin` verifies `Named(Path) × Text -> Named(Path)` and uses the core `Fs.join`
separator/absolute-leaf rules; `PathParent` verifies `Named(Path) -> Named(Path)`;
`PathName`, `PathExtension`, and `PathStem` verify `Named(Path) -> Text`. They do not add filesystem effects and
are eligible for the direct bytecode path. Composition allocates permanent storage
for joined paths, while parent/name preserve safe views into the existing path
payload. The scripting-profile aliases `dirname`, `basename`, `suffix`, and
`stem` lower to these same opcodes and retain source-level shadowing rules. The
`Path` members `parent`, `name`, `suffix`, and `stem`, together with
`joinpath`, `exists`, `is_file`, `is_symlink`, `readlink`, `read_link`, `symlink_to`, and `is_dir` methods, are lowered to the same operations.
`Path.with_name` lowers to one `PathParent` followed by `PathJoin`; `Path.with_suffix`
lowers to `PathParent`, `PathStem`, `Concat`, and `PathJoin`. Both return a nominal
`Path`, take one positional `Text`/`sview` argument, add no effects or errors, and
reuse the existing path operation semantics without a new runtime representation.
`PathIsAbsolute` is likewise pure and verifies `Named(Path) -> Bool`; it checks
only the first byte of the length-delimited path for `/`, adds no effect or error,
and is eligible for direct bytecode execution. The global aliases `is_absolute`
and `isabs`, plus `Path.is_absolute()`, lower to this opcode.
`PathNormalize` is pure and verifies `Named(Path) -> Named(Path)`. It performs
lexical separator, dot, and dot-dot cleanup in the core `Fs.normalize` helper,
without filesystem or working-directory access, and is eligible for direct
bytecode execution. The `path_normalize`, `normalize_path`, and `normpath`
builtins plus `Path.normalize()` lower to this opcode.
`PathAbsolute` verifies `Named(Path) -> Named(Path)` and requires
`Directory.Read` plus `DirectoryError`. It reads the current directory through
the existing directory state machine, joins relative input, and delegates
separator/dot cleanup to `Fs.normalize`; absolute input is normalized without
changing it. The `path_absolute`, `absolute_path`, and `abspath` builtins plus
`Path.absolute()` lower to this direct-bytecode-capable operation.
`PathRelative` verifies `Named(Path) × Named(Path) -> Named(Path)` and performs
the same lexical normalization and component subtraction as `Fs.relative`, with
the target as its first operand and the base as its second. It is pure, does not
consult the filesystem, and is eligible for direct bytecode execution. The
`path_relative`, `relative_path`, and `relpath` builtins plus the scripting
convenience `Path.relative_to()` lower to this operation.
`PathReal` verifies `Named(Path) -> Named(Path)` and requires `File.Read` plus
`FileIoError`; it follows symbolic links through the host filesystem and returns
an owned canonical absolute path. The `path_real`, `realpath`, and `resolve_path`
builtins plus `Path.realpath()`/`Path.resolve()` lower to this operation. It is
eligible for direct bytecode execution and is distinct from the pure lexical
`PathNormalize` operation and the non-following `ReadLink` operation.
`CreateTemporary` verifies `Text -> Named(Path)` with an instruction kind of `0`
(file) or `1` (directory), and requires `File.Write` plus `FileIoError`. The
interpreter calls POSIX `mkstemp`/`mkdtemp` under `/tmp`; `mkstemp`'s descriptor is
closed before returning the permanent generated path. `temp_file`, `mktemp`,
`temp_directory`, `temp_dir`, and `mkdtemp` are lowering aliases, and the
operation remains on the direct bytecode filesystem path.
The shell-size predicate has no dedicated opcode: `is_nonempty`/`file_nonempty`
lower to `FileSize` followed by a typed `Greater` comparison against zero. This
keeps the existing `Named(Path) -> Int(unsigned, 64)` file-size contract while
retaining `File.Read` and `FileIoError` on the enclosing function.
`ReadText` extends that contract to whole-file input with verified signature
`Named(Path) -> Text`. Its function must carry both `File.Read` and `FileIoError`;
lowering supplies both and the verifier rejects either omission. The interpreter
uses Elisa's stdio bindings, checks every open/seek/read/close transition, and
returns one owned length-delimited buffer. It checks the file size against its 64 MiB
input safety ceiling before allocation; oversized files and other I/O failures become
`InterpretError.FileIo` at the reference-interpreter boundary. Empty files return
empty text.
The shell-shaped `cat(path)` spelling lowers to this same typed opcode and retains
the nominal `Path`, effect, and error contract.
`WriteText` has verified signature `Named(Path) × Text -> usize` and requires
`File.Write` plus `FileIoError`. Execution opens in replacement mode, verifies the
complete byte count, checks close status, and returns that count. A partial write
never produces a successful result, and empty text still creates or truncates the
target file deterministically.
`AppendText` has the same verified signature and effect/error requirements, but
opens in append mode so each byte is written after the existing file contents.
It is the typed IR counterpart to shell `>>` and Python append-mode writes.
`ReadBytes` verifies as `Named(Path) -> Array[Int(unsigned, 8)]` and requires
`File.Read` plus `FileIoError`. The interpreter reads exact length-delimited file
bytes, checks the size against its 64 MiB input safety ceiling before allocation,
stores them as flat runtime integer values, and preserves embedded NULs. Empty files
produce an empty array. `WriteBytes` and `AppendBytes` verify as
`Named(Path) × Array[Int(unsigned, 8)] -> Int(unsigned, 64)` and require
`File.Write` plus `FileIoError`; they replace or append respectively and return the
exact byte count. Their direct bytecode path calls the same checked runtime
boundary as the reference interpreter, so binary file round trips remain
backend-parity operations.
The line-oriented helpers `read_lines(path) -> Array[Text]` and
`write_lines(path, lines) -> usize` and `append_lines(path, lines) -> usize` are
deliberately not new opcodes: lowering expands them to `ReadText` + `Split`,
`Join` + `WriteText`, and `Join` + `AppendText`, respectively. This keeps their
effect/error rows and runtime behavior identical to the primitive operations while
making empty lines and final-newline handling explicit.
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
Process waits use nonblocking `waitpid` polling and a 120-second deadline; a child
that exceeds the deadline is killed and reported as `ProcessError` rather than
blocking the host indefinitely.
The explicit `executable(text)` constructor adapts a runtime `Text` value to the
nominal `Executable` type for validated runner configurations. It contributes
`ProcessError` to the enclosing function's error row and rejects empty or
embedded-NUL names at execution time; every process opcode applies the same NUL
check to its executable and argument values before constructing C strings.
The scripting-profile `run_process_with_stdin` facade lowers to a
`CaptureProcessResult` followed by `ProcessResultExitStatus`, preserving the
same typed stdin staging and one-shot child execution while exposing only the
status result.
`run_process_in_directory` lowers equivalently to
`CaptureProcessResultInDirectory` with an empty stdin snapshot followed by
`ProcessResultExitStatus`; the child-only `Path` control therefore has the same
parent-cwd isolation as the explicit capture form.
`run_process_with_environment` lowers to
`CaptureProcessResultWithEnvironment` with an empty stdin snapshot followed by
`ProcessResultExitStatus`, preserving typed child-local environment overrides.
`run_process_in_directory_with_environment` lowers to
`CaptureProcessResultInDirectoryWithEnvironment` with an empty stdin snapshot
followed by `ProcessResultExitStatus`, composing both child-only controls.
`CaptureProcessStdout` has the same operands, effect, and error row, with `Text` as
its result. Its opcode is handled by the interpreter's exhaustive Elisa dispatch
machine. Execution redirects only stdout into an anonymous temporary file, reaps
the child, and returns owned length-delimited bytes. The interpreter checks the
temporary-file size against its 64 MiB per-stream safety ceiling before allocation
and raises `ProcessError` for an oversized capture. It does not reinterpret output
as a C string or capture stderr.
`CaptureProcessStderr` has the same verified signature and redirects descriptor 2
instead; descriptor 1 remains inherited. The shared stream-capture implementation
keeps byte ownership, wait behavior, and shell-free argument handling identical.
`CaptureProcessStdoutWithStdin` verifies as `Named(Executable) × Array[Text] × Text
-> Text` with the same `Process.Run` effect and `ProcessError` row. The interpreter
stages the input in a temporary file, redirects descriptors 0 and 1 in the child,
and drives input writing and process waiting through explicit state machines before
returning the owned stdout snapshot, subject to the 64 MiB per-stream safety ceiling.
`CaptureProcessStderrWithStdin` has the same verified signature and contract, but
redirects descriptor 2 and returns the owned stderr snapshot under the same 64 MiB
ceiling while stdout remains inherited. It shares the same state-machine input staging and shell-free argv
execution path as the stdout variant.
`CaptureProcessResult` is the differential-testing primitive: it has the same typed
 executable, argument-vector, and stdin operands but returns nominal `ProcessCapture`
 data containing the exit status, stdout, and stderr from one child execution. The
 child redirects descriptors 0, 1, and 2 to separate temporary files; the parent
 waits before reading both streams, checking each against the interpreter's 64 MiB
 per-stream safety ceiling before allocation. An oversized capture raises
 `ProcessError`, so a reference process is never allowed to exhaust host memory.
 `process_exit_status`, `process_stdout`, and `process_stderr` are typed accessors
 over that value. The capture and accessor
 opcodes are separately verified and dispatched explicitly by the interpreter.
`CaptureProcessResultInDirectory` extends the same contract with a nominal `Path`
operand. The child calls `chdir` after fork, leaving the parent cwd unchanged; a
failed child directory produces process status `126` while setup failures still
raise `ProcessError`.
`CaptureProcessResultWithEnvironment` extends the capture contract with a typed
`Map[Text, Text]` operand. The child applies each override with `setenv` before
`execvp`; no environment mutation leaks into the parent interpreter.
`CaptureProcessResultInDirectoryWithEnvironment` combines both controls. It consumes
`Executable`, `Array[Text]`, `Text`, `Path`, and `Map[Text, Text]` operands and
produces `Named(ProcessCapture)`. The directory and environment are applied only in
the forked child, preserving the parent process state for deterministic
differential-testing runs.
`CaptureProcessPipeline` consumes `Array[Named(Executable)]`,
`Array[Array[Text]]`, and `Text`, producing the final `ProcessCapture`. The arrays
must be equal and non-empty at runtime; each stage's captured stdout is staged as
the next stage's stdin through the same bounded temporary-file transport as
`CaptureProcessResult`. It is deliberately sequential and shell-free, so argv
boundaries remain typed and pipe backpressure cannot deadlock the interpreter.
`Sleep` takes one signed/unsigned 64-bit integer or `f64` duration operand and
returns `Void`. Its instruction integer is `0` for seconds and `1` for
milliseconds. Verification requires `Time.Sleep` and `TimeError`; the reference
interpreter and direct bytecode path share the same bounded POSIX `usleep`
implementation and reject negative or non-finite durations.
`GetEnvironment`, `SetEnvironment`, and `UnsetEnvironment` operate on `Text`
operands. Reads produce owned `Text` under `Environment.Read`; mutations produce
`Bool` under `Environment.Write`. All three require `EnvironmentError`, reject C
string truncation hazards, and execute through explicit exhaustive opcode arms.
The scripting-profile `get_environment_or(name, fallback)` lowers to the same
`GetEnvironment` operation wrapped by `ErrorGuardPush`/`ErrorGuardPop` and a typed
merge block, so a missing variable follows the fallback edge without evaluating the
fallback on successful reads.
`CreateDirectory`, `CreateDirectories`, `RemoveDirectory`, and `ChangeDirectory` verify as
`Named(Path) -> Bool` with `Directory.Write` and `DirectoryError`.
The legacy `CreateDirectory` form takes one path operand. `Path.mkdir` may use
the extended three-operand form `Named(Path) × Bool × Bool -> Bool`, where the
second operand is `parents` and the third is `exist_ok`, or the four-operand
form `Named(Path) × u64 × Bool × Bool -> Bool`, which adds the permission mode.
All controls remain runtime-typed and preserve the same effect/error row.
`CreateDirectories` recursively creates missing parent components and accepts
already-existing directory components, matching `mkdir -p`/`os.makedirs` while
keeping the same typed contract.
`CurrentDirectory` takes no operands, returns `Named(Path)`, and requires
`Directory.Read` plus the same error. All four have explicit opcode-machine arms;
the cwd result is copied before the POSIX allocation is released.
The shell-shaped source aliases `pwd`, `cd`, `mkdir`, `rmdir`, `rm`, `cp`, and
`mv` lower to these same verified directory and filesystem opcodes; no alias has a
separate runtime or weaker type contract.
`ListDirectory` verifies as `Named(Path) -> Array[Text]` with `Directory.Read` and
`DirectoryError`. The reference interpreter drives `readdir` through an explicit
scan machine, copies each entry before the next transition, removes dot entries,
and sorts owned names before materializing the runtime array. The current low-level
entry layout bridge is isolated and Darwin-specific; other native targets must
supply their platform `dirent` layout without changing this IR contract.
`IsDirectory` verifies as `Named(Path) -> Bool` with `Directory.Read` and
`DirectoryError`. It has its own exhaustive dispatch arm and uses the same isolated
directory bridge that recursive glob traversal builds upon. The `is_dir` scripting
alias and `Path.is_dir()` method lower to this opcode without changing its effects
or error contract.
`ExpandGlob` verifies as `Named(Glob) -> Array[Text]` with `Directory.Read` and
`DirectoryError`. The interpreter performs component matching and recursive `**`
traversal in Elisa, filters symlink recursion, sorts and deduplicates owned matches,
and enforces a depth bound to make malformed/cyclic trees terminate deterministically.
`ReadStdin` verifies as `() -> Text` with `Console.Read` and `ConsoleError`;
`ReadStdinLine` verifies as `() -> Text` with the same effect/error row and consumes
one line at a time, preserving stdin for subsequent reads. Both state machines
enforce the interpreter's 64 MiB stdin safety ceiling before materializing the
owned result. The Python-facing
`input(prompt)` lowering emits an optional `WriteStdout` for the prompt followed by
`ReadStdinLine`; EOF before a line is represented as the recoverable `Console` failure.
`WriteStdout` and `WriteStderr` verify as `Text -> Int(unsigned, 64)` with
`Console.Write` and `ConsoleError`. The reference interpreter drives input until EOF
and drives output through explicit `Data/End/Error` and `Progress/Done/Error` stream
machines, preserving partial-write semantics and owned read results. `print`,
`echo`, `println`, and `eprint` lower their typed scalar arguments to formatting
and `Concat` instructions before one final stream write; optional `sep` and `end`
text controls are evaluated once and use the same typed concatenation path. An
optional `flush: bool` control is type-checked and accepted for Python
compatibility; because the stream backend writes directly with POSIX `write`,
the bytes are already visible and no separate buffering instruction is needed.
The shell-shaped `printf(text)` spelling lowers directly to `WriteStdout` with the
same literal-text, byte-count, effect, and error contract; it does not interpret
format directives.
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
Modules containing only the currently closed scalar, text, regex, homogeneous-array,
and scalar-map subset (boolean, 64-bit integer, or 64-bit float values, text/nominal constants,
including four nested array levels,
array/map construction and key/value extraction, nominal path/glob/regex/URL constructors, typed path composition/decomposition, indexing, length, slicing, membership, concatenation, split,
join, typed integer/float parsing and formatting, regex search/replacement/splitting/extraction, indexed updates, unary/binary operators,
observations, pure direct calls, and typed filesystem/process/time operations) take a
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
other widths, arrays nested deeper than six levels, handlers, and continuations.
Map values may use the inline bounded array/map layers on the packed path; nested
aggregate shapes beyond the descriptor remain reference-interpreter-only.
Error guards are eligible for the direct path: `ErrorGuardPush`/`ErrorGuardPop`
maintain a checked fallback stack, and recoverable typed failures jump to the
verified fallback block without wrapping the value in a result object.
Integer divide/remainder/shift operations validate zero divisors, signed minimum
overflow, and shift counts before entering host arithmetic, preserving the typed
interpreter failures while remaining on the direct path.
The direct path uses the same overflow-safe flat-array range predicates as the
interpreter for array/map indexing, slicing, membership, joining, concatenation,
indexed updates, equality, key extraction, and process argument vectors; malformed external arguments
therefore cannot diverge between engines.
`Expr.IndexN` lowers to the same `Index` opcode repeatedly from left to right,
so multi-dimensional array and map access introduces no new runtime operation or
temporary collection.
An `IndexN` assignment lowers the final replacement to `SetIndex` and then emits
one outward `SetIndex` per parent aggregate before rebinding the mutable root (or
storing a mutable module global).
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
type annotations, integer indexing, the `.count` field, and the Python-compatible
`len(value)` builtin. `len` is a compiler-known alias for the verified `Length`
opcode over arrays, dictionaries, and byte-oriented text, and remains shadowable
by an ordinary source function. `is_empty(value)`/`isempty(value)` and their
receiver methods lower to `Length` plus an exact zero comparison over the same
three families, without introducing general truthiness coercion. The
`is_nonempty`/`nonempty` forms add a typed `Not` over that comparison.
compiler-known `abs(value)` builtin lowers
to a typed comparison, branch, and merge using the existing `Less` and `Negate`
operations, so it preserves single evaluation and exact integer/float types.
The compiler-known `sorted(values)` builtin lowers to the existing `SortArray`
operation and returns its fresh owned array without mutating the source value.
It accepts only arrays whose scalar elements have a deterministic total order.
The compiler-known `reversed(values)` builtin lowers to `ReverseArray` and
returns a fresh owned array with the original element descriptor in reverse
order, without requiring a mutable binding.
The compiler-known `print(value, ...)` convenience formats each supported scalar,
joins arguments with one space, appends a newline, and lowers directly to the
existing `Concat` plus `WriteStdout` operations; `echo` and `println` are
equivalent stdout aliases and `eprint` selects `WriteStderr`. The optional
`flush: bool` control is accepted as a typed compatibility spelling because
POSIX writes are unbuffered at this boundary. No command string or separate
stdout runtime is introduced.
The compiler-known `min(values)`/`max(values)` calls lower to `SortArray` followed
by a checked `Index` at `0` or `-1`, preserving exact scalar element types and
the normal empty-array failure path. Two or more scalar arguments are first
packed into a typed temporary array, so variadic calls share the same operation
and never evaluate an argument more than once.
The Python-shaped `sum(values, start)`/`product(values, start)` calls reuse the
integer-fold state machine with identities `start`/`1` (`sum` defaults to `0`,
`product` defaults to `1`),
while `any(values)`/`all(values)` reuse
the early-exit boolean-fold CFG. All four preserve exact element types and
short-circuit or fold without materializing a second collection. Their iterable
forms also normalize Python `range(stop)`, `range(start, stop)`, and
`range(start, stop, step)` calls to the same counter-driven fold/query CFG.
Empty literals use
their expected array type in bindings, assignments, returns, and call arguments,
so `[]` never introduces an untyped dynamic collection. Arrays may nest six levels
(`darray[darray[darray[darray[darray[darray[T]]]]]]`) using the compatibility fields; a seventh array
layer remains an explicit lowering error until the recursive table is used directly by
source typing. Dictionary values may be scalar or bounded combinations of arrays
and nested maps; shapes whose value needs a deeper descriptor are rejected at the
source boundary. The
`intern_module_types` pass records every type-bearing IR position in the shared
table, and malformed ranges or duplicate rows are verifier errors. Scalar
statement `match` alternatives such as `1 | 2` are expanded into adjacent typed
arms that share the original body and guard. The same expansion applies before
array shape lowering, so `[0, head] | [1, head]` becomes two typed shape-check
arms. Statement `match` also lowers array prefix/rest patterns such as
`[head, ...tail]`: a
typed `Length` shape check branches before `Index` extraction, and a matching
rest binding is a typed `Slice` view of the original array. Prefix bindings and the
rest suffix remain lexically scoped to the arm, while outer mutable bindings use
the same merge parameters as scalar matches. Nested aggregate subpatterns remain
explicitly rejected until the IR gains aggregate-pattern descriptors.
Source annotation lowering interns function signatures into the same structural
identity space early; the final module pass then assigns ids to all inferred
instruction and handler types before verification.
Plain single-binder `for value in array` loops lower to explicit header, body,
latch, and exit blocks. The collection is evaluated once; length and indexing stay
typed IR operations. `continue` targets the incrementing latch, `break` targets the
exit, and mutations of outer bindings travel through typed loop parameters.
Read-only dictionary loops additionally accept `for key, value in map`; the key
binding comes from `MapKeys` and the value binding from a typed map `Index` in the
body block. Arrays and text additionally accept `for index, value in collection`:
the first binding is the loop's typed `usize` cursor and the second is the
ordinary `Index` result (`char` for text), so no pair materialization is needed.
The Elisa-compatible `collection.enumerate()` suffix is sugar for the same
lowering and is only valid with the two bindings. The Python-compatible
`enumerate(collection, start)` accepts one array/text source and an optional
non-negative integer start; literals normalize to `usize`, while dynamic starts
must already be exact `usize`. The form remains shadowable by a source function
and preserves the typed `usize` cursor. The Python-compatible
`mapping.items()` suffix is likewise sugar for the existing map-pair loop: it
snapshots keys once, performs typed value indexes in the body, and never creates
pair objects.
The Python-compatible `zip(left, right)` loop form accepts exactly two positional
array or text sources. Lowering evaluates both once, emits one typed `Length` for
each, selects the smaller `usize` through a three-block merge CFG, and reuses that
limit for the indexed loop. The body emits one typed `Index` per source and binds
the two element values directly; no tuple or pair array is materialized. A source
function named `zip` shadows this loop sugar and is lowered as an ordinary call.
`sorted(values, reverse: flag)` accepts an optional statically typed boolean. A
literal `true` lowers to `SortArray` followed by `ReverseArray`; a runtime flag
branches through a typed merge CFG so only the selected ordering path executes.
`for mutable value in values` additionally requires `values` to be a named mutable
array binding. Python's `range(stop)`, `range(start, stop)`, and
`range(start, stop, step)` loop calls are normalized to the same counter-driven
range CFG, with typed steps and no temporary collection. Literal steps select a
fixed comparison direction; dynamic integer steps use `RangeCondition`, which
selects the sign-aware direction at runtime. A zero dynamic step raises
`RangeStepZero` through the function's error channel. Lowering
records a scoped element-owner relation; every successful
`value <- replacement` or compound update immediately transitions the owner through
`SetIndex`. The updated array is loop-carried state, so writes survive conditional
and match merges, nested loops, `continue`, and `break` without hidden aliasing or
deferred writeback. Temporary collections, immutable owners, and mutable text
iteration are rejected statically.
Text uses the same verified collection operations and loop CFG. In the current
Elisa-compatible `sview` model, `.count` is a byte count and `text[index]` or
`for character in text` yields one 8-bit `char`; negative array/text indices are
normalized from the end before bounds checking, while dictionary indices remain
exact keys. Invalid indices raise the same typed `IndexOutOfBounds` interpreter
error as arrays. This byte contract is explicit rather than silently pretending
to provide Unicode grapheme indexing.
Value recovery with `get collection[index] else fallback` is lowered as a lazy
state-machine branch. `IndexValid` checks array/text bounds or dictionary key
membership without raising for an ordinary miss; the success edge then performs
the ordinary checked `Index`, while the fallback edge evaluates its expression
only when needed. Both edges merge through one typed block parameter, so the
fallback cannot be eagerly evaluated and the semantics remain identical in the
reference interpreter and bytecode facade. Index and fallback types must match
exactly, and malformed runtime storage still raises the usual typed error.
Dynamic destructuring uses `UnpackArray(array, index)` with the required target
arity stored in the instruction integer payload. The verifier checks the array
element result type and requires `IndexOutOfBounds` in the function error row;
the interpreter and direct bytecode path reject any runtime length mismatch
before exposing an element. Lowering emits all unpack operations before applying
target updates, preserving simultaneous assignment semantics.
`collection[low:high]` lowers to the dedicated typed `Slice` operation. Either
bound may be absent: the lower default is zero and the upper default is one
`Length` evaluation of the already-evaluated collection. Slices are half-open,
preserve the exact array or text type, and require `0 <= low <= high <= count`;
violations raise typed `IndexOutOfBounds`. Immutable array slices share their
backing value storage, while text slices are byte views under the `sview` contract.
The compiler-known `split(text, separator)` operation has the exact static type
`Text × Text -> Array[Text]` and lowers to the semantic `Split` opcode. Its optional
third argument is a signed `i64` `maxsplit`, producing a three-operand bounded
split; negative values mean unlimited splitting and zero returns one unsplit field.
It preserves leading, trailing, and consecutive empty fields. An empty separator
splits a nonempty input into one-byte text views, while empty input produces an
empty array; this follows the same explicit byte model as indexing and iteration.
The interpreter stores fields in caller-owned value storage, so split results can be
indexed, compared structurally, iterated, and returned without hidden host
allocations.
The inverse compiler-known `join(fields, separator)` operation has type
`Array[Text] × Text -> Text` and lowers to `Join`. Verification rejects non-text
arrays before execution; the interpreter also validates each runtime element and
constructs one owned output buffer. Empty arrays join to empty text, separators
appear only between fields, and empty fields remain observable.
The compiler-known `starts_with(text, prefix)` and `ends_with(text, suffix)`
predicates have type `Text × Text -> Bool` and lower to dedicated semantic
opcodes. They compare bytes under the same `sview` contract as indexing and
regex helpers; an empty prefix or suffix succeeds, while a boundary longer than
the input fails. Both are pure operations, remain shadowable by a user-defined
function of the same name, and share the packed bytecode text dispatch family.
The compiler-known `contains(collection, needle)` helper and
`collection.contains(needle)` method have type `Array[T] × T -> Bool`,
`Map[K, V] × K -> Bool`, or `Text × (Text | Char) -> Bool`. They normalize to
the same `Contains(needle, collection)` instruction used by the binary `in`
operator, preserving exact element/key typing and single evaluation of both
operands.
The compiler-known `replace(text, old, replacement)` operation has type
`Text × Text × Text -> Text` and lowers to `TextReplace`. It performs left-to-right,
non-overlapping literal replacement without interpreting `old` as a regex. An
empty `old` value follows Python's boundary rule (the replacement is emitted
before, between, and after input bytes); all output is copied into permanent
runtime storage for parity across interpreter and bytecode execution.
The compiler-known `strip(text)` and `trim(text)` aliases have type `Text -> Text`
and lower to `TrimText` with mode 0. The Python-shaped `text.lstrip()` and
`text.rstrip()` methods use the same opcode with modes 1 and 2 respectively.
They remove ASCII whitespace (`space`, tab, line feed,
vertical tab, form feed, and carriage return) only at the two boundaries and
return an `sview` into the existing text storage; interior whitespace is retained.
The compiler-known `lower(text)` and `upper(text)` operations, together with the
`text.lower()` and `text.upper()` method spellings, have type `Text -> Text` and
lower to `LowerText` and `UpperText`. They fold ASCII letters while preserving
all other bytes, and allocate owned output so the result remains valid across
both execution backends.
The compiler-known `split_lines(text)`/`splitlines(text)` aliases and the
`text.splitlines()`/`text.split_lines()` methods have type `Text -> Array[Text]`
and lower to `SplitLines`. LF, CR, and CRLF delimiters are recognized; a trailing
delimiter does not create an extra field, and empty input yields an empty array.
Python-shaped text method aliases lower to these existing typed operations as
well: `startswith`/`starts_with` and `endswith`/`ends_with` lower to
`StartsWith`/`EndsWith`, `replace(old, replacement)` lowers to `TextReplace`,
`strip()`/`trim()`/`lstrip()`/`rstrip()` lower to `TrimText` (modes 0/0/1/2),
and `split(separator)`/`split(separator, maxsplit)`/`split()` lower to `Split`
(modes 0/1). `rsplit()` uses whitespace mode 1, while `rsplit(separator)` and its bounded form use the same `Split`
opcode with mode 2; the runtime scans separators from the right and reverses
the materialized fields back to source order. The method forms require text receivers and exact positional arity;
the bounded method form requires a signed `i64` limit, while zero-argument
`split()` uses ASCII-whitespace runs and produces no empty fields.
The Python-compatible `separator.join(fields)` method lowers to the existing
`Join` opcode with the fields operand first and the text receiver as separator.
The Python-compatible `mapping.keys()` method is also compiler-known: it requires
zero arguments, returns `Array[K]` for `Map[K, V]`, and lowers to the existing
insertion-order `MapKeys` instruction. The set descriptor is rejected at lowering
so set membership remains the only supported key-like operation for sets.
`mapping.values()` has the same zero-argument contract, returns `Array[V]`, and
lowers to `MapValues`; nested value descriptors are retained for verifier and
backend checks, and set descriptors are rejected.
The `text.count(substring)` method has type `Text × Text -> usize` and lowers to
`TextCount`. Matching is byte-oriented and non-overlapping; an empty substring
returns one more than the input length, and both reference and direct bytecode
paths use the same deterministic scan.
The `text.find(substring)` method has type `Text × Text -> Int(signed, 64)` and
lowers to `TextFind`; it returns the first byte offset, zero for an empty needle,
and `-1` for a miss.
The matching `text.rfind(substring)` method lowers to `TextRFind` and returns the
last byte offset, the input length for an empty needle, or `-1` for a miss.
`text.index(substring)` and `text.rindex(substring)` lower to `TextIndex` and
`TextRIndex`. They return the corresponding first/last offset (including empty
needle boundaries) and raise `IndexOutOfBounds` on a miss through the function's
declared error row. Array `.index(element)` lowers to checked `ArrayIndex`, while
`array.find(element)` remains the sentinel-returning `ArrayFind` operation.
The no-argument `text.isdigit()`, `text.isalpha()`, `text.isalnum()`,
`text.isspace()`, `text.islower()`, `text.isupper()`, and `text.isascii()` methods lower to
`TextPredicate` with a compile-time mode and return `Bool`. The interpreter and
direct bytecode backend share the same non-empty ASCII rules: decimal digits,
ASCII letters, their per-byte union, the scripting profile's
space/tab/LF/VT/FF/CR whitespace set, and case predicates that ignore uncased
bytes but require at least one cased byte; `isascii` accepts the empty string.
`text.removeprefix(prefix)` and `text.removesuffix(suffix)` lower to
`TextRemoveBoundary` with mode 0/1 and return `Text`; matching uses the same
byte-oriented boundary predicates and nonmatching/empty boundaries return the
original view.
`ParseInt` has type `Text -> Int(signed, 64)` and requires `ParseError` in the
function error row. Its state-machine parser accepts only an optional sign and
ASCII decimal digits (with underscores only between adjacent digits), checks
signed 64-bit overflow before each accumulation, and
raises `InterpretError.InvalidNumber` for malformed or out-of-range input. The
compiler-known `parse_int` call lowers to this opcode. `FormatInt` has type
`Int(any width/sign) -> Text`; it uses Elisa's permanent string runtime so the
returned view remains valid after the instruction and is eligible for the direct
bytecode path without introducing a shell or host-language conversion. The
explicit `format_int` builtin remains the checked signed-`i64` spelling; broader
integer output is selected by `str`, f-strings, and `print` without changing the
value's static type.
`ParseFloat` has type `Text -> Float(64)` and shares the `ParseError` row. Its
validation machine requires a decimal mantissa and, when present, a complete
exponent before invoking the shared decimal evaluator; malformed input therefore
cannot silently become zero. `FormatFloat` has type `Float(32|64) -> Text` and copies
the core `%g` spelling into permanent storage before returning its view. These
opcodes are classified into the packed text dispatch family. `FormatBool` has
type `Bool -> Text` and emits canonical lowercase `true` or `false`; it is
classified in the same family and is eligible for the direct bytecode path.
`FormatNominal` has type `Path|Glob|Regex|Executable|Url -> Text`; it exposes
the underlying text representation of a text-backed nominal value for the
explicit `str(value)` facade. It is verified separately from `Copy`, so no
other implicit nominal-to-text conversion is introduced, and it is eligible
for the same interpreter and direct bytecode paths.
`FormatChar` has type `Char -> Text`; char constants use the shared text payload
and are copied into the text result without implicit widening elsewhere.
`FormatAggregate` has type `Array[T] | Map[K, V] -> Text`; it emits `[a, b]` or
`{key: value}` using insertion order and the same scalar spellings as the
corresponding `Format*` operations. The Python-compatible `str(value)` facade
selects `FormatChar`, `FormatInt`, `FormatFloat`, `FormatBool`, `FormatNominal`, or
`FormatAggregate` for the corresponding exact type and returns text unchanged
for text values; all integer widths use `FormatInt` without implicit numeric
coercion. Nominal and
aggregate conversion is explicit at this boundary rather than an implicit
coercion elsewhere. Binary ordering (`Less`, `LessEqual`, `Greater`,
`GreaterEqual`) accepts exact numeric types as before and also exact `Text`/`Char`
pairs. Text ordering is unsigned byte-lexicographic and is implemented
identically by the interpreter and direct bytecode helper; mixed families remain
verifier errors.
The `int(value)` and `float(value)` facades reuse `ParseInt`/`ParseFloat` for
text and return exact `i64`/`f64` operands unchanged; `bool(value)` is an exact
boolean identity. Lossy numeric and truthiness conversions are rejected before
emission, and all three names remain shadowable by source functions.
Exact-type `array + array` and `text + text` lower to the semantic `Concat`
operation rather than numeric `Add`. Array concatenation copies both inputs into
fresh value storage. Text concatenation copies both byte views into permanent,
length-aware Elisa runtime storage, so chained results and results involving
empty text do not borrow temporary buffers. Mixed element or collection types are
rejected statically. The same verified `Concat` operation is used internally for
`mapping.update(other)`: it copies the receiver map, replaces duplicate keys in
place, and appends new keys in source insertion order before rebinding the mutable
receiver.
Exact-type scalar arrays also support structural `==` and `!=`. The interpreter
compares lengths first and then elements deterministically from left to right;
empty arrays, slices, concatenated arrays, separate equal allocations, and shared
or copy-on-update storage therefore follow one value-semantic rule. Mixed array
element types remain static errors; nested arrays use the same recursive runtime
comparison within the supported six-level descriptor. The compact structural type
descriptor currently carries six array layers; a seventh layer is reserved for the
next migration step, where source typing will emit recursive table ids directly.
Statement-form `array.push(value)` and the Python-compatible
`array.append(value)` alias, together with `array.extend(values)`, are
ownership-safe SSA updates rather than hidden aliasing mutations. `push` constructs
a typed singleton and `append` has exactly the same contract; `extend` accepts the
receiver's exact array type; all three concatenate
into a fresh array value and rebind the receiver. Python's zero-argument
`array.pop()` and `array.pop(index)` are available in both expression and statement
position: their typed `PopArrayValue` result yields the removed element while
`PopArray` rebinds the receiver to a shortened view. The optional index is an
integer and supports Python's negative-from-the-end normalization. Both
operations reject an empty array or an out-of-range index with `IndexOutOfBounds`,
and no rebinding occurs on failure. Mutation discovery treats these calls as
assignments, so updates inside `if`, `while`, and `for` flow through the same typed
merge, header, latch, and exit parameters as explicit `<-` rebinding. Named
arguments, mismatched index types, and non-array receivers are rejected.
Mutable set bindings also accept Python's `values.discard(element)` spelling;
it lowers to the same typed `DeleteIndex` update as `values.remove(element)`,
but is restricted to set descriptors and remains a no-op when the element is
absent.
The statement-form `array.reverse()` method lowers to `ReverseArray`. It requires
a mutable array binding and zero arguments, emits an owned reversed array value,
and rebinds the receiver through the ordinary SSA state-machine path. The
interpreter and direct bytecode backend both preserve the exact element type and
leave empty arrays empty.
The statement-form `array.insert(index, value)` lowers to `InsertArray`. Its
index may use any integer type; Python-compatible negative and out-of-range
clamping is performed by the runtime, while the inserted value is checked
statically against the array element descriptor. The operation produces an
owned array and participates in the same mutation-name and CFG merge machinery.
The expression-form `array.copy()` lowers to `CopyArray`, preserves the complete
array element descriptor, and copies the flat payload into fresh runtime storage.
It is available for immutable and mutable arrays alike and has no mutation-name
side effect.
The expression-form `mapping.copy()` lowers to `CopyMap`, preserves the complete
key/value descriptor, and copies the interleaved pair payload into fresh runtime
storage. It is available for immutable and mutable maps alike and has no
mutation-name side effect.
The expression-form `array.count(element)` lowers to `ArrayCount`, returns a
`usize`, and compares elements with the same structural equality used by `==`.
The verifier requires an exact array element type and a valid `usize` result.
`array.find(element)` lowers to `ArrayFind` and returns the first matching
zero-based offset as signed `i64`, or `-1` when absent. `array.index(element)`
lowers to checked `ArrayIndex` and raises `IndexOutOfBounds` on a miss; the
verifier preserves the complete element descriptor for structural comparison.
The statement-form `array.sort(reverse: flag)` lowers to `SortArray` and, when
selected, `ReverseArray`. It requires a mutable array whose element type is a
scalar with a deterministic total order (`bool`, integer, float, `char`, or text),
copies the input into owned storage, and performs a stable insertion sort. Text
values compare by unsigned `sview` bytes. A dynamic reverse flag branches through
a typed merge before rebinding the owner; unsupported aggregate element types and
malformed instructions are rejected before execution, while the interpreter and
bytecode backend share the same result and failure behavior.
Dictionary values also expose Python's `mapping.get(key, default)` spelling. It
lowers to the same `IndexValid`-guarded CFG as `get mapping[key] else default`,
so the default expression is lazy and both branches merge one exact value type.
Mutable dictionaries additionally lower `mapping.pop(key)` and
`mapping.pop(key, default)` to the paired `PopMapValue`/`PopMap` operations.
`PopMapValue` returns the exact dictionary value type (or the typed default when
the key is absent), while `PopMap` removes the key into fresh map storage. A
missing key without a default raises `IndexOutOfBounds`; the verifier rejects
set descriptors, mismatched key/default types, and immutable receivers before
execution.
`mapping.setdefault(key, default)` lowers to the paired
`SetDefaultMapValue`/`SetDefaultMap` operations. The value operation returns the
existing value or the typed default, while the map operation rebinds the mutable
dictionary only when insertion is needed. Both operations require an exact map,
key, and default descriptor; set descriptors and mismatched types are rejected
by the verifier.
Lowering retains one mutability fact alongside every lexical binding. Plain locals,
parameters, loop variables, and match binders are immutable; `mutable` local type
markers and mutable parameters opt into SSA rebinding. `<-`, compound assignment,
`push`, `append`, and `extend` all check the same fact and produce the structured
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
ordinary typed boolean `Not` to the merged result. Strided range membership
accepts positive integer constants and typed integer expressions. After the
bounds states succeed, an alignment state tests `(value - start) % stride == 0`
for ascending ranges or `(start - value) % stride == 0` for descending ranges.
A dynamic stride uses `RangeCondition` for sign-aware bound tests and raises the
recoverable `RangeStepZero` error before alignment when it is zero; non-integer
strides remain type errors.
Integer ranges use the same CFG shape. `low..<high` is exclusive ascending,
`low..=high` is inclusive ascending, and `high..>low` is strict descending.
The range-owned stride spelling (`low..<high..step`) accepts a typed integer
expression; the latch adds or subtracts it according to direction, including after
`continue`. Dynamic steps use `RangeCondition` in the header to choose the
exclusive/inclusive/descending comparison mode and reject zero at runtime.
Python `range(stop)`, `range(start, stop)`, and `range(start, stop, step)` loop
forms are normalized to these same counter states; a negative literal step selects
the descending state machine, while a dynamic step selects by sign. No temporary
array or pair object is created.
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
Expression-form scalar `match` uses the same ordered states but requires an
exhaustive arm set and lowers each arm's value expression through a typed
`match-result` merge parameter. Literal, pin, binding, wildcard, guard, and
ordered `|` alternatives are supported; arm bindings remain lexical. Structural
array expression matches are rejected until aggregate result merging is added,
while statement-form structural arrays use the `Length`/`Index`/`Slice` path
described above. Integer literal patterns are parsed in decimal or hexadecimal
form (including a sign), and an explicit `i8`/`u64`/other integer suffix is
accepted only when it matches the scrutinee type. Numeric range arms add a
lower-bound state followed by a strict or inclusive upper-bound state before
entering the value arm.
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

Array, text, integer-range, dictionary, and boolean quantifier comprehensions
use the same state-machine discipline.
The lowerer first probes the projection in a restored lexical scope to infer its
type(s) without retaining speculative instructions, then emits an empty typed
`MakeArray` or `MakeMap` as the loop-carried accumulator. Array/text iterables use
a `Length`/`Less` header that gates a checked `Index`; integer range iterables
instead carry the current typed counter, compare it with the bound in the header,
and add/subtract the typed stride in the latch. Dynamic strides use a
three-operand `RangeCondition` header (current, bound, step) with a mode stored in
`Instruction.integer`; it performs the sign-aware comparison and raises
`RangeStepZero` for zero. Range bounds and stride are lowered once, so ranges
never allocate a temporary collection. An
optional boolean filter branches to the append state or directly to the latch.
Array projections become singleton `MakeArray` values and `Concat` produces the
next accumulator. When an array projection uses two dictionary binders, the
canonical array binder comes from a `MapKeys` snapshot and the value binder is a
checked `Index` lookup before the projection executes. Dictionary projections
lower their key and value separately
and use immutable `SetIndex` copies, retaining duplicate-key replacement
semantics; range-backed dictionary projections use the same counter directly as
the key/value source. A two-binder dictionary iterable snapshots `MapKeys` once,
then performs a checked value lookup for the second binder on each iteration.
The `mapping.items()` spelling normalizes to that same source expression, so it
also snapshots keys once without materializing pair objects.
Array comprehensions may also use the Python-compatible two-binder
`zip(left, right)` iterable. The lowerer emits both source `Length` operations,
selects the shorter `usize` through a merge CFG, and performs one typed `Index`
per source in the body before projecting and concatenating the result.
They also accept the two-binder `enumerate(collection, start)` iterable. Its
header carries a zero-based source cursor for `Length`/`Index`; the body adds
the one-time, exact-`usize` start value only for the public index binder, so
non-zero starts do not alter collection bounds.
Dictionary comprehensions accept the same iterable and use the offset index as
the projected key while retaining the source element as the second binder.
Python's `range(stop)`, `range(start, stop)`, and `range(start, stop, step)`
spellings are accepted in array and dictionary comprehensions as well. They are
normalized to the same typed counter-driven CFG as explicit ranges, without
materializing an intermediate collection.
Header, latch, and exit block parameters carry both the accumulator and iteration
state through the flat edge-argument pool. Consequently the
interpreter, bytecode VM, and future native backends observe identical evaluation
order and allocation behavior. Quantifier headers carry a boolean accumulator
initialized to the identity (`false` for existential `any` / `exists`, `true` for
universal `all` / `forall`); a predicate branch targets the exit block on the
decisive result and otherwise advances to the latch. The initial shared IR
also lowers `each` queries as identity array comprehensions. It deliberately
lowers `count` queries as a `usize` accumulator with a conditional increment,
and `sum` / `product` queries as exact integer accumulators with identities 0 / 1.
Two-binder dictionary folds count entries or fold the value binder, respectively.
These folds and boolean quantifiers accept integer ranges through the same
counter-driven header/latch states, so no range collection is created. Boolean
quantifiers also accept two-binder dictionary iterables by snapshotting `MapKeys`
and looking up each value in the body state. Set literals and single-binder set
comprehensions use the same verified map storage with a canonical boolean marker and
an internal set descriptor marker that preserves source-level method typing.
Mutable set `.add` lowers to a typed `SetIndex` rebind and is duplicate-stable;
`.clear()` lowers to a typed empty `MakeMap` rebind, and `.remove(element)` lowers
to a typed `DeleteIndex` rebind with no-op missing-key behavior. Indexed access
remains outside this initial IR subset. Ordinary mutable dictionaries use the same
`.clear()` and `.remove(key)` operations with their declared key/value types, while
mutable arrays use `.clear()` to emit a typed empty `MakeArray` rebind. Query
forms with more than two binders and non-straight-line query predicates remain
explicitly rejected rather than lowered with guessed semantics.

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
3. Continue extending the reference interpreter through the remaining structural
   and ownership operations. The initial scripting profile already executes
   verified scalar values, arrays/maps, filesystem and process primitives, error
   recovery, dynamic handlers, multi-shot continuations, and `observe` trace sites.
4. Lower the same verified modules to additional native/JIT targets and test each
   engine differentially against the interpreter. The bytecode backend already
   has typed dispatch classes, table preflight, a state-machine program counter,
   and direct guarded-recovery execution; unsupported dynamic effects continue to
   use the reference interpreter until their target lowering is defined.

## End-to-end execution boundary

`execute_elisascript_source` and `execute_elisascript_file` are the canonical
typed launch APIs. They validate the `.elisascript` suffix, parse and semantically
check the source, lower it to verified IR, lower that IR to bytecode, and execute
the bytecode with the supplied entry function, arguments, observation sink,
runtime storage, and step limit. Source failures remain
`ElisascriptSourceError`; runtime failures remain `InterpretError`, so adapters
can distinguish a malformed script from a failed invocation without introducing
a result-shaped sentinel. The bytecode engine selects direct state-machine
dispatch when supported and otherwise preserves interpreter semantics for dynamic
effects and continuations.
The file-backed boundary also rejects embedded NUL bytes before tokenization;
source cannot be silently truncated by the C-string compatibility boundary.
It also rejects source files larger than 4 MiB before allocating the parser arena,
keeping source-size arithmetic and compiler memory use bounded at the host
boundary. Hosts that need to process generated code should split it into several
modules and call the same loader for each file.
Hosts with an explicit in-memory byte span can use
`lower_elisascript_source_bytes` (or its `_with_handlers` variant), which checks
the supplied length for NUL bytes before constructing the terminated parser buffer.
`execute_elisascript_source_bytes` and
`execute_elisascript_program_source_bytes` expose the same length-delimited
guarantee at the execution boundary.

The launcher-facing ABI is `main(arguments: darray[sview]) -> i64`. The program
runner appends each host argument to caller-owned runtime storage, passes one typed
array value to `main`, and returns the signed 64-bit result as the process status.
`validate_elisascript_entrypoint` rejects a missing or differently typed `main`
before lowering to bytecode; source and runtime failures continue to use their
ordinary `error[...]` families.

The reference command-line adapter lives in `src/driver/elisascript.elisa`. Its
only raw host boundary is `main(argc, argv)`: it drops the executable name,
constructs a `darray[sview]` without shell splitting or environment expansion,
and sends that request through `parse_elisascript_cli`. The parser requires a
`.elisascript` source path, rejects embedded NUL bytes, and preserves every
remaining argv element—including spaces and empty strings—as one typed value.
Usage failures return status `2`; allocation, source, and execution failures
return status `1`; a successful script's signed `i64` result is returned
unchanged. The adapter copies the borrowed source view into a NUL-terminated
buffer only at the file-I/O boundary, so the script itself never receives a
raw C string or a command-string escape hatch.
