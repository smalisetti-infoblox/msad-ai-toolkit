# Handoff: DDIDNS-7732 — Replication Scope Update (DDIDNS-10547 / DDIDNS-10566)

**Date:** 2026-08-20 (updated 2026-08-20: Q2 partially resolved, unblocked for Forward-zone first pass)
**Status:** Unblocked for Forward zones (this pass's actual scope). Auth/Primary remain blocked on Q1/Q3.
**Owner:** unassigned

## Context

DDIDNS-7732 (Microsoft DNS zone creation with replication scope) has been executed for **zone creation** — see `specs/msad-dev-plans/2026-08-20-DDIDNS-10562-plan.md` (Story DDIDNS-10562, PRs [#507](https://github.com/Infoblox-CTO/ddi.cloud.proxy.middleware/pull/507) and [#617](https://github.com/Infoblox-CTO/ddi.msad.agent/pull/617), both ready for human review).

**Zone update** (changing replication scope on an *existing* zone) is a separate, explicitly-scoped-out exception, tracked as its own story:

- **Story DDIDNS-10566** — "Support changing replication scope on existing AD-integrated Microsoft DNS zones (backend + UI)"
  - **DDIDNS-10547** — Backend: allow changing replication scope on Microsoft DNS zone update (unassigned, To Do)
  - **DDIDNS-10548** — Portal UI: allow editing replication scope on existing zones (unassigned, To Do, 🚫 Frontend — blocked on DDIDNS-10547 landing first)

DDIDNS-7732's own description says: *"This story focuses specifically on zone creation and replication scope selection. It does not cover broader lifecycle operations."* Replication scope is currently a **deliberate write-once/immutable field** — enforced in code and documented in `site/content/architecture/service-architecture.md` ("Replication scope cannot be changed after creation"). DDIDNS-10566/10547 implement a DDIDNS-9464-approved exception to that rule.

## Why This Was Blocked (and Why It's Now Unblocked for Forward Zones)

Unlike DDIDNS-10562 (creation), DDIDNS-10547 had unresolved product/architecture design questions that code inspection couldn't answer. Q2 has now been **partially resolved by decision** (see below), and it turns out the two questions that remain fully open (Q1, Q3) only matter for **Auth/Primary zones**, which DDIDNS-10547's own task description already scopes *out* of this first pass. Forward zones — the actual scope of this pass — already have a complete, working, rollback-safe agent-side implementation. So planning can proceed now for Forward zones without hitting Q1/Q3 as Blocking findings.

## Resolved: Legacy Scope Handling (2026-08-20)

**Decision:** `legacy` replication scope may only ever be **synced in** (via `cq-source-msad`/`cloud.discovery`, the MSAD→DDI read path — see `references/repo-topology.md`'s Direction 2 diagram). It can **never** be set via **creation** (already enforced, DDIDNS-10562) or **update** (new — applies to this task).

**Implementation requirement — keep this a single, easily-changeable point of truth:** the Update-path replication-scope allow-list must exclude `legacy`, exactly mirroring the Create-path allow-list (`local`/`domain`/`forest` only). Concretely:

- In `ddi.cloud.proxy.middleware`, whatever allow-list constant/function gates the new Update-path scope-change logic should reuse or exactly mirror `isValidMSADReplicationScopeForZoneCreate()` (the Create-path validator from DDIDNS-10519/PR #507) — do not introduce a second, independently-maintained list of allowed values. If Create and Update ever need to diverge (e.g., a future exception), that should require an explicit, visible change to a single named constant/list, not scattered literals.
- Same principle in `ddi.msad.agent`: `IsValidReplicationScopeValue()` (fixed for Create in DDIDNS-10521/PR #617 to exclude `legacy`) should be reused for the Update path's *new-target-value* validation too, if `/msad-dev-planning` determines the Update path needs its own allow-list check distinct from the existing write-once block being relaxed. **Do not confuse this with the existing separate Update allow-list at `DnsZoneRequestHandler.cs:509-518`, which validates the *unchanged* scope on non-scope-changing updates and correctly still includes `legacy`** (needed for idempotent reconciliation of already-synced legacy zones, per DDIDNS-10562's plan) — that one must NOT be touched by this task. This task only concerns validating a *new, user-requested* target scope on a scope-change-on-update request, which must reject `legacy` as a target regardless of the zone's current scope.

**Why "easily changeable":** if this decision changes later (e.g., product decides legacy zones should be re-classifiable to local/domain/forest via update, or vice versa), the fix should be a one-line edit to the shared allow-list, not a hunt through multiple call sites.

## Open Design Questions (Now Scoped to Auth/Primary Only — Not Blocking Forward)

### 1. Is "Update" even the right operation model for Auth/Primary zones?

Does Microsoft DNS actually support changing an AD-integrated **Primary** zone's replication scope **in place**, or does it require moving the zone to a different AD directory partition — i.e., a **migration**, not a simple property update?

- **Forward zones are unaffected by this question** — the agent's `DnsConditionalForwarderZoneController` already does this successfully via `Set-DnsServerConditionalForwarderZone -ReplicationScope`, proving in-place update works for that zone type.
- Still needs verification against real Windows Server DNS/AD behavior before Auth/Primary zone support is attempted in a future pass.

### 2. Which scope transitions are allowed? — Partially resolved

- **Resolved:** no transition may target `legacy` (see above). This applies to both zone types once each is in scope.
- **Still open:** are all of Local↔Domain↔Forest transitions allowed, or are some one-way/irreversible? This can be answered during `/msad-dev-planning DDIDNS-10547` as a scoped clarifying question if needed — it's a narrower question now than the original Q2, and may have an obvious answer once the middleware/agent code is inspected for existing transition logic.

### 3. Partial-failure / rollback behavior for Auth/Primary zones

**Forward zones already have this answered** — `DnsConditionalForwarderZoneController` rolls back to the original scope on failure today; DDIDNS-10547 should ensure the middleware-side change for Forward zones doesn't disturb that.

**Still open for Auth/Primary:** whether the same rollback pattern needs to be built when that zone type is unblocked in a future pass (post-Q1).

## Current Code State (verified 2026-08-20)

| Zone Type | Middleware (ddi.cloud.proxy.middleware) | Agent (ddi.msad.agent) |
|---|---|---|
| **Auth/Primary** | Blocks **any** scope change via strict equality check — `pkg/interceptor_handlers.go:1261` (`existingZoneEPMD.MSADConfig.ReplicationScope != zoneEPMD.MSADConfig.ReplicationScope` → `errCannotUpdateReplicationScope`) | `DnsPrimaryZoneController.Update` has the actual `Set-DnsServerPrimaryZone -ReplicationScope` call **present but commented out** ("Commented for future use" — dead code) |
| **Forward** | Same middleware-side block — `pkg/interceptor_handlers.go:2280` | `DnsConditionalForwarderZoneController` already has a **complete, working implementation** via `Set-DnsServerConditionalForwarderZone -ReplicationScope`, **including rollback** to the original scope on failure |
| **Secondary** | N/A — Microsoft DNS secondary zones have no replication-scope concept | `DnsSecondaryZoneController` explicitly rejects scope changes — correct, no change needed |
| **Stub** | Explicitly out of scope per DDIDNS-7732 (stub zones excluded from this epic entirely) | `DnsStubZoneController` explicitly rejects scope changes — correct, no change needed unless a separate stub-zone story revisits this |

**Key implication:** Forward zones are much closer to ready — the agent-side implementation already exists and works (with rollback). Auth/Primary zones need the agent-side RPC call uncommented and completed **after** the "in-place vs. migration" question (Q1) is resolved, since that answer determines whether the existing commented-out call is even the right approach.

**DDIDNS-10547's task description already narrows scope for a first pass:** implement scope-change-on-update for **Forward zones only** in this iteration; Auth/Primary zones remain write-once-blocked until the agent-side work and Q1 are resolved.

## Recommended Next Steps

1. **Run `/msad-dev-planning DDIDNS-10547` now**, scoped to Forward zones only (per the task's existing scope note) — no longer blocked. The plan should explicitly encode the legacy-exclusion decision above using a single shared allow-list, and may surface the Local↔Domain↔Forest transition question (remaining part of Q2) as a scoped clarifying question if the code doesn't already make it obvious.
2. DDIDNS-10548 (Portal UI) stays blocked until DDIDNS-10547's backend contract is settled — do not start UI work in parallel, per the task's own dependency note.
3. **Auth/Primary zone support is a separate, still-blocked future pass** — Q1 (in-place vs. migration) and Q3 (rollback for that zone type) remain open and need whoever owns MSAD/AD architecture decisions (live-AD testing or Microsoft documentation research) before that work can be planned.
4. When Auth/Primary zone support is eventually planned, consider extracting Forward's rollback pattern into a shared helper first, so Auth/Primary can reuse it rather than duplicating it.

## References

- Epic structure plan: `specs/msad-epic-plans/2026-08-20-DDIDNS-7732-structure-plan.md`
- Completed sibling work (zone creation): `specs/msad-dev-plans/2026-08-20-DDIDNS-10562-plan.md`
- Topology + request-flow diagram (both DDI→MSAD write and MSAD→DDI sync directions): `references/repo-topology.md`
- Jira: [DDIDNS-10566](https://infoblox.atlassian.net/browse/DDIDNS-10566) (story), [DDIDNS-10547](https://infoblox.atlassian.net/browse/DDIDNS-10547) (backend task), [DDIDNS-10548](https://infoblox.atlassian.net/browse/DDIDNS-10548) (UI task)
