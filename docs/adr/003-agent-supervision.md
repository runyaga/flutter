# ADR-003: Agent Supervision via Host Functions

**Status:** Spike (validating)

**Date:** 2026-03-06

**Branch:** `spike/agent-watch`

## Context

Python scripts running in the Monty sandbox can spawn sub-agents via
`spawn_agent(room, prompt)` and collect results via `get_result(handle)` or
`wait_all(handles)`. However, `get_result` throws on failure and evicts the
handle, making it impossible for scripts to implement supervision patterns
(retry, backoff, quality validation, escalation).

Soliplex's `AgentSession` already has parent-child relationships (`_children`,
`spawnChild()`, cascading cancel/dispose), but this tree structure is invisible
to Python. Scripts need a non-destructive way to observe child outcomes.

### What We Need

1. **Observe without crashing** -- check if a child succeeded, failed, or
   timed out without the script raising an exception.
2. **Retry on failure** -- spawn a replacement if the original failed.
3. **Cancel stuck agents** -- clean up agents that timed out.
4. **Compose patterns** -- parallel fan-out with per-agent error handling.

### Future Constraint: Isolates

Monty is moving to Dart isolates. Host function handlers currently capture
`RuntimeAgentApi` (which holds `Map<int, AgentSession>`) on the main isolate.
When Python runs in a worker isolate, host function dispatch must cross the
isolate boundary.

## Decision

### 1. Add `agent_watch` Host Function

**Decision:** Expose `AgentResult` to Python as a dict via a new `agent_watch`
host function. It calls `watchAgent()` on `AgentApi`, which awaits the session
result without evicting the handle.

**Return format:**

```python
# Success
{"status": "success", "output": "..."}

# Failure
{"status": "failed", "reason": "serverError", "error": "...", "partial_output": "..."}

# Timeout
{"status": "timed_out", "elapsed_seconds": 15}
```

**Rationale:** Same abstraction level as existing host functions (`spawn_agent`,
`get_result`, `wait_all`). Python scripts can pattern-match on `status` to
implement any supervision policy.

### 2. Add `cancel_agent` Host Function (TODO)

**Decision:** Expose the existing `AgentApi.cancelAgent(handle)` as a host
function. Currently `cancelAgent` exists on the interface but has no
corresponding Python-callable function.

**Rationale:** Without `cancel_agent`, a script that watches a stuck agent
cannot clean up the handle. The handle leaks until session disposal.

### 3. Supervision Logic Lives in Python, Not Dart

**Decision:** The retry/backoff/validation policy is authored in Python (either
LLM-generated or injected as a skill), not hardcoded in Dart.

**Rationale:** Different tasks need different supervision strategies. A finance
analysis might retry 3 times with exponential backoff. A real-time query might
fail fast. Hardcoding strategies in Dart limits flexibility and violates SRP.
The host functions are primitives; the policy is composed in Python.

**Future:** When `soliplex_skills` lands, a `MarkdownSkill` can teach the LLM
the supervision API and patterns, auto-injected when agent functions are
registered.

### 4. Handles Are Opaque Integers, Resolved on Main Isolate

**Decision:** Agent handles remain opaque `int` tokens. The worker isolate
never sees `AgentSession`. `RuntimeAgentApi._handles` on the main isolate is
the single source of truth.

**Rationale:** This design survives the isolate transition unchanged. The
worker sends `{handle: 5}` across the isolate boundary; the main isolate
resolves it. No serialization of `AgentSession` needed.

### 5. Isolate Pattern: Proxy/Stub (Decided)

**Decision:** When isolates land, create `ProxyAgentApi implements AgentApi`
that runs on the worker isolate and delegates to the real `RuntimeAgentApi`
via `SendPort`/`ReceivePort` message passing.

**Alternatives considered:**

| Pattern | Description | Tradeoff |
|---------|------------|----------|
| Command Dispatch | Sealed command classes to single ReceivePort | Simple but manual switch per command |
| **Proxy/Stub** | `ProxyAgentApi` hides message passing behind `AgentApi` interface | Clean API, worker code unchanged |
| Actor Model | Each AgentSession gets its own ReceivePort mailbox | Scalable but complex, overkill now |

**Rationale:** The Proxy pattern preserves the existing `AgentApi` contract.
`HostFunctionWiring` takes an `AgentApi` -- it doesn't care whether it's
`RuntimeAgentApi` (same isolate) or `ProxyAgentApi` (cross-isolate). Zero
changes to host function code.

**Known issue:** `AgentApi.getThreadId()` is synchronous. It must become
`Future<String>` before the proxy pattern works. Small breaking change.

## Proxy/Stub Design

