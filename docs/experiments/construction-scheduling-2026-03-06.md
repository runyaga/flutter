# Construction Scheduling Experiment: Full Overview

**Date:** 2026-03-06 (Run 4 — with stream fix)
**Models:** gpt-oss:20b and gpt-oss:120b via Ollama on bizon:11435
**Server:** Soliplex on localhost:8000
**Client:** soliplex_cli with ConstructionPlugin (Monty interpreter)

---

## 1. Architecture

The LLM runs server-side. It receives a system prompt + user message and
generates `execute_python` tool calls. The client (soliplex_cli) executes
the Python code in a sandboxed Monty interpreter that has domain-specific
host functions pre-registered. The LLM never sees the Dart implementation —
it only sees function signatures described in its system prompt.

```text
┌──────────────────────┐     ┌──────────────────────┐
│  Server (soliplex)   │     │  Client (soliplex_cli)│
│                      │     │                       │
│  System Prompt ──┐   │ SSE │  Monty Interpreter    │
│  User Message ──►│LLM│────►│  ├─ construction_*()  │
│                  │   │     │  ├─ stream_*()         │
│  gpt-oss:20b     │   │◄────│  ├─ blackboard_*()    │
│  gpt-oss:120b    └───│     │  ├─ log() / print()   │
└──────────────────────┘     └──────────────────────┘
```

---

## 2. Test Data (same for all rooms)

### Jobs (5 total, 2 houses)

| ID | House | Task | Trade | Material | Deps | Outdoor |
|----|-------|------|-------|----------|------|---------|
| H1_FND | H1 | Foundation | concrete_crew | concrete | none | yes |
| H1_FRM | H1 | Framing | framer | lumber | H1_FND | no |
| H1_ROF | H1 | Roofing | roofer | shingles | H1_FRM | yes |
| H2_FND | H2 | Foundation | concrete_crew | concrete | none | yes |
| H2_FRM | H2 | Framing | framer | lumber | H2_FND | no |

### Workers (3)

| Name | Trade | Level |
|------|-------|-------|
| Bob | concrete_crew | master |
| Alice | framer | journeyman |
| Charlie | roofer | journeyman |

### Weather

| Day | Condition |
|-----|-----------|
| 1 | rain |
| 2 | sunny |
| 3 | sunny |
| 4 | sunny |
| 5 | sunny |

### T3 Stream Events (pre-seeded for dispatcher rooms)

Pre-seeded schedule before dispatcher runs:

- Bob → H1_FND day 2, Bob → H2_FND day 3
- Alice → H1_FRM day 3, Alice → H2_FRM day 4
- Charlie → H1_ROF day 4

**crew_updates stream:** `{"type": "crew_noshow", "worker": "Alice", "day": 3}`
**weather_updates stream:** `{"type": "weather_change", "day": 4, "condition": "rain"}`

---

## 3. Dart Library — ConstructionPlugin

The `ConstructionPlugin` (MontyPlugin) registers **20 host functions** onto
the Monty bridge. All state lives in `ConstructionState`. The LLM calls
these functions from Python — it never sees the Dart implementation.

**Source:** `packages/soliplex_scripting/lib/src/experiments/construction_plugin.dart`

### All Registered Functions

| Function | Returns | Description |
|----------|---------|-------------|
| `construction_get_jobs()` | `List<Map>` | All jobs with deps, trade, outdoor flag |
| `construction_get_staff()` | `List<Map>` | All workers with trade and skill level |
| `construction_get_weather(day)` | `String` | "rain" or "sunny" |
| `construction_get_ready_jobs()` | `List<Map>` | Jobs pending AND deps met |
| `construction_find_workers_for_job(job_id, day)` | `List<Map>` | Qualified + available workers |
| `construction_get_job_details(job_id)` | `Map` | Full details with dep statuses |
| `construction_assign(worker, job_id, day)` | `Map` | `{ok: true}` or `{ok: false, error_code, error, context}` |
| `construction_unassign(worker, day)` | `Map` | Remove assignment |
| `construction_complete_job(job_id)` | `Map` | Mark done, unlocks dependents |
| `construction_advance_day(day)` | `List<String>` | Complete all jobs on that day |
| `construction_get_schedule()` | `List<Map>` | Full current schedule |
| `construction_get_day_schedule(day)` | `List<Map>` | Assignments for one day |
| `construction_detect_conflicts()` | `List<String>` | Constraint violations |
| `construction_job_status(job_id)` | `String` | "pending" / "in_progress" / "completed" |
| `construction_deps_met(job_id)` | `bool` | True if all deps completed |
| `construction_is_outdoor(job_id)` | `bool` | True if outdoor work |
| `construction_available_workers(day)` | `List<Map>` | Workers not assigned that day |
| `construction_workers_for_trade(trade)` | `List<Map>` | Workers with that trade |
| `construction_inject_disruption(day, disruption)` | `null` | Simulate a disruption |
| `construction_get_disruptions(day)` | `List<Map>` | Disruptions for that day |

