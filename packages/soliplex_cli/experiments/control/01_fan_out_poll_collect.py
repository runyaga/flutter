# Control: Pattern 1 — Fan-out poll collect (happy path)
# Spawn 2 workers, poll until done, collect results.

h1 = spawn_agent("plain", "say hello")
h2 = spawn_agent("plain", "say goodbye")

for handle in [h1, h2]:
    while True:
        status = agent_status(handle)
        if status in ("completed", "failed", "cancelled"):
            break
        sleep(500)

r1 = get_result(h1)
r2 = get_result(h2)
print(f"Worker 1: {r1}")
print(f"Worker 2: {r2}")
