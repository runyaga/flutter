# Soliplex Documentation Roadmap

> A plan to restructure documentation so it serves humans, AI agents, and the
> backend team equally well.

## Philosophy

Documentation in an AI-driven development workflow is not passive reference
material. It is an **active system** with three legs:

1. **Reference Docs** — layered: shallow for humans, dense for AI
1. **Interactive Docs** — tutorials that guide agents through the CLI to validate
   understanding against the real application
1. **Maintenance Docs** — a self-validating meta-protocol that detects drift
   between docs and code, and can be run as a health check

The maintenance layer is the most important *and* the most likely to rot. To
combat this, maintenance docs contain **executable assertions** that CI and AI
agents can verify continuously.

### Design Principles

- **Humans skim, AI reads dense prose.** Every section has a short "TL;DR" block
  (2-3 sentences) followed by full technical detail with code examples.
- **Docs guide interaction.** Tutorials don't just explain — they instruct the
  reader to run commands (via `soliplex_cli`) and verify output.
- **Self-validating.** Maintenance docs include checkable assertions, discovery
  commands, and freshness markers that an agent can execute.
- **Portable pattern.** Everything we learn here becomes a template the backend
  team can adopt for server-side documentation.

---

## Current State Assessment

### What's Good (Keep)

| Document | Rating | Notes |
|---|---|---|
| `architecture/agent-stack.md` | Good | Canonical agent reference |
| `architecture/agent-integration-guide.md` | Good | Practical, highlights gaps |
| `architecture/http-stack.md` | Evergreen | Decorator chain docs |
| `architecture/http-extension-guide.md` | Evergreen | Extension rules |
| `architecture/cli-monty-guide.md` | Evergreen | CLI + Python usage |
| `guides/developer-setup.md` | Good | Clear onboarding |
| `adr/001-whitelabel-architecture.md` | Evergreen | Foundational decisions |
| `adr/002-backend-log-shipping.md` | Evergreen | Operational architecture |
| `adr/003-agent-supervision.md` | Active | Spike, still evolving |
| Package READMEs (most) | Good | Accurate, well-structured |

### What's Stale (Archive or Delete)

| Document | Action | Reason |
|---|---|---|
| `design/runtime-guide.md` | Archive | Superseded by `agent-stack.md` |
| `design/orchestration-guide.md` | Archive | Superseded by `agent-stack.md` |
| `design/soliplex-agent-package.md` | Archive | Planning doc for completed work |
| `design/index.md` | Delete | Links to stale docs, misleads readers |
| `design/implementation-milestones.md` | Archive | Historical, work completed |
| `design/m4-behavioral-contract.md` | Archive | Historical milestone detail |
| `design/monty-host-capabilities-integration.md` | Delete | Explicitly marked SUPERSEDED |
| `design/diagrams.md` | Refactor | Move diagrams into their host docs |
| `logging-quickstart.md` (root level) | Move | Should be in `guides/` |

### What's Missing (Gaps)

1. **"Start Here" golden path** — No clear reading order for newcomers
1. **soliplex_agent tutorials** — Zero how-to guides (custom tools, HostApi impl, etc.)
1. **Interactive CLI walkthrough** — No guided "learn by doing" docs
1. **Testing strategy** — No project-wide testing philosophy
1. **CI/CD and deployment** — No build/release docs
1. **Auth workflow** — No user authentication docs
1. **Flutter UI layer** — No guidance on state management or adding features
1. **Maintenance protocol** — No process for keeping docs current
1. **Cross-team sharing** — No documentation standards doc for backend adoption

---

## Proposed Structure

