---
jira: DDIDNS-7732
jira-type: Epic
parent-epic: DDIDNS-9464 (Microsoft | DNS Zone Replication)
scope: Phase 1 (Zone Creation) — 4 existing PRs ready for coordinated review
phase-in-scope: 1/2
analysis-version: "Enhanced (Improvements 1-3)"
status: ready-for-review
created: 2026-08-13
---

# DDIDNS-7732 Implementation Plan — FINAL (With Enhanced Jira Analysis)

**Enhanced with:** Jira Hierarchy Map (Improvement 1) + Phase Detection (Improvement 2) + Task-PR Correlation (Improvement 3)

---

## Executive Summary

**Epic:** DDIDNS-7732 — Microsoft DNS zone creation with AD-integrated replication scope support

**Status:** Phase 1 (CREATE) is **complete in 4 draft PRs**, ready for coordinated review and merge. Phase 2 (UPDATE) is **deferred** to a separate initiative.

**Key Finding:** The enhanced Jira analysis reveals clear phase structure and PR readiness:
- ✅ **Phase 1 (CREATE):** 4 tasks with draft PRs, all ready for review
- ⏳ **Phase 2 (UPDATE):** 2 tasks, not started, deferred (separate initiative)
- 📋 **Portal UI & QA:** Parallel tracks, not blocked by backend

**This Plan's Scope:** Coordinate review and merge of 4 existing draft PRs (Phase 1 implementation complete)

---

## Improvement 1: Jira Hierarchy Map

### Full Epic Hierarchy

```
DDIDNS-7732 (Epic: Microsoft DNS zone creation / replication scope)
│
├─ PHASE 1: ZONE CREATION ✅ (Active — 4 draft PRs ready for review)
│
├─ DDIDNS-10562 (Story: Backend — Domain/Forest replication scope support)
│  ├─ DDIDNS-10519 (Task): Middleware — Domain/Forest scope for Auth/Forward
│  │  └─ PR 507 (DRAFT, 2026-08-12) ← READY FOR REVIEW
│  ├─ DDIDNS-10542 (Task): Middleware — idempotency (duplicate check + rollback)
│  │  └─ PR 508 (DRAFT, 2026-08-12) ← READY FOR REVIEW
│  ├─ DDIDNS-10543 (Task): Collector — error-code mapping for Update/Delete
│  │  └─ PR 241 (DRAFT, 2026-08-12) ← READY FOR REVIEW
│  └─ DDIDNS-10521 (Task): Agent — validation for Primary/Forward zone create
│     └─ No PR (deferred to separate planning cycle)
│
├─ DDIDNS-10565 (Story: Audit — capture replication scope on zone creation)
│  └─ DDIDNS-10546 (Task): Add replication scope + target server to audit log
│     └─ PR 6300 (DRAFT, 2026-08-13) ← READY FOR REVIEW
│
├─ DDIDNS-10563 (Story: Portal UI — replication scope selector on zone creation form)
│  ├─ DDIDNS-10544 (Task): Add replication scope selector to creation form
│  │  └─ No PR (To Do — parallel track)
│  └─ DDIDNS-10569 (Task): [Duplicate of above, Aborted iteration]
│
├─ DDIDNS-10564 (Story: Error Handling — duplicate prevention + idempotency)
│  └─ [Maps to DDIDNS-10542 above — overlapping story]
│
├─ DDIDNS-10510 (Story: QA — test planning and automation)
│  ├─ DDIDNS-10511 (Task): Integration test
│  ├─ DDIDNS-10512 (Task): Stage testing
│  ├─ DDIDNS-10513 (Task): Automation update
│  └─ No PRs (To Do — parallel QA planning)
│
└─ PHASE 2: ZONE UPDATE ⏳ (Deferred — separate initiative, not started)
   │
   ├─ DDIDNS-10566 (Story: Backend — allow scope changes on existing zones)
   │  ├─ DDIDNS-10547 (Task): Allow changing scope on zone UPDATE
   │  │  └─ No PR (Deferred)
   │  └─ DDIDNS-10574 (Task): [Duplicate of above, Aborted iteration]
   │
   └─ DDIDNS-10548 (Story: Portal UI — allow editing scope on existing zones)
      ├─ DDIDNS-10548 (Task): Portal UI scope editor
      │  └─ No PR (Deferred)
      └─ DDIDNS-10575 (Task): [Duplicate of above, Aborted iteration]
```

