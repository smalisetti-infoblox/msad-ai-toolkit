# MSAD Developer — Epic Execution

**End-to-end epic automation:** discovers tasks, existing PRs, identifies gaps, dispatches subagents, orchestrates execution, reports results.

## Quick Start

```bash
/msad-dev-epic DDIDNS-7732
```

Input an epic ID. The skill:
1. Fetches epic + all linked tasks/stories
2. Discovers existing draft PRs (via `gh pr list`)
3. Identifies gaps and completion status per PR
4. Dispatches parallel subagents to:
   - Complete gaps in partial PRs (add tests, verify coverage)
   - Review complete PRs (run tests, verify CI)
   - Implement fresh tasks (if no PR exists)
5. Consolidates results
6. Reports: "All PRs ready for human review" or "X issues to resolve"

## Inputs

- **epic_id** (required): Jira epic ID, e.g., `DDIDNS-7732`

## Process Overview

```
Input: Epic ID (DDIDNS-7732)
  ↓
Step 1: Discovery
  ├─ Fetch epic via Atlassian MCP
  ├─ List all linked tasks/stories
  ├─ Discover existing PRs (gh pr list per repo)
  ├─ Classify: partial vs. complete vs. not-started
  ├─ Identify gaps per PR
  └─ NEW: Fetch & analyze PR review comments (blocking vs. non-blocking)

Step 2: Dispatch Subagents (Parallel, Prioritized)
  ├─ For each partial PR with review feedback:
  │   └─ Agent: address gaps + blocking comments → verify coverage → commit → push
  ├─ For each complete PR:
  │   └─ Agent: run tests → verify CI → ready for review
  └─ For each not-started task:
      └─ Agent: implement → test → commit → push → draft PR

Step 3: Consolidate & Report
  ├─ Collect all results
  ├─ Verify all tests passing
  ├─ Verify all coverage ≥80%
  ├─ Track which review comments were addressed
  ├─ Generate per-PR summary
  └─ Return: status (ready-for-review / issues-found)
```

## Workflow Details

### Step 1: Discovery

1. **Fetch epic** via `getJiraIssue(DDIDNS-7732)` — get summary, description, status
2. **List linked issues** via JQL: `parent = DDIDNS-7732` — all tasks/stories
3. **Discover PRs** — for each repo involved, run `gh pr list --search <epic-id>`
4. **Classify PRs:**
   - **Partial** — DRAFT status + gap identified in description
   - **Complete** — DRAFT status + no gap identified
   - **Not-started** — no PR found for task
5. **Identify gaps** — parse PR description or infer from task AC

### Step 2: Dispatch Subagents (Parallel)

For independent work packages (no cross-repo dependencies), dispatch agents in parallel. Order matters only when:
- Proto change must land before middleware that consumes it
- Error-code addition must precede collector mapping PR

**Agent per PR/task:**
```python
Agent(
  description="Complete PR 507 gap: add handler tests",
  prompt=f"""
  Task: DDIDNS-10519 (Middleware scope support)
  PR: 507 (DRAFT, partial)
  Gap: Conditional Forwarder handler tests missing
  
  Workflow:
  1. Clone & checkout branch
  2. Analyze existing test patterns
  3. Generate & add tests
  4. Run make test (Docker services)
  5. Verify coverage ≥92%
  6. Commit & push
  
  Report: test results, coverage, ready status
  """
)
```

**Awaiting all agents** — collect results, flag any failures.

### Step 3: Consolidate & Report

**Metrics per agent:**
- Test results (pass/fail)
- Coverage % (threshold check)
- Files modified
- Commits pushed
- Ready-for-review status

**Consolidated status:**
- All tests passing? ✅ / ❌
- All coverage ≥80%? ✅ / ❌
- All pushed? ✅ / ❌
- Summary: "4/4 PRs ready for human review" or "PR 507 coverage low (78%)"

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
  4 existing draft PRs (507, 508, 241, 6300)
  3 tasks not-started (10521, 10544, 10541)

Dispatch:
  Agent 1: PR 507 (partial, gap: handler tests)
  Agent 2: PR 508 (complete, review)
  Agent 3: PR 241 (partial, gap: error codes)
  Agent 4: PR 6300 (complete, review)
  Agent 5: Task 10521 (not-started, agent validation)
  Agent 6: Task 10544 (not-started, portal UI)
  Agent 7: Task 10541 (not-started, E2E verification)

Results:
  ✅ PR 507: tests added, coverage 92.3%, ready
  ✅ PR 508: tests pass, CI green, ready
  ✅ PR 241: test cases added, coverage 92.1%, ready
  ✅ PR 6300: tests pass, CI green, ready
  ✅ Task 10521: implementation complete, PR 999 ready
  ⏳ Task 10544: in progress...
  ⏳ Task 10541: in progress...

Report: 4/7 ready for review, 3 in progress
```

## Phase Support

Automatically handles multi-phase epics:

- **Phase 1 (CREATE):** Zone creation with replication scope (active in DDIDNS-7732)
- **Phase 2 (UPDATE):** Zone scope changes (deferred, status=To Do)
- **Phase N (X):** Other phases (discovered via parent story status)

Dispatches agents only for active phase tasks unless `--all-phases` flag used.

## Limitations & Future Work

**Current (Phase 1):**
- ✅ Discovers and executes Phase 1 tasks only
- ✅ Handles partial PRs with gap completion
- ✅ Runs tests locally with Docker
- ✅ Dispatches parallel subagents

**Future:**
- [ ] Windows CI integration for ddi.msad.agent (currently CI-only)
- [ ] Cross-repo dependency ordering (proto → middleware → collector)
- [ ] Automatic PR merge when all gates pass (currently human gate only)
- [ ] Integration with JIRA transitions (mark task "In Progress" / "Done")
- [ ] Slack notifications per agent completion

## Review Comment Handling (NEW)

The skill discovers and prioritizes existing PR review comments:

- **Blocking comments** (e.g., "Coverage must be ≥92%") → Must address
- **Non-blocking comments** (e.g., "Consider refactoring X") → Should address
- **Informational comments** → Acknowledge in PR body

Agents receive comment context and address feedback systematically. Final PR body documents which comments were resolved.

**Learn more:** See [REVIEW-COMMENT-HANDLING.md](REVIEW-COMMENT-HANDLING.md) and [COMMENT-INTEGRATION-GUIDE.md](COMMENT-INTEGRATION-GUIDE.md)

---

## Related Skills

- **`/msad-dev-planning`** — generates plan from epic (still used for detailed analysis)
- **`/msad-dev-execution`** — dispatches agents (called internally by this skill, also standalone)
- **`/msad-backend-dev`** — implements a single task (dispatched as subagent by this skill)
- **`/msad-code-review`** — reviews a PR (can be invoked manually for detailed review)
