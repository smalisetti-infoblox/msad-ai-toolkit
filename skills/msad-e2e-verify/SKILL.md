---
name: msad-e2e-verify
description: "End-to-end verification of MSAD zone operations via API (without the Windows agent). Brings up the dns.config service with mocked MSAD collector, drives zone create/update/delete flows via WAPI v3, verifies replication-scope handling, and asserts on DB state and mocked responses. Use to validate replication-scope logic end-to-end at the API layer."
version: 0.1.0
created_by:
  name: Claude Code
  role: AI SDLC for MSAD epic
---

# MSAD E2E Verification

End-to-end verification skill for MSAD zone operations at the API layer. Since the Windows MSAD agent (`ddi.msad.agent`) cannot be executed or tested on Mac/Linux, this skill verifies replication-scope logic and error handling as far as possible: WAPI v3 zone creation → middleware interceptor → mocked MSAD collector gRPC boundary.

## Scope & Limitations

### What This Skill Can Verify

- **Request construction:** zone create/update requests with replication-scope parameters are built correctly
- **Middleware routing:** the interceptor correctly routes MSAD-bound zones to the collector
- **Scope validation:** replication-scope allow-list is enforced (reject `legacy`, accept `local`/`domain`/`forest`)
- **Error handling:** agent error codes (mocked as if from the collector) are correctly mapped to gRPC status codes
- **DB persistence:** DDI zone table reflects the replication scope and other metadata correctly
- **Idempotency:** pre-flight duplicate-zone checks work; rollback markers are correct

### What This Skill CANNOT Verify

- **PowerShell cmdlet execution** (real `Add-DnsServerPrimaryZone -ReplicationScope domain`)
- **Active Directory replication** (zone actually replicated across domain controllers)
- **Real MSAD collector responses** (behavior of actual Windows RPC/LDAP bridge)

These gaps are verified via:
- Unit tests in each repo (xUnit for agent, table-driven for Go services)
- Windows CI: Jenkins `windows_node_ddi_msad_agent_label` node runs `dotnet test MSADAgent\Agent.Tests`
- Stage/prod testing: manual, documented in QA tickets (DDIDNS-10510, DDIDNS-10511, DDIDNS-10512 under the epic)

---

## Quick Collector-Level Testing via `cmd/testclient` (Alternative)

For **faster collector-only checks** without bringing up the full WAPI v3 + middleware stack, use the MSAD Collector's gRPC test client directly:

**When to use:**
- Verifying a new replication-scope value or error-code mapping at the collector level
- Quick gRPC integration check during implementation (before e2e stack tests)
- Collector-proto changes that need validation before middleware regenerates

**Exact steps:** See `references/repo-topology.md` → "MSAD Collector Test Client (cmd/testclient)" section for setup, invocation examples, and flags.

---

## Prerequisites

1. **Local repos cloned:** `~/ddi.dns.config` and `~/ddi.cloud.proxy.middleware` (middleware is a library, included as a dependency in dns.config).
2. **Docker + docker-compose:** for PostgreSQL, Redis, and the dns.config service. Do NOT install PostgreSQL locally.
3. **Tools:** curl (or newman for Postman collections), jq, git, make.

---

## Process

### Step 1: Setup (Docker-Based)

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
   # Expected: {"status": "healthy"} or similar
   ```
   If the service fails to start, check logs:
   ```bash
   docker-compose logs dns-config  # or whatever the service is named in docker-compose.yml
   ```

3. **Identify the WAPI v3 endpoint** (usually `http://localhost:8080/api/v3/...` — check the docker-compose.yml or Makefile for exact port).

4. **Provision a test account/view/JWT** (the existing `k6/` or test fixtures in dns.config should populate these automatically; if not, use curl to create):
   ```bash
   # Example (adjust to your auth scheme):
   JWT=$(curl -s -X POST http://localhost:8080/auth/login -d '{"user":"test","pass":"test"}' | jq -r .token)
   ACCOUNT_ID=$(curl -s -H "Authorization: Bearer $JWT" http://localhost:8080/api/v3/accounts | jq -r '.[] | select(.name == "test-account") | .id')
   VIEW_ID=$(curl -s -H "Authorization: Bearer $JWT" http://localhost:8080/api/v3/views | jq -r '.[] | select(.name == "test-view") | .id')
   ```

