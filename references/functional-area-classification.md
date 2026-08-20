# Functional-Area Classification — Backend vs. Frontend/UI

Single source of truth for classifying Jira tasks/stories as Backend (toolkit-managed) or Frontend/UI (excluded from toolkit dispatch). Cited by `msad-dev-planning` and `msad-dev-epic` instead of copy-pasting the keyword lists.

## Classification Rule

For each Jira task/story, examine the **summary/title** for signal keywords. Classify as one of:
- **Backend** — toolkit will dispatch `msad-backend-dev` for this task
- **Frontend/UI** — toolkit excludes this; managed by a separate team
- **QA/Testing** — toolkit may dispatch `msad-e2e-verify`, else exclude

## Signal Keywords

### Backend Signals
Any of these in the task summary → classify as **Backend** (will be dispatched):
- Repo names: `middleware`, `collector`, `agent`, `dns.config`, `dns.data`, `proxy`
- Layer names: `backend`, `API`, `gRPC`, `validation`, `handler`, `interceptor`, `service`, `controller`, `service-layer`
- Concerns: `replication-scope`, `error-code`, `idempotency`, `proto`, `contract`, `validator`

**Examples:**
- `"middleware: transform & validate replication scope"`
- `"collector: add error-code mapping for ZONE-005"`
- `"dns.config: validate replication scope on zone creation"`

### Frontend/UI Signals
Any of these in the task summary → classify as **Frontend/UI** (will be excluded, not dispatched):
- UI keywords: `portal`, `UI`, `frontend`, `form`, `selector`, `editor`, `component`, `view`, `page`, `dashboard`, `UX`
- Example repos: `portal`, `ddi-portal` (if mentioned)
- Concerns: `design`, `wireframe`, `mockup`, `layout`, `theme`

**Examples:**
- `"Portal: add selector component for replication scope"`
- `"Frontend: form validation for scope changes"`
- `"UI: update dashboard for zone replication"`

### QA/Testing Signals
Any of these → classify as **QA/Testing** (handled separately, not core implementation):
- Keywords: `test`, `automation`, `E2E`, `e2e`, `testing`, `CI/CD`, `verification`, `validate`, `stage testing`
- Concerns: `test plan`, `test suite`, `integration`, `coverage`, `automation`

**Examples:**
- `"QA: E2E testing for zone replication scope"`
- `"test automation: add CI checks for idempotency"`

## Default and Conflict Resolution

- **No signals matching any of the above** → default to **Backend** (toolkit will dispatch)
- **Both Backend and Frontend signals present** (rare) → classify as **Frontend/UI** (conservative; don't dispatch mixed concerns)
- **Multiple Frontend/UI signals** → still classifies as Frontend/UI (no sub-categorization)

## Usage in Skills

### msad-dev-planning (Step 2b)

```python
# Fetch all linked issues (tasks) for the story
tasks = jira.search(f"parent = {story_id}")

for task in tasks:
    classification = classify_functional_area(task.summary)
    if classification == "Backend":
        backend_tasks.append(task)
    elif classification == "Frontend/UI":
        frontend_tasks.append(task)
    elif classification == "QA/Testing":
        qa_tasks.append(task)
```

Output a **Scope Boundaries** table in the plan:

| Task | Classification | Summary | Notes |
|---|---|---|---|
| DDIDNS-10519 | ✅ Backend | Middleware: Domain/Forest scope | Will be dispatched to msad-backend-dev |
| DDIDNS-10544 | 🚫 Frontend/UI | Portal selector for replication scope | Managed by separate team, excluded |
| DDIDNS-10546 | ✅ Backend | DNS Config: audit logging | Will be dispatched to msad-backend-dev |

### msad-dev-epic (Step 1: Discovery + Classification)

Same pattern: list all linked tasks/stories for the epic, classify each, report Backend vs. Frontend/UI split in the final report:

```
✅ Backend PRs ready for review: 7/7
  - PR 507 (middleware, gap closed, 92.3% coverage)
  - PR 508 (collector, tests pass)
  - ... (5 more)

🚫 Frontend/UI tasks excluded (managed by separate team): 3 tasks
  - DDIDNS-10544: Portal selector component
  - DDIDNS-10548: Portal form validation
  - DDIDNS-10563: Portal UI design
```

## Notes

- **Keyword matching is the only gate** — no Jira custom-field or component lookup. This keeps the classification fast and independent of Jira configuration.
- **Keyword signals are case-insensitive** — match "Portal", "portal", "PORTAL" all the same.
- **Repo names in the summary are preferred signals** — if a task says "middleware: ...", it's unambiguously Backend.
- **Update this document if new signal keywords emerge** — if the team identifies a new Frontend keyword (e.g., a new Portal sub-repo name), add it here once and update all callers in one place (here), rather than separately in each skill.

## Testing / Verification

After implementation, verify:
- `msad-dev-planning` Step 2b cites this doc (no inlined keyword list).
- `msad-dev-epic` Step 1 cites this doc (no inlined keyword list).
- Grep the repo for the old triplicated keyword lists and confirm they're removed / replaced with citations.
