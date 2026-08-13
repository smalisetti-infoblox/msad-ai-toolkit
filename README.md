# MSAD AI Toolkit

Claude Code custom agent + skills for the MSAD (Microsoft Active Directory DNS) ecosystem. Implements multi-repo orchestration for **DDIDNS-7732** (Microsoft DNS zone creation / replication scope) and related features across five repositories with different stacks.

**Quick Start:** See [Getting Started](#getting-started) for your first task, or jump to [Usage Patterns](#usage-patterns) for worked examples.

---

## Five-Repo Ecosystem

| Repo | Stack | Role |
|---|---|---|
| **ddi.dns.config** | Go | WAPI v3 API surface; replication-scope validation |
| **ddi.cloud.proxy.middleware** | Go | gRPC interceptor library; MSAD request translation |
| **ddi.msad.collector** | Go, gRPC | gRPC microservice; error-code mapping |
| **ddi.msadconnect.proxy** | Go | Windows RPC/LDAP bridge |
| **ddi.msad.agent** | C#/.NET 8 | Windows Service; PowerShell zone controllers (Windows-only testing) |

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

## Getting Started

### Step 1: Understand Your Task

You have a Jira task (epic, story, or task ID). Examples:

- **Epic:** DDIDNS-7732 ("Microsoft DNS zone creation / replication scope")
- **Story:** DDIDNS-10562 ("Backend: support Domain/Forest replication scope on Microsoft DNS zone creation")
- **Task:** DDIDNS-10519 ("ddi.cloud.proxy.middleware: support Domain/Forest replication scope for Auth/Reverse Auth/Forward zone creation")

### Step 2: Invoke the Router

Start by invoking the **router skill**, which classifies your task and suggests the right next step:

```
User: work on DDIDNS-7732
```

The router will ask questions to understand scope, then suggest:

- **For epics:** `/msad-dev-planning DDIDNS-7732` (plan the epic)
- **For stories/tasks:** `/msad-dev-planning DDIDNS-10562` (plan the story/task)
- **For "execute plan X":** `/msad-dev-execution /path/to/plan.md` (run a pre-approved plan)

### Step 3: Run Planning

Follow the router's suggestion and invoke the planning skill:

```
User: /msad-dev-planning DDIDNS-7732
```

**What the planning skill does:**

1. Reads the Jira ticket (epic + linked stories/tasks)
2. Groups work by repo (ddi.dns.config, ddi.cloud.proxy.middleware, ddi.msad.collector, etc.)
3. Identifies cross-repo dependencies (proto sync, validator mirrors, error codes)
4. Calls a fresh-context reviewer agent to audit the plan
5. Surfaces the plan + reviewer's findings for your approval

**You review:**

- Does each work package make sense?
- Are cross-repo dependencies clear?
- Are acceptance criteria mapped?
- Do you agree with the scope?

**You respond:**

- **"Approve"** → planning stamps the plan as approved
- **"Approve with edits"** → you provide feedback, planning revises
- **"Reject"** → planning goes back to clarifying questions

### Step 4: Run Execution

Once the plan is approved, invoke the execution skill:

```
User: /msad-dev-execution /path/to/plan.md
```

**What the execution skill does:**

1. For each work package in the plan:
   - Dispatches an implementation agent (`msad-backend-dev`) to write code TDD-style
   - Runs the repo's test suite (go test / dotnet test)
   - **Validation loop** (≤3 rounds):
     - Code review agent reviews the branch
     - You see findings (MUST fix, SHOULD fix, MAY fix)
     - You fix or justify findings
     - Code review agent re-reviews until clean
   - Opens a **draft PR** cross-linked with dependencies

2. Returns to you with all draft PR URLs.

---

## Usage Patterns

### Pattern 1: Epic Work (Multi-Repo)

**Input:** A large epic like DDIDNS-7732 touching all five repos.

**Flow:**

```
User: work on DDIDNS-7732

Router: suggests /msad-dev-planning DDIDNS-7732

User: /msad-dev-planning DDIDNS-7732
[Planning reads epic, finds 20+ linked tasks, groups into 5 work packages (one per repo)]

Planning: Here's your plan:
  - Package 1: ddi.dns.config (2 tasks)
  - Package 2: ddi.cloud.proxy.middleware (3 tasks)
  - Package 3: ddi.msad.collector (2 tasks)
  - Package 4: ddi.msad.agent (1 task)
  
  Cross-repo dependencies:
  - Collector proto changes → middleware must regenerate
  - Validator sync: dns.config + middleware must mirror
  
  Plan approved? (Y/N/Edit)

User: Approve

User: /msad-dev-execution /path/to/plan.md
[Execution dispatches 4 agents in parallel (independent packages)]

[Agents return with code + test results]

[Code review loop runs; findings are fixed]

[Draft PRs opened, cross-linked]

Execution: All done. Draft PRs:
  - https://github.com/Infoblox-CTO/ddi.dns.config/pull/123
  - https://github.com/Infoblox-CTO/ddi.cloud.proxy.middleware/pull/456
  - ... etc ...
```

### Pattern 2: Single-Task Work (One Repo)

**Input:** A task scoped to one repo, like DDIDNS-10519.

**Flow:**

```
User: work on DDIDNS-10519

Router: suggests /msad-dev-planning DDIDNS-10519

User: /msad-dev-planning DDIDNS-10519
[Planning reads task, finds it's in ddi.cloud.proxy.middleware, writes a 1-package plan]

Planning: Plan for DDIDNS-10519:
  - Single package: ddi.cloud.proxy.middleware
  - Changes: update isValidMSADReplicationScopeForZoneCreate to allow domain/forest
  - Tests: unit tests + sqlmock integration test
  - No cross-repo dependencies
  
  Ready? (Y/N/Edit)

User: Approve

User: /msad-dev-execution /path/to/plan.md
[Execution dispatches 1 agent]

[Agent writes test first, then implementation]

[Code review runs; findings fixed]

[Draft PR opened]

Execution: Done. Draft PR:
  - https://github.com/Infoblox-CTO/ddi.cloud.proxy.middleware/pull/456
```

### Pattern 3: API-Level E2E Testing

**Input:** You want to test zone creation flows without the Windows agent.

**Flow:**

```
User: I want to test zone replication scope changes via the API, but I can't run the Windows agent locally

Router: suggests /msad-e2e-verify

User: /msad-e2e-verify
[E2E skill brings up dns.config service + mocked collector]
[Runs zone create/update test sequences]
[Verifies scope values in DB, error handling]

E2E: Tests passed:
  - ✓ Create zone with local scope
  - ✓ Create zone with domain scope
  - ✓ Create zone with forest scope
  - ✓ Reject invalid scope (legacy)
  - ✓ Update zone scope (forward only)
  - ✓ Error code mapping (ZONE-001 → AlreadyExists)
```

### Pattern 4: Reviewing Someone Else's PR

**Input:** A teammate opened a PR in one of the MSAD repos; you want a second opinion.

**Flow:**

```
User: review https://github.com/Infoblox-CTO/ddi.cloud.proxy.middleware/pull/456

[Note: You would invoke the code-review agent directly here, not the router]

Code Review: MSAD-Specific Findings:
  [✓] Replication-scope allow-list consistent (local/domain/forest, no legacy)
  [✓] Idempotency checks present (duplicate pre-flight, rollback on failure)
  [!] Error-code mapping missing (new ZONE-005 not in ErrorCodeToStatus)
  [!] Validator not mirrored in dns.config
  
  Verdict: SHOULD FIX before merge (2 issues)
```

---

## Artifact Guide

### Agents

See [agents/README.md](agents/README.md) for details on:

- **`msad-backend-dev`** — writes code (TDD-first, cross-repo aware, PowerShell-safe)
- **`msad-code-review`** — reviews code (MSAD checklist, severity levels)

**You typically don't invoke these directly.** Planning and execution dispatch them.

### Skills

See [skills/README.md](skills/README.md) for details on:

- **`msad-developer`** — router (epic → planning, task → planning, plan → execution)
- **`msad-dev-planning`** — plan generator (reads Jira, groups by repo, identifies dependencies, gated approval)
- **`msad-dev-execution`** — plan executor (implement → test → validate loop → draft PR)
- **`msad-e2e-verify`** — API-level E2E (no Windows agent needed)

**Typical entry point:** `/msad-developer <task>`

### References

- **[references/repo-topology.md](references/repo-topology.md)** — Shared knowledge (stacks, commands, validators, proto pairs, test patterns)
- **[references/plan-reviewer-prompt.md](references/plan-reviewer-prompt.md)** — Template for the auto-reviewer agent (loaded by planning skill)

---

## FAQ

### Q: Can I test ddi.msad.agent locally on Mac?

**A:** No. It's a Windows Service with PowerShell cmdlets; the agent cannot run on Mac/Linux. **Local verification:** unit tests (xUnit in the agent repo). **Real verification:** Windows CI (Jenkins `windows_node_ddi_msad_agent_label` node).

The toolkit acknowledges this and points to the right verification gate.

### Q: What if my task spans multiple repos?

**A:** The router will detect it. Planning will group the work into per-repo packages, identify dependencies (e.g., "collector proto change must land before middleware PR"), and write a plan with ordering. Execution respects that ordering: it runs independent packages in parallel, but holds dependent packages until their dependency is done.

### Q: What's the "validation loop" in execution?

**A:** Implementation → code review → findings reported → you fix or justify → code review runs again (up to 3 rounds) → if clean, draft PR opens. This prevents landing code with review findings still open.

### Q: Can I skip planning and go straight to implementation?

**A:** Technically yes (user could invoke agents directly), but **don't**. Planning is the gate that:
- Catches scope creep
- Surfaces cross-repo dependencies
- Runs a fresh-context reviewer to catch gaps
- Gathers the whole team's consent upfront

Skipping planning is a quality regression.

### Q: How do I know if a change is done?

**A:** You get a **draft PR** (not merged yet). The PR:
- Links to the Jira task
- Lists files changed
- References cross-repo dependencies
- Notes any deferred work (e.g., Windows testing, stage testing)
- Is ready for review by a human (your team)

You can iterate on the draft PR, or request a human review, or merge if it looks good.

---

## Key Design Decisions

### 1. Multi-Round Code Review Before PR

Code doesn't land in a draft PR until review findings are clean (or explicitly justified). This is **non-negotiable** in the execution skill.

### 2. Honest About Windows Testing

If your task involves `ddi.msad.agent`, the toolkit says:
- "Local testing impossible"
- "Windows CI will verify"
- "Stage testing will verify AD replication"

No false claims of "fully tested on Mac."

### 3. Cross-Repo Contract Discipline

Four replication-scope validators must stay in sync across repos. Planning surfaces this upfront. Code review enforces it.

### 4. Plan Auto-Review

Before you approve a plan, a fresh-context reviewer agent audits it for:
- Scope clarity
- Dependency gaps
- Assumption honesty
- Risk realism

Reviewer is advisory; you decide on findings.

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

## Next Steps

1. **Install the toolkit** (add as plugin or symlink)
2. **Pick a task** (Jira epic or story)
3. **Invoke the router:** `/msad-developer <task-id>`
4. **Follow the flow:** plan → approve → execute
5. **Review draft PR** when done

Questions? Ask the MSAD team or file an issue in this repo.
