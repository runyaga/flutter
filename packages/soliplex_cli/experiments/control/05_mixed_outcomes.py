# Control: Pattern 5 — Mixed outcomes with partial results
# 3 workers: expect success, possible failure, possible slow.

tasks = [
    ("plain", "Say 'alpha'"),
    ("plain", "Say 'beta'"),
    ("plain", "Say 'gamma'"),
]

handles = [spawn_agent(room, prompt) for room, prompt in tasks]

results = {}
failures = []
timeouts = []

for idx, h in enumerate(handles):
    polls = 0
    max_polls = 60  # 30s timeout per worker
    done = False

    while polls < max_polls:
        status = agent_status(h)
        if status in ("completed", "failed", "cancelled"):
            done = True
            break
        sleep(500)
        polls += 1

    if not done:
        timeouts.append(idx)
        cancel_agent(h)
    elif status == "completed":
        results[idx] = get_result(h)
    else:
        failures.append(idx)

blackboard_write("successes", len(results))
blackboard_write("failures", len(failures))
blackboard_write("timeouts", len(timeouts))

print(f"Results: {results}")
print(f"Failures: {failures}")
print(f"Timeouts: {timeouts}")
print(f"Blackboard: successes={blackboard_read('successes')}, failures={blackboard_read('failures')}, timeouts={blackboard_read('timeouts')}")