### assign() Error Codes

| Code | Meaning | Context Fields |
|------|---------|----------------|
| `TRADE_MISMATCH` | Worker's trade doesn't match job | `worker_trade`, `required_trade` |
| `DEPS_NOT_MET` | Dependencies not completed | `unmet_deps` |
| `WEATHER_RAIN` | Outdoor job on a rain day | `day`, `weather` |
| `DOUBLE_BOOKING` | Worker already assigned that day | `existing_job` |
| `UNKNOWN_JOB` | Job ID not found | — |
| `UNKNOWN_WORKER` | Worker name not found | — |

---

## 4. Per-Room Details

### 4a. T1 — Prescriptive (follow instructions)

**Goal:** Can the model translate explicit step-by-step instructions into valid Python?

#### System Prompt — 20B

Directive style. 5 functions listed. Copy-paste example.

```text
You solve tasks by writing Python code via the execute_python tool.
All functions are pre-loaded globals. No imports, no classes, no async/await.

You will be given a sequence of assignments. Convert them into code.

## FUNCTIONS YOU NEED

- `construction_assign(worker, job_id, day)` → assign a worker
- `construction_advance_day(day)` → complete jobs on that day
- `construction_detect_conflicts()` → check for errors (empty = good)
- `log(message)` → log what you're doing
- `print(value)` → show output

## EXAMPLE

If told "Assign Bob to H1_FND on day 2, then advance day 2":

    result = construction_assign("Bob", "H1_FND", 2)
    log(f"Assign Bob to H1_FND day 2: {result}")
    completed = construction_advance_day(2)
    log(f"Day 2 completed: {completed}")

## RULES
- ALWAYS call execute_python. NEVER just output code as text.
- Put ALL code in one execute_python call per step.
- Check results with print() so you can see what happened.
```

#### System Prompt — 120B

Rule-based style. 18 functions listed. Sandbox rules. No copy-paste code.

```text
You are a construction scheduling assistant. Follow the instructions given
to you exactly.

Execute the assignment sequence you are given. Call the functions in order.

You MUST think step-by-step. For each step, decide which function to call,
execute it, and use the result to inform your next action.

## CRITICAL SANDBOX RULES (violation = crash)
1. NO IMPORTS. Everything is a pre-registered global function.
2. NO CLASSES. Use dicts, lists, and `def` functions only.
[... 8 rules ...]

## AVAILABLE FUNCTIONS
### Scheduling
- construction_get_jobs(), construction_get_staff(), construction_get_weather(day)
- construction_get_ready_jobs(), construction_find_workers_for_job(job_id, day)
- construction_assign(worker, job_id, day) → ok/error dict with error_code
- construction_unassign(worker, day), construction_complete_job(job_id)
- construction_advance_day(day), construction_get_schedule()
[... 18 functions total ...]

### Utility
- log(message, level="info"), print(value)

## EXECUTION MODEL
- Each execute_python call gets a FRESH scope — no variables persist.
- ALWAYS call execute_python to run code. NEVER output code as text.
```

#### User Message (both)

> Assign Bob to H1_FND on day 2, Alice to H1_FRM on day 3, then Charlie to H1_ROF on day 4. Advance day after each assignment. Verify no conflicts at the end.

---

### 4b. T2 — Scheduler (build optimal schedule)

