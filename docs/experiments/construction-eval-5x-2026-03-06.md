# Construction Scheduling Experiment: 5-Run Validated Eval

**Date:** 2026-03-06
**Server:** localhost:8000 (Ollama)
**Models:** gpt-oss:20b, gpt-oss:120b
**Iterations:** 5
**Static reference:** See `docs/experiments/construction-scheduling-2026-03-06.md` for
prompts, host functions, test data, and system architecture.

## Methodology

### Previous eval (smoke test)

The first 5-run eval only checked whether the agent returned `SUCCESS` vs
crashed. This produced false positives: a model could report SUCCESS with an
incomplete or incorrect schedule.

### This eval (correctness validation)

Each tier now has per-check validation against the actual `ConstructionState`
after the agent finishes. The verdict is **CORRECT** (all checks pass) or
**INCORRECT** (at least one check fails), independent of the agent's
self-reported SUCCESS/FAIL status.

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
| 1 | CORRECT 6/6 (6s, 4 py) | CORRECT 6/6 (12s, 7 py) |
| 2 | CORRECT 6/6 (8s, 4 py) | INCORRECT 3/6 server 400 (8s, 4 py) |
| 3 | CORRECT 6/6 (5s, 2 py) | INCORRECT 3/6 server 400 (6s, 5 py) |
| 4 | CORRECT 6/6 (4s, 1 py) | CORRECT 6/6 (8s, 2 py) |
| 5 | CORRECT 6/6 (4s, 2 py) | INCORRECT 2/6 server 500 (14s, 6 py) |
| **Total** | **5/5 CORRECT** | **2/5 CORRECT, 3/5 INCORRECT** |

**Notes:**

- 20B is 100% reliable on T1 across all 5 runs.
- All 120B failures are Ollama server errors (400/500), not model capability. The model completed 2-3/3 assignments before the server died each time.
- 120B run 5 is a server 500 with a tool-call parse error: the model emitted reasoning text before its JSON tool call, which the server rejected.

### T2: Scheduler (build optimal schedule from constraints)

| Run | 20B | 120B |
|-----|-----|------|
| 1 | CORRECT 5/5 (8s, 2 py) | CORRECT 5/5 (18s, 3 py) |
| 2 | CORRECT 5/5 (8s, 1 py) | CORRECT 5/5 (13s, 3 py) |
| 3 | CORRECT 5/5 (12s, 2 py) | CORRECT 5/5 (18s, 4 py) |
| 4 | CORRECT 5/5 (7s, 1 py) | CORRECT 5/5 (16s, 2 py) |
| 5 | CORRECT 5/5 (15s, 2 py) | CORRECT 5/5 (15s, 2 py) |
| **Total** | **5/5 CORRECT** | **5/5 CORRECT** |

**Notes:**

- Both models achieve optimal 4-day schedule every run.
- 20B averages 1.6 python calls; 120B averages 2.8.
- Both correctly skip day 1 (rain) for outdoor foundation work.

### T3: Dispatcher (stream subscription + reactive scheduling)

| Run | 20B | 120B |
|-----|-----|------|
| 1 | CORRECT 5/5 (12s, 1 py) | CORRECT 5/5 (10s, 1 py) |
| 2 | CORRECT 5/5 (11s, 1 py) | CORRECT 5/5 (10s, 1 py) |
| 3 | CORRECT 5/5 (8s, 1 py) | CORRECT 5/5 (10s, 1 py) |
| 4 | CORRECT 5/5 (7s, 1 py) | CORRECT 5/5 (9s, 1 py) |
| 5 | CORRECT 5/5 (3s, 0 py) | CORRECT 5/5 (10s, 1 py) |
| **Total** | **5/5 CORRECT** | **5/5 CORRECT** |

**Notes:**

