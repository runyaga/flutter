# Milestones: soliplex_scripting

Implementation plan for [SPEC.md](SPEC.md), broken into five ordered milestones.

```text
M1 ──→ M2 ──→ M3 ──→ M4 ──→ M5
```

Each milestone is independently shippable and testable. Later milestones
depend on earlier ones.

---

## M1: BridgeEvent + Interpreter Refactor

**Package:** `soliplex_interpreter_monty`
**Branch:** `refactor/bridge-event-hierarchy`
**Goal:** Remove `ag_ui` from the interpreter. Replace ag-ui event emission
with a protocol-agnostic `BridgeEvent` sealed hierarchy.

### Deliverables

1. **`bridge_event.dart`** — `BridgeEvent` sealed class with 12 subtypes:
   `BridgeRunStarted`, `BridgeRunFinished`, `BridgeRunError`,
   `BridgeStepStarted`, `BridgeStepFinished`, `BridgeToolCallStart`,
   `BridgeToolCallArgs`, `BridgeToolCallEnd`, `BridgeToolCallResult`,
   `BridgeTextStart`, `BridgeTextContent`, `BridgeTextEnd`.

2. **`monty_bridge.dart`** — Update interface:
   - `execute(String code)` returns `Stream<BridgeEvent>` (was `Stream<BaseEvent>`)
   - Remove `toAgUiTools()` method
   - Remove `ag_ui` import

3. **`default_monty_bridge.dart`** — Replace all 12 ag-ui event constructors
   with `BridgeEvent` constructors. Remove `ag_ui` import.

4. **`host_function_schema.dart`** — Remove `toAgUiTool()` method and
   `ag_ui` import.

5. **`python_executor_tool.dart`** — Delete file (migrates to M2).

6. **`pubspec.yaml`** — Remove `ag_ui` dependency.

7. **`soliplex_interpreter_monty.dart`** — Update barrel: remove
   `python_executor_tool.dart` export, add `bridge_event.dart` export.

8. **Tests** — Update `default_monty_bridge_test.dart`,
   `host_function_schema_test.dart`, `python_executor_tool_test.dart`
   (delete), and integration tests to assert on `BridgeEvent` types.

### Acceptance Criteria

- [ ] `ag_ui` does not appear in `pubspec.yaml`
- [ ] `grep -r 'ag_ui' lib/` returns no results
- [ ] `BridgeEvent` sealed hierarchy has 12 subtypes
- [ ] `MontyBridge.execute()` returns `Stream<BridgeEvent>`
- [ ] `HostFunctionSchema` has no `toAgUiTool()` method
- [ ] `PythonExecutorTool` file deleted
- [ ] `dart format .` clean
- [ ] `dart analyze --fatal-infos` clean
- [ ] All tests pass

---

## M2: Package Scaffold + Adapter

**Package:** `soliplex_scripting` (new)
**Branch:** `feat/scripting-scaffold`
**Goal:** Create the wiring package with the ag-ui adapter and the pieces
that migrated from the interpreter.

### Deliverables

1. **Package skeleton:**
   - `pubspec.yaml` (deps: `ag_ui`, `soliplex_agent`, `soliplex_interpreter_monty`, `meta`)
   - `analysis_options.yaml` (include `very_good_analysis`)
   - `soliplex_scripting.dart` barrel export

2. **`python_executor_tool.dart`** — `const pythonExecutorToolDefinition`
   (migrated from interpreter, `Tool` type from ag-ui).

3. **`host_schema_ag_ui.dart`** — `HostSchemaAgUi` extension on
   `HostFunctionSchema` providing `toAgUiTool()` (migrated logic).

4. **`ag_ui_bridge_adapter.dart`** — `adaptToAgUi(Stream<BridgeEvent>)`
   top-level function. Exhaustive `switch` mapping all 12 `BridgeEvent`
   subtypes to ag-ui `BaseEvent` subtypes. Injects `threadId` and `runId`.

5. **Tests:**
   - `ag_ui_bridge_adapter_test.dart` — One test per `BridgeEvent` subtype
     (12 tests) verifying correct `BaseEvent` output.
   - `host_schema_ag_ui_test.dart` — Extension produces correct `Tool` for
     schemas with various param types (required, optional, descriptions).

### Acceptance Criteria

- [ ] `packages/soliplex_scripting/` exists with valid `pubspec.yaml`
- [ ] `dart pub get` resolves all dependencies
- [ ] `pythonExecutorToolDefinition` is a `const Tool` with name `execute_python`
- [ ] `HostSchemaAgUi.toAgUiTool()` matches prior behavior
- [ ] `adaptToAgUi()` handles all 12 `BridgeEvent` types (exhaustive switch)
- [ ] `dart format .` clean
- [ ] `dart analyze --fatal-infos` clean
- [ ] All tests pass

---

## M3: BridgeCache

**Package:** `soliplex_scripting`
**Branch:** `feat/bridge-cache`
**Goal:** Thread-keyed bridge pool with platform-aware concurrency limits
and LRU eviction.

### Deliverables

1. **`bridge_cache.dart`:**
   - Constructor takes `PlatformConstraints` and optional `bridgeFactory`
   - `acquire(ThreadKey key)` — returns cached or creates new `MontyBridge`
   - `release(ThreadKey key)` — marks bridge as idle (available for eviction)
   - `evict(ThreadKey key)` — disposes and removes a specific bridge
   - `disposeAll()` — disposes all bridges
   - Internal `Map<ThreadKey, _CacheEntry>` with last-access timestamp
   - LRU eviction when `platform.maxConcurrentBridges` reached on `acquire()`
   - `StateError` when all bridges are currently executing (WASM safety)

