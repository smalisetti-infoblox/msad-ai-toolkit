# DDIDNS-7732 Planning Context

**Date:** 2026-08-13  
**Epic:** DDIDNS-7732 — Microsoft DNS zone creation with replication scope  
**Status:** Implementing → Phase 1 backend work (To Do)  

---

## Epic Overview

**Summary:** Enable Infoblox Cloud Portal to create Microsoft DNS zones with AD-integrated replication scopes (Domain, Forest).

**Scope:**
- ✅ Zone creation with Local / Domain / Forest replication scope
- ✅ Replication scope validation across stack
- ✅ Error handling, idempotency, audit logging
- ❌ Zone updates/scope changes (Phase 2, DDIDNS-10547 / DDIDNS-10548)
- ❌ Zone transfers, SOA, DNSSEC, stub zones

**Acceptance Criteria (Epic Level):**
1. User can create Local zones
2. User can create Domain-replicated zones
3. User can create Forest-replicated zones
4. Replication scope correctly applied in Microsoft DNS
5. Portal displays replication scope
6. Audit logs capture all actions

---

## Phase 1: Zone Creation (Active)

### Backend Story: DDIDNS-10562

**Status:** To Do (not yet started)

**Scope:**
- Middleware accepts domain/forest scope values
- Agent validates and applies replication scope
- Invalid scopes rejected with clear errors
- Auth and Forward zone types support new scopes

**Linked Tasks:**
- DDIDNS-10519 — Middleware support (relates)
- DDIDNS-10521 — Agent validation (relates)

### Existing Draft PRs (Discovery)

**4 PRs currently in flight (draft, awaiting completion):**

| PR | Task | Repo | Status | Gap |
|---|---|---|---|---|
| 507 | DDIDNS-10519 | ddi.cloud.proxy.middleware | DRAFT | Missing Conditional Forwarder handler tests (Coverage: 87% → 92.3%) |
| 508 | DDIDNS-10542 | ddi.cloud.proxy.middleware | DRAFT | Idempotency: prevent orphaned zones (Complete) |
| 241 | DDIDNS-10543 | ddi.msad.collector | DRAFT | Missing ZONE-005 error code test cases (Coverage: 85% → 92.1%) |
| 6300 | DDIDNS-10546 | ddi.dns.config | DRAFT | Audit logging for replication scope (Complete) |

**Author:** smalisetti-infoblox (draft branches: `DDIDNS-10519`, `DDIDNS-10542`, `DDIDNS-10543`, `DDIDNS-10546`)

**Key Observation:** All 4 PRs exist and are in draft state. They represent partial work on Phase 1 backend implementation.

### Tasks Not Yet Started

| Task | Title | Status | Work |
|---|---|---|---|
| DDIDNS-10521 | Agent validation for replication scope | None | Implement scope validation in DnsPrimaryZoneController.cs |
| DDIDNS-10544 | Portal UI selector for replication scope | None | Add dropdown to zone creation form |
| DDIDNS-10541 | E2E verification tests | None | Drive zone creation with domain/forest scopes via WAPI v3 |

---

## Phase 2: Zone Updates (Deferred)

**Status:** To Do / not started

**Scope:** Allow changing replication scope on existing AD-integrated zones

| Task | Title | Repo | Status |
|---|---|---|---|
| DDIDNS-10547 | Backend: allow scope change | ddi.dns.config | None |
| DDIDNS-10548 | Portal UI: scope change UI | Portal | None |
| DDIDNS-10566 | Support scope change | Epic | To Do |

---

## Cross-Repo Dependency Map

### Proto & Generated Code
- **Collector proto:** `ddi.msad.collector/api/protobuf-spec/service.proto` (13 services)
- **Middleware consumer:** `ddi.cloud.proxy.middleware/pkg/pb/` (vendored, regenerate via `make protobuf`)
- **Status:** No proto changes needed for Phase 1 (scope values already supported)

### Replication-Scope Validation (Must Stay Synchronized)
- **ddi.dns.config:** `pkg/service/application/stub_zone.go:validateStubZoneReplicationScopeNotLegacy()`
- **ddi.cloud.proxy.middleware:** `pkg/msad_zone_helper.go:isValidMSADReplicationScopeForZoneCreate()`
- **ddi.msad.agent:** DnsPrimaryZoneController.cs (validation currently missing)
- **Pattern:** All three must allow `local`/`domain`/`forest`, reject `legacy`

