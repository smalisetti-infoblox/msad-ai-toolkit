# MSAD Agents

Two specialized Claude Code agents for MSAD development. Typically dispatched by skills (planning and execution), but can be invoked directly for specific tasks.

---

## msad-backend-dev

**Implementation agent for a single Jira task in a single repo.**

Writes code, tests, and commits. Works across the five-repo ecosystem (Go + C#/.NET).

### When to Invoke

- **Via skills:** planning and execution skills dispatch this automatically
- **Directly:** rarely — usually let execution skill handle it
- **Entry point:** Jira task ID (e.g., `DDIDNS-10519`)

### What It Does

1. **Reads Jira** (task, parent story, linked tickets)
2. **Resolves the target repo** via `references/repo-topology.md`
3. **Researches** (git log, grep, existing test patterns)
4. **Implements TDD-style:**
   - Writes a failing test first
   - Writes code to make the test pass
   - Runs the full test suite
   - Reports coverage

### TDD Discipline

- **Always writes tests before code** — no exceptions
- **Test patterns per repo:**
  - Go: table-driven tests (`[]struct{...}`) with sqlmock for DB
  - C#: xUnit in `Agent.Tests/`
- **Discovers test commands** from the repo's Makefile/CI, not generic ones

### Cross-Repo Contracts

Enforces these non-negotiable constraints:

- **Proto sync:** if collector proto changes, agent regenerates middleware's vendored code
- **Validator mirrors:** if replication-scope validator changes in one repo, all mirrors must be updated
- **Error codes:** new agent errors must be mapped in collector's `ErrorCodeToStatus()`

### PowerShell / LDAP Safety

When touching `ddi.msad.agent`'s zone controllers:

- Validates all user-input strings before using in PowerShell `-ReplicationScope` arguments
- Checks LDAP filter strings for injection (RFC 4515 escaping)
- Flags unvalidated shell-out as a blocker

### Output

- Modified files in the target repo
- All tests passing
- Implementation log (file paths, one-liners, test status)

---

## msad-code-review

**Review agent for a single pull request.**

Reviews against MSAD-specific requirements + general code quality. Advisory only; doesn't approve or block, just surfaces findings.

### When to Invoke

- **Via execution skill:** execution skill dispatches this automatically after implementation
- **Directly:** for a quick second opinion on a teammate's PR
- **Entry point:** GitHub PR URL or branch name

### What It Does

1. **Fetches the PR diff** and metadata
2. **Runs MSAD-specific checklist:**
   - Replication-scope allow-list consistency (local/domain/forest, no legacy)
   - Idempotency/rollback patterns (pre-flight duplicate check, best-effort rollback after zone create)
   - gRPC error-code mapping (agent codes → gRPC status, not raw `Unknown`)
   - PowerShell/LDAP safety (ddi.msad.agent only)
3. **Runs general code quality checks:**
   - SOLID principles
   - Correctness & edge cases
   - Test coverage
   - Security (SQL injection, XSS, shell injection)
   - RFC correctness (DNS-relevant changes)

### Severity Levels

- **MUST fix** — blocker; code is wrong or unsafe
- **SHOULD fix** — strong recommendation; author should justify any deferral
- **MAY fix** — nice-to-have
- **INFO** — observation; no action needed

### MSAD Checklist Details

#### Replication-Scope Validators

Four validators exist across the ecosystem and **must stay in sync:**

| Repo | File | Function | Allows |
|---|---|---|---|
| dns.config | `pkg/service/application/stub_zone.go` | `validateStubZoneReplicationScopeNotLegacy()` | local, domain, forest |
| middleware | `pkg/msad_zone_helper.go:187` | `isValidMSADReplicationScopeForZoneCreate()` | local, domain, forest |
| middleware | `pkg/msad_zone_helper.go:200` | `isValidMSADReplicationScopeForStubZone()` | local, domain, forest |
| dns.config | `pkg/service/application/stub_zone.go` | `isADRestrictedScope()` | domain, forest (excludes local) |

If a PR changes one, **all mirrors must be updated in the same PR or a linked PR.**

#### Idempotency & Rollback (MSAD-Create Paths)

Any new zone-create handler must:

1. **Pre-flight duplicate check:**
   - Query DDI DB before calling MSAD Collector Create RPC
   - Return `codes.AlreadyExists` if zone exists
   - Example: `zoneExistsInDB(accountID, viewID, fqdn)` in PR #508

2. **Rollback on failure after MSAD creation:**
   - If MSAD Create succeeds but downstream fails (tag validation, DB write)
   - Call rollback with `context.WithoutCancel` (persists even if original context is cancelled)
   - Rollback is **best-effort** — logs failure but never masks original error
   - Example: `rollbackMSADAuthZone()` in PR #508

#### Error-Code Mapping

gRPC error handling must flow through `GetErrorCode()` → `ErrorCodeToStatus()`:

```go
// ✅ GOOD
util.GetErrorCode(errMsg string) string         // extracts "ZONE-001" from error
util.ErrorCodeToStatus(code string) error       // maps to gRPC status (AlreadyExists, etc.)

// ❌ BAD
return status.Error(codes.Unknown, raw_error_text)  // loses all ZONE-00x semantics
```

New agent error codes must be added to `ErrorCodeToStatus()` and tested.

#### PowerShell / LDAP Safety (ddi.msad.agent only)

Unvalidated user input in PowerShell arguments = **MUST BLOCK**.

```csharp
// ❌ UNSAFE
$"Add-DnsServerPrimaryZone -Name '{zoneName}' -ReplicationScope '{replicationScope}'"

// ✅ SAFE — validated against allow-list before use
if (!IsValidReplicationScope(replicationScope)) throw new InvalidOperationException(...);
```

### Output

Markdown report with sections:

- **Summary:** is this PR sound?
- **MUST Fix** findings (blockers)
- **SHOULD Fix** findings (recommendations)
- **MAY Fix / INFO** (nits, observations)
- **Verification checklist** (MSAD items checked off)
- **Recommendation:** Approved / Issues Found

---

## How Agents Work Together

```
Skill: msad-dev-planning
  └─ (writes plan file)
  └─ (presents to user for approval)

Skill: msad-dev-execution
  ├─ (for each work package)
  │  ├─ Agent: msad-backend-dev
  │  │  └─ (implements task, all tests pass)
  │  ├─ (runs test suite for repo)
  │  └─ Agent: msad-code-review (validation loop, ≤3 rounds)
  │     ├─ (identifies findings)
  │     ├─ (user fixes or justifies)
  │     ├─ (re-reviews until clean)
  │     └─ (reports to user)
  └─ (opens draft PRs)
```

---

## See Also

- **[skills/README.md](../skills/README.md)** — Skills that dispatch these agents
- **[../README.md](../README.md)** — Main usage guide
- **[references/repo-topology.md](../references/repo-topology.md)** — Shared knowledge (repos, build/test commands, test patterns)
