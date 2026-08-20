---
name: msad-dev-epic
description: "End-to-end epic execution orchestrator with mandatory planning gates. Discovers tasks, ensures each has an approved dev plan (invoking /msad-dev-planning if needed), and orchestrates execution via /msad-dev-execution. Reports Backend PRs ready for review; filters out Frontend/UI tasks."
version: 1.0.0
created_by:
  name: Seshachalam Malisetti
  role: MSAD Epic Orchestration with Planning Gates
---

# MSAD Developer — Epic Execution (with Mandatory Plans)

End-to-end epic automation with bounded-review planning gates: discovers epic/story tasks, classifies Backend/Frontend, ensures each Backend task has an approved plan (creates via `/msad-dev-planning` if needed), orchestrates execution via `/msad-dev-execution`, reports results.

**Key change:** This skill no longer dispatches implementation agents directly. It loops per-task through `/msad-dev-planning` (if plan missing/draft) and then `/msad-dev-execution`. This ensures **every task passes a bounded-reviewed, approved plan before any code is written.**

## Quick Start

```bash
/msad-dev-epic DDIDNS-7732
```

Input an epic or story ID. The skill:
1. Fetches epic/story + all linked Backend tasks (Frontend/UI are listed as excluded)
2. For each Backend task:
   - Check if an approved plan exists (search `specs/msad-dev-plans/*-<task-id>-plan.md` with `status: approved`)
   - If missing/draft: invoke `/msad-dev-planning <task-id>` (plan creation + bounded review + user approval)
   - Then: invoke `/msad-dev-execution <plan-path>` (implementation + tests + code review + draft PR)
3. Consolidates all results
4. Reports: "All Backend PRs ready for human review. X Frontend/UI tasks excluded (separate track)."

## Inputs

- **epic_id** (required): Jira epic ID, e.g., `DDIDNS-7732`
- **phase** (optional, default: `1`): Which epic phase(s) to execute (`1`, `2`, or `all`)
- **mode** (optional, default: `auto`): Execution mode (`auto`, `dry-run`, or `real`)

## Process Overview

```
Input: Epic/Story ID (DDIDNS-7732 or DDIDNS-10562)
  ↓
Step 1: Discovery
  ├─ Fetch epic/story via Atlassian MCP
  ├─ List all linked Backend/Frontend/QA tasks (classify per references/functional-area-classification.md)
  ├─ Keep list of Backend tasks for planning+execution; exclude Frontend/UI for reporting
  └─ Note existing PRs per Backend task (for context, not direct dispatch)

Step 2: Loop Per Backend Task — Gated Planning + Execution
  For each Backend task:
    ├─ Check: does an approved plan exist? (search specs/msad-dev-plans/*-<task-id>-plan.md with status: approved)
    │
    ├─ If NO plan or plan status: draft:
    │   └─ Invoke /msad-dev-planning <task-id>
    │       → produces dev plan with Gherkin scenarios + conflict-aware batches
    │       → bounded-review loop (≤3 rounds, fresh-context reviewer)
    │       → user approval gate (status: draft → approved)
    │
    └─ Invoke /msad-dev-execution <plan-path>
        → dispatches msad-backend-dev per conflict-aware batches (parallel-safe)
        → bounded code-review loop (≤3 rounds, msad-code-review agent)
        → opens draft PR per repo/package
        → returns result

  Parallel dispatch: Backend tasks with no plan dependencies can be processed in parallel batches

Step 3: Consolidate & Report
  ├─ Collect all Backend results (plan status + execution status + PR links)
  ├─ Verify all Backend tests passing
  ├─ Verify all Backend coverage ≥80%
  ├─ Generate consolidated report
  ├─ List excluded Frontend/UI/QA tasks
  └─ Return: status (all-ready-for-review / some-blockers)
```

## Workflow Details

### Step 1: Discovery

