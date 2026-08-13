---
name: msad-dev-story
description: "Story-level epic execution orchestrator. Discovers tasks linked to a single Jira Story, classifies Backend/Frontend/UI, identifies gaps in draft PRs, dispatches parallel subagents to complete Backend work only, and reports consolidated results. Use to drive single-story tasks like DDIDNS-10562 from discovery through ready-for-review, with explicit Backend/Frontend filtering."
version: 0.1.0
created_by:
  name: Seshachalam Malisetti
  role: MSAD Story Orchestration
---

# MSAD Developer — Story Execution

Story-level automation: discovers tasks linked to a story, classifies Backend vs. Frontend/UI, identifies partial PRs, dispatches subagents for Backend work only, orchestrates execution, reports results.

## Quick Start

```bash
/msad-dev-story DDIDNS-10562
```

Input a story ID. The skill:
1. Fetches story + all linked tasks
2. Classifies Backend vs. Frontend/UI
3. Discovers existing draft PRs (via `gh pr list`, Backend tasks only)
4. Identifies gaps and completion status per Backend PR
5. Dispatches parallel subagents to:
   - Complete gaps in partial Backend PRs (add tests, verify coverage)
   - Review complete Backend PRs (run tests, verify CI)
   - Implement fresh Backend tasks (if no PR exists)
6. Consolidates results
7. Reports: "All Backend PRs ready for human review" or "X issues to resolve"; lists excluded Frontend/UI tasks

## Inputs

- **story_id** (required): Jira story ID, e.g., `DDIDNS-10562`
- **mode** (optional, default: `auto`): Execution mode (`auto`, `dry-run`, or `real`)

## Process Overview

```
Input: Story ID (DDIDNS-10562)
  ↓
Step 1: Discovery
  ├─ Fetch story via Atlassian MCP
  ├─ List all linked tasks
  ├─ Classify Backend vs. Frontend/UI (keyword matching on summary)
  │   ├─ Backend signals: "middleware", "collector", "agent", "dns.config", "dns.data", "proxy", "backend"
  │   └─ Frontend/UI signals: "portal", "UI", "frontend", "form", "selector", "editor"
  ├─ Discover existing PRs (gh pr list per repo, Backend tasks only)
  ├─ Classify: partial vs. complete vs. not-started (Backend PRs only)
  ├─ Identify gaps per Backend PR
  └─ Fetch & analyze PR review comments (blocking vs. non-blocking)

Step 2: Dispatch Subagents (Parallel, Prioritized) — Backend-Only
  ├─ For each partial Backend PR with review feedback:
  │   └─ Agent: address gaps + blocking comments → verify coverage → commit → push
  ├─ For each complete Backend PR:
  │   └─ Agent: run tests → verify CI → ready for review
  └─ For each not-started Backend task:
      └─ Agent: implement → test → commit → push → draft PR

Step 3: Consolidate & Report
  ├─ Collect all Backend results
  ├─ Verify all Backend tests passing
  ├─ Verify all Backend coverage ≥80%
  ├─ Track which review comments were addressed
  ├─ Generate per-PR summary (Backend PRs only)
  ├─ List excluded Frontend/UI tasks
  │   └─ "X tasks excluded — Frontend/UI, managed by separate team: DDIDNS-10544, 10548"
  └─ Return: status (ready-for-review / issues-found)
```

## Workflow Details

### Step 1: Discovery

1. **Fetch story** via `getJiraIssue(DDIDNS-10562)` — get summary, description, status
2. **List linked issues** via JQL: `parent = DDIDNS-10562` — all tasks
3. **Classify Backend vs. Frontend/UI** for each linked task (keyword matching on summary):
   - **Frontend/UI signals:** "portal", "UI", "frontend", "form", "selector", "editor" → classify as 🚫 Frontend/UI (excluded from dispatch)
   - **Backend signals:** "middleware", "collector", "agent", "dns.config", "dns.data", "proxy", "backend" → classify as ✅ Backend (will be dispatched)
   - **No signals:** default to ✅ Backend
   - **Keep a list of excluded Frontend/UI tasks** for reporting in Step 3
4. **Discover PRs** — for each Backend task, run `gh pr list --search <task-id>` (skip Frontend/UI tasks)
5. **Classify Backend PRs:**
   - **Partial** — DRAFT status + gap identified in description
   - **Complete** — DRAFT status + no gap identified
   - **Not-started** — no PR found for task
6. **Identify gaps** — parse PR description or infer from task AC
7. **Fetch review comments** — analyze blocking vs. informational feedback

### Step 2: Dispatch Subagents (Parallel)

For independent Backend work packages (no cross-repo dependencies), agents run in parallel. Order matters only when:
- Proto change must land before middleware that consumes it
- Error-code addition must precede collector mapping PR

