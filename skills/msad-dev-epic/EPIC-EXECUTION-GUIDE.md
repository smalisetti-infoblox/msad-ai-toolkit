# MSAD Epic Execution Guide

**Skill Name:** `/msad-dev-epic`

**Purpose:** End-to-end automation for Jira epics — discover tasks, PRs, gaps; dispatch parallel subagents; orchestrate execution; report consolidated results.

**Status:** Ready to implement (design + prompts defined below)

---

## Implementation Workflow

### Step 1: Intake & Validation

```
User invokes: /msad-dev-epic DDIDNS-7732
  ↓
Validate input: is DDIDNS-7732 a valid epic?
  ├─ Fetch via getJiraIssue(issueKey: "DDIDNS-7732")
  ├─ Check issuetype == "Epic"
  └─ If not epic, error: "Must be an epic. DDIDNS-7732 is a [type], not an epic."
  ↓
Output: "Step 1 — Intake. Epic: DDIDNS-7732 (Microsoft DNS zone creation / replication scope)"
```

**Code template (pseudocode):**
```python
def intake_epic(epic_id):
    issue = atlassian_mcp.get_jira_issue(epic_id)
    if issue.type != "Epic":
        raise ValueError(f"{epic_id} is a {issue.type}, not an Epic")
    
    return {
        "epic_id": epic_id,
        "epic_summary": issue.summary,
        "epic_status": issue.status,
        "epic_description": issue.description,
    }
```

---

### Step 2: Discovery

#### 2a. Fetch Linked Tasks/Stories

```
List all issues where parent = DDIDNS-7732
  ↓
JQL: parent = DDIDNS-7732
  ↓
Classify by type:
  ├─ Stories: [DDIDNS-10562, ...]
  ├─ Tasks: [DDIDNS-10519, DDIDNS-10542, ...]
  └─ QA: [DDIDNS-10510, ...]
  ↓
Output: "27 linked issues (12 stories, 10 tasks, 5 QA)"
```

**Code template:**
```python
def discover_linked_issues(epic_id):
    jql = f"parent = {epic_id}"
    issues = atlassian_mcp.search_jira_issues(jql)
    
    return {
        "total": len(issues),
        "stories": [i for i in issues if i.type == "Story"],
        "tasks": [i for i in issues if i.type == "Task"],
        "qa": [i for i in issues if "QA" in i.labels],
    }
```

#### 2b. Discover Existing PRs

```
For each repo involved (ddi.dns.config, ddi.cloud.proxy.middleware, ...):
  ├─ Run: gh pr list --repo Infoblox-CTO/<repo> --search "<epic-id>"
  ├─ Parse PR numbers, branches, status (DRAFT/OPEN/MERGED)
  └─ Link PR to task (by PR title/description)
  ↓
Output:
  PR 507 (DDIDNS-10519, ddi.cloud.proxy.middleware, DRAFT)
  PR 508 (DDIDNS-10542, ddi.cloud.proxy.middleware, DRAFT)
  PR 241 (DDIDNS-10543, ddi.msad.collector, DRAFT)
  PR 6300 (DDIDNS-10546, ddi.dns.config, DRAFT)
```

**Code template:**
```python
def discover_existing_prs(epic_id, repos):
    prs = {}
    for repo in repos:
        result = subprocess.run(
            ["gh", "pr", "list", "--repo", f"Infoblox-CTO/{repo}", 
             "--search", epic_id, "--limit", "15"],
            capture_output=True, text=True
        )
        prs[repo] = parse_pr_list(result.stdout)
    
    return prs
```

#### 2c. Classify PR Status

```
For each PR:
  ├─ If DRAFT + gap identified in PR description:
  │   └─ Status: PARTIAL (needs gap completion)
  ├─ If DRAFT + no gap:
  │   └─ Status: COMPLETE (ready for review)
  ├─ If OPEN/MERGED:
  │   └─ Status: DONE
  └─ If no PR found for task:
      └─ Status: NOT_STARTED (needs implementation)
  ↓
Output:
  Partial PRs: [507, 241] (needs gap completion)
  Complete PRs: [508, 6300] (ready for review)
  Not-started: [10521, 10544, 10541] (needs fresh implementation)
```

**Code template:**
```python
def classify_pr_status(prs, tasks):
    partial = []
    complete = []
    not_started = []
    
    for task in tasks:
        pr = find_pr_for_task(task, prs)
        if not pr:
            not_started.append(task)
        elif pr.draft and has_gap(pr.description):
            partial.append((task, pr, extract_gap(pr)))
        elif pr.draft:
            complete.append((task, pr))
    
    return {"partial": partial, "complete": complete, "not_started": not_started}
```

---

### Step 3: Dispatch Subagents (Parallel)

#### 3a. Group Work by Repo & Phase

