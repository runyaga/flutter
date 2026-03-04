# soliplex_scripting

Wiring package that bridges `soliplex_interpreter_monty` events to the AG-UI protocol, making the Monty Python sandbox available as an agent tool.

## Quick Start

```bash
cd packages/soliplex_scripting
dart pub get
dart test
dart format . --set-exit-if-changed
dart analyze --fatal-infos
```

## Architecture

### Tool Definition

- `PythonExecutorTool` -- static `toolName` (`execute_python`) and AG-UI `Tool` definition schema
- `ScriptingToolRegistryResolver` -- decorator that wraps an inner `ToolRegistryResolver` and injects the `execute_python` tool

### Execution

- `MontyToolExecutor` -- acquires a bridge from cache, configures host functions, runs Python code, returns aggregated text output; default 30s execution timeout with evict-on-timeout to prevent cache poisoning
- `BridgeCache` -- LRU pool of `MontyBridge` instances keyed by `ThreadKey`; respects concurrency limits; passes `defaultLimits` to bridges it creates

### Event Bridging

- `AgUiBridgeAdapter` -- transforms `Stream<BridgeEvent>` (from the interpreter) into `Stream<BaseEvent>` (AG-UI protocol) for live UI rendering

### Host Wiring

- `HostFunctionWiring` -- registers Dart callback functions (via `HostApi`) onto a `MontyBridge` so Python code can call back into the host
- `HostSchemaAgUi` -- extension on `HostFunctionSchema` that converts interpreter function metadata to AG-UI `Tool` definitions

## Dependencies

- `ag_ui` -- AG-UI protocol types
- `soliplex_agent` -- `ThreadKey`, `ToolRegistryResolver`, `ToolRegistry`
- `soliplex_client` -- `ToolCallInfo`, `ClientTool`
- `soliplex_interpreter_monty` -- `MontyBridge`, `BridgeEvent`, `HostFunctionRegistry`, `MontyLimitsDefaults`
- `dart_monty_platform_interface` -- `MontyLimits` type for bridge resource limits
- `meta` -- annotations

## Defaults

| Parameter | Default | Notes |
|-----------|---------|-------|
| `BridgeCache.defaultLimits` | `MontyLimitsDefaults.tool` (5s, 16 MB) | Interpreter-level limits passed to every bridge |
| `MontyToolExecutor.executionTimeout` | 30 s | Dart-side safety net; evicts bridge on timeout |
| `HostFunctionWiring.agentTimeout` | 30 s | Timeout for `ask_llm`, `get_result`, `wait_all` |

For interactive demos (play button), use `MontyLimitsDefaults.playButton` (10s, 32 MB)
and longer execution/agent timeouts (e.g. 60s).

## Example

```dart
import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:soliplex_scripting/soliplex_scripting.dart';

void main() {
  // 1. Create a bridge cache with concurrency limit and resource limits
  final cache = BridgeCache(
    limit: 4,
    defaultLimits: MontyLimitsDefaults.tool, // 5s, 16 MB
  );

  // 2. Wire host functions with agent timeout
  final wiring = HostFunctionWiring(
    hostApi: myHostApi,
    agentTimeout: const Duration(seconds: 30),
  );

  // 3. Create executor for a thread with execution timeout
  final executor = MontyToolExecutor(
    threadKey: (serverId: 'default', roomId: 'r1', threadId: 't1'),
    bridgeCache: cache,
    hostWiring: wiring,
    executionTimeout: const Duration(seconds: 30),
  );

  // 4. Wrap the base tool resolver to add execute_python
  final resolver = ScriptingToolRegistryResolver(
    inner: baseToolResolver,
    executor: executor,
  );
}
```
