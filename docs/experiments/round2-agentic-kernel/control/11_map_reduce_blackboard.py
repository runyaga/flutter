# Control: Pattern 11 — Map-reduce via blackboard
# Spawn N workers (map), each writes to blackboard, supervisor reduces.

questions = [
    "Name one planet in our solar system. Reply with just the name.",
    "Name one ocean on Earth. Reply with just the name.",
    "Name one continent. Reply with just the name.",
]

# Map phase: spawn all workers
handles = []
for i, q in enumerate(questions):
    h = spawn_agent("plain", q)
    handles.append((i, h))
    log(f"Spawned worker {i} with handle {h}", level="debug")

# Collect phase: poll and write to blackboard
for i, h in handles:
    while True:
        status = agent_status(h)
        if status in ("completed", "failed", "cancelled"):
            break
        sleep(500)

    if status == "completed":
        result = get_result(h)
        blackboard_write(f"answer_{i}", result)
        log(f"Worker {i} completed: {result}", level="info")
    else:
        blackboard_write(f"answer_{i}", f"FAILED:{status}")
        log(f"Worker {i} failed: {status}", level="warning")

# Reduce phase: read all results and aggregate
answers = []
for i in range(len(questions)):
    val = blackboard_read(f"answer_{i}")
    answers.append(val)

summary = "; ".join(answers)
blackboard_write("all_answers", summary)
print(f"Map-reduce result: {summary}")
print(f"Blackboard keys: {blackboard_keys()}")
