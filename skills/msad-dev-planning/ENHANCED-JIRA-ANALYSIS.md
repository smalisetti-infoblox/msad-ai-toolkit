# MSAD Developer — Planning (ENHANCED)

Enhanced Jira analysis for epics, incorporating improvements 1–3.

## Enhanced Step 2: Jira Analysis with Hierarchy & Phase Detection

### Substep 2.1: Fetch Epic + Linked Issues (Same as Before)

Use Atlassian MCP tools:
- `getJiraIssue` for the ticket (summary, description, AC, components, status, fix versions)
- `getJiraIssue` for parent epic if this is a story/task
- `getJiraIssue` for each linked ticket (blocks / blocked-by / relates-to)

Result: Flat list of 20–30 issues with standard fields.

### Substep 2.2: Build Jira Hierarchy Map (NEW)

**Goal:** Organize the flat list into a structured hierarchy.

**Process:**

1. **Group by type:**
   - Root: Epic (1)
   - Level 2: Stories (N)
   - Level 3: Tasks (M per story)
   - Level 4: Subtasks (P per task, if any)

2. **Identify parent-child relationships:**
   - If issue.parent exists, use it
   - Otherwise, infer from title/description keywords
   - Example: "ddi.cloud.proxy.middleware: support Domain/Forest replication scope..." belongs under "Backend: Domain/Forest support" story

3. **Output structured tree:**
   ```
   DDIDNS-7732 (Epic)
   ├── DDIDNS-10562 (Story): Backend: support Domain/Forest scope
   │   ├── DDIDNS-10519 (Task): Middleware — Auth/Forward zone creation
   │   ├── DDIDNS-10542 (Task): Middleware — idempotency
   │   ├── DDIDNS-10543 (Task): Collector — error-code mapping
   │   └── DDIDNS-10521 (Task): Agent — validation
   ├── DDIDNS-10563 (Story): Portal UI: replication scope selector
   │   ├── DDIDNS-10544 (Task): Add selector to zone creation form
   │   └── DDIDNS-10548 (Task): Add editor to existing zones (UPDATE)
   ├── DDIDNS-10546 (Story): Audit: capture scope and target server
   │   └── DDIDNS-10546 (Task): Add audit logging for zone creation
   └── DDIDNS-10510 (Story): QA: test planning and automation
       ├── DDIDNS-10511 (Task): Integration test
       └── DDIDNS-10512 (Task): Stage testing
   ```

### Substep 2.3: Detect Phases & Functional Areas (NEW)

**Goal:** Identify natural groupings (phases, functional areas) to organize the plan.

**Phase Detection Logic:**

1. **Keyword analysis on summaries:**
   ```
   Phase 1 keywords: "create", "creation", "new"
   Phase 2 keywords: "update", "change", "modify", "delete"
   ```

2. **Status clustering:**
   - If all Phase 1 tasks: status in [To Do, Draft PR, In Progress] → Phase 1 is active
   - If all Phase 2 tasks: status in [None, Aborted] → Phase 2 is deferred

3. **Inference:**
   ```
   Phase 1 (Zone Creation):
     - All Phase 1 keywords (create, creation)
     - Status: To Do or Draft PR (active work)
     - Action: Include in this plan
   
   Phase 2 (Zone Update):
     - All Phase 2 keywords (update, change)
     - Status: None or Aborted (not active)
     - Action: Mark as deferred, exclude from this plan
   ```

**Functional Area Detection Logic:**

```
For each task, match summary against keyword patterns:

Backend:     "middleware", "proxy", "agent", "collector", "dns.config"
Portal UI:   "portal", "UI", "frontend", "form", "selector", "editor"
Audit:       "audit", "log", "logging", "capture"
Error Hdlg:  "error", "handle", "code", "status", "mapping"
QA:          "QA", "test", "automation", "stage", "integration"
```

**Output:** Hierarchical organization with phase and functional area labels:

```
## Phase 1: Zone Creation (Active)

### Backend Track
- DDIDNS-10519 (Task): Middleware — Domain/Forest scope support
- DDIDNS-10542 (Task): Middleware — idempotency
- DDIDNS-10543 (Task): Collector — error-code mapping

### Audit Track
- DDIDNS-10546 (Task): Audit logging for zone creation

### Portal UI Track
- DDIDNS-10544 (Task): Replication scope selector

### QA Track
- DDIDNS-10511, 10512, 10513 (Tasks): Test planning, automation

## Phase 2: Zone Update (Deferred)

Rationale: All Phase 2 tasks in "None" or "Aborted" status; no active work.

### Backend Track
- DDIDNS-10547 (Task): Allow scope changes on zone UPDATE

### Portal UI Track
- DDIDNS-10548 (Task): Allow editing scope on existing zones
```

---

## Enhanced Step 3: Repo Context with PR Discovery & Correlation

### Substep 3.1: Read Per-Repo CLAUDE.md (Same as Before)

For each involved repo, read CLAUDE.md and record coding conventions, build commands, etc.

### Substep 3.2: Existing PR Discovery (Enhanced)

