# RunOrchestrator Behavioral Contract

## State Machine

```text
         startRun()
IdleState ---------> RunningState
    ^                  |  |   |   |
    |  reset()         |  |   |   | RunFinished + pending client tools
    +------------------+  |   |   +---------> ToolYieldingState
    |                     |   |                  |   |
    |  reset()            |   | RunFinished      |   | submitToolOutputs()
    +---------------------+   | (no pending)     |   +----> RunningState (new run)
    |                     |   +---------> CompletedState
    |                     |
    |                     | RunErrorEvent / stream error
    |                     +---------> FailedState
    |                     |
    |  reset()            | cancelRun()
    +---------------------+-----------> CancelledState
```

## Design Gap Resolutions

| # | Gap | Resolution |
|---|-----|-----------|
| 1 | Internal handle pattern | Single run per orchestrator instance. No RunRegistry in M4. Orchestrator owns resources (subscription, cancel token) directly. |
| 2 | RunFinished + pending tools | If pending client-side tools exist (registered in ToolRegistry), transition to ToolYieldingState. Server-side tools (not in registry) are ignored. `submitToolOutputs()` creates a **new backend run** for the continuation — the backend does not allow re-posting to an existing run ID. |
| 3 | messageStates merge | Host concern, not orchestrator's. Orchestrator passes Conversation through; UI layer merges messageStates. |
| 4 | startRun concurrency guard | Throw StateError if currentState is RunningState. No queuing, no silent ignore. |
| 5 | ThreadHistoryCache dep | Accept optional `ThreadHistory? cachedHistory` param on startRun(). Orchestrator never fetches history itself. |
| 6 | ActiveRunState vs RunState | Agent package defines `RunState` (sealed). App keeps its own `ActiveRunState`. No rename, no shared type. |
| 7 | initialState deep merge | Caller's responsibility. Pass pre-merged AG-UI state via cachedHistory. Orchestrator does not merge. |

## Stream Semantics

- `stateChanges` is a broadcast stream (multiple listeners allowed).
- Every state transition emits exactly once to `stateChanges`.
- `currentState` always equals the most recently emitted state.
- Stream closes only on `dispose()`.

## Concurrency Invariants

- Only one run active at a time (enforced by `_guardNotRunning()`).
- `startRun()` while RunningState or ToolYieldingState throws `StateError`.
- `cancelRun()` while idle is a no-op; handles both RunningState and ToolYieldingState.
- `syncToThread()` blocks on RunningState and ToolYieldingState.
- `reset()` cancels any active run, transitions to IdleState.
- After `dispose()`, all methods throw `StateError`.

## Terminal State Detection

- `RunFinishedEvent` + pending client tools -> ToolYieldingState.
- `RunFinishedEvent` + no pending client tools -> CompletedState.
- `RunErrorEvent` -> FailedState with classified reason.
- Stream error (exception) -> FailedState via error classifier.
- Stream done without terminal event -> FailedState(networkLost).
- `CancellationError` -> CancelledState (not FailedState).
- Tool depth > 10 -> FailedState(toolExecutionFailed).

## Tool Yielding

**Client vs server tools:** Only tool calls registered in the `ToolRegistry`
are considered client-side. Server-side tool calls (visible in the event
stream but not in the registry) are ignored and do not trigger yielding.

**Resume creates a new run:** The backend does not allow re-posting to an
existing run ID (`RunAlreadyStarted` / HTTP 400). Each `submitToolOutputs()`
call creates a new run via `createRun()`, sends the full conversation
(including `ToolCallMessage` with results), and reconnects the SSE stream.

**Depth limit:** Hardcoded to 10. Exceeding it transitions to
`FailedState(toolExecutionFailed)`.

**Tool definition parameters:** The backend requires a `parameters` field
(JSON Schema) on each `Tool` definition. Omitting it causes HTTP 500.