**Goal:** Can the model autonomously build a multi-day, multi-worker schedule?

#### System Prompt — 20B

Scaffolded. 9 functions listed. Complete copy-paste scheduling loop.

```text
Your job: schedule construction jobs as fast as possible.

## FUNCTIONS YOU NEED
- construction_get_ready_jobs(), construction_find_workers_for_job(job_id, day)
- construction_get_weather(day), construction_assign(worker, job_id, day)
- construction_advance_day(day), construction_detect_conflicts()
- construction_get_schedule(), log(message), print(value)

## HOW TO SCHEDULE (copy and adapt this)

    current_day = 1
    while True:
        ready = construction_get_ready_jobs()
        if len(ready) == 0:
            break
        for job in ready:
            workers = construction_find_workers_for_job(job["id"], current_day)
            if len(workers) > 0:
                result = construction_assign(workers[0]["name"], job["id"], current_day)
                ...
        construction_advance_day(current_day)
        current_day = current_day + 1
    ...
```

#### System Prompt — 120B

Rule-based. 18+ functions listed. Pattern guidance (not copy-paste). Includes delegation functions (ask_llm, spawn_agent).

```text
You are an autonomous construction scheduler. Create an optimal,
conflict-free schedule that finishes as early as possible.

## AVAILABLE FUNCTIONS
### Scheduling
[... 18 scheduling functions ...]

### Delegation
- ask_llm(prompt, room="general"), spawn_agent(room, prompt)
- agent_watch(handle), cancel_agent(handle)

## PATTERN: Autonomous Scheduling Loop
    jobs = construction_get_jobs()
    staff = construction_get_staff()
    log(f"Scheduling {len(jobs)} jobs with {len(staff)} workers")
    current_day = 1
    while True:
        ready = construction_get_ready_jobs()
        if len(ready) == 0: break
        ...
```

#### User Message (both)

> Here are the project details:
>
> - 2 houses (H1, H2), 5 jobs total
> - Day 1 has rain, days 2-5 are sunny
> - 3 workers: Bob (concrete_crew), Alice (framer), Charlie (roofer)
> - Foundation must be done before framing, framing before roofing
> - Foundation is outdoor work, framing is indoor, roofing is outdoor
>
> Build an optimal schedule. All jobs must be completed. Minimize the number of days. Show the final schedule.

---

### 4c. T3 — Dispatcher (react to stream events)

**Goal:** Can the model subscribe to event streams and reactively fix the schedule?

#### System Prompt — 20B

Scaffolded. 10 functions + stream functions. Complete event loop code.

```text
Your job: listen to event streams and fix the schedule when disruptions happen.

## FUNCTIONS YOU NEED
- stream_subscribe(name), stream_select(handles)
- construction_unassign(worker, day), construction_assign(worker, job_id, day)
- construction_find_workers_for_job(job_id, day)
- construction_get_day_schedule(day), construction_is_outdoor(job_id)
- construction_get_schedule(), log(message), print(value)

## HOW TO HANDLE EVENTS (copy and adapt this)

    crew_h = stream_subscribe("crew_updates")
    weather_h = stream_subscribe("weather_updates")
    while True:
        event = stream_select([crew_h, weather_h])
        if event is None: break
        data = event["data"]
        if data["type"] == "crew_noshow":
            # unassign, find replacement...
        elif data["type"] == "weather_change":
            # unassign outdoor jobs on rain day...
    print(construction_get_schedule())
```

#### System Prompt — 120B

Rule-based. 13 scheduling functions + 4 stream functions + utility. Pattern guidance.

```text
You are a disruption dispatcher. Monitor event streams and keep the
schedule valid by reacting to crew no-shows, weather changes, and
material delays.

## AVAILABLE FUNCTIONS
### Scheduling (query + modify)
[... 13 functions ...]

### Event Streams
- stream_subscribe(name), stream_select(handles)
- stream_next(handle), stream_close(handle)

## PATTERN: Reactive Disruption Loop
    crew_h = stream_subscribe("crew_updates")
    weather_h = stream_subscribe("weather_updates")
    handles = [crew_h, weather_h]
    while True:
        event = stream_select(handles)
        if event is None: break
        ...
```