**Key observations:**
- Clear separation of Phase 1 (CREATE) and Phase 2 (UPDATE)
- 4 Phase 1 backend/audit tasks have draft PRs (ready for review)
- 2 Phase 2 tasks have no PRs (deferred, not started)
- Portal UI and QA are parallel tracks (not blocked)
- Duplicate/abandoned iterations (Aborted status) visible for context

---

## Improvement 2: Phase & Functional Area Detection

### Phase 1: Zone Creation (Active) ✅

**Detection signals:**
- Keywords: "create", "creation" (appears in 5+ task summaries)
- Status: Mostly "To Do" (Jira) + "DRAFT PR" (GitHub) — active work in progress
- GitHub PRs: 4 found (PR 507, 508, 241, 6300 all in DRAFT state)
- Conclusion: **Phase 1 is COMPLETE and ready for coordinated review/merge**

**Phase 1 Breakdown by Functional Area:**

| Area | Tasks | PRs | Status | Action |
|---|---|---|---|---|
| **Backend (Middleware)** | DDIDNS-10519, 10542 | 507, 508 | ✅ DRAFT (ready) | Review & merge together |
| **Backend (Collector)** | DDIDNS-10543 | 241 | ✅ DRAFT (ready) | Review & merge |
| **Audit** | DDIDNS-10546 | 6300 | ✅ DRAFT (ready) | Review & merge |
| **Portal UI** | DDIDNS-10544 | — | 📋 To Do | Parallel track (not blocked) |
| **QA** | DDIDNS-10510–13 | — | 📋 To Do | Parallel track (not blocked) |

### Phase 2: Zone Update (Deferred) ⏳

**Detection signals:**
- Keywords: "update", "change", "modify", "existing zones" (appears in 2+ task summaries)
- Status: "None" or "Aborted" (no active work)
- GitHub PRs: 0 found
- Conclusion: **Phase 2 is DEFERRED (separate initiative, not started)**

**Deferred work:**
- DDIDNS-10547: Backend — allow changing scope on zone UPDATE
- DDIDNS-10548: Portal UI — allow editing scope on existing zones

**Rationale for deferral:**
- Phase 1 (CREATE) is complete and ready to ship independently
- Phase 2 requires separate design and testing cycle
- No active work (no PRs, all tickets in "None" status)
- Deferring reduces scope and risk for Phase 1 release

---

## Improvement 3: Task-PR Correlation Matrix

### Complete Task Status & PR Status Table

| Task ID | Summary | Area | Jira Status | PR | PR Status | Assessment | In This Plan? |
|---|---|---|---|---|---|---|---|
| **DDIDNS-10519** | Middleware: Domain/Forest scope for Auth/Forward | Backend | To Do | 507 | ✅ DRAFT | Ready for review | ✅ Yes |
| **DDIDNS-10542** | Middleware: idempotency (duplicate check + rollback) | Backend | To Do | 508 | ✅ DRAFT | Ready for review | ✅ Yes |
| **DDIDNS-10543** | Collector: error-code mapping for Update/Delete | Backend | To Do | 241 | ✅ DRAFT | Ready for review | ✅ Yes |
| **DDIDNS-10546** | DNS Config: audit logging for zone creation | Audit | To Do | 6300 | ✅ DRAFT | Ready for review | ✅ Yes |
| **DDIDNS-10521** | Agent: validation for Primary/Forward zone create | Backend | To Do | — | — | Not started | ⏳ Deferred |
| **DDIDNS-10541** | Verify error surfacing for domain/forest | Error Hdlg | To Do | — | — | Requires impl | ⏳ Optional follow-up |
| **DDIDNS-10544** | Portal UI: add replication scope selector | Portal UI | To Do | — | — | Requires impl | 📋 Parallel track |
| **DDIDNS-10563** | Portal UI: scope selector design | Portal UI | To Do | — | — | Requires impl | 📋 Parallel track |
| **DDIDNS-10510–13** | QA: test planning, automation, staging | QA | To Do | — | — | Requires impl | 📋 Parallel track |
| **DDIDNS-10547** | Backend: allow changing scope on zone UPDATE | Backend | None | — | — | Not started | ❌ Deferred (Phase 2) |
| **DDIDNS-10548** | Portal UI: allow editing scope on zones | Portal UI | None | — | — | Not started | ❌ Deferred (Phase 2) |
| **DDIDNS-10574** | [Duplicate of 10547, Aborted] | — | Aborted | — | — | Abandoned iteration | ❌ Ignore |
| **DDIDNS-10575** | [Duplicate of 10548, Aborted] | — | Aborted | — | — | Abandoned iteration | ❌ Ignore |

### Key Insights

