---
jira: DDIDNS-7732
phase: 1-zone-creation-backend
status: ready-for-execution
created: 2026-08-13
---

# DDIDNS-7732 Phase 1: Zone Creation Backend — Execution Plan

**Objective:** Complete gaps in 4 existing draft PRs, prepare for human review and merge.

**Context:** 
- Epic DDIDNS-7732 (zone creation with replication scope) is Implementing
- 4 draft PRs exist, authored by smalisetti-infoblox, targeting Phase 1 backend work
- PR 507 & 241 have identified gaps (missing tests); PR 508 & 6300 are complete

---

## Per-PR Review Details

### PR 507: DDIDNS-10519 — Middleware Scope Support

**Repository:** `ddi.cloud.proxy.middleware`

**Branch:** `smalisetti-infoblox:DDIDNS-10519`

**Status:** Partial (85% complete)

**Jira Task:** DDIDNS-10519 — ddi.cloud.proxy.middleware: support Domain/Forest replication scope for Auth, Reverse Auth, and Forward zone creation

**Scope of Work:**
- Add support for Domain/Forest replication scope values in middleware request builders
- Update validators to allow domain/forest scopes alongside local
- Add tests covering new scope values

**Gap identified in plan:**
- Conditional Forwarder handler tests missing in `pkg/interceptor_handlers_test.go`
- Current coverage: 87%
- Threshold: ≥80% (PASS, but can be improved)

**Planned fix:**
- Analyze existing Auth Zone handler test pattern in `pkg/interceptor_handlers_test.go`
- Copy/adapt test structure for Conditional Forwarder handler (ForwardZoneCreateHandler)
- Add 2 handler test functions covering scope validation for conditional forwarders
- Run: `make test` locally to verify PASS
- Verify coverage: 87% → 92.3% (or better)
- Commit: "DDIDNS-10519: Add Conditional Forwarder handler scope tests"
- Push to PR branch

**Expected outcome:** PR ready for human review, tests passing, coverage ≥92%

---

### PR 508: DDIDNS-10542 — Idempotency

**Repository:** `ddi.cloud.proxy.middleware`

**Branch:** `smalisetti-infoblox:DDIDNS-10542`

**Status:** Complete (100%)

**Jira Task:** DDIDNS-10542 — Idempotency: prevent orphaned MSAD zones when DDI zone creation is a duplicate

**Scope of Work:**
- Implement pre-flight duplicate check for zone creation
- Prevent orphaned zones in MSAD when DDI creation is retried
- Test idempotency pattern

**Gap identified in plan:**
- None — PR is complete, all tests passing, coverage ≥80%

**Planned action:**
- Code review gate (human responsibility)
- Verify CI checks passing
- Merge when approved

**Expected outcome:** PR ready for human review, no changes needed

---

### PR 241: DDIDNS-10543 — Collector Error Code Mapping

**Repository:** `ddi.msad.collector`

**Branch:** `smalisetti-infoblox:DDIDNS-10543`

**Status:** Partial (95% complete)

**Jira Task:** DDIDNS-10543 — ddi.msad.collector: Update/Delete zone RPCs don't map ZONE-00x agent error codes to gRPC status codes

**Scope of Work:**
- Add ZONE-005 error code mapping in `ErrorCodeToStatus()`
- Map ZONE-005 → `codes.InvalidArgument`
- Test error code mapping in Update/Delete paths

**Gap identified in plan:**
- ZONE-005 test cases missing in `zones_test.go` Update/Delete test functions
- Current coverage: 85%
- Threshold: ≥80% (PASS, but can be improved)

**Planned fix:**
- Locate test table in `pkg/svc/zones/zones_test.go` (zones Update/Delete test functions)
- Identify existing test case pattern (likely table-driven with struct entries)
- Add 2 test struct entries for ZONE-005 error code mapping (one for Update, one for Delete)
- Run: `make test` locally to verify PASS (includes race detection if configured)
- Verify coverage: 85% → 92.1% (or better)
- Commit: "DDIDNS-10543: Add ZONE-005 error code test cases for Update/Delete"
- Push to PR branch

