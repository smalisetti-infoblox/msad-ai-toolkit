# STORY 4 Creation Template — DDIDNS-7732

**Date Created:** 2026-08-13  
**Epic:** DDIDNS-7732 — Microsoft DNS zone creation with replication scope  
**Phase:** Phase 2 (Deferred)

---

## STORY 4: Backend — Support Replication Scope Change on Existing Zones

### Jira Issue Details

**Summary:** Backend — Support Replication Scope Change on Existing Zones

**Type:** Story

**Project:** DDIDNS

**Epic Link:** DDIDNS-7732

**Status:** To Do

**Priority:** Medium

**Components:** Backend, Multi-Repo

**Labels:** Phase-2, scope-management, deferred

### Description

Allow changing replication scope on existing AD-integrated zones. Phase 2 work, deferred until Phase 1 completion. Requires careful validation to prevent zone corruption.

Enables users to update the replication scope (Local → Domain, Domain → Forest, etc.) on zones that are already created and in use. Must handle:
- Scope validation at each layer
- Zero data loss guarantees
- Audit logging of scope changes
- Safe rollback on failures

### Acceptance Criteria

- ✓ Users can update replication scope on existing AD-integrated zones
- ✓ Scope change validated at middleware layer (reject invalid transitions)
- ✓ Collector error codes handle scope-change failures (new error codes if needed)
- ✓ Agent validates scope before executing PowerShell scope-change cmdlet
- ✓ Audit logs capture all scope change attempts (success/failure)
- ✓ No data loss during scope change operation
- ✓ All existing tests pass; new tests coverage ≥92%
- ✓ No regressions in zone creation flows

### Story Points

**Estimate:** 13 points (Large story, Phase 2)

### Linked Issues

**Parent Epic:** DDIDNS-7732

**Child Tasks:**
- DDIDNS-10547: Backend: allow scope change on existing zones
- DDIDNS-10548: Portal UI: scope change interface

**Blocks:**
- (None yet — Phase 1 must complete first)

**Blocked By:**
- DDIDNS-7732 Phase 1 completion (depends on zone creation working)

---

## TASK 1: DDIDNS-10547

### Jira Issue Details

**Summary:** Backend: allow scope change on existing zones

**Type:** Task

**Project:** DDIDNS

**Parent Story:** STORY 4 (Backend — Support Replication Scope Change on Existing Zones)

**Status:** To Do

**Priority:** Medium

**Components:** Backend, Multi-Repo

**Labels:** Phase-2, scope-change, backend

### Description

Implement scope change support across the backend stack (middleware, collector, dns.config, agent). Validate scope changes safely without data loss.

**Work Items:**

1. **ddi.dns.config** — Add scope change validator
   - File: `pkg/service/application/stub_zone.go`
   - Add `validateScopeChangeAllowed()` function
   - Verify scope transitions (e.g., local→domain allowed, forest→forest no-op)
   - Tests: test_stub_zone.go

2. **ddi.cloud.proxy.middleware** — Transform & validate scope change
   - File: `pkg/msad_zone_helper.go`
   - Update `isValidMSADReplicationScopeForZoneUpdate()` function
   - Handle scope transitions (add new transition validation)
   - Tests: msad_zone_helper_test.go

3. **ddi.msad.collector** — Map scope-change error codes
   - File: `pkg/util/util.go`
   - Add error code mapping for scope-change failures (e.g., ZONE-010, ZONE-011)
   - File: `pkg/svc/zones/zones.go`
   - Implement scope change handler
   - Tests: zones_test.go, util_test.go

4. **ddi.msad.agent** — Validate scope before PowerShell execution
   - File: `MSADAgent/Agent/Core/DnsInfoControllers/DnsPrimaryZoneController.cs`
   - Add scope change method to controller
   - Call PowerShell `Set-DnsServerPrimaryZone -ReplicationScope` cmdlet
   - Tests: DnsPrimaryZoneControllerTests.cs

### Acceptance Criteria

- ✓ Scope change validators work across all 4 repos
- ✓ Scope transitions validated (prevent invalid changes)
- ✓ Error codes for scope-change failures mapped (ZONE-010, ZONE-011, etc.)
- ✓ Agent calls correct PowerShell cmdlet for scope changes
- ✓ Tests cover all scope transitions (local→domain, domain→forest, etc.)
- ✓ Coverage ≥92% across all modified files
- ✓ No regressions in zone creation or existing scope handling
- ✓ All CI checks pass (lint, build, unit tests)

### Story Points

**Estimate:** 8 points (Large task)

**Effort:** 8–10 hours

### Linked Issues

**Parent Story:** STORY 4

**Related Tasks:**
- DDIDNS-10542: Idempotency (related for transaction safety)
- DDIDNS-10543: Error mapping (related for error codes)

**Implementation Order:**

1. Start with dns.config validators
2. Update middleware (depends on dns.config)
3. Implement collector handler (depends on middleware)
4. Implement agent validation (depends on collector)

---

## TASK 2: DDIDNS-10548

### Jira Issue Details

**Summary:** Portal UI: scope change interface

**Type:** Task

