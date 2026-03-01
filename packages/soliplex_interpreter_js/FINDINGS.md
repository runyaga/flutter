# Findings: js_interpreter Bridge Spike

## Summary

The BridgeEvent interface is portable to js_interpreter with moderate
adaptation. The core event lifecycle (RunStarted/Finished, ToolCall*,
TextMessage*) maps cleanly. The primary gap is the synchronous execution
model: all events must be buffered and emitted post-execution, eliminating
real-time tool call streaming. Host function dispatch works via
`JSNativeFunction` globals with a JSValue coercion layer. Output capture
requires overriding the built-in `console` object. The interface is viable
for production with the recommended changes below.

## Interface Gaps

| BridgeEvent Contract | Expected Behavior | Actual Behavior | Severity |
|---------------------|-------------------|-----------------|----------|
| `execute() -> Stream<BridgeEvent>` with suspend/resume | Events emitted incrementally as tool calls happen | All events buffered during sync `eval()`, emitted post-execution | **high** |
| Async host function handlers | `HostFunctionHandler` returns `Future<Object?>`, awaited during execution | `eval()` is sync; async handlers forced via Zone microtask hack; truly async I/O handlers cannot work | **blocking** |
| `unregister(name)` | Remove function from registry | `setGlobal(name, JSNull.instance)` possible but untested; recreating interpreter is safer | **low** |
| Execution limits (timeout) | `MontyLimits(timeoutMs, memoryBytes, stackDepth)` | `Future.timeout()` wrapping `eval()` works for timeout only; no memory/stack controls | **medium** |
| Execution limits (memory) | Memory cap on interpreter | No mechanism; interpreter shares host memory | **high** |
| Execution limits (stack depth) | Stack depth cap | No mechanism | **medium** |

## Workarounds Applied

| Gap | Workaround | Complexity | Acceptable for Production? |
|-----|------------|------------|---------------------------|
| No suspend/resume | Buffer all BridgeEvent objects during `eval()`, emit after completion | Low | Yes — consumers must tolerate batched events instead of streaming |
| Async host handlers | `Zone.fork` with `scheduleMicrotask: (_, _, _, f) => f()` forces immediate microtask execution | Medium | No — fragile hack; production should use synchronous handler typedef |
| Output capture | Override built-in `console` via `setGlobal('console', customJSObject)` with `JSNativeFunction` log method | Low | Yes — clean and reliable |
| JSValue type coercion | Delegate to built-in `DartValueConverter.toDartValue()` and `JSValueFactory.fromDart()` | Low | Yes — the package already provides bidirectional conversion |
| No execution limits | `Future.timeout()` wrapping `Future(() => interpreter.eval(code))` | Low | Partial — timeout works, but memory/stack are uncontrolled |
| `setGlobal` double-wrapping | Pass `JSNativeFunction` instances directly instead of Dart closures to avoid `fromDart` re-wrapping | Low | Yes — correct approach for any host function registration |

## Missing Features

1. **Truly async host functions**: The synchronous `eval()` model makes it
   impossible to await async Dart handlers inline. The Zone microtask hack
   only works for `async => value` patterns (no I/O). Production would
   need either:
   - A synchronous handler typedef (`Object? Function(Map<String, Object?>)`)
   - Or js_interpreter's `evalAsync()` with proper Promise integration

2. **Memory and stack depth limits**: No mechanism exists in js_interpreter
   to constrain memory usage or call stack depth. For untrusted code
   execution, this is a security concern. Isolate-based sandboxing would
   be needed.

3. **No incremental event streaming**: The BridgeEvent contract assumes
   events can be emitted as execution progresses (e.g., `ToolCallStart`
   before the handler runs, `ToolCallResult` after). With synchronous
   eval, all events are post-hoc. Consumers relying on real-time events
   for progress UI will see everything at once.

## Recommended Bridge Contract Changes

1. **Add `SyncHostFunctionHandler` typedef**: The current
   `HostFunctionHandler = Future<Object?> Function(Map<String, Object?>)`
   assumes async. For synchronous interpreters, add a sync variant and let
   the bridge interface accept either:

   ```dart
   typedef SyncHostFunctionHandler = Object? Function(Map<String, Object?>);
   ```

2. **Make suspend/resume optional in the contract**: Add a capability flag
   so consumers can adapt their UI accordingly (spinner vs. progress):

   ```dart
   abstract class InterpreterBridge {
     bool get supportsIncrementalEvents; // false for sync interpreters
   }
   ```

3. **Extract BridgeEvent to a shared package**: Both spike packages copy the
   hierarchy. A `soliplex_bridge_events` package would eliminate duplication
   and ensure contract consistency across runtimes.

4. **Add `mapAndValidate(List<Object?>)` overload**: The current
   `mapAndValidate(MontyPending)` couples to Monty's `MontyPending` type.
   The JS spike needed `mapAndValidate(List<Object?> positionalArgs)` for
   positional-only interpreters. Adding this overload makes the schema
   portable.

5. **Define a `ConsoleEvent` contract**: Both Monty and JS spikes define
   `ConsoleEvent` with different shapes (`ExecutionResult` vs `String?`).
   Standardize on the simpler `{String? value, String output}` shape for
   the execution service layer.

## Test Results

**25/25 tests passed** (0 failures, 0 skipped)

| Test Suite | Tests | Status |
|-----------|-------|--------|
| `js_execution_service_test` | 8 | All pass |
| `default_js_bridge_test` | 17 | All pass |

### Test Coverage

- **Execution service**: Simple expression, console.log capture (single
  and multiple), syntax error, runtime error, dispose guard, concurrent
  execution guard, sequential execution, undefined result
- **Bridge**: Lifecycle events (start/finish/error), output capture (single,
  multiple, none), host function dispatch (call + events, positional->named
  mapping, JSON args, error handling, return value usability), registration
  (schemas, unregister, dispose guard), error propagation (reference error,
  type error)

### Notable Findings During Testing

- `setGlobal` with raw Dart closures double-wraps through `fromDart`,
  converting `List<JSValue>` args to primitives. Must use `JSNativeFunction`
  directly for correct JSValue access.
- The built-in `console` object must be overridden via `setGlobal`, not
  shadowed via `eval('var console = ...')`, because the evaluator's built-in
  takes precedence.
- `JSUndefined` and `JSNull` use singleton pattern (`JSUndefined.instance`,
  `JSNull.instance`) — no public constructors.
- js_interpreter v0.0.2 handles closures, object literals, prototype chains,
  and basic error types well enough for spike scenarios. No missing JS
  features were encountered in testing.
