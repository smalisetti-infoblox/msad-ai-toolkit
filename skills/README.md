# MSAD Skills

Six orchestration skills that drive the multi-repo MSAD development workflow. Each skill is self-contained and can be invoked independently, but typically they form a chain: **epic-planner → planning → epic/story execution**.

---

## Quick Reference

| Skill | Use When | Invokes |
|---|---|---|
| **msad-epic-planner** | You have a rough epic idea; need to structure it | Atlassian MCP (creates stories/tasks) |
| **msad-developer** | You have a Jira task (epic/story) | Nothing (suggests planning or execution) |
| **msad-dev-planning** | You need a detailed plan (plan doesn't exist yet) | No sub-agents (dispatches reviewer internally) |
| **msad-dev-epic** | You have a structured epic; want to orchestrate all stories + tasks | Parallel msad-backend-dev agents (Backend tasks only) |
| **msad-dev-story** | You have a story; want to orchestrate its tasks | Parallel msad-backend-dev agents (Backend tasks only) |
| **msad-dev-execution** | You have an approved plan | msad-backend-dev + msad-code-review agents |
| **msad-e2e-verify** | You want API-level E2E tests (no Windows agent) | Docker, curl (no agents) |

---

## msad-developer (Router)

**Entry point for any MSAD development task.**

Classifies your input and suggests the right downstream skill. **Never auto-chains** — you invoke the suggestion.

### Usage

```
User: /msad-developer <input>

Where <input> is one of:
  - Jira ID: DDIDNS-7732 (epic), DDIDNS-10562 (story), DDIDNS-10519 (task)
  - Jira URL: https://infoblox.atlassian.net/browse/DDIDNS-10519
  - "execute plan at /path/to/plan.md"
  - Prose: "I want to add validation for replication scope"
```

### Output

The router classifies and suggests:

- **Epic (4+ repos / 5+ tasks):** `/msad-dev-planning DDIDNS-7732`
- **Story/Task (1–3 repos):** `/msad-dev-planning DDIDNS-10562`
- **"Execute plan":** `/msad-dev-execution /path/to/plan.md`
- **Ambiguous:** router asks clarifying questions

### Example

```
User: work on DDIDNS-10519

Router: 
  Classified: Task (DDIDNS-10519, type=Task)
  Repo: ddi.cloud.proxy.middleware (based on task title mentioning "middleware")
  
  Recommendation: /msad-dev-planning DDIDNS-10519
  
  This is a single task in a single repo. Planning will scope it, identify dependencies 
  (if any), write a plan, and get your approval before execution.

User: /msad-dev-planning DDIDNS-10519
```

### When to Use

- **Always start here** if you have a new Jira task and don't know what to do next
- **Skip for:** one-off code edits, ad-hoc questions, or if you already have an approved plan

---

## msad-epic-planner (Epic Structurer)

**Analyzes a Jira epic and generates a recommended structure of stories and backend/frontend tasks.**

Helps you organize an epic into well-structured stories (Backend, Frontend, QA) with all tasks properly scoped to repos. Can auto-create the stories/tasks in Jira or output a template.

### Usage

```
User: /msad-epic-planner DDIDNS-7732
```

Input: Epic ID

Output: 
1. Analysis of epic scope (repos, features, dependencies)
2. Recommended story hierarchy
3. Per-story task breakdown
4. Option to create in Jira or show template

### What It Does

1. **Fetch & analyze epic** — reads summary, description, AC, identifies impacted repos
2. **Decompose into functional areas** — Backend, Frontend/UI, QA, Docs
3. **Group Backend work into stories** — each story = one logical deliverable
4. **Break each story into repo-scoped tasks** — one task per repo with changes
5. **Generate Frontend/QA stories** — if detected
6. **Output structured hierarchy** — with full descriptions and AC
7. **Create in Jira** — optional auto-creation via Atlassian MCP

### Example Flow

```
User: /msad-epic-planner DDIDNS-7732

Planner: Analyzing epic...
  ✓ Feature: Zone creation with replication scopes
  ✓ Repos: dns.config, middleware, collector, agent
  ✓ Functional areas: Backend, Frontend, QA

Planner: Recommended structure:
  
  Story 1: "Backend — Support Domain/Forest Replication Scope"
    ├─ Task: middleware (transform & validate)
    ├─ Task: collector (error-code mapping)
    ├─ Task: dns.config (validation)
    └─ Task: agent (scope check)
  
  Story 2: "Frontend — Portal UI for Scope Selection"
    ├─ Task: Portal selector component
    ├─ Task: Form validation
    └─ Task: Documentation
  
  Story 3: "QA — E2E Testing"
    ├─ Task: Test plan
    └─ Task: Automation

Planner: Create in Jira? (Yes / No / Show Template)

User: Yes

[Planner creates 3 stories and 9 tasks in Jira]

Planner: ✓ Created 3 stories, 9 tasks. Ready for /msad-dev-epic DDIDNS-7732
```

### When to Use

- **New epic** — before any planning/implementation, structure the work correctly
- **Existing epic with messy structure** — refactor into Backend/Frontend/QA stories
- **Adding stories to an epic** — decompose new feature into structured stories + tasks
- **Before running /msad-dev-epic** — ensure epic is well-structured for automatic Backend/Frontend filtering

### Output Formats

- **Interactive (default):** Shows analysis + recommended structure; prompts for action
- **--template:** Outputs markdown + Jira CLI commands for manual creation
- **--create:** Auto-creates all stories/tasks in Jira

---

## msad-dev-planning (Plan Generator)

**Reads a Jira ticket (epic/story/task) and produces a multi-repo implementation plan.**

Groups work by repo, identifies dependencies, and writes a plan file. **Hard-gates on your approval before any code is written.**

### Usage

```
User: /msad-dev-planning DDIDNS-7732
```

Input: Jira ID (epic, story, or task)

Output: Plan file at `specs/msad-dev-plans/YYYY-MM-DD-<jira-id>-plan.md` with frontmatter:

```yaml
---
jira: DDIDNS-7732
repos: [ddi.dns.config, ddi.cloud.proxy.middleware, ddi.msad.collector, ddi.msad.agent]
status: draft              # set to "approved" by you after reviewing
created: 2026-08-13
---
```

### What It Does (Step by Step)

1. **Step 1: Intake** — classifies the input (epic / story / task)
2. **Step 2: Jira analysis** — reads ticket + linked context
3. **Step 3: Repo context** — searches for similar prior work, test patterns
4. **Step 4: Per-repo impact** — what changes in each repo?
5. **Step 5: Identify dependencies** — proto sync, validator mirrors, error codes
6. **Step 6: Clarifying questions** — if needed, asks the user
7. **Step 7: Write plan** — groups work into per-repo packages
8. **Step 7b: Plan auto-review** — dispatches fresh-context reviewer agent to audit the plan
9. **Step 8: User approval gate** — presents plan + reviewer's findings for your decision

### Example Flow

```
User: /msad-dev-planning DDIDNS-7732

[Planning reads epic, finds 20+ linked tasks]

Planning: Step 1–6 done. Writing plan...

[Planning writes plan with 5 work packages (one per repo)]

Planning: Plan auto-review in progress...

[Fresh-context reviewer agent audits plan]

Reviewer: Issues Found
  SHOULD FIX: "Cross-repo dependency section missing detailed ordering"
  MAY FIX: "Audit logging task (DDIDNS-10546) not clearly marked as deferred"

Planning: Here's your plan + reviewer's findings. Approve / Edit / Reject?

User: Approve with edits

[Planning revises, re-runs self-critique + auto-review, re-presents]

Planning: Here's the revised plan. Approve?

User: Approve

Planning: Plan status set to "approved". Next: /msad-dev-execution /path/to/plan.md
```

### Plan Format

The plan lists:

- **Per-repo work packages** (which Jira task IDs, what files change, test plan)
- **Cross-repo dependencies** (proto sync, validator mirrors, error codes, ordering)
- **Assumptions** (Windows testing limitations, etc.)
- **Risks** (validator drift, cross-repo coordination, scope creep)
- **Acceptance criteria coverage** (which AC maps to which implementation step)

### When to Use

- **First time:** you have a new Jira task and want a plan before committing
- **Multi-repo work:** epics or stories spanning multiple repos (plan helps coordinate)
- **Cross-repo contract:** if validator sync or proto changes are needed, planning identifies them upfront

---

## msad-dev-execution (Plan Executor)

**Reads an approved plan and executes it end-to-end.**

Implements, tests, validates with a multi-round code review loop, and opens draft PRs.

### Usage

```
User: /msad-dev-execution DDIDNS-7732

# or equivalently:
User: /msad-dev-execution 2026-08-13-DDIDNS-7732-plan.md
User: /msad-dev-execution /path/to/plan.md
```

Input (auto-discovery, user-friendly):
- **Jira ID:** `DDIDNS-7732` — auto-discovers most recent `YYYY-MM-DD-DDIDNS-7732-plan.md` in `specs/msad-dev-plans/`
- **Plan filename:** `2026-08-13-DDIDNS-7732-plan.md` — searches `specs/msad-dev-plans/` for match
- **Full path:** `/path/to/plan.md` — uses file directly

All require plan frontmatter `status: approved`

Output: Draft PR URLs, one per repo involved

### What It Does (Step by Step)

1. **Step 1: Verify** — checks that plan `status: approved` (refuses to proceed otherwise)
2. **Step 2: Implementation** — for each work package:
   - Dispatches `msad-backend-dev` agent
   - Agent writes code TDD-style
3. **Step 3: Test suite** — runs repo's standard tests (go test / dotnet test)
4. **Step 4: Validation loop** (≤3 rounds):
   - Dispatches `msad-code-review` agent
   - Reviews the branch, reports findings (MUST/SHOULD/MAY)
   - You fix findings or justify them
   - Code review agent re-reviews until clean
5. **Step 5: Final checks** — pre-push linter/type-checker (if available)
6. **Step 6: PR creation** — opens draft PRs cross-linked by dependency

### Example Flow

```
User: /msad-dev-execution /Users/smalisetti/msad-dev-plans/2026-08-13-DDIDNS-7732-plan.md

[Execution verifies status: approved]

Execution: Implementing 5 work packages...

[Agents dispatch in parallel for independent packages]

[Package 1/5: ddi.dns.config]
  Agent: writes test → implements → tests pass ✓
  Review round 1: finds 3 MUST findings
  User: fixes findings
  Review round 2: clean ✓
  Opens draft PR

[Package 2/5: ddi.cloud.proxy.middleware]
  [similar flow, clean after 1 review round]
  Opens draft PR

... etc ...

Execution: All done. Draft PRs opened:
  - https://github.com/Infoblox-CTO/ddi.dns.config/pull/123
  - https://github.com/Infoblox-CTO/ddi.cloud.proxy.middleware/pull/456
  - https://github.com/Infoblox-CTO/ddi.msad.collector/pull/789
  - https://github.com/Infoblox-CTO/ddi.msad.agent/pull/234
  
All PRs are draft (not merged). Ready for human review.
```

### Code Review Loop (The Heart of It)

Execution runs a **bounded loop** (max 3 rounds) for each package:

1. **Round 1:** code-review agent reviews branch, reports findings
2. **You respond:** fix MUST findings, justify SHOULD findings if needed
3. **Round 2:** code-review agent re-reviews (only changed files if possible)
4. **Loop continues** until:
   - Zero MUST findings remaining, **OR**
   - 3 rounds completed (then escalates to user)

This ensures code doesn't land in a draft PR with unresolved findings.

### When to Use

- **After approval:** you approved a plan, now execute it
- **Multi-repo coordination:** execution respects dependencies, runs parallel packages safely
- **Quality gate:** validation loop catches issues before PR

### Important Notes

- **Windows testing limitation:** if plan involves `ddi.msad.agent`, execution notes that local testing is impossible, Windows CI is the gate
- **Draft PRs only:** PRs are never merged automatically; you (or a teammate) must review and merge
- **Cross-repo linking:** if Package A depends on Package B, execution holds Package A as draft until B merges

---

## msad-e2e-verify (API-Level E2E Testing)

**End-to-end verification at the API layer without the Windows agent.**

Brings up dns.config + mocked MSAD collector, drives zone create/update flows via WAPI v3, verifies replication-scope handling and error codes.

### Usage

```
User: /msad-e2e-verify
```

No input needed. The skill brings up the test stack and runs test sequences.

### What It Does

1. **Setup:** brings up dns.config service + docker-compose stack
2. **Test sequences:** drives zone creation/update flows via WAPI v3
   - Create zone with local scope
   - Create zone with domain scope
   - Create zone with forest scope
   - Reject invalid scope (legacy)
   - Update zone scope (forward zones only)
   - Verify error-code mapping (ZONE-001 → codes.AlreadyExists, etc.)
3. **Assertions:** checks DB state and mocked collector responses
4. **Teardown:** brings down the stack, reports results

### Coverage

**Can verify:**
- Zone creation requests (scope, zone type, account/view)
- Middleware routing to mocked MSAD collector
- Scope validation (allow-list enforcement)
- Error-code extraction and mapping
- DB persistence (replication-scope value, metadata)
- Pre-flight duplicate checks
- Request/response shape correctness

**Cannot verify:**
- Real PowerShell `Add-DnsServerPrimaryZone` execution (Windows-only)
- Actual AD replication (requires real MSAD + AD environment)
- Real MSAD collector responses (mocked in test)

These gaps are covered by:
- **Unit tests** in each repo
- **Windows CI** (Jenkins node for agent changes)
- **Stage testing** (manual, real MSAD + AD)

### Example Output

```
User: /msad-e2e-verify

[E2E brings up dns.config + mocked collector]

E2E: Running test sequences...

Test 2A: Create auth zone with local scope
  ✓ HTTP 201 Created
  ✓ DB row: replication_scope = "local"
  ✓ Middleware called collector Create RPC

Test 2B: Create auth zone with domain scope
  ✓ HTTP 201 Created
  ✓ DB row: replication_scope = "domain"

Test 2C: Create forward zone with forest scope
  ✓ HTTP 201 Created

Test 2D: Reject invalid scope (legacy)
  ✓ HTTP 400 Bad Request
  ✓ Zone NOT created in DB

Test 2E: Duplicate zone check
  ✓ First request: created
  ✓ Second request: 409 Conflict (pre-flight blocked)

Test 2F: Update forward zone scope (local → domain)
  ✓ HTTP 200 OK
  ✓ DB row updated

Test 2G: Error code mapping
  ✓ ZONE-001 → codes.AlreadyExists

Results: 7/7 passed

Deferred: Real MSAD agent (Windows CI), AD replication (stage testing)
```

### When to Use

- **API contract verification:** zone creation/update flows work end-to-end
- **Scope validation testing:** replication-scope logic is enforced correctly
- **Error handling:** agent error codes are mapped to gRPC statuses
- **DB persistence:** scope values are stored and retrieved correctly
- **Before manual testing:** verify the basics in a local stack before sending to stage/prod

---

## Skill Dependency Chain

```
       Rough Epic Idea
         ↓
  /msad-epic-planner ← Structure the epic (stories/tasks)
         ↓
   (analyzes scope)
         ↓
   (generates story hierarchy)
         ↓
   (creates in Jira or shows template)
         ↓
   Structured Epic
         ↓
   Pick Path A or B:
   
   PATH A (Fast):
   ├─ /msad-dev-epic ← Orchestrate all stories
   │  ├─ (discovers tasks)
   │  ├─ (classifies Backend/Frontend/UI)
   │  ├─ (dispatches agents for Backend only)
   │  └─ (reports: X PRs ready, Y Frontend tasks excluded)
   │
   PATH B (Detailed):
   ├─ /msad-dev-planning ← Generate detailed plan
   │  ├─ (analyzes each task)
   │  ├─ (identifies dependencies)
   │  ├─ (plan auto-review)
   │  └─ (user approval gate)
   │
   ├─ /msad-dev-execution ← Execute approved plan
   │  ├─ (dispatches agents per work package)
   │  ├─ (validation loop: review → fix → re-review)
   │  └─ (draft PRs ready)
   │
   Parallel Story Execution:
   └─ /msad-dev-story DDIDNS-10562 ← Faster single-story focus
      └─ (same flow as epic, one story only)

   Parallel Testing:
   └─ /msad-e2e-verify ← API-level E2E testing (anytime)
         ↓
      Done (all PRs ready for review + merge)
```

**Recommended flow for epic release:**
1. `/msad-epic-planner DDIDNS-7732` (structure: 5 min)
2. `/msad-dev-epic DDIDNS-7732` (execute: 20 min)
3. Review & merge PRs (parallel to Frontend team's work)

**For single story:**
1. `/msad-dev-story DDIDNS-10562` (execute: 10-15 min)

**For detailed planning + execution (more control):**
1. `/msad-epic-planner DDIDNS-7732` (structure: 5 min)
2. `/msad-dev-planning DDIDNS-7732` (plan: 10 min)
3. `/msad-dev-execution DDIDNS-7732` (execute: 20 min)

**Parallel tracks:**
- `/msad-e2e-verify` (API-level testing, anytime)
- Frontend team works on excluded UI stories in parallel

---

## Tips & Tricks

### For Epic Work (Multi-Repo)

1. Invoke `msad-dev-planning DDIDNS-7732` early
2. Review the plan carefully (cross-repo deps are complex)
3. Once approved, `msad-dev-execution` handles all 5 repos in parallel (for independent packages)

### For Single-Repo Tasks

1. Invoke `msad-dev-planning DDIDNS-10519`
2. Expect a simple 1-package plan (one file, one test, one PR)
3. Approve and execute

### For Debugging Code Review Findings

If `msad-code-review` reports a finding you disagree with:
- **MUST findings:** check the MSAD checklist in [agents/README.md](../agents/README.md) — probably non-negotiable (safety, contract, RFC)
- **SHOULD findings:** you can justify and move on (code review won't block)
- **MAY findings:** skip if cost is high

### For Windows Agent Changes

If your plan involves `ddi.msad.agent`:
- Acknowledge: "Local testing impossible"
- Know: Windows CI node is `windows_node_ddi_msad_agent_label`
- Expect: draft PR, merged after CI passes

### For Cross-Repo Validator Changes

If you're changing a replication-scope validator:
- Planning will flag all mirrors that must be updated
- Code review will check that all mirrors are in sync
- If you forget one, code review will catch it as a MUST finding

---

## See Also

- **[agents/README.md](../agents/README.md)** — Agent details
- **[../README.md](../README.md)** — Main usage guide (with worked examples)
- **[references/repo-topology.md](../references/repo-topology.md)** — Repos, stacks, build/test commands
- **[references/plan-reviewer-prompt.md](../references/plan-reviewer-prompt.md)** — Plan reviewer checklist
