---
jira: DDIDNS-7732
repos: [ddi.dns.config, ddi.cloud.proxy.middleware, ddi.msad.collector, ddi.msadconnect.proxy, ddi.msad.agent]
status: approved
created: 2026-08-20
---

# Structure Plan: DDIDNS-7732 — Microsoft DNS Zone Creation with Replication Scope

## Epic Summary

**DDIDNS-7732** ("[FS]: Microsoft DNS zone creation\replication scope", parent initiative DDIDNS-9464 "Microsoft | DNS Zone Replication", status: Implementing) enables the Infoblox Cloud Portal to create Microsoft DNS zones with Active Directory–integrated replication scopes (Domain, Forest), in addition to the existing Local (file-based) zones. Scoped to **zone creation only** — broader lifecycle (transfers, SOA, DNSSEC) is explicitly out of scope; stub zones are out of scope; replication-scope *update* on existing zones is a DDIDNS-9464-approved exception tracked separately (DDIDNS-10566).

## Deduplication Finding (Step 1)

This epic is **not greenfield** — it already has 9 Stories and 9 active Tasks (plus 9 Aborted duplicate tasks that a prior process already caught and killed). Per the toolkit's deduplication policy, **no new stories or tasks were created**. Instead:

1. Existing structure was inventoried in full (27 total linked issues; see below).
2. The 9 active tasks were flat children of the epic (not nested under their matching story) due to a Jira project-hierarchy restriction (Task→Story `parent` re-assignment is rejected: *"Given parent work item does not belong to appropriate hierarchy"*).
3. Since re-parenting is blocked at the Jira config level, each task was connected to its matching story via a **"Relates" issue link** instead (9 links created — see mapping below).

## Story → Task Mapping (as-linked)

### STORY DDIDNS-10562 — "Backend: support Domain/Forest replication scope on Microsoft DNS zone creation" (To Do)

**Acceptance Criteria:**
```gherkin
Feature: Domain/Forest replication scope on zone creation

  Scenario: Middleware accepts domain/forest scope
    Given a zone creation request with replication_scope = "domain" or "forest"
    When the middleware processes an Auth, Reverse Auth, or Forward zone create
    Then the request is accepted and forwarded to the MSAD collector

  Scenario: Agent validates and applies scope
    Given a Domain or Forest replication scope on Primary or Forward zone creation
    When ddi.msad.agent receives the create request
    Then it validates the scope against the allow-list and applies it via PowerShell

  Scenario: Invalid scope is rejected
    Given a zone creation request with an unsupported replication_scope value
    When the middleware or agent validates the request
    Then it is rejected with a clear InvalidArgument error
```

**Linked Tasks:**
- **DDIDNS-10519** — `ddi.cloud.proxy.middleware: support Domain/Forest replication scope for Auth, Reverse Auth, and Forward zone creation` (assignee: smalisetti, status: To Do)
- **DDIDNS-10521** — `ddi.msad.agent: validate Domain/Forest replication scope on Primary and Forward zone creation` (assignee: smalisetti, status: To Do)

**Repos:** ddi.cloud.proxy.middleware, ddi.msad.agent

---

### STORY DDIDNS-10563 — "Portal UI: replication scope selector on Microsoft DNS zone creation form" (To Do)

**Acceptance Criteria:** Zone creation form displays Local/Domain/Forest selector (Primary/AD-integrated zones only); default Local; submits `external_providers_metadata.msad_config.replication_scope`; surfaces backend validation errors clearly.

**Linked Tasks:**
- **DDIDNS-10544** — `Portal UI: add replication scope selector (Local, Domain, Forest) to Microsoft DNS zone creation form` (unassigned, status: To Do)

**Repos:** Portal/UI repo (not toolkit-managed — needs a UI repo owner)

**Classification:** 🚫 Frontend/UI — excluded from `/msad-dev-epic` dispatch, tracked separately.

---

### STORY DDIDNS-10564 — "Zone-creation error handling, duplicate prevention & idempotency for AD-integrated zones" (To Do)

**Acceptance Criteria:**
```gherkin
Feature: Error handling and idempotency for AD-integrated zone creation

  Scenario: Insufficient AD permissions surfaced clearly
    Given a zone creation attempt lacking AD permissions on the target domain/forest partition
    When the create request fails
    Then a clear, actionable "insufficient AD permissions" error reaches the caller

  Scenario: Duplicate zone conflict detected
    Given a zone name that already exists as an AD-integrated zone
    When a duplicate creation is attempted
    Then a clear "zone already exists" error is returned and no orphaned AD zone remains

  Scenario: Collector error-code mapping on Update/Delete
    Given a ZONE-00x error from the agent during Update or Delete
    When the collector processes the response
    Then it maps to the correct gRPC status code (not opaque codes.Unknown)
```

