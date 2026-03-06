# Control: Pattern 17 — Blackboard accumulator: multiple agents write, supervisor reduces
# Tests blackboard as shared state across sequential agent operations.

topics = ["math", "science", "history"]

# Phase 1: Each agent generates a question about its topic
for i, topic in enumerate(topics):
    h = spawn_agent("plain", f"Write one trivia question about {topic}. Just the question, no answer.")
    result = agent_watch(h, timeout_seconds=30)
    if result["status"] == "success":
        blackboard_write(f"question_{i}", result["output"])
        print(f"Q{i} ({topic}): {result['output']}")
    else:
        blackboard_write(f"question_{i}", f"FAILED: {result['status']}")

# Phase 2: Read all questions from blackboard and create a quiz
questions = []
for i in range(len(topics)):
    q = blackboard_read(f"question_{i}")
    if q and not q.startswith("FAILED"):
        questions.append(q)

quiz_text = "\n".join(f"{i+1}. {q}" for i, q in enumerate(questions))
print(f"\nQuiz ({len(questions)} questions):")
print(quiz_text)

# Phase 3: Ask an LLM to answer the quiz
r = ask_llm(
    f"Answer these trivia questions briefly:\n{quiz_text}",
    room="plain",
)
print(f"\nAnswers: {r['text']}")
blackboard_write("quiz", quiz_text)
blackboard_write("answers", r["text"])
print(f"Blackboard keys: {blackboard_keys()}")
