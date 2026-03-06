#!/usr/bin/env zsh
# Experiment runner: control (direct code) + 120b + 20b for each pattern.
#
# Usage:
#   ./run.sh [pattern_number] [group]
#   ./run.sh 01              # run pattern 01, all groups
#   ./run.sh 01 control      # run pattern 01, control only
#   ./run.sh 01 120b         # run pattern 01, 120b only
#   ./run.sh all             # run everything
#   ./run.sh 13-18 120b      # run new hard patterns, 120b only
#
# After a run, extract generated code:
#   ./run.sh extract <timestamp>
#
# Prerequisites:
#   - Backend running: soliplex-cli serve example/minimal.yaml --no-auth-mode
#   - Run from packages/soliplex_cli/ (or docs/experiments/round2-agentic-kernel/)

set -euo pipefail

SCRIPT_DIR="${0:a:h}"
# Support running from either location
if [[ -d "$SCRIPT_DIR/../../packages/soliplex_cli" ]]; then
  CLI_DIR="$SCRIPT_DIR/../../packages/soliplex_cli"
else
  CLI_DIR="${SCRIPT_DIR:h}"
fi
RESULTS_DIR="$SCRIPT_DIR/results"
CONTROL_DIR="$SCRIPT_DIR/control"
CODEGEN_DIR="$SCRIPT_DIR/codegen"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

HOST="${SOLIPLEX_BASE_URL:-http://localhost:8000}"
TIMEOUT=180  # seconds

mkdir -p "$RESULTS_DIR" "$CODEGEN_DIR"

# ── Guided-goal prompts (zsh associative array) ─────────────────────────

typeset -A PROMPTS

# Patterns 01-12: Original suite
PROMPTS[01]="Use spawn_agent('plain', 'say hello') and spawn_agent('plain', 'say goodbye') to create 2 workers. Poll each with agent_status(handle) in a while loop with sleep(500). When status is 'completed', call get_result(handle). Print both results."
PROMPTS[02]="Use spawn_agent('plain', 'What is 2+2? Reply just the number.') and spawn_agent('plain', 'What is 3+3? Reply just the number.'). Poll with agent_status(handle) + sleep(500) until 'completed'. Call get_result(handle) for each. Then blackboard_write('r1', result1) and blackboard_write('r2', result2). Read them back with blackboard_read('r1') and print."
PROMPTS[03]="Retry loop: for attempt in range(3), call spawn_agent('plain', 'Say success'). Poll with agent_status(handle) + sleep(500). If agent_status returns 'completed', call get_result(handle), print it, and break. If 'failed', call cancel_agent(handle) and continue to next attempt."
PROMPTS[04]="Call spawn_agent('plain', 'Write a haiku about the sea'). Bounded poll: for i in range(60), call agent_status(handle), if 'completed' break, else sleep(500). If completed, print get_result(handle) and the poll count. If still running after 60 polls, call cancel_agent(handle) and print 'timeout'."
PROMPTS[05]="Call spawn_agent('plain', 'Say alpha'), spawn_agent('plain', 'Say beta'), spawn_agent('plain', 'Say gamma'). Poll each handle: for i in range(60), agent_status(h) + sleep(500), break on terminal state. Classify each as success/failure/timeout. Call cancel_agent on timeouts. Use blackboard_write('successes', count). Print all results."
PROMPTS[06]="Call spawn_agent('plain', 'Summarize: the sky is blue and water is wet'). Poll with agent_status(handle) + sleep(500) up to 120 times. When completed, call get_result(handle). Then blackboard_write('l2_result', result). Print the result."
PROMPTS[07]="Call h1 = spawn_agent('plain', 'Say alpha'), h2 = spawn_agent('plain', 'Say beta'), h3 = spawn_agent('plain', 'Say gamma'). Then call results = wait_all([h1, h2, h3]). Print results. Write each to blackboard: blackboard_write('batch_0', results[0]), etc."
PROMPTS[08]="Call h1 = spawn_agent('plain', 'Say hello'), h2 = spawn_agent('plain', 'Say goodbye'). For each handle, call agent_watch(handle). Check the returned dict: if status is 'success', print output and blackboard_write the result. If 'failed', print the reason. If 'timed_out', call cancel_agent(handle)."
PROMPTS[09]="Call r1 = ask_llm('What is 2+2? Reply just the number.', room='plain'). Print r1['text'] and r1['thread_id']. Then call r2 = ask_llm('Multiply that by 3. Reply just the number.', room='plain', thread_id=r1['thread_id']). Print r2['text']. Then blackboard_write('conversation', r2['text'])."
PROMPTS[10]="Call resp = fetch('http://localhost:8000/api/ok'). Print resp['status'] and resp['body']. Then call summary = ask_llm('Summarize: status=' + str(resp['status']) + ' body=' + resp['body'], room='plain'). Print summary['text']. blackboard_write('api_summary', summary['text'])."
PROMPTS[11]="Map phase: call h0 = spawn_agent('plain', 'Name one planet. Reply just the name.'), h1 = spawn_agent('plain', 'Name one ocean. Reply just the name.'), h2 = spawn_agent('plain', 'Name one continent. Reply just the name.'). Poll each with agent_status + sleep(500). Call get_result for completed ones. blackboard_write('answer_0', r0), etc. Reduce: read all with blackboard_read, join with '; ', print."
PROMPTS[12]="Call r1 = ask_llm('Remember this word: elephant. Just say OK.', room='plain'). Print r1['text']. Call r2 = ask_llm('What word did I ask you to remember? Reply just the word.', room='plain', thread_id=r1['thread_id']). Print r2['text']. Call r3 = ask_llm('Spell that word backwards.', room='plain', thread_id=r1['thread_id']). Print r3['text']. blackboard_write('recall', r2['text'])."

