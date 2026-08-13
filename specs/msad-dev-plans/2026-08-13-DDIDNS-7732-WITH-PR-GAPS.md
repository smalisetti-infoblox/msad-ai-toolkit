---
jira: DDIDNS-7732
jira-type: Epic
parent-epic: DDIDNS-9464 (Microsoft | DNS Zone Replication)
scope: Phase 1 (Zone Creation) — Complete & refine 4 existing PRs
phase-in-scope: 1/2
pr-treatment: "Partial work with gaps; execution agents will complete"
status: ready-for-execution
created: 2026-08-13
---

# DDIDNS-7732 Implementation Plan — Phase 1 (Complete Partial PRs)

**Plan approach:** The 4 existing draft PRs represent **partially implemented work**. This plan identifies gaps and plans fixes. Execution agents will complete the PRs, run tests, and merge when ready.

---

## Executive Summary

**What we have:** 4 draft PRs (507, 508, 241, 6300) with partial implementations of Phase 1

**What we do:** 
1. Identify gaps in each PR (missing AC coverage, incomplete tests, edge cases)
2. Plan fixes for execution phase
3. Execute agents modify PRs, complete tests, verify quality
4. Merge PRs when ready

**Outcome:** Phase 1 (Zone Creation) fully implemented, tested, and shipped

---

## PR Gap Assessment (Step 3.4)

### PR 507: DDIDNS-10519 — Middleware: Domain/Forest Replication Scope

**Repo:** `Infoblox-CTO/ddi.cloud.proxy.middleware`  
**Status:** DRAFT (created 2026-08-12)  
**Current Completion:** ~85%

#### AC Coverage Analysis

| AC | Description | Status | Evidence |
|---|---|---|---|
| **AC1** | User can create Domain-replicated zones | ✅ Implemented | `toMSADCreateAuthZoneRequest` accepts domain scope, unit tests present |
| **AC2** | User can create Forest-replicated zones | ✅ Implemented | `toMSADCreateAuthZoneRequest` accepts forest scope, unit tests present |
| **AC3** | Replication scope is correctly applied | ✅ Implemented | Validator `isValidMSADReplicationScopeForZoneCreate` shared across zone types |
| **AC5** | Portal displays replication scope correctly | ⚠️ Partial | Handler tests verify scope round-trips to DDI write for Auth zones, but **Conditional Forwarder NOT tested** |

#### Gap Details

**Gap 1: Conditional Forwarder Scope Validation Not Tested**

- **Problem:** PR implements scope support for Auth Zone and Forward Zone, but handler-level tests don't verify it for Conditional Forwarder zone type
- **Risk:** Conditional Forwarder zones might not properly validate/propagate scope in production
- **Evidence:** 
  - Unit tests in `pkg/msad_zone_helper_test.go` cover Stub/Auth/Forward builders
  - Handler tests in `pkg/interceptor_handlers_test.go` cover Auth and Forward handlers
  - **Missing:** No handler test for `DnsConditionalForwarderZoneController` with domain/forest scope
- **Fix needed:** Add handler test cases for Conditional Forwarder with domain and forest scopes

**Gap 2: Test Coverage: 87% (Acceptable, but could be higher)**

- Current coverage: 87% (≥80% threshold met, but incomplete coverage of Conditional Forwarder path)
- Adding Conditional Forwarder handler tests would bring coverage to ~92%

#### Test Coverage Status

```
Current state:
- Unit tests (request builders): ✅ All scope values covered
- Handler tests (Auth Zone): ✅ Domain and forest scope tested
- Handler tests (Forward Zone): ✅ Domain and forest scope tested
- Handler tests (Conditional Forwarder): ❌ MISSING

After fix:
- Add: Test_DnsConditionalForwarderZoneController_Create_DomainScope
- Add: Test_DnsConditionalForwarderZoneController_Create_ForestScope
- Coverage: 87% → ~92%
```

#### Execution Plan

**Phase 1 (Planning - Done):** Identify gap  
**Phase 2 (Execution - Todo):**
1. Checkout PR 507 branch: `git checkout origin/507/branch`
2. Add handler test in `pkg/interceptor_handlers_test.go`:
   ```go
   func Test_DnsConditionalForwarderZoneController_Create_DomainScope(t *testing.T) {
       // Test domain scope for Conditional Forwarder
       // Verify scope propagates to MSAD collector and DDI write handler
   }
   
   func Test_DnsConditionalForwarderZoneController_Create_ForestScope(t *testing.T) {
       // Test forest scope for Conditional Forwarder
       // Verify scope propagates to MSAD collector and DDI write handler
   }
   ```
3. Run `docker-compose up && make test && docker-compose down`
4. Verify coverage ≥80%
5. Commit: "DDIDNS-10519: add handler tests for Conditional Forwarder scope validation"
6. Push to PR branch
7. CI runs, verify checks passing
8. Merge PR when ready

**Readiness:** 🟡 **Partial work — 85% complete, needs 1 gap fix**

---

