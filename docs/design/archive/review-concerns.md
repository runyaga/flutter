# Design Review Concerns

Captured from the visioning/design session. These are the primary
concerns to validate across all three design documents before
implementation begins.

## Design Documents Under Review

1. `docs/design/soliplex-agent-package.md` — Package structure, what
   moves, dependency injection, HostCapabilities
2. `docs/design/monty-host-capabilities-integration.md` — Monty bridge
   rewire, platform discrimination, WASM constraints
3. `docs/design/agent-runtime-vision.md` — Scriptable agent runtime,
   use cases, UX boundary, multi-session orchestration

## P0: Three-Concept Layering (Naming & Boundaries)

The design session converged on three distinct concepts that need
clear naming and separation:

```text
HostApi (interface)
  │  Pure Dart calls → Flutter/host implements
  │  GUI rendering: registerDataFrame, registerChart
  │  Native services: location, camera, file picker
  │  Extensibility: invoke(name, args)
  │  Analogy: Pigeon @HostApi()

PlatformConstraints (queryable flags)
  │  Derived from the binding layer
  │  supportsParallelExecution, supportsAsyncMode, maxConcurrentBridges
  │  The runtime queries these to adapt behavior
  │  Sits BETWEEN bindings and runtime

Platform Bindings (the actual FFI/WASM layer)
  │  MontyNative(bindings: NativeIsolateBindingsImpl())
  │  MontyWasm(bindings: WasmBindingsJs())
  │  _MutexGuardedPlatform (web serialization)
  │  Not exposed to soliplex_agent — implementation detail
```

**Review question:** Is this layering correct? Does `PlatformConstraints`
need to be an interface in `soliplex_agent`, or just a value type?
Should it live in `soliplex_agent` or `soliplex_client`?

## P0: Gemini Review Findings (Blocking)

### A. executeTool Contradiction (Doc 2)

Doc 2 says tool dispatch moves to direct `ToolRegistry` injection but
then shows `capabilities.executeTool()` in the Flutter implementation
and rewiring sections. Must pick one.

**Proposed resolution:** Direct `ToolRegistry` injection. Delete all
`executeTool` references. `MontyHostCapabilities` folds into base
`HostApi`.

### B. Multi-Room ToolRegistry Scoping (Doc 3)

`AgentRuntime` takes a single `ToolRegistry` but needs per-room
registries for cross-room agent spawning (UC1, UC3).

**Proposed resolution:** Inject a factory:

```dart
typedef ToolRegistryResolver = Future<ToolRegistry> Function(String roomId);
```

Flutter implements this by reading room tool definitions and merging
with client tools.

### C. WASM Re-Entrancy Deadlock (Doc 3)

If a background agent's tool call requires Python execution (Monty),
and Python is already suspended waiting for `wait_all()`, WASM
deadlocks — single-threaded, non-reentrant.

**Proposed resolution:** Add `supportsReentrantInterpreter` to
`PlatformConstraints`. Runtime guards against this on WASM. Fail
gracefully instead of freezing.

## P1: Gemini Review Findings (Medium)

### D. Thread Garbage Collection

Iterative refinement (UC2) creates many temporary threads. No
`deleteThread` API exists. Backend pollution.

**Proposed resolution:** `ephemeral: true` flag on `AgentSession`.
Runtime auto-deletes on completion unless promoted.

### E. Unbounded Event History Buffer

`AgentSession.eventHistory` buffers all events for UI catch-up.
Memory leak for long-running sessions.

**Proposed resolution:** Don't buffer in runtime. Use
`SoliplexApi.getThreadHistory()` for catch-up, attach to live
`eventStream` for the tail.

## P1: Interface Simplification

### F. Merge queryPlatform + dispatchHostFunction

Both are `(String, Map) → Future<Object?>`. Same shape, same role.
Merge into single `invoke()` method on `HostApi`.

### G. Eliminate MontyHostCapabilities

With tool dispatch moved to direct injection, `MontyHostCapabilities`
is identical to base `HostCapabilities`/`HostApi`. Remove the
inheritance layer.

## P2: Open Design Questions

1. **Thread lifecycle** — auto-create vs reuse, ownership, cleanup
2. **Session visibility** — how Flutter surfaces background sessions
3. **Resource limits** — max concurrent sessions, HTTP connection caps
4. **State serialization** — checkpoint/restore for Python context
5. **Streaming partial results** — observe tokens mid-flight vs
   completion-only
6. **Inter-session communication** — can sessions message each other?

## Documents Need Updates

All three docs need these changes applied before implementation:

- [x] Rename `HostCapabilities` → `HostApi` everywhere
- [x] Rename `PlatformCapabilities` → `PlatformConstraints` everywhere
- [x] Merge `queryPlatform` + `dispatchHostFunction` → `invoke()`
- [x] Remove `MontyHostCapabilities` (fold into `HostApi`)
- [x] Fix Doc 2: delete `executeTool`, show direct `ToolRegistry` injection
- [x] Fix Doc 3: `AgentRuntime` takes `ToolRegistryResolver` not single `ToolRegistry`
- [x] Add WASM deadlock guard to Doc 3 (incl. error propagation path)
- [x] Add ephemeral thread flag to Doc 3
- [x] Remove event history buffering from Doc 3 (subscribe-first-fetch-second)
- [x] Add "LLM generates scripts at runtime" vision to Doc 3 front matter
- [x] Update Doc 1 package structure (remove monty_host_capabilities.dart)
- [x] Update Doc 2 Flutter impl (_FlutterHostApi, not _FlutterMontyHost)
- [x] Update Doc 3 gap analysis → dependency table (stale fat-interface removed)
- [x] Fix stale callback refs (onRunCompleted → sessionChanges stream)
