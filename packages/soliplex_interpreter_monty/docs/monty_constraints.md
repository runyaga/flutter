# Monty Interpreter Constraints

Baseline specification of what the Monty Python runtime can and cannot do.
Room designers and tool authors should consult this before writing host
functions or LLM system prompts.

## Language Restrictions

| Constraint | Detail |
|-----------|--------|
| No `import` | All capabilities come from registered host functions |
| No `class` | Flat procedural code only — dicts, lists, strings, host function returns |
| No I/O | No file, network, or system calls |
| `async`/`await` | Supported when platform implements `MontyFutureCapable` |

## Supported Control Flow

`if/else`, `for`, `while`, `try/except`, function definitions (`def`),
variable assignment, list/dict comprehensions, f-strings.

## Resource Limits

Two layers of defense protect against runaway scripts:

### Layer 1: Interpreter limits (cooperative)

Enforced inside the Monty interpreter via `MontyLimits`. These are
cooperative — the interpreter checks limits between bytecode
instructions. A tight native/C-extension loop can bypass them.

| Resource | tool | playButton | Field |
|----------|------|------------|-------|
| Timeout | 5 s | 10 s | `MontyLimits.timeoutMs` |
| Memory | 16 MB | 32 MB | `MontyLimits.memoryBytes` |
| Stack depth | 100 | 100 | `MontyLimits.stackDepth` |

Presets live in `MontyLimitsDefaults`:

```dart
// AI tool-call execution (tighter)
MontyLimitsDefaults.tool      // 5s, 16 MB, stack 100

// User-initiated play-button execution (more generous)
MontyLimitsDefaults.playButton // 10s, 32 MB, stack 100
```

`BridgeCache` passes `defaultLimits` to every `DefaultMontyBridge` it
creates. The frontend wires `MontyLimitsDefaults.tool` by default.

### Layer 2: Dart-side timeouts (hard kill)

A non-cooperative safety net wrapping the bridge event stream:

| Component | Default | Configurable via |
|-----------|---------|------------------|
| `MontyToolExecutor` | 30 s | `executionTimeout` constructor param |
| `HostFunctionWiring` agent calls | 30 s | `agentTimeout` constructor param |
| Showcase screen | 60 s | Hardcoded for interactive demos |

When `MontyToolExecutor` times out, it **evicts** (disposes) the
tainted bridge rather than releasing it back to the pool. This
prevents cache poisoning — a bridge whose stream is still producing
events must never be reused.

## Boundary Types

Only JSON-serializable types cross the Python-Dart boundary:

| Python | Dart | Notes |
|--------|------|-------|
| `str` | `String` | |
| `int` | `int` | |
| `float` | `double` | `HostParamType.number` accepts both |
| `bool` | `bool` | |
| `list` | `List<Object?>` | |
| `dict` | `Map<String, Object?>` | |
| `None` | `null` | |

## Execution Model

| Aspect | Behavior |
|--------|----------|
| State | Each `execute()` starts fresh — no persistent state between calls |
| Print capture | `print()` output buffered and flushed as `TextMessage` events at end |
| Error propagation | Python exceptions → `RunErrorEvent` |
| Handler errors | Dart handler exceptions → `resumeWithError()` → Python sees error |
| Unknown functions | Calls to unregistered functions → `resumeWithError()` |
| Concurrency | Single execution at a time per bridge instance |
| Async host functions | Host function futures launched immediately, resolved on `MontyResolveFutures` |

## Future Work

- **S10:** `MontySession` for persistent state across executions
