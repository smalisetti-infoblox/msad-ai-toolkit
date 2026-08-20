# MSAD AI Toolkit

**End-to-end automation for MSAD epic development.** Claude Code skills + subagents orchestrate multi-repo work across six repositories, from epic planning through PR-ready automation with automatic Backend/Frontend filtering.

**Core Workflow:** Epic → Structure (planner) → Orchestrate (parallel agents) → Code Review → PR-Ready (25 min total)

**Key Features:**
- 🎯 **Epic Planner** — Structure epics into Backend/Frontend/QA stories with repo-scoped tasks
- 🚀 **Parallel Orchestration** — Execute Backend work in parallel; auto-exclude Frontend/UI tasks (separate team)
- 📖 **Story-Scoped Execution** — Target one story instead of a full epic when you want a faster, narrower run
- ✅ **Automatic Quality Gates** — Tests, coverage ≥80%, linting all verified before PR
- 🔄 **Cross-Repo Coordination** — Handles proto sync, validator mirrors, error-code mapping
- 📝 **Jira Guidance** — Structured epic/story templates for optimal toolkit automation

**Mandatory Review Gates:** Every task passes a **bounded-reviewed, approved plan** before implementation. No code path skips planning.
- Structure-plan review (≤2 rounds) before stories are created in Jira
- Dev-plan review (≤3 rounds) before any implementation begins
- Code-review loop (≤3 rounds) before PRs are opened
- All using shared **bounded-review-loop pattern** with MUST/SHOULD/MAY triage and escalation on non-convergence
- **Deduplication built in:** existing stories, plans, and PRs are discovered and improved, never blindly recreated

