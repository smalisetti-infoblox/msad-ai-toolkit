# MSAD Dev Planning: Enhanced Jira Analysis for Epics

**Status:** Improvements 2 (Phase Detection) and 7 (Scope Boundaries) have been promoted into SKILL.md Step 2b (Functional Area Classification). This document serves as design reference; live implementation is in SKILL.md.

**Purpose:** Improve how the msad-dev-planning skill analyzes Jira epics, stories, tasks, and subtasks to produce better plans that account for work phases, scope boundaries, and existing PRs.

**Motivation:** Current analysis missed critical structure in DDIDNS-7732:
- Two-phase epic (CREATE vs. UPDATE) was not identified
- Deferred work was not flagged upfront
- Task-to-PR correlation was incomplete
- Duplicate/overlapping tasks in different statuses were not consolidated

---

## Current Gaps

| Gap | Example | Impact |
|---|---|---|
| No hierarchy analysis | 27 linked tickets treated as flat list | Scope boundaries invisible; deferred work hidden |
| No phase detection | CREATE (Phase 1) and UPDATE (Phase 2) not distinguished | Plan scope ambiguous |
| No task-PR correlation | DDIDNS-10519 task vs. PR 507 status not connected | Unclear what work is done vs. remaining |
| No status consolidation | Same task in "To Do", "Aborted", "None" status treated separately | Confusion about active work items |
| No deferred-work flagging | UPDATE tasks listed but not marked as deferred | Risk of scope creep |
| No scope matrix | Task list without clear "in this plan" vs. "out of this plan" | Requires user to infer scope |

---

## Improvement 1: Build Jira Hierarchy Map

**Goal:** Organize tickets into a structured hierarchy before analysis.

**Process:**

1. Fetch the epic via `getJiraIssue`
2. For each linked issue, fetch it and identify:
   - `parent` (if this is a subtask, what task is it under?)
   - `type` (Epic, Story, Task, Subtask)
   - `status` (To Do, In Progress, Done, Aborted, None, etc.)
   - `key` (DDIDNS-XXXXX)
   - `summary`

3. Build a tree structure:
   ```
   DDIDNS-7732 (Epic)
   ├── DDIDNS-10562 (Story)
   │   ├── DDIDNS-10519 (Task)
   │   ├── DDIDNS-10542 (Task)
   │   └── DDIDNS-10521 (Task)
   ├── DDIDNS-10563 (Story)
   │   ├── DDIDNS-10544 (Task)
   │   └── ... (more tasks)
   └── ...
   ```

4. Group by `type` at each level:
   - Epic level: 1 epic
   - Story level: N stories (group tasks under each story)
   - Task level: M tasks per story
   - Subtask level: P subtasks per task (if any)

**Output:** A structure like `EpicNode { stories: [StoryNode { tasks: [TaskNode] }] }`

**Implementation tip:** If Jira doesn't provide `parent` explicitly, infer it from the task title or description (e.g., "DDIDNS-10519: ddi.cloud.proxy.middleware: support Domain/Forest..." clearly belongs under backend stories, not Portal UI stories).

---

## Improvement 2: Detect Phases & Functional Areas

**Goal:** Identify natural groupings (phases, functional areas) in the epic without explicit "phase" field in Jira.

**Signals:**

- **Title/summary keywords:**
  - "create" → Phase 1 (Creation)
  - "update" / "change" / "modify" → Phase 2 (Updates)
  - "audit" / "log" → Audit functional area
  - "error" / "handle" → Error handling area
  - "UI" / "portal" / "frontend" → Portal/Frontend area
  - "test" / "QA" / "automation" → QA area

- **Dependencies:**
  - If Task A says "after DDIDNS-XYZ ships" in description → A depends on XYZ
  - If all "update" tasks are in "To Do" status while "create" tasks are in "Draft PR" status → create is Phase 1, update is Phase 2