# Patterns 13-18: Harder patterns (push 120b ceiling)
PROMPTS[13]="Conditional fan-out: Call r = ask_llm(\"Is 7 even or odd? Reply just 'even' or 'odd'.\", room='plain'). Print the answer. If the answer contains 'odd', call spawn_agent('plain', 'Name 3 odd numbers, comma-separated') and spawn_agent('plain', 'What is 7*3? Just the number.'). If 'even', spawn different workers asking about even numbers. Use wait_all to collect results. Print both results. blackboard_write('classification', answer) and blackboard_write('worker_results', results)."
PROMPTS[14]="Iterative refinement: Spawn a worker in 'plain' asking 'Write a one-sentence fun fact about dolphins.' Use agent_watch(h, timeout_seconds=30). Check len() of the output. If less than 20 characters, spawn again with a longer prompt. Repeat up to 3 times. Print each attempt with its length. When satisfied (len >= 20), blackboard_write('dolphin_fact', result) and stop."
PROMPTS[15]="Sequential pipeline: Step 1: call ask_llm('List 5 countries and populations in millions, format: country:number, one per line.', room='plain'). Print the raw data. blackboard_write('raw_data', data). Step 2: call ask_llm('Given this data: ' + raw_data + ' Which country has the largest population? Just the name.', room='plain'). Print the answer. blackboard_write('largest', answer). Step 3: call spawn_agent('plain', 'Tell me one fact about ' + largest + '. One sentence.'). Use agent_watch. Print the fact. blackboard_write('fact', fact). Print blackboard_keys()."
PROMPTS[16]="Race pattern: Call spawn_agent('plain', 'Count 1 to 5, just numbers'), spawn_agent('plain', 'Name 4 seasons, just names'), spawn_agent('plain', 'List 3 primary colors, just colors'). Poll all handles in a loop with sleep(300). As soon as ANY agent_status returns 'completed', that handle wins. Call get_result on the winner. Call cancel_agent on all other handles. Print winner handle, result, and how many polls it took. blackboard_write('winner_result', result)."
PROMPTS[17]="Blackboard accumulator: For each topic in ['math', 'science', 'history'], spawn_agent('plain', 'Write one trivia question about ' + topic + '. Just the question.'). Use agent_watch for each. blackboard_write('question_0', result), etc. After all 3, read questions from blackboard with blackboard_read, build a numbered quiz string. Call ask_llm('Answer these: ' + quiz, room='plain'). Print quiz and answers. blackboard_write('answers', response)."
PROMPTS[18]="Dynamic worker count: Call r = ask_llm('Pick a number between 2 and 5. Reply with just the digit.', room='plain'). Parse the digit. Spawn that many workers using spawn_agent('plain', 'Say item_N') in a loop. Collect all with wait_all(handles). Print results count and each result. Verify len(results) matches the number. blackboard_write('worker_count', count) and blackboard_write('results', results)."

# ── Helpers ─────────────────────────────────────────────────────────────

run_control() {
  local pattern=$1
  local outfile="$RESULTS_DIR/${TIMESTAMP}_${pattern}_control.log"

  local file
  file=$(ls "$CONTROL_DIR"/${pattern}_*.py 2>/dev/null | head -1)
  if [[ -z "$file" ]]; then
    echo "  SKIP: no control file for $pattern"
    return
  fi

  local code
  code=$(<"$file")

  echo "  CONTROL: $pattern → $outfile"
  cd "$CLI_DIR"
  gtimeout "$TIMEOUT" dart run bin/soliplex_cli.dart \
    --monty --room spike-120b -v \
    --prompt "Execute this exact Python code using execute_python. Do not modify it:

$code" \
    > "$outfile" 2>&1 || true
}

run_model() {
  local pattern=$1
  local room=$2
  local label=$3
  local outfile="$RESULTS_DIR/${TIMESTAMP}_${pattern}_${label}.log"
  local prompt="${PROMPTS[$pattern]}"

  if [[ -z "$prompt" ]]; then
    echo "  SKIP: no prompt for $pattern"
    return
  fi

  echo "  ${label:u}: $pattern → $outfile"
  cd "$CLI_DIR"
  gtimeout "$TIMEOUT" dart run bin/soliplex_cli.dart \
    --monty --room "$room" -v \
    --prompt "$prompt" \
    > "$outfile" 2>&1 || true
}

