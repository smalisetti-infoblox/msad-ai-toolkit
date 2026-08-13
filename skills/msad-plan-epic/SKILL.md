---
name: msad-plan-epic
description: "Epic structure planner for MSAD development. Analyzes a Jira epic and generates a recommended hierarchy of stories and backend/frontend tasks following toolkit patterns. Use before running /msad-dev-epic to ensure optimal epic structure and automatic toolkit filtering."
version: 0.1.0
created_by:
  name: Seshachalam Malisetti
  role: MSAD Epic Planning
---

# MSAD Epic Planner

Analyze a Jira epic and generate a recommended structure of stories and tasks for optimal toolkit automation. Produces a detailed plan showing Backend stories, Frontend stories, and QA stories, with all tasks properly scoped to repos.

## Quick Start

```bash
/msad-plan-epic DDIDNS-7732
```

**Input:** Epic ID (e.g., `DDIDNS-7732`)

**Output:** 
1. Analysis of epic scope (repos, features, dependencies)
2. Recommended story hierarchy (Backend, Frontend, QA tracks)
3. Per-story task breakdown
4. Jira creation template (markdown or Jira CLI commands)
5. Option to create stories/tasks in Jira automatically

---

## Process

```
Input: Epic ID (DDIDNS-7732)
  ↓
Step 1: Fetch & Analyze Epic
  ├─ Read epic summary, description, AC
  ├─ Extract feature requirements
  ├─ Identify impacted repos
  └─ Detect multi-repo dependencies

Step 2: Decompose into Functional Areas
  ├─ Identify Backend work (core feature implementation)
  ├─ Identify Frontend/UI work (Portal, forms, dashboards)
  ├─ Identify QA/Testing work (E2E, automation, validation)
  └─ Identify Documentation/Other work

Step 3: Group Backend Work into Stories
  ├─ Each story: one logical Backend deliverable
  ├─ Story scope: 1–3 repos, tied to one feature
  └─ Name: "Backend — [feature description]"

Step 4: Decompose Each Story into Repo-Scoped Tasks
  ├─ Per story, identify per-repo work
  ├─ Example: middleware task, collector task, agent task
  ├─ Name: "[repo]: [what changes]"
  └─ Link each task to exactly one story

Step 5: Generate Frontend Stories (if detected)
  ├─ Each story: one Portal/UI deliverable
  ├─ Story scope: one UI feature
  └─ Name: "Frontend — [UI description]" or "Portal — [feature]"

Step 6: Generate QA / Test Stories (if applicable)
  ├─ Test planning, automation, stage validation
  └─ Name: "QA — [test scope]"

Step 7: Output & Create
  ├─ Show recommended hierarchy
  ├─ Ask: "Create in Jira? (Y/N/Show Template Only)"
  ├─ If Yes: use Atlassian MCP to create stories/tasks
  └─ If No: output Jira CLI template for manual creation
```

---

## Inputs

- **epic_id** (required): Jira epic ID, e.g., `DDIDNS-7732`
- **output_format** (optional, default: `interactive`): `interactive`, `template`, or `jira-cli`

## Output

### Example: DDIDNS-7732 Epic Planner Output