**Goal:** For each task in the epic, search GitHub for related PRs.

**Process:**

For each repo in the MSAD ecosystem:
```bash
gh pr list --repo Infoblox-CTO/<repo> --search "<JIRA_ID>" --state all --limit 15
```

Collect:
- PR number
- PR state (DRAFT, OPEN, CLOSED)
- PR title (verify it matches the task)
- PR created/updated date

Example results:
```
DDIDNS-10519 → PR 507 in ddi.cloud.proxy.middleware (DRAFT, created 2026-08-12)
DDIDNS-10542 → PR 508 in ddi.cloud.proxy.middleware (DRAFT, created 2026-08-12)
DDIDNS-10543 → PR 241 in ddi.msad.collector (DRAFT, created 2026-08-12)
DDIDNS-10521 → (no PR found)
```

### Substep 3.3: Correlate Task ↔ PR Status (NEW)

**Goal:** For each task, determine if it's complete, in progress, or not started based on PR status.

**Correlation Matrix:**

| Task Status (Jira) | PR Status (GitHub) | Assessment | Action |
|---|---|---|---|
| To Do | PR DRAFT | Partial work in progress | Include in plan as "partially implemented, needs gap fixes" |
| To Do | PR OPEN | In progress, under review | Include in plan as "in progress, continue work" |
| To Do | PR CLOSED/MERGED | Done | Acknowledge as complete; mark for verification |
| To Do | No PR | Not started | Include in plan as "requires implementation" |
| None | No PR | Deferred (no active work) | Mark as "Phase 2, deferred" |
| Aborted | No PR | Abandoned planning iteration | Note as historical, deprioritize |

**Output: Task-PR Correlation Table**

```markdown
| Task ID | Task Summary | Jira Status | PR | PR Status | Assessment |
|---|---|---|---|---|---|
| DDIDNS-10519 | Middleware: Domain/Forest scope | To Do | 507 | DRAFT | 🟡 Partial work, gap assessment needed |
| DDIDNS-10542 | Middleware: idempotency | To Do | 508 | DRAFT | 🟡 Partial work, gap assessment needed |
| DDIDNS-10543 | Collector: error-code mapping | To Do | 241 | DRAFT | 🟡 Partial work, gap assessment needed |
| DDIDNS-10546 | DNS Config: audit logging | To Do | 6300 | DRAFT | 🟡 Partial work, gap assessment needed |
| DDIDNS-10521 | Agent: validation | To Do | — | — | ⏳ Not started |
| DDIDNS-10547 | Backend: allow scope changes (UPDATE) | None | — | — | ❌ Deferred (Phase 2) |
| DDIDNS-10548 | Portal UI: allow editing scope (UPDATE) | None | — | — | ❌ Deferred (Phase 2) |
```

### Substep 3.4: PR Gap Assessment (NEW)

**Goal:** For each existing PR, assess what work remains before it's ready for merge. Treat PRs as partially implemented work, not as finished artifacts.

**Process:**

For each PR with DRAFT status:

1. **Fetch PR metadata:**
   ```bash
   gh pr view <PR_NUMBER> --repo <REPO> --json body,state,draft,commits,files,checks
   ```

2. **Get PR description and commits to understand scope:**
   - What does the PR aim to implement?
   - Which Jira ACs does it claim to address?

3. **Fetch PR diff to analyze implementation:**
   ```bash
   gh pr diff <PR_NUMBER> --repo <REPO>
   ```
   - Files changed
   - Code added/modified
   - Tests added

4. **Compare against Jira task Acceptance Criteria:**
   - For each AC in the task, is it implemented?
   - Are there test cases covering each AC?
   - Are edge cases handled?

