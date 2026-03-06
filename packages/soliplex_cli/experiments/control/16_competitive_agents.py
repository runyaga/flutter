# Control: Pattern 16 — Competitive agents: spawn N, take first completed, cancel rest
# Race pattern: first agent to finish wins.

prompts = [
    "Count from 1 to 5 and reply with just the numbers.",
    "Name the 4 seasons. Reply with just the names.",
    "List 3 primary colors. Reply with just the colors.",
]

# Spawn all
handles = []
for p in prompts:
    h = spawn_agent("plain", p)
    handles.append(h)
    print(f"Spawned handle {h}")

# Poll for first completion
winner = None
winner_result = None
polls = 0

while winner is None:
    for h in handles:
        status = agent_status(h)
        if status == "completed":
            winner = h
            winner_result = get_result(h)
            break
    if winner is None:
        sleep(300)
        polls += 1
        if polls > 100:
            print("Timeout waiting for any agent")
            break

# Cancel losers
cancelled = 0
for h in handles:
    if h != winner:
        cancel_agent(h)
        cancelled += 1

print(f"Winner: handle {winner} after {polls} polls")
print(f"Result: {winner_result}")
print(f"Cancelled {cancelled} other agents")
blackboard_write("winner_handle", winner)
blackboard_write("winner_result", winner_result)
