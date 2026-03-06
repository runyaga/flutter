# Control: Pattern 6 — Nested supervision (2-level)
# L1 supervisor spawns an L2 sub-supervisor (chat room agent),
# which internally handles a task. L1 polls L2 status.

sub = spawn_agent(
    "plain",
    "You are a helpful assistant. Summarize the following two facts: "
    "Fact 1: The sky is blue. Fact 2: Water is wet. "
    "Give a one-sentence summary."
)

max_polls = 120  # 60s timeout
timed_out = True

for i in range(max_polls):
    status = agent_status(sub)
    if status in ("completed", "failed", "cancelled"):
        timed_out = False
        break
    sleep(500)

if timed_out:
    cancel_agent(sub)
    print("L2 sub-supervisor timed out")
elif status == "completed":
    result = get_result(sub)
    blackboard_write("l2_result", result)
    print(f"L2 completed: {result}")
    print(f"Blackboard l2_result: {blackboard_read('l2_result')}")
else:
    print(f"L2 ended with status: {status}")