### PR 508: DDIDNS-10542 — Middleware: Idempotency

**Repo:** `Infoblox-CTO/ddi.cloud.proxy.middleware`  
**Status:** DRAFT (created 2026-08-12)  
**Current Completion:** ~100%

#### AC Coverage Analysis

| AC | Description | Status | Evidence |
|---|---|---|---|
| **AC (Implicit)** | Idempotency: duplicate creation attempts prevented | ✅ Implemented | Pre-flight duplicate check + rollback on failure, full test coverage |

#### Gap Details

**No gaps identified.** PR is functionally complete:
- ✅ Pre-flight duplicate check implemented
- ✅ Rollback on DDI write failure implemented
- ✅ Test coverage: duplicate detection verified with gomock
- ✅ Test coverage: rollback scenarios verified
- ✅ Edge case handling: rollback doesn't mask original error
- ✅ Code coverage: 92% (exceeds ≥80% threshold)

#### Execution Plan

**Phase 1 (Planning - Done):** Assess PR, no gaps found  
**Phase 2 (Execution - Todo):**
1. Code review by toolkit reviewer agent
2. Run `docker-compose up && make test && docker-compose down`
3. Verify coverage ≥80% (already met)
4. Verify no lint/fmt issues
5. Merge PR when checks pass

**Readiness:** 🟢 **Complete work — ready for merge**

---

### PR 241: DDIDNS-10543 — Collector: Error-Code Mapping

**Repo:** `Infoblox-CTO/ddi.msad.collector`  
**Status:** DRAFT (created 2026-08-12)  
**Current Completion:** ~95%

#### AC Coverage Analysis

| AC | Description | Status | Evidence |
|---|---|---|---|
| **AC (Implicit)** | Error codes consistently mapped to gRPC status | ✅ Implemented | ZONE-005 added to ErrorCodeToStatus, Update/Delete paths updated |

#### Gap Details

**Gap 1: Verify ZONE-005 Mapping in All Three RPC Paths**

- **Problem:** ZONE-005 mapping is added to `ErrorCodeToStatus`, and unit test covers it. However, integration tests need to verify it works in actual Update/Delete RPC paths (not just unit test)
- **Risk:** ZONE-005 mapping might not work end-to-end in Update/Delete flows
- **Evidence:**
  - Unit test in `pkg/util/util_test.go`: `TestErrorCodeToStatus` has ZONE-005 case ✅
  - Update path test in `pkg/svc/zones/zones_test.go`: Covers AlreadyExists, PermissionDenied, but doesn't explicitly test ZONE-005 ⚠️
  - Delete path test: Same — covers basic cases but not ZONE-005 ⚠️
- **Fix needed:** Add table-driven test cases for ZONE-005 in Update and Delete test functions

#### Test Coverage Status

```
Current state:
- Unit test (ErrorCodeToStatus): ✅ ZONE-005 mapped correctly
- Create path test: ✅ ZONE-005 case covered
- Update path test: ❌ ZONE-005 case missing
- Delete path test: ❌ ZONE-005 case missing

After fix:
- Add: Test case for Update RPC with ZONE-005 agent error
- Add: Test case for Delete RPC with ZONE-005 agent error
- Coverage: 85% → ~92%
```

#### Execution Plan

**Phase 1 (Planning - Done):** Identify gap  
**Phase 2 (Execution - Todo):**
1. Checkout PR 241 branch: `git checkout origin/241/branch`
2. Update `pkg/svc/zones/zones_test.go` — Update test function:
   ```go
   // In TestUpdate, add table-driven case:
   {
       name: "invalid_zone_name (ZONE-005)",
       setup: func(...) { /* mock agent returns ZONE-005 error */ },
       expectedStatus: codes.InvalidArgument,
   }
   ```
3. Update `pkg/svc/zones/zones_test.go` — Delete test function:
   ```go
   // In TestDelete, add table-driven case:
   {
       name: "invalid_zone_name (ZONE-005)",
       setup: func(...) { /* mock agent returns ZONE-005 error */ },
       expectedStatus: codes.InvalidArgument,
   }
   ```
4. Run `docker-compose up && make test && docker-compose down`
5. Verify coverage ≥80%
6. Commit: "DDIDNS-10543: add ZONE-005 test cases for Update/Delete paths"
7. Push to PR branch
8. CI runs, verify checks passing
9. Merge PR when ready

**Readiness:** 🟡 **Partial work — 95% complete, needs 1 gap fix**

---

### PR 6300: DDIDNS-10546 — DNS Config: Audit Logging

**Repo:** `Infoblox-CTO/ddi.dns.config`  
**Status:** DRAFT (created 2026-08-13)  
**Current Completion:** ~100%

#### AC Coverage Analysis

| AC | Description | Status | Evidence |
|---|---|---|---|
| **AC6** | Audit logs capture all actions (zone creation with scope detail) | ✅ Implemented | Audit log extended with replication_scope + target_server fields, tests verify |

#### Gap Details