#### User Message (both)

> A schedule has been built. You need to monitor for disruptions.
> Available streams: "crew_updates" and "weather_updates".
>
> Subscribe to both streams and react to whatever events come in.
> For crew no-shows: unassign the worker, find a replacement.
> For weather changes: if rain, move outdoor jobs.
>
> Keep going until all streams are exhausted.

---

### 4d. T4 — Recovery (handle errors, retry)

**Goal:** Can the model handle assign() failures, diagnose error codes, and retry?

#### System Prompt — 20B

Scaffolded. 10 functions. Complete error-handling loop with WEATHER_RAIN and DOUBLE_BOOKING patterns.

```text
Your job: build a schedule. When assign() fails, read the error and fix it.

## FUNCTIONS YOU NEED
- construction_get_ready_jobs(), construction_find_workers_for_job(job_id, day)
- construction_get_weather(day)
- construction_assign(worker, job_id, day) → Success: {ok: True} or Failure: {ok: False, error_code, error}
- construction_advance_day(day), construction_detect_conflicts()
- construction_get_schedule(), blackboard_write(key, value)
- log(message), print(value)

## HOW TO HANDLE ERRORS (copy and adapt this)

    current_day = 1
    errors = []
    while True:
        ready = construction_get_ready_jobs()
        if len(ready) == 0: break
        for job in ready:
            ...
            if result["ok"]: ...
            else:
                if code == "WEATHER_RAIN":
                    # try next sunny day
                elif code == "DOUBLE_BOOKING":
                    # try next day
        construction_advance_day(current_day)
        current_day = current_day + 1
    blackboard_write("errors", errors)
    ...
```

#### System Prompt — 120B

Rule-based. 18 scheduling + 3 blackboard + utility. Full error recovery pattern with all 4 error codes handled.

```text
You are a resilient scheduler. Build a schedule, but expect errors.

## AVAILABLE FUNCTIONS
### Scheduling
[... 18 functions ...]

### Shared Memory (for tracking errors and reflecting)
- blackboard_write(key, value), blackboard_read(key), blackboard_keys()

## PATTERN: Error Recovery Loop
    ...
    if code == "TRADE_MISMATCH":
        needed = ctx["required_trade"]
        right_workers = construction_workers_for_trade(needed)
        ...
    elif code == "DEPS_NOT_MET":
        log(f"Skipping {job['id']} — deps not met yet")
    elif code == "WEATHER_RAIN":
        for try_day in range(current_day + 1, current_day + 10):
            if construction_get_weather(try_day) == "sunny": ...
    elif code == "DOUBLE_BOOKING":
        retry = construction_assign(candidates[0]["name"], job["id"], current_day + 1)
```

#### User Message (both)

> Build a schedule for 2 houses (H1, H2) with 5 jobs and 3 workers. Day 1 is rain, days 2-5 are sunny.
>
> Expect your assign() calls to fail sometimes. When they fail, read the error_code, diagnose what went wrong, fix it, and retry. Track all errors on the blackboard. Show the final schedule and error count.

---

## 5. Results Matrix (Run 4 — with stream fix)

| Room | Tier | Model | Duration | Assignments | Conflicts | Status |
|------|------|-------|----------|-------------|-----------|--------|
| prescriptive-20b | T1 | 20B | 10s | 3/3 | 0 | PASS |
| prescriptive-120b | T1 | 120B | 15s | 3/3 | 0 | PASS |
| scheduler-20b | T2 | 20B | 10s | 5/5 | 0 | PASS (optimal) |
| scheduler-120b | T2 | 120B | 8s | 0/5 | 0 | FAIL (server 400 — nil content) |
| dispatcher-20b | T3 | 20B | 7s | 2/2* | 0 | PASS |
| dispatcher-120b | T3 | 120B | 9s | 2/2* | 0 | PASS |
| recovery-20b | T4 | 20B | 5s | 2/5 | 0 | PARTIAL — only foundations |
| recovery-120b | T4 | 120B | 32s | 5/5 | 0 | PASS (multi-turn recovery) |