run_pattern() {
  local pattern=$1
  local group="${2:-all}"

  echo "── Pattern $pattern ──"

  case "$group" in
    control) run_control "$pattern" ;;
    120b)    run_model "$pattern" spike-120b 120b ;;
    20b)     run_model "$pattern" spike-20b 20b ;;
    all)
      run_control "$pattern"
      run_model "$pattern" spike-120b 120b
      run_model "$pattern" spike-20b 20b
      ;;
    *) echo "Unknown group: $group (use control|120b|20b|all)" ;;
  esac
}

# ── Extract generated code from logs ────────────────────────────────────

extract_codegen() {
  local ts="$1"
  local outdir="$CODEGEN_DIR/$ts"
  mkdir -p "$outdir"

  echo "Extracting generated code from $ts logs..."

  for logfile in "$RESULTS_DIR"/${ts}_*.log; do
    [[ -f "$logfile" ]] || continue
    local base=$(basename "$logfile" .log)

    # Extract all code blocks from tool call args
    grep -o 'args={"code":"[^}]*"}' "$logfile" 2>/dev/null | while IFS= read -r line; do
      # Pull just the code value between "code":" and "}
      local code=$(echo "$line" | sed 's/^args={"code":"//; s/"}$//')
      # Unescape \n to actual newlines
      echo "$code" | sed 's/\\n/\n/g; s/\\t/\t/g; s/\\"/"/g'
      echo ""
      echo "# --- next tool call ---"
      echo ""
    done > "$outdir/${base}.py" 2>/dev/null

    if [[ -s "$outdir/${base}.py" ]]; then
      echo "  $base → ${base}.py"
    else
      rm -f "$outdir/${base}.py"
    fi
  done

  echo "Codegen extracted to: $outdir/"
}

# ── Summary ─────────────────────────────────────────────────────────────

summarize() {
  local ts="$1"
  echo ""
  echo "=== Summary for $ts ==="
  echo ""
  printf "%-8s %-10s %-8s %s\n" "Pattern" "Group" "Status" "Notes"
  printf "%-8s %-10s %-8s %s\n" "-------" "-----" "------" "-----"

  for logfile in "$RESULTS_DIR"/${ts}_*.log; do
    [[ -f "$logfile" ]] || continue
    local base=$(basename "$logfile" .log)
    local pattern=$(echo "$base" | sed "s/${ts}_//" | cut -d_ -f1)
    local group=$(echo "$base" | sed "s/${ts}_//" | cut -d_ -f2-)

    local status="?"
    local notes=""

    if grep -q "SUCCESS:" "$logfile" 2>/dev/null; then
      status="PASS"
      # Count tool calls
      local tools=$(grep -c "tool=execute_python" "$logfile" 2>/dev/null || echo 0)
      notes="tools=$tools"
    elif grep -q "FAILED.*serverError" "$logfile" 2>/dev/null; then
      status="BACKEND"
      notes=$(grep "FAILED" "$logfile" 2>/dev/null | head -1 | sed 's/.*FAILED.*: //' | head -c 60)
    elif grep -q "FAILED" "$logfile" 2>/dev/null; then
      status="FAIL"
      notes=$(grep "FAILED" "$logfile" 2>/dev/null | head -1 | sed 's/.*FAILED.*: //' | head -c 60)
    elif grep -q "Bad state:" "$logfile" 2>/dev/null; then
      status="ERROR"
      notes=$(grep "Bad state:" "$logfile" 2>/dev/null | tail -1 | sed 's/.*Bad state: //' | head -c 60)
    fi

    # Check for namespace pollution
    if grep -q 'AGENT\.\|BLACKBOARD\.\|PLATFORM\.' "$logfile" 2>/dev/null; then
      notes="$notes [NAMESPACE]"
    fi

    printf "%-8s %-10s %-8s %s\n" "$pattern" "$group" "$status" "$notes"
  done
}

# ── Main ────────────────────────────────────────────────────────────────

PATTERN="${1:-all}"
GROUP="${2:-all}"

# Special commands
if [[ "$PATTERN" == "extract" ]]; then
  extract_codegen "${GROUP}"
  exit 0
fi

if [[ "$PATTERN" == "summary" ]]; then
  summarize "${GROUP}"
  exit 0
fi

ALL_PATTERNS=(01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18)

if [[ "$PATTERN" == "all" ]]; then
  for p in "${ALL_PATTERNS[@]}"; do
    run_pattern "$p" "$GROUP"
  done
elif [[ "$PATTERN" == "01-12" ]]; then
  for p in 01 02 03 04 05 06 07 08 09 10 11 12; do
    run_pattern "$p" "$GROUP"
  done
elif [[ "$PATTERN" == "13-18" ]]; then
  for p in 13 14 15 16 17 18; do
    run_pattern "$p" "$GROUP"
  done
else
  run_pattern "$PATTERN" "$GROUP"
fi

echo ""
echo "Results in: $RESULTS_DIR/"
echo "Timestamp: $TIMESTAMP"

# Auto-summarize
summarize "$TIMESTAMP"

# Auto-extract codegen
extract_codegen "$TIMESTAMP"