When Monty moves to isolates, `ProxyAgentApi` runs on the worker isolate and
delegates to `RuntimeAgentApi` on the main isolate via message passing.

```text
Worker Isolate                          Main Isolate
--------------                          ------------
HostFunctionWiring                      RuntimeAgentApi
  -> ProxyAgentApi                        -> AgentRuntime
       |                                       -> AgentSession(s)
       | SendPort.send({method, args})         |
       |-------------------------------------->|
       |                                       | executes method
       |<--------------------------------------|
       | ReceivePort receives {result}         |
```

### Worker side: `ProxyAgentApi`

```dart
class ProxyAgentApi implements AgentApi {
  ProxyAgentApi(this._mainPort);
  final SendPort _mainPort;

  @override
  Future<int> spawnAgent(String roomId, String prompt, {/*...*/}) =>
      _call('spawnAgent', {'roomId': roomId, 'prompt': prompt});

  @override
  Future<AgentResult> watchAgent(int handle, {Duration? timeout}) =>
      _call('watchAgent', {'handle': handle});

  @override
  Future<bool> cancelAgent(int handle) =>
      _call('cancelAgent', {'handle': handle});

  Future<T> _call<T>(String method, Map<String, Object?> args) {
    final completer = Completer<T>();
    final replyPort = ReceivePort();
    replyPort.listen((message) {
      replyPort.close();
      final msg = message as Map<String, Object?>;
      if (msg.containsKey('error')) {
        completer.completeError(Exception(msg['error']! as String));
      } else {
        completer.complete(msg['result'] as T);
      }
    });
    _mainPort.send({
      'method': method,
      'args': args,
      'replyTo': replyPort.sendPort,
    });
    return completer.future;
  }
}
```

### Main side: Dispatcher

```dart
void handleAgentCommands(ReceivePort port, RuntimeAgentApi api) {
  port.listen((message) async {
    final msg = message as Map<String, Object?>;
    final method = msg['method']! as String;
    final args = msg['args']! as Map<String, Object?>;
    final replyTo = msg['replyTo']! as SendPort;
    try {
      final result = switch (method) {
        'spawnAgent' => await api.spawnAgent(
            args['roomId']! as String, args['prompt']! as String),
        'watchAgent' => await api.watchAgent(args['handle']! as int),
        'cancelAgent' => await api.cancelAgent(args['handle']! as int),
        _ => throw ArgumentError('Unknown method: $method'),
      };
      replyTo.send({'result': result});
    } on Object catch (e) {
      replyTo.send({'error': e.toString()});
    }
  });
}
```

### Key property

`HostFunctionWiring` accepts `AgentApi?`. It doesn't know or care whether it
receives `RuntimeAgentApi` (same isolate) or `ProxyAgentApi` (cross-isolate).
Zero changes to host function handlers.

### Prerequisites

- `getThreadId()` must become `Future<String>` (currently sync)
- `AgentResult` must be sendable across isolates (it's immutable + records, so it is)

## Consequences

### Positive

- Python scripts can implement arbitrary supervision policies
- No new packages, no architectural changes (just 1 new method + 1 host function)
- Handle-based design survives isolate migration unchanged
- Proxy pattern provides clean isolate upgrade path

### Negative

- `agent_watch` without `cancel_agent` is incomplete -- handles leak on timeout
- No built-in supervision skill yet (LLM must generate supervision code)
- `getThreadId` sync-to-async migration is a future breaking change

### What This Enables

- **L2 agency:** Parallel sub-agents with error handling
- **L3 agency:** Reactive observation (watch + retry)
- **L4 agency:** LLM-driven supervision (combine with `ask_llm`)
- **Supervision trees:** Parent monitors children, restarts on failure

## Files Changed

| File | Change |
|------|--------|
| `soliplex_agent/.../agent_api.dart` | +`watchAgent()` method |
| `soliplex_agent/.../runtime_agent_api.dart` | +impl via `session.awaitResult()` |
| `soliplex_agent/.../fake_agent_api.dart` | +configurable `watchResult` |
| `soliplex_scripting/.../host_function_wiring.dart` | +`agent_watch` host function |
| `soliplex_scripting/test/...` | 7 new tests |

## Related

- [LLM + MCP Host Functions Plan](~/dev/soliplex-plans/llm-mcp-host-functions-plan.md)
- [Session Ownership Master Plan](~/dev/soliplex-plans/SESSION-OWNERSHIP-MASTER-PLAN-2026-03-04.md)
- [Distributed Autonomous Mesh Spec](~/dev/soliplex-plans/distributed-autonomous-mesh-spec.md) (L0-L7 agency levels)
- [Event Loop Protocol Plan](~/dev/soliplex-plans/event-loop-protocol-plan-2026-03-06.md)
