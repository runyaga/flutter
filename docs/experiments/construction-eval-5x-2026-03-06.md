# Construction Scheduling Experiment: 5-Run Validated Eval (v3)

**Date:** 2026-03-06
**Server:** localhost:8000 (Ollama)
**Models:** gpt-oss:20b, gpt-oss:120b
**Iterations:** 5
**Static reference:** See `docs/experiments/construction-scheduling-2026-03-06.md` for
prompts, host functions, test data, and system architecture.

## Methodology

### Previous evals

- **v1 (smoke test):** Only checked whether the agent returned SUCCESS vs crashed.
  Produced false positives (model reports SUCCESS with incomplete schedule).
- **v2 (correctness validation):** Added per-check validation against actual
  `ConstructionState`. But only captured Python code, not execution results.

### This eval (v3)

Same correctness validation as v2, but each tool call now captures both the
**code** sent and the **result** returned. Output format per call:

```text
--- call N ---
[code]
<python code the LLM generated>

[result]
<what the Monty interpreter returned>
```

### Scoring Criteria

| Tier | Checks | CORRECT | INCORRECT |
|------|--------|---------|-----------|
| T1 (Prescriptive) | 3 assigns, 0 conflicts, Bob->H1_FND d2, Alice->H1_FRM d3, Charlie->H1_ROF d4, all completed | 6/6 | <6/6 |
| T2 (Scheduler) | 5 assigns, 0 conflicts, all completed, no outdoor d1, span <= 4 days | 5/5 | <5/5 |
| T3 (Dispatcher) | 0 conflicts, Alice NOT on d3, no outdoor d4, Bob->H1_FND d2, Bob->H2_FND d3 | 5/5 | <5/5 |
| T4 (Recovery) | 5 assigns, 0 conflicts, all completed, no outdoor d1 | 4/4 | <4/4 |

## Results Matrix

### T1: Prescriptive (explicit step-by-step instructions)

| Run | 20B | 120B |
|-----|-----|------|
| 1 | CORRECT 6/6 (14s, 1 call) | INCORRECT 3/6 server 400 (21s, 6 calls) |
| 2 | CORRECT 6/6 (6s, 4 calls) | INCORRECT 3/6 server 400 (9s, 3 calls) |
| 3 | CORRECT 6/6 (7s, 4 calls) | INCORRECT 5/6 tool depth (15s, 11 calls) |
| 4 | CORRECT 6/6 (7s, 4 calls) | CORRECT 6/6 (11s, 2 calls) |
| 5 | CORRECT 6/6 (6s, 4 calls) | INCORRECT 3/6 server 400 (14s, 10 calls) |
| **Total** | **5/5 CORRECT** | **1/5 CORRECT** |

**Notes:**

- 20B is 100% reliable on T1 across all 5 runs.
- 120B run 3 is a new failure mode: hit tool depth limit (10 calls). All 3 assignments were placed correctly (5/6 checks pass) but `advance_day` was never called, so jobs aren't marked "completed" (FAIL on check 6). The model explored/queried too much before executing.
- 120B runs 1, 2, 5 are server 400 (Ollama `nil content`). Run 2 also hit a Monty type error (`expected String, got _Map`) — 120B passed a dict instead of a string for the worker parameter.

### T2: Scheduler (build optimal schedule from constraints)

| Run | 20B | 120B |
|-----|-----|------|
| 1 | CORRECT 5/5 (5s, 1 call) | CORRECT 5/5 (14s, 2 calls) |
| 2 | CORRECT 5/5 (11s, 1 call) | CORRECT 5/5 (15s, 2 calls) |
| 3 | CORRECT 5/5 (14s, 1 call) | CORRECT 5/5 (11s, 1 call) |
| 4 | CORRECT 5/5 (20s, 1 call) | CORRECT 5/5 (22s, 3 calls) |
| 5 | INCORRECT 3/5 (4s, 0 calls) | CORRECT 5/5 (31s, 5 calls) |
| **Total** | **4/5 CORRECT** | **5/5 CORRECT** |

**Notes:**

- **T2 20B run 5: code-as-text false positive.** The model outputted a complete Python script as markdown text in its SUCCESS response instead of calling `execute_python`. 0 tool calls, empty schedule, INCORRECT. The model "knew" the algorithm but didn't execute it.
- 120B is 100% on T2 but takes 1-5 calls vs 20B's single-call approach.

### T3: Dispatcher (stream subscription + reactive scheduling)

| Run | 20B | 120B |
|-----|-----|------|
| 1 | CORRECT 5/5 (23s, 2 calls) | CORRECT 5/5 (10s, 1 call) |
| 2 | CORRECT 5/5 (12s, 1 call) | CORRECT 5/5 (11s, 1 call) |
| 3 | CORRECT 5/5 (6s, 1 call) | CORRECT 5/5 (13s, 1 call) |
| 4 | CORRECT 5/5 (9s, 1 call) | CORRECT 5/5 (9s, 1 call) |
| 5 | CORRECT 5/5 (10s, 1 call) | CORRECT 5/5 (12s, 1 call) |
| **Total** | **5/5 CORRECT** | **5/5 CORRECT** |

**Notes:**

- 100% correctness for both models across all 5 runs. T3 is completely solved.
- Both correctly: subscribe to streams, unassign Alice on day 3 (crew_noshow), handle rain on day 4, exhaust streams.