5. **Check code quality against toolkit standards:**
   - Run `make test` / `dotnet test` on the PR branch (conceptually)
   - Verify test coverage ≥ threshold (75% Go, 70% C#)
   - Verify lint/fmt pass
   - Identify any obvious gaps or incomplete patterns

6. **Assess PR readiness:**

   ```markdown
   PR 507: DDIDNS-10519 (ddi.cloud.proxy.middleware)
   
   **PR Summary:** "Allow Domain/Forest replication scope for Auth and Forward zone creation"
   
   **Jira Task:** DDIDNS-10519
   **Jira ACs:**
   - AC1: User can create Domain-replicated zones (via Auth Zone)
   - AC2: User can create Forest-replicated zones (via Auth Zone)
   - AC3: Middleware validates scope before forwarding to collector
   - AC4: Handler tests verify scope round-trips to DDI write
   
   **PR Implementation Status:**
   ✅ AC1: Implemented in `toMSADCreateAuthZoneRequest`, test coverage present
   ✅ AC2: Implemented in `toMSADCreateAuthZoneRequest`, test coverage present
   ✅ AC3: Validator shared across Auth/Forward/Stub zones, tests passing
   ⚠️  AC4: Handler tests for Auth Zone Create/Update present, but **Conditional Forwarder scope validation NOT tested**
   
   **Gap Analysis:**
   - Missing: DnsConditionalForwarderZoneController handler test for scope validation
   - Missing: Edge case coverage for Conditional Forwarder with domain/forest scopes
   - Test coverage: 87% (acceptable, ≥80%, but incomplete for Conditional Forwarder)
   
   **Plan for Execution Phase:**
   1. Add handler test case: `Test_DnsConditionalForwarderZoneController_Create_DomainScope`
   2. Add handler test case: `Test_DnsConditionalForwarderZoneController_Create_ForestScope`
   3. Re-run coverage check, verify ≥80%
   4. Merge when all ACs fully covered
   
   **Readiness:** 🟡 **Partial work — needs gap fixes before merge**
   ```

7. **Output: PR Gap Assessment Matrix**

   ```markdown
   | PR | Task | ACs Covered | Gaps | Coverage | Readiness | Action |
   |---|---|---|---|---|---|---|
   | 507 | DDIDNS-10519 | 3/4 | Conditional Forwarder tests missing | 87% | 🟡 Partial | Add tests, re-verify |
   | 508 | DDIDNS-10542 | 1/1 | None identified | 92% | 🟢 Complete | Ready (needs review) |
   | 241 | DDIDNS-10543 | 1/1 | None identified | 85% | 🟢 Complete | Ready (needs review) |
   | 6300 | DDIDNS-10546 | 1/1 | None identified | 78% | 🟢 Complete | Ready (needs review) |
   ```

**Key Principle:** Treat DRAFT PRs as **starting points for execution, not as finished work.** The execution phase will:
- Complete any gap fixes
- Run full test suite
- Verify coverage and quality
- Refine/iterate as needed
- Merge only when ready

---

## Enhanced Step 6: Clarifying Questions (Updated)

With hierarchy + phase detection + PR correlation, ask targeted questions:

1. **Phase scope:** "This epic has two phases: Phase 1 (CREATE, complete in 4 draft PRs) and Phase 2 (UPDATE, deferred). Should this plan cover Phase 1 only, or do you want Phase 2 in scope?"

2. **Deferred work:** "The following tasks are in Phase 2 (UPDATE) and will be marked out of scope: DDIDNS-10547, DDIDNS-10548. Is that acceptable?"

3. **Existing PRs:** "These 4 PRs are already in draft and ready for review: 507, 508, 241, 6300. Should this plan focus on coordinating their review rather than starting new implementation?"

---

## Enhanced Step 7: Plan Template Output

The plan file now includes:

1. **Frontmatter with structure info:**
   ```yaml
   ---
   jira: DDIDNS-7732
   jira-type: Epic
   phases: [1, 2]
   phase-in-scope: 1
   existing-prs: 4
   tasks-in-scope: 5
   tasks-deferred: 2
   status: ready-for-review
   ---
   ```

2. **Executive summary with phase structure:**
   ```markdown
   ## Summary
   
   Phase 1 (CREATE): Complete in 4 draft PRs, ready for coordinated review
   Phase 2 (UPDATE): Deferred (separate initiative, not started)
   ```

3. **Jira Hierarchy & Task Status Matrix:**
   ```markdown
   ## Jira Hierarchy & Task Status
   
   [Full hierarchy tree showing phases, stories, tasks, PR status]
   [Task-PR correlation table]
   ```

4. **Phase-organized work packages:**
   ```markdown
   ## Phase 1 Work Packages (In Scope)
   
   ### PR 507: DDIDNS-10519 — Middleware: Domain/Forest Scope
   ...
   
   ### PR 508: DDIDNS-10542 — Middleware: Idempotency
   ...
   
   ## Phase 2 Work Packages (Deferred)
   
   Rationale: Phase 2 tasks all in "None" status; no active work.
   ```

---

## Summary of Improvements

| Improvement | Before | After | Benefit |
|---|---|---|---|
| **Hierarchy** | Flat list of 27 tickets | Organized Epic → Phase → Story → Task | Clear scope boundaries |
| **Phase detection** | All work treated equally | Phase 1 vs. Phase 2 explicitly identified | Deferred work flagged upfront |
| **PR correlation** | PRs discovered late, manually | PR status integrated into task assessment | Clear what's complete vs. remaining |
| **Task-PR matrix** | No single source of truth | One authoritative table showing all status | Fewer surprises during approval |
| **Scope clarity** | Vague ("this epic work") | Explicit ("Phase 1: CREATE in 4 draft PRs") | User knows exactly what's in/out |

---

## Implementation Notes

**Reference implementations available:**
- `lib/jira-hierarchy-builder.sh` — builds hierarchy from fetched Jira data
- `lib/phase-detector.sh` — detects phases and functional areas
- `lib/pr-correlation.sh` — discovers and correlates PRs to tasks

**Integration into planning workflow:**
1. After Step 2 (Jira Analysis), run improvements 1-3 to produce enhanced outputs
2. Use outputs to inform Step 6 (Clarifying Questions)
3. Present enhanced hierarchy + phase structure + task-PR matrix to user before Step 8 (Approval)
4. User approves plan with full visibility into phase scope and PR status
