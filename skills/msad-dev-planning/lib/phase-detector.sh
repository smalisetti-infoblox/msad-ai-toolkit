#!/bin/bash
# phase-detector.sh
#
# Improvement 2: Detect Phases & Functional Areas
#
# Analyzes Jira task summaries and status to detect:
#   1. Phases (e.g., Phase 1: CREATE, Phase 2: UPDATE)
#   2. Functional areas (Backend, Portal UI, QA, Audit, Error Handling)
#
# Detection logic:
#   - Keywords in summary: "create" → Phase 1, "update"/"change" → Phase 2
#   - Keywords: "portal"/"UI" → Portal, "audit"/"log" → Audit, "test"/"QA" → QA
#   - Status clustering: if all Phase 1 tasks in DRAFT PR, Phase 2 tasks in "None" → deferred
#
# Input: CSV with columns: task_id,summary,status
# Output: Grouped by phase/area with detection rationale
#
# Usage:
#   cat tasks.csv | ./phase-detector.sh

set -e

echo "=== Phase & Functional Area Detector ==="
echo ""

# Phase keywords
declare -a PHASE1_KEYWORDS=("create" "creation" "new")
declare -a PHASE2_KEYWORDS=("update" "change" "modify" "delete" "remove")

# Functional area keywords
declare -A AREA_KEYWORDS=(
    ["Backend"]="backend|middleware|collector|agent|dns.config|proxy"
    ["Portal UI"]="portal|UI|frontend|form|selector|editor"
    ["Audit"]="audit|log|logging|capture"
    ["Error Handling"]="error|handle|code|status|mapping"
    ["QA"]="QA|test|automation|stage|integration"
)

# Example detection
cat <<'EOF'
## Phase Detection Rules

### Rule 1: Keyword Matching
- Summary contains ("create", "creation", "new") → Phase 1 (Zone Creation)
- Summary contains ("update", "change", "modify") → Phase 2 (Zone Update)

### Rule 2: Status Clustering
- If Phase 1 tasks: status = [To Do, Draft PR, In Progress]
- If Phase 2 tasks: status = [None, Aborted]
- → Phase 2 is deferred (later initiative)

### Rule 3: Functional Area Detection
- ("middleware", "proxy", "agent", "collector") → Backend
- ("portal", "UI", "frontend", "form", "selector") → Portal UI
- ("audit", "log", "logging", "capture") → Audit
- ("error", "handle", "status", "mapping") → Error Handling
- ("QA", "test", "automation", "stage") → QA

## Example Output

### Phase 1: Zone Creation ✅ (Complete in Draft PRs)

#### Backend Track
- DDIDNS-10519 (PR 507 DRAFT): Middleware — Domain/Forest scope for Auth/Forward
- DDIDNS-10542 (PR 508 DRAFT): Middleware — idempotency (duplicate check + rollback)
- DDIDNS-10543 (PR 241 DRAFT): Collector — error-code mapping

#### Audit Track
- DDIDNS-10546 (PR 6300 DRAFT): DNS Config — audit logging for creation

#### Portal UI Track
- DDIDNS-10563 (To Do): Portal design
- DDIDNS-10544 (To Do): Portal selector

#### QA Track
- DDIDNS-10510–10513 (To Do): Test planning, automation, stage testing

### Phase 2: Zone Update (Deferred)

Rationale: UPDATE tasks all in "None" or "Aborted" status, no active work.
Phase 2 is deferred to a separate initiative after Phase 1 ships.

#### Backend Track
- DDIDNS-10547 (None): Backend — allow scope changes on zone UPDATE
- DDIDNS-10548 (None): Portal UI — allow editing scope on existing zones

EOF

echo ""
echo "To implement detection:"
echo "  1. Read input CSV (task_id, summary, status)"
echo "  2. For each task, match summary against phase/area keyword lists"
echo "  3. Group by detected phase and area"
echo "  4. Analyze status clustering to identify deferred phases"
echo "  5. Output grouped structure"
