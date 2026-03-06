# Control: Pattern 8 — agent_watch structured result
# Use agent_watch() for rich status info (success/failed/timed_out + details).

h1 = spawn_agent("plain", "Say hello")
h2 = spawn_agent("plain", "Say goodbye")

for handle in [h1, h2]:
    info = agent_watch(handle)
    print(f"Handle {handle}: status={info['status']}")

    if info["status"] == "success":
        print(f"  output: {info['output']}")
        blackboard_write(f"watch_{handle}", info["output"])
    elif info["status"] == "failed":
        print(f"  reason: {info.get('reason', 'unknown')}")
        print(f"  error: {info.get('error', 'none')}")
        if "partial_output" in info:
            print(f"  partial: {info['partial_output']}")
    elif info["status"] == "timed_out":
        print(f"  elapsed: {info['elapsed_seconds']}s")
        cancel_agent(handle)