- **Status clustering:**
  - Tickets with the same status (all "To Do" or all "In Progress") often represent the same phase

**Example from DDIDNS-7732:**
```
Phase 1 (CREATE): DDIDNS-10519, 10542, 10543, 10546 → Status: DRAFT PR (complete)
Phase 2 (UPDATE): DDIDNS-10547, 10548 → Status: None/Aborted (deferred)
QA track: DDIDNS-10510–10513 → Status: To Do (parallel)
Portal track: DDIDNS-10563, 10544 → Status: To Do (parallel)
```

**Output:** A phased/grouped organization of tasks.

---

## Improvement 3: Correlate Task ↔ PR Status

**Goal:** For each task, determine if there's an existing PR and what state it's in.

**Process:**

1. For each task (e.g., DDIDNS-10519), search GitHub for related PRs:
   ```bash
   gh pr list --repo Infoblox-CTO/<repo> --search "DDIDNS-10519" --state all --limit 15
   ```

2. Classify the result:
   - **PR found in DRAFT** → Task is "Complete, ready for review"
   - **PR found in OPEN** → Task is "In review, may need changes"
   - **PR found in CLOSED/MERGED** → Task is "Done"
   - **No PR found** → Task is "Not started" (requires implementation)

3. Cross-reference:
   - If task summary says "support Domain/Forest scope" and there's a PR 507 in DRAFT, mark this as `task: DDIDNS-10519, pr: 507, status: DRAFT (ready for review)`

**Output:** A task-PR correlation table like:

| Task | PR | Status | Notes |
|---|---|---|---|
| DDIDNS-10519 | 507 | DRAFT | Ready for review |
| DDIDNS-10521 | — | Not started | Deferred |
| DDIDNS-10542 | 508 | DRAFT | Ready for review |

---

## Improvement 4: Consolidate Duplicate Tasks in Different Statuses

**Goal:** Recognize that the same work appears in multiple statuses (planning iterations) and consolidate.

**Pattern:** The DDIDNS-7732 epic has three sets of linked issues:
- **Status: To Do** (active planned work)
- **Status: Aborted** (previous planning iterations that were abandoned)
- **Status: None** (unstarted, possibly deferred)

Example:
```
DDIDNS-10567 (Aborted): ddi.cloud.proxy.middleware: support Domain/Forest replication scope...
DDIDNS-10519 (To Do, but has PR 507): ddi.cloud.proxy.middleware: support Domain/Forest replication scope...
```

These are **the same work**, just created in different Jira planning cycles. The current active work is DDIDNS-10519 (which has PR 507); DDIDNS-10567 is a stale ticket that was abandoned.

**Process:**

1. Group tasks by (title keywords + repo) to detect duplicates
2. Keep the one with the most recent activity (has PR, has recent comment, etc.)
3. Note that the others are "abandoned planning iterations" (for context, but deprioritize)

**Output:** Deduplicated task list with notes like "This is the active ticket; DDIDNS-10568 is an abandoned iteration of the same work."

---

## Improvement 5: Flag Deferred Work Explicitly

**Goal:** Identify work that is intentionally out of scope for this planning cycle and surface it upfront.

**Signals:**

- Task is in "None" or "Aborted" status (not active)
- Task title includes keywords like "update", "change", "future" but related "create" tasks are in draft PRs
- Task is linked as "depends on" a lower-priority initiative
- Description says "after Phase 1 ships" or "planned for Q3"

**Example from DDIDNS-7732:**
```
DDIDNS-10547: Backend: allow changing replication scope on zone UPDATE
  Status: None (not in "To Do", not in "In Progress")
  Rationale: UPDATE is Phase 2; Phase 1 (CREATE) is what's in draft PRs
  Action: Mark as "Deferred to Phase 2" and call it out in the plan summary
```

