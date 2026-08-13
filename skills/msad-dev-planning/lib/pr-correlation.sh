#!/bin/bash
# pr-correlation.sh
#
# Improvement 3: Correlate Task ↔ PR Status
#
# For each Jira task in an epic, search GitHub for related PRs and determine:
#   - PR exists in DRAFT → Task is "complete, ready for review"
#   - PR exists in OPEN → Task is "in review"
#   - PR exists in CLOSED/MERGED → Task is "done"
#   - No PR found → Task is "not started"
#
# Input: List of Jira task IDs (one per line or as arguments)
# Output: CSV/table correlating task_id → pr_number → status
#
# Usage:
#   ./pr-correlation.sh DDIDNS-10519 DDIDNS-10542 DDIDNS-10521
#   OR
#   cat tasks.txt | ./pr-correlation.sh

set -e

# Core repos in MSAD ecosystem
REPOS=(
    "Infoblox-CTO/ddi.dns.config"
    "Infoblox-CTO/ddi.cloud.proxy.middleware"
    "Infoblox-CTO/ddi.msad.collector"
    "Infoblox-CTO/ddi.msadconnect.proxy"
    "Infoblox-CTO/ddi.msad.agent"
)

# Read tasks from arguments or stdin
declare -a TASKS
if [[ $# -gt 0 ]]; then
    TASKS=("$@")
else
    while IFS= read -r task; do
        [[ -n "$task" ]] && TASKS+=("$task")
    done
fi

echo "=== PR Correlation Matrix ==="
echo ""
echo "| Task | Repo | PR | Status | Date |"
echo "|---|---|---|---|---|"

# For each task, search all repos for related PRs
for task in "${TASKS[@]}"; do
    pr_found=0

    for repo in "${REPOS[@]}"; do
        # Search for PR mentioning this task
        pr_info=$(gh pr list --repo "$repo" --search "$task" --state all --limit 1 --json number,title,state,createdAt 2>/dev/null || echo "")

        if [[ -n "$pr_info" ]] && echo "$pr_info" | grep -q "number"; then
            pr_found=1

            # Extract fields from JSON
            pr_num=$(echo "$pr_info" | grep -o '"number":[0-9]*' | grep -o '[0-9]*')
            pr_state=$(echo "$pr_info" | grep -o '"state":"[A-Z]*"' | cut -d'"' -f4)
            pr_date=$(echo "$pr_info" | grep -o '"createdAt":"[^"]*"' | cut -d'"' -f4 | cut -d'T' -f1)

            # Map Jira state to status label
            case "$pr_state" in
                "DRAFT") status="✅ DRAFT (ready)" ;;
                "OPEN") status="🔄 OPEN (in review)" ;;
                "CLOSED"|"MERGED") status="✅ MERGED" ;;
                *) status="? $pr_state" ;;
            esac

            echo "| $task | $repo | $pr_num | $status | $pr_date |"
            break  # Found PR, stop searching other repos
        fi
    done

    if [[ $pr_found -eq 0 ]]; then
        echo "| $task | — | — | ⏳ NOT STARTED | — |"
    fi
done

echo ""
echo "Legend:"
echo "  ✅ DRAFT (ready) — PR in draft state, ready for review"
echo "  🔄 OPEN (in review) — PR open, may have review feedback"
echo "  ✅ MERGED — PR merged, work complete"
echo "  ⏳ NOT STARTED — No PR found, task not started"