### T4: Recovery (error handling + retry logic)

| Run | 20B | 120B |
|-----|-----|------|
| 1 | INCORRECT 2/4 (16s, 1 call) | CORRECT 4/4 (36s, 3 calls) |
| 2 | INCORRECT 2/4 (5s, 1 call) | CORRECT 4/4 (10+ calls) |
| 3 | CORRECT 4/4 (30s, 4 calls) | CORRECT 4/4 (31s, 2 calls) |
| 4 | INCORRECT 2/4 (9s, 1 call) | CORRECT 4/4 (43s, 5 calls) |
| 5 | INCORRECT 2/4 (9s, 1 call) | CORRECT 4/4 (61s, 7 calls) |
| **Total** | **1/5 CORRECT** | **5/5 CORRECT** |

**Notes:**

- **T4 20B run 3: first CORRECT.** 30s, 4 tool calls — 20B CAN do multi-phase scheduling when it gets lucky. All other runs stop after foundations (1 call, 2/5 jobs).
- **120B is 100% on T4** across all 5 runs. Even runs with many tool calls (run 2: 10+) complete all work.
- The 20B capability boundary is real but not absolute — 1/5 success rate vs 0/5 in v2.

## Aggregate Correctness Rates

| Tier | 20B | 120B |
|------|-----|------|
| T1 Prescriptive | 5/5 (100%) | 1/5 (20%) |
| T2 Scheduler | 4/5 (80%) | 5/5 (100%) |
| T3 Dispatcher | 5/5 (100%) | 5/5 (100%) |
| T4 Recovery | 1/5 (20%) | 5/5 (100%) |

## Adjusted Correctness Rates (excluding infra failures)

Removing runs where server 400/500 prevented the model from completing:

| Tier | 20B | 120B |
|------|-----|------|
| T1 Prescriptive | 5/5 (100%) | 1/2 (50%) |
| T2 Scheduler | 4/5 (80%) | 5/5 (100%) |
| T3 Dispatcher | 5/5 (100%) | 5/5 (100%) |
| T4 Recovery | 1/5 (20%) | 5/5 (100%) |

Note: T1 120B run 3 (tool depth exceeded) is a model failure, not infra. T2 20B run 5 (code-as-text) is a model failure.

## Cross-Eval Comparison

| Finding | v1 (smoke) | v2 (validated) | v3 (validated + answers) |
|---------|-----------|----------------|--------------------------|
| T1 20B | 5/5 | 5/5 | 5/5 |
| T1 120B | 2/5* | 2/5* | 1/5 |
| T2 20B | 5/5 | 5/5 | 4/5 (code-as-text) |
| T2 120B | 5/5 | 5/5 | 5/5 |
| T3 all | 10/10 | 10/10 | 10/10 |
| T4 20B | 1/5 (false+) | 0/5 | 1/5 (genuine) |
| T4 120B | 3/5 (false-) | 5/5 | 5/5 |

*120B T1 failures are mostly server 400 (Ollama infrastructure).

Key deltas from v2 to v3:

- **T2 20B dropped from 100% to 80%** — run 5 revealed a new failure mode (code output as text, 0 tool calls).
- **T4 20B went from 0% to 20%** — run 3 showed 20B CAN complete all 5 jobs given enough calls (4 calls, 30s).
- **T1 120B dropped from 40% to 20%** — run 3 hit tool depth instead of server error.

## Key Findings

### 1. Answer capture reveals hidden failure modes

The code-as-text failure (T2 20B run 5) is only visible when you capture both the LLM's answer and the tool call log. The model generated a perfect Python scheduler in its response text, but never called `execute_python`. Without answer capture, this looks like "SUCCESS with 0 calls" which is ambiguous.

### 2. T3 is the most reliably solved tier

10/10 across both models, all 3 eval runs. Stream subscription + reactive scheduling is a fully solved capability for both model sizes.

### 3. T4 20B is not a hard zero

v2 showed 0/5, v3 shows 1/5. The 20B model CAN complete multi-phase scheduling — it just needs 4 tool calls and 30 seconds instead of giving up after 1 call. This suggests prompt engineering (e.g., "continue scheduling after foundations") could improve 20B T4 reliability.

### 4. 120B tool depth is the primary 120B risk

T1 120B run 3 failed because the model used 11 calls exploring and querying before executing. It made all 3 correct assignments but never called `advance_day`. This pattern — "correct work, incomplete finalization" — suggests the tool depth limit (10) is too low for how 120B approaches problems.

### 5. Ollama server 400 remains the dominant 120B failure mode

3/5 T1 120B failures are server 400 (`nil content`). This is not fixable from the client side. The adjusted T1 120B rate excluding infra is 1/2 (50%), not 1/5 (20%).

### 6. Both models generate clean, functional Python

When Python IS executed (not output as text), both models produce correct Monty-compatible code. The captured `[result]` sections confirm correct return values from host functions. The Monty bridge and host function wiring are solid.

## Data Files

All raw data is in `/tmp/construction-eval-v3/run{1-5}/`. Each file contains:

- Room ID, tier, model, duration
- Verdict with per-check OK/FAIL detail
- LLM result text (full answer)
- All tool calls with `[code]` and `[result]` sections
- Final schedule state
- Conflict detection results
- Completed job list
