# Control: Pattern 15 — Sequential pipeline where each step depends on previous
# Step 1: Generate data → Step 2: Analyze → Step 3: Summarize

# Step 1: Ask for raw data
r1 = ask_llm(
    "List 5 countries and their approximate populations in millions. "
    "Format: country:population, one per line. Just the data, no extra text.",
    room="plain",
)
raw_data = r1["text"]
print(f"Step 1 (raw data):\n{raw_data}")
blackboard_write("raw_data", raw_data)

# Step 2: Ask another agent to analyze the data from step 1
r2 = ask_llm(
    f"Given this data:\n{raw_data}\n\n"
    "Which country has the largest population? Reply with just the country name.",
    room="plain",
)
largest = r2["text"]
print(f"Step 2 (analysis): {largest}")
blackboard_write("largest_country", largest)

# Step 3: Ask a third agent to generate a fact about the result of step 2
h = spawn_agent(
    "plain",
    f"Tell me one interesting fact about {largest}. Keep it to one sentence.",
)
result = agent_watch(h, timeout_seconds=30)
if result["status"] == "success":
    fact = result["output"]
    print(f"Step 3 (fact): {fact}")
    blackboard_write("fact", fact)
else:
    print(f"Step 3 failed: {result['status']}")

# Verify full pipeline via blackboard
print(f"Pipeline complete. Keys: {blackboard_keys()}")