**No gaps identified.** PR is complete:
- ✅ Audit schema extended for scope + target server
- ✅ Logging at zone creation points
- ✅ All scope values (local, domain, forest) captured
- ✅ Tests verify audit entries contain correct fields
- ✅ Code coverage: 78% (exceeds ≥75% threshold for dns.config)

#### Execution Plan

**Phase 1 (Planning - Done):** Assess PR, no gaps found  
**Phase 2 (Execution - Todo):**
1. Code review by toolkit reviewer agent
2. Run `docker-compose up && make test && docker-compose down`
3. Verify coverage ≥75% (already met)
4. Verify no lint/fmt issues
5. Merge PR when checks pass

**Readiness:** 🟢 **Complete work — ready for merge**

---

## PR Readiness Summary

| PR | Task | Gaps | Coverage | Readiness | Action |
|---|---|---|---|---|---|
| 507 | DDIDNS-10519 | 1 gap (Conditional Forwarder test) | 87% | 🟡 Partial (85%) | Add handler tests, re-verify |
| 508 | DDIDNS-10542 | None | 92% | 🟢 Complete | Ready to merge |
| 241 | DDIDNS-10543 | 1 gap (ZONE-005 in Update/Delete) | 85% | 🟡 Partial (95%) | Add test cases, re-verify |
| 6300 | DDIDNS-10546 | None | 78% | 🟢 Complete | Ready to merge |

---

## Execution Phase Workflow

**Overview:** Execution agents will complete gaps and merge PRs in this order:

```
Step 1: Complete PR 507 (Conditional Forwarder tests)
  └─ Checkout branch, add tests, push, merge when ready

Step 2: Complete PR 241 (ZONE-005 Update/Delete tests)
  └─ Checkout branch, add test cases, push, merge when ready

Step 3: Merge PR 508 (already complete)
  └─ Code review, merge

Step 4: Merge PR 6300 (already complete)
  └─ Code review, merge

Result: Phase 1 fully implemented and shipped
```

### Execution Checkpoints

**For PR 507:**
```
Pre-execution:
- [ ] Plan identifies gap (Conditional Forwarder tests missing)
- [ ] Planned fix is clear (add 2 handler test cases)

During execution:
- [ ] Agent checks out PR branch
- [ ] Agent adds test cases to interceptor_handlers_test.go
- [ ] Agent runs: docker-compose up && make test
- [ ] Agent verifies: coverage ≥80%, all tests green
- [ ] Agent commits: "DDIDNS-10519: add Conditional Forwarder handler tests"
- [ ] Agent pushes to PR branch
- [ ] CI runs on PR
- [ ] Agent verifies: checks passing

Post-execution:
- [ ] All gaps closed
- [ ] Coverage ≥80%
- [ ] Tests green
- [ ] Ready to merge
```

**For PR 241:**
```
Pre-execution:
- [ ] Plan identifies gap (ZONE-005 not tested in Update/Delete)
- [ ] Planned fix is clear (add table-driven test cases)

During execution:
- [ ] Agent checks out PR branch
- [ ] Agent adds test cases to zones_test.go (Update path)
- [ ] Agent adds test cases to zones_test.go (Delete path)
- [ ] Agent runs: docker-compose up && make test
- [ ] Agent verifies: coverage ≥80%, all tests green
- [ ] Agent commits: "DDIDNS-10543: add ZONE-005 test cases for Update/Delete"
- [ ] Agent pushes to PR branch
- [ ] CI runs on PR
- [ ] Agent verifies: checks passing

Post-execution:
- [ ] All gaps closed
- [ ] Coverage ≥80%
- [ ] Tests green
- [ ] Ready to merge
```

---

## Cross-Repo Coordination

### Merge Order & Dependencies

No hard dependencies between PRs:
- PR 507 + 508 (middleware) are independent
- PR 241 (collector) is independent
- PR 6300 (dns.config) is independent

**Recommended merge order:**
1. Complete PR 507 + 508 (middleware work)
2. Complete PR 241 (collector work)
3. Complete PR 6300 (audit logging)

**All can merge simultaneously if execution agents work in parallel.**

---

## Success Criteria

Phase 1 is complete when:

- ✅ PR 507: Conditional Forwarder scope validation tested, coverage ≥80%, merged
- ✅ PR 508: Idempotency tests passing, merged
- ✅ PR 241: ZONE-005 tested in Update/Delete paths, coverage ≥80%, merged
- ✅ PR 6300: Audit logging verified, merged

---

## Approval Gate

**Status:** Ready for execution phase

This plan identifies gaps in 4 existing PRs and plans fixes. Execution agents will:
1. Complete gap fixes (add missing tests)
2. Run full test suite
3. Verify quality meets toolkit standards
4. Merge PRs when ready

**Execution method:** Agents checkout PR branches, make commits, run tests, push, merge.

### Proceed with Execution?

- **Yes, proceed** — Execute agents will complete PRs per plan
- **No, need changes** — Specify modifications to the plan

Which is your call?
