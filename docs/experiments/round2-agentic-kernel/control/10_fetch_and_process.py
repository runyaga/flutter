# Control: Pattern 10 — fetch HTTP + process with LLM
# Use fetch() to get data, then ask_llm() to process it.

# Fetch from the backend API (no auth needed in --no-auth-mode)
resp = fetch("http://localhost:8000/api/ok")
print(f"Status: {resp['status']}")
print(f"Body: {resp['body']}")

# Now ask an LLM to summarize what we got
summary = ask_llm(
    f"I fetched an API and got status {resp['status']} with body: {resp['body']}. "
    "Summarize this in one sentence.",
    room="plain",
)
print(f"LLM summary: {summary['text']}")
blackboard_write("api_summary", summary["text"])
