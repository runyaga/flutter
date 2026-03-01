#!/usr/bin/env bash
# =============================================================================
# Milestone Review — soliplex-flutter
# =============================================================================
# Runs format/analyze/DCM/tests gates, captures metrics delta, generates
# unified diff, and assembles a lean review prompt for Gemini.
# The prompt contains instructions + metrics. Changed source files and the
# diff are passed separately to read_files.
#
# Ported from soliplex-plans/tool/slice_review.sh, adapted for Flutter project
# and soliplex_agent milestones (M1-M7).
#
# Usage:
#   bash tool/milestone_review.sh M1                # full: format + analyze + dcm + tests
#   bash tool/milestone_review.sh M1 --skip-tests   # skip test execution
#   bash tool/milestone_review.sh M1 --skip-analyze # skip flutter analyze
#   bash tool/milestone_review.sh M1 --skip-format  # skip dart format check
#   bash tool/milestone_review.sh M1 --skip-dcm     # skip DCM analysis
#   bash tool/milestone_review.sh M1 --skip-all     # skip all gates
#   bash tool/milestone_review.sh M1 --context path/to/file  # add context file
#   bash tool/milestone_review.sh M1 --plan docs/design/soliplex-agent-package.md
#   bash tool/milestone_review.sh M1 --range abc123..def456  # explicit range
#   bash tool/milestone_review.sh M1 --full          # diff entire branch vs main
#   bash tool/milestone_review.sh M1 --dcm-options PLANS/0008-soliplex-scripting/dcm_options.yaml
#
# Gates (run in order, each can be skipped independently):
#   1. dart format --set-exit-if-changed .
#   2. flutter analyze --fatal-infos
#   3. dcm analyze (with optional --dcm-options override)
#   4. tests (flutter test + dart test per package)
#
# Diff scoping:
#   By default, the script auto-detects the commit range for the given
#   milestone by searching commit messages for "(M<N>)" or "(Milestone <N>)".
#   It diffs between the previous milestone's last commit and this milestone's
#   last commit. Use --range to override. Use --full to diff the entire branch
#   against main (legacy behavior).
#
# Plan auto-detection:
#   Default spec: docs/design/implementation-milestones.md
#   Override with --plan to point at a different spec file.
#
# Output:
#   ci-review/milestone-reviews/M<N>-prompt.md   (review instructions)
#   ci-review/milestone-reviews/M<N>.diff         (unified diff)
# =============================================================================
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

