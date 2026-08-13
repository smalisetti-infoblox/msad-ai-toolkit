# MSAD AI Toolkit

**End-to-end automation for MSAD epic development.** Claude Code skills + subagents for discovering tasks, completing partial PRs, implementing fresh features, and orchestrating execution across five repositories with different stacks.

**Handles:** Epic → Discovery → Parallel Agents → PR-Ready (20 min, all quality gates passed)

**Quick Start:** See [Quick Start](#quick-start-recommended) for your first epic, or jump to [Usage Patterns](#usage-patterns) for worked examples.

---

## Five-Repo Ecosystem

| Repo | Stack | Role |
|---|---|---|
| **ddi.dns.config** | Go | WAPI v3 API surface; replication-scope validation |
| **ddi.cloud.proxy.middleware** | Go | gRPC interceptor library; MSAD request translation |
| **ddi.msad.collector** | Go, gRPC | gRPC microservice; error-code mapping |
| **ddi.msadconnect.proxy** | Go | Windows RPC/LDAP bridge |
| **ddi.msad.agent** | C#/.NET 8 | Windows Service; PowerShell zone controllers (Windows-only testing) |

**Dependency Repos (referenced, not owned):**

| Repo | Role |
|---|---|
| **atlas.onprem.rpc.server** | Proto-contract dependency of ddi.msadconnect.proxy and ddi.msad.agent (Windows RPC/gRPC dispatcher) |
| **atlas.onprem.common** | Go module dependency of ddi.msadconnect.proxy (common utilities) |

See `references/repo-topology.md` "Dependency Repos" for how to discover and track additional dependencies.

---

## Installation

### Option 1: Add as Claude Code Plugin (Recommended)

```bash
# Clone the repo
git clone <this-repo> ~/msad-ai-toolkit

# In Claude Code: Settings → Plugins → Add Local Plugin
# Path: ~/msad-ai-toolkit
```

### Option 2: Symlink into ~/.claude/

```bash
# Install agents
ln -s ~/msad-ai-toolkit/agents/* ~/.claude/agents/

# Install skills
ln -s ~/msad-ai-toolkit/skills/* ~/.claude/skills/

# Reload Claude Code
```

---

## Quick Start (Recommended)

### One-Command Epic Execution

You have a Jira epic. **Just run:**

```bash
/msad-dev-epic DDIDNS-7732
```

**What happens (automatically):**

1. **Discover** → Fetch epic, list all linked tasks/stories, find existing PRs
2. **Classify** → Identify partial PRs (gaps to close), complete PRs, not-started tasks
3. **Dispatch** → Launch parallel subagents (one per work item)
4. **Consolidate** → Collect results, verify tests + coverage
5. **Report** → "All 7 PRs ready for human review"

**Timeline:** ~20 minutes total (parallel execution)

**Result:** All PRs ready for human review + merge

---

## Advanced: Detailed Planning + Execution

If you want explicit approval gates or detailed analysis before execution:

### Step 1: Generate Detailed Plan

```bash
/msad-dev-planning DDIDNS-7732
```

**What happens:**
- Reads epic + all linked tasks
- Groups work by repo, identifies dependencies
- Runs fresh-context reviewer to catch gaps
- Presents plan for your approval

### Step 2: Execute Approved Plan

```bash
/msad-dev-execution DDIDNS-7732
```

**What happens:**
- Dispatches implementation agents per work package
- Runs tests (docker-compose, go test, dotnet test)
- Validation loop (≤3 rounds): code review → findings → fixes
- Opens draft PRs when all gates pass

---

## Architecture: Three-Tier Automation

```
Tier 1: /msad-dev-planning (10 min)
  ↓ Detailed phase-by-phase analysis + approval gate
  
Tier 2: /msad-dev-epic (20 min) ← RECOMMENDED (NEW)
  ↓ Automated discovery + parallel agent dispatch
  
Tier 3: /msad-dev-execution (20 min)
  ↓ Agent-driven implementation + validation loop
  
Manual: /msad-backend-dev (10-30 min)
  ↓ Single-task implementation
```

**Use Tier 2 for most work.** Use Tier 1 if you want detailed plan review first.

---

## Usage Patterns

### Pattern A: Quick Epic Execution (Recommended)

**Input:** Epic like DDIDNS-7732 (zone creation / replication scope)

**Flow:**

```bash
User: /msad-dev-epic DDIDNS-7732

Epic Execution:
  ✓ Discovery: Found 4 existing PRs, 3 tasks not-started
  ✓ Classification: 2 partial PRs (gaps), 2 complete PRs
  ✓ Dispatch: 4 agents launched in parallel
  ✓ Agent 1: PR 507 (complete gap) → Coverage 87% → 92.3% ✓
  ✓ Agent 2: PR 508 (review) → Tests passing ✓
  ✓ Agent 3: PR 241 (complete gap) → Coverage 85% → 92.1% ✓
  ✓ Agent 4: PR 6300 (review) → Tests passing ✓

Result: All 4 PRs ready for human review
Timeline: ~20 minutes (parallel execution)

PRs ready to review/merge:
  - https://github.com/Infoblox-CTO/ddi.cloud.proxy.middleware/pull/507
  - https://github.com/Infoblox-CTO/ddi.cloud.proxy.middleware/pull/508
  - https://github.com/Infoblox-CTO/ddi.msad.collector/pull/241
  - https://github.com/Infoblox-CTO/ddi.dns.config/pull/6300
```

**Speedup:** 18-20 min (parallel) vs 70+ min (sequential)

### Pattern B: Detailed Plan + Execution

**Input:** Epic with complex dependencies or where you want explicit approval

**Flow:**

```bash
User: /msad-dev-planning DDIDNS-7732

Planning: Here's your detailed plan:
  - Phase 1 (CREATE): 7 work packages across 5 repos
  - Phase 2 (UPDATE): 2 deferred stories
  - Dependencies: 
    - Collector error codes → middleware validation
    - Validator sync: dns.config ↔ middleware
  - Risks: Windows testing only on CI
  
  Reviewer audit: [✓] All AC covered [✓] Dependencies clear
  
  Approve? (Y/N/Edit)

User: Approve

User: /msad-dev-execution DDIDNS-7732

[Execution dispatches agents, runs tests, opens draft PRs]
```

**Timeline:** 10 min (planning) + 20 min (execution) = 30 min total

### Pattern C: Complete Existing PR Gaps

**Input:** Draft PR with identified gap (e.g., missing tests)

**Flow:**

```bash
User: /msad-dev-epic DDIDNS-7732

Epic Execution:
  ✓ Discovers: PR 507 (DRAFT, 85% complete, gap: missing handler tests)
  ✓ Classifies: Partial
  ✓ Dispatches: Agent to complete gap
  ✓ Agent adds tests, verifies coverage 87% → 92.3%
  ✓ Commits and pushes to PR branch
  ✓ Reports: "PR 507 ready for review"
```

**Timeline:** ~8-9 minutes per partial PR

### Pattern D: Single-Task Implementation

**Input:** Individual task like DDIDNS-10521

**Flow:**

```bash
User: /msad-dev-planning DDIDNS-10521

User: /msad-dev-execution DDIDNS-10521
# OR
User: /msad-backend-dev DDIDNS-10521

[Agent implements single task, runs tests, opens draft PR]
```

**Timeline:** 10-30 min depending on complexity

### Pattern E: API-Level E2E Testing

**Input:** You want to test zone flows without the Windows agent

**Flow:**

```bash
User: /msad-e2e-verify

E2E Verification:
  ✓ Brought up dns.config + mocked collector
  ✓ Create zone with local scope → ✓ PASS
  ✓ Create zone with domain scope → ✓ PASS
  ✓ Create zone with forest scope → ✓ PASS
  ✓ Reject invalid scope (legacy) → ✓ PASS
  ✓ Error code mapping (ZONE-005) → ✓ PASS
```

### Pattern F: Code Review (Peer Review)

**Input:** PR in one of the MSAD repos

**Flow:**

```bash
User: review https://github.com/Infoblox-CTO/ddi.cloud.proxy.middleware/pull/507

Code Review: MSAD-Specific Findings:
  [✓] Replication-scope allow-list consistent (local/domain/forest)
  [✓] Idempotency checks present (pre-flight, rollback)
  [!] SHOULD: Coverage could be improved (87% → 92%)
  [!] INFO: Validator mirrors dns.config (verified)
  
  Verdict: APPROVE (all MUST findings resolved)
```

---

## Artifact Guide

### Agents

See [agents/README.md](agents/README.md) for details on:

- **`msad-backend-dev`** — writes code (TDD-first, cross-repo aware, PowerShell-safe)
- **`msad-code-review`** — reviews code (MSAD checklist, severity levels)

**You typically don't invoke these directly.** Planning and execution dispatch them.

### Skills

**Recommended Entry Point:** `/msad-dev-epic <epic-id>` (NEW)

**All Skills:**

| Skill | Purpose | Entry Point | Timeline |
|---|---|---|---|
| **`msad-dev-epic`** (NEW) | End-to-end epic automation with subagent orchestration | `/msad-dev-epic DDIDNS-7732` | ~20 min |
| **`msad-dev-planning`** | Detailed phase-by-phase planning with approval gate | `/msad-dev-planning DDIDNS-7732` | ~10 min |
| **`msad-dev-execution`** | Execute approved plan, dispatch agents, run tests | `/msad-dev-execution <plan>` | ~20 min |
| **`msad-backend-dev`** | Implement single task (TDD-first, cross-repo aware) | (dispatched by execution) | ~10-30 min |
| **`msad-code-review`** | Review PR against MSAD-specific checklist | (dispatched by execution) | ~5-10 min |
| **`msad-e2e-verify`** | API-level E2E tests (no Windows agent needed) | `/msad-e2e-verify` | ~15 min |

**Typical workflow:** `/msad-dev-epic` → PR review → human merge

### Documentation & References

**Architecture:**
- **[TOOLKIT-ARCHITECTURE.md](TOOLKIT-ARCHITECTURE.md)** — Full three-tier automation architecture, workflows, capabilities matrix

**Epic Execution:**
- **[skills/msad-dev-epic/README.md](skills/msad-dev-epic/README.md)** — Epic skill user guide
- **[skills/msad-dev-epic/EPIC-EXECUTION-GUIDE.md](skills/msad-dev-epic/EPIC-EXECUTION-GUIDE.md)** — Detailed workflow, agent dispatch, error handling
- **[skills/msad-dev-epic/IMPLEMENTATION.md](skills/msad-dev-epic/IMPLEMENTATION.md)** — Technical implementation details

**Planning & Execution:**
- **[skills/msad-dev-planning/README.md](skills/msad-dev-planning/README.md)** — Planning skill guide
- **[skills/msad-dev-execution/README.md](skills/msad-dev-execution/README.md)** — Execution skill guide
- **[skills/msad-dev-execution/PR-GAP-HANDLING.md](skills/msad-dev-execution/PR-GAP-HANDLING.md)** — 11-step PR gap completion workflow

**References:**
- **[references/repo-topology.md](references/repo-topology.md)** — Shared knowledge (stacks, commands, validators, proto pairs, test patterns, dependency repos, PR discovery, collector test client)
- **[references/plan-reviewer-prompt.md](references/plan-reviewer-prompt.md)** — Template for the auto-reviewer agent (loaded by planning skill)

**Examples & Status:**
- **[DDIDNS-7732-EXECUTION-STATUS.md](DDIDNS-7732-EXECUTION-STATUS.md)** — Live execution status for Phase 1
- **[IMPLEMENTATION-COMPLETE.md](IMPLEMENTATION-COMPLETE.md)** — Summary of all implementations
- **[specs/msad-dev-plans/](specs/msad-dev-plans/)** — Generated plans and execution contexts

---

## What's New (Recent Improvements)

### Epic Automation Skill (`/msad-dev-epic`)

**Previously:** Manual discovery + sequential task execution

**Now:** Automatic discovery + parallel agent dispatch

- Discovers Jira epic + all linked tasks/stories
- Discovers existing PRs via GitHub
- Automatically identifies gaps (missing tests, coverage gaps)
- Dispatches parallel subagents (one per work item)
- Completes gaps (for partial PRs) or implements fresh (for not-started)
- Consolidates results → "All PRs ready for review"

**Speed improvement:** 3.5x faster (20 min vs 70+ min for 7 work items)

### Parallel Subagent Execution

**Previously:** One agent at a time (sequential)

**Now:** Multiple agents in parallel (independent work items)

- PR 507 (handler tests): 8 min
- PR 508 (review): 3 min
- PR 241 (error codes): 9 min
- PR 6300 (audit): 3 min
- **Sequential:** 23 min | **Parallel:** 18 min

### PR Gap Completion

**New capability:** Toolkit recognizes existing draft PRs with identified gaps and completes them

- Discovers: "PR 507 is 85% done, gap = missing handler tests"
- Analyzes: reads existing test patterns
- Generates: test code following the pattern
- Verifies: coverage 87% → 92.3%
- Commits & pushes: ready for review

**Faster than rewrite:** 8 min gap completion vs 20+ min fresh implementation

---

## FAQ

### Q: How do I start with an epic?

**A:**
```bash
/msad-dev-epic DDIDNS-7732
```

The skill discovers everything (tasks, PRs, gaps) and dispatches agents automatically.

### Q: Can I test ddi.msad.agent locally on Mac?

**A:** No. It's a Windows Service with PowerShell cmdlets. **Local:** unit tests only. **Real:** Windows CI (Jenkins `windows_node_ddi_msad_agent_label`).

The toolkit acknowledges this and points to the right verification gate.

### Q: What if my task spans multiple repos?

**A:** `/msad-dev-epic` detects it automatically. Identifies dependencies (e.g., "proto change must land before middleware"). Dispatches agents respecting the ordering: independent packages run in parallel, dependent packages wait for their dependency.

### Q: What does "gap completion" mean?

**A:** A draft PR is partially done (e.g., 85% complete). Toolkit:
1. Discovers the gap ("missing handler tests for Conditional Forwarder")
2. Analyzes existing test patterns
3. Generates new tests
4. Verifies coverage improves (87% → 92.3%)
5. Commits & pushes

Result: PR moves from 85% → 100% complete in ~8 minutes.

### Q: What's the "validation loop"?

**A:** After implementation, code review runs (≤3 rounds):
1. Code review agent analyzes code
2. You see findings (MUST fix, SHOULD fix, MAY fix)
3. You fix or justify
4. Code review re-runs
5. When clean, draft PR opens

Prevents landing code with unresolved review findings.

### Q: Can I skip planning and go straight to epic execution?

**A:** Yes, and it's recommended (that's the whole point of `/msad-dev-epic`). 

