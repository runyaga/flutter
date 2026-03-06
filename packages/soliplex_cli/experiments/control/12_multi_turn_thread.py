# Control: Pattern 12 — Multi-turn thread continuation
# Use ask_llm with thread_id to build a multi-turn conversation,
# then verify context is maintained.

# Turn 1: establish context
turn1 = ask_llm("Remember this word: elephant. Just say 'OK'.", room="plain")
print(f"Turn 1: {turn1['text']}, thread={turn1['thread_id']}")

# Turn 2: test recall on same thread
turn2 = ask_llm(
    "What word did I ask you to remember? Reply with just the word.",
    room="plain",
    thread_id=turn1["thread_id"],
)
print(f"Turn 2: {turn2['text']}")

# Turn 3: build on context
turn3 = ask_llm(
    "Spell that word backwards. Reply with just the reversed word.",
    room="plain",
    thread_id=turn1["thread_id"],
)
print(f"Turn 3: {turn3['text']}")

blackboard_write("recall_test", turn2["text"])
blackboard_write("reverse_test", turn3["text"])
