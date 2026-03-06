# SoliplexKernel Experiment Inventory

Two rounds of experiments validating that small local LLMs (20B, 120B) can generate
correct Python code for our sandboxed interpreter (Monty). Each round tests a different
host function surface area.

---

## Round 1: DataFrame Pipelines

**Branch:** `feat/soliplex-cli-monty` on [runyaga/soliplex](https://github.com/runyaga/soliplex/tree/feat/soliplex-cli-monty)
**Overview doc:** `example/spike-prompts/OVERVIEW.md`
**Evaluation prompts:** `example/spike-prompts/evaluation-prompts.md`
**System prompt:** `example/rooms/spike-120b/prompt.txt`
**Full results:** [runyaga/flutter#66](https://github.com/runyaga/flutter/pull/66)

### Host Functions Under Test

```text
df_create(data_list) -> handle
df_filter(handle, col, op, value) -> handle
df_sort(handle, col, ascending) -> handle
df_group_agg(handle, cols, agg_map) -> handle
df_merge(h1, h2, on_cols, how) -> handle
df_rename(handle, mapping) -> handle
df_add_column(handle, name, values) -> handle
df_head(handle, n) -> list of dicts
df_to_list(handle) -> list of dicts
chart_create(config) -> handle
+ 17 more (df_mean, df_std, df_nlargest, df_unique, etc.)
```

### Experiment Types (9)

| # | Experiment | What It Tests | 20B | 120B |
|---|-----------|--------------|-----|------|
| 0a | Baseline 6-step | create/filter/group/sort/chart pipeline | 90% | 100% |
| 0b | Parameter extraction | NL → structured args (pure Python) | 100% | 100% |
| 1a | Multi-source merge | two datasets, join, compute | 83% | 100% |
| 1b | Ambiguous intent | vague 3-word prompts | 100% | 50% |
| 1c | Math formulas | std dev, variance by group | 100% | 100% |
| 2 | String processing | word frequency, top-N | 67% | 100% |
| 3 | Schema mismatch | mismatched keys, rename+merge | 40% | 100% |
| 4 | Conditional logic | Fibonacci, grade calculator (pure Python) | 100% | 100% |
| 5 | 10+ step pipeline | full ETL in one shot | 60% | 100% |

**71 total trials.** 20B: 84% pass. 120B: 93% pass.

### Key Findings (Round 1)

1. **Enumerating every function with parameter types** in the system prompt was the single highest-impact change
2. Larger models need MORE documentation, not less — 120B hallucinated Pandas-like functions when docs were incomplete
3. "NOT Supported" section listing Monty limitations prevents first-attempt errors
4. Self-correction works — LLM receives error, diagnoses, rewrites (e.g. Fibonacci primes rewrote `summary[cls] += 1`)
5. 20B prefers pure Python; 120B uses host function API more idiomatically

### File Structure (Round 1)

```text
soliplex (backend repo) / feat/soliplex-cli-monty branch:
  example/
    spike-prompts/
      OVERVIEW.md                    # Summary doc (what you linked)
      evaluation-prompts.md          # Exact text for all 9 experiments
      exp_0a_create_inspect.txt      # Individual experiment prompts
      exp_0b_filter_sort_agg.txt
      exp_1a_multipass_create.txt
      exp_1b_multipass_filter.txt
      exp_1c_multipass_aggregate.txt
      exp_4a_merge.txt
    rooms/
      spike-20b/room_config.yaml     # 20B room with system prompt
      spike-120b/room_config.yaml    # 120B room with system prompt
      spike-120b/prompt.txt          # Full system prompt (df_* API docs)
```

---

## Round 2: Soliplex Agentic Kernel

**Branch:** `feat/kernel-experiments` on soliplex-flutter-spike-supervision
**Backend branch:** `pgsql+m7-room-configs` on soliplex (backend)
**Results doc:** `~/dev/soliplex-plans/kernel-stress-results-2026-03-06.md`
**Continuation plan:** `~/dev/soliplex-plans/kernel-experiments-continuation-plan.md`

### Host Functions Under Test

```text
spawn_agent(room, prompt, thread_id=None) -> int
agent_status(handle) -> "spawning"|"running"|"completed"|"failed"|"cancelled"
get_result(handle) -> str
cancel_agent(handle) -> bool
wait_all(handles) -> list of str
agent_watch(handle, timeout_seconds=None) -> {"status":..., ...}
ask_llm(prompt, room="plain", thread_id=None) -> {"text":str, "thread_id":str}
blackboard_write(key, value)
blackboard_read(key) -> value or None
blackboard_keys() -> list
sleep(ms)
fetch(url, method="GET", headers=None, body=None) -> {"status":int, "body":str, ...}
log(message, level="info")
```

### Experiment Types (12 patterns)

| # | Pattern | What It Tests | Primitives Used |
|---|---------|--------------|----------------|
| 01 | Fan-out poll | Spawn N workers, poll until done, collect | spawn_agent, agent_status, get_result, sleep |
| 02 | Blackboard coordination | Spawn, collect, write/read blackboard | spawn_agent, agent_status, get_result, blackboard_write/read |
| 03 | Retry on failure | Retry loop with cancel | spawn_agent, agent_status, get_result, cancel_agent |
| 04 | Timeout + cancel | Bounded poll, cancel on timeout | spawn_agent, agent_status, get_result, cancel_agent, sleep |
| 05 | Mixed outcomes | Classify success/fail/timeout per worker | spawn_agent, agent_status, get_result, cancel_agent, blackboard_write |
| 06 | Nested supervision | Supervisor spawns sub-supervisor | spawn_agent, agent_status, get_result, blackboard_write |
| 07 | wait_all | Block until all workers done | spawn_agent, wait_all, blackboard_write |
| 08 | agent_watch | Event-based monitoring per worker | spawn_agent, agent_watch, cancel_agent, blackboard_write |
| 09 | ask_llm sync | Synchronous LLM call with thread continuation | ask_llm (with thread_id), blackboard_write |
| 10 | fetch + process | HTTP fetch then LLM summarize | fetch, ask_llm, blackboard_write |
| 11 | Map-reduce | Fan-out → collect → reduce via blackboard | spawn_agent, agent_status, get_result, blackboard_write/read, sleep |
| 12 | Multi-turn thread | Multi-turn conversation via thread_id | ask_llm (with thread_id), blackboard_write |

### Three Experiment Groups Per Pattern

| Group | Description | How It Runs |
|-------|-------------|------------|
| **Control** | Hand-written Python (my code) | Fed to 120b with "Execute this exact code" |
| **120b** | gpt-oss:120b generates code from prompt | Natural language prompt → LLM generates code |
| **20b** | gpt-oss:20b generates code from prompt | Same prompt as 120b |

### Results Across Prompt Iterations

| Round | System Prompt | Prompt Style | 120b | 20b |
|-------|--------------|-------------|------|-----|
| R2 (V1) | V1: `AGENT:` / `BLACKBOARD:` / `PLATFORM:` headers | Concise ("Spawn workers") | **0/12** | ~1/12 |
| R4 intermediate | V1 (server not restarted) | V2 guided-goal | 7/12 | ~4/12 |
| **R4 (V2)** | **V2: flat globals, anti-namespace rule** | **V2 guided-goal** | **10/12** | **7/12** |

### Key Findings (Round 2)

1. **Category headers (`AGENT:`, `BLACKBOARD:`) cause namespace hallucination** — 20b generated `AGENT.spawn_agent()` instead of `spawn_agent()`. Flattening to bare globals fixed it completely.
2. **Guided-goal prompts work** — "Call h = spawn_agent('plain', 'say hello')" beats "Spawn a worker"
3. **Anti-namespace rule is essential** — "Do NOT prefix functions with namespaces" in system prompt
4. **120b is production-ready** with V2 prompt — 10/12 first-try correct code, zero namespace errors
5. **20b has residual habits** — still tries `import time` (self-corrects), some backend 400 errors
6. **Remaining blockers are infrastructure, not model** — fetch() needs httpClient, FFI bridge reuse bug, backend 400 errors

### File Structure (Round 2)

```text
soliplex-flutter-spike-supervision / packages/soliplex_cli:
  experiments/
    system_prompt.txt              # V1 system prompt (category headers)
    system_prompt_v2.txt           # V2 system prompt (flat globals)
    run.sh                         # Experiment runner (zsh, V2 guided-goal prompts)
    control/                       # Hand-written reference Python code
      01_fan_out_poll_collect.py
      02_blackboard_coordination.py
      03_retry_on_failure.py
      04_timeout_cancel.py
      05_mixed_outcomes.py
      06_nested_supervision.py
      07_wait_all_batch.py
      08_agent_watch_events.py
      09_ask_llm_sync.py
      10_fetch_and_process.py
      11_map_reduce_blackboard.py
      12_multi_turn_thread.py
    results/                       # Timestamped logs per run
      YYYYMMDD_HHMMSS_NN_control.log
      YYYYMMDD_HHMMSS_NN_120b.log
      YYYYMMDD_HHMMSS_NN_20b.log

soliplex (backend repo):
  example/rooms/
    spike-20b/room_config.yaml     # V2 system prompt (active)
    spike-120b/room_config.yaml    # V2 system prompt (active)
    plain/room_config.yaml         # Worker room (simple assistant)
```

---

## Cross-Round Comparison

| Dimension | Round 1 (DataFrame) | Round 2 (Soliplex Agentic Kernel Supervision) |
|-----------|--------------------|-----------------------------|
| Host function count | ~27 (`df_*` + `chart_create`) | 13 (agentic kernel primitives) |
| Execution model | Single-step code gen | Multi-step: spawn → poll → collect |
| State management | Handle-based (int IDs) | Handle-based + blackboard key-value |
| Concurrency | None (sequential pipeline) | Parallel agents (fan-out, wait_all) |
| Error recovery | Monty retries (up to 10) | cancel_agent, retry loop, bounded poll |
| Inter-agent communication | N/A | blackboard_write/read, ask_llm thread_id |
| 120b pass rate | 93% (71 trials) | 83% (10/12 patterns, V2 prompt) |
| 20b pass rate | 84% (43 trials) | 58% (7/12 patterns, V2 prompt) |
| Dominant failure mode (120b) | Hallucinated Pandas functions | Namespace hallucination (V1), infra gaps (V2) |
| Dominant failure mode (20b) | Schema mismatch, string processing | `import time`, backend 400 errors |
| Critical prompt fix | Enumerate every function with types | Flat globals + anti-namespace rule |

### Shared Lesson

Both rounds prove the same core insight from Round 1's OVERVIEW.md:

> **"Enumerating every available function with parameter types"** in the system prompt
> is the single highest-impact change. Larger models need MORE documentation, not less.

Round 2 adds a corollary:

> **How you organize that documentation matters.** Category headers (`AGENT:`, `BLACKBOARD:`)
> become namespace hallucinations. Flat function lists with explicit "no prefix" rules work.

---

## Next: Agentic Kernel Continuation

See `~/dev/soliplex-plans/kernel-experiments-continuation-plan.md`:
1. Iterate with Gemini on V2 results → create V3 system prompt with few-shot examples
2. Fix infra gaps (httpClient for fetch, log() stub in FakeHostApi)
3. Investigate backend 400 errors hitting 20b
4. Target: 120b 12/12, 20b 10/12
