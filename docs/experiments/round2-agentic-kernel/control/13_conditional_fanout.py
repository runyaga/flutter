# Control: Pattern 13 — Conditional fan-out based on intermediate result
# Ask an LLM a question, then based on the answer, spawn different workers.

# Step 1: Ask a classifier question
r = ask_llm("Is 7 an even or odd number? Reply with just 'even' or 'odd'.", room="plain")
classification = r["text"].strip().lower()
print(f"Classification: {classification}")

# Step 2: Conditional fan-out based on answer
if "odd" in classification:
    h1 = spawn_agent("plain", "Name 3 odd numbers. Reply with just the numbers separated by commas.")
    h2 = spawn_agent("plain", "What is 7 * 3? Reply with just the number.")
else:
    h1 = spawn_agent("plain", "Name 3 even numbers. Reply with just the numbers separated by commas.")
    h2 = spawn_agent("plain", "What is 8 * 3? Reply with just the number.")

# Step 3: Collect results
results = wait_all([h1, h2])
print(f"Worker 1: {results[0]}")
print(f"Worker 2: {results[1]}")

# Step 4: Write decision path to blackboard
blackboard_write("classification", classification)
blackboard_write("worker_results", results)
print(f"Blackboard keys: {blackboard_keys()}")
