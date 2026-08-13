# MSAD AI Toolkit

**End-to-end automation for MSAD epic development.** Claude Code skills + subagents orchestrate multi-repo work across six repositories, from epic planning through PR-ready automation with automatic Backend/Frontend filtering.

**Core Workflow:** Epic → Structure (planner) → Orchestrate (parallel agents) → Code Review → PR-Ready (25 min total)

**Key Features:**
- 🎯 **Epic Planner** — Structure epics into Backend/Frontend/QA stories with repo-scoped tasks
- 🚀 **Parallel Orchestration** — Execute Backend work in parallel; auto-exclude Frontend/UI tasks (separate team)
- 📖 **Story-Level Execution** — Run single stories faster (10-15 min) when needed
- ✅ **Automatic Quality Gates** — Tests, coverage ≥80%, linting all verified before PR
- 🔄 **Cross-Repo Coordination** — Handles proto sync, validator mirrors, error-code mapping
- 📝 **Jira Guidance** — Structured epic/story templates for optimal toolkit automation

**Quick Start:** See [Quick Start](#quick-start-recommended) for your first epic, or [Usage Patterns](#usage-patterns) for worked examples.

---

## Table of Contents

- [Six-Repo Ecosystem](#six-repo-ecosystem) — Core repos + dependencies
- [Installation](#installation) — Setup options
- [Quick Start](#quick-start-recommended) — Two-step workflow for new epics
- [Other Epic Patterns](#other-epic-patterns) — Story-level execution, detailed planning
- [Architecture](#architecture-four-tier-automation) — Four-tier automation model
- [Suggested Jira Structure](#suggested-jira-structure-for-toolkit-optimization) — Best practices for epic organization
- [Usage Patterns](#usage-patterns) — Worked examples (Quick Epic, Detailed Plan, PR Gaps)
- [Troubleshooting & FAQ](#troubleshooting--faq)
- [References](#references-documentation) — Links to detailed docs

---

## Six-Repo Ecosystem

| Repo | Stack | Role |
|---|---|---|
| **ddi.dns.config** | Go | WAPI v3 API surface; replication-scope validation |
| **ddi.dns.data** | Go | WAPI v3 data layer; zone data retrieval and transformation |
| **ddi.cloud.proxy.middleware** | Go | gRPC interceptor library; MSAD request translation (shared by dns.config and dns.data) |
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

## Organization & Fork Pattern

**All repos live in the [Infoblox-CTO](https://github.com/Infoblox-CTO) organization.**

This toolkit uses a **fork-based contribution model**:
- Clone repos from **Infoblox-CTO** (canonical)
- Push changes to your **personal fork**
- Open PRs to **Infoblox-CTO/main**

See **[CLAUDE.md](CLAUDE.md)** for setup instructions and **[CONTRIBUTING.md](CONTRIBUTING.md)** for the full workflow.

---

## Installation

### Option 1: Add as Claude Code Plugin (Recommended)

```bash
# Clone the toolkit
git clone https://github.com/Infoblox-CTO/msad-ai-toolkit.git ~/msad-ai-toolkit

# In Claude Code: Settings → Plugins → Add Local Plugin
# Path: ~/msad-ai-toolkit
```

**First Time?** Follow [CLAUDE.md](CLAUDE.md) to fork and configure the six MSAD repos.

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

### Step 1: Structure Your Epic (One-Time)

You have a rough idea. **First, structure the epic:**

```bash
/msad-plan-epic DDIDNS-7732
```

**What happens:**
1. Analyzes epic scope (what repos, what features)
2. Recommends Backend/Frontend/QA story breakdown
3. Suggests per-story tasks (one task per repo with changes)
4. Creates stories/tasks in Jira (or shows template)

**Timeline:** ~5 minutes

**Result:** Structured epic with Backend stories (toolkit-ready) + Frontend stories (separate team) + QA stories

### Step 2: Execute the Epic

Your epic is now structured. **Run:**

```bash
/msad-dev-epic DDIDNS-7732
```

**What happens (automatically):**

1. **Discover** → Fetch epic, list all Backend stories/tasks, find existing PRs
2. **Classify** → Identify partial PRs (gaps to close), complete PRs, not-started tasks; **filter out Frontend/UI tasks**
3. **Dispatch** → Launch parallel subagents (one per Backend work item)
4. **Consolidate** → Collect results, verify tests + coverage
5. **Report** → "All 7 Backend PRs ready for human review. 3 Frontend tasks excluded (separate team)."

**Timeline:** ~20 minutes total (parallel execution)

**Result:** All Backend PRs ready for human review + merge; Frontend team works in parallel

---

## Other Epic Patterns

### Story-Level Execution (Faster Single-Story Focus)

```bash
/msad-dev-story DDIDNS-10562
```

Same discovery, classification, and dispatch as epic skill, but **scoped to one story** (fewer agents, typically 2–4 instead of 6–8). Excludes Frontend/UI tasks.

**Timeline:** ~10–15 minutes

**When to use:**
- You want to complete a single story within an epic
- Faster than full epic orchestration
- Still gets Backend/Frontend filtering and consolidated reporting

### Advanced: Detailed Planning + Execution

If you want explicit approval gates or detailed analysis before execution:

#### Step 1: Generate Detailed Plan

```bash
/msad-dev-planning DDIDNS-7732
```

**What happens:**
- Reads epic + all linked tasks
- Groups work by repo, identifies dependencies, **classifies Backend vs. Frontend/UI**
- Runs fresh-context reviewer to catch gaps
- Presents plan for your approval

#### Step 2: Execute Approved Plan

```bash
/msad-dev-execution DDIDNS-7732
```

**What happens:**
- Dispatches implementation agents per Backend work package
- Runs tests (docker-compose, go test, dotnet test)
- Validation loop (≤3 rounds): code review → findings → fixes
- Opens draft PRs when all Backend gates pass
- Reports excluded Frontend/UI tasks

---

## Architecture: Four-Tier Automation

```
Tier 0: /msad-plan-epic (5 min) ← START HERE for new epic
  ↓ Structure epic into Backend/Frontend/QA stories
  
Tier 1: /msad-dev-planning (10 min) ← for detailed approval gates
  ↓ Generate detailed implementation plan
  
Tier 2a: /msad-dev-epic (20 min) ← RECOMMENDED for full epic release
  ↓ Orchestrate all stories + tasks, automated discovery
  
Tier 2b: /msad-dev-story (10–15 min) ← RECOMMENDED for single story
  ↓ Orchestrate one story, faster granular execution
  
Tier 3: /msad-dev-execution (20 min) ← from approved plan
  ↓ Agent-driven implementation + validation loop
  
Manual: /msad-backend-dev (10-30 min)
  ↓ Single-task implementation
```

**Typical flow:**
1. Start with `/msad-plan-epic` (structure the epic once)
2. Then use `/msad-dev-epic` or `/msad-dev-story` (execute repeatedly as stories change)

---

## Suggested Jira Structure for Toolkit Optimization

The toolkit works best when epics and stories are structured thoughtfully. Here's the recommended pattern:

### Epic Structure (Multi-Story Initiative)

**Example: DDIDNS-7732 — Microsoft DNS Zone Creation with Replication Scope**

```
DDIDNS-7732 (Epic: "Microsoft DNS Zone Creation")
├── DDIDNS-10562 (Story: "Backend — Support Domain/Forest Replication Scope")
│   ├── DDIDNS-10519 (Task: middleware — request transformation)
│   ├── DDIDNS-10542 (Task: middleware — idempotency)
│   ├── DDIDNS-10543 (Task: collector — error-code mapping)
│   └── DDIDNS-10546 (Task: dns.config — audit logging)
│
├── DDIDNS-10563 (Story: "Frontend — Portal UI for Replication Scope Selection")
│   ├── DDIDNS-10544 (Task: Portal selector component)
│   ├── DDIDNS-10548 (Task: Portal form validation)
│   └── DDIDNS-10545 (Task: Portal documentation)
│
└── DDIDNS-10567 (Story: "QA — E2E Testing for Zone Replication")
    ├── DDIDNS-10510 (Task: test plan)
    └── DDIDNS-10511 (Task: automation)
```

**Best Practices:**

1. **Separate Backend and Frontend stories.** Tag story title with `"Backend —"` or `"Frontend —"` or `"Portal —"` so the toolkit can classify and filter automatically.
2. **One logical concern per story.** Each story represents a deliverable unit (e.g., "Support Domain/Forest scopes" vs. "Portal UI for scope selection").
3. **Backend stories contain backend tasks only.** Frontend stories contain UI tasks only. Don't mix.
4. **Link all tasks to exactly one story.** The toolkit expects a clean hierarchy: Epic → Stories → Tasks.
5. **Use consistent naming:** Task title should mention the repo or layer (e.g., "middleware: support Domain/Forest", "collector: add error codes", "dns.config: validation").

**What the toolkit does:**
- `/msad-dev-epic DDIDNS-7732` orchestrates all Backend stories (skips Frontend stories, lists them as excluded)
- `/msad-dev-story DDIDNS-10562` orchestrates a single Backend story (faster, fewer agents)
- Frontend stories are explicitly noted as "managed by separate team"

### Story Structure (Focused Deliverable)

**Example: DDIDNS-10562 — Backend Support for Domain/Forest Replication Scope**

```
DDIDNS-10562 (Story: "Backend — Support Domain/Forest Replication Scope on Zone Creation")
  
Description:
  Add support for Domain and Forest replication scopes on zone creation requests.
  This enables users to create Microsoft DNS zones with different replication scopes
  via the WAPI v3 API.

Acceptance Criteria:
  ✓ WAPI v3 accepts replication_scope = "domain" and "forest" on zone creation
  ✓ Values are validated at each layer (dns.config, middleware, collector)
  ✓ Middleware forwards correct scope to MSAD collector
  ✓ Error codes are mapped correctly (invalid scope → 400 Bad Request)
  ✓ Existing tests pass; new tests cover scope validation

Linked Tasks:
  ├── DDIDNS-10519 (Task: ddi.cloud.proxy.middleware: validate & transform)
  ├── DDIDNS-10542 (Task: ddi.cloud.proxy.middleware: idempotency)
  ├── DDIDNS-10543 (Task: ddi.msad.collector: error-code mapping)
  └── DDIDNS-10546 (Task: ddi.dns.config: audit logging)
```

**Best Practices:**

1. **Clear AC mapping.** Each AC maps to one or more tasks. The toolkit verifies all ACs are covered in the plan.
2. **Repo-scoped tasks.** Each task title mentions the repo (middleware, collector, dns.config) so the toolkit can organize work by repo.
3. **Single story focus.** A story is one vertical slice (one replication-scope feature, one error-code addition). Don't bundle unrelated work.
4. **"Backend —" prefix.** Use this to signal the toolkit that the story is backend-only (not Portal UI). Frontend stories use `"Frontend —"` or `"Portal —"`.

**What the toolkit does:**
- `/msad-dev-story DDIDNS-10562` discovers all linked tasks, classifies Backend (skips any with UI keywords), finds existing PRs, and orchestrates 4 agents in parallel
- Typical timeline: 10–15 minutes (all Backend work done, ready for review)

### Backend vs. Frontend Task Naming

The toolkit uses keyword matching to classify tasks automatically. Here's the signal list:

**Backend signals** (task will be automated by toolkit):
- Repo names: `middleware`, `collector`, `agent`, `dns.config`, `dns.data`, `proxy`
- Layer names: `backend`, `API`, `gRPC`, `validation`, `handler`, `interceptor`
- Examples:
  - `"middleware: support Domain/Forest replication scope"`
  - `"collector: add error-code mapping for ZONE-005"`
  - `"dns.config: validate replication scope"`

**Frontend/UI signals** (task will be flagged as excluded, managed separately):
- UI keywords: `portal`, `UI`, `frontend`, `form`, `selector`, `editor`, `component`, `view`
- Examples:
  - `"Portal selector for replication scope"`
  - `"Frontend form validation for scope changes"`
  - `"UI component for zone configuration"`

**Default:** If a task name has no signals (ambiguous), the toolkit classifies it as **Backend** and dispatches it. To ensure a task is excluded, use explicit Frontend/UI keywords.

### Example: Full Epic to Story Hierarchy

```
DDIDNS-7732 (Epic: "Microsoft DNS Zone Creation with Replication Scope")
  
├─ Story 1: DDIDNS-10562 "Backend — Zone Creation with Scope"
│  │
│  ├─ Task: "ddi.cloud.proxy.middleware: transform scope in gRPC request"
│  ├─ Task: "ddi.cloud.proxy.middleware: add idempotency check"
│  ├─ Task: "ddi.msad.collector: map ZONE-005 error code"
│  └─ Task: "ddi.dns.config: validate replication scope on create"
│  
│  [/msad-dev-story DDIDNS-10562 → orchestrates 4 agents → 15 min]
│
├─ Story 2: DDIDNS-10563 "Frontend — Portal UI for Scope Selection"
│  │
│  ├─ Task: "Portal: add selector component for scope"
│  ├─ Task: "Portal: add form validation"
│  └─ Task: "Portal: update documentation"
│  
│  [NOT orchestrated by toolkit — managed by Frontend team]
│
└─ Story 3: DDIDNS-10567 "QA — E2E Testing"
   │
   ├─ Task: "test plan for scope changes"
   └─ Task: "CI/CD automation"
   
   [/msad-e2e-verify covers API-level testing]

Full Epic Flow:
  /msad-dev-epic DDIDNS-7732
  ├─ Discovers: 3 stories (1 Backend, 1 Frontend, 1 QA)
  ├─ Classifies: Backend story + tasks → dispatch; Frontend story → exclude
  ├─ Dispatch: Orchestrates Backend story (4 agents)
  └─ Report: "4/4 Backend PRs ready. 1 Frontend story excluded (managed separately)."
  
  Timeline: ~20 min for Backend track; Frontend track runs in parallel
```

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

## Troubleshooting & FAQ

### "My epic has no stories/tasks yet. What do I do?"

Use `/msad-plan-epic EPIC-ID` to analyze the epic and generate a recommended structure. It creates Backend/Frontend/QA stories with repo-scoped tasks automatically.

### "Can I run this on an epic with mixed Backend/Frontend tasks?"

Yes! The toolkit automatically classifies Backend vs. Frontend/UI tasks using keywords. Frontend tasks are excluded from dispatch and reported as "managed by separate team". **See [Backend vs. Frontend Task Naming](#backend-vs-frontend-task-naming) for the signal keywords.**

### "How do I execute just one story instead of the full epic?"

Use `/msad-dev-story STORY-ID` for faster, single-story orchestration (10-15 min vs 20 min for full epic). Same Backend/Frontend filtering applies.

### "What if a task fails during execution?"

The failing agent will stop and report the issue. You have three options:
1. **Fix locally** and restart the agent with more context
2. **Skip the task** and run other tasks (manual completion later)
3. **Ask for detailed plan** via `/msad-dev-planning` for more control

### "Do I need to structure the epic in a specific way?"

Yes, for optimal toolkit performance. **See [Suggested Jira Structure](#suggested-jira-structure-for-toolkit-optimization)** for the recommended Epic → Story → Task hierarchy. Or use `/msad-plan-epic` to generate it.

### "What repos should I expect PRs in?"

Depends on your task. **See [references/repo-topology.md](references/repo-topology.md) for which repos are involved**. For zone creation tasks, expect PRs in: dns.config, dns.data, middleware, collector, agent.

### "Can I use this for non-MSAD work?"

This toolkit is MSAD-specific (zone creation, replication scope, error codes, Windows agent). For other work, see if `architecture-hub` has other toolkit templates.

### "How do I troubleshoot a plan?"

Use `/msad-dev-planning EPIC-ID` with the `--edit` or `--review` flags to audit the plan interactively. The plan auto-review agent flags gaps, unclear dependencies, and missing AC coverage.

### "Are there limits on epic size?"

No hard limits, but practical guidance:
- **Small epic (1–2 stories, 3–5 tasks):** Use `/msad-dev-story` (faster)
- **Medium epic (3–5 stories, 10–15 tasks):** Use `/msad-dev-epic` (20 min)
- **Large epic (6+ stories, 20+ tasks):** Use `/msad-dev-planning` first for detailed coordination

---

## References — Documentation

**Getting Started:**
- **[CLAUDE.md](CLAUDE.md)** — Fork pattern setup (one-time)
- **[CONTRIBUTING.md](CONTRIBUTING.md)** — Contribution workflow, 6-repo setup

**Skill & Agent Details:**
- **[skills/README.md](skills/README.md)** — All 7 skills + dependency chain
  - `/msad-plan-epic` — Structure epics (NEW)
  - `/msad-dev-epic` — Execute epic (updated)
  - `/msad-dev-story` — Execute story (NEW)
  - `/msad-dev-planning` — Detailed plan
  - `/msad-developer` — Router
  - `/msad-dev-execution` — From approved plan
  - `/msad-e2e-verify` — API-level E2E tests
- **[agents/README.md](agents/README.md)** — Agent details + MSAD checklist

**Reference Material:**
- **[references/repo-topology.md](references/repo-topology.md)** — 6 repos (stack, commands, validators, files, contracts)
- **[references/default-branches.md](references/default-branches.md)** — Per-repo default branch
- **[references/git-commit-discipline.md](references/git-commit-discipline.md)** — Commit patterns
- **[references/plan-reviewer-prompt.md](references/plan-reviewer-prompt.md)** — Plan review checklist

**External Links:**
- **[DDIDNS-7732 Epic](https://infoblox.atlassian.net/browse/DDIDNS-7732)** — The canonical zone creation epic
- **[architecture-hub](https://github.com/Infoblox-CTO/architecture-hub)** — Specs, contracts, design docs
- **[Infoblox-CTO GitHub](https://github.com/Infoblox-CTO)** — All 6 canonical repos

---

## Getting Started

### Fastest Path (Recommended)

1. **Install the toolkit** — See [Installation](#installation)
2. **Have a Jira epic** (e.g., DDIDNS-7732)
3. **Three commands:**
   ```bash
   /msad-plan-epic DDIDNS-7732    # (5 min) Structure the epic
   /msad-dev-epic DDIDNS-7732        # (20 min) Execute all Backend stories in parallel
   ```
4. **Review draft PRs** when notified (parallel to Frontend team's work)
5. **Approve & merge** when ready

### Alternative: Detailed Planning + Execution

For more control or complex dependencies:

```bash
/msad-dev-planning DDIDNS-7732      # (10 min) Generate detailed plan + auto-review
# → Approve plan
/msad-dev-execution DDIDNS-7732     # (20 min) Execute with validation loop (≤3 rounds)
```

### For Single Story (Faster)

```bash
/msad-dev-story DDIDNS-10562        # (10-15 min) Execute one story
```

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