```
Epic Analysis: DDIDNS-7732 — Microsoft DNS Zone Creation with Replication Scope

Feature Summary:
  Add support for creating Microsoft DNS zones with Domain and Forest replication scopes
  via WAPI v3 API. Zones must be validated at each layer and errors mapped correctly.

Impacted Repos (6):
  ✓ ddi.dns.config (WAPI v3 API changes)
  ✓ ddi.dns.data (zone data layer changes)
  ✓ ddi.cloud.proxy.middleware (request transformation)
  ✓ ddi.msad.collector (error-code mapping)
  ✓ ddi.msadconnect.proxy (RPC bridge — likely no changes)
  ✓ ddi.msad.agent (PowerShell scope validation)

Functional Areas Detected:
  ✓ Backend: Zone creation API, validation, gRPC integration
  ✓ Frontend: Portal UI for scope selection
  ✓ QA: E2E testing, automation

===== RECOMMENDED STRUCTURE =====

STORY 1: DDIDNS-10562 "Backend — Support Domain/Forest Replication Scope on Zone Creation"
  
  Description:
    Add support for creating Microsoft DNS zones with Domain and Forest replication scopes.
    Scopes must be validated at the WAPI v3 layer, middleware layer, and collector layer
    before passing to the Windows agent for PowerShell execution.
  
  Acceptance Criteria:
    ✓ WAPI v3 accepts replication_scope = "domain" and "forest" on zone creation
    ✓ All scopes validated at dns.config layer (creation only)
    ✓ Middleware transforms and validates scope before forwarding to collector
    ✓ Collector error codes mapped correctly (ZONE-005 for invalid scopes)
    ✓ Agent validates scope before passing to PowerShell cmdlet
    ✓ Existing tests pass; new tests cover scope validation (≥92% coverage)
  
  Tasks (5):
    ├─ DDIDNS-10519 "ddi.cloud.proxy.middleware: transform & validate replication scope"
    │   Repos: ddi.cloud.proxy.middleware
    │   Files: pkg/msad_zone_helper.go, pkg/interceptor_handlers.go, *_test.go
    │   Effort: Medium
    │
    ├─ DDIDNS-10542 "ddi.cloud.proxy.middleware: add idempotency for zone creation"
    │   Repos: ddi.cloud.proxy.middleware
    │   Files: pkg/idempotency.go (new), *_test.go
    │   Effort: Medium
    │
    ├─ DDIDNS-10543 "ddi.msad.collector: map error codes for scope validation failures"
    │   Repos: ddi.msad.collector
    │   Files: pkg/util/util.go, pkg/svc/zones/zones.go, *_test.go
    │   Effort: Small
    │
    ├─ DDIDNS-10546 "ddi.dns.config: validate replication scope on zone creation"
    │   Repos: ddi.dns.config
    │   Files: pkg/service/application/stub_zone.go, pkg/messages/messages.go, *_test.go
    │   Effort: Small
    │
    └─ DDIDNS-10521 "ddi.msad.agent: validate replication scope before PowerShell"
        Repos: ddi.msad.agent
        Files: MSADAgent/Agent/Core/DnsInfoControllers/DnsPrimaryZoneController.cs, *Tests*.cs
        Effort: Small
        Note: Windows-only testing (CI only)

  Toolkit Recommendation:
    Use: /msad-dev-story DDIDNS-10562
    Expected time: 15 minutes (5 agents in parallel)
    Expected result: 5 Backend PRs ready for review

---

STORY 2: DDIDNS-10563 "Frontend — Portal UI for Replication Scope Selection"
  
  Description:
    Add Portal UI components and forms to allow users to select replication scope
    when creating DNS zones via the Infoblox Cloud Portal.
  
  Acceptance Criteria:
    ✓ Portal selector component displays valid scopes (local, domain, forest)
    ✓ Form validation prevents invalid scope submissions
    ✓ Portal documentation updated with scope descriptions
    ✓ UX review passed
  
  Tasks (3):
    ├─ DDIDNS-10544 "Portal: add selector component for replication scope"
    │   Repos: ddi-portal (UI repo, not in toolkit scope)
    │   Effort: Medium
    │
    ├─ DDIDNS-10548 "Portal: add form validation for scope changes"
    │   Repos: ddi-portal (UI repo, not in toolkit scope)
    │   Effort: Small
    │
    └─ DDIDNS-10545 "Portal: update documentation for scope feature"
        Repos: docs
        Effort: Small

  Toolkit Recommendation:
    NOT ORCHESTRATED by toolkit (Frontend repo, separate team)
    Use: Manual coordination with Portal team
    Note: Listed as excluded when running /msad-dev-epic DDIDNS-7732

---

STORY 3: DDIDNS-10567 "QA — E2E Testing for Zone Replication Scope"
  
  Description:
    E2E testing and automation for zone creation with replication scope across
    the full stack (API → middleware → collector → agent).
  
  Acceptance Criteria:
    ✓ E2E test plan written and approved
    ✓ Automation covers scope validation at each layer
    ✓ CI/CD pipeline updated for new test cases
    ✓ Stage testing completed (real MSAD environment)
  
  Tasks (2):
    ├─ DDIDNS-10510 "QA: write E2E test plan for replication scope"
    │   Repos: test-infrastructure
    │   Effort: Medium
    │
    └─ DDIDNS-10511 "QA: implement automation and CI/CD integration"
        Repos: test-infrastructure
        Effort: Medium

  Toolkit Recommendation:
    Partially covered: /msad-e2e-verify (API-level testing)
    Not automated: Stage testing (real MSAD + AD), Portal UI testing

===== CREATION OPTIONS =====

Option 1: Create in Jira Automatically
  /msad-plan-epic DDIDNS-7732 --create

Option 2: Show Jira CLI Commands
  /msad-plan-epic DDIDNS-7732 --template

Option 3: Review First (Default)
  /msad-plan-epic DDIDNS-7732
  [Review output above, then decide]
```