*T3 expected: 2 assignments remain after unassigning Alice (day 3) and Charlie's outdoor job (day 4 rain). Both models correctly processed both disruptions.

**T2 120B server error:** The 120B model returned nil content on this run — a known flaky issue with the Ollama provider. Previous runs passed (5/5 optimal).

---

## 6. Generated Python (per room)

Python code is reconstructed from MONTY log output. The 20B models
copy-paste the scaffold almost verbatim. The 120B models write
their own logic from the function catalog.

### 6a. T1 20B — Generated Python

20B emitted all 3 assignments + advances in a single `execute_python` call,
directly copying the example pattern from the prompt:

```python
# Single execute_python call — all 3 steps
result = construction_assign("Bob", "H1_FND", 2)
log(f"Assign Bob to H1_FND day 2: {result}")
completed = construction_advance_day(2)
log(f"Day 2 completed: {completed}")

result = construction_assign("Alice", "H1_FRM", 3)
log(f"Assign Alice to H1_FRM day 3: {result}")
completed = construction_advance_day(3)
log(f"Day 3 completed: {completed}")

result = construction_assign("Charlie", "H1_ROF", 4)
log(f"Assign Charlie to H1_ROF day 4: {result}")
completed = construction_advance_day(4)
log(f"Day 4 completed: {completed}")

conflicts = construction_detect_conflicts()
print(conflicts)
```

**Observations:** Literal copy of the example pattern. 1 tool call, 9s total.

### 6b. T1 120B — Generated Python

120B used **4 separate** `execute_python` calls — one per assignment step,
then one for conflict check. Each step was a single function call:

```python
# Call 1:
result = construction_assign("Bob", "H1_FND", 2)
construction_advance_day(2)
print(result)

# Call 2:
result = construction_assign("Alice", "H1_FRM", 3)
construction_advance_day(3)
print(result)

# Call 3:
result = construction_assign("Charlie", "H1_ROF", 4)
construction_advance_day(4)
print(result)

# Call 4:
conflicts = construction_detect_conflicts()
print(conflicts)
```

**Observations:** Step-by-step reasoning. 4 tool calls, 15s total. The 120B
model "thinks step by step" as instructed, using each call's output to inform
the next. More expensive but self-corrects if any step fails.

### 6c. T2 20B — Generated Python

20B copied the scaffolded scheduling loop verbatim in a single call:

```python
current_day = 1
while True:
    ready = construction_get_ready_jobs()
    if len(ready) == 0:
        break
    log(f"Day {current_day}: {len(ready)} ready jobs")
    for job in ready:
        workers = construction_find_workers_for_job(job["id"], current_day)
        if len(workers) > 0:
            result = construction_assign(workers[0]["name"], job["id"], current_day)
            if result["ok"]:
                log(f"  {workers[0]['name']} -> {job['id']}")
            else:
                log(f"  FAILED: {result['error']}")
    construction_advance_day(current_day)
    current_day = current_day + 1

conflicts = construction_detect_conflicts()
schedule = construction_get_schedule()
log(f"Done: {len(schedule)} assignments, {len(conflicts)} conflicts")
print(schedule)
```

**Observations:** Near-verbatim copy of the prompt scaffold. 1 tool call,
10s total. Produced optimal 4-day schedule. Skipped day 1 (rain) naturally
because `construction_find_workers_for_job` returned empty for outdoor jobs.

### 6d. T2 120B — Generated Python

120B returned nil content on this run (server 400). On previous successful
runs, it wrote its own scheduling loop (not a copy-paste) with explicit
weather checks:

```python
# Previous successful run (Run 3):
jobs = construction_get_jobs()
staff = construction_get_staff()
log(f"Scheduling {len(jobs)} jobs with {len(staff)} workers")

current_day = 1
while True:
    ready = construction_get_ready_jobs()
    if len(ready) == 0:
        break

    weather = construction_get_weather(current_day)
    log(f"Day {current_day}: weather={weather}, {len(ready)} ready jobs")

    for job in ready:
        candidates = construction_find_workers_for_job(job["id"], current_day)
        if len(candidates) > 0:
            result = construction_assign(
                candidates[0]["name"], job["id"], current_day
            )
            if result["ok"]:
                log(f"  Assigned {candidates[0]['name']} -> {job['id']}")
            else:
                log(f"  Failed: {result['error']}", level="warning")

    completed = construction_advance_day(current_day)
    log(f"  Completed: {completed}")
    current_day = current_day + 1

conflicts = construction_detect_conflicts()
schedule = construction_get_schedule()
log(f"Done! {len(schedule)} assignments, {len(conflicts)} conflicts")
print(schedule)
```