```text
docs/
  index.md                          # Rewritten: "Start Here" golden path
  MAINTENANCE.md                    # Self-validating maintenance protocol

  getting-started/
    developer-setup.md              # Existing (moved from guides/)
    architecture-overview.md        # NEW: 10-min layered overview
    cli-quickstart.md               # NEW: Interactive CLI tutorial

  architecture/
    agent-stack.md                  # Existing (canonical)
    agent-integration-guide.md      # Existing
    http-stack.md                   # Existing
    http-extension-guide.md         # Existing
    cli-monty-guide.md              # Existing
    package-dependency-map.md       # NEW: visual + text dep graph

  tutorials/
    01-your-first-agent.md          # NEW: spawn agent via CLI, see output
    02-building-a-custom-tool.md    # NEW: ToolRegistry, ToolExecutor, context
    03-implementing-host-api.md     # NEW: HostApi/FormApi contract guide
    04-adding-python-scripts.md     # NEW: ScriptEnvironment walkthrough
    05-multi-server-setup.md        # NEW: when multi-server lands

  reference/
    soliplex-agent-api.md           # NEW: full public API surface
    host-api-contract.md            # NEW: HostApi/FormApi/BlackboardApi specs
    platform-constraints.md         # NEW: native/mobile/web differences
    tool-system.md                  # NEW: ToolRegistry, resolver, context
    error-classification.md         # NEW: FailureReason taxonomy
    signals-and-state.md            # NEW: RunState, AgentSessionState, signals

  adr/
    001-whitelabel-architecture.md  # Existing
    002-backend-log-shipping.md     # Existing
    003-agent-supervision.md        # Existing

  guides/
    logging.md                      # Existing
    logging-quickstart.md           # Existing (moved from root)
    flush-gating.md                 # Existing
    testing-strategy.md             # NEW: project-wide testing philosophy

  planning/
    (active planning docs)          # Existing — live work stays here
    archive/                        # Stale planning docs moved here

  design/
    agent-runtime-vision.md         # Existing (good, keep)
    multi-server-support.md         # Existing (active)
    multi-server-*.md               # Existing (active)
    archive/                        # Stale design docs moved here

  experiments/
    construction-scheduling.md      # PR #89: plugin-based eval tiers
    construction-eval-5x.md         # PR #89: 5x run results
```

---

## Phased Roadmap

### Phase 0: Cleanup and Foundation

**Goal:** Remove noise so developers can trust what remains.

- [ ] Create `design/archive/` and `planning/archive/`
- [ ] Move stale docs to archive (see table above)
- [ ] Delete `design/index.md` and superseded `monty-host-capabilities-integration.md`
- [ ] Move `logging-quickstart.md` to `guides/`
- [ ] Refactor `design/diagrams.md` — distribute diagrams into host documents
- [ ] Rewrite `docs/index.md` as a "Start Here" page with clear reading order

### Phase 1: Maintenance Protocol (MAINTENANCE.md)

**Goal:** The most critical doc — a self-validating protocol for humans and bots.

This document contains:

#### Freshness Markers

Every doc section gets a marker:

```markdown
<!-- freshness: verified=2026-03-06, by=claude, next-check=2026-04-06 -->
```

#### Executable Assertions

Checkable statements that CI or an agent can run:

```markdown
## Assertion: soliplex_agent test suite
- Run: `cd packages/soliplex_agent && dart test`
- Expect: 1492+ tests passing, 0 failures
- If failing: agent-stack.md may reference APIs that have changed
```

```markdown
## Assertion: HostApi has no visual-domain methods
- Run: `grep -n 'chart\|widget\|form' packages/soliplex_agent/lib/src/host/host_api.dart`
- Expect: Only `registerDataFrame` and `registerChart` (grandfathered)
- If violated: Package contract rules are being breached — see CLAUDE.md
```

#### Discovery Commands

Commands that detect doc drift:

```markdown
## Discovery: Public API completeness
- Run: `grep 'export' packages/soliplex_agent/lib/soliplex_agent.dart`
- Compare against: reference/soliplex-agent-api.md class list
- If mismatch: New classes exported without documentation
```

#### Gap Detection Checklist

A periodic checklist for humans and bots:

- [ ] Every exported class in `soliplex_agent.dart` has a reference doc entry
- [ ] Every tutorial's CLI commands still produce expected output
- [ ] Every ADR's status (accepted/spike/superseded) is accurate
- [ ] Every package README matches its actual `pubspec.yaml` description
- [ ] No docs reference deleted files or renamed classes

#### Bot Protocol

When an AI agent reads documentation:

1. Read the relevant doc section
1. Run the associated assertion commands
1. If assertions fail, flag the doc as stale before proceeding
1. After making code changes, re-run assertions and update freshness markers

### Phase 2: soliplex_agent Deep Dive

**Goal:** Dense reference docs + interactive tutorials for the core package.

#### Reference Docs (AI-dense layer)

- [ ] `reference/soliplex-agent-api.md` — Full public API map with class descriptions,
      method signatures, and relationships. Generated from the Gemini analysis:
  - Host layer: `HostApi`, `AgentApi`, `BlackboardApi`, `FormApi`, `PlatformConstraints`
  - Runtime layer: `AgentRuntime`, `AgentSession`, `MultiServerRuntime`
  - Orchestration layer: `RunOrchestrator`, `RunState`, `ErrorClassifier`
  - Tools layer: `ToolRegistry`, `ToolExecutor`, `ToolExecutionContext`, `ToolRegistryResolver`
  - Models: `AgentResult`, `FailureReason`, `ThreadKey`
  - Scripting: `ScriptEnvironment`, `SessionExtension`

- [ ] `reference/host-api-contract.md` — Implementer guide for HostApi, FormApi,
      BlackboardApi. Includes field schemas for `FormApi.createForm()`, handle
      lifecycle rules, error reporting contract.