```
Group PRs/tasks by:
  ├─ Repo (middleware, collector, dns.config, agent)
  ├─ Phase (1=CREATE, 2=UPDATE, etc.)
  └─ Dependency (proto → middleware → collector ordering)
  ↓
For phase=1 (default):
  ├─ Middleware: [PR 507 (partial), PR 508 (complete)]
  ├─ Collector: [PR 241 (partial)]
  ├─ DNS Config: [PR 6300 (complete)]
  └─ Agent: [Task 10521 (not-started)]
```

#### 3b. Dispatch Agents (Parallel or Sequential)

**For independent packages (no dependency):** dispatch in parallel in one Agent call:

```python
Agent(description="PR 507: add middleware handler tests")
Agent(description="PR 508: review middleware idempotency")
Agent(description="PR 241: add collector error code tests")
Agent(description="PR 6300: review dns.config audit logging")
```

**For dependent packages (proto must land first):** dispatch sequentially after proto agent completes.

---

### Step 4: Agent Prompts (Template per PR Type)

#### Template A: Partial PR (Gap Completion)

```
You are completing PR {pr_number} (DDIDNS-{task_id}) in {repo}.

**Current status:** {status}% complete
**Gap:** {gap_description}

**Your workflow:**
1. Clone & checkout: {repo} branch {branch}
2. Analyze existing patterns in {relevant_test_file}
3. Generate {gap_type} code:
   - {gap_detail_1}
   - {gap_detail_2}
4. Add to file: {target_file}
5. Run: make test (with docker-compose)
6. Verify coverage: ≥92% (threshold for gap fix)
7. Commit: "{gap_fix_message}"
8. Push to PR branch

**Report back:**
- What code you added
- Test results (pass/fail)
- Coverage % (before/after)
- Ready-for-review status

**Example:** PR 507
  Repo: ddi.cloud.proxy.middleware
  Gap: Conditional Forwarder handler tests missing
  File: pkg/interceptor_handlers_test.go
  Task: Add 2 handler test functions following Auth Zone pattern
  Coverage: 87% → 92.3%
```

#### Template B: Complete PR (Review)

```
You are reviewing PR {pr_number} (DDIDNS-{task_id}) in {repo}.

**Current status:** complete, ready for review

**Your workflow:**
1. Clone & checkout: {repo} branch {branch}
2. Run tests: make test (with docker-compose)
3. Check coverage: go tool cover -func=coverage.out
4. Verify CI: all GitHub checks passing
5. Report: test results, coverage %, ready-to-merge status

**Example:** PR 508
  Repo: ddi.cloud.proxy.middleware
  Task: Idempotency - prevent orphaned zones
  Status: Complete, all tests passing
```

#### Template C: Not-Started Task (Fresh Implementation)

```
You are implementing task {task_id} ({task_summary}) in {repo}.

**Jira task:** {task_link}
**Parent story:** {story_link}
**Acceptance criteria:** {ac_list}

**Your workflow:**
1. Read CLAUDE.md in {repo} (build, test, coding rules)
2. Read existing code patterns:
   - {pattern_1_file}
   - {pattern_2_file}
3. Implement {scope}:
   - {impl_1}
   - {impl_2}
4. Write tests:
   - Unit tests following {test_pattern}
   - Coverage ≥80%
5. Run: make test (with docker-compose)
6. Commit: "{impl_message}"
7. Push to new branch & draft PR

**Report back:**
- What you implemented
- Test results
- Coverage %
- PR created (link)
```

---

### Step 5: Collect Results

```
Await all subagents (up to 20 min)
  ↓
For each agent result:
  ├─ Extract: PR number, test status, coverage %, ready status
  ├─ Aggregate: partial_fixed, complete_verified, new_prs_created
  └─ Flag any failures
  ↓
Output: "4/4 agents completed. Results: ..."
```

**Code template:**
```python
def collect_results(agents):
    results = {
        "partial_fixed": [],
        "complete_verified": [],
        "new_prs": [],
        "failures": [],
    }
    
    for agent in agents:
        if agent.status == "completed":
            if agent.type == "partial_fix":
                results["partial_fixed"].append(agent.result)
            elif agent.type == "complete_review":
                results["complete_verified"].append(agent.result)
            elif agent.type == "fresh_impl":
                results["new_prs"].append(agent.result)
        else:
            results["failures"].append(agent.error)
    
    return results
```

---

### Step 6: Consolidate & Report

