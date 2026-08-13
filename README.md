# MSAD AI Toolkit

Claude Code custom agent + skills for the MSAD (Microsoft Active Directory DNS) ecosystem. Implements multi-repo orchestration for **DDIDNS-7732** (Microsoft DNS zone creation / replication scope) and related features across five repositories with different stacks.

## Five-Repo Ecosystem

| Repo | Stack | Role |
|---|---|---|
| **ddi.dns.config** | Go | WAPI v3 API surface; replication-scope validation |
| **ddi.cloud.proxy.middleware** | Go | gRPC interceptor library; MSAD request translation |
| **ddi.msad.collector** | Go, gRPC | gRPC microservice; error-code mapping |
| **ddi.msadconnect.proxy** | Go | Windows RPC/LDAP bridge |
| **ddi.msad.agent** | C#/.NET 8 | Windows Service; PowerShell zone controllers (Windows-only testing) |

---

## What's In This Toolkit

### Agents (2)

- **`msad-backend-dev`** — implementation agent for a single Jira task in a single repo
  - TDD discipline (write test first)
  - Cross-repo contract awareness (proto sync, validator mirrors)
  - PowerShell/LDAP safety checks
  - Per-repo test/build commands (dotnet vs. go)

- **`msad-code-review`** — review agent for a single PR
  - MSAD-specific checklist (replication-scope allow-list, idempotency/rollback, error-code mapping, PowerShell safety)
  - General code quality (SOLID, correctness, security, test coverage)
  - Severity levels (MUST/SHOULD/MAY)

### Skills (4)

- **`msad-developer`** — entry-point router
  - Classifies input (epic / story / task / "execute plan")
  - Suggests downstream skill (planning or execution)
  - Never auto-chains; user owns the decision

- **`msad-dev-planning`** — plan generator for an epic/story/task
  - Reads Jira ticket + linked context
  - Groups work into per-repo packages
  - Identifies cross-repo dependencies (proto sync, validator mirrors)
  - Writes a plan file; hard-gates on user approval

- **`msad-dev-execution`** — plan executor
  - Dispatches `msad-backend-dev` agents (parallel for independent packages)
  - Runs test suite per repo
  - **Validation loop** (bounded, ≤ 3 rounds): review → fix findings → re-review → clean/converged
  - Opens draft PRs cross-linked by dependency

- **`msad-e2e-verify`** — API-level end-to-end verification
  - Brings up dns.config service + mocked MSAD collector
  - Drives zone create/update flows via WAPI v3
  - Verifies replication-scope handling, error-code mapping, DB persistence
  - **Does not require Windows agent** (only for PowerShell cmdlet execution, deferred to Windows CI)

### Reference Materials

- **`references/repo-topology.md`** — shared knowledge loaded by agents/skills
  - Stack, build/test/lint commands per repo
  - Request flow chain + validation points
  - Proto/generated-code pairs (what to regenerate when)
  - Build/test patterns (table-driven Go tests, sqlmock, xUnit)

---

## Installation

Clone this repo (or add as a Claude Code plugin):

```bash
# Option 1: Clone + load locally
git clone <this-repo> ~/msad-ai-toolkit
# Then in Claude Code: add plugin path (settings → plugins → local)

# Option 2: Symlink into ~/.claude/
ln -s ~/msad-ai-toolkit/agents/* ~/.claude/agents/
ln -s ~/msad-ai-toolkit/skills/* ~/.claude/skills/
# Then in Claude Code: reload settings
```

## Getting Started

### For a Jira Epic/Story

```
User: work on DDIDNS-7732

Claude Code: suggests /msad-dev-planning DDIDNS-7732

User: /msad-dev-planning DDIDNS-7732

[Planning skill reads the epic, groups tasks by repo, writes plan, asks for approval]

User: (approves plan)

User: /msad-dev-execution /path/to/plan.md

[Execution skill dispatches implementation agents, runs tests, validates with code review loop, opens draft PRs]
```

