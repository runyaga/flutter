# Control: Pattern 4 — Timeout + cancel
# Cancel a worker that takes too long (bounded poll loop).

handle = spawn_agent("plain", "Write a very short haiku about the sea")
max_polls = 60  # 30 seconds at 500ms intervals
timed_out = True

for i in range(max_polls):
    status = agent_status(handle)
    if status in ("completed", "failed", "cancelled"):
        timed_out = False
        break
    sleep(500)

if timed_out:
    cancel_agent(handle)
    print("TIMEOUT: cancelled worker after max polls")
elif status == "completed":
    result = get_result(handle)
    print(f"Completed in {i + 1} polls: {result}")
else:
    print(f"Worker ended with status: {status}")