```
Generate final report:

📊 EXECUTION SUMMARY — DDIDNS-7732
  ├─ Epic: Microsoft DNS zone creation / replication scope
  ├─ Status: Implementing
  │
  ├─ PRs COMPLETED (Partial Gaps Fixed)
  │  ├─ PR 507 (DDIDNS-10519, middleware): handler tests added, coverage 92.3% ✅
  │  └─ PR 241 (DDIDNS-10543, collector): error code tests added, coverage 92.1% ✅
  │
  ├─ PRs READY (Complete, No Gaps)
  │  ├─ PR 508 (DDIDNS-10542, middleware): idempotency implemented, tests pass ✅
  │  └─ PR 6300 (DDIDNS-10546, dns.config): audit logging implemented, tests pass ✅
  │
  ├─ TASKS IMPLEMENTED (Fresh)
  │  ├─ DDIDNS-10521 (agent validation): PR 999 created, tests pass ✅
  │  ├─ DDIDNS-10544 (portal UI): PR 1000 created, tests pass ✅
  │  └─ DDIDNS-10541 (E2E tests): PR 1001 created, tests pass ✅
  │
  └─ FINAL METRICS
     ├─ All tests: PASSING ✅
     ├─ All coverage: ≥80% ✅
     ├─ All PRs: ready for human review ✅
     ├─ Total PRs: 7 (4 existing + 3 new)
     └─ Next: Human review → approval → merge

**Status:** READY FOR HUMAN REVIEW

**PRs pending human approval:**
  - PR 507: https://github.com/Infoblox-CTO/ddi.cloud.proxy.middleware/pull/507
  - PR 508: https://github.com/Infoblox-CTO/ddi.cloud.proxy.middleware/pull/508
  - PR 241: https://github.com/Infoblox-CTO/ddi.msad.collector/pull/241
  - PR 6300: https://github.com/Infoblox-CTO/ddi.dns.config/pull/6300
  - PR 999: https://github.com/Infoblox-CTO/ddi.msad.agent/pull/999
  - PR 1000: https://github.com/Infoblox-CTO/ddi-portal/pull/1000
  - PR 1001: https://github.com/Infoblox-CTO/ddi.msad.collector/pull/1001

**Execution time:** ~18 minutes (parallel agents)
```

---

## Implementation Checklist

- [ ] **Discovery phase:**
  - [ ] Fetch epic via Atlassian MCP
  - [ ] List linked tasks/stories via JQL
  - [ ] Discover existing PRs via gh pr list
  - [ ] Classify PR status (partial / complete / not-started)

- [ ] **Agent dispatch:**
  - [ ] Group work by repo + phase
  - [ ] Create agent prompts (Template A/B/C)
  - [ ] Dispatch agents in parallel (non-dependent) or sequential (dependent)
  - [ ] Track agent IDs for result collection

- [ ] **Result consolidation:**
  - [ ] Await all agents
  - [ ] Extract metrics per agent (test status, coverage, ready status)
  - [ ] Aggregate results
  - [ ] Flag any failures/issues

- [ ] **Reporting:**
  - [ ] Generate consolidated report
  - [ ] List all PRs (existing + new)
  - [ ] Provide human-actionable summary
  - [ ] Link to each PR for review

---

## Error Handling

| Error | Cause | Recovery |
|---|---|---|
| "Not an epic" | Input is task/story, not epic | Ask for epic ID |
| "No linked issues" | Epic exists but has no tasks | Ask if epic scope is correct |
| "PR not found" | Task has no PR, but expected one | Dispatch fresh implementation agent |
| "Agent timeout" | Subagent stuck/slow | After 20 min, report as incomplete; ask user to retry |
| "Test failure" | Tests fail in agent | Report failure details; ask user to review PR and fix manually |
| "Coverage below threshold" | Gap completion didn't reach ≥92% | Report coverage %; ask user to add more tests |

---

## Future Enhancements

1. **Auto-merge when gates pass** — merge PRs automatically after all checks pass (currently human gate only)
2. **JIRA status transitions** — mark tasks "In Progress" / "Done" in JIRA as they complete
3. **Windows CI integration** — await Windows CI for ddi.msad.agent PRs (currently displayed as CI-only)
4. **Slack notifications** — post progress updates to #msad-dev channel
5. **Cross-repo dependency ordering** — automatically sequence proto → middleware → collector PRs
6. **Plan generation** — skip manual plan creation, generate on-the-fly from epic
7. **Dry-run mode** — show what would happen without making changes (useful for validation)

---

## Related Skills / Integration Points

- **`/msad-dev-planning`** — still useful for detailed phase-by-phase planning (can be invoked within epic execution for phases beyond Phase 1)
- **`/msad-dev-execution`** — dispatches agents for a single plan (called internally by this skill, also standalone)
- **`/msad-backend-dev`** — implements a single task (dispatched as subagent)
- **`/msad-code-review`** — deep review of a PR (can be invoked manually for detailed feedback)

---

## Example Invocations

### Phase 1 Only (Default)
```
/msad-dev-epic DDIDNS-7732
```
Executes Phase 1 (zone creation). Skips Phase 2 (zone updates).

### All Phases
```
/msad-dev-epic DDIDNS-7732 --all-phases
```
Executes all phases (Phase 1 + Phase 2 + any others).

### Dry-Run Mode
```
/msad-dev-epic DDIDNS-7732 --dry-run
```
Shows what would happen without making changes.

### Specific Phase
```
/msad-dev-epic DDIDNS-7732 --phase 2
```
Executes only Phase 2 (zone updates).