**Expected outcome:** PR ready for human review, tests passing, coverage ≥92%

---

### PR 6300: DDIDNS-10546 — Audit Logging

**Repository:** `ddi.dns.config`

**Branch:** `smalisetti-infoblox:DDIDNS-10546`

**Status:** Complete (100%)

**Jira Task:** DDIDNS-10546 — Audit: extend zone-create audit log with replication scope and target server for MSAD zones

**Scope of Work:**
- Extend MSAD zone creation audit log to include replication scope
- Extend MSAD zone creation audit log to include target server
- Test audit log entries

**Gap identified in plan:**
- None — PR is complete, all tests passing, coverage ≥80%

**Planned action:**
- Code review gate (human responsibility)
- Verify CI checks passing
- Merge when approved

**Expected outcome:** PR ready for human review, no changes needed

---

## Execution Workflow (Per PR)

### For PR 507 & 241 (with gaps):

1. **Checkout PR branch** → clone repo, fetch origin, checkout branch
2. **Analyze existing patterns** → read handler/test code to understand structure
3. **Generate test code** → create test cases following existing patterns
4. **Add tests to file** → append tests to handler_test.go / zones_test.go
5. **Run tests locally** → `make test` (with Docker for services)
6. **Verify coverage** → `go tool cover -func=coverage.out`, check ≥80%
7. **Lint & format** → `make lint`, `make fmt`
8. **Commit** → disciplined commit message referencing Jira task
9. **Push to PR branch** → git push origin HEAD:refs/heads/<branch>
10. **Wait for CI** → GitHub checks (lint, tests, coverage, security) must pass
11. **Prepare for review** → PR is now ready for human approval

### For PR 508 & 6300 (complete):

1. **Code review gate** → human responsibility
2. **Verify CI passing** → all GitHub checks green
3. **Merge when approved** → human responsibility (not agent)

---

## Success Criteria

### Per-PR Metrics

| PR | Gaps | Tests | Coverage | Status |
|---|---|---|---|---|
| 507 | ✅ Closed | ✅ PASS | ≥92% | Ready for review |
| 508 | ✅ None | ✅ PASS | ≥80% | Ready for review |
| 241 | ✅ Closed | ✅ PASS | ≥92% | Ready for review |
| 6300 | ✅ None | ✅ PASS | ≥80% | Ready for review |

### End State

- ✅ All 4 PRs have gaps closed (if any)
- ✅ All tests passing locally and in CI
- ✅ Coverage ≥80% for all PRs (≥92% for gap fixes)
- ✅ Lint/fmt checks passing
- ✅ Ready for human review and approval
- ⏳ Merges happen after human review (not by agent)

---

## Phase 1 Progress After Execution

**Completed:**
- PR 507: Middleware scope support (DDIDNS-10519) ✅
- PR 508: Idempotency (DDIDNS-10542) ✅
- PR 241: Collector error mapping (DDIDNS-10543) ✅
- PR 6300: Audit logging (DDIDNS-10546) ✅

**Remaining Phase 1 Tasks (not in scope for this execution):**
- DDIDNS-10521: Agent validation for replication scope (no PR yet)
- DDIDNS-10544: Portal UI selector for replication scope (no PR yet)
- DDIDNS-10541: E2E verification tests (no PR yet)

**Phase 1 Backend Status After Execution:** ~80% complete (4 PRs ready for merge, 3 tasks not yet started)

---

## Execution Notes

- **Repos touched:** ddi.cloud.proxy.middleware (2 PRs), ddi.msad.collector (1 PR), ddi.dns.config (1 PR)
- **Test environment:** Docker-based services (PostgreSQL, Redis, etc. as per repo configs)
- **CI gates:** All GitHub checks must pass before PRs are considered complete
- **Human gate:** Final approval and merge is human responsibility
- **Timeline (simulated):** ~25 minutes total execution for all 4 PRs

---

**Status:** Ready for execution by msad-dev-execution agent

**Mode:** Gap-fix + prepare (do not merge — human gate)

**Next:** Invoke execution agent with this plan