1. **Fetch epic/story** via `getJiraIssue(DDIDNS-7732)` — get summary, description, status
2. **List linked issues** via JQL: `parent = DDIDNS-7732` — all tasks/stories
3. **Classify Backend vs. Frontend/UI** for each linked task. See `references/functional-area-classification.md` for the authoritative signal list (do not duplicate it here — cite the reference).
   - Classify each task as ✅ **Backend** (in-scope, will be gated + executed), 🚫 **Frontend/UI** (excluded, separate team), or ❓ **QA** (separate handling)
   - Keep a list of excluded Frontend/UI/QA tasks for reporting in Step 3
4. **Discover existing PRs + review context** (prefer to COMPLETE existing PRs, not create duplicates):
   - For each Backend task, run `gh pr list --search <task-id>` to find related PRs (open, draft, merged)
   - **For each discovered PR:** fetch full PR details, parse comments/reviews, identify:
     - Current state (DRAFT/OPEN/MERGED)
     - Blocking findings (must address)
     - Non-blocking feedback (should address / justify)
     - Current test status / coverage
   - **Strategy:** If DRAFT or OPEN PR exists, plan to complete/improve it (checkout branch, add missing work)
   - **Only create new PR** if no existing PR found for that Backend task
   - This context informs the plan (what gaps exist, what feedback to address, what's been tried)
5. **State after discovery:**
   > Discovery complete. Backend: `<N>` tasks. Existing PRs with context: `<K>` found. Frontend/UI excluded: `<M>`. QA excluded: `<Q>`.

### Step 2: Loop Per Backend Task — Gated Planning + Execution

For each Backend task discovered in Step 1:

1. **Check for approved plan:**
   - Search `specs/msad-dev-plans/` for `*-<task-id>-plan.md` with `status: approved`
   - If found → proceed to Step 2b (invoke execution)
   - If not found or `status: draft` → proceed to Step 2a (invoke planning)

2. **Step 2a — Create/Approve Plan (if needed):**
   - Invoke `/msad-dev-planning <task-id>`
   - This produces a plan with Gherkin scenarios, conflict-aware task batches, and traceability tables
   - Runs a bounded-review loop (≤3 rounds, fresh-context reviewer)
   - User approves: `status: draft → approved`
   - When approved, the plan file is ready for execution

3. **Step 2b — Execute Approved Plan:**
   - Invoke `/msad-dev-execution <plan-path>` (path to the approved plan from Step 2a)
   - Executes strictly per the plan's "Parallel Execution Batches"
   - Runs bounded code-review loop (≤3 rounds, msad-code-review agent)
   - Opens draft PR(s) per repo/package
   - Returns: test results, coverage, PR links

4. **Parallelization:**
   - Backend tasks with no plan-level dependencies can have their (Step 2a + Step 2b) processed in parallel
   - Within a task's plan, Step 5a (conflict-aware batching) determines parallelization of implementation
   - **Don't block on one task's CI while another is ready to start.** If Task A's PR is pushed and its CI is running, move immediately to Task B's planning/execution rather than waiting idle — see `/msad-dev-execution`'s "Non-Blocking CI Verification" section. Check back on Task A's CI when it completes or when other work reaches a pause point.

### Step 3: Consolidate & Report

**Metrics per Backend agent:**
- Test results (pass/fail)
- Coverage % (threshold check)
- Files modified
- Commits pushed
- Ready-for-review status

**Frontend/UI exclusion summary:**
- List all tasks classified as 🚫 Frontend/UI
- Example: "3 tasks excluded — Frontend/UI, managed by separate team: DDIDNS-10544 (Portal selector), DDIDNS-10548 (Portal UI), DDIDNS-10563 (Portal design)"

**Consolidated Backend status:**
- All Backend tests passing? ✅ / ❌
- All Backend coverage ≥80%? ✅ / ❌
- All Backend PRs pushed? ✅ / ❌
- Summary: "4/4 Backend PRs ready for human review. 3 Frontend/UI tasks excluded (separate track)." or "PR 507 coverage low (78%). 2 Frontend/UI tasks excluded."

## Success Criteria

- ✅ All linked tasks have PRs (either partial or complete)
- ✅ All partial PRs have gaps closed
- ✅ All tests passing locally + CI
- ✅ All coverage ≥80% (≥92% for gap fixes)
- ✅ All changes committed & pushed
- ⏳ Merges: human gate (not automated)

## Example: DDIDNS-7732

```
Input: /msad-dev-epic DDIDNS-7732

Discovery:
  Epic DDIDNS-7732 (Implementing)
  27 linked tasks/stories
  Classification (Backend vs. Frontend/UI):
    - Backend: 20 tasks
    - Frontend/UI: 7 tasks (excluded from dispatch)
  4 existing draft PRs (507, 508, 241, 6300) — all Backend
  3 Backend tasks not-started (10521, 10541)

Dispatch (Backend only):
  Agent 1: PR 507 (partial, gap: handler tests)
  Agent 2: PR 508 (complete, review)
  Agent 3: PR 241 (partial, gap: error codes)
  Agent 4: PR 6300 (complete, review)
  Agent 5: Task 10521 (not-started, agent validation)
  Agent 6: Task 10541 (not-started, E2E verification)
  [Skipped Frontend/UI: Task 10544, 10548, 10563 — managed by separate team]

Results:
  ✅ PR 507: tests added, coverage 92.3%, ready
  ✅ PR 508: tests pass, CI green, ready
  ✅ PR 241: test cases added, coverage 92.1%, ready
  ✅ PR 6300: tests pass, CI green, ready
  ✅ Task 10521: implementation complete, PR 999 ready
  ✅ Task 10541: implementation complete, PR 1000 ready
  
  Frontend/UI Excluded (separate track):
    • DDIDNS-10544: Portal selector for replication scope
    • DDIDNS-10548: Portal form for scope changes
    • DDIDNS-10563: Portal UI design + implementation

Report: 6/6 Backend PRs ready for human review. 3 Frontend/UI tasks excluded (managed by separate team).
```

## Phase Support

Automatically handles multi-phase epics:

- **Phase 1 (CREATE):** Zone creation with replication scope (active in DDIDNS-7732)
- **Phase 2 (UPDATE):** Zone scope changes (deferred, status=To Do)
- **Phase N (X):** Other phases (discovered via parent story status)

Dispatches agents only for active phase tasks unless `--all-phases` flag used.

## Review Comment Handling

The skill discovers and prioritizes existing PR review comments:

- **Blocking comments** (e.g., "Coverage must be ≥92%") → Must address
- **Non-blocking comments** (e.g., "Consider refactoring X") → Should address
- **Informational comments** → Acknowledge in PR body

Agents receive comment context and address feedback systematically. Final PR body documents which comments were resolved. This is the same PR-context discovery described in Step 1.4 above — no separate workflow.

## Limitations & Future Work

**Current:**
- ✅ Discovers and executes Phase 1 tasks only
- ✅ Handles partial PRs with gap completion
- ✅ Runs tests locally with Docker
- ✅ Dispatches parallel subagents
- ✅ Analyzes and addresses PR review comments

**Future:**
- [ ] Windows CI integration for ddi.msad.agent (currently CI-only)
- [ ] Cross-repo dependency ordering (proto → middleware → collector)
- [ ] Automatic PR merge when all gates pass (currently human gate only)
- [ ] Integration with JIRA transitions (mark task "In Progress" / "Done")
- [ ] Slack notifications per agent completion

## Related Skills

- **`/msad-dev-epic --scope story`** — same orchestrator, scoped to a single story (smaller scope, faster); use for one-story focus
- **`/msad-dev-planning`** — invoked internally by this skill (Step 2a) to create/review plans per task; also available standalone for detailed analysis
- **`/msad-dev-execution`** — invoked internally by this skill (Step 2b) to execute approved plans; also available standalone
- **`/msad-backend-dev`** — implements a single task; dispatched as subagent by `/msad-dev-execution`
- **`/msad-code-review`** — reviews PR diffs; invoked as subagent by `/msad-dev-execution`'s bounded code-review loop

**Architecture note:** `/msad-dev-epic` no longer directly dispatches implementation agents. Instead, it loops: per-task planning (via `/msad-dev-planning`) → approval gate → execution (via `/msad-dev-execution`). This ensures every task passes a bounded-reviewed plan before code is written.