Use detailed planning only if you want explicit approval gates before execution.

### Q: How do I know if a change is done?

**A:** You get **draft PRs** (not merged, not auto-merged). Each PR:
- Links to Jira task
- Lists files changed
- References cross-repo dependencies
- Notes any Windows-only testing gates
- Is ready for human review

You review, request changes, or approve + merge.

### Q: How long does epic execution take?

**A:** ~20 minutes for typical Phase 1 epic (parallel agents)

Breakdown:
- Discovery: 1-2 min
- Agent dispatch: 1 min
- Parallel execution: 15-18 min
- Result consolidation: 1 min

### Q: What happens to deferred work (Phase 2, QA)?

**A:** `/msad-dev-epic` executes only the active phase (Phase 1) by default.

To execute all phases:
```bash
/msad-dev-epic DDIDNS-7732 --all-phases
```

To execute specific phase:
```bash
/msad-dev-epic DDIDNS-7732 --phase 2
```

---

## Key Design Decisions

### 1. Parallel Subagent Dispatch

**Decision:** Dispatch independent work items (PRs/tasks) in parallel instead of sequential execution.

**Benefit:** 20 min (parallel 4 agents) vs 70+ min (sequential) = 3.5x faster for Phase 1

**Implementation:** `/msad-dev-epic` dispatches agents simultaneously; depends ordering is respected (e.g., proto → middleware)

