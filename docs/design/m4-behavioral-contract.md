# M4 Behavioral Contract: RunOrchestrator State Machine

## State Machine

```text
         startRun()         RunFinished
IdleState ---------> RunningState ---------> CompletedState
    ^                  |  |   |
    |  reset()         |  |   | RunErrorEvent / stream error
    +------------------+  |   +---------> FailedState
    |                     |
    |  reset()            | cancelRun()
    +---------------------+-----------> CancelledState
```

## Design Gap Resolutions

| # | Gap | Resolution |
|---|-----|-----------|
| 1 | Internal handle pattern | Single run per orchestrator instance. No RunRegistry in M4. Orchestrator owns resources (subscription, cancel token) directly. |
| 2 | RunFinished + pending tools | Always transition to CompletedState. Log warning for any pending tool calls. M5 adds ToolYieldingState for suspend/resume. |
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
- `startRun()` while running throws `StateError`.
- `cancelRun()` while idle is a no-op.
- `reset()` cancels any active run, transitions to IdleState.
- After `dispose()`, all methods throw `StateError`.

## Terminal State Detection

- `RunFinishedEvent` -> CompletedState (normal completion).
- `RunErrorEvent` -> FailedState with classified reason.
- Stream error (exception) -> FailedState via error classifier.
- Stream done without terminal event -> FailedState(networkLost).
- `CancellationError` -> CancelledState (not FailedState).