**Output:** Explicit section in the plan:
```markdown
## Phase 2 Scope (Deferred)

The following work is intentionally out of scope for Phase 1 (Zone Creation):

| Task | Summary | Reason |
|---|---|---|
| DDIDNS-10547 | Backend: allow changing replication scope on zone UPDATE | Phase 2 — separate initiative, not started |
| DDIDNS-10548 | Portal UI: allow editing replication scope on existing zones | Phase 2 — separate initiative, not started |
```

---

## Improvement 6: Create Task-Status Matrix

**Goal:** Provide a single authoritative table showing all epic tasks, their status, PR status, and scope.

**Template:**

| Task ID | Type | Summary | PR | Jira Status | PR Status | Phase/Area | In This Plan? | Notes |
|---|---|---|---|---|---|---|---|---|
| DDIDNS-10519 | Task | Middleware: Domain/Forest scope for Auth/Forward create | 507 | To Do | DRAFT (ready) | Phase 1 / Backend | ✅ Yes | Complete, ready for review |
| DDIDNS-10542 | Task | Middleware: idempotency | 508 | To Do | DRAFT (ready) | Phase 1 / Backend | ✅ Yes | Complete, ready for review |
| DDIDNS-10521 | Task | Agent: validation | — | None | Not started | Phase 1 / Backend | ⏳ Deferred | Separate planning cycle |
| DDIDNS-10547 | Task | Backend: allow scope changes on UPDATE | — | None | Not started | Phase 2 / Backend | ❌ No | Deferred to Phase 2 |

---

## Improvement 7: Scope Boundary Definition

**Goal:** Explicitly state what's in and out of scope for THIS plan.

**Process:**

1. Ask user (or infer from phase detection): What's the scope boundary?
   - "Phase 1 only (Zone Creation)"
   - "All backend work (exclude Portal UI, QA)"
   - "Middleware only (exclude collector, agent)"

2. For each task, classify:
   - ✅ **In scope** (will be included in this plan)
   - ❌ **Out of scope** (will not be included; either deferred or separate initiative)
   - ⏳ **Deferred** (intentionally pushed to later phase with explicit rationale)

3. State the boundary explicitly in the plan:
   ```markdown
   ## Scope Boundaries

   **In scope:**
   - Zone CREATION with Domain/Forest replication scopes (Phase 1)
   - Middleware scope validation, idempotency, error mapping
   - Audit logging for CREATION (not UPDATE)
   
   **Out of scope:**
   - Zone UPDATE with scope changes (Phase 2, separate initiative)
   - Agent-side validation (DDIDNS-10521, deferred)
   - Portal UI (separate track)
   - QA automation (separate track)
   ```

---

## Improvement 8: Integration with Existing PRs

**Goal:** When analyzing an epic, automatically discover and document existing draft/open PRs, rather than treating PRs as an afterthought.

**Process:**

1. **Parallel to fetching Jira hierarchy**, run `gh pr list` queries for each repo mentioned in the epic
2. Build a PR registry (mapped to Jira tasks)
3. Use PR status to inform task status assessment:
   - If DDIDNS-10519 task has PR 507 in DRAFT → Task is "complete, ready for review" (not "not started")
4. In the plan, surface existing PRs prominently at the top (as the starting point for review)

**Example:**
```markdown
## Context: Existing Draft PRs

The following work is already complete and in draft PRs, ready for review:

| Task | PR | Repo | Status | Summary |
|---|---|---|---|---|
| DDIDNS-10519 | 507 | middleware | DRAFT | Domain/Forest scope for Auth/Forward |
| DDIDNS-10542 | 508 | middleware | DRAFT | Idempotency (duplicate check + rollback) |
| DDIDNS-10543 | 241 | collector | DRAFT | Error-code mapping for Update/Delete |
| DDIDNS-10546 | 6300 | dns.config | DRAFT | Audit logging for zone creation |
```

This makes the plan a "review plan" (coordinate review of existing PRs) rather than an "implementation plan" (start coding).

---

## Implementation Roadmap

