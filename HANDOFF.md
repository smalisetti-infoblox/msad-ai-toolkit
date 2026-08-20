# Handoff: DDIDNS-7732 — Replication Scope Update (DDIDNS-10547 / DDIDNS-10566)

**Date:** 2026-08-20
**Status:** Blocked on design decisions — do not start `/msad-dev-planning DDIDNS-10547` until these are answered
**Owner:** unassigned

## Context

DDIDNS-7732 (Microsoft DNS zone creation with replication scope) has been executed for **zone creation** — see `specs/msad-dev-plans/2026-08-20-DDIDNS-10562-plan.md` (Story DDIDNS-10562, PRs [#507](https://github.com/Infoblox-CTO/ddi.cloud.proxy.middleware/pull/507) and [#617](https://github.com/Infoblox-CTO/ddi.msad.agent/pull/617), both ready for human review).

**Zone update** (changing replication scope on an *existing* zone) is a separate, explicitly-scoped-out exception, tracked as its own story:

- **Story DDIDNS-10566** — "Support changing replication scope on existing AD-integrated Microsoft DNS zones (backend + UI)"
  - **DDIDNS-10547** — Backend: allow changing replication scope on Microsoft DNS zone update (unassigned, To Do)
  - **DDIDNS-10548** — Portal UI: allow editing replication scope on existing zones (unassigned, To Do, 🚫 Frontend — blocked on DDIDNS-10547 landing first)

DDIDNS-7732's own description says: *"This story focuses specifically on zone creation and replication scope selection. It does not cover broader lifecycle operations."* Replication scope is currently a **deliberate write-once/immutable field** — enforced in code and documented in `site/content/architecture/service-architecture.md` ("Replication scope cannot be changed after creation"). DDIDNS-10566/10547 implement a DDIDNS-9464-approved exception to that rule.

## Why This Is Blocked

Unlike DDIDNS-10562 (creation), DDIDNS-10547 has **unresolved product/architecture design questions** that code inspection cannot answer — they require a decision from whoever owns the MSAD/AD architecture, not implementation work. Per the toolkit's gating rules, `/msad-dev-planning` will surface these as MUST/Blocking findings in its bounded review; better to resolve them here first so planning isn't wasted.

## Open Design Questions

### 1. Is "Update" even the right operation model?

Does Microsoft DNS actually support changing an AD-integrated zone's replication scope **in place**, or does changing scope require moving the zone to a different AD directory partition — i.e., a **migration**, not a simple property update?

- If it's a migration: "Update" may be the wrong verb/UX entirely. This affects the API shape, not just the implementation.
- **Needs verification against real Windows Server DNS/AD behavior** — this is not something that can be determined by reading the DDI/MSAD codebase; it requires either testing against a live AD environment or authoritative Microsoft documentation.

### 2. Which scope transitions are allowed?

E.g., Local→Domain, Domain→Forest, Forest→Domain, Domain→Local, etc.

- Are any of these transitions **irreversible**?
- Does the answer differ by zone type (Auth/Primary vs. Forward)?

### 3. Partial-failure / rollback behavior

If the scope change succeeds in AD but the DDI database write fails (or vice versa):

- Is rollback required, similar to the pattern the Forward zone's agent controller (`DnsConditionalForwarderZoneController`) **already implements for itself** (rollback to original scope on failure)?
- Should the same pattern be added to the Auth/Primary zone path once it's unblocked (see below)?

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

1. **Get Q1–Q3 answered** by whoever owns MSAD/AD architecture decisions (not a coding task — needs either live-AD testing or Microsoft documentation research, plus a product call on allowed transitions).
2. Once answered, run `/msad-dev-planning DDIDNS-10547` — the plan can now proceed without hitting these as Blocking findings, and can scope the first pass to Forward zones only (per the task's existing scope note) if that's still the agreed approach.
3. DDIDNS-10548 (Portal UI) stays blocked until DDIDNS-10547's backend contract is settled — do not start UI work in parallel, per the task's own dependency note.
4. Consider whether Q3's rollback pattern should be extracted into a shared helper now, since Auth/Primary will eventually need the same rollback logic Forward already has — worth deciding at planning time to avoid duplicating it later.

## References

- Epic structure plan: `specs/msad-epic-plans/2026-08-20-DDIDNS-7732-structure-plan.md`
- Completed sibling work (zone creation): `specs/msad-dev-plans/2026-08-20-DDIDNS-10562-plan.md`
- Topology + request-flow diagram (both DDI→MSAD write and MSAD→DDI sync directions): `references/repo-topology.md`
- Jira: [DDIDNS-10566](https://infoblox.atlassian.net/browse/DDIDNS-10566) (story), [DDIDNS-10547](https://infoblox.atlassian.net/browse/DDIDNS-10547) (backend task), [DDIDNS-10548](https://infoblox.atlassian.net/browse/DDIDNS-10548) (UI task)