### Error-Code Mapping (Task DDIDNS-10543)
- **ddi.msad.collector:** `pkg/util/util.go:ErrorCodeToStatus()` (ZONE-005 mapping)
- **PR 241 in flight:** Adds error code test cases
- **Status:** Needs completion before merge

### Request Flow Validation
```
WAPI v3 (dns.config)
  ↓ validates scope → {local, domain, forest}
Cloud Proxy Middleware (ddi.cloud.proxy.middleware)
  ↓ mirrors validation
MSAD Collector (ddi.msad.collector)
  ↓ maps error codes (ZONE-005 → status)
MSAD Agent (ddi.msad.agent)
  ↓ validates scope → PowerShell -ReplicationScope arg
Add-DnsServerPrimaryZone / Set-DnsServerPrimaryZone
```

---

## Repository Build/Test Commands

| Repo | Build | Test | Lint |
|---|---|---|---|
| ddi.dns.config | `make vendor` | `make test` (Docker) | `make lint` |
| ddi.cloud.proxy.middleware | `make vendor` | `make test` (Docker) | `make lint` |
| ddi.msad.collector | `make vendor` | `make test` (Docker) | `make lint`, `nilaway` |
| ddi.msadconnect.proxy | `make vendor` | `make test` (Docker) | `make lint` |
| ddi.msad.agent | `dotnet build MSADAgent\MSADAgent.sln` | `dotnet test MSADAgent\Agent.Tests` | (Windows only) |

**Coverage Thresholds:**
- Go repos: ≥80% new code, ≥75% overall
- C# repos: ≥75% new code, ≥70% overall

---

## Existing PR Analysis (from prior simulation)

### PR 507 (DDIDNS-10519) — Middleware Scope Support
**Status:** Partial (85% complete)  
**Gap:** Conditional Forwarder handler tests missing  
**Fix:** Add 2 handler test functions → Coverage 87% → 92.3%  
**Time (simulation):** 8m 24s  

### PR 508 (DDIDNS-10542) — Idempotency
**Status:** Complete (100%)  
**Gap:** None  
**Action:** Code review + merge  
**Time (simulation):** 3m 15s  

### PR 241 (DDIDNS-10543) — Collector Error Mapping
**Status:** Partial (95% complete)  
**Gap:** ZONE-005 test cases missing in Update/Delete paths  
**Fix:** Add test cases → Coverage 85% → 92.1%  
**Time (simulation):** 9m 27s  

### PR 6300 (DDIDNS-10546) — Audit Logging
**Status:** Complete (100%)  
**Gap:** None  
**Action:** Code review + merge  
**Time (simulation):** 3m 45s  

**Total simulation time:** ~25 minutes for all 4 PRs

---

## Decision Points for User

### Option A: Complete Existing PRs (Recommended)
- Use msad-dev-execution agent to close gaps in PR 507 & 241
- Review and merge PR 508 & 6300
- Total time: ~25 minutes (per simulation)
- Outcome: 4/4 PRs merged, Phase 1 backend ~80% complete

### Option B: Start Fresh
- Abandon draft PRs
- Reimplement from scratch across all 5 repos
- Creates merge conflicts with existing branches
- Not recommended unless PRs are fundamentally broken

### Option C: Manual Review
- Review each PR manually in GitHub
- Complete gaps by hand (following PR-GAP-HANDLING.md guide)
- Slower, but gives full control

### Option D: Continue Planning Only
- Generate comprehensive plan without executing
- Defer execution to later
- Useful for alignment with team before proceeding

---

## Clarifying Questions for User

1. **Proceed with execution on existing PRs?** (Option A recommended)
2. **Which phase to focus on?** (Phase 1 backend is active; Phase 2 is deferred)
3. **Include Portal UI work (DDIDNS-10544)?** (Currently not started)
4. **Include E2E verification (DDIDNS-10541)?** (Currently not started)

---

## Next Steps

**If proceeding with Option A:**
1. Invoke `/msad-dev-execution` with plan file containing the 4 existing PRs
2. Agent completes gaps, runs tests, merges PRs
3. Remaining Phase 1 tasks (UI, E2E, agent validation) handled separately

**If proceeding with Option D (plan only):**
1. Continue to Step 3 (Repo Context) for full gap analysis
2. Generate comprehensive phase-based plan
3. Present for user approval before execution

---

**Current Context:** Steps 1–2 complete. Awaiting user decision on next phase.
