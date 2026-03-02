# 0012: Agent Package Fixes (#23, #24, #25)

Three open issues in the agent/client packages, ordered by dependency
(#24 is foundational, #25 is a standalone fix, #23 builds on the state stream).

---

## Issue #25 — RunOrchestrator.dispose() throws unhandled async exception

### Problem

When `dispose()` is called, it cancels the `CancelToken` (line 226 of
`run_orchestrator.dart`), which triggers a `CancellationError` on the SSE
stream. The stream's error handler tries to emit a `CancelledState` but
the `StreamController` is already closing. The underlying HTTP client then
throws `ClientException: Connection closed while receiving data` with no
handler to catch it.

### Root cause

`dispose()` cancels the token and closes the controller in the same
synchronous frame. The cancel triggers an async error on the SSE transport
that arrives after the controller is closed.

### Fix

**File:** `packages/soliplex_client/lib/src/application/run_orchestrator.dart`

1. **Set a `_disposing` flag** before cancelling, so `_onStreamError` can
   silently swallow errors during teardown:

   ```dart
   bool _disposing = false;

   Future<void> dispose() async {
     if (_disposed) return;
     _disposing = true;
     _disposed = true;

     _cancelToken?.cancel();
     await _subscription?.cancel();  // await instead of unawaited
     _subscription = null;

     if (!_controller.isClosed) {
       _controller.close();
     }
     _disposing = false;
   }
   ```

2. **Guard `_onStreamError`** (around line 410+) to ignore errors when
   `_disposing` is true:

   ```dart
   void _onStreamError(Object error, StackTrace stack) {
     if (_disposing || _disposed) return;
     // ... existing error handling
   }
   ```

3. **Guard `_addState`** (around line 483) — already checks `_controller.isClosed`,
   but add `_disposing` check too for safety.

### Tests

- Add test: calling `dispose()` during an active run does not throw
- Add test: calling `dispose()` after run completes is a no-op
- Verify existing dispose tests still pass

---

## Issue #24 — AgUiClient baseUrl should include /api/v1 path prefix

### Problem

`RunOrchestrator._buildEndpoint()` (line 340-342) builds relative paths
like `rooms/{roomId}/agui/{threadId}/{runId}`. The `AgUiClient` concatenates
`baseUrl + endpoint`. If callers forget to include `/api/v1` in the baseUrl,
all SSE connections 404.

Currently, `createClientBundle()` in `client_bundle.dart` (line 17) does
the right thing: `baseUrl = '$serverUrl/api/v1'`. But:

- It's implicit and easy to miss when wiring manually
- The integration harness (line 42-45) independently duplicates this
- `soliplex_tui` and `soliplex_cli` may have their own ad-hoc wiring

### Fix

**File:** `packages/soliplex_agent/lib/src/client_bundle.dart`

The wiring is already correct here. The real fix is documentation + a
guard to prevent misconfiguration:

1. **Add a URI assertion** to `createClientBundle()` to fail fast:

   ```dart
   ClientBundle createClientBundle({required String serverUrl, ...}) {
     final baseUrl = '$serverUrl/api/v1';
     assert(
       !serverUrl.endsWith('/api/v1'),
       'serverUrl should be the root URL without /api/v1 suffix',
     );
     // ...
   }
   ```

2. **Audit all call sites** for manual AgUiClient construction:
   - `packages/soliplex_tui/` — check how it wires AgUiClient
   - `packages/soliplex_cli/` — check how it wires AgUiClient
   - `packages/soliplex_agent/test/integration/helpers/integration_harness.dart`
   - Goal: ensure all go through `createClientBundle()` or at minimum
     use the same `$serverUrl/api/v1` pattern

3. **Add doc comment** to `AgUiClientConfig.baseUrl` (in ag_ui package or
   our wrapper) explaining it must include the API prefix.

### Tests

- Add test: `createClientBundle` with a URL that already has `/api/v1` triggers assertion
- Add test: `createClientBundle` produces correct baseUrl

---

## Issue #23 — Expose stateChanges stream on AgentSession

### Problem

`AgentSession` only exposes `Future<AgentResult> get result`. Consumers
that need live token streaming (TUI headless mode, CLI piping) cannot
observe intermediate `RunningState` events with `TextStreaming` data.

### Current architecture

- `RunOrchestrator` has a `Stream<RunState> get stateChanges` (broadcast
  StreamController, line 94-95 of `run_orchestrator.dart`)
- `AgentSession` holds the orchestrator as `_orchestrator` (line 21 of
  `agent_session.dart`) but does not expose its stream
- `AgentSession._onStateChange()` (line 103-119) listens internally to
  drive the session state machine

### Fix

**File:** `packages/soliplex_agent/lib/src/runtime/agent_session.dart`

1. **Add a `stateChanges` getter** that delegates to the orchestrator:

   ```dart
   /// Stream of [RunState] changes from the underlying orchestrator.
   ///
   /// Use this to observe live token streaming, tool calls, and other
   /// intermediate events. The stream completes when the session reaches
   /// a terminal state.
   Stream<RunState> get stateChanges => _orchestrator.stateChanges;
   ```

   This is safe because `_orchestrator.stateChanges` is already a broadcast
   stream — multiple listeners are fine.

2. **Export `RunState` and related types** from the `soliplex_agent` barrel
   file if not already exported, so consumers don't need to import from
   `soliplex_client` directly.

   **File:** `packages/soliplex_agent/lib/soliplex_agent.dart`

   Check if `RunState`, `RunningState`, `StreamingState`, `TextStreaming`
   are already re-exported. If not, add:

   ```dart
   export 'package:soliplex_client/src/application/run_state.dart';
   export 'package:soliplex_client/src/application/streaming_state.dart';
   ```

### Tests

- Add test: `session.stateChanges` emits `RunningState` with
  `TextStreaming` during an active run
- Add test: `session.stateChanges` completes after session result settles
- Add test: multiple listeners on `stateChanges` work (broadcast)

---

## Implementation order

1. **#25 (dispose fix)** — standalone bug fix, no API changes, unblocks
   `soliplex_tui` from needing the `runZonedGuarded` workaround
2. **#24 (baseUrl guard)** — small defensive fix + audit, no behavior change
3. **#23 (stateChanges)** — new API surface, depends on #25 being solid
   (clean dispose is needed for stream lifecycle correctness)

Each can be its own PR/branch.