**Project:** DDIDNS

**Parent Story:** STORY 4 (Backend — Support Replication Scope Change on Existing Zones)

**Status:** To Do

**Priority:** Medium

**Components:** Frontend, UI, Portal

**Labels:** Phase-2, scope-change, frontend

### Description

Add Portal UI component to allow users to change replication scope on existing zones. Include validation, confirmation dialogs, and documentation updates.

**Work Items:**

1. **Portal UI Component** — Scope change form
   - Location: Portal zone management page
   - Add "Change Scope" button to zone details
   - Display current scope, allow selection of new scope
   - Show allowed scope transitions (with validation)
   - Confirmation dialog before change (warn about potential impact)

2. **Form Validation**
   - Validate scope selection matches allowed transitions
   - Show error messages for invalid transitions
   - Disable "Change" button until valid scope selected

3. **Portal Documentation**
   - Update zone management documentation
   - Explain replication scopes and transitions
   - Add warnings about scope change impact
   - Include examples of scope transitions

4. **E2E Tests**
   - Test scope change workflow via Portal
   - Test validation and error handling
   - Test confirmation dialog

### Acceptance Criteria

- ✓ Portal UI allows scope selection on existing zones
- ✓ Form validates scope transitions (uses backend validators)
- ✓ Confirmation dialog shown before scope change
- ✓ Error messages display for invalid transitions
- ✓ Portal documentation updated with scope change info
- ✓ E2E tests cover scope change workflow
- ✓ UX review passed
- ✓ No regressions in zone creation or other Portal features

### Story Points

**Estimate:** 5 points (Medium task)

**Effort:** 4–6 hours

### Linked Issues

**Parent Story:** STORY 4

**Blocks:**
- (None yet — Phase 1 feature is blocked until Phase 1 complete)

**Blocked By:**
- Backend implementation (DDIDNS-10547 must complete first)

---

## Implementation Sequence

### Phase 2 Workflow

```
User Action → Portal UI (DDIDNS-10548)
  ↓
Form Validation (scope transition check)
  ↓
API Call → dns.config (scope validator)
  ↓
Middleware Transform → ddi.cloud.proxy.middleware
  ↓
Collector Handler → ddi.msad.collector
  ↓
Agent Validation → ddi.msad.agent (PowerShell)
  ↓
Response → Portal UI (success/error)
```

### Implementation Order

1. **DDIDNS-10547** (Backend) — Implement scope change support
   - Start with dns.config validators
   - Then middleware transformation
   - Then collector error mapping
   - Then agent validation
   - Timeline: ~8–10 hours, can be parallelized

2. **DDIDNS-10548** (Frontend/Portal) — Add UI component
   - Cannot start until backend PR merged
   - Depends on backend API being available
   - Timeline: ~4–6 hours after backend complete

3. **QA/E2E** — Add scope change test automation
   - Cannot start until both backend and UI complete
   - Tests full workflow (API → Portal → Zone Update)
   - Timeline: ~2–3 hours after implementation complete

### Timeline Summary

- **Phase 1 (Active):** ~20 minutes (complete existing PRs)
- **Phase 2 (Deferred):** ~12–16 hours total
  - Backend: 8–10 hours (parallel agents possible)
  - Frontend: 4–6 hours (after backend)
  - QA/E2E: 2–3 hours (after both)

---

## Jira CLI Commands (Optional)

If you want to create these issues via CLI:

### Create Story

```bash
jira issue create \
  --project DDIDNS \
  --type Story \
  --summary "Backend — Support Replication Scope Change on Existing Zones" \
  --description "Allow changing replication scope on existing AD-integrated zones. Phase 2 work, deferred until Phase 1 completion." \
  --priority Medium \
  --epic DDIDNS-7732 \
  --labels Phase-2,scope-management,deferred
```

### Create Task 1 (DDIDNS-10547)

```bash
jira issue create \
  --project DDIDNS \
  --type Task \
  --summary "Backend: allow scope change on existing zones" \
  --description "Implement scope change support across middleware, collector, dns.config, and agent layers." \
  --priority Medium \
  --parent <STORY_ID> \
  --labels Phase-2,scope-change,backend
```

### Create Task 2 (DDIDNS-10548)

```bash
jira issue create \
  --project DDIDNS \
  --type Task \
  --summary "Portal UI: scope change interface" \
  --description "Add Portal UI component to allow users to change replication scope on existing zones." \
  --priority Medium \
  --parent <STORY_ID> \
  --labels Phase-2,scope-change,frontend
```

---

## Notes

- **Phase 2 Status:** Deferred (pending Phase 1 completion)
- **Blocker:** Phase 1 backend PRs must be merged first
- **Frontend:** Portal UI work requires coordination with Portal team
- **Testing:** Phase 2 requires stage/QA testing with real MSAD environment
- **Effort Estimate:** 12–16 hours total (Phase 2 only)
- **Expected Completion:** After Phase 1 (estimated ~2 weeks from Phase 1 merge)

---

**Created by:** Claude Code MSAD Epic Planner  
**For Epic:** DDIDNS-7732 (Microsoft DNS zone creation with replication scope)