**Linked Tasks:**
- **DDIDNS-10541** — `Verify insufficient-AD-permissions and duplicate-zone error surfacing for domain/forest zone creation` (assignee: smalisetti, status: To Do) — QA/verification task, no new code expected
- **DDIDNS-10542** — `Idempotency: prevent orphaned AD zones when DDI zone creation is a duplicate` (assignee: smalisetti, status: To Do) — approach (pre-flight check vs. rollback vs. both) not yet decided; resolve during `/msad-dev-planning`
- **DDIDNS-10543** — `ddi.msad.collector: Update/Delete zone RPCs don't map ZONE-00x agent errors to gRPC status codes` (assignee: smalisetti, status: To Do)

**Repos:** ddi.cloud.proxy.middleware, ddi.msad.collector, ddi.msad.agent (verification only)

---

### STORY DDIDNS-10565 — "Audit: capture replication scope and target server on Microsoft DNS zone creation" (To Do)

**Acceptance Criteria:** Zone-creation audit logs include `replication_scope` and `target_server` (AgentGUID) fields for MSAD zones; no schema/proto change required (existing `EventMetadata` JSONB field).

**Linked Tasks:**
- **DDIDNS-10546** — `Audit: extend zone-create audit log with replication scope and target server for MSAD zones` (unassigned, status: To Do) — has 3 open questions to confirm with ddi.dns.config team before implementation (see task description: target-server format, Update-path scope, Forward-zone parity)

**Repos:** ddi.dns.config

---

### STORY DDIDNS-10566 — "Support changing replication scope on existing AD-integrated Microsoft DNS zones (backend + UI)" (To Do)

**Note:** This is the DDIDNS-9464-approved **exception** to DDIDNS-7732's own "creation only" scope — tracked as its own story specifically because it's an Update capability, not Create.

**Acceptance Criteria:** Backend allows scope change on AD-integrated Forward zones initially (Auth zones remain write-once-blocked pending agent-side work); UI provides edit controls (Forward zones only, initial phase); transitions validated; confirmation dialogs shown; errors surfaced; changes audited.

**Linked Tasks:**
- **DDIDNS-10547** — `Backend: allow changing replication scope on Microsoft DNS zone update` (unassigned, status: To Do) — **has 3 unresolved open questions** (does MSAD actually support in-place scope change vs. migration; which transitions are allowed; partial-failure/rollback behavior) — must be resolved before `/msad-dev-planning` can produce an actionable plan
- **DDIDNS-10548** — `Portal UI: allow editing replication scope on existing Microsoft DNS zones` (unassigned, status: To Do) — explicitly depends on DDIDNS-10547 landing first

**Repos:** ddi.cloud.proxy.middleware, ddi.msad.agent, Portal/UI (10548 only)

**Classification:** Backend task (10547) ✅ toolkit-managed; UI task (10548) 🚫 excluded, and additionally blocked on 10547.

---

### QA Stories (not repo-scoped, tracked but not toolkit-dispatched)

- **DDIDNS-10510** — "QA: TP preparation" (To Do) — test plan covering scope-change impact, new-zone creation (Forest/Domain), Legacy support check, existing Local scope check
- **DDIDNS-10511** — "[QA]Integration test" (To Do) — testing all TP cases on us-dev2 cluster
- **DDIDNS-10512** — "[QA]Stage testing" (To Do) — regression + replication scope changes on us-stg
- **DDIDNS-10513** — "[QA]Automation update" (To Do) — extend existing MSAD automation with replication-scope-edit cases from CSP

**Toolkit coverage:** `/msad-e2e-verify` partially covers integration-test scope (API-level, no Windows agent); stage testing and CSP automation are manual/QA-team tracks.

---

## Full Issue Inventory (27 total)