**Observations:** Similar to the pattern guidance but not a copy-paste.
Added explicit weather logging. 2 tool calls (first to explore, then schedule).

### 6e. T3 20B — Generated Python

**First successful T3 run!** 20B copied the scaffolded event loop:

```python
crew_h = stream_subscribe("crew_updates")
weather_h = stream_subscribe("weather_updates")
log("Subscribed to streams")

while True:
    event = stream_select([crew_h, weather_h])
    if event is None:
        log("All streams done")
        break

    data = event["data"]
    event_type = data["type"]
    log(f"Event: {event_type}")

    if event_type == "crew_noshow":
        worker = data["worker"]
        day = data["day"]
        job_id = None
        schedule = construction_get_day_schedule(day)
        for entry in schedule:
            if entry["worker"] == worker:
                job_id = entry["job_id"]
        construction_unassign(worker, day)
        log(f"Unassigned {worker} from day {day}")
        if job_id is not None:
            replacements = construction_find_workers_for_job(job_id, day)
            if len(replacements) > 0:
                result = construction_assign(replacements[0]["name"], job_id, day)
                log(f"Replaced with {replacements[0]['name']}: {result}")

    elif event_type == "weather_change":
        day = data["day"]
        condition = data["condition"]
        log(f"Weather on day {day} changed to {condition}")
        if condition == "rain":
            schedule = construction_get_day_schedule(day)
            for entry in schedule:
                if construction_is_outdoor(entry["job_id"]):
                    construction_unassign(entry["worker"], day)
                    log(f"Removed outdoor job {entry['job_id']}")

print(construction_get_schedule())
```

