# CLI Monty Integration Guide

How to run `soliplex_cli` as a headless Monty-capable client,
executing `execute_python` tool calls through the full Monty FFI
pipeline without Flutter.

For general agent integration patterns, see
[agent-integration-guide.md](agent-integration-guide.md).

## Prerequisites

### 1. Build the native Monty library

```bash
cd /path/to/dart_monty/native
cargo build --release
```

This produces `target/release/libdart_monty_native.dylib` (macOS) or
the equivalent `.so` / `.dll` for your platform.

### 2. Set the library path

```bash
export DART_MONTY_LIB_PATH=/path/to/dart_monty/native/target/release/libdart_monty_native.dylib
```

`NativeBindingsFfi()` requires this environment variable. Without it,
`DynamicLibrary.open()` crashes at startup with no helpful error
message. See [dart_monty#70](https://github.com/runyaga/dart_monty/issues/70).

### 3. Start the backend server

```bash
cd /path/to/soliplex-backend
OLLAMA_BASE_URL=http://your-ollama-host:11434 \
  uv run soliplex-cli serve example/minimal.yaml --no-auth-mode --port 8000
```

The backend room's `prompt.txt` should instruct the LLM to use the
`execute_python` tool rather than outputting code as text.

## Usage

### Single-turn execution

```bash
dart run bin/soliplex_cli.dart \
  --host http://localhost:8000 --room my-room --monty -v \
  --prompt "Create x = 42 and print it"
```

The process sends the prompt, waits for the LLM to call
`execute_python`, executes the Python code through Monty FFI, returns
the result to the LLM, and exits.

### Multi-turn (sequential prompts)

```bash
dart run bin/soliplex_cli.dart \
  --host http://localhost:8000 --room my-room --monty -v \
  --prompt "Create a list of 3 names and print them" \
  --prompt "How many names are in the list?"
```

Multiple `--prompt` flags run sequentially on the same server-side
thread (`ephemeral: false`). The LLM sees the full conversation
history from prior turns.

### WASM constraint simulation

```bash
dart run bin/soliplex_cli.dart \
  --host http://localhost:8000 --room my-room --monty --wasm-mode -v \
  --prompt "Create x = 42 and print it"
```

`--wasm-mode` applies `WebPlatformConstraints` (single bridge, no
reentrant interpreter) while still using native FFI. This validates
constraint enforcement paths without requiring a browser.

### Interactive REPL with Monty

```bash
dart run bin/soliplex_cli.dart \
  --host http://localhost:8000 --room my-room --monty -v
```

Starts an interactive REPL. Type prompts at the `>` prompt. Use
`/room <name>` to switch rooms, `/spawn` for background sessions,
`Ctrl-C` to cancel.

## How It Wires Up

When `--monty` is passed, the CLI registers the Monty FFI platform
and creates a script environment factory:

```dart
MontyPlatform.instance = MontyFfi(bindings: NativeBindingsFfi());

final envFactory = createMontyScriptEnvironmentFactory(
  hostApi: FakeHostApi(),
  bridgeCache: BridgeCache(limit: platform.maxConcurrentBridges),
);

final runtime = AgentRuntime(
  bundle: bundle,
  toolRegistryResolver: resolver,
  platform: platform,
  logger: logger,
  extensionFactory: wrapScriptEnvironmentFactory(envFactory),
);
```

`FakeHostApi` stubs chart and platform calls with auto-incrementing
handles, making the CLI fully headless. `execute_python` tool calls
flow through `DefaultMontyBridge` -> Monty FFI -> real Python
execution.

### Component flow

```text
CLI (--monty, ephemeral:false) -> AG-UI -> Backend -> LLM (Ollama)
                                                        |
                                          tool_call: execute_python
                                                        |
                                    CLI auto-executes via Monty FFI
                                                        |
                                    tool_result -> AG-UI -> LLM continues
```

## Multi-Turn State Behavior

Server-side thread persistence and client-side interpreter state are
independent concerns:

| What | Controlled by | Persists across turns? |
|------|--------------|----------------------|
| Conversation history | `ephemeral: false` | Yes (server-side) |
| Python variables | `DefaultMontyBridge` | No (fresh interpreter per execute) |
| DfRegistry handles | `extensionFactory` | No (fresh environment per spawn) |

Each `spawn()` creates a new `MontyScriptEnvironment` with a fresh
`DfRegistry` and a fresh interpreter context. Python variables and
DataFrame handles from turn 1 do not exist in turn 2.

The LLM can compensate for simple state by re-declaring variables
from conversation history (the server-side thread retains all
messages). This works for simple cases but breaks down for complex
computed state (DataFrames, intermediate results).

### Production fix path

[dart_monty#71](https://github.com/runyaga/dart_monty/issues/71)
(S10) -- wire `MontySession` into `DefaultMontyBridge` for
JSON-serializable Python state persistence between `execute()` calls.
`MontySession` already exists and passes 44/44 tests, but
`DefaultMontyBridge` does not use it yet.

## Troubleshooting

**`DynamicLibrary.open()` crash on startup**
Set `DART_MONTY_LIB_PATH` to the absolute path of the native library.
Build it with `cargo build --release` in `dart_monty/native/`.

**500 error on second prompt in multi-turn**
Known backend issue
([soliplex#670](https://github.com/soliplex/soliplex/issues/670)).
SSE client disconnect poisons the asyncpg connection pool. Workaround:
add `pool_pre_ping=True` to the backend's `create_async_engine()`
call.

**Python NameError on turn 2 referencing turn 1 variables**
Expected behavior -- `DefaultMontyBridge` creates a fresh interpreter
per `execute()`. Python state does not persist between turns. See
[dart_monty#71](https://github.com/runyaga/dart_monty/issues/71).

**LLM outputs code as text instead of calling execute_python**
The room's `prompt.txt` must explicitly instruct the LLM to use the
`execute_python` tool. Small local LLMs (20B) need strong prompting
to prefer tool calls over markdown code blocks.

**`--wasm-mode` fails but native works**
A real WASM-blocking pattern was found. Check if the code triggers
reentrant interpreter calls or exceeds the single-bridge limit.
