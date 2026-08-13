# /msad-dev-epic Skill Implementation

**Status:** Ready to implement as a Skill (detailed design below)

**Language:** Bash/Python orchestrator + Anthropic Claude for subagent dispatch

**Key Pattern:** Epic → Discovery → Parallel Agent Dispatch → Result Aggregation → Report

---

## Orchestration Flow

The skill acts as an orchestrator:

```
1. User invokes: /msad-dev-epic DDIDNS-7732
                  ↓
2. Intake phase (validate epic)
                  ↓
3. Discovery phase (fetch tasks, PRs, classify status)
                  ↓
4. Agent dispatch phase (create Agent() calls for each work item)
                  ↓
5. Collection phase (await all agents, collect results)
                  ↓
6. Report phase (consolidate + present findings)
```

---

## Core Functions

### Function 1: `intake_and_validate_epic(epic_id)`

**Input:** Epic ID (e.g., `DDIDNS-7732`)

**Output:** Epic object with summary, status, description

**Errors:** If not an epic, error out

**Implementation:**
```bash
#!/bin/bash
# Validate epic exists and is correct type

epic_id=$1
cloudId="f198b87e-3ffc-4b59-a101-99d0be5ee37f"  # infoblox Atlassian instance

# Use Anthropic Claude's Atlassian MCP to fetch the issue
mcp_call getJiraIssue \
  --cloudId "$cloudId" \
  --issueIdOrKey "$epic_id" \
  --fields "summary,description,status,issuetype"

# Check if issuetype is Epic
if ! jq -e '.fields.issuetype.name == "Epic"' /dev/stdin; then
  echo "Error: $epic_id is not an epic"
  exit 1
fi

echo "✅ Epic validated: $epic_id"
```

### Function 2: `discover_linked_issues(epic_id)`

**Input:** Epic ID

**Output:** List of linked tasks/stories with metadata

**Errors:** If none found, warn but continue (epic may be empty)

**Implementation:**
```bash
#!/bin/bash

epic_id=$1
cloudId="f198b87e-3ffc-4b59-a101-99d0be5ee37f"

# Search for all issues where parent = epic_id
jql="parent = $epic_id"

mcp_call searchJiraIssuesUsingJql \
  --cloudId "$cloudId" \
  --jql "$jql" \
  --maxResults 100 \
  --fields "summary,status,issuetype,assignee,created"

# Parse and classify by type
jq '.issues.nodes | group_by(.fields.issuetype.name) | 
  map({type: .[0].fields.issuetype.name, count: length, issues: map(.key)})' 
```

### Function 3: `discover_existing_prs(epic_id, repos)`

**Input:** Epic ID, list of repos (auto-detected from tasks or provided)

**Output:** List of PRs with metadata (PR number, branch, status, gap assessment)

**Errors:** If gh not authenticated, error out

**Implementation:**
```bash
#!/bin/bash

epic_id=$1
shift
repos=("$@")  # List of repos

for repo in "${repos[@]}"; do
  echo "Searching $repo for PRs mentioning $epic_id..."
  
  gh pr list \
    --repo "Infoblox-CTO/$repo" \
    --search "$epic_id" \
    --limit 15 \
    --json number,title,headRefName,state,body
done | jq -s 'group_by(.repo) | map({repo: .[0].repo, prs: .})'
```

### Function 4: `classify_pr_status(prs, tasks)`

**Input:** List of discovered PRs, list of tasks

**Output:** Classified status: partial, complete, not-started

**Logic:**
- If PR found + DRAFT + gap in description → PARTIAL
- If PR found + DRAFT + no gap → COMPLETE
- If no PR found → NOT_STARTED