**Observations:** Near-verbatim copy of scaffold. Single `execute_python` call.
Processed both events, `stream_select` returned `None` on third call (fix #2),
loop exited cleanly. 7s total. The stream fix unblocked this completely.

### 6f. T3 120B — Generated Python

120B wrote its own event loop from the pattern guidance:

```python
crew_h = stream_subscribe("crew_updates")
weather_h = stream_subscribe("weather_updates")
handles = [crew_h, weather_h]
log(f"Subscribed to {len(handles)} streams")

while True:
    event = stream_select(handles)
    if event is None:
        log("All streams exhausted")
        break

    data = event["data"]
    event_type = data["type"]
    log(f"Event: {event_type} on day {data.get('day', '?')}")

    if event_type == "crew_noshow":
        worker = data["worker"]
        day = data["day"]
        job_id = None
        schedule = construction_get_day_schedule(day)
        for entry in schedule:
            if entry["worker"] == worker:
                job_id = entry["job_id"]
        result = construction_unassign(worker, day)
        log(f"Unassigned {worker} from day {day}: {result}")
        if job_id is not None:
            candidates = construction_find_workers_for_job(job_id, day)
            if len(candidates) > 0:
                result = construction_assign(
                    candidates[0]["name"], job_id, day
                )
                log(f"Replaced with {candidates[0]['name']}: {result}")
        else:
            log(f"Worker {worker} had no assigned job on day {day}")

    elif event_type == "weather_change":
        day = data["day"]
        new_weather = data["condition"]
        log(f"Weather changed to {new_weather} on day {day}")
        if new_weather == "rain":
            schedule = construction_get_day_schedule(day)
            for entry in schedule:
                job_id = entry["job_id"]
                if construction_is_outdoor(job_id):
                    construction_unassign(entry["worker"], day)
                    log(f"Unassigned outdoor job {job_id}")

conflicts = construction_detect_conflicts()
log(f"Final conflicts detected: {len(conflicts)}")
print(construction_get_schedule())
```

**Observations:** Single `execute_python` call. More defensive — logs unassign
result, handles case where worker had no assignment. Added conflict check at
end. 9s total.

### 6g. T4 20B — Generated Python

20B copied the error-handling scaffold but **stopped after the first pass**:

```python
current_day = 1
errors = []

while True:
    ready = construction_get_ready_jobs()
    if len(ready) == 0:
        break
    log(f"Day {current_day}: {len(ready)} ready jobs")

    for job in ready:
        workers = construction_find_workers_for_job(job["id"], current_day)
        if len(workers) == 0:
            log(f"  No workers for {job['id']} — skip")
            continue

        result = construction_assign(workers[0]["name"], job["id"], current_day)

        if result["ok"]:
            log(f"  OK: {workers[0]['name']} -> {job['id']}")
        else:
            errors.append(result)
            code = result["error_code"]
            log(f"  ERROR {code}: {result['error']}")

            if code == "WEATHER_RAIN":
                for try_day in range(current_day + 1, current_day + 5):
                    if construction_get_weather(try_day) == "sunny":
                        retry = construction_assign(workers[0]["name"], job["id"], try_day)
                        if retry["ok"]:
                            log(f"  Fixed: moved to day {try_day}")
                            break

            elif code == "DOUBLE_BOOKING":
                retry = construction_assign(workers[0]["name"], job["id"], current_day + 1)
                if retry["ok"]:
                    log(f"  Fixed: moved to day {current_day + 1}")

    construction_advance_day(current_day)
    current_day = current_day + 1

blackboard_write("errors", errors)
schedule = construction_get_schedule()
conflicts = construction_detect_conflicts()
log(f"Done: {len(schedule)} assignments, {len(errors)} errors, {len(conflicts)} conflicts")
print(schedule)
```

**Observations:** Verbatim copy of scaffold. Handles WEATHER_RAIN correctly
(moves H1_FND to day 2, H2_FND to day 3). But `construction_advance_day(1)`
doesn't complete any jobs (nothing was assigned to day 1), so deps for framing
are never met. The loop sees 0 ready jobs on day 2 and exits. **Only 2/5 jobs
completed** — the 20B model can't reason about "I moved jobs to later days so
I need to advance those days too."

### 6h. T4 120B — Generated Python

120B used **2 tool calls** with self-correction across turns:

```python
# Call 1: Initial scheduling attempt
jobs = construction_get_jobs()
staff = construction_get_staff()
errors = []

current_day = 1
while True:
    ready = construction_get_ready_jobs()
    if len(ready) == 0:
        break

    for job in ready:
        candidates = construction_find_workers_for_job(
            job["id"], current_day
        )
        if len(candidates) == 0:
            log(f"No workers for {job['id']} on day {current_day}")
            continue

        result = construction_assign(
            candidates[0]["name"], job["id"], current_day
        )

        if not result["ok"]:
            code = result["error_code"]
            errors.append(result)
            log(f"Assign error {code} for job {job['id']}: {result['error']}",
                level="warning")

            if code == "WEATHER_RAIN":
                for try_day in range(current_day + 1, current_day + 10):
                    if construction_get_weather(try_day) == "sunny":
                        retry = construction_assign(
                            candidates[0]["name"], job["id"], try_day
                        )
                        if retry["ok"]:
                            log(f"Rescheduled {job['id']} to sunny day {try_day}")
                            break
        else:
            log(f"Assigned {candidates[0]['name']} -> {job['id']}")

    construction_advance_day(current_day)
    current_day = current_day + 1

blackboard_write("errors", errors)
schedule = construction_get_schedule()
conflicts = construction_detect_conflicts()
log(f"Finished scheduling: {len(schedule)} assignments, "
    f"{len(errors)} errors, {len(conflicts)} conflicts")
print(schedule)
```

```python
# Call 2: 120B saw only 2 assignments, realized deps are now met,
# and scheduled the remaining 3 jobs
ready = construction_get_ready_jobs()
log(f"Remaining ready jobs: {len(ready)}")

current_day = 3
for job in ready:
    candidates = construction_find_workers_for_job(job["id"], current_day)
    if len(candidates) > 0:
        result = construction_assign(
            candidates[0]["name"], job["id"], current_day
        )
        if result["ok"]:
            log(f"Assigned {candidates[0]['name']} -> {job['id']} on day {current_day}")
            construction_advance_day(current_day)
            current_day = current_day + 1

schedule = construction_get_schedule()
conflicts = construction_detect_conflicts()
log(f"Finished: {len(schedule)} assignments, 0 errors, "
    f"{len(conflicts)} conflicts")
print(schedule)
```

**Observations:** The key difference from 20B: after the first call returned
only 2 assignments, the 120B model **inspected the result, realized the
schedule was incomplete, and issued a second call** to schedule the remaining
3 jobs. This is the "executive function" that 20B lacks — the ability to
self-monitor progress and take corrective action across turns. 32s total.

---

## 7. Analysis

### Prompt Strategy Comparison

| Dimension | 20B Prompts | 120B Prompts |
|-----------|-------------|--------------|
| **Style** | Directive, scaffolded | Rule-based, catalog |
| **Functions listed** | 5-10 (minimal) | 18+ (full catalog) |
| **Code examples** | Copy-paste ready | Pattern guidance |
| **Sandbox rules** | Implicit (no imports) | Explicit (8 rules) |
| **Error handling** | Pre-built in scaffold | Pattern with all codes |

### Key Findings

**T1 (Prescriptive):** Both models pass. 20B is faster (10s vs 15s) and
uses fewer tool calls (1 vs 4). 20B copies the scaffold; 120B reasons
step-by-step.

**T2 (Scheduler):** 20B passes consistently (optimal 4-day schedule, 1
tool call). 120B passes but is flaky — nil content errors on some runs.
When it works, it also produces the optimal schedule.

**T3 (Dispatcher):** **Both models now pass** after the stream fix.
Both subscribe to 2 streams, process crew_noshow + weather_change events,
and exit cleanly when streams exhaust. The 20B copies the scaffold; the
120B writes more defensive code (logs results, handles edge cases).

**T4 (Recovery):** 20B fails (2/5 jobs) — copies the error-handling loop
but can't self-correct across turns. When jobs get rescheduled to later
days, the 20B loop exits because `construction_get_ready_jobs()` returns
empty (deps not met yet for the advanced day). The model doesn't realize
it needs to keep going. 120B succeeds (5/5) by issuing a second tool call
after inspecting the incomplete result.

### 20B vs 120B Capability Boundary

| Capability | 20B | 120B |
|------------|-----|------|
| Follow explicit instructions | YES | YES |
| Copy-paste and parameterize scaffolds | YES | YES |
| Generate code from function catalog | NO | YES |
| Single-pass scheduling loop | YES | YES |
| Reactive event processing | YES (with scaffold) | YES |
| Multi-turn self-correction | NO | YES |
| Self-monitor progress across calls | NO | YES |

**The boundary is "executive function"** — the ability to inspect partial
results, realize the task is incomplete, and take corrective action. 20B
can execute a pre-written plan but can't adapt when the plan produces
incomplete results.

### Architecture Decision

**Tiered model routing:**

- T1-T3: Run on 20B locally (fast, cheap, reliable with scaffolds)
- T4+: Run on 120B (or cloud for higher reliability)
- Build task router that dispatches based on room tier

---

## 8. Infrastructure Fixes Applied

### Bug #1: Bridge error handling (this run)

`DefaultMontyBridge._dispatchToolCall` and `_resolveFutures` caught `Exception`
but not `Error`. When `StreamRegistry.select()` threw `ArgumentError` (an `Error`),
the Monty platform was never resumed — stuck permanently in `Pending` state.

**Fix:** `on Exception catch (e)` → `on Object catch (e)` in both methods.

### Bug #2: Stream handle cleanup (this run)

`StreamRegistry.select()` threw `ArgumentError` on exhausted handles. LLM's
natural loop pattern retries `stream_select([1, 2])` after streams exhaust.

**Fix:** Filter stale handles, return `null` when all gone.

### Bug #3: StreamRegistry inaccessible (GitHub issue #88)

`StreamRegistry` created inside `createMontyScriptEnvironmentFactory` — not
accessible from outside. Added `streamSetup` callback parameter as workaround.
