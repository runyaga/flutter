# Control: Pattern 7 — wait_all batch await
# Use wait_all() instead of manual polling — simpler fan-out.

h1 = spawn_agent("plain", "Say 'alpha'")
h2 = spawn_agent("plain", "Say 'beta'")
h3 = spawn_agent("plain", "Say 'gamma'")

# Block until all three complete (no manual polling needed).
results = wait_all([h1, h2, h3])

print(f"All done. Results: {results}")
for i, r in enumerate(results):
    blackboard_write(f"batch_{i}", str(r))

print(f"Blackboard keys: {blackboard_keys()}")