**Implementation:**
```bash
#!/bin/bash
# Classify PRs

pr_list=$1
task_list=$2

echo "Classifying PR status..."

# For each task, find corresponding PR
jq -c '.[] | 
  . as $task |
  if ($pr_list | map(select(.title | contains($task.key))) | length > 0) then
    if ($pr_list | map(select(.state == "DRAFT")) | length > 0) then
      if ($pr_list[0].body | contains("Gap:")) then
        {task: $task.key, status: "partial", pr: $pr_list[0]}
      else
        {task: $task.key, status: "complete", pr: $pr_list[0]}
      end
    else
      {task: $task.key, status: "merged", pr: $pr_list[0]}
    end
  else
    {task: $task.key, status: "not-started"}
  end' <<< "$task_list"
```

### Function 5: `dispatch_agents(work_items)`

**Input:** List of work items (PRs/tasks) classified by type

**Output:** Agent IDs for tracking

**Logic:**
- Create Agent() call per item with appropriate prompt
- For independent items: dispatch in parallel (single Agent call block)
- For dependent items: dispatch sequentially
- Track agent IDs for result collection

**Implementation:**
```python
#!/usr/bin/env python3

import json
import sys
from anthropic import Anthropic

def dispatch_agents(work_items):
    """Dispatch subagents for each work item"""
    
    client = Anthropic()
    agent_ids = []
    
    # Group by dependency
    independent = [w for w in work_items if not w.get('depends_on')]
    dependent = [w for w in work_items if w.get('depends_on')]
    
    # Dispatch independent items in parallel
    for item in independent:
        agent_id = dispatch_agent(client, item)
        agent_ids.append(agent_id)
    
    # Dispatch dependent items sequentially (wait for each to complete)
    for item in dependent:
        deps = item.get('depends_on', [])
        # Wait for dependencies to complete
        while not all_completed(agent_ids, deps):
            time.sleep(5)
        
        agent_id = dispatch_agent(client, item)
        agent_ids.append(agent_id)
    
    return agent_ids

def dispatch_agent(client, item):
    """Create and dispatch a single agent"""
    
    prompt = generate_prompt(item)
    
    # Use Anthropic API to dispatch agent
    response = client.messages.create(
        model="claude-opus-5",
        max_tokens=8000,
        messages=[{"role": "user", "content": prompt}]
    )
    
    # Extract agent ID from response
    return response.id
```

### Function 6: `collect_results(agent_ids)`

**Input:** List of agent IDs

**Output:** Aggregated results (tests, coverage, status per PR/task)

**Errors:** If agent times out, mark as timeout; continue with others

**Implementation:**
```bash
#!/bin/bash

# Wait for all agents to complete and collect results

declare -A results

for agent_id in "$@"; do
  echo "Waiting for agent $agent_id..."
  
  # Poll agent status (or use webhook if available)
  while true; do
    status=$(gh api -X GET "/agents/$agent_id/status" --jq '.status')
    
    if [[ "$status" == "completed" ]]; then
      output=$(gh api -X GET "/agents/$agent_id/output" --jq '.')
      results[$agent_id]="$output"
      break
    elif [[ "$status" == "failed" ]]; then
      results[$agent_id]="FAILED"
      break
    else
      sleep 5
    fi
  done
done

# Output aggregated results
echo "${results[@]}" | jq -s '.'
```

### Function 7: `consolidate_and_report(results)`

**Input:** Aggregated results from all agents

**Output:** Consolidated report for user

**Sections:**
1. Epic summary (name, status, tasks count)
2. Per-PR status (PR number, test results, coverage, ready status)
3. Per-task status (task ID, implementation status, PR link)
4. Metrics (total PRs, tests passing, coverage distribution)
5. Next steps (human review → approval → merge)

**Implementation:**
```bash
#!/bin/bash

results=$1

echo "📊 EXECUTION SUMMARY — DDIDNS-7732"
echo "=================================="
echo ""

# Extract and format results
jq -r '.[] | 
  "PR \(.pr_number) (\(.task_id)): \(.status) — Coverage: \(.coverage)%"' \
  <<< "$results"

echo ""
echo "✅ READY FOR HUMAN REVIEW"
```

---

## Agent Prompt Templates

### Template A: Gap Completion (Partial PR)

