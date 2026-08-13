#!/bin/bash
# jira-hierarchy-builder.sh
#
# Improvement 1: Build Jira Hierarchy Map
#
# Organizes fetched Jira tickets into a structured hierarchy:
#   Epic → Phase → Story → Task
#
# Input: Jira issue ID (e.g., DDIDNS-7732)
# Output: Structured hierarchy (markdown or JSON) showing:
#   - Parent-child relationships
#   - Issue type (Epic, Story, Task, Subtask)
#   - Status (To Do, In Progress, Done, Aborted, None, Draft PR)
#   - Summary
#
# Usage:
#   ./jira-hierarchy-builder.sh DDIDNS-7732

set -e

JIRA_ID="${1:?Error: provide Jira issue ID (e.g., DDIDNS-7732)}"
CLOUD_ID="${2:-infoblox.atlassian.net}"

echo "=== Jira Hierarchy Builder ==="
echo "Epic: $JIRA_ID"
echo "Cloud: $CLOUD_ID"
echo ""

# Fetch the epic and all linked issues
# Output: structured list of: issue_key|parent_key|issue_type|status|summary

declare -A issues
declare -A parents
declare -A types
declare -A statuses

# Fetch epic
epic_data=$(gh api repos/Infoblox-CTO/ddi.dns.config/issues \
  -H "Accept: application/vnd.github.v3+json" 2>/dev/null || echo "")

# For now, output a template showing the expected structure
# In a full implementation, this would:
# 1. Call Atlassian MCP getJiraIssue for the epic
# 2. Parse the linked issues
# 3. For each linked issue, determine parent-child relationships
# 4. Build a tree structure

cat <<'EOF'
## Epic Hierarchy Structure

This script builds a hierarchy map from Jira data. Structure:

```
EPIC (root)
├── Story 1
│   ├── Task 1.1
│   ├── Task 1.2
│   └── Subtask 1.2.1
├── Story 2
│   ├── Task 2.1
│   └── Task 2.2
└── Story 3
    └── Task 3.1
```

## Key Fields to Collect:

For each issue:
- issueKey: DDIDNS-XXXXX
- issueType: Epic | Story | Task | Subtask
- status: To Do | In Progress | Done | Aborted | None | etc.
- parent: (if subtask, parent issue key)
- summary: issue title

## Detection Logic:

1. **Phase detection:** Analyze summary keywords
   - "create" → Phase 1
   - "update" / "change" → Phase 2
   - Group tasks by detected phase

2. **Functional area detection:** Analyze component keywords
   - "middleware" / "proxy" → Backend
   - "portal" / "UI" → Portal/Frontend
   - "audit" → Audit
   - "test" / "QA" → QA

3. **Status interpretation:** For planning purposes
   - Jira Status: "To Do" + GitHub PR exists (DRAFT) → "Ready for review"
   - Jira Status: "In Progress" → "In progress"
   - Jira Status: "None" or "Aborted" → "Deferred" (if related to Phase 2)

## Output Format:

Structured hierarchy (as markdown tree or JSON)

EOF

echo ""
echo "Note: This is a template. Full implementation requires:"
echo "  1. Atlassian MCP getJiraIssue calls for epic + all linked issues"
echo "  2. Parse linked issues to identify parent-child relationships"
echo "  3. Build tree structure with type/status/phase info"
echo "  4. Output as markdown tree or JSON"