### For a Single Task

```
User: implement DDIDNS-10521

Claude Code: suggests /msad-dev-planning DDIDNS-10521

[Same flow, but scoped to one task]
```

### For E2E Testing (API Layer)

```
User: test the replication scope flow via API

Claude Code: suggests /msad-e2e-verify

[E2E skill brings up the stack, runs zone create/update test sequences, verifies DB state and error handling]
```

---

## Key Design Decisions

### Multi-Round Validation Before PR

Implementation → **review loop** (bounded, ≤ 3 rounds) → fix findings → **re-review until clean** → then draft PR.

This prevents landing half-baked code with review findings still open. Matches the DNS-team `dns-dev-execution` pattern.

### Windows Testing Reality

`ddi.msad.agent` is a Windows Service and **cannot be tested on Mac/Linux**. This toolkit acknowledges that:

- **Local tests** can cover (go test, table-driven tests in Go repos, xUnit in agent)
- **API-level E2E** can cover (zone create/update with mocked collector, scope validation, error mapping)
- **Windows CI** must cover (real PowerShell cmdlets, Windows-only DLLs, Jenkins `windows_node_ddi_msad_agent_label` node)
- **Stage testing** must cover (real MSAD, AD replication, permission errors)

Skills explicitly flag what's deferred and point to the right verification gate.

### Cross-Repo Contract Discipline

Four validators must stay in sync:

- `validateStubZoneReplicationScopeNotLegacy()` in dns.config
- `isValidMSADReplicationScopeForZoneCreate()` in middleware
- `isValidMSADReplicationScopeForStubZone()` in middleware
- `isADRestrictedScope()` in dns.config

Code review checklist enforces this. Planning surfaces it upfront.

---

## PR Quality Bar

PRs from this toolkit follow the pattern set by the existing DDIDNS-7732 work:

- ✅ Precise Jira/AC cross-references
- ✅ "Intentionally unchanged" call-outs for unrelated code
- ✅ Cross-repo dependencies documented (proto sync, validator sync)
- ✅ Follow-up tickets filed for out-of-scope gaps
- ✅ Test coverage at all layers (unit, integration, e2e where applicable)
- ✅ Windows CI verification acknowledged (if agent changes)

---

## Repo Map (from `references/repo-topology.md`)

See `references/repo-topology.md` for:
- Exact build/test commands per repo (`make test` for Go, `dotnet test` for agent)
- Proto files + regeneration points
- Test patterns (table-driven, sqlmock, xUnit, gomock)
- Replication-scope validator locations
- Error-code mapping in the collector

---

## Contributing & Future Work

This toolkit is a **v0.1.0 scaffold** with real, repo-specific content. As the team uses it:

- **Feedback on planning/execution flow?** File an issue or reach out to the MSAD team.
- **New patterns discovered?** Update the agents/skills to capture them.
- **Ready to merge into `ib.ai-hub`?** This can become a new `playbooks/uddi/msad` entry in the org-wide plugin marketplace.

---

## Contact

For questions, feedback, or to join MSAD development work: [MSAD team contact info]

---

## See Also

- **[DDIDNS-7732 Epic](https://infoblox.atlassian.net/browse/DDIDNS-7732)** — Microsoft DNS zone creation / replication scope
- **[architecture-hub](https://github.com/Infoblox-CTO/architecture-hub)** — specs, design docs, contracts for this epic
- **[ddi.dns.config](https://github.com/Infoblox-CTO/ddi.dns.config)** — WAPI v3 surface
- **[ddi.cloud.proxy.middleware](https://github.com/Infoblox-CTO/ddi.cloud.proxy.middleware)** — gRPC interceptor library
- **[ddi.msad.collector](https://github.com/Infoblox-CTO/ddi.msad.collector)** — gRPC microservice
- **[ddi.msad.agent](https://github.com/Infoblox-CTO/ddi.msad.agent)** — Windows Service (C#/.NET)