```markdown
## Task: Complete PR {pr_number} Gap

**Context:**
- Jira: {task_id}
- Repo: {repo}
- Branch: {branch}
- Status: {current_status}% complete
- Gap: {gap_description}

**Your Workflow:**
1. Clone & checkout: {repo} branch {branch}
2. Analyze existing patterns in {test_file}
3. Generate test code for {gap}
4. Add tests following existing patterns
5. Run: make test (docker-compose)
6. Verify coverage ≥92%
7. Commit & push

**Report:**
- Tests added (what, how many)
- Test results (PASS/FAIL)
- Coverage % (before/after)
- Ready-for-review status
```

### Template B: Complete PR Review

```markdown
## Task: Review PR {pr_number}

**Context:**
- Jira: {task_id}
- Repo: {repo}
- Branch: {branch}
- Status: Complete, no gaps

**Your Workflow:**
1. Clone & checkout: {repo} branch {branch}
2. Run: make test (docker-compose)
3. Check coverage: go tool cover -func=coverage.out
4. Report: test status, coverage %, ready status
```

### Template C: Fresh Implementation

```markdown
## Task: Implement {task_id}

**Context:**
- Jira: {task_link}
- Repo: {repo}
- Acceptance criteria: {ac}

**Your Workflow:**
1. Read CLAUDE.md & existing patterns
2. Implement {scope}
3. Write tests (≥80% coverage)
4. Run: make test
5. Commit & push
6. Create draft PR

**Report:**
- What you implemented
- Test results
- Coverage %
- PR link
```

---

## Integration with Existing Skills

### msad-dev-planning

**Current role:** Generate detailed phase-by-phase plan

**Future role in epic execution:**
- Still invoked for **detailed phase analysis** (optional, user can choose)
- /msad-dev-epic skips planning by default (uses discovery instead)
- But user can invoke /msad-dev-planning separately for detailed review

### msad-dev-execution

**Current role:** Execute a pre-created plan

**Future role in epic execution:**
- Refactor to become subagent dispatcher (already designed this way)
- /msad-dev-epic calls msad-dev-execution internally for agent dispatch
- Or /msad-dev-execution becomes generic dispatcher (not epic-specific)

### Relationship

```
/msad-dev-epic (NEW)
  ├─ Calls: Discovery (Atlassian MCP + gh pr list)
  ├─ Calls: Agent dispatch (subagents for each work item)
  └─ Calls: Result consolidation

/msad-dev-planning (EXISTING)
  └─ Optional, for detailed phase analysis (invoked separately)

/msad-dev-execution (EXISTING, REFACTORED)
  └─ Called by /msad-dev-epic for agent dispatch
  └─ Also standalone for plan-based execution
```

---

## Phased Rollout

### Phase 1: Proof of Concept (Now)
- Implement /msad-dev-epic for DDIDNS-7732 specifically
- Hardcode epic ID, discover tasks/PRs, dispatch agents
- Test with 4 existing PRs

### Phase 2: Generalization
- Parameterize for any epic ID
- Support multi-phase epics (Phase 1, Phase 2, etc.)
- Add `--phase` and `--dry-run` flags

### Phase 3: Production Hardening
- Automated JIRA status transitions
- Slack notifications
- Auto-merge option (with guards)
- Windows CI integration for agent PRs

---

## Testing Checklist

- [ ] Epic discovery works for DDIDNS-7732
- [ ] PR discovery finds 4 existing PRs
- [ ] PR classification: 2 partial, 2 complete
- [ ] Task discovery finds 3 not-started
- [ ] Agent dispatch: 7 agents created
- [ ] Result collection: all agents complete
- [ ] Report generation: consolidated summary
- [ ] Links: all PRs navigable

---

## Success Criteria

- ✅ Epic execution time: <30 min (parallel agents)
- ✅ All tests passing
- ✅ All coverage ≥80%
- ✅ All PRs ready for human review
- ✅ Clear next steps for human merge
