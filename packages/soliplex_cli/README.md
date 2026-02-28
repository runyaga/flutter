# soliplex_cli

Interactive CLI for exercising `soliplex_agent` against a live Soliplex backend.

## Quick start

```bash
cd packages/soliplex_cli
dart pub get
dart run bin/soliplex_cli.dart --host http://localhost:8000 --room plain
```

## Options

| Flag | Env var | Default |
|------|---------|---------|
| `--host`, `-H` | `SOLIPLEX_BASE_URL` | `http://localhost:8000` |
| `--room`, `-r` | `SOLIPLEX_ROOM_ID` | `plain` |
| `--help`, `-h` | | |

## Commands

| Command | Description |
|---------|-------------|
| `<text>` | Send prompt to default room, wait for result |
| `/spawn <text>` | Spawn a background session in the default room |
| `/room <roomId> <text>` | Send prompt to a specific room |
| `/sessions` | List active background sessions |
| `/waitall` | Wait for all background sessions to complete |
| `/waitany` | Wait for the first background session to complete |
| `/cancel` | Cancel all active sessions |
| `/rooms` | List available backend rooms |
| `/examples` | Show usage walkthrough |
| `/clear` | Clear terminal |
| `/help` | Show command reference |
| `/quit` | Exit |

## Built-in tools

The CLI registers two demo client-side tools that the agent can call:

| Tool | Params | Returns |
|------|--------|---------|
| `secret_number` | none | `"42"` |
| `echo` | `text` (string) | the `text` value |

## Example session

```text
$ dart run bin/soliplex_cli.dart --host http://localhost:8000 --room plain

soliplex-cli connected to http://localhost:8000 (room: plain)
tools: [secret_number, echo]

Commands:
  ...

> Call the secret_number tool and tell me what it returns
Spawning session...
[abc-123] SUCCESS: The secret number is 42.

> /spawn Tell me a joke
Spawned session joke-456-1234567890 (1 tracked)
> /spawn What is 2+2?
Spawned session math-789-1234567890 (2 tracked)
> /sessions
  joke-456-1234567890  state=AgentSessionState.running  room=plain
  math-789-1234567890  state=AgentSessionState.running  room=plain
> /waitall
Waiting for 2 session(s)...
[joke-456] SUCCESS: Why did the chicken cross the road? ...
[math-789] SUCCESS: 2+2 = 4.

> /room echo-room Just say hi
Sending to room "echo-room"...
[echo-001] SUCCESS: Hi!

> /quit
```

## M7 scenario mapping

Use `/room` to target backend scenario rooms:

```text
> /room echo-room Say hello                  # basic lifecycle
> /room tool-call-room Call secret_number     # single tool call
> /room multi-tool-room Chain the tools       # multi-tool chaining
> /room error-room Trigger an error           # mid-stream error
> /room cancel-room Start a long task         # then /cancel or Ctrl+C
```

For parallel agent scenarios:

```text
> /spawn Tell me a joke
> /spawn What is 2+2?
> /waitall                                    # or /waitany for race
```