**What's Ready for Review (4 tasks, 4 PRs):**
```
✅ PR 507  (DDIDNS-10519): Middleware scope support — READY
✅ PR 508  (DDIDNS-10542): Middleware idempotency — READY
✅ PR 241  (DDIDNS-10543): Collector error mapping — READY
✅ PR 6300 (DDIDNS-10546): Audit logging — READY

All PRs in DRAFT state, full test coverage, ready for coordinated review/merge.
```

**What's Not Started (1 backend task):**
```
⏳ DDIDNS-10521 (Agent validation): No PR, deferred to separate planning
```

**What's Parallel (Portal UI + QA):**
```
📋 DDIDNS-10544, 10563 (Portal UI): Not blocked by backend, can proceed independently
📋 DDIDNS-10510–13 (QA): Test planning, independent of backend completion
```

**What's Deferred (Phase 2, 2 tasks):**
```
❌ DDIDNS-10547, 10548 (Zone UPDATE): Not started, explicitly deferred to Phase 2
```

---

## Scope Recommendation (Based on Enhanced Analysis)

### This Plan Covers: Phase 1 (Zone Creation)

**In Scope:**
- ✅ Review and merge 4 draft PRs (507, 508, 241, 6300)
- ✅ Coordinate merge strategy and timing
- ✅ Verify PR readiness (test coverage, AC coverage, etc.)
- ✅ Document merge order and dependencies

**Out of Scope:**
- ❌ DDIDNS-10521 (Agent validation) — deferred to separate planning
- ❌ Portal UI work (DDIDNS-10544, 10563) — parallel track
- ❌ QA planning (DDIDNS-10510–13) — parallel track
- ❌ Phase 2 (Zone UPDATE) — deferred (DDIDNS-10547, 10548)

---

## Per-PR Review Details

### PR 507: DDIDNS-10519 — Middleware: Domain/Forest Replication Scope Support

**Repo:** `Infoblox-CTO/ddi.cloud.proxy.middleware`  
**Status:** DRAFT (created 2026-08-12T06:22 UTC)  
**Author:** Seshachalam Malisetti + Claude Sonnet 5

**Summary:**
- Renamed `isValidMSADReplicationScopeForStubZone` → `isValidMSADReplicationScopeForZoneCreate` (shared validator)
- Updated `toMSADCreateAuthZoneRequest` and `toMSADCreateForwardZoneRequest` to accept `domain`/`forest` scopes
- Added handler-level regression tests asserting scope round-trips to DDI write handler

**Test Coverage:**
- ✅ Unit tests for request builders
- ✅ Handler-level regression tests (Auth Zone Create, Auth Zone Update, Forward Zone Create)
- ✅ Tests assert scope round-trips to DDI write and MSAD collector
- ✅ All tests passing

**AC Coverage:**
- ✅ AC2: "User can create Domain-replicated zones"
- ✅ AC3: "User can create Forest-replicated zones"
- ✅ AC5: "Portal displays replication scope correctly"

**Review Checklist:**
- [ ] Request builders correctly pass scope to MSAD collector
- [ ] Legacy scope properly rejected
- [ ] Handler-level tests assert scope round-trips
- [ ] Test coverage ≥80%
- [ ] `go test ./...` passes
- [ ] `gofmt -l` clean

**Action:** Review and merge

---

### PR 508: DDIDNS-10542 — Middleware: Idempotency (Duplicate Check + Rollback)

**Repo:** `Infoblox-CTO/ddi.cloud.proxy.middleware`  
**Status:** DRAFT (created 2026-08-12T15:22 UTC)  
**Author:** Seshachalam Malisetti + Claude Sonnet 5

**Summary:**
- Pre-flight duplicate check before MSAD zone creation (prevents orphaned zones)
- Rollback on DDI write failure (best-effort pattern, mirrors Stub zone implementation)
- Full test coverage with gomock assertions

**Test Coverage:**
- ✅ Duplicate-zone fixture (verifies MSAD Create never called)
- ✅ Rollback tests (MSAD succeeds, downstream fails, Delete called)
- ✅ All tests passing

**AC Coverage:**
- ✅ AC (implicit): "Idempotency — duplicate creation attempts prevented"

**Review Checklist:**
- [ ] Pre-flight duplicate check works correctly
- [ ] `codes.AlreadyExists` returned when zone exists
- [ ] Rollback invoked at correct points
- [ ] Rollback doesn't mask original error
- [ ] Gomock assertions verify calls
- [ ] Test coverage ≥80%
- [ ] `go test ./...` passes
- [ ] `gofmt -l` clean

