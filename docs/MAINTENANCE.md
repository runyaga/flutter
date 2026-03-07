# Documentation Maintenance Protocol

> For humans AND AI agents. This document is self-validating — its assertions
> can be executed to detect drift between documentation and code.

## How to Use This Document

**Humans:** Review the checklists periodically (monthly or after major PRs).
Skim the assertions — if something looks wrong, run the command to verify.

**AI Agents:** Before working on the codebase, run the relevant assertion
commands below. If any fail, flag the associated documentation as stale
before relying on it. After making code changes, re-run assertions and
update freshness markers.

**CI:** The deterministic assertions are encoded as Dart tests in
`packages/soliplex_agent/test/doc_health_test.dart`. These run automatically
with the existing test matrix — no LLM required.

---

## Freshness Markers

Every documentation section should include a freshness marker comment:

```markdown
<!-- freshness: verified=YYYY-MM-DD, by=<human|claude|gemini>, next-check=YYYY-MM-DD -->
```

**Rules:**

- `next-check` defaults to 30 days after `verified`
- A stale marker does not mean the doc is wrong — it means it hasn't been checked
- When you verify a section, update the marker even if no changes were needed

---

## Executable Assertions

These are deterministic checks that CI can run. Each assertion maps to a
documentation claim. When an assertion fails, the linked doc section may be
stale.

### A1: Public API Exports Match Documentation

**Docs:** `reference/soliplex-agent-api.md`
**Check:** Every class exported from `soliplex_agent.dart` has an entry in
the API reference.

```bash
# List all exports
grep "export" packages/soliplex_agent/lib/soliplex_agent.dart
```

**CI test:** `doc_health_test.dart` > `'all exported classes are documented'`

### A2: HostApi Package Contract

**Docs:** `reference/host-api-contract.md`, CLAUDE.md package contract rules
**Check:** `HostApi` contains no visual-domain methods beyond the
grandfathered `registerDataFrame` and `registerChart`.

```bash
# Should only find registerDataFrame and registerChart
grep -n 'chart\|widget\|form\|Chart\|Widget\|Form' \
  packages/soliplex_agent/lib/src/host/host_api.dart
```

**CI test:** `doc_health_test.dart` > `'HostApi has no visual-domain methods'`

### A3: Package READMEs Exist

**Docs:** `docs/index.md` package table
**Check:** Every package listed in `docs/index.md` has a README.md.

```bash
# List packages without READMEs
for pkg in packages/soliplex_*/; do
  [ -f "$pkg/README.md" ] || echo "MISSING: $pkg/README.md"
done
```

**CI test:** `doc_health_test.dart` > `'all packages have READMEs'`

### A4: No Broken Internal Doc Links

**Docs:** All markdown files
**Check:** Every `[text](path.md)` link in docs/ points to an existing file.

```bash
# Find all relative links and check targets
grep -roh '\]([^http][^)]*\.md)' docs/ | sort -u
```

**CI test:** `doc_health_test.dart` > `'no broken internal doc links'`

### A5: Test Suite Baseline

**Docs:** `architecture/agent-stack.md` (references test coverage)
**Check:** soliplex_agent tests pass and meet minimum count.

```bash
cd packages/soliplex_agent && dart test 2>&1 | tail -5
```

**CI test:** Already covered by existing CI test matrix.

### A6: Pure Dart Contract

**Docs:** CLAUDE.md development rules
**Check:** Pure Dart packages do not import Flutter.

```bash
for pkg in soliplex_agent soliplex_client soliplex_logging soliplex_scripting soliplex_interpreter_monty; do
  grep -r "import 'package:flutter" "packages/$pkg/lib/" && echo "VIOLATION: $pkg imports Flutter"
done
```

**CI test:** `doc_health_test.dart` > `'pure Dart packages have no Flutter imports'`

---

## Discovery Commands

Run these to find undocumented areas. These are not CI-enforced but useful
for periodic human or AI review.

### D1: New Exports Without Docs

```bash
# Compare exports against documented classes
diff <(grep 'export' packages/soliplex_agent/lib/soliplex_agent.dart | \
       sed "s/.*'\(.*\)'.*/\1/" | sort) \
     <(grep -oE '[A-Z][a-zA-Z]+' docs/reference/soliplex-agent-api.md | sort -u)
```

### D2: Undocumented Architecture Files

```bash
# Dart files with no doc comments on public classes
for f in packages/soliplex_agent/lib/src/**/*.dart; do
  grep -L '///' "$f"
done
```