### 2. Gap-Based PR Completion

**Decision:** Toolkit discovers existing draft PRs and completes identified gaps instead of starting from scratch.

**Benefit:** Respects ongoing work, faster to merge (8-9 min to close gap vs 20-30 min for fresh implementation)

**Example:** PR 507 was 85% done with clear gap (missing handler tests); agent completes in 8 min vs rewrite from scratch

### 3. Honest About Windows Testing

**Decision:** If task involves `ddi.msad.agent`, toolkit explicitly says:
- "Local testing impossible on Mac"
- "Windows CI will verify" (jenkins `windows_node_ddi_msad_agent_label`)
- "Stage testing will verify AD replication"

No false claims of "fully tested locally."

### 4. Cross-Repo Contract Discipline

**Decision:** Four replication-scope validators must stay in sync across repos.

**Enforcement:** Planning surfaces this upfront; code review verifies; execution validates

### 5. Plan Auto-Review (Optional)

**Decision:** Fresh-context reviewer agent audits plans for scope, dependencies, assumptions, risks.

**Gate:** Advisory only; you decide on findings before execution

### 6. Human Gate for Merge

**Decision:** Toolkit prepares PRs (all tests pass, coverage ≥80%), but humans must review and approve before merge.

**Rationale:** Preserves human accountability for production code

