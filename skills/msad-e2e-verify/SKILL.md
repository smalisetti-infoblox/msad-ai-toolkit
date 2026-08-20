---
name: msad-e2e-verify
description: "End-to-end verification of any MSAD zone/record feature via API (without the Windows agent). Brings up the dns.config service with a mocked MSAD collector, drives zone/record create/update/delete flows via WAPI v3 for whatever feature is under test, and asserts on DB state and mocked collector calls. Reads the Gherkin scenarios from the task's dev plan to know what to test — not hardcoded to any one feature."
version: 0.2.0
created_by:
  name: Claude Code
  role: AI SDLC for MSAD epic
---

# MSAD E2E Verification

End-to-end verification skill for **any** MSAD zone/record feature at the API layer — replication scope, idempotency, error-code mapping, audit logging, zone-transfer settings, or anything else a story/task introduces. Since the Windows MSAD agent (`ddi.msad.agent`) cannot be executed or tested on Mac/Linux, this skill verifies as much of the flow as possible without it: WAPI v3 request → middleware interceptor → mocked MSAD collector gRPC boundary → DB persistence.

**This skill does not have a fixed set of test cases.** It derives what to test from the Gherkin scenarios in the governing dev plan (see `references/bdd-acceptance-criteria.md`) or from whatever the user describes. The worked examples in this doc (replication scope, idempotency) are illustrations of the pattern, not an exhaustive checklist to run every time.

## Scope & Limitations

### What This Skill Can Verify (for any feature)

- **Request construction:** the request under test is built correctly (whatever fields the feature adds/changes)
- **Middleware routing:** the interceptor routes MSAD-bound zones/records to the collector correctly
- **Validation logic:** allow-lists, required-field checks, and rejection paths behave as the feature's AC specifies
- **Error handling:** agent error codes (mocked as if from the collector) are correctly mapped to gRPC status codes
- **DB persistence:** the DDI table reflects the feature's data correctly after the request
- **Idempotency / duplicate handling:** pre-flight checks and rollback markers, when the feature involves them

### What This Skill CANNOT Verify

- **PowerShell cmdlet execution** (real `Add-DnsServerPrimaryZone`, `Set-DnsServerConditionalForwarderZone`, etc.)
- **Active Directory replication** (zone actually replicated across domain controllers)
- **Real MSAD collector responses** (behavior of the actual Windows RPC/LDAP bridge)

These gaps are verified via:
- Unit tests in each repo (xUnit for agent, table-driven for Go services)
- Windows CI: Jenkins `windows_node_ddi_msad_agent_label` node runs `dotnet test MSADAgent\Agent.Tests`
- Stage/prod testing: manual, tracked in the epic's QA stories (see the governing epic's structure plan for which QA tickets apply — don't assume a fixed set)

---

## Quick Collector-Level Testing via `cmd/testclient` (Alternative)

For **faster collector-only checks** without bringing up the full WAPI v3 + middleware stack, use the MSAD Collector's gRPC test client directly:

**When to use:**
- Verifying a new value, field, or error-code mapping at the collector level, for any feature
- Quick gRPC integration check during implementation (before e2e stack tests)
- Collector-proto changes that need validation before middleware regenerates

**Exact steps:** See `references/repo-topology.md` → "MSAD Collector Test Client (cmd/testclient)" section for setup, invocation examples, and flags.

---

## Prerequisites

1. **Local repos cloned:** `~/ddi.dns.config` and `~/ddi.cloud.proxy.middleware` (middleware is a library, included as a dependency in dns.config).
2. **Docker + docker-compose:** for PostgreSQL, Redis, and the dns.config service. Do NOT install PostgreSQL locally.
3. **Tools:** curl (or newman for Postman collections), jq, git, make.
4. **A feature to verify:** a Jira task/story ID with a governing dev plan (`specs/msad-dev-plans/*-plan.md`), or a plain-language description of the flow to test if no plan exists yet.

---

## Process

### Step 0: Identify What to Test

1. **If a Jira ID or plan path is given:** read the dev plan's Gherkin scenarios and Scenario→Test traceability table (see `references/bdd-acceptance-criteria.md`). Each scenario becomes one or more test cases in Step 2 — translate `Given/When/Then` into a request/assert pair.
2. **If no plan exists (ad-hoc verification):** ask the user which request fields, values, and expected outcomes to test. Don't guess a feature's allow-list or expected status codes.
3. **State what you're testing before proceeding:**
   > Step 0 — Verifying `<N>` scenarios from `<plan path or user description>`: `<one-line list of scenario names>`.

