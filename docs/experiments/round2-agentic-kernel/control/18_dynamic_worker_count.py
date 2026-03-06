# Control: Pattern 18 — Dynamic worker count based on data
# The supervisor doesn't know how many workers to spawn until it gets data.

# Step 1: Ask how many items to process
r = ask_llm("Pick a number between 2 and 5. Reply with just the digit.", room="plain")
raw = r["text"].strip()

# Parse the number (defensive)
count = 3  # default
for ch in raw:
    if ch.isdigit():
        n = int(ch)
        if 2 <= n <= 5:
            count = n
            break

print(f"Worker count: {count}")
blackboard_write("worker_count", count)

# Step 2: Dynamically spawn that many workers
handles = []
for i in range(count):
    h = spawn_agent("plain", f"Say the word 'item_{i}'. Reply with just that word.")
    handles.append(h)

# Step 3: Collect all with wait_all
results = wait_all(handles)
print(f"Results ({len(results)} workers): {results}")

# Step 4: Verify count matches
blackboard_write("results", results)
expected = count
actual = len(results)
match = "MATCH" if expected == actual else "MISMATCH"
print(f"Expected {expected} results, got {actual}: {match}")
blackboard_write("count_check", match)