**Quick Start:** See [Quick Start](#quick-start-recommended-fully-gated-pipeline) for your first epic, or [Usage Patterns](#usage-patterns) for worked examples.

---

## Table of Contents

- [Six-Repo Ecosystem](#six-repo-ecosystem) — Core repos + dependencies
- [Installation](#installation) — Setup options
- [Quick Start](#quick-start-recommended-fully-gated-pipeline) — The fully gated pipeline for new epics
- [Architecture](#architecture-fully-gated-pipeline) — Gate-by-gate pipeline diagram
- [Suggested Jira Structure](#suggested-jira-structure-for-toolkit-optimization) — Best practices for epic organization
- [Usage Patterns](#usage-patterns) — Worked examples
- [Skills & Agents Reference](#skills--agents-reference) — What each skill/agent does
- [FAQ](#faq)
- [References](#references--documentation) — Links to detailed docs

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

**Sync / Discovery Repos (reverse direction — MSAD → DDI):**

The six repos above handle DDI → MSAD (create/update/delete, initiated from the Portal/API). A separate pair of repos handles the reverse direction: discovering and syncing existing Microsoft DNS zone state (including zones with `legacy` replication scope, which can only ever arrive via this path — never via creation) back into DDI.

| Repo | Stack | Role |
|---|---|---|
| **cq-source-msad** | Go | CloudQuery source plugin; fetches zones/records from the MSAD collector (read-only, no allow-list validation) |
| **cloud.discovery** | Go | Discovers resources from 20+ providers including MSAD; fans out to BloxOne DDI via the `b1ddi` overlay adapter |

**Dependency Repos (referenced, not owned):**

| Repo | Role |
|---|---|
| **atlas.onprem.rpc.server** | Proto-contract dependency of ddi.msadconnect.proxy and ddi.msad.agent (Windows RPC/gRPC dispatcher) |
| **atlas.onprem.common** | Go module dependency of ddi.msadconnect.proxy (common utilities) |

See `references/repo-topology.md` for the full two-direction request-flow diagram (write path + sync path, with every validation point cited to source) and "Dependency Repos" for how to discover and track additional dependencies.

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

### Contributing to This Toolkit (Not the MSAD Repos)

If you're editing the toolkit itself (skills, agents, references, this README) rather than using it to work on the six MSAD repos, enable the doc-drift pre-commit hook once per clone:

```bash
cd ~/msad-ai-toolkit
git config core.hooksPath .githooks
```

This blocks commits that (a) add/remove a repo in `references/repo-topology.md` without updating README.md to match, or (b) change `skills/`, `agents/`, `references/`, or `CLAUDE.md` without touching any documentation file. See `.githooks/pre-commit` for the exact checks and the `SKIP_DOC_CHECK=1` escape hatch for genuinely internal changes.

---

## Quick Start (Recommended): Fully Gated Pipeline

Every task requires an **approved, bounded-reviewed plan** before any code is written. This ensures no duplicate work, respects existing PRs, and makes reviews easier.

### Step 1: Structure Your Epic (With Review Gate)

You have a rough idea. **First, structure the epic:**

```bash
/msad-plan-epic DDIDNS-7732
```

**What happens:**
1. Analyzes epic scope (repos, features, dependencies)
2. Decomposes into Backend/Frontend/QA stories (with Gherkin scenarios)
3. Writes structure plan to disk (`specs/msad-epic-plans/...`)
4. **Runs bounded review loop** (≤2 rounds, fresh-context reviewer)
5. **Presents plan for user approval** ← HARD STOP until approved

**Timeline:** ~10 minutes (including review + approval)

**Result:** Approved structure plan with Backend stories (toolkit-ready) + Frontend stories (separate team) + QA stories

### Step 2: Create Stories in Jira (Gated on Approval)

Once structure plan is **approved**, create stories:

```bash
/msad-plan-epic DDIDNS-7732 --create
```

**What happens:**
- Verifies plan status is `approved` (refuses if status is `draft`)
- Uses Atlassian MCP to create stories + tasks in Jira
- Links all tasks to their parent story
- Links all stories to the epic

**Timeline:** ~2 minutes

**Result:** Jira stories/tasks created per approved structure

### Step 3: Execute the Epic (With Planning Gates Per Story)

Your epic is structured and approved. **Run:**

```bash
/msad-dev-epic DDIDNS-7732
```

**What happens (automatically, per story):**

1. **Discover** → Fetch epic, list Backend stories/tasks, find existing PRs (prefer to complete existing PRs, not create duplicates)
2. For each Backend task:
   - Check if approved dev plan exists; if not, invoke `/msad-dev-planning` (plan creation + bounded review + user approval)
   - Invoke `/msad-dev-execution` (implementation + parallel batches + bounded code-review + draft PR)
3. **Report** → "All Backend PRs ready for human review. Frontend tasks excluded (separate team)."

**Timeline:** ~30 minutes total (includes per-story planning gates + implementation)

**Result:** All Backend PRs ready for human review + merge; every change has a reviewed plan behind it

---

## Architecture: Fully Gated Pipeline

Every task requires an **approved, bounded-reviewed plan** before implementation. No code path skips planning.

```
┌─ EPIC LEVEL ─────────────────────────────────────────┐
│                                                      │
│  Step 1: /msad-plan-epic DDIDNS-7732 (5-10 min)    │
│  ├─ Analyze epic scope                             │
│  ├─ Decompose into Backend/Frontend/QA stories     │
│  ├─ Author Gherkin acceptance criteria             │
│  └─ Write structure plan → specs/msad-epic-plans/  │
│                                                      │
│  Step 2: Bounded Structure-Plan Review (≤2 rounds) │
│  ├─ Fresh-context reviewer checks decomposition    │
│  ├─ Triage findings: MUST / SHOULD / MAY            │
│  └─ Converge on final plan                         │
│                                                      │
│  Step 3: User Approval Gate (HARD STOP)            │
│  └─ Plan status: draft → approved (required for creation)
│                                                      │
│  Step 4: /msad-plan-epic DDIDNS-7732 --create     │
│  └─ Create Backend stories + tasks in Jira         │
│                                                      │
└──────────────────────────────────────────────────────┘
                          ↓
┌─ STORY/TASK LEVEL (per story) ───────────────────────┐
│                                                      │
│  Step 5: /msad-dev-planning DDIDNS-10562 (10 min)  │
│  ├─ Analyze story scope, acceptance criteria       │
│  ├─ Identify per-repo work packages                │
│  ├─ Detect conflicts (file-level), compute parallel batches
│  ├─ Map Gherkin scenarios → TDD tests              │
│  └─ Write dev plan → specs/msad-dev-plans/         │
│                                                      │
│  Step 6: Bounded Dev-Plan Review (≤3 rounds)       │
│  ├─ Fresh-context reviewer checks implementation   │
│  ├─ Triage findings: MUST / SHOULD / MAY            │
│  └─ Converge on final plan                         │
│                                                      │
│  Step 7: User Approval Gate (HARD STOP)            │
│  └─ Plan status: draft → approved (required for execution)
│                                                      │
└──────────────────────────────────────────────────────┘
                          ↓
┌─ EXECUTION (per parallel batch) ─────────────────────┐
│                                                      │
│  Step 8: /msad-dev-execution <plan> (15-20 min)    │
│  ├─ Dispatch msad-backend-dev per conflict-aware   │
│  │  batches (parallel-safe, no file conflicts)     │
│  ├─ Run per-repo tests (docker-compose, make test) │
│  │                                                  │
│  ├─ Bounded Code-Review Loop (≤3 rounds)           │
│  │  ├─ msad-code-review runs on diff               │
│  │  ├─ Triage findings: MUST / SHOULD / MAY         │
│  │  ├─ Verify scenario → test traceability         │
│  │  └─ Converge or escalate to user                │
│  │                                                  │
│  └─ Open Draft PRs (per repo)                       │
│     └─ Rich template: What/Why/How/Scenarios/Tests │
│                                                      │
└──────────────────────────────────────────────────────┘
                          ↓
                 HUMAN REVIEW GATE
              (merge is never automated)
```

**Typical flow:**
1. `/msad-plan-epic` → structure plan review → approval → create stories (one-time per epic)
2. Per story: `/msad-dev-planning` → dev plan review → approval → `/msad-dev-execution` (parallel batches)

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
- `/msad-dev-epic DDIDNS-10562 --scope story` orchestrates a single Backend story (faster, fewer tasks in flight)
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
- `/msad-dev-epic DDIDNS-10562 --scope story` discovers all linked tasks, classifies Backend (skips any with UI keywords), finds existing PRs, and loops each task through planning (if needed) + execution
- Typical timeline: 10–15 minutes for a focused story (each task still requires an approved plan before implementation)

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
│  [/msad-dev-epic DDIDNS-10562 --scope story → plan+execute 4 tasks → ~15 min]
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

### Pattern A: Full Epic, First Time

**Input:** New epic like DDIDNS-7732 with no stories yet.

```bash
/msad-plan-epic DDIDNS-7732
#   → structure plan written, bounded review (≤2 rounds), user approval gate

/msad-plan-epic DDIDNS-7732 --create
#   → creates Backend/Frontend/QA stories + tasks in Jira (refuses duplicates)

/msad-dev-epic DDIDNS-10562
#   → for each Backend task in the story:
#       - approved plan missing? runs /msad-dev-planning (bounded review ≤3 rounds, user approval)
#       - runs /msad-dev-execution (parallel batches, bounded code review ≤3 rounds, draft PR)
```

**Timeline:** ~10 min (structure + approval) + ~2 min (create) + ~30 min per story (planning gates + execution)

**Result:** Draft PRs ready for human review; Frontend/QA stories tracked separately.

### Pattern B: Epic Already Has Stories

**Input:** Epic/story already structured in Jira (e.g., from a previous `/msad-plan-epic` run).

```bash
/msad-dev-epic DDIDNS-10562 --scope story
```

Skips structure planning entirely. Loops per task: approved plan exists? execute; otherwise plan → review → approval → execute.

### Pattern C: Single Task, Detailed Control

**Input:** One task, e.g., DDIDNS-10521.

```bash
/msad-dev-planning DDIDNS-10521
#   → dev plan, bounded review (≤3 rounds), user approval

/msad-dev-execution <plan-path>
#   → implementation, bounded code review (≤3 rounds), draft PR
```

Use this when you want to review/approve a single task's plan without going through epic/story orchestration.

### Pattern D: Complete an Existing PR

**Input:** A draft/open PR already exists for a task (e.g., from a previous partial run).

`/msad-dev-planning` and `/msad-dev-epic` both discover existing PRs automatically (state, blocking findings, coverage) and prefer completing them over opening a duplicate. No special flag needed — just re-run the normal flow for that task.

### Pattern E: API-Level E2E Testing

```bash
/msad-e2e-verify
```

Brings up `dns.config` + a mocked collector and drives zone create/update flows via WAPI v3 (no Windows agent required).

### Pattern F: Ad-Hoc Code Review

```bash
review https://github.com/Infoblox-CTO/ddi.cloud.proxy.middleware/pull/507
```

Runs `msad-code-review` against MSAD-specific checklist (validator sync, idempotency, error-code mapping, PowerShell/LDAP safety) plus general code quality — independent of the planning/execution flow, for peer review of any PR.

---

## Skills & Agents Reference

| Skill | Purpose | Entry Point |
|---|---|---|
| **`msad-plan-epic`** | Structure an epic into Backend/Frontend/QA stories with Gherkin ACs; bounded review + approval gate before Jira creation | `/msad-plan-epic DDIDNS-7732` |
| **`msad-dev-epic`** | Orchestrate a Backend epic or single story; loops each task through planning (if needed) then execution | `/msad-dev-epic DDIDNS-7732` (or `--scope story`) |
| **`msad-dev-planning`** | Produce a per-task/story dev plan (Gherkin traceability, conflict-aware batches); bounded review + approval gate | `/msad-dev-planning DDIDNS-10519` |
| **`msad-dev-execution`** | Execute an approved plan: dispatch implementation agents per conflict-safe batch, bounded code review, draft PR | `/msad-dev-execution <plan-path>` |
| **`msad-developer`** | Router — classifies input (epic/story/task) and suggests the right skill | `/msad-developer` |
| **`msad-e2e-verify`** | API-level E2E tests without the Windows agent | `/msad-e2e-verify` |

**Agents** (dispatched internally — you don't invoke these directly):

| Agent | Purpose |
|---|---|
| **`msad-backend-dev`** | Implements a single task: TDD-first, cross-repo aware, PowerShell/LDAP-safe |
| **`msad-code-review`** | Reviews a diff against the MSAD checklist (validator sync, idempotency, error codes) + general code quality, severity MUST/SHOULD/MAY |

See [skills/README.md](skills/README.md) and [agents/README.md](agents/README.md) for full details.

---

## PR Quality Bar

PRs opened by this toolkit:

- ✅ Precise Jira/AC cross-references, with Gherkin scenario → test traceability
- ✅ "Intentionally unchanged" call-outs for unrelated code
- ✅ Cross-repo dependencies documented (proto regen, validator sync)
- ✅ Follow-up tickets filed for deferred work
- ✅ Test coverage reported (unit, integration, e2e where applicable)
- ✅ Windows CI verification acknowledged (ddi.msad.agent)
- ✅ Always **draft** — human review and merge is never automated

---

## FAQ

**My epic has no stories/tasks yet. What do I do?**
Run `/msad-plan-epic DDIDNS-7732`. It analyzes the epic and proposes Backend/Frontend/QA stories with repo-scoped tasks; you review and approve before anything is created in Jira.

**Can I skip planning and go straight to execution?**
No — this is by design. `/msad-dev-execution` refuses to run against a plan whose `status` isn't `approved`, and `/msad-dev-epic` always routes through planning first. This prevents scope creep and undocumented changes; see [Architecture](#architecture-fully-gated-pipeline).

**What if the epic/story already has stories or a plan?**
The toolkit checks first. `/msad-plan-epic` won't recreate an existing story (it points you to `/msad-dev-epic <id>` to improve it instead); `/msad-dev-planning` detects an existing approved/draft plan and offers to reuse it rather than duplicate it.

**How do I execute just one story instead of the full epic?**
`/msad-dev-epic <story-id> --scope story` — same gating, narrower scope, fewer tasks in flight.

**What if a task already has a draft PR from a previous run?**
It's discovered automatically (state, blocking review comments, coverage) and completed in place — the toolkit checks out the existing branch rather than opening a duplicate PR.

**Can I test `ddi.msad.agent` locally on Mac?**
No — it's a Windows Service with PowerShell cmdlets. Unit tests run locally; full verification happens on Windows CI (`windows_node_ddi_msad_agent_label`). The toolkit states this explicitly rather than claiming false local coverage.

**What does the bounded review loop actually do?**
Runs a fresh-context reviewer, triages findings as MUST/SHOULD/MAY, and loops (fix → re-review) until zero MUST findings remain or the round cap is hit (2 for structure plans, 3 for dev plans and code review). If it doesn't converge, it stops and hands you the full findings + ledger — never silently proceeds or loops forever.

**Are there limits on epic size?**
No hard limit. For a large epic (6+ stories), still start with `/msad-plan-epic` — the structure plan and per-story gating scale the same way regardless of size.

---

## References — Documentation

**Getting Started:**
- **[CLAUDE.md](CLAUDE.md)** — Fork pattern setup (one-time)
- **[CONTRIBUTING.md](CONTRIBUTING.md)** — Contribution workflow, 6-repo setup

**Skill & Agent Details:**
- **[skills/README.md](skills/README.md)** — All 6 skills + orchestration
- **[agents/README.md](agents/README.md)** — Agent details + MSAD checklist

**Reference Material — Gated Pipeline & Standards:**
- **[references/bounded-review-loop.md](references/bounded-review-loop.md)** — Shared parameterized review loop (max_rounds, MUST/SHOULD/MAY, convergence, escalation)
- **[references/functional-area-classification.md](references/functional-area-classification.md)** — Backend/Frontend/QA signals (definitive keyword list)
- **[references/bdd-acceptance-criteria.md](references/bdd-acceptance-criteria.md)** — Gherkin authoring + test-traceability rules (no new runner, native TDD only)
- **[references/plan-reviewer-prompt.md](references/plan-reviewer-prompt.md)** — Dev plan review checklist (per-task planning)
- **[references/structure-plan-reviewer-prompt.md](references/structure-plan-reviewer-prompt.md)** — Structure plan review checklist (epic decomposition)

**Reference Material — Repository & Commit Standards:**
- **[references/repo-topology.md](references/repo-topology.md)** — 6 repos (stack, commands, validators, files, contracts)
- **[references/default-branches.md](references/default-branches.md)** — Per-repo default branch
- **[references/git-commit-discipline.md](references/git-commit-discipline.md)** — Atomic commit patterns (additions → modifications → deletions)

**External Links:**
- **[DDIDNS-7732 Epic](https://infoblox.atlassian.net/browse/DDIDNS-7732)** — First epic run through this toolkit (Microsoft DNS zone creation with replication scope); used as the worked example throughout this doc, not the toolkit's scope
- **[architecture-hub](https://github.com/Infoblox-CTO/architecture-hub)** — Specs, contracts, design docs
- **[Infoblox-CTO GitHub](https://github.com/Infoblox-CTO)** — All 6 canonical repos