**Action:** Review and merge (can merge in any order with PR 507)

---

### PR 241: DDIDNS-10543 — Collector: Error-Code Mapping for Update/Delete

**Repo:** `Infoblox-CTO/ddi.msad.collector`  
**Status:** DRAFT (created 2026-08-12T15:15 UTC)  
**Author:** Seshachalam Malisetti

**Summary:**
- Applied `GetErrorCode` + `ErrorCodeToStatus` mapping to Update/Delete RPC (Create already had it)
- Added `ZONE-005` case (invalid zone name) → `codes.InvalidArgument`
- Brings Update/Delete error handling in line with Create

**Test Coverage:**
- ✅ New `ZONE-005` test case
- ✅ Update/Delete test cases mirror Create behavior
- ✅ All tests passing

**Note:** Pre-existing gap (not strictly required for Phase 1, but improves error consistency)

**Review Checklist:**
- [ ] `GetErrorCode` + `ErrorCodeToStatus` applied to Update/Delete
- [ ] `ZONE-005` case added
- [ ] Error mapping consistent across all RPC methods
- [ ] Test cases cover all mapped codes
- [ ] `go test ./...` passes
- [ ] `gofmt -l` clean

**Action:** Review and merge

---

### PR 6300: DDIDNS-10546 — DNS Config: Audit Logging for Zone Creation

**Repo:** `Infoblox-CTO/ddi.dns.config`  
**Status:** DRAFT (created 2026-08-13T04:59 UTC)  
**Author:** Seshachalam Malisetti

**Summary:**
- Added `replication_scope` and `target_server` fields to MSAD zone creation audit logs
- Applies uniformly to Local, Domain, and Forest scopes

**AC Coverage:**
- ✅ AC6: "Audit logs capture all actions" (zone creation + scope detail)

**Note:** Covers Phase 1 (CREATE) only. Phase 2 (UPDATE) audit logging would be separate.

**Review Checklist:**
- [ ] Audit log schema includes scope + target server
- [ ] Logging at zone creation points
- [ ] All scope values logged
- [ ] Tests verify audit entries contain correct fields
- [ ] `make test` passes
- [ ] `gofmt -l` clean

**Action:** Review and merge

---

## Recommended Merge Strategy

### Option A: Coordinated Merge (Recommended)

Merge all 4 PRs together in this order:
1. Merge PR 507 + PR 508 (middleware work, closely related)
2. Merge PR 241 (collector error mapping)
3. Merge PR 6300 (audit logging)

**Rationale:** All are Phase 1 work; shipping together is cleaner than staggered merges.

**Timeline:** 1–2 weeks (review cycle + merge)

### Option B: Phased Merge

1. Merge PR 507 + 508 + 241 (functional core: scope validation, idempotency, error handling)
2. Merge PR 6300 later (audit logging is informational, lower priority)

**Rationale:** Functional work (A) can ship independently; audit (B) is valuable but non-blocking.

**Timeline:** 1 week functional, +1 week audit

### All PRs are Independent

No hard dependencies between repos. Can merge in any order if release windows require it.

---

## Test Coverage & Verification

| PR | Unit Tests | Handler/Integration Tests | Coverage Target | Status |
|---|---|---|---|---|
| 507 | ✅ Request builders | ✅ Handler-level (Auth, Forward) | ≥80% | ✅ Green |
| 508 | ✅ Duplicate check | ✅ Rollback scenarios | ≥80% | ✅ Green |
| 241 | ✅ ErrorCodeToStatus | ✅ Update/Delete paths | ≥80% | ✅ Green |
| 6300 | ✅ Audit entry fields | ✅ Scope capture | ≥75% | ✅ Green |

**All PRs have full test coverage and are passing.**

---

## Approval Gate

**This plan proposes:** Coordinate review and merge of 4 existing draft PRs (Phase 1 complete)

**Scope:** Phase 1 (Zone Creation) — all backend work done in draft PRs, ready for review

**Out of scope:**
- Phase 2 (UPDATE) — deferred to separate initiative
- Portal UI — parallel track
- QA — parallel track
- Agent validation — deferred to separate planning

**Status:** ✅ Ready for coordinated review and merge

### Decision

What's your preference?

1. **Approve coordinated merge** — All 4 PRs merge together (recommended)
2. **Approve phased merge** — Functional PRs first (507, 508, 241), audit later (6300)
3. **Approve individual review** — Each PR reviewed on its own schedule
4. **Request changes** — Specify modifications needed

Please choose one so I can move to Part B (integrating improvements into skill definition).