### D3: Stale Planning Docs

```bash
# Planning docs older than 60 days with no freshness marker
find docs/planning -name "*.md" -mtime +60 -exec \
  grep -L 'freshness:' {} \;
```

---

## Gap Detection Checklist

Run monthly or after major feature landings.

- [ ] Every exported class in `soliplex_agent.dart` has a reference doc entry
- [ ] Every tutorial's CLI commands still produce expected output
- [ ] Every ADR status (accepted/spike/superseded) is accurate
- [ ] Every package README matches its `pubspec.yaml` description field
- [ ] No docs reference deleted files or renamed classes
- [ ] `docs/index.md` links are all reachable (no 404s)
- [ ] Active design docs reflect current implementation state
- [ ] Archive contains only completed/superseded work
- [ ] Package dependency graph in docs matches actual `pubspec.yaml` deps

---

## Bot Protocol

When an AI agent reads documentation to assist with code changes:

1. **Before coding:** Read the relevant doc section. Run associated assertions
   from this file. If any fail, note the discrepancy before proceeding.
2. **During coding:** If you discover a doc claim is wrong, fix the doc in the
   same PR as the code change.
3. **After coding:** Re-run assertions. Update freshness markers on any docs
   you verified or modified.
4. **If uncertain:** Use `soliplex_cli` to interact with the system and
   validate understanding against live behavior.

---

## Adding New Assertions

When you add a new documentation section that makes a testable claim:

1. Write the assertion in this file (pattern: Docs link, Check description,
   bash command, CI test name)
2. Add the corresponding test case in `doc_health_test.dart`
3. Verify it passes locally before committing

Format:

```markdown
### A{N}: {Short Name}

**Docs:** `path/to/doc.md`
**Check:** {What the assertion verifies}

\`\`\`bash
{command to check manually}
\`\`\`

**CI test:** `doc_health_test.dart` > `'{test name}'`
```

---

## Cross-Team Sharing

This maintenance protocol is designed to be portable. The backend team can
adopt the same pattern:

1. Copy this file as a template
2. Replace Dart-specific assertions with backend equivalents
3. Replace CLI tutorials with API/curl-based tutorials
4. Keep the same freshness marker convention for consistency
5. Share the `doc_health_test` pattern (adapt to their test framework)

---

## Documentation Readiness Gate

New documentation must pass a readiness gate before merging. The gate is
designed to be **evaluated backwards** — the reviewer (human or LLM) must
produce concrete evidence for each criterion, not subjective assessment.

An LLM evaluating readiness MUST cite specific evidence. If it cannot cite
evidence, the criterion fails. "Looks good" or "appears complete" is not
evidence.

### Gate Criteria

For every new or substantially rewritten doc section:

1. **Falsifiable claims only.** Every factual claim in the doc can be verified
   by running a command or reading a source file. Cite the command or file.
   - Evidence: list each claim and its verification command
   - FAIL if: any claim cannot be independently verified

2. **Code examples compile.** Every Dart code snippet, when extracted, passes
   `dart analyze`. Every bash command, when run, produces the documented output.
   - Evidence: paste the actual output of running each example
   - FAIL if: any example produces different output than documented

3. **Links resolve.** Every internal `[text](path.md)` link points to a file
   that exists in the repository.
   - Evidence: list each link and confirm the target file exists
   - FAIL if: any link target is missing

4. **No orphan docs.** The new doc is reachable from `docs/index.md` via
   links. It is not a floating file.
   - Evidence: show the link chain from index.md to the new doc
   - FAIL if: no path exists from index.md

5. **Freshness marker present.** The doc includes a freshness comment.
   - Evidence: quote the freshness marker line
   - FAIL if: missing

6. **Assertion registered.** If the doc makes a testable claim about code
   (API surface, contracts, behavior), a corresponding assertion exists in
   this file and in `doc_health_test.dart`.
   - Evidence: cite the assertion ID (e.g., A7)
   - FAIL if: testable claims exist without assertions

### Anti-Sycophancy Rule

When an LLM reviews documentation against this gate:

- It MUST attempt to falsify each criterion, not confirm it
- It MUST report at least one concern or gap, even if minor
- If it finds zero issues, it must explicitly state: "I found no issues.
  This is unusual — a human should double-check criteria 1 and 2."
- Reviewers should be suspicious of all-pass reviews

<!-- freshness: verified=2026-03-06, by=claude, next-check=2026-04-06 -->