Each agent receives:
- Task ID + PR link (if exists)
- Gap description or full task spec
- Any blocking review comments
- Success criteria (coverage ≥92%, tests pass, CI green)

Frontend/UI tasks are **never** dispatched — they are noted in Step 3 reporting only.

### Step 3: Consolidate & Report

**Metrics per Backend agent:**
- Test results (pass/fail)
- Coverage % (threshold check)
- Files modified
- Commits pushed
- Ready-for-review status

**Frontend/UI exclusion summary:**
- List all tasks classified as 🚫 Frontend/UI
- Example: "2 tasks excluded — Frontend/UI, managed by separate team: DDIDNS-10545 (Portal form), DDIDNS-10546 (Portal design)"

**Consolidated Backend status:**
- All Backend tests passing? ✅ / ❌
- All Backend coverage ≥80%? ✅ / ❌
- All Backend PRs pushed? ✅ / ❌
- Summary: "3/3 Backend PRs ready for human review. 2 Frontend/UI tasks excluded (separate track)." or "PR 507 coverage low (78%). 1 Frontend/UI task excluded."

## Success Criteria

- ✅ All Backend linked tasks have PRs (either partial or complete)
- ✅ All partial Backend PRs have gaps closed
- ✅ All Backend tests passing locally + CI
- ✅ All Backend coverage ≥80% (≥92% for gap fixes)
- ✅ All Backend changes committed & pushed
- ✅ Frontend/UI tasks clearly listed as excluded
- ⏳ Merges: human gate (not automated)

## Example: DDIDNS-10562

```
Input: /msad-dev-story DDIDNS-10562

Discovery:
  Story DDIDNS-10562 (Zone Creation - Middleware Layer)
  5 linked tasks
  Classification (Backend vs. Frontend/UI):
    - Backend: 4 tasks
    - Frontend/UI: 1 task (excluded from dispatch)
  2 existing draft PRs (507, 508) — both Backend
  2 Backend tasks not-started (10519, 10520)

Dispatch (Backend only):
  Agent 1: PR 507 (partial, gap: handler tests)
  Agent 2: PR 508 (complete, review)
  Agent 3: Task 10519 (not-started, validation)
  Agent 4: Task 10520 (not-started, error mapping)
  [Skipped Frontend/UI: Task 10545 — managed by separate team]

Results:
  ✅ PR 507: tests added, coverage 92.3%, ready
  ✅ PR 508: tests pass, CI green, ready
  ✅ Task 10519: implementation complete, PR 999 ready
  ✅ Task 10520: implementation complete, PR 1000 ready
  
  Frontend/UI Excluded (separate track):
    • DDIDNS-10545: Portal form for middleware configuration

Report: 4/4 Backend PRs ready for human review. 1 Frontend/UI task excluded (managed by separate team).
```

## Comparison with msad-dev-epic

| Aspect | `msad-dev-epic` | `msad-dev-story` |
|---|---|---|
| Entry point | Epic (DDIDNS-7732) | Story (DDIDNS-10562) |
| Scope | All stories + tasks under epic | All tasks under single story |
| Dispatch breadth | Typically 6–8 agents (multi-story) | Typically 2–4 agents (single-story) |
| Use case | "Orchestrate entire epic release" | "Complete one story in the epic" |
| Timeline | ~20–30 min | ~10–15 min |
| Backend/Frontend filtering | ✅ Yes (same rules as planning) | ✅ Yes (same rules as planning) |

**When to use each:**
- Use `msad-dev-epic` to orchestrate the full epic (all phases, all stories)
- Use `msad-dev-story` to focus on a single story within an epic (faster, more granular)

## Limitations & Future Work

**Current:**
- ✅ Discovers and executes single-story Backend tasks only
- ✅ Handles partial PRs with gap completion
- ✅ Runs tests locally with Docker
- ✅ Dispatches parallel subagents
- ✅ Analyzes and addresses PR review comments
- ✅ Filters out Frontend/UI tasks

**Future:**
- [ ] Windows CI integration for ddi.msad.agent (currently CI-only)
- [ ] Cross-repo dependency ordering (proto → middleware → collector)
- [ ] Automatic PR merge when all gates pass (currently human gate only)
- [ ] Integration with JIRA transitions (mark task "In Progress" / "Done")
- [ ] Slack notifications per agent completion

## Related Skills

- **`/msad-dev-epic`** — orchestrates full epic (all stories); use for multi-story releases
- **`/msad-dev-planning`** — generates detailed plan with Backend/Frontend split (still used for upfront planning)
- **`/msad-dev-execution`** — dispatches agents (called internally by this skill, also standalone)
- **`/msad-backend-dev`** — implements a single task (dispatched as subagent by this skill)
- **`/msad-code-review`** — reviews a PR (can be invoked manually for detailed review)