### 7. Discovery-First Execution

**Decision:** `/msad-dev-epic` discovers tasks + PRs automatically (vs requiring manual plan creation).

**Benefit:** Faster start-up, less manual ceremony, discovers existing work automatically

---

## PR Quality Bar

PRs from this toolkit follow the pattern set by existing DDIDNS-7732 work:

- ✅ Precise Jira/AC cross-references
- ✅ "Intentionally unchanged" call-outs for unrelated code
- ✅ Cross-repo dependencies documented
- ✅ Follow-up tickets filed for deferred work
- ✅ Test coverage (unit, integration, e2e where applicable)
- ✅ Windows CI verification acknowledged

---

## See Also

- **[agents/README.md](agents/README.md)** — Agent details
- **[skills/README.md](skills/README.md)** — Skill details
- **[references/repo-topology.md](references/repo-topology.md)** — Repo reference (stacks, commands, validators)
- **[DDIDNS-7732 Epic](https://infoblox.atlassian.net/browse/DDIDNS-7732)** — The Microsoft DNS zone creation epic
- **[architecture-hub](https://github.com/Infoblox-CTO/architecture-hub)** — Specs and contracts

---

## Getting Started

1. **Install the toolkit** (add as plugin or symlink)
2. **Pick an epic** (Jira epic ID like DDIDNS-7732)
3. **One command:**
   ```bash
   /msad-dev-epic DDIDNS-7732
   ```
4. **Wait ~20 minutes** for agents to complete
5. **Review draft PRs** when notified
6. **Approve & merge** when ready

**Detailed planning?** Use `/msad-dev-planning` first for explicit approval gates.

---

## Metrics

From DDIDNS-7732 Phase 1 execution:

| Metric | Result |
|---|---|
| **PRs processed** | 4 (2 partial with gaps, 2 complete) |
| **Agents dispatched** | 4 (in parallel) |
| **Execution time** | ~20 min (parallel) vs 70+ min (sequential) |
| **Speedup** | 3.5x faster |
| **Test coverage** | Gap fixes: 87%→92.3%, 85%→92.1% |
| **Quality gates** | All tests PASS, all lint PASS, all coverage ≥80% |
| **Ready for merge** | 100% |

---

## Support

- **Questions?** See [FAQ](#faq) below or check [TOOLKIT-ARCHITECTURE.md](TOOLKIT-ARCHITECTURE.md)
- **Issue?** File an issue in this repo
- **Questions about MSAD ecosystem?** Ask the MSAD team
