# Findings: d4rt Bridge Spike

## Summary

The BridgeEvent interface is portable to d4rt with moderate workarounds. The
core contract — register host functions, execute code, emit a stream of events
— maps cleanly onto d4rt's `D4rt()` class. The main friction is d4rt's
synchronous execution model: all tool call events must be buffered and emitted
post-execution rather than streamed in real time. This is acceptable for
non-interactive scripting scenarios but blocks real-time tool call UX. The
`registertopLevelFunction` API (note: lowercase 't') supports both positional
and named arguments, which is *better* than the spec assumed (spec said
"positional only"). Overall, d4rt is a viable interpreter for the bridge
contract with the workarounds documented below.

## Interface Gaps

| BridgeEvent Contract | Expected Behavior | Actual Behavior | Severity |
|---------------------|-------------------|-----------------|----------|
| `execute(code) → Stream<BridgeEvent>` | Suspend/resume loop emits events incrementally | `execute()` is synchronous — returns after all code runs | **high** |
| `register(HostFunction)` — named params | Named params via `HostFunctionSchema.mapAndValidate()` | `NativeFunctionImpl` receives both `List<Object?>` positional AND `Map<String, Object?>` named args | low |
| `unregister(name)` | Remove function from registry | No d4rt API to remove registered functions | medium |
| `schemas` getter | `List<HostFunctionSchema>` maintained by bridge | N/A in d4rt — bridge must track schemas itself | low |
| Output capture | `__console_write__` external function + Zone | `print()` intercepted via `Zone.fork` with custom `ZoneSpecification(print: ...)` | low |
| Execution limits (timeout) | `MontyLimits(timeoutMs, ...)` | `Future.timeout()` wrapping synchronous execution | medium |
| Execution limits (memory/stack) | `MontyLimits(memoryBytes, stackDepth)` | Not available — no d4rt API for memory or stack controls | **high** |
| Error propagation | `MontyException` with type/message/traceback | User-thrown values cross boundary as `BridgedInstance` (see deep-dive below) | **high** |
| Async host functions | Handler returns `Future<Object?>` | d4rt host functions are synchronous — cannot await Futures | **high** |

## Error Propagation Deep-Dive: The BridgedInstance Problem

This section documents the most surprising interface breakage discovered.

### The Spec Assumption

The 0009 spec (line 95) assumed the error gap was simple:

> d4rt: Dart `Exception` or `Error` from interpreter → Map to
> `BridgeRunError(message)`

This turns out to be significantly more complex.

### What Actually Happens

d4rt's exception hierarchy has three layers, and errors cross the host
boundary differently depending on which layer they originate from:

**Layer 1 — d4rt engine errors** (catchable with `on Exception`):

- `RuntimeError implements Exception` — undefined variables, type mismatches,
  accessing null members
- `SourceCodeException implements Exception` — syntax/parse errors
- These are thrown directly by d4rt's engine and ARE catchable with
  `on Exception catch`

**Layer 2 — User-thrown values** (NOT catchable with `on Exception`):

When interpreted code executes `throw Exception('boom')`, d4rt:

1. Evaluates `Exception('boom')` via the bridged `ExceptionCore` constructor
   (`stdlib/core/exceptions.dart:9`), which creates a real Dart
   `Exception('boom')` object
2. Wraps it in `BridgedInstance(exceptionBridgedClass, Exception('boom'))`
   (`interpreter_visitor.dart:3352`)
3. Wraps that in `InternalInterpreterException(BridgedInstance(...))`
   (`interpreter_visitor.dart:8294`)