---

## Step-by-Step Process

### Step 1: Fetch & Analyze Epic

1. Fetch epic via `getJiraIssue(epic_id)` — summary, description, AC, components, status
2. Extract key information:
   - **Feature scope:** What's being built? (e.g., "zone creation with replication scopes")
   - **Repos impacted:** Which of the 6 repos are involved? (grep description for repo names)
   - **User-facing changes:** What do users do differently? (e.g., "select scope in form")
   - **Backend changes:** What layers need changes? (API, middleware, collector, agent)
   - **Cross-repo dependencies:** Does middleware change? Does it need collector proto changes?

3. Record findings in analysis section

### Step 2–6: Decompose into Functional Areas & Stories

For each functional area (Backend, Frontend, QA, Docs):

**Backend stories:**
- Each story is one **logical Backend deliverable** (not one repo)
- Example: "Zone creation with Domain/Forest scopes" spans 4 repos but is ONE story
- Story name: `"Backend — [feature]"` (e.g., `"Backend — Support Domain/Forest Replication Scope"`)
- Split into stories only if they're truly independent (e.g., separate from "audit logging" story)

**Frontend stories:**
- Each story is one **Portal/UI deliverable**
- Story name: `"Frontend — [UI feature]"` or `"Portal — [feature]"`
- Example: `"Frontend — Portal UI for Scope Selection"`

**QA stories:**
- Testing, automation, validation
- Story name: `"QA — [test scope]"`
- Example: `"QA — E2E Testing for Zone Replication Scope"`

### Step 7: Decompose Stories into Repo-Scoped Tasks

For each Backend story, identify per-repo work:

1. **For each repo mentioned in epic:**
   - What changes? (validators, handlers, error codes, tests)
   - What files? (from `references/repo-topology.md` "Key Implementation Files")
   - What effort? (Small/Medium/Large)

2. **Task naming:** `"[repo]: [what changes]"`
   - Example: `"ddi.cloud.proxy.middleware: transform & validate replication scope"`
   - Example: `"ddi.msad.collector: map error codes for scope failures"`

3. **Link to story:** All tasks for a story link to that story as parent

4. **Add acceptance criteria:** Each task has its own AC (subset of story AC)

---

## Story & Task Template

### Backend Story Template

```markdown
## DDIDNS-XXXXX: Backend — [Feature Name]

**Description:**
[2–3 sentences describing what users can now do]

**Acceptance Criteria:**
✓ [AC 1: User-facing outcome]
✓ [AC 2: API layer outcome]
✓ [AC 3: Middleware outcome]
✓ [AC 4: Collector outcome]
✓ [AC 5: Agent outcome (if applicable)]
✓ [AC 6: Tests cover new behavior; coverage ≥92%]

**Impacted Repos:** 3–5 repos (list them)

**Linked Tasks:**
- DDIDNS-XXXXX: [repo 1 task]
- DDIDNS-XXXXX: [repo 2 task]
- ... (one per repo with changes)
```

### Backend Task Template

```markdown
## DDIDNS-XXXXX: [repo]: [What Changes]

**Description:**
[1–2 sentences: what code changes, why, where]

**Repository:** [repo name]

**Acceptance Criteria:**
✓ [AC 1: Validation works]
✓ [AC 2: Tests added; coverage ≥92%]
✓ [AC 3: No regressions]

**Acceptance Criteria Mapping:**
- Addresses parent story AC #N (e.g., "Middleware validates scope")

**Parent Story:** DDIDNS-XXXXX

**Estimated Effort:** Small / Medium / Large
```

---

## Backend Breakdown Strategy

When decomposing a Backend story, follow this order:

1. **dns.config** (WAPI v3 API layer) — adds/changes public API validators
2. **ddi.dns.data** (WAPI v3 data layer) — adds/changes zone data handling
3. **ddi.cloud.proxy.middleware** (gRPC interceptor) — transforms requests, calls collectors
4. **ddi.msad.collector** (gRPC service) — maps errors, calls proxy
5. **ddi.msadconnect.proxy** (RPC bridge) — rarely changes for zone features
6. **ddi.msad.agent** (Windows service) — final validation, PowerShell execution

**Typical ordering:**
- `dns.config` changes first (API shape)
- `middleware` changes second (validates & transforms)
- `collector` changes third (error mapping)
- `agent` changes last (PowerShell behavior)

**Note:** Middleware is a **shared dependency** (consumed by dns.config and dns.data), so if middleware changes, both consumers must be validated.

---

## Recommended Prompts for Story Decomposition

