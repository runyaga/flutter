# Control: Pattern 9 — ask_llm synchronous call
# ask_llm() is spawn+await in one shot. Returns {text, thread_id}.
# Use thread_id to continue conversations.

# First question
response1 = ask_llm("What is 2+2? Reply with just the number.", room="plain")
print(f"Response 1: {response1['text']}")
print(f"Thread ID: {response1['thread_id']}")

# Follow-up on the same thread
response2 = ask_llm(
    "Now multiply that by 3. Reply with just the number.",
    room="plain",
    thread_id=response1["thread_id"],
)
print(f"Response 2: {response2['text']}")

blackboard_write("conversation_result", response2["text"])