5. **Verify the middleware's mocked MSAD collector is enabled:**
   Check `ddi.cloud.proxy.middleware/pkg/interceptor_handlers.go` or `main.go` (in dns.config's integration context) — the `CloudProxyHandler` should be wired to use the `MockCloudProxyClient` from `pkg/mocks` when running in test mode, not dialing a real remote service.

**Cleanup after testing:**
```bash
docker-compose down             # stops and removes containers
```

State:
> Step 1 — Setup complete. dns.config running at `<endpoint>`. PostgreSQL running in container. Test account: `<account-id>`, view: `<view-id>`.

### Step 2: Test Cases

Run the following request sequences via curl or a test runner (newman, k6, or a custom bash loop). Each case asserts on:
- HTTP response status and body
- DDI zone table row (replication-scope value, zone type, metadata)
- Mocked collector response captured in logs or via spy/mock assertion

#### Test Case 2A: Create Auth Zone with Local Scope

```bash
POST /api/v3/zones
Headers: Authorization: Bearer $JWT, Content-Type: application/json

Body:
{
  "name": "local.test.com",
  "zone_type": "primary_auth",
  "replication_scope": "local",
  "view_id": "$VIEW_ID",
  "account_id": "$ACCOUNT_ID"
}

Expected:
- HTTP 201 Created
- DB row: zones.replication_scope = "local"
- Middleware called collector Create RPC with replication_scope="local"
```

#### Test Case 2B: Create Auth Zone with Domain Scope

```bash
POST /api/v3/zones
{
  "name": "domain.test.com",
  "zone_type": "primary_auth",
  "replication_scope": "domain",
  "view_id": "$VIEW_ID",
  "account_id": "$ACCOUNT_ID"
}

Expected:
- HTTP 201 Created
- DB row: replication_scope = "domain"
- Middleware routed to MSAD collector with domain scope
```

#### Test Case 2C: Create Forward Zone with Forest Scope

```bash
POST /api/v3/zones
{
  "name": "forest.test.com",
  "zone_type": "forward",
  "replication_scope": "forest",
  "view_id": "$VIEW_ID",
  "account_id": "$ACCOUNT_ID"
}

Expected:
- HTTP 201 Created
- DB row: replication_scope = "forest"
- Middleware routed to MSAD collector with forest scope
```

#### Test Case 2D: Reject Create with Invalid Scope (Legacy)

```bash
POST /api/v3/zones
{
  "name": "invalid.test.com",
  "zone_type": "primary_auth",
  "replication_scope": "legacy",
  "view_id": "$VIEW_ID",
  "account_id": "$ACCOUNT_ID"
}

Expected:
- HTTP 400 Bad Request (or 422 Unprocessable Entity)
- Error message: "replication scope 'legacy' is not valid for zone creation" (or similar)
- DB row: zone NOT created
- Middleware validation blocked before calling collector
```

#### Test Case 2E: Duplicate Zone Check

Create the same zone twice:

```bash
POST /api/v3/zones
{ "name": "dup.test.com", "zone_type": "primary_auth", "replication_scope": "local", ... }

# First call: HTTP 201
# Second call with same name/account/view: HTTP 409 Conflict (or codes.AlreadyExists in gRPC)

Expected:
- First request succeeds; zone created in DB
- Second request fails before calling collector (pre-flight duplicate check)
- DB still has one zone row (no orphan)
```

#### Test Case 2F: Update Forward Zone Replication Scope

Replication scope changes are allowed for Forward zones (DDIDNS-10547); Auth zones forbid them (write-once).

```bash
# Create
POST /api/v3/zones
{ "name": "mutable.test.com", "zone_type": "forward", "replication_scope": "local", ... }
# Returns 201, zone_id = X

# Update
PATCH /api/v3/zones/X
{ "replication_scope": "domain" }

Expected:
- HTTP 200 OK (or 204 No Content)
- DB row: zones.replication_scope updated to "domain"
- Middleware called collector Update RPC with new scope
```

#### Test Case 2G: Error Code Mapping

Mock a collector error (e.g., `ZONE-001` for "zone already exists" from AD). Assert that the middleware translates it to the correct gRPC status code.

```bash
# In the middleware's mock setup (or via test harness), inject:
# mock_collector_response.err_info = "... ErrorCode: ZONE-001 ..."

POST /api/v3/zones
{ "name": "error-test.com", ... }

Expected:
- HTTP 409 Conflict (gRPC codes.AlreadyExists)
- Error message includes the agent error details
```

State:
> Step 2 — Test cases: 2A–2G executed. Results:
> - 2A (local scope): `<pass/fail>`
> - 2B (domain scope): `<pass/fail>`
> - 2C (forest scope): `<pass/fail>`
> - 2D (reject legacy): `<pass/fail>`
> - 2E (duplicate check): `<pass/fail>`
> - 2F (update scope): `<pass/fail>`
> - 2G (error mapping): `<pass/fail>`

### Step 3: Data Model & DB Verification

Spot-check the DDI DB:

```bash
# Connect to postgres (docker exec or via psql client)
SELECT id, name, zone_type, replication_scope, account_id, view_id
  FROM zones
  WHERE name LIKE '%.test.com'
  ORDER BY created_at DESC;
```

Verify:
- All test zones are present
- `zone_type` values match input (primary_auth → auth, forward → forward)
- `replication_scope` values are correct (local/domain/forest, not legacy)
- Foreign keys (account_id, view_id) are valid

State:
> Step 3 — DB: `<N>` test zones created. All replication-scope values correct. No orphans.

### Step 4: Middleware Logging & Mocked Collector Assertions

If the middleware logs gRPC requests/responses or the mock collector captures calls, inspect them to confirm the flow:

```bash
# Check middleware logs for:
# "CloudProxyHandler.Handle: routing zone create to MSAD collector"
# "collector.Create request: replication_scope=domain"

# Check mock collector for:
# "Zones.Create called with: zone_name=..., replication_scope=..."
```

Assert:
- Scope value was transmitted to the collector unchanged
- Error codes (if any) were mapped correctly

State:
> Step 4 — Request flow verified. Middleware correctly routed `<N>` requests to mocked collector.

### Step 5: Cleanup & Documentation

1. Bring down the docker stack:
   ```bash
   docker-compose down
   cd -
   ```

2. Document the results:
   - Which test cases passed/failed
   - Any deferred/blocked tests (e.g., "Docker compose unavailable")
   - Link to this verification as evidence in PR body

State:
> Step 5 — Cleanup done. E2E verification complete.

---

## Automation

For repeatability, wrap the above in a shell script or k6 test file:

### Bash Script (`msad-zone-e2e.sh`)

```bash
#!/bin/bash
set -e

JWT=$(...)
ACCOUNT_ID=$(...)
VIEW_ID=$(...)
ENDPOINT="http://localhost:8080/api/v3"

# Test 2A: Local scope
echo "Test 2A: Create zone with local scope..."
curl -X POST $ENDPOINT/zones \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "local.test.com",
    "zone_type": "primary_auth",
    "replication_scope": "local",
    "view_id": "'$VIEW_ID'",
    "account_id": "'$ACCOUNT_ID'"
  }' | jq .

# ... repeat for 2B–2G ...

echo "All tests completed."
```

### K6 Test (`msad-zones.js`)

Extend the existing `k6/auth_zone.js` pattern:

```javascript
import http from 'k6/http';
import { check } from 'k6';

export default function (jwt, accountId, viewId) {
  // Test 2A: local scope
  const res = http.post(`${__ENV.ENDPOINT}/zones`, {
    name: 'local.test.com',
    zone_type: 'primary_auth',
    replication_scope: 'local',
    view_id: viewId,
    account_id: accountId,
  }, {
    headers: { Authorization: `Bearer ${jwt}` },
  });
  
  check(res, {
    'local scope: status 201': (r) => r.status === 201,
    'local scope: replication_scope = local': (r) => r.json('replication_scope') === 'local',
  });

  // ... repeat for other scopes ...
}
```

---

## Known Gaps & Deferral

| Aspect | Status | Why | Verified By |
|---|---|---|---|
| PowerShell cmdlet execution | ❌ Deferred | Windows-only; no Mac/Linux equivalent | Windows CI (Jenkins `windows_node_ddi_msad_agent_label`) + unit tests (xUnit in MSADAgent/Agent.Tests) |
| Real AD replication | ❌ Deferred | Requires live AD environment | Stage/prod testing (DDIDNS-10510, 10511, 10512) |
| Real MSAD collector RPC | ❌ Deferred | ddi.msadconnect.proxy unreachable from test env | Unit tests in collector + integration tests in dns.config |
| Actual zone creation in AD | ❌ Deferred | Requires real MSAD agent + AD | Windows CI + stage testing |

All deferred aspects are **covered by other verification layers** (unit tests, Windows CI, stage testing), so this gap is **not a blocker**.

---

## Integration with PR Workflow

Include this skill's verification in the PR body:

```markdown
## E2E Verification

- [x] Local scope creation
- [x] Domain scope creation
- [x] Forest scope creation
- [x] Legacy scope rejected
- [x] Duplicate zone pre-flight check
- [x] Forward zone scope update
- [x] Error code mapping (ZONE-001 → codes.AlreadyExists)
- [x] DB persistence correct

**Deferred:** real MSAD agent/AD replication (Windows CI + stage testing; tracked in DDIDNS-10510/10511/10512).
```

---

## Error Handling

- **docker-compose up fails:** check DNS config's Makefile or README for setup requirements (e.g., postgres running, env vars). Mark deferred if Docker unavailable.
- **JWT/account/view creation fails:** use fixtures from `k6/` or create manually via admin API.
- **WAPI v3 endpoint not found:** check dns.config's service port in docker-compose.yml or logs.
- **Mocked collector not wired:** confirm middleware is using `pkg/mocks.MockCloudProxyClient` in test mode (check dns.config's integration test setup).
- **Test fails unexpectedly:** run the single failing test with verbose logging; check middleware + dns.config logs for error details.