Use these prompts to generate story/task structure:

**For Backend stories:**
> "Break down this epic feature into Backend stories. Each story should be one logical deliverable that spans 1–3 repos. Follow the pattern: 'Backend — [feature]'. For each story, list the per-repo tasks (middleware, collector, dns.config, agent). Include AC for each."

**For Frontend stories:**
> "Identify Portal/UI stories in this epic. Each story should be one UI deliverable (e.g., 'Portal selector component', 'Form validation'). Follow the pattern: 'Frontend — [UI feature]'. These are NOT automated by the toolkit."

**For QA stories:**
> "Identify testing/QA stories. Each story covers one QA area (E2E testing, automation, stage validation). Follow the pattern: 'QA — [test scope]'."

---

## Creation Workflow

### Option A: Manual Review (Default)

1. Run `/msad-plan-epic DDIDNS-7732`
2. Review recommended structure
3. If happy: `/msad-plan-epic DDIDNS-7732 --create`
4. If changes needed: manually edit Jira stories/tasks

### Option B: Auto-Create from Planner

1. Run `/msad-plan-epic DDIDNS-7732 --create`
2. Skill uses Atlassian MCP to create stories + tasks
3. Links all tasks to their parent story
4. Links all stories to the epic
5. Reports: "Created 3 stories (5 tasks) in DDIDNS-7732"

### Option C: CLI Template for Manual Creation

1. Run `/msad-plan-epic DDIDNS-7732 --template`
2. Outputs Jira CLI commands (or curl equivalents)
3. Example:
   ```bash
   # Create story DDIDNS-10562
   gh api repos/Infoblox-CTO/msad-ai-toolkit/issues \
     --input - << EOF
   {
     "title": "Backend — Support Domain/Forest Replication Scope",
     "body": "...",
     "assignee": "..."
   }
   EOF
   ```
4. User runs commands manually or via CI/CD

---

## Output Formats

### Interactive (Default)

User sees:
1. Analysis of epic (scope, repos, functional areas)
2. Recommended story hierarchy
3. Per-story task breakdown
4. Prompt: "Create in Jira? (Yes / No / Show Template)"

### Template (--template)

Outputs:
1. Markdown with all stories/tasks (copy-paste into Jira description)
2. Jira CLI commands (for automation)
3. Example Jira issue JSON (for integrations)

### Auto-Create (--create)

Outputs:
1. Progress: "Creating story DDIDNS-10562..."
2. Progress: "Creating task DDIDNS-10519..."
3. Final report: "Created 3 stories, 11 tasks. All linked to DDIDNS-7732."
4. Summary: "Ready for /msad-dev-epic DDIDNS-7732"

---

## When to Use

- **First-time epic** — run planner before any implementation to structure the work correctly
- **Existing epic with messy structure** — run planner to suggest refactoring/reorganization
- **Adding new stories to existing epic** — use planner to decompose new feature into stories + tasks
- **Before running /msad-dev-epic** — ensure epic is well-structured so toolkit filters work correctly

---

## Integration with Other Skills

**Workflow:**

```
1. Create epic in Jira (rough description)
2. /msad-plan-epic EPIC-ID          ← Structure the epic
3. /msad-dev-planning EPIC-ID          ← Generate detailed implementation plan
4. /msad-dev-epic EPIC-ID              ← Orchestrate implementation (parallelized)
```

**Cross-links:**
- **Before:** `/msad-plan-epic` (structure)
- **After:** `/msad-dev-epic` (execute)
- **Reference:** See `README.md` "Suggested Jira Structure" for examples

---

## Limitations & Future Work

**Current:**
- ✅ Analyzes epic scope and recommends structure
- ✅ Decomposes into Backend/Frontend/QA stories
- ✅ Per-story task breakdown by repo
- ✅ Outputs markdown + Jira CLI template
- ✅ Can create stories/tasks via Atlassian MCP

**Future:**
- [ ] Detect existing stories/tasks and suggest refactoring
- [ ] Validate story AC coverage against epic AC
- [ ] Suggest effort estimates per task (based on prior work)
- [ ] Integrate with CI/CD for bulk story creation
- [ ] Detect cross-repo dependencies and surface ordering constraints
- [ ] Auto-assign tasks to team members based on repo expertise

---

## See Also

- **`README.md` → "Suggested Jira Structure"** — detailed structure guidance with examples
- **`/msad-dev-epic`** — orchestrates epic execution once structure is in place
- **`/msad-dev-planning`** — generates implementation plan from structured epic
- **`references/repo-topology.md`** — repo mapping, per-repo files, commands