2. **Tests — `bridge_cache_test.dart`:**
   - Acquire creates bridge on first call
   - Acquire returns same bridge for same key
   - Acquire creates different bridges for different keys
   - LRU eviction disposes least-recently-used when at capacity
   - StateError when all bridges executing and new acquire attempted
   - Release makes bridge eligible for eviction
   - Evict disposes specific bridge
   - DisposeAll disposes all bridges
   - Acquire after evict creates fresh bridge

### Acceptance Criteria

- [ ] `BridgeCache` manages `MontyBridge` instances keyed by `ThreadKey`
- [ ] Lazy creation on first `acquire()`
- [ ] LRU eviction respects `maxConcurrentBridges`
- [ ] `StateError` when all bridges executing (WASM guard)
- [ ] `dart format .` clean
- [ ] `dart analyze --fatal-infos` clean
- [ ] All tests pass

---

## M4: HostFunctionWiring + MontyToolExecutor

**Package:** `soliplex_scripting`
**Branch:** `feat/tool-executor`
**Goal:** The core execution path — connect `HostApi` to bridge host
functions and implement the `execute_python` tool executor.

### Deliverables

1. **`host_function_wiring.dart`:**
   - Constructor takes `HostApi`
   - `registerOnto(MontyBridge bridge)` — creates `HostFunctionRegistry`,
     adds categories (`data`, `chart`, `platform`), registers all onto bridge
   - Host function mappings:

     | HostApi Method | Python Function | Category |
     |----------------|-----------------|----------|
     | `registerDataFrame(columns)` | `df_create(columns)` | data |
     | `getDataFrame(handle)` | `df_get(handle)` | data |
     | `registerChart(config)` | `chart_create(config)` | chart |
     | `invoke(name, args)` | `host_invoke(name, args)` | platform |

2. **`monty_tool_executor.dart`:**
   - Constructor takes `BridgeCache` and `HostFunctionWiring`
   - `Future<String> execute(ToolCallInfo toolCall)`:
     1. Extract `code` from `toolCall.arguments['code']`
     2. Derive `ThreadKey` from tool call context
     3. `bridgeCache.acquire(key)` → `MontyBridge`
     4. `hostWiring.registerOnto(bridge)`
     5. `bridge.execute(code)` → `Stream<BridgeEvent>`
     6. `_collectTextResult(events)` → accumulate `BridgeTextContent` deltas,
        return concatenated text or error from `BridgeRunError`
     7. `bridgeCache.release(key)`

3. **Tests:**
   - `host_function_wiring_test.dart` — Registers correct categories,
     handler delegates to `HostApi` methods correctly.
   - `monty_tool_executor_test.dart` — End-to-end with mock bridge: extracts
     code, acquires/releases bridge, collects text result, handles errors.

### Acceptance Criteria

- [ ] `HostFunctionWiring` maps all 4 `HostApi` methods to host functions
- [ ] `MontyToolExecutor.execute()` returns text result from bridge execution
- [ ] Bridge is acquired before and released after execution
- [ ] `BridgeRunError` produces error string result (not exception)
- [ ] `dart format .` clean
- [ ] `dart analyze --fatal-infos` clean
- [ ] All tests pass

---

## M5: ScriptingToolRegistryResolver + Integration

**Package:** `soliplex_scripting`
**Branch:** `feat/scripting-resolver`
**Goal:** Wire `execute_python` into the agent's tool registry system.
Full integration test of the execution path.

### Deliverables

1. **`scripting_tool_registry_resolver.dart`:**
   - Constructor takes inner `ToolRegistryResolver` and `MontyToolExecutor`
   - `Future<ToolRegistry> call(String roomId)`:
     1. `await inner(roomId)` → base `ToolRegistry`
     2. `.register(ClientTool(definition: pythonExecutorToolDefinition, executor: executor.execute))`
     3. Return augmented registry

2. **Integration test — `scripting_integration_test.dart`:**
   - Full path: `ScriptingToolRegistryResolver` → `ToolRegistry` →
     `execute(toolCall)` → `MontyToolExecutor` → mock `MontyBridge` →
     `BridgeEvent` stream → text result
   - Verifies `execute_python` is registered and executable
   - Verifies tool definitions include `execute_python` plus inner tools

3. **Barrel export update** — Ensure `soliplex_scripting.dart` exports all
   public types.

### Acceptance Criteria

- [ ] `ScriptingToolRegistryResolver` wraps inner resolver
- [ ] Returned `ToolRegistry` contains `execute_python` tool
- [ ] Integration test exercises full resolver → executor → bridge path
- [ ] All public types exported from barrel
- [ ] `dart format .` clean
- [ ] `dart analyze --fatal-infos` clean
- [ ] All tests pass

---

## Summary

| Milestone | Package | Key Output | Depends On |
|-----------|---------|------------|------------|
| M1 | `soliplex_interpreter_monty` | `BridgeEvent` hierarchy, ag-ui removed | — |
| M2 | `soliplex_scripting` (new) | Package scaffold, `AgUiBridgeAdapter` | M1 |
| M3 | `soliplex_scripting` | `BridgeCache` with LRU + WASM guard | M2 |
| M4 | `soliplex_scripting` | `HostFunctionWiring`, `MontyToolExecutor` | M3 |
| M5 | `soliplex_scripting` | `ScriptingToolRegistryResolver`, integration | M4 |
