# Control: Pattern 14 — Iterative refinement loop
# Spawn a worker, check if result meets criteria, if not refine and retry.

target_length = 20  # want a response of at least 20 chars
max_attempts = 3
final_result = None

for attempt in range(max_attempts):
    prompt = "Write a one-sentence fun fact about dolphins."
    if attempt > 0:
        prompt = f"Write a longer one-sentence fun fact about dolphins (at least {target_length} characters)."

    h = spawn_agent("plain", prompt)
    result = agent_watch(h, timeout_seconds=30)

    if result["status"] == "success":
        text = result["output"]
        print(f"Attempt {attempt + 1}: '{text}' (len={len(text)})")
        if len(text) >= target_length:
            final_result = text
            break
        print(f"  Too short, refining...")
    elif result["status"] == "failed":
        print(f"Attempt {attempt + 1}: failed — {result['reason']}")
    else:
        print(f"Attempt {attempt + 1}: timed out")
        cancel_agent(h)

if final_result:
    blackboard_write("dolphin_fact", final_result)
    print(f"Final: {final_result}")
else:
    print("All attempts failed to meet criteria")