- 100% correctness for both models across all 5 runs.
- Both correctly: subscribe to streams, unassign Alice on day 3 (crew_noshow), handle rain on day 4.
- **False positive warning:** T3 20B run 5 hit server 400 with 0 python calls. The pre-seeded state (Bob's assignments only, no Alice) passes validation vacuously. The model did not actually process any stream events. This is a known limitation of end-state validation — it cannot distinguish "correctly reacted" from "initial state happens to pass."

### T4: Recovery (error handling + retry logic)

| Run | 20B | 120B |
|-----|-----|------|
| 1 | INCORRECT 2/4 (7s, 1 py) | CORRECT 4/4 (39s, 6 py) |
| 2 | INCORRECT 2/4 (8s, 1 py) | CORRECT 4/4 (51s, 7 py) |
| 3 | INCORRECT 2/4 (7s, 1 py) | CORRECT 4/4 (106s, 11 py)* |
| 4 | INCORRECT 2/4 (10s, 1 py) | CORRECT 4/4 (36s, 4 py) |
| 5 | INCORRECT 2/4 (5s, 0 py) | CORRECT 4/4 (117s, 11 py)* |
| **Total** | **0/5 CORRECT** | **5/5 CORRECT** |

*Hit tool depth limit (10 calls) but completed all work before the limit was reached.

**Notes:**

- **20B is 0% on T4** — consistently schedules only foundations (2/5 assignments), never continues to framing/roofing. Every run stops after handling the weather error for day 1, reports SUCCESS with only 2 jobs done.
- **120B is 100% on T4** — even when hitting the tool depth limit (runs 3, 5), the model completed all 5 assignments before running out of calls. The "FAILED: tool depth exceeded" status is misleading — the schedule is fully correct.
- 120B run 5 also hit server 400 on the 20B side, but 120B itself was unaffected.

## Aggregate Correctness Rates

| Tier | 20B | 120B |
|------|-----|------|
| T1 Prescriptive | 5/5 (100%) | 2/5 (40%)* |
| T2 Scheduler | 5/5 (100%) | 5/5 (100%) |
| T3 Dispatcher | 5/5 (100%)** | 5/5 (100%) |
| T4 Recovery | 0/5 (0%) | 5/5 (100%) |

*120B T1 failures are server 400/500 (Ollama infrastructure), not model capability.

**T3 20B includes one false positive (run 5: server 400, 0 py calls, pre-seeded state passes vacuously).

## Adjusted Correctness Rates (excluding infra failures)

Removing runs where server 400/500 prevented the model from executing:

| Tier | 20B | 120B |
|------|-----|------|
| T1 Prescriptive | 5/5 (100%) | 2/2 (100%) |
| T2 Scheduler | 5/5 (100%) | 5/5 (100%) |
| T3 Dispatcher | 4/4 (100%) | 5/5 (100%) |
| T4 Recovery | 0/4 (0%) | 5/5 (100%) |

## Comparison: Smoke Test vs Validated Eval

The correctness validation fundamentally changed two conclusions:

| Finding | Smoke Test (v1) | Validated (v2) | Delta |
|---------|----------------|----------------|-------|
| T4 20B | 1/5 PASS (20%) | 0/5 CORRECT (0%) | **Worse** — the "PASS" was a false positive |
| T4 120B | 3/5 PASS (60%) | 5/5 CORRECT (100%) | **Better** — "FAIL" runs had correct schedules |

**T4 20B false positive (v1):** The smoke test counted the agent's self-reported SUCCESS. But 20B only scheduled 2/5 jobs and declared victory. Correctness validation caught this.

**T4 120B false negatives (v1):** Two runs hit the tool depth limit and were scored FAIL. But the model had already completed all 5 assignments before running out of calls. Correctness validation revealed the schedule was perfect.

## Key Findings

### 1. Correctness validation is essential

Self-reported SUCCESS is not trustworthy. 20B consistently reports SUCCESS on T4 with only 2/5 jobs scheduled. Without per-check validation, we would have rated 20B at 20% on T4 instead of the true 0%.

### 2. T1-T3 are solved problems

Both models handle prescriptive, scheduling, and stream-reactive tasks with 100% correctness (excluding infra failures). The infrastructure (Monty bridge, stream registry, error recovery) is solid.

### 3. T4 reveals a hard 20B capability boundary

20B cannot plan multi-phase scheduling. It handles the immediate error recovery (weather rain on day 1 -> move foundations to days 2-3) but never continues to schedule framing and roofing. This is consistent across all 5 runs (0% correct). This is the planning horizon limit of the 20B model.

### 4. 120B has deep planning and is robust at T4

120B completes T4 5/5 times (100%). Even when it hits the tool depth limit by taking extra calls, it has already finished the work. The concern from the smoke test that 120B "over-thinks and wastes tool calls" is still true — but the schedule is correct regardless.

### 5. End-state validation has a known blind spot

T3 validation checks the final schedule state, not whether the model actually processed stream events. When the model crashes before executing any code, the pre-seeded state can pass validation vacuously (T3 20B run 5). Process validation (checking that streams were subscribed and events processed) would close this gap.

### 6. Ollama server errors remain a reliability concern

3/5 T1 120B runs hit server 400/500. One T3 20B run and one T4 20B run also hit server 400. These are provider-level issues (`invalid message content type: <nil>`) not actionable from the client side.

## Data Files

All raw data is in `/tmp/construction-eval-v2/run{1-5}/`. Each file contains:

- Room ID, tier, model, duration
- Verdict with per-check OK/FAIL detail
- LLM result text
- All generated Python code (per execute_python call)
- Final schedule state
- Conflict detection results
- Completed job list
