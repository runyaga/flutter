# Control: Pattern 3 — Failure detection + retry
# Spawn a worker, retry on failure up to max_retries.
# (In practice chat rooms don't fail often, so this tests the structure.)

max_retries = 2
result = None

for attempt in range(max_retries + 1):
    handle = spawn_agent("plain", "Say the word 'success'")

    while True:
        status = agent_status(handle)
        if status in ("completed", "failed", "cancelled"):
            break
        sleep(500)

    if status == "completed":
        result = get_result(handle)
        print(f"Attempt {attempt + 1}: completed — {result}")
        break

    print(f"Attempt {attempt + 1}: {status} — retrying")
    cancel_agent(handle)

if result is None:
    print("ERROR: all retries exhausted")
