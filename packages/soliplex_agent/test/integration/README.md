# Integration Tests

## Prerequisites

1. **Running Soliplex backend** on branch `pgsql+m7-room-configs` (or any branch with M7 rooms)
2. **PostgreSQL** database accessible (for thread persistence)
3. Set `SOLIPLEX_BASE_URL` (defaults to `http://localhost:8000`)

## Backend Setup

The M7 room configs live in the backend repo at `example/rooms/<room-id>/room_config.yaml`.
The branch `pgsql+m7-room-configs` (`runyaga/pgsql+m7-room-configs`) has all rooms committed.

**Important:** `example/minimal.yaml` does NOT include all M7 rooms in its `room_paths`.
You must add the missing rooms to `room_paths` or use a custom config.

### Rooms to add to `room_paths` (beyond minimal defaults)

```yaml
room_paths:
  # ... existing rooms ...
  # M7 integration test rooms:
  - "./rooms/echo"         # already in minimal
  - "./rooms/parallel"
  - "./rooms/writer"
  - "./rooms/reviewer"
  - "./rooms/fixer"
  - "./rooms/classifier"
  - "./rooms/planner"
  - "./rooms/judge"
  - "./rooms/advocate"
  - "./rooms/critic"
```

### Start command

```bash
cd /path/to/soliplex   # on pgsql+m7-room-configs branch
.venv/bin/soliplex-cli serve example/minimal.yaml --no-auth-mode
```

## Required Rooms by Test File

### `test/integration/l2_agent_api_integration_test.dart`

| Room | Purpose |
|------|---------|
| `echo` | Basic agent spawn, concurrent runs, cancellation |

### `test/run/m7_room_integration_test.dart`

| Room | Purpose |
|------|---------|
| `echo` | L0/L1 basic run, streaming, cancellation |
| `parallel` | Parallel tool execution |
| `writer` | Multi-agent pipeline (write stage) |
| `reviewer` | Multi-agent pipeline (review stage) |
| `fixer` | Multi-agent pipeline (fix stage) |
| `classifier` | L2+ classification tasks |
| `planner` | L2+ planning tasks |
| `judge` | L2+ evaluation/judgment |
| `advocate` | L2+++ debate (advocate role) |
| `critic` | L2+++ debate (critic role) |

## Running

```bash
# All integration tests
SOLIPLEX_BASE_URL=http://localhost:8000 \
  dart test -t integration

# M7 room tests only
SOLIPLEX_BASE_URL=http://localhost:8000 \
  dart test test/run/m7_room_integration_test.dart -t integration

# L2 agent API tests only
SOLIPLEX_BASE_URL=http://localhost:8000 \
  dart test test/integration/l2_agent_api_integration_test.dart -t integration
```
