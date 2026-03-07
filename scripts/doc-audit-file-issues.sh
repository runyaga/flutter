#!/usr/bin/env bash
# Stage 3: File GitHub issues for audit findings.
# Reads the LLM findings JSON and creates one issue per FAIL verdict.
# Deduplicates against open issues to avoid filing the same finding twice.
# Capped at 10 NEW issues per run to prevent flooding.
set -euo pipefail

FINDINGS_FILE="${1:?Usage: $0 <findings.json>}"
MAX_ISSUES="${2:-10}"
DRY_RUN="${DRY_RUN:-false}"

if [ ! -f "$FINDINGS_FILE" ]; then
  echo "ERROR: Findings file not found: $FINDINGS_FILE" >&2
  exit 1
fi

FAIL_COUNT=$(jq '[.findings[] | select(.verdict=="FAIL")] | length' "$FINDINGS_FILE")
echo "Found $FAIL_COUNT FAIL verdicts in audit findings" >&2

if [ "$FAIL_COUNT" -eq 0 ]; then
  echo "No failures found. No issues to file." >&2
  exit 0
fi

# ---------------------------------------------------------------------------
# Dedup: fetch all open issues with the "documentation" label.
# We match on the file path in the title to avoid duplicates.
# Title format is: "docs(audit): <filepath> — <score>"
# We extract the filepath portion for matching.
# ---------------------------------------------------------------------------
echo "Fetching open documentation issues for dedup..." >&2
OPEN_ISSUES=$(gh issue list --label documentation --state open --limit 200 \
  --json title --jq '.[].title' 2>/dev/null || true)

# Extract file paths from existing issue titles
EXISTING_FILES=$(echo "$OPEN_ISSUES" | \
  grep '^docs(audit):' | \
  sed 's/^docs(audit): \(.*\) — .*/\1/' | \
  sort -u)

echo "Found $(echo "$EXISTING_FILES" | grep -c . || echo 0) open audit issues" >&2

FILED=0
SKIPPED=0

jq -c '.findings[] | select(.verdict=="FAIL")' "$FINDINGS_FILE" | while IFS= read -r finding; do
  if [ "$FILED" -ge "$MAX_ISSUES" ]; then
    REMAINING=$((FAIL_COUNT - FILED - SKIPPED))
    echo "Issue cap reached ($MAX_ISSUES). $REMAINING findings skipped." >&2
    break
  fi

  FILE=$(echo "$finding" | jq -r '.file')
  SCORE=$(echo "$finding" | jq -r '.score // "unknown"')
  CONCERNS=$(echo "$finding" | jq -r '.concerns | join("\n- ")')
  EVIDENCE=$(echo "$finding" | jq -r '.evidence // "No raw evidence provided"')
  SUGGESTED_FIX=$(echo "$finding" | jq -r '.suggested_fix // "No suggestion provided"')

  # Check if an open issue already exists for this file
  if echo "$EXISTING_FILES" | grep -qF "$FILE"; then
    echo "SKIP: Open issue already exists for $FILE" >&2
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  TITLE="docs(audit): $FILE — $SCORE"
  BODY="$(cat <<ISSUE
## Documentation Audit Finding

**File:** \`$FILE\`
**Score:** $SCORE
**Audit date:** $(date -u +%Y-%m-%d)
**Source:** Automated LLM audit (doc-audit.yml)

### Concerns

- $CONCERNS

### Evidence

\`\`\`
$EVIDENCE
\`\`\`

### Suggested fix

$SUGGESTED_FIX

---
*Filed automatically by the documentation audit workflow.
See MAINTENANCE.md for the evaluation criteria.*
ISSUE
)"

  if [ "$DRY_RUN" = "true" ]; then
    echo "=== DRY RUN: Would create issue ===" >&2
    echo "Title: $TITLE" >&2
    echo "===" >&2
  else
    echo "Filing issue for $FILE..." >&2
    gh issue create \
      --title "$TITLE" \
      --label "documentation" \
      --body "$BODY" 2>&1 || echo "WARNING: Failed to create issue for $FILE" >&2
  fi

  FILED=$((FILED + 1))
done

echo "Done. Filed $FILED new issues, skipped $SKIPPED duplicates." >&2
