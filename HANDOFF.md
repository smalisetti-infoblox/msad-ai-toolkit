# Handoff: DDIDNS-7732 — Replication Scope Update (DDIDNS-10547 / DDIDNS-10566)

**Date:** 2026-08-20 (superseded prior version — corrected a factual error and recorded scope-expansion decisions)
**Status:** Unblocked for ALL zone types (Auth/Primary + Forward). All three original open questions now resolved by explicit decision.
**Owner:** unassigned

## Context

DDIDNS-7732 (Microsoft DNS zone creation with replication scope) has been executed for **zone creation** — see `specs/msad-dev-plans/2026-08-20-DDIDNS-10562-plan.md` (Story DDIDNS-10562, PRs [#507](https://github.com/Infoblox-CTO/ddi.cloud.proxy.middleware/pull/507) and [#617](https://github.com/Infoblox-CTO/ddi.msad.agent/pull/617), both ready for human review).

**Zone update** (changing replication scope on an *existing* zone) is a separate, DDIDNS-9464-approved exception to DDIDNS-7732's write-once rule, tracked as its own story:

- **Story DDIDNS-10566** — "Support changing replication scope on existing AD-integrated Microsoft DNS zones (backend + UI)"
  - **DDIDNS-10547** — Backend: allow changing replication scope on Microsoft DNS zone update (unassigned, To Do) — **scope expanded 2026-08-20 to cover Auth/Primary zones, not just Forward zones (see decisions below)**
  - **DDIDNS-10548** — Portal UI: allow editing replication scope on existing zones (unassigned, To Do, 🚫 Frontend — blocked on DDIDNS-10547 landing first)

## Correction: Forward Zone's Agent-Side Was NOT Already Complete

Earlier versions of this document (and the original DDIDNS-10547/10521 Jira task descriptions) claimed **`DnsConditionalForwarderZoneController` already has a complete, working implementation with rollback**. This was **wrong** — verified by reading the actual current code, not the ticket description:

- The scope-change PowerShell call (`Set-DnsServerConditionalForwarderZone -ReplicationScope`) in `DnsConditionalForwarderZoneController.Update` is **commented out** ("Commenting for future use as we are not updating zone replication scope as of now") — dead code, exactly like Primary zone's.
- The rollback block is **also commented out**, and — worse — **it references the wrong cmdlet**: `Set-DnsServerForwarder` instead of `Set-DnsServerConditionalForwarderZone`. Simply uncommenting it as-is would ship a rollback that doesn't actually revert the zone's scope.

**Implication:** both `DnsPrimaryZoneController.Update` and `DnsConditionalForwarderZoneController.Update` need real new work on the agent side — this is not a middleware-only task.

## Resolved Decisions (2026-08-20)

### Decision 1: Scope now covers all zone types, not Forward-only

Originally scoped to Forward zones only, deferring Auth/Primary pending Q1 (in-place update vs. AD migration) and Q3 (rollback design). **User decision: implement all zone types now** rather than deferring Auth/Primary to a future pass. Rationale given: proceed pragmatically — `Set-DnsServerPrimaryZone -ReplicationScope` is a documented, first-class Microsoft cmdlet parameter; treat it as supported and validate correctness via our own test suite rather than blocking on separate live-AD verification.

### Decision 2: Legacy scope handling (unchanged from prior version of this doc)

`legacy` replication scope may only ever be **synced in** (via `cq-source-msad`/`cloud.discovery`, the MSAD→DDI read path — see `references/repo-topology.md`'s Direction 2 diagram). It can **never** be set via **creation** (already enforced, DDIDNS-10562) or **update** (this task). The Update-path allow-list for a new target scope must exclude `legacy`, reusing the same shared allow-list as the Create path — not a separately-maintained list. **Do not confuse this with the existing, correct `IsValidUpdateDnsZoneRequest` allow-list in `DnsZoneRequestHandler.cs`, which validates the *unchanged* scope on non-scope-changing updates and correctly still includes `legacy`** — that one is untouched by this task.

### Decision 3: No zone-type-specific transition restrictions (local↔domain/forest allowed uniformly)

Primary zone's original (commented-out) code had a stricter guard than Forward zone's: it explicitly threw an exception for any transition involving `local` ("delete and recreate a zone to change its replication scope" instead of updating in place) — reflecting that converting between file-backed (Local) and AD-integrated (Domain/Forest) storage is a materially different operation than moving between AD directory partitions, which is what `-ReplicationScope` on Update is designed for. Forward zone's validator (PR #511) does not have this restriction and already tests `domain→local` and `forest→domain` transitions as valid.

**User decision: drop the local-exclusion for Primary zones too — allow all scope transitions uniformly across zone types, using one shared allow-list.** This is explicitly acknowledged as the higher-risk option (it removes a caution a previous engineer deliberately wrote into dead code, without new evidence that it's safe for Primary zones specifically) — recorded here for traceability, not silently done. If this proves wrong in practice (e.g., real AD environments reject or mishandle `local`-involving Update transitions for Primary zones), the fix is to reintroduce the guard at a single shared validation point, not scattered checks.

## Current Code State (re-verified 2026-08-20, corrected)

| Zone Type | Middleware (ddi.cloud.proxy.middleware) | Agent (ddi.msad.agent) |
|---|---|---|
| **Auth/Primary** | PR #511 already relaxes the write-once block for Auth zones too (allow-list validated, `local`/`domain`/`forest`, rejects `legacy`) — this was originally treated as an out-of-scope regression but is now **correctly in scope** per Decision 1 | `DnsPrimaryZoneController.Update` has the `Set-DnsServerPrimaryZone -ReplicationScope` call **present but commented out** (dead code); the original local-exclusion guard (also commented) is being **dropped**, not restored, per Decision 3; **no rollback exists at all** — must be written fresh, mirroring Forward's pattern (once fixed) |
| **Forward** | PR #511 relaxes the write-once block, allow-list validated, tested (domain→local, forest→domain, legacy-rejection) | `DnsConditionalForwarderZoneController.Update`'s scope-change call **and its rollback block are both commented out, and the rollback references the wrong cmdlet** (`Set-DnsServerForwarder` instead of `Set-DnsServerConditionalForwarderZone`) — needs real fix, not just uncommenting |
| **Secondary** | N/A — Microsoft DNS secondary zones have no replication-scope concept | `DnsSecondaryZoneController` explicitly rejects scope changes — correct, no change needed |
| **Stub** | Explicitly out of scope per DDIDNS-7732 (stub zones excluded from this epic entirely) | `DnsStubZoneController` explicitly rejects scope changes — correct, no change needed unless a separate stub-zone story revisits this |

## Recommended Next Steps

1. Plan DDIDNS-10547 covering: (a) middleware — keep PR #511 as-is for both zone types, just correct its description (Auth zone change is now intentional, not a bug); (b) agent — new work in both `DnsPrimaryZoneController.Update` and `DnsConditionalForwarderZoneController.Update`: uncomment/fix the scope-change PowerShell calls, write correct rollback logic (fixing the wrong-cmdlet bug in Forward's dead code), add legacy-target rejection, and drop (not restore) the local-exclusion guard.
2. Update DDIDNS-10547's Jira description to reflect the actual, now-expanded scope (all zone types, not "Forward only, Auth deferred").
3. DDIDNS-10548 (Portal UI) stays blocked until DDIDNS-10547's backend contract is settled.
4. If real-world testing later reveals the local-exclusion guard was actually necessary for Primary zones (Decision 3's risk), reintroduce it at the single shared validation point — don't scatter the fix.

## References

- Epic structure plan: `specs/msad-epic-plans/2026-08-20-DDIDNS-7732-structure-plan.md`
- Completed sibling work (zone creation): `specs/msad-dev-plans/2026-08-20-DDIDNS-10562-plan.md`
- This task's dev plan: `specs/msad-dev-plans/2026-08-20-DDIDNS-10547-plan.md`
- Topology + request-flow diagram (both DDI→MSAD write and MSAD→DDI sync directions): `references/repo-topology.md`
- Jira: [DDIDNS-10566](https://infoblox.atlassian.net/browse/DDIDNS-10566) (story), [DDIDNS-10547](https://infoblox.atlassian.net/browse/DDIDNS-10547) (backend task), [DDIDNS-10548](https://infoblox.atlassian.net/browse/DDIDNS-10548) (UI task)