| Key | Type | Status | Role |
|---|---|---|---|
| DDIDNS-10510 | Story | To Do | QA — TP preparation |
| DDIDNS-10511 | Story | To Do | QA — Integration test |
| DDIDNS-10512 | Story | To Do | QA — Stage testing |
| DDIDNS-10513 | Story | To Do | QA — Automation update |
| DDIDNS-10519 | Task | To Do | Backend (middleware) — linked to 10562 |
| DDIDNS-10521 | Task | To Do | Backend (agent) — linked to 10562 |
| DDIDNS-10541 | Task | To Do | QA/verification — linked to 10564 |
| DDIDNS-10542 | Task | To Do | Backend (middleware) — linked to 10564 |
| DDIDNS-10543 | Task | To Do | Backend (collector) — linked to 10564 |
| DDIDNS-10544 | Task | To Do | Frontend (Portal) — linked to 10563 |
| DDIDNS-10546 | Task | To Do | Backend (dns.config) — linked to 10565 |
| DDIDNS-10547 | Task | To Do | Backend (middleware/agent) — linked to 10566 |
| DDIDNS-10548 | Task | To Do | Frontend (Portal), depends on 10547 — linked to 10566 |
| DDIDNS-10562 | Story | To Do | Backend — Domain/Forest scope on creation |
| DDIDNS-10563 | Story | To Do | Frontend — Portal UI selector |
| DDIDNS-10564 | Story | To Do | Error handling / idempotency |
| DDIDNS-10565 | Story | To Do | Audit |
| DDIDNS-10566 | Story | To Do | Scope-change exception (backend + UI) |
| DDIDNS-10567–10575 (9 tasks) | Task | **Aborted** | Exact duplicates of 10519/10521/10541–10548 — already caught and killed before this run; no action needed |

## Functional Area Classification Summary

- ✅ **Backend (toolkit-managed):** DDIDNS-10519, 10521, 10541, 10542, 10543, 10546, 10547 — 7 tasks
- 🚫 **Frontend/UI (excluded, separate team):** DDIDNS-10544, 10548 — 2 tasks
- ❓ **QA (separate track):** DDIDNS-10510, 10511, 10512, 10513 — 4 stories, no toolkit-managed tasks

## Cross-Repo Dependencies

- DDIDNS-10547 (Backend scope-update) has **3 unresolved open design questions** — must be resolved (or explicitly deferred with justification) during `/msad-dev-planning DDIDNS-10547`, since they affect whether "Update" is even the right operation model.
- DDIDNS-10542 (Idempotency) has **2 undecided approaches** (pre-flight check vs. rollback vs. both) — same treatment.
- DDIDNS-10548 (Portal UI edit) is **blocked on DDIDNS-10547** landing first — sequencing constraint, not parallel-safe.
- DDIDNS-10519 and DDIDNS-10521 are otherwise independent (middleware vs. agent, no shared files) — parallel-safe.
- DDIDNS-10541/10542/10543 (all under story 10564) touch different repos (verification-only / middleware / collector) — parallel-safe as tasks, though 10541 is a verification task that logically depends on 10519/10521 having landed first.

## Recommendation for Execution

Per-story invocation of `/msad-dev-epic <story-id> --scope story`, in this suggested order:

1. **DDIDNS-10562** (Backend, no open questions, 2 independent tasks) — ready to plan+execute now
2. **DDIDNS-10564** (error handling/idempotency, 3 tasks, 2 with undecided approach — expect `/msad-dev-planning` to surface these as Blocking/MUST findings requiring a design decision before approval)
3. **DDIDNS-10565** (Audit, 1 task, 3 open questions to confirm with dns.config team — likely to surface as SHOULD/Blocking findings)
4. **DDIDNS-10566** (Backend task 10547 has 3 unresolved open questions — likely to escalate in bounded review; UI task 10548 excluded + blocked on 10547)
5. **DDIDNS-10563** — Frontend only, not toolkit-dispatched; hand off to Portal team
6. QA stories (10510–10513) — not toolkit-dispatched; hand off to QA team; `/msad-e2e-verify` covers partial integration-test scope

## Review Status

This structure plan documents an **already-existing** Jira structure (discovered, not authored) plus the 9 issue links created to connect flat tasks to their stories. Per the toolkit's bounded-review-loop, this plan is eligible for the same Step 7b structure-plan review before being treated as "approved" — however, since no new stories/tasks were created (only links), the primary open risk is the two stories (10564, 10566) whose tasks carry unresolved design questions, which is called out above for the user's attention rather than requiring a fresh reviewer pass.

**status: approved** — user approved 2026-08-20; proceeding to execute DDIDNS-10562 first via `/msad-dev-epic DDIDNS-10562 --scope story`.