### Step 1: Setup (Docker-Based, Generic Regardless of Feature)

1. **Start all dependencies via docker-compose:**
   ```bash
   cd ~/ddi.dns.config
   docker-compose up -d           # starts PostgreSQL, Redis, service, etc.
   ```
   Wait a few seconds for services to become healthy:
   ```bash
   sleep 5 && docker-compose logs postgres | tail -5
   ```

2. **Confirm the dns.config service is running:**
   ```bash
   curl -s http://localhost:8080/health | jq .
   ```
   If the service fails to start, check logs: `docker-compose logs dns-config` (or the actual service name in docker-compose.yml).

3. **Identify the WAPI v3 endpoint** (usually `http://localhost:8080/api/v3/...` — check docker-compose.yml or the Makefile for the exact port).

4. **Provision a test account/view/JWT** (existing `k6/` fixtures should populate these; otherwise create manually):
   ```bash
   JWT=$(curl -s -X POST http://localhost:8080/auth/login -d '{"user":"test","pass":"test"}' | jq -r .token)
   ACCOUNT_ID=$(curl -s -H "Authorization: Bearer $JWT" http://localhost:8080/api/v3/accounts | jq -r '.[] | select(.name == "test-account") | .id')
   VIEW_ID=$(curl -s -H "Authorization: Bearer $JWT" http://localhost:8080/api/v3/views | jq -r '.[] | select(.name == "test-view") | .id')
   ```

5. **Verify the middleware's mocked MSAD collector is enabled:** `CloudProxyHandler` should be wired to `pkg/mocks.MockCloudProxyClient` in test mode, not dialing a real remote service.

**Cleanup after testing:** `docker-compose down`

State:
> Step 1 — Setup complete. dns.config running at `<endpoint>`. Test account: `<account-id>`, view: `<view-id>`.

### Step 2: Run Test Cases Derived From Step 0's Scenarios

For **each** scenario identified in Step 0, construct a request/assert pair:

1. **Map the scenario's `Given` to request fields** (whatever the feature's request shape requires — not limited to any particular field).
2. **Send the request** (`POST`/`PATCH`/`DELETE` per the scenario's `When`).
3. **Assert per the scenario's `Then`:**
   - HTTP response status and body match the expected outcome
   - Relevant DDI table row(s) reflect the expected state (only check the fields the feature actually touches)
   - Mocked collector received the expected call (via logs or a spy/mock assertion), if the feature reaches the collector

State per case:
> Test case `<name>`: `<pass/fail>` — `<one-line reason if fail>`.

State after all cases:
> Step 2 — `<N>` test cases executed, `<P>` passed, `<F>` failed.

### Step 3: Data Model & DB Verification

Spot-check the DDI DB for whatever table(s) the feature touches (usually `zones`, sometimes `records` or an audit table):

```bash
SELECT id, name, zone_type, <feature-relevant-columns>, account_id, view_id
  FROM zones
  WHERE name LIKE '%.test.com'
  ORDER BY created_at DESC;
```

Verify only the columns relevant to the feature under test — don't assert on unrelated fields.

State:
> Step 3 — DB: `<N>` test rows created/updated. Feature-relevant fields correct. No orphans.

### Step 4: Middleware Logging & Mocked Collector Assertions

If the feature reaches the collector, inspect middleware logs / mock collector call captures to confirm the request was routed and transmitted correctly (field values unchanged, error codes mapped correctly if the scenario tests an error path).

State:
> Step 4 — Request flow verified. Middleware correctly routed `<N>` requests to mocked collector.

### Step 5: Cleanup & Documentation

1. `docker-compose down`
2. Document results: which scenarios passed/failed, anything deferred/blocked, link this verification as evidence in the PR body (see template below).

State:
> Step 5 — Cleanup done. E2E verification complete.

---

## Worked Examples (Illustrations of the Pattern, Not a Fixed Checklist)

### Example 1: Replication Scope (DDIDNS-10562)

Scenarios from that story's dev plan: accept `domain`/`forest` on Auth/Forward creation, reject `legacy` at creation, persist scope correctly.

```bash
# Accept domain scope
POST /api/v3/zones
{ "name": "domain.test.com", "zone_type": "primary_auth", "replication_scope": "domain", "view_id": "$VIEW_ID", "account_id": "$ACCOUNT_ID" }
# Expected: HTTP 201, DB row replication_scope="domain", collector Create called with domain

# Reject legacy scope
POST /api/v3/zones
{ "name": "invalid.test.com", "zone_type": "primary_auth", "replication_scope": "legacy", "view_id": "$VIEW_ID", "account_id": "$ACCOUNT_ID" }
# Expected: HTTP 400/422, zone NOT created, blocked before calling collector
```

### Example 2: Idempotency / Duplicate Prevention (DDIDNS-10542)

Scenario: a duplicate zone-creation attempt must not orphan an AD-side zone.

```bash
# First create succeeds
POST /api/v3/zones
{ "name": "dup.test.com", "zone_type": "primary_auth", "replication_scope": "local", ... }
# Expected: HTTP 201

# Second create with same name/account/view
POST /api/v3/zones
{ "name": "dup.test.com", "zone_type": "primary_auth", "replication_scope": "local", ... }
# Expected: HTTP 409 (or codes.AlreadyExists), fails before calling collector, DB still has exactly one row
```

### Example 3: Error-Code Mapping (any feature that surfaces agent errors)

```bash
# Inject a mocked collector error (e.g. ZONE-001 "zone already exists") and confirm translation
POST /api/v3/zones
{ "name": "error-test.com", ... }
# Expected: HTTP 409 (gRPC codes.AlreadyExists), error message includes agent error detail
```

These three examples show the pattern: **Given/When/Then from the plan → request → assert on status + DB + collector call.** Apply the same pattern to whatever feature you're actually verifying.

---

## Automation

Wrap Step 2's cases in a shell script or k6 test file for repeatability. Parameterize by scenario rather than hardcoding any one feature's values:

```bash
#!/bin/bash
set -e
JWT=$(...)
ACCOUNT_ID=$(...)
VIEW_ID=$(...)
ENDPOINT="http://localhost:8080/api/v3"

run_case() {
  local name="$1" method="$2" path="$3" body="$4" expected_status="$5"
  echo "Test case: $name"
  status=$(curl -s -o /tmp/resp.json -w "%{http_code}" -X "$method" "$ENDPOINT$path" \
    -H "Authorization: Bearer $JWT" -H "Content-Type: application/json" -d "$body")
  [ "$status" = "$expected_status" ] && echo "  PASS ($status)" || echo "  FAIL (got $status, want $expected_status)"
}

# Add one run_case call per scenario from Step 0 — do not hardcode a fixed list here.
```

Extend the existing `k6/auth_zone.js` pattern similarly, adding one `check()` block per scenario under test.

---

## Known Gaps & Deferral (Environment Limitations, Not Feature-Specific)

| Aspect | Status | Why | Verified By |
|---|---|---|---|
| PowerShell cmdlet execution | ❌ Deferred | Windows-only; no Mac/Linux equivalent | Windows CI (Jenkins `windows_node_ddi_msad_agent_label`) + unit tests (xUnit in MSADAgent/Agent.Tests) |
| Real AD replication | ❌ Deferred | Requires live AD environment | Stage/prod testing (see the epic's QA stories) |
| Real MSAD collector RPC | ❌ Deferred | ddi.msadconnect.proxy unreachable from test env | Unit tests in collector + integration tests in dns.config |
| Actual zone creation in AD | ❌ Deferred | Requires real MSAD agent + AD | Windows CI + stage testing |

All deferred aspects are **covered by other verification layers** (unit tests, Windows CI, stage testing) regardless of which feature is under test — this gap is **not a blocker**.

---

## Integration with PR Workflow

Include this skill's verification in the PR body, listing the actual scenarios tested (not a fixed template):

```markdown
## E2E Verification

- [x] <Scenario 1 name>: pass
- [x] <Scenario 2 name>: pass
- [ ] <Scenario 3 name>: deferred — <reason>

**Deferred:** real MSAD agent/AD replication (Windows CI + stage testing; tracked in <QA ticket IDs from this epic>).
```

---

## Error Handling

- **docker-compose up fails:** check dns.config's Makefile or README for setup requirements (e.g., postgres running, env vars). Mark deferred if Docker unavailable.
- **JWT/account/view creation fails:** use fixtures from `k6/` or create manually via admin API.
- **WAPI v3 endpoint not found:** check dns.config's service port in docker-compose.yml or logs.
- **Mocked collector not wired:** confirm middleware is using `pkg/mocks.MockCloudProxyClient` in test mode (check dns.config's integration test setup).
- **No dev plan found for the feature:** ask the user directly which fields/values/expected outcomes to test — don't invent scenarios.
- **Test fails unexpectedly:** run the single failing case with verbose logging; check middleware + dns.config logs for error details.