- [ ] `reference/tool-system.md` — How to define a `ToolExecutor`, register it,
      resolve registries per-room, use `ToolExecutionContext` to spawn children
      and emit events.

- [ ] `reference/platform-constraints.md` — Native vs mobile vs web differences.
      Concurrency limits, reentrant interpreter support, queue behavior.

- [ ] `reference/error-classification.md` — `FailureReason` enum taxonomy,
      `ErrorClassifier` usage, how errors flow through the system.

- [ ] `reference/signals-and-state.md` — `RunState` sealed class variants,
      `AgentSessionState` lifecycle, signal-based reactive API (and the current
      gap where consumers still use legacy streams).

#### Tutorials (Interactive layer)

Each tutorial follows the pattern: concept -> code example -> CLI verification.

The construction scheduling experiment (PR #89) serves as a real-world example
of the plugin pattern: ConstructionPlugin exposes 20 host functions, the LLM
writes Python glue code, and StreamRegistry manages event coordination. Tutorials
should reference this as a concrete, tested example.

- [ ] `tutorials/01-your-first-agent.md`
  - TL;DR for humans
  - Dense walkthrough: create a room, spawn agent, observe lifecycle via CLI
  - Verification: run specific CLI commands, check output matches expected

- [ ] `tutorials/02-building-a-custom-tool.md`
  - Implement a `ToolExecutor` function
  - Register in `ToolRegistry`, wire via `ToolRegistryResolver`
  - Use `ToolExecutionContext` for child spawning
  - Verify via CLI: trigger the tool, see execution events

- [ ] `tutorials/03-implementing-host-api.md`
  - Implement `HostApi` for a new consumer
  - Wire `FormApi` for dynamic forms
  - Test with `FakeHostApi` in unit tests

- [ ] `tutorials/04-adding-python-scripts.md`
  - Create a `ScriptEnvironment`
  - Wire host functions (FormApi, AgentApi) into the interpreter
  - Test via CLI: run a Python script that spawns a sub-agent
  - Reference: ConstructionPlugin as a production example of this pattern

### Phase 3: Architecture Overview and Getting Started

**Goal:** The "front door" — what newcomers and AI agents see first.

- [ ] `getting-started/architecture-overview.md`
  - 10-minute read
  - Package dependency diagram (mermaid)
  - Layer descriptions: Foundation -> Client -> Agent -> Scripting -> Applications
  - "Where does X live?" quick-reference table

- [ ] `getting-started/cli-quickstart.md`
  - Interactive: install, configure, run first command
  - This is the **proving ground** where AI agents validate their understanding

- [ ] `architecture/package-dependency-map.md`
  - Visual mermaid diagram of all packages
  - Brief role description per package
  - Dependency arrows with rationale

### Phase 4: Supporting Docs

**Goal:** Fill remaining gaps.

- [ ] `guides/testing-strategy.md` — unit/widget/integration test philosophy,
      where to find examples, CI expectations
- [ ] Update package READMEs: `soliplex_skills` (needs work), add missing
      READMEs for `soliplex_client_native`, `soliplex_cli`
- [ ] `design/agent-runtime-vision.md` — review and refresh (currently good)
- [ ] `INSTALL.md` — End-user/deployer installation guide (separate from
      developer-setup, which targets contributors)

### Phase 5: Scheduled LLM Documentation Audit

**Goal:** Automated, periodic LLM-driven review that runs the evaluation
criteria from MAINTENANCE.md and files GitHub issues for findings.

This is the enforcement loop that keeps documentation honest over time.
Without it, the maintenance protocol is a checklist that humans forget to
run.

#### Architecture

A scheduled GitHub Action (`doc-audit.yml`) runs weekly (or biweekly).
It has two stages:

**Stage 1 — Deterministic (no LLM):**

- Run all assertion commands from MAINTENANCE.md (A1-A6)
- Check freshness markers for expiration
- Check all internal doc links resolve
- Collect results into a structured JSON report

**Stage 2 — LLM evaluation (OpenAI):**

- Feed the JSON report + each doc file to the LLM
- System prompt includes the fail-by-default doctrine and anti-sycophancy
  rules from MAINTENANCE.md verbatim
- LLM evaluates each doc against the readiness gate criteria
- LLM must produce a structured verdict per doc: PASS/FAIL with evidence
- For each FAIL: LLM drafts a GitHub issue body with the required template
- Script calls `gh issue create` for each finding

#### Key Design Decisions

- **OpenAI, not local model.** Scheduled batch job, cost is low (weekly
  cadence, bounded input size). `OPENAI_API_KEY` stored as repo secret.
- **Model choice:** Use a capable model (gpt-4o or equivalent). The
  anti-sycophancy prompt must be tested against the chosen model to
  ensure it actually falsifies.
- **Deterministic first.** Stage 1 runs without the LLM. If Stage 1
  finds failures, they are filed as issues regardless of Stage 2. The
  LLM adds value by catching semantic drift that assertions miss (e.g.,
  "this diagram no longer matches the actual data flow").
- **Rate limiting.** Cap at 10 issues per run to prevent flooding. If
  more than 10 findings, file a summary issue linking to the raw report.
- **Audit log.** The full structured report is uploaded as a workflow
  artifact for human review.

#### Workflow Skeleton

```yaml
name: Documentation Audit
on:
  schedule:
    - cron: '0 9 * * 1'  # Every Monday 9am UTC
  workflow_dispatch:

jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6

      - name: Run deterministic assertions
        run: scripts/doc-audit-deterministic.sh > report.json

      - name: LLM evaluation
        env:
          OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}
        run: scripts/doc-audit-llm.py report.json > findings.json

      - name: File issues for findings
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: scripts/doc-audit-file-issues.sh findings.json

      - name: Upload audit report
        uses: actions/upload-artifact@v4
        with:
          name: doc-audit-report
          path: report.json
```

#### Implementation Checklist

- [ ] `scripts/doc-audit-deterministic.sh` — runs MAINTENANCE.md assertions,
      outputs structured JSON
- [ ] `scripts/doc-audit-llm.py` — sends docs + report to OpenAI, parses
      structured verdicts, enforces anti-sycophancy prompt
- [ ] `scripts/doc-audit-file-issues.sh` — creates GitHub issues from
      findings JSON, respects 10-issue cap
- [ ] `.github/workflows/doc-audit.yml` — scheduled workflow
- [ ] `OPENAI_API_KEY` added as repo secret
- [ ] Test run: trigger manually, verify issues are filed correctly
- [ ] Tune anti-sycophancy prompt against chosen model until false-pass
      rate is acceptable

### Phase 6: Cross-Team Sharing

**Goal:** Make this documentation system a reusable template.

- [ ] Extract a `docs/DOCUMENTATION-STANDARDS.md` that captures:
  - The three-leg philosophy (reference, interactive, maintenance)
  - The layered depth model (human TL;DR + AI-dense prose)
  - The self-validating assertion pattern
  - The freshness marker convention
  - The bot protocol for doc consumption
- [ ] Share with backend team as a starting template
- [ ] Adapt CLI-based tutorials to backend equivalents (API calls, curl, etc.)

---

## Priority Order

| Priority | Phase | Rationale |
|---|---|---|
| P0 | Phase 0 (Cleanup) | Remove noise — prerequisite for everything |
| P0 | Phase 5 (LLM Audit) | **Bootstrap first.** The audit creates the backlog. Without it, everything else is a checklist nobody runs. Get the enforcement loop spinning immediately — it will file issues that drive Phases 1-4. |
| P0 | Phase 1 (MAINTENANCE.md) | Assertions + gate criteria that the audit evaluates against |
| P1 | Phase 2 (soliplex_agent) | Core package, driven by audit findings |
| P1 | Phase 3 (Getting Started) | Front door for new developers and agents |
| P2 | Phase 4 (Supporting) | Fills gaps, driven by audit findings |
| P2 | Phase 6 (Cross-Team) | Force multiplier, depends on P0-P1 |

---

## Success Criteria

Each criterion is falsifiable — it either passes or fails, no subjective
assessment.

- [ ] **Golden path test:** A new developer, following only `docs/index.md`
  links, can answer: (a) what package owns agent orchestration? (b) how do
  you spawn an agent via CLI? (c) what is `RunState`? — without reading
  source code
- [ ] **AI code generation test:** An LLM, given only the docs (no source),
  can produce a valid `ToolExecutor` implementation that compiles. Verified
  by extracting the generated code and running `dart analyze`
- [ ] **CI green:** `doc_health_test.dart` passes in CI with zero failures
- [ ] **Link integrity:** `grep -roh '\]([^http][^)]*\.md)' docs/` produces
  zero references to nonexistent files
- [ ] **No orphans:** Every `.md` file in `docs/` (excluding `archive/`) is
  reachable from `index.md` via at most 2 link hops
- [ ] **Backend portability:** `DOCUMENTATION-STANDARDS.md` contains no
  Flutter/Dart-specific content — all patterns are framework-agnostic
- [ ] **Audit loop running:** `doc-audit.yml` has run at least 3 scheduled
  cycles, filed at least 1 issue per cycle, and zero issues were
  false positives (sycophantic passes that a human later overturned)