# -------------------------------------------------------
# Argument parsing
# -------------------------------------------------------
if [[ $# -lt 1 ]]; then
  echo "Usage: bash tool/milestone_review.sh <milestone> [options]"
  echo ""
  echo "  Milestones: M1, M2, M3, M4, M5, M6, M7"
  echo ""
  echo "  Options:"
  echo "    --skip-tests       Skip test execution"
  echo "    --skip-analyze     Skip flutter analyze"
  echo "    --skip-format      Skip dart format check"
  echo "    --skip-dcm         Skip DCM analysis"
  echo "    --skip-all         Skip all gates (format/analyze/dcm/tests)"
  echo "    --context <file>   Add context file (repeatable)"
  echo "    --plan <file>      Override spec file"
  echo "    --range BASE..HEAD Explicit diff range"
  echo "    --full             Diff entire branch vs main"
  echo "    --dcm-options <f>  Custom DCM options file"
  exit 1
fi

MILESTONE="$1"
shift

# Extract numeric part (M1 → 1, M7 → 7, etc.)
MILESTONE_NUM="${MILESTONE#M}"
if ! [[ "$MILESTONE_NUM" =~ ^[0-9]+$ ]]; then
  echo "ERROR: Milestone must be M1-M7 (got: $MILESTONE)"
  exit 1
fi

SKIP_TESTS=false
SKIP_ANALYZE=false
SKIP_FORMAT=false
SKIP_DCM=false
CONTEXT_FILES=()
PLAN_OVERRIDE=""
DIFF_RANGE=""
FULL_BRANCH=false
DCM_OPTIONS_OVERRIDE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-tests)   SKIP_TESTS=true ;;
    --skip-analyze) SKIP_ANALYZE=true ;;
    --skip-format)  SKIP_FORMAT=true ;;
    --skip-dcm)     SKIP_DCM=true ;;
    --skip-all)     SKIP_TESTS=true; SKIP_ANALYZE=true; SKIP_FORMAT=true; SKIP_DCM=true ;;
    --context)
      shift
      if [[ $# -eq 0 ]]; then
        echo "ERROR: --context requires a file path argument"
        exit 1
      fi
      if [[ ! -f "$1" ]]; then
        echo "ERROR: context file not found: $1"
        exit 1
      fi
      if [[ "$1" = /* ]]; then
        CONTEXT_FILES+=("$1")
      else
        CONTEXT_FILES+=("$(cd "$(dirname "$1")" && pwd)/$(basename "$1")")
      fi
      ;;
    --plan)
      shift
      if [[ $# -eq 0 ]]; then
        echo "ERROR: --plan requires a file path argument"
        exit 1
      fi
      PLAN_OVERRIDE="$1"
      ;;
    --range)
      shift
      if [[ $# -eq 0 ]]; then
        echo "ERROR: --range requires BASE..HEAD argument"
        exit 1
      fi
      DIFF_RANGE="$1"
      ;;
    --dcm-options)
      shift
      if [[ $# -eq 0 ]]; then
        echo "ERROR: --dcm-options requires a file path argument"
        exit 1
      fi
      DCM_OPTIONS_OVERRIDE="$1"
      ;;
    --full)
      FULL_BRANCH=true
      ;;
    *)
      echo "Unknown flag: $1"
      exit 1
      ;;
  esac
  shift
done

OUTPUT_DIR="$ROOT/ci-review/milestone-reviews"
OUTPUT_FILE="$OUTPUT_DIR/${MILESTONE}-prompt.md"
DIFF_FILE="$OUTPUT_DIR/${MILESTONE}.diff"
BASELINE_FILE="$ROOT/ci-review/baseline.json"

# -------------------------------------------------------
# Plan file resolution
# -------------------------------------------------------
DEFAULT_SPEC="$ROOT/docs/design/implementation-milestones.md"

if [[ -n "$PLAN_OVERRIDE" ]]; then
  if [[ "$PLAN_OVERRIDE" = /* ]]; then
    MILESTONE_PLAN="$PLAN_OVERRIDE"
  else
    MILESTONE_PLAN="$ROOT/$PLAN_OVERRIDE"
  fi
else
  MILESTONE_PLAN="$DEFAULT_SPEC"
fi

if [[ ! -f "$MILESTONE_PLAN" ]]; then
  echo "ERROR: Spec file not found: $MILESTONE_PLAN"
  exit 1
fi

# -------------------------------------------------------
# DCM options resolution
# -------------------------------------------------------
if [[ -n "$DCM_OPTIONS_OVERRIDE" ]]; then
  if [[ "$DCM_OPTIONS_OVERRIDE" = /* ]]; then
    DCM_OPTIONS_FILE="$DCM_OPTIONS_OVERRIDE"
  else
    DCM_OPTIONS_FILE="$ROOT/$DCM_OPTIONS_OVERRIDE"
  fi
else
  DCM_OPTIONS_FILE="$ROOT/dcm_options.yaml"
fi

mkdir -p "$OUTPUT_DIR"

echo "=== Milestone Review: $MILESTONE ==="
echo "  Plan:    $MILESTONE_PLAN"
echo "  DCM:     $DCM_OPTIONS_FILE"
echo "  Output:  $OUTPUT_DIR"

if ! command -v jq &>/dev/null; then
  echo "ERROR: jq is required but not installed"
  exit 1
fi

# -------------------------------------------------------
# Tempfiles — cleaned on exit
# -------------------------------------------------------
METRICS_AFTER=$(mktemp)
ANALYZE_OUTPUT=$(mktemp)
TEST_OUTPUT=$(mktemp)
FORMAT_OUTPUT=$(mktemp)
DCM_OUTPUT=$(mktemp)
trap 'rm -f "$METRICS_AFTER" "$ANALYZE_OUTPUT" "$TEST_OUTPUT" "$FORMAT_OUTPUT" "$DCM_OUTPUT"' EXIT

# -------------------------------------------------------
# Phase 1: dart format check (unless --skip-format)
# -------------------------------------------------------
if [[ "$SKIP_FORMAT" == false ]]; then
  echo "=== Phase 1: Checking dart format ==="
  set +e
  dart format --set-exit-if-changed . > "$FORMAT_OUTPUT" 2>&1
  FORMAT_EXIT=$?
  set -e
  if [[ $FORMAT_EXIT -eq 0 ]]; then
    FORMAT_STATUS="PASSED"
    FORMAT_SUMMARY="All files formatted correctly."
  else
    FORMAT_STATUS="FAILED (exit $FORMAT_EXIT)"
    FORMAT_SUMMARY="$(tail -20 "$FORMAT_OUTPUT")"
  fi
else
  echo "=== Phase 1: SKIPPED (--skip-format) ==="
  FORMAT_STATUS="SKIPPED"
  FORMAT_SUMMARY="(format check skipped via --skip-format)"
fi

# -------------------------------------------------------
# Phase 2: Run flutter analyze (unless --skip-analyze)
# -------------------------------------------------------
if [[ "$SKIP_ANALYZE" == false ]]; then
  echo "=== Phase 2: Running flutter analyze ==="
  set +e
  flutter analyze --fatal-infos > "$ANALYZE_OUTPUT" 2>&1
  ANALYZE_EXIT=$?
  set -e
  if [[ $ANALYZE_EXIT -eq 0 ]]; then
    ANALYZE_STATUS="PASSED"
    ANALYZE_SUMMARY="No issues found."
  else
    ANALYZE_STATUS="FAILED (exit $ANALYZE_EXIT)"
    ANALYZE_SUMMARY="$(tail -20 "$ANALYZE_OUTPUT")"
  fi
else
  echo "=== Phase 2: SKIPPED (--skip-analyze) ==="
  ANALYZE_STATUS="SKIPPED"
  ANALYZE_SUMMARY="(analyze skipped via --skip-analyze)"
fi

# -------------------------------------------------------
# Phase 3: DCM analyze (unless --skip-dcm)
# -------------------------------------------------------
if [[ "$SKIP_DCM" == false ]]; then
  echo "=== Phase 3: Running DCM analyze ==="
  if ! command -v dcm &>/dev/null; then
    echo "  WARNING: dcm not found in PATH — skipping"
    DCM_STATUS="NOT INSTALLED"
    DCM_SUMMARY="dcm binary not found. Install: https://dcm.dev/docs/getting-started/"
  else
    set +e
    DCM_ARGS=("analyze" "." "--options" "$DCM_OPTIONS_FILE")
    dcm "${DCM_ARGS[@]}" > "$DCM_OUTPUT" 2>&1
    DCM_EXIT=$?
    set -e

    # Count violations from DCM output
    DCM_VIOLATIONS=$(grep -cE '(WARNING|ERROR|STYLE)' "$DCM_OUTPUT" 2>/dev/null || echo "0")

    if [[ $DCM_EXIT -eq 0 && "$DCM_VIOLATIONS" -eq 0 ]]; then
      DCM_STATUS="PASSED"
      DCM_SUMMARY="No violations found (options: $(basename "$DCM_OPTIONS_FILE"))."
    elif [[ $DCM_EXIT -eq 0 ]]; then
      DCM_STATUS="WARNINGS ($DCM_VIOLATIONS)"
      DCM_SUMMARY="$(tail -30 "$DCM_OUTPUT")"
    else
      DCM_STATUS="FAILED (exit $DCM_EXIT, $DCM_VIOLATIONS violations)"
      DCM_SUMMARY="$(tail -30 "$DCM_OUTPUT")"
    fi
  fi
else
  echo "=== Phase 3: SKIPPED (--skip-dcm) ==="
  DCM_STATUS="SKIPPED"
  DCM_SUMMARY="(DCM analysis skipped via --skip-dcm)"
fi

# -------------------------------------------------------
# Phase 4: Run tests (unless --skip-tests)
# -------------------------------------------------------
if [[ "$SKIP_TESTS" == false ]]; then
  echo "=== Phase 4: Running tests ==="
  set +e

  # Root-level tests
  flutter test > "$TEST_OUTPUT" 2>&1
  ROOT_EXIT=$?

  # Package tests (dart test for pure Dart packages, flutter test for Flutter)
  PKG_EXIT=0
  for pkg_dir in packages/*/; do
    if [[ -d "$pkg_dir/test" ]]; then
      pkg_name=$(basename "$pkg_dir")
      echo "  Testing $pkg_name..."
      if grep -q "flutter:" "$pkg_dir/pubspec.yaml" 2>/dev/null; then
        (cd "$pkg_dir" && flutter test 2>&1 | tail -3)
      else
        (cd "$pkg_dir" && dart test 2>&1 | tail -3)
      fi
      if [[ ${PIPESTATUS[0]} -ne 0 ]]; then PKG_EXIT=1; fi
    fi
  done

  set -e
  if [[ $ROOT_EXIT -ne 0 || $PKG_EXIT -ne 0 ]]; then
    TEST_STATUS="FAILED"
    TEST_SUMMARY="Test failures detected. Tail of root test output:

$(tail -20 "$TEST_OUTPUT")"
  else
    TEST_STATUS="PASSED"
    TEST_SUMMARY="$(tail -5 "$TEST_OUTPUT")"
  fi
else
  echo "=== Phase 4: SKIPPED (--skip-tests) ==="
  TEST_STATUS="SKIPPED"
  TEST_SUMMARY="(tests skipped via --skip-tests)"
fi

# -------------------------------------------------------
# Phase 5: Capture metrics
# -------------------------------------------------------
echo "=== Phase 5: Capturing metrics ==="

# Create baseline if it doesn't exist
if [[ ! -f "$BASELINE_FILE" ]]; then
  echo "  No baseline found — capturing now"
  mkdir -p "$(dirname "$BASELINE_FILE")"
fi

capture_pkg_metrics() {
  local pkg_name="$1"
  local pkg_dir="$2"
  local src_lines=0
  local test_lines=0
  local test_count=0

  if [[ -d "$pkg_dir/lib" ]]; then
    src_lines=$(find "$pkg_dir/lib" -name '*.dart' -exec cat {} + 2>/dev/null | wc -l | tr -d ' ')
  fi
  if [[ -d "$pkg_dir/test" ]]; then
    test_lines=$(find "$pkg_dir/test" -name '*.dart' -exec cat {} + 2>/dev/null | wc -l | tr -d ' ')
    test_count=$(grep -r 'test(' "$pkg_dir/test" --include='*.dart' -l 2>/dev/null | wc -l | tr -d ' ')
  fi

  echo "    \"$pkg_name\": {\"source_lines\": $src_lines, \"test_lines\": $test_lines, \"test_count\": $test_count}"
}

generate_metrics() {
  echo "{"
  echo "  \"git_sha\": \"$(git rev-parse --short HEAD)\","
  echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
  echo "  \"packages\": {"

  local first=true

  # Root lib/
  capture_pkg_metrics "soliplex_app" "."
  first=false

  for pkg_dir in packages/*/; do
    [[ ! -d "$pkg_dir" ]] && continue
    local pkg_name
    pkg_name=$(basename "$pkg_dir")
    echo ","
    capture_pkg_metrics "$pkg_name" "$pkg_dir"
  done

  echo ""
  echo "  }"
  echo "}"
}

generate_metrics > "$METRICS_AFTER"

# -------------------------------------------------------
# Phase 6: Determine diff range + collect git data
# -------------------------------------------------------
echo "=== Phase 6: Collecting git data ==="
GIT_SHA=$(git rev-parse --short HEAD)
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
GIT_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Determine the upstream base ref (prefer origin/main over local main)
BASE_REF=""
if git rev-parse --verify origin/main &>/dev/null; then
  BASE_REF="origin/main"
elif git rev-parse --verify main &>/dev/null; then
  BASE_REF="main"
fi

# Compute merge-base using upstream ref (not local main, which may be HEAD)
MERGE_BASE=""
if [[ -n "$BASE_REF" ]]; then
  MERGE_BASE=$(git merge-base "$BASE_REF" HEAD 2>/dev/null || echo "")
  # If merge-base equals HEAD (we're on main, ahead of origin), use BASE_REF directly
  if [[ "$MERGE_BASE" == "$(git rev-parse HEAD)" && "$BASE_REF" == "origin/main" ]]; then
    MERGE_BASE=$(git rev-parse origin/main 2>/dev/null || echo "")
  fi
fi

# Generate baseline from merge-base if missing or stale
if [[ ! -f "$BASELINE_FILE" ]]; then
  cp "$METRICS_AFTER" "$BASELINE_FILE"
  echo "  Baseline initialized from current state"
elif [[ -n "$MERGE_BASE" ]]; then
  BASELINE_SHA=$(jq -r '.git_sha // ""' "$BASELINE_FILE" 2>/dev/null || echo "")
  MERGE_BASE_SHORT=$(git rev-parse --short "$MERGE_BASE")
  if [[ "$BASELINE_SHA" != "$MERGE_BASE_SHORT" && "$BASELINE_SHA" != "$(git rev-parse --short HEAD)" ]]; then
    echo "  Baseline SHA ($BASELINE_SHA) differs from merge-base ($MERGE_BASE_SHORT)"
  fi
fi

# Diff excludes — Dart/Flutter specific
DIFF_EXCLUDES=(
  ':(exclude)*.lock'
  ':(exclude)*.g.dart'
  ':(exclude)*.freezed.dart'
  ':(exclude)*.mocks.dart'
  ':(exclude).dart_tool'
  ':(exclude)build'
)

# --- Diff range resolution ---
DIFF_BASE=""
DIFF_HEAD="HEAD"
USE_EMPTY_TREE=false

if [[ -n "$DIFF_RANGE" ]]; then
  DIFF_BASE="${DIFF_RANGE%%..*}"
  DIFF_HEAD="${DIFF_RANGE##*..}"
  echo "  Using explicit range: ${DIFF_BASE}..${DIFF_HEAD}"
elif [[ "$FULL_BRANCH" == true ]]; then
  if [[ -n "$MERGE_BASE" ]]; then
    DIFF_BASE="$MERGE_BASE"
    echo "  Using full branch diff against ${BASE_REF:-main}"
  else
    USE_EMPTY_TREE=true
    echo "  Using full tree diff (no merge-base available)"
  fi
else
  # Auto-detect: find commits tagged with "(M<N>)" in commit messages
  SEARCH_RANGE=""
  if [[ -n "$BASE_REF" && -n "$MERGE_BASE" ]]; then
    SEARCH_RANGE="${BASE_REF}..HEAD"
  fi

  if [[ -n "$SEARCH_RANGE" ]]; then
    MILESTONE_COMMIT=$(git log --format='%H %s' "$SEARCH_RANGE" 2>/dev/null \
      | grep -iE "\(M${MILESTONE_NUM}\)|\(Milestone ${MILESTONE_NUM}\)" | head -1 | awk '{print $1}')
  else
    MILESTONE_COMMIT=$(git log --format='%H %s' 2>/dev/null \
      | grep -iE "\(M${MILESTONE_NUM}\)|\(Milestone ${MILESTONE_NUM}\)" | head -1 | awk '{print $1}')
  fi

  if [[ -n "$MILESTONE_COMMIT" ]]; then
    DIFF_HEAD="$MILESTONE_COMMIT"
    # Walk backwards to find the previous milestone's commit as the base
    PREV=$((MILESTONE_NUM - 1))
    FOUND_PREV=false
    while [[ $PREV -ge 1 ]]; do
      if [[ -n "$SEARCH_RANGE" ]]; then
        PREV_COMMIT=$(git log --format='%H %s' "$SEARCH_RANGE" 2>/dev/null \
          | grep -iE "\(M${PREV}\)|\(Milestone ${PREV}\)" | head -1 | awk '{print $1}')
      else
        PREV_COMMIT=$(git log --format='%H %s' 2>/dev/null \
          | grep -iE "\(M${PREV}\)|\(Milestone ${PREV}\)" | head -1 | awk '{print $1}')
      fi
      if [[ -n "$PREV_COMMIT" ]]; then
        DIFF_BASE="$PREV_COMMIT"
        FOUND_PREV=true
        break
      fi
      PREV=$((PREV - 1))
    done
    if [[ "$FOUND_PREV" == false ]]; then
      if [[ -n "$MERGE_BASE" ]]; then
        DIFF_BASE="$MERGE_BASE"
      else
        USE_EMPTY_TREE=true
      fi
    fi
    if [[ "$USE_EMPTY_TREE" == false && -n "$DIFF_BASE" ]]; then
      echo "  Auto-detected range: $(git rev-parse --short "$DIFF_BASE")..$(git rev-parse --short "$DIFF_HEAD")"
    fi
  else
    echo "  WARNING: No commit matching '(M${MILESTONE_NUM})' — falling back to full branch diff"
    if [[ -n "$MERGE_BASE" ]]; then
      DIFF_BASE="$MERGE_BASE"
    else
      USE_EMPTY_TREE=true
    fi
  fi
fi

# Generate diff
if [[ "$USE_EMPTY_TREE" == true ]]; then
  EMPTY_TREE=$(git hash-object -t tree /dev/null)
  DIFF_STAT=$(git diff "$EMPTY_TREE" HEAD --stat -- . "${DIFF_EXCLUDES[@]}" 2>/dev/null || echo "(could not compute diff stat)")
  git diff "$EMPTY_TREE" HEAD -- . "${DIFF_EXCLUDES[@]}" > "$DIFF_FILE" 2>/dev/null
  echo "  Diffing entire tree (no merge-base)"
elif [[ -n "$DIFF_BASE" ]]; then
  DIFF_STAT=$(git diff "$DIFF_BASE" "$DIFF_HEAD" --stat -- . "${DIFF_EXCLUDES[@]}" 2>/dev/null || echo "(could not compute diff stat)")
  git diff "$DIFF_BASE" "$DIFF_HEAD" -- . "${DIFF_EXCLUDES[@]}" > "$DIFF_FILE" 2>/dev/null
else
  # Fallback: diff working tree
  DIFF_STAT=$(git diff --stat -- . "${DIFF_EXCLUDES[@]}" 2>/dev/null || echo "(could not compute diff stat)")
  git diff -- . "${DIFF_EXCLUDES[@]}" > "$DIFF_FILE" 2>/dev/null
fi
DIFF_SIZE=$(wc -c < "$DIFF_FILE" | tr -d ' ')

# Collect changed source/test files (skip docs, config, deleted files)
CHANGED_FILES=()
if [[ "$USE_EMPTY_TREE" == true ]]; then
  CHANGED_LIST=$(git diff "$(git hash-object -t tree /dev/null)" HEAD --name-only -- . "${DIFF_EXCLUDES[@]}" 2>/dev/null)
elif [[ -n "$DIFF_BASE" ]]; then
  CHANGED_LIST=$(git diff "$DIFF_BASE" "$DIFF_HEAD" --name-only -- . "${DIFF_EXCLUDES[@]}" 2>/dev/null)
else
  CHANGED_LIST=$(git diff --name-only -- . "${DIFF_EXCLUDES[@]}" 2>/dev/null)
fi

while IFS= read -r file; do
  [[ -z "$file" ]] && continue
  [[ ! -f "$ROOT/$file" ]] && continue
  case "$file" in
    *.yaml|*.yml|*.toml|*.json|*.lock) continue ;;
  esac
  CHANGED_FILES+=("$ROOT/$file")
done <<< "$CHANGED_LIST"

# -------------------------------------------------------
# Phase 7: Extract milestone spec
# -------------------------------------------------------
echo "=== Phase 7: Extracting milestone spec ==="

# The implementation-milestones.md uses "## M<N>:" section headers
MILESTONE_SPEC=$(awk "
  /^## M${MILESTONE_NUM}:/ { found=1; print; next }
  found && /^---\$/ { exit }
  found && /^## M[0-9]/ { exit }
  found && /^## [A-Z]/ { exit }
  found { print }
" "$MILESTONE_PLAN")

if [[ -z "$MILESTONE_SPEC" ]]; then
  MILESTONE_SPEC="(Milestone $MILESTONE spec not found in $MILESTONE_PLAN)"
fi

# -------------------------------------------------------
# Phase 8: Compute metrics delta
# -------------------------------------------------------
echo "=== Phase 8: Computing metrics delta ==="

pkg_metric() {
  local file="$1" pkg="$2" field="$3"
  jq -r ".packages.\"$pkg\".\"$field\" // \"N/A\"" "$file" 2>/dev/null || echo "N/A"
}

delta() {
  local before="$1" after="$2"
  if [[ "$before" == "N/A" || "$before" == "null" || "$after" == "N/A" || "$after" == "null" ]]; then
    echo "—"
  else
    local d=$(( after - before ))
    if [[ $d -gt 0 ]]; then echo "+$d"
    elif [[ $d -eq 0 ]]; then echo "0"
    else echo "$d"
    fi
  fi
}

# All packages in the project
PACKAGES=(
  soliplex_app
  soliplex_client
  soliplex_client_native
  soliplex_logging
  soliplex_agent
)

AFFECTED_PKGS=()
UNAFFECTED_PKGS=()
METRICS_LINES=""

for pkg in "${PACKAGES[@]}"; do
  has_delta=false
  for field in source_lines test_lines test_count; do
    b=$(pkg_metric "$BASELINE_FILE" "$pkg" "$field")
    a=$(pkg_metric "$METRICS_AFTER" "$pkg" "$field")
    d=$(delta "$b" "$a")
    if [[ "$d" != "0" && "$d" != "—" ]]; then
      has_delta=true
    fi
  done
  if [[ "$has_delta" == true ]]; then
    AFFECTED_PKGS+=("$pkg")
    src_b=$(pkg_metric "$BASELINE_FILE" "$pkg" "source_lines")
    src_a=$(pkg_metric "$METRICS_AFTER" "$pkg" "source_lines")
    src_d=$(delta "$src_b" "$src_a")
    tst_b=$(pkg_metric "$BASELINE_FILE" "$pkg" "test_lines")
    tst_a=$(pkg_metric "$METRICS_AFTER" "$pkg" "test_lines")
    tst_d=$(delta "$tst_b" "$tst_a")
    cnt_b=$(pkg_metric "$BASELINE_FILE" "$pkg" "test_count")
    cnt_a=$(pkg_metric "$METRICS_AFTER" "$pkg" "test_count")
    cnt_d=$(delta "$cnt_b" "$cnt_a")
    METRICS_LINES="$METRICS_LINES
- **$pkg**: source ${src_d} (${src_a}), tests ${tst_d} (${tst_a} lines, ${cnt_a} tests)"
  else
    UNAFFECTED_PKGS+=("$pkg")
  fi
done

METRICS_SUMMARY="**Affected packages:**$METRICS_LINES"
if [[ ${#UNAFFECTED_PKGS[@]} -gt 0 ]]; then
  UNAFFECTED_LIST=$(printf '%s' "${UNAFFECTED_PKGS[0]}"; printf ', %s' "${UNAFFECTED_PKGS[@]:1}")
  METRICS_SUMMARY="$METRICS_SUMMARY
- **Containment:** No changes in ${UNAFFECTED_LIST}."
fi

# -------------------------------------------------------
# Build gate summary for prompt
# -------------------------------------------------------
GATE_PASS_COUNT=0
GATE_TOTAL=0

for gate_status in "$FORMAT_STATUS" "$ANALYZE_STATUS" "$DCM_STATUS" "$TEST_STATUS"; do
  case "$gate_status" in
    SKIPPED) ;;
    PASSED) GATE_TOTAL=$((GATE_TOTAL + 1)); GATE_PASS_COUNT=$((GATE_PASS_COUNT + 1)) ;;
    *)       GATE_TOTAL=$((GATE_TOTAL + 1)) ;;
  esac
done

if [[ $GATE_TOTAL -eq 0 ]]; then
  GATE_VERDICT="ALL SKIPPED"
elif [[ $GATE_PASS_COUNT -eq $GATE_TOTAL ]]; then
  GATE_VERDICT="ALL PASSED ($GATE_PASS_COUNT/$GATE_TOTAL)"
else
  GATE_VERDICT="FAILURES ($GATE_PASS_COUNT/$GATE_TOTAL passed)"
fi

# -------------------------------------------------------
# Phase 9: Assemble prompt markdown
# -------------------------------------------------------
echo "=== Phase 9: Assembling prompt ==="

cat > "$OUTPUT_FILE" << PROMPT
# Milestone $MILESTONE Review

You are a strict, adversarial Principal Engineer reviewing
Milestone $MILESTONE for the soliplex-flutter project (soliplex_agent package).
Do not trust the author's stated intentions — verify every claim
against the unified diff.

**Branch:** $GIT_BRANCH | **SHA:** $GIT_SHA | **Date:** $GIT_DATE

---

## Input Files

1. **This file** — review instructions, milestone spec, metrics, gate results
2. **\`${MILESTONE}.diff\`** — the unified diff. This is the primary artifact.
   Read every hunk. Do not skim.
3. **Changed source files** — the full current state of modified files
4. **Context files** (if any) — unchanged pre-existing code included so
   you can verify claims about existing infrastructure without guessing

---

## Quality Gates: $GATE_VERDICT

| Gate | Status |
|------|--------|
| dart format | $FORMAT_STATUS |
| flutter analyze | $ANALYZE_STATUS |
| DCM analyze | $DCM_STATUS |
| Tests | $TEST_STATUS |

Any gate failure is a blocking issue. The reviewer must verify that
gate failures are addressed or explicitly waived with justification.

---

## Mandatory Review Process (Chain of Thought)

You MUST follow this process. Do not skip steps. Do not summarize
without evidence.

### Step 1: Read the unified diff end-to-end

Before analyzing anything, read \`${MILESTONE}.diff\` completely.
Note every file touched, every function added/changed/removed.

### Step 2: Analyze each rubric item

For EACH item below, you must:
- State your finding (PASS / CONCERN / FAIL)
- Cite specific diff hunks or file:line references as evidence
- If PASS, briefly explain why. If CONCERN or FAIL, quote the
  offending code from the diff

**Rubric:**

1. **Correctness** — Does the diff implement what the milestone spec
   says? Compare each spec deliverable against the diff. List any
   deliverable that is missing or incorrectly implemented.

2. **Containment** — Are changes scoped to the milestone? Flag any
   file or function that is not described in the spec. Scope creep
   is a FAIL.

3. **Tests** — Are new/changed code paths tested? For each new public
   API or class in the diff, verify a corresponding test exists.
   Flag untested paths.

4. **Style** — Matches surrounding code. No \`// ignore:\` directives.
   No TODO comments without issue references. Consistent naming.

5. **Platform safety** — \`soliplex_agent\` is pure Dart. Search the
   diff for \`import 'package:flutter\`, \`dart:ffi\`, \`dart:isolate\`,
   \`dart:html\`, \`dart:ui\`. Any unconditional Flutter import is a FAIL.

6. **KISS/YAGNI** — No over-engineering. No premature abstractions.
   Flag any interface with only one implementation, any class that
   could be a function, any parameter that is never used in tests.

7. **Immutability** — New types should be immutable where possible.
   Flag mutable fields on model classes. Sealed classes should not
   have setters.

8. **Package boundary** — \`soliplex_agent\` must not depend on Flutter.
   Check \`pubspec.yaml\` in the diff — it may depend on
   \`soliplex_client\` and \`soliplex_logging\`, nothing else from the
   monorepo. No path dependencies that pull in Flutter.

9. **DCM compliance** — Review the DCM gate output below. Any metric
   violation (cyclomatic complexity > threshold, lines-of-code >
   threshold, etc.) or rule violation is a CONCERN. Persistent
   violations after being flagged are a FAIL.

### Step 3: Summarize

After all 9 items, provide:
- **Verdict**: APPROVE / REQUEST CHANGES
- **Blocking issues**: numbered list (if any)
- **Non-blocking suggestions**: numbered list (if any)
- **Risk assessment**: Low / Medium / High with justification

---

## Milestone Spec

$MILESTONE_SPEC

---

## Diff Stats

\`\`\`text
$DIFF_STAT
\`\`\`

## Metrics Summary

$METRICS_SUMMARY

## Format: $FORMAT_STATUS

$FORMAT_SUMMARY

## Analyze: $ANALYZE_STATUS

$ANALYZE_SUMMARY

## DCM: $DCM_STATUS

$DCM_SUMMARY

## Tests: $TEST_STATUS

$TEST_SUMMARY

---

*Generated by tool/milestone_review.sh*
PROMPT

# -------------------------------------------------------
# Phase 10: Build file list for read_files
# -------------------------------------------------------
echo "=== Phase 10: Building file list ==="

FILES_JSON="[\"$OUTPUT_FILE\",\"$DIFF_FILE\""
if [[ ${#CHANGED_FILES[@]} -gt 0 ]]; then
  for file in "${CHANGED_FILES[@]}"; do
    FILES_JSON="$FILES_JSON,\"$file\""
  done
fi
if [[ ${#CONTEXT_FILES[@]} -gt 0 ]]; then
  for file in "${CONTEXT_FILES[@]}"; do
    FILES_JSON="$FILES_JSON,\"$file\""
  done
fi
FILES_JSON="$FILES_JSON]"

FILE_COUNT=$(( 2 + ${#CHANGED_FILES[@]} + ${#CONTEXT_FILES[@]} ))

# -------------------------------------------------------
# Done
# -------------------------------------------------------
OUTPUT_SIZE=$(wc -c < "$OUTPUT_FILE" | tr -d ' ')
echo ""
echo "========================================"
echo "  Milestone $MILESTONE review ready"
echo "  Prompt:  $OUTPUT_FILE ($OUTPUT_SIZE bytes)"
echo "  Diff:    $DIFF_FILE ($DIFF_SIZE bytes)"
echo "  Files:   $FILE_COUNT total (prompt + diff + ${#CHANGED_FILES[@]} source + ${#CONTEXT_FILES[@]} context)"
echo "  Gates:   $GATE_VERDICT"
echo "    Format:  $FORMAT_STATUS"
echo "    Analyze: $ANALYZE_STATUS"
echo "    DCM:     $DCM_STATUS"
echo "    Tests:   $TEST_STATUS"
echo "========================================"
echo ""
echo "Next step:"
echo ""
echo "  mcp__gemini__read_files("
echo "    file_paths=$FILES_JSON,"
echo "    prompt=\"Follow the review instructions in the first file exactly."
echo "      The first file contains the chain-of-thought review process —"
echo "      you MUST follow all 3 steps: (1) read the unified diff end-to-end,"
echo "      (2) analyze each of the 9 rubric items with PASS/CONCERN/FAIL and"
echo "      cite specific diff hunks as evidence, (3) produce a verdict with"
echo "      blocking issues, non-blocking suggestions, and risk assessment."
echo "      Pay special attention to the Quality Gates table — any gate failure"
echo "      is automatically a blocking issue."
echo "      The second file is the unified diff. Files after are source + context."
echo "      Do not skip any rubric item. Do not approve without evidence.\","
echo "    model=\"gemini-3.1-pro-preview\""
echo "  )"