### Step 1: Enhanced Jira Fetch (Low effort, high value)

Improve Step 2 (Jira Analysis) of msad-dev-planning skill:

```python
# Current: flat list of 27 tickets
# Improved: structured hierarchy with phases, deferred work flagged

result = {
    "epic": { ... },
    "hierarchy": [
        {
            "phase": "Phase 1: Zone Creation",
            "stories": [
                {
                    "story_id": "DDIDNS-10562",
                    "tasks": [
                        { "task_id": "DDIDNS-10519", "status": "To Do", "has_pr": True, "pr": 507 },
                        ...
                    ]
                },
                ...
            ]
        },
        {
            "phase": "Phase 2: Zone Update (Deferred)",
            "status": "Not started",
            "stories": [ ... ]
        }
    ],
    "task_matrix": [ ... ],
    "scope_summary": "Phase 1 only (Zone Creation)"
}
```

### Step 2: PR Discovery & Correlation (Medium effort, high value)

Improve Step 3 (Repo Context / Existing PR Discovery) of skill:

```python
# For each task, automatically search for related PRs
gh_prs_by_task = {
    "DDIDNS-10519": {
        "repo": "ddi.cloud.proxy.middleware",
        "pr": 507,
        "status": "DRAFT",
        "date": "2026-08-12T06:22:00Z"
    },
    ...
}

# Correlate with task status
for task in all_tasks:
    if task.id in gh_prs_by_task:
        task.pr_status = "complete, ready for review"
    else:
        task.pr_status = "not started"
```

### Step 3: Phase Detection (Medium effort, high value)

Analyze task titles, descriptions, and status to auto-detect phases:

```python
phases = {
    "Phase 1: Zone Creation": [
        tasks matching ("create" in summary AND status in [To Do, Draft PR])
    ],
    "Phase 2: Zone Update (Deferred)": [
        tasks matching ("update" or "change" in summary AND status in [None, Aborted])
    ]
}
```

### Step 4: Task-Status Matrix Generation (Low effort, high value)

Output structured table format (markdown or YAML) that the plan can reference:

```markdown
| Task | Type | Summary | PR | Status | In Scope? |
|---|---|---|---|---|---|
| DDIDNS-10519 | Task | Middleware: Domain/Forest scope | 507 | DRAFT | ✅ Yes |
...
```

---

## Expected Outcomes

With these improvements, the msad-dev-planning skill would:

1. **Produce clearer scope boundaries** — "Phase 1 (CREATE): Complete in 4 draft PRs" vs. "Phase 2 (UPDATE): Deferred"
2. **Surface existing work first** — Start with "Here are 4 existing PRs ready for review" instead of "Here's what needs to be built"
3. **Flag deferred work explicitly** — User sees immediately what's out of scope and why
4. **Reduce planning iteration** — Fewer "wait, what about X?" surprises during user approval
5. **Improve plan reusability** — Future updates to the epic can reuse the same analysis structure

---

## Open Questions

1. **Should phase detection be automatic or user-specified?**
   - Option A: Auto-detect via title/status keywords
   - Option B: User specifies phase boundaries in planning input
   - Recommendation: Auto-detect with user override option

2. **Should PR discovery be required or optional?**
   - Option A: Always run `gh pr list` (adds latency but catches hidden work)
   - Option B: Optional flag (faster, but user must remember to check)
   - Recommendation: Always run (completeness > latency)

3. **How to handle cross-repo tasks?**
   - Example: DDIDNS-10519 (middleware task) might have a corresponding task in collector
   - Should the plan link them?
   - Recommendation: Track cross-repo dependencies explicitly in the hierarchy

4. **Should the plan recommend scope boundaries, or let user decide?**
   - Option A: Skill recommends "Phase 1 only; Phase 2 deferred" based on analysis
   - Option B: Skill presents all options; user chooses
   - Recommendation: Recommend based on PR status + phase detection, but let user override