4. At the `execute()` boundary (`d4rt_base.dart:491-495`), catches
   `InternalInterpreterException` and checks `is RuntimeError` → **false**
   (it's a `BridgedInstance`, not a `RuntimeError`)
5. **Re-throws `BridgedInstance` directly**: `throw e.originalThrownValue!`

The `BridgedInstance` class:

```dart
class BridgedInstance<T extends Object> implements RuntimeValue { ... }
```

`RuntimeValue` is NOT `Exception`, NOT `Error`. It's a d4rt internal
interface. So `on Exception catch` does not catch it.

`BridgedInstance.toString()` delegates to `nativeObject.toString()`, so the
error message LOOKS like `"Exception: boom"` — misleading because the thrown
object is NOT an `Exception`.

**Layer 3 — Uncatchable d4rt internals** (should never escape, but can):

- `ReturnException`, `BreakException`, `ContinueException` — control flow
  exceptions that all `implement Exception`; they should be caught internally
  by d4rt but in edge cases may leak.

### Severity Assessment

This is **high severity** for the bridge contract because:

1. **Silent type mismatch**: `on Exception catch` silently misses user-thrown
   values. The exception escapes as an unhandled error in the isolate zone.
   No `BridgeRunError` is emitted, no `ConsoleError` is emitted — the stream
   just closes without a terminal event.

2. **Affects all user `throw` statements**: Any interpreted code that uses
   `throw` (including `throw Exception(...)`, `throw FormatException(...)`,
   `throw 'error string'`) produces a `BridgedInstance` or raw value at the
   host boundary that won't match `on Exception catch`.

3. **Workaround requires `on Object catch`**: The bridge must use
   `on Object catch (e)` to handle all thrown types. This works but:
   - Loses type information (the `BridgedInstance` wraps the real exception
     but the bridge can't safely unwrap it without importing d4rt internals)
   - The `very_good_analysis` linter flags `on Object catch` with
     `avoid_catches_without_on_clauses` at `info` level — acceptable but
     worth noting

### Recommendation

The d4rt package should unwrap `BridgedInstance` in
`d4rt_base.dart:491-503` before re-throwing, so that
`throw Exception('boom')` in interpreted code yields a real
`Exception('boom')` at the host boundary:

```dart
// Current (broken for user-thrown bridged types):
} on InternalInterpreterException catch (e) {
  if (e.originalThrownValue is RuntimeError) {
    throw e.originalThrownValue as RuntimeError;
  } else {
    throw e.originalThrownValue!; // BridgedInstance escapes
  }
}

// Proposed fix:
} on InternalInterpreterException catch (e) {
  final thrown = e.originalThrownValue;
  if (thrown is RuntimeError) {
    throw thrown;
  } else if (thrown is BridgedInstance) {
    throw thrown.nativeObject; // Unwrap to real Exception
  } else {
    throw thrown!;
  }
}
```

This would be an upstream fix to d4rt. Until then, bridges must use
`on Object catch`.

## Workarounds Applied

| Gap | Workaround | Complexity | Acceptable for Production? |
|-----|------------|------------|---------------------------|
| Synchronous execution / no suspend-resume | Buffer all tool call records during execution, emit BridgeEvent sequence after `execute()` returns | Low | Yes — but no real-time tool call streaming |
| No unregister API | Track functions in a forwarding map in the bridge wrapper; skip removed entries at dispatch time | Low | Yes |
| No schema concept in d4rt | Maintain `List<HostFunctionSchema>` in bridge wrapper | Trivial | Yes |
| Output capture | `Zone.fork` with custom `ZoneSpecification(print: ...)` captures `print()` output reliably | Low | Yes |
| Error propagation — BridgedInstance leak | `on Object catch` instead of `on Exception catch`; extract message via `e.toString()` | Low | Yes — but lossy (no type info, no traceback) |
| Async host functions | Call handler, attach `.then()` for sync-resolved Futures; async handlers that need event loop ticks will not resolve before d4rt returns | Medium | **No** — only `Future.value()` style handlers work |
| Timeout | Wrap synchronous `execute()` in `Future()` + `.timeout()` | Low | Partial — works for d4rt code, but infinite loops in d4rt block the isolate |
| `main()` entry point required | Auto-wrap user code in `main() { ... }` if no `main` function detected | Trivial | Yes |

## Missing Features

Features that block production use (not workaround-able):

1. **No memory limits**: d4rt provides no API to cap memory usage. A
   malicious or buggy script can exhaust the isolate's heap.

2. **No stack depth limits**: d4rt has no stack depth control. Recursive
   scripts will hit the Dart VM's stack limit and crash the isolate.

3. **Async host function support**: The `HostFunctionHandler` typedef returns
   `Future<Object?>`, but d4rt's `NativeFunctionImpl` is synchronous. Handlers
   that need I/O (HTTP, database) cannot be properly awaited. This is
   fundamental to d4rt's architecture and cannot be worked around.

4. **No real-time event streaming**: Because `execute()` is synchronous, all
   bridge events are emitted post-execution. For long-running scripts with
   multiple tool calls, the UI cannot show intermediate progress.

## Recommended Bridge Contract Changes

1. **Add `BridgeEvent` batch mode**: The abstract bridge interface should
   explicitly support two emission modes:
   - **Streaming** (Monty): events emitted incrementally during execution
   - **Batched** (d4rt, js_interpreter): events emitted after execution
   completes

   This could be a `BridgeCapabilities` enum or a `bool get supportsStreaming`
   on the bridge interface.

2. **Make `HostFunctionHandler` sync-optional**: Consider adding a
   `SyncHostFunctionHandler` typedef (`Object? Function(Map<String, Object?>)`)
   for interpreters that cannot await Futures. The bridge adapter can wrap
   sync handlers in `Future.value()` for the streaming case.

3. **Decouple `MontyException` from error events**: `BridgeRunError` currently
   carries only a `String message`. This is sufficient — but the Monty bridge
   should also not require `MontyException` in the shared interface. The
   current design is already portable here.

4. **Rename abstract bridge interface**: The existing `MontyBridge` name is
   Monty-specific. Rename to `InterpreterBridge` or `ScriptBridge` for the
   shared contract. Note: d4rt exports its own `D4rtBridge` annotation, so
   avoid that name in the shared package.

5. **Add `mapAndValidate` overload for positional+named**: The current
   `HostFunctionSchema.mapAndValidate(MontyPending)` is Monty-specific. Add
   a `mapAndValidateArgs(List<Object?> positional, Map<String, Object?> named)`
   overload that works with any interpreter's argument passing convention.

## API Quirks Discovered

### 1. `registertopLevelFunction` — lowercase 't'

The spec (line 49) says `registerTopLevelFunction`. The actual method is
`registertopLevelFunction` (lowercase 't' in 'top'). This is a typo in
d4rt's public API. It takes `NativeFunctionImpl`:

```dart
typedef NativeFunctionImpl = Object? Function(
    InterpreterVisitor visitor,
    List<Object?> arguments,
    Map<String, Object?> namedArguments,
    List<RuntimeType>? typeArguments);
```

Note: the spec assumed "positional args only" but d4rt passes BOTH
positional AND named arguments. This is better than expected.

### 2. `d4rt` exports `D4rtBridge` annotation

The `d4rt` package barrel (`package:d4rt/d4rt.dart`) exports a `D4rtBridge`
class from `bridge_annotations.dart`. This collides with any bridge
interface named `D4rtBridge`. The spike uses `import 'package:d4rt/d4rt.dart'
hide D4rtBridge` to avoid the conflict.

### 3. `main()` entry point is mandatory

`D4rt().execute(source: code)` defaults to calling `main()`. Code without a
`main` function throws. The bridge auto-wraps user code in
`main() { ... }` as a workaround.

### 4. `execute()` return type is `dynamic`

`execute()` returns `dynamic` — the return value of the called function.
This includes `BridgedInstance` wrappers for bridged types, raw primitives
for `int`/`String`/`bool`, and `InterpretedInstance` for interpreted classes.
The bridge ignores the return value (it's not part of the BridgeEvent
contract).

## Test Results

All 18 tests pass:

```text
00:00 +18: All tests passed!
```

| Test File | Tests | Pass | Fail | Notes |
|-----------|-------|------|------|-------|
| `d4rt_execution_service_test.dart` | 7 | 7 | 0 | Basic execute, print capture, errors, auto-wrap, state guards |
| `default_d4rt_bridge_test.dart` | 11 | 11 | 0 | RunStarted/Finished, print→text events, host fn dispatch, multi-call, param validation, register/unregister, error propagation |

**Analysis**: `dart analyze --fatal-infos` passes with 0 issues.
