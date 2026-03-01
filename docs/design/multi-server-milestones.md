# Multi-Server Support — Implementation Milestones

> **Source:** `soliplex-flutter/docs/design/multi-server-support.md`
> (branch: `docs/multi-server-spec`)

---

## Phase 1: Multi-Backend

### M1: ServerConnection value object

**Scope:** `packages/soliplex_agent/lib/src/runtime/server_connection.dart`

- [ ] Create `ServerConnection` immutable value object
  - Fields: `serverId`, `api` (SoliplexApi), `agUiClient` (AgUiClient)
  - Equality/hashCode by `serverId` only
  - `@immutable`, `const` constructor
- [ ] Add test file `test/runtime/server_connection_test.dart`
  - Construction, equality, hashCode, toString
- [ ] Export from `lib/soliplex_agent.dart`

**Acceptance:**
- `dart analyze --fatal-infos` clean
- `dart format . --set-exit-if-changed` clean
- All tests pass

---

### M2: ServerRegistry CRUD

**Scope:** `packages/soliplex_agent/lib/src/runtime/server_registry.dart`

- [ ] Create `ServerRegistry` mutable registry class
  - `add()` — throws `StateError` on duplicate
  - `remove()` — returns connection or null
  - `operator []` — nullable lookup
  - `require()` — throws on missing
  - `serverIds`, `connections`, `length`, `isEmpty`
- [ ] Add test file `test/runtime/server_registry_test.dart`
  - Full CRUD test matrix (add, duplicate, remove, require, iterables)
- [ ] Export from `lib/soliplex_agent.dart`

**Acceptance:**
- `dart analyze --fatal-infos` clean
- `dart format . --set-exit-if-changed` clean
- All tests pass

---

### M3: AgentRuntime.fromConnection factory

**Scope:** `packages/soliplex_agent/lib/src/runtime/agent_runtime.dart`

- [ ] Add `AgentRuntime.fromConnection()` named constructor
  - Pure delegation to existing constructor, extracting from `ServerConnection`
- [ ] Add `fromConnection` test group in `test/runtime/agent_runtime_test.dart`
  - Correct serverId propagation
  - Spawned sessions have matching `ThreadKey.serverId`

**Acceptance:**
- Existing tests unchanged and passing
- `dart analyze --fatal-infos` clean
- `dart format . --set-exit-if-changed` clean

---

## Phase 2: Server-Scoped Sessions

### M4: MultiServerRuntime coordinator

**Scope:** `packages/soliplex_agent/lib/src/runtime/multi_server_runtime.dart`

- [ ] Create `MultiServerRuntime` class
  - Lazy `runtimeFor(serverId)` — creates `AgentRuntime` on first access
  - `spawn()` — routes to correct server by serverId
  - `activeSessions` — aggregates across all servers
  - `getSession(ThreadKey)` — routes by serverId
  - `cancelAll()` — cancels all servers
  - `dispose()` — idempotent cleanup
- [ ] Add test file `test/runtime/multi_server_runtime_test.dart`
  - Lazy creation, unknown server throws, routing correctness
  - Cross-server aggregation, waitAll/waitAny, cancelAll
  - Dispose cleanup and idempotency

### M5: MultiServerRuntime cross-server utilities

**Scope:** Same file as M4

- [ ] `waitAll(sessions)` — `Future.wait` across servers
- [ ] `waitAny(sessions)` — `Future.any` across servers
- [ ] Tests for cross-server wait semantics
- [ ] Export from `lib/soliplex_agent.dart`

**Acceptance:**
- Spawn routes to correct server
- Sessions have correct `serverId` in `ThreadKey`
- `waitAll`/`waitAny` work across servers
- Single-server `AgentRuntime` unaffected
- `dart analyze --fatal-infos` clean
- `dart format . --set-exit-if-changed` clean

---

## Phase 3: Federation

### M6: ServerScopedToolRegistryResolver typedef

**Scope:** `packages/soliplex_agent/lib/src/tools/server_scoped_tool_registry_resolver.dart`

- [ ] Create `ServerScopedToolRegistryResolver` typedef
  - `Future<ToolRegistry> Function(String serverId, String roomId)`
- [ ] Export from `lib/soliplex_agent.dart`

**Acceptance:**
- Type compiles and is usable
- `dart analyze --fatal-infos` clean

---

### M7: FederatedToolRegistry merge + routing

**Scope:** `packages/soliplex_agent/lib/src/tools/federated_tool_registry.dart`

- [ ] Create `FederatedToolRegistry` immutable class
  - `factory FederatedToolRegistry.merge(Map<String, ToolRegistry>)`
  - `serverId::toolName` prefixed naming for multi-server
  - Single-server optimization (no prefix)
  - `toToolRegistry()` — returns standard `ToolRegistry` with routing executors
  - `serverIdFor(federatedName)` — reverse lookup
- [ ] Add test file `test/tools/federated_tool_registry_test.dart`
  - Merge two servers, single server, empty map
  - Routing correctness, reverse lookup, duplicate names across servers

**Acceptance:**
- Merge correctly prefixes and routes
- Tool execution dispatches to originating server
- Single-server returns unprefixed
- `dart analyze --fatal-infos` clean
- `dart format . --set-exit-if-changed` clean

---

### M8: FederatedToolRegistryResolver + MultiServerRuntime integration

**Scope:**
- `packages/soliplex_agent/lib/src/tools/federated_tool_registry_resolver.dart`
- `packages/soliplex_agent/lib/src/runtime/multi_server_runtime.dart` (modified)

- [ ] Create `FederatedToolRegistryResolver` class
  - Takes `ServerRegistry`, `ServerScopedToolRegistryResolver`, `Logger`
  - `toToolRegistryResolver()` — queries all servers, merges, graceful skip on failure
- [ ] Modify `MultiServerRuntime` — optional `serverScopedResolver` parameter
  - When provided, uses `FederatedToolRegistryResolver`
  - When null, Phase 2 behavior unchanged
- [ ] Add test file `test/tools/federated_tool_registry_resolver_test.dart`
  - All servers resolved, failing server skipped, single server unprefixed, warning logged
- [ ] Export from `lib/soliplex_agent.dart`

**Acceptance:**
- Federation merges tools from all servers
- Failing servers gracefully skipped
- `MultiServerRuntime` without federation works exactly as Phase 2
- `dart analyze --fatal-infos` clean
- `dart format . --set-exit-if-changed` clean

---

## Milestone Summary

| Milestone | Phase | Deliverable | New Files | Modified Files |
|-----------|-------|-------------|-----------|----------------|
| M1 | 1 | ServerConnection | 2 | 1 (barrel) |
| M2 | 1 | ServerRegistry | 2 | 1 (barrel) |
| M3 | 1 | AgentRuntime.fromConnection | 0 | 2 (runtime + test) |
| M4 | 2 | MultiServerRuntime core | 2 | 1 (barrel) |
| M5 | 2 | Cross-server wait utilities | 0 | 1 (test additions) |
| M6 | 3 | ServerScopedToolRegistryResolver | 1 | 1 (barrel) |
| M7 | 3 | FederatedToolRegistry | 2 | 1 (barrel) |
| M8 | 3 | Resolver + integration | 2 | 2 (barrel + runtime) |

**Total: 11 new files, 4 existing files modified (all additive)**

## Verification (run after each milestone)

```bash
cd packages/soliplex_agent
dart pub get
dart format . --set-exit-if-changed
dart analyze --fatal-infos
dart test
dart test --coverage
```
