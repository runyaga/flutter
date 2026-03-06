# Control: Pattern 2 — Blackboard coordination
# Workers produce data, supervisor aggregates via blackboard.

h1 = spawn_agent("plain", "What is 2 + 2? Reply with just the number.")
h2 = spawn_agent("plain", "What is 3 + 3? Reply with just the number.")

for handle in [h1, h2]:
    while True:
        status = agent_status(handle)
        if status in ("completed", "failed", "cancelled"):
            break
        sleep(500)

blackboard_write("answer_1", get_result(h1))
blackboard_write("answer_2", get_result(h2))

a1 = blackboard_read("answer_1")
a2 = blackboard_read("answer_2")
blackboard_write("summary", f"Answer1={a1}, Answer2={a2}")

print(f"Blackboard keys: {blackboard_keys()}")
print(f"Summary: {blackboard_read('summary')}")
