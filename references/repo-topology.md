# MSAD Repo Topology & Build Reference

This document maps the six-repo MSAD ecosystem, lists build/test/lint commands, and identifies key implementation files per repo. It's shared reference material for any MSAD epic/story/task — not scoped to one epic. The "Request Flow & Validation Points" section below uses the replication-scope validators (introduced by DDIDNS-7732, the first epic run through this toolkit) as a worked example of how validation flows through the layers; update it as new validation points are added by later epics.

## Repo Summary Table

| Repo | Stack | Role | Local path | Build | Test |
|---|---|---|---|---|---|
| **ddi.dns.config** | Go 1.23+ | WAPI v3 API surface; owns replication-scope validation | `~/ddi.dns.config` | `make vendor` | `make test` |
| **ddi.dns.data** | Go 1.23+ | WAPI v3 data layer; zone data retrieval and transformation | `~/ddi.dns.data` | `make vendor` | `make test` |
| **ddi.cloud.proxy.middleware** | Go 1.23+ | gRPC interceptor library; MSAD request translation (consumed by dns.config and dns.data) | `~/ddi.cloud.proxy.middleware` | `make vendor` | `make test` |
| **ddi.msad.collector** | Go 1.23+ | gRPC microservice; error-code mapping | `~/ddi.msad.collector` | `make vendor` | `make test` |
| **ddi.msadconnect.proxy** | Go (not yet surveyed) | Windows RPC/LDAP bridge | `~/ddi.msadconnect.proxy` | `make vendor` | `make test` |
| **ddi.msad.agent** | C#/.NET 8 (net8.0-windows) | Windows Service; PowerShell zone controllers | `~/ddi.msad.agent` | `dotnet build MSADAgent\MSADAgent.sln -c Debug` | `dotnet test MSADAgent\Agent.Tests\Agent.Tests.csproj` |

**Windows CI note:** `ddi.msad.agent` tests run on a Jenkins node labeled `windows_node_ddi_msad_agent_label` — the only way to verify PowerShell/LDAP cmdlet execution. No local Mac/Linux execution possible.

---

## Request Flow & Validation Points (Both Directions)

Zones/records flow through this ecosystem in **two directions** using **two separate API surfaces** — they only share the collector and below. Write requests never pass through the sync/discovery repos, and sync/discovery never calls the write RPCs. Confirmed by reading the actual RPC definitions and client call sites (not inferred).

```
┌─────────────────────────────────────────────────────────────────────────┐
│  DIRECTION 1: DDI → MSAD  (write path — create/update/delete)          │
│  API surface: WAPI v3 (REST) → gRPC Create/Update/Delete RPCs          │
└─────────────────────────────────────────────────────────────────────────┘

  Portal / WAPI v3 client
    │  REST: POST/PATCH zone (replication_scope: local|domain|forest)
    ▼
  WAPI v3 (ddi.dns.config)                                    ◄── VALIDATION
    │  pkg/service/application/stub_zone.go
    │  validateStubZoneReplicationScopeNotLegacy() — rejects `legacy`
    │  at creation; allows local/domain/forest
    │  gRPC: Zones.Create / Zones.Update
    ▼
  Cloud Proxy Middleware (ddi.cloud.proxy.middleware)          ◄── VALIDATION
    │  pkg/msad_zone_helper.go
    │  isValidMSADReplicationScopeForZoneCreate() — mirrors dns.config's
    │  allow-list (local/domain/forest, rejects `legacy`)
    │  gRPC: Zones.Create / Zones.Update / Zones.Delete
    ▼
  MSAD Collector (ddi.msad.collector)                          — no validation
    │  pkg/svc/zones/zones.go — ZonesServer.Create/Update/Delete
    │  passes request through; only maps agent ZONE-00x errors →
    │  gRPC status via pkg/util/util.go:ErrorCodeToStatus()
    │  gRPC: MSADMigrateClient (to proxy)
    ▼
  MSAD Connect Proxy (ddi.msadconnect.proxy)                    — no validation
    │  Windows RPC/LDAP bridge; dials the agent
    ▼
  MSAD Agent (ddi.msad.agent)                                  ◄── VALIDATION
    │  MSADAgent/Agent/Core/RequestHandlers/DnsZoneRequestHandler.cs
    │  IsValidCreateDnsZoneRequest() / IsValidUpdateDnsZoneRequest()
    │  IsValidReplicationScopeValue() — allow-list check before dispatch
    │  to per-zone-type controllers (DnsPrimaryZoneController,
    │  DnsConditionalForwarderZoneController)
    │  Create: should reject `legacy` (drift as of 2026-08-20, see
    │  specs/msad-dev-plans/2026-08-20-DDIDNS-10562-plan.md)
    │  Update: correctly allows `legacy` (write-once/immutability is
    │  enforced separately in middleware; Update's allow-list is not
    │  the mechanism that blocks scope changes)
    ▼
  PowerShell: Add-DnsServerPrimaryZone -ReplicationScope /
              Set-DnsServerConditionalForwarderZone -ReplicationScope
    ▼
  Microsoft Active Directory (AD-integrated zone, replication scope applied)


┌─────────────────────────────────────────────────────────────────────────┐
│  DIRECTION 2: MSAD → DDI  (sync/discovery path — read-only)            │
│  API surface: gRPC List RPC (streaming) → CloudQuery → overlay adapter │
└─────────────────────────────────────────────────────────────────────────┘

  Microsoft Active Directory (zones may have ANY replication scope,
  including `legacy` — e.g. pre-existing zones never migrated)
    ▼
  MSAD Agent (ddi.msad.agent)                                  — no validation
    │  reports actual zone state (whatever scope AD has)
    ▼
  MSAD Connect Proxy (ddi.msadconnect.proxy)                    — pass-through
    ▼
  MSAD Collector (ddi.msad.collector)                          — no validation
    │  pkg/svc/zones/zones.go — ZonesServer.List (streaming RPC)
    │  gRPC: Zones.List(ListZoneRequest) returns (stream ListZoneResponse)
    │  Records equivalent: Records.List / Records.Get
    ▼
  cq-source-msad (CloudQuery plugin)                            — no validation
    │  resources/services/dns/zones.go
    │  calls ZoneClient.List(...) directly against the collector's gRPC
    │  endpoint (msad_collector_endpoint) — bypasses middleware entirely,
    │  this is a read-only fan-in, not a write path
    │  maps ZoneInfo.ReplicationScope → CQ zones table column verbatim
    ▼
  cloud.discovery                                               — no validation
    │  pkg/adapters/overlay/msad/cq_fetchers.go — reads the CQ table,
    │  maps to provider.ReplicationScope(...)
    │  pkg/adapters/overlay/b1ddi/ — writes into DDI's
    │  ExternalProvidersMetadata.msad_config.replication_scope
    │  (JSONB field, no schema/proto change needed to add scope values)
    ▼
  DDI (BloxOne) — zone now visible in Portal with its actual
  replication scope, including `legacy` if that's what AD reports
```

**Why this matters for replication-scope work:** a zone can carry `legacy` scope in DDI *only* via Direction 2 (sync of a pre-existing AD zone). Direction 1 will never produce a `legacy`-scope zone once the Create-path validators are consistent (dns.config and middleware already reject it; the agent fix is tracked in DDIDNS-10562). This is why "legacy scope must be allowed to sync but not be creatable" is not a contradiction — they are two different API surfaces with two different repos, confirmed by reading `cq-source-msad`'s and `cloud.discovery`'s code (no allow-list logic exists on that side at all).

### Replication-Scope Validation Today

| Layer | File(s) | Validation | Issue |
|---|---|---|---|
| **dns.config** | `pkg/service/application/stub_zone.go:~1198` | `validateStubZoneReplicationScopeNotLegacy()`, `isADRestrictedScope()` — allows `local`/`domain`/`forest`, rejects `legacy` at creation; scope-change mostly forbidden except in stub zones | Partial — Auth zones don't allow scope changes (DDIDNS-10547 work in progress) |
| **middleware** | `pkg/msad_zone_helper.go:187,200` | `isValidMSADReplicationScopeForZoneCreate()`, `isValidMSADReplicationScopeForStubZone()` — allow-list is `local`/`domain`/`forest` | Correct (mirrors dns.config) |
| **collector** | `pkg/svc/zones/zones.go` | No validation; passes `ErrorCodeToStatus` mapping but doesn't reject bad scopes | Correct (validation is upstream responsibility) |
| **proxy** | TBD | TBD | TBD |
| **agent** | `MSADAgent/Agent/Core/RequestHandlers/DnsZoneRequestHandler.cs` — `IsValidCreateDnsZoneRequest()` / `IsValidReplicationScopeValue()` | Allow-list check added for Primary/Forward zone creation (DDIDNS-10521, PR #617); **known drift as of 2026-08-20:** the Create-path allow-list currently includes `legacy` (to mirror Update), but dns.config/middleware reject `legacy` at creation — Create should exclude it. See `specs/msad-dev-plans/2026-08-20-DDIDNS-10562-plan.md` | Fix tracked in DDIDNS-10562's dev plan |

---

## Proto / Contract Files

### Collector gRPC Surface

**Proto source:** `ddi.msad.collector/api/protobuf-spec/service.proto`

Defines 13 services (Zones, Records, Subnets, etc.). Generated code committed alongside at `ddi.msad.collector/pkg/pb/service.pb.go` (+ `.pb.gorm.go`, `.pb.validate.go`).

Key service for this epic: **Zones** (methods: Create, Update, Delete, List, Get).

### Middleware Proto Integration

**Generated client location:** `ddi.cloud.proxy.middleware/pkg/pb/` (vendored copy of the collector's generated code; **regenerate when collector's proto changes** via `make protobuf` in that repo).

**Usage:** `pkg/msad_zone_helper.go` builds gRPC requests matching the collector's `Zones` service shape; `pkg/msadcollector/msadcollector.go` instantiates the client via `NewZonesClient(conn)`.

### Agent Proto Surface

**Outbound health/telemetry proto:** `MSADAgent/Agent/Protos/HealthCollector/service.proto` (inbound to cloud collector, documented in `docs-manifest.yaml` as `health-collector-grpc`).

**Local dispatcher proto:** `MSADAgent/Agent/Protos/RpcServer/service.proto` (internal command dispatcher; not directly relevant to the MSAD epic).

---

## Key Implementation Files by Repo

### ddi.dns.config

- `pkg/service/application/stub_zone.go` — `validateStubZoneReplicationScopeNotLegacy()`, `isADRestrictedScope()`
- `pkg/service/application/auth_zone.go` — auth-zone-specific validation (scope-change forbidden, pending DDIDNS-10547)
- `pkg/service/application/forward_zone.go` — forward-zone-specific validation (scope-change allowed per DDIDNS-10547)
- `pkg/messages/messages.go` — `ErrStubZoneInvalidReplicationScope` error const
- `*_test.go` — table-driven tests using sqlmock, test fixtures in sibling dirs

### ddi.dns.data

**Not yet surveyed.** On first task involving ddi.dns.data, confirm exact validator/file names, whether ddi.cloud.proxy.middleware is a direct dependency, and which validation/conversion logic lives here vs. in ddi.dns.config.

### ddi.cloud.proxy.middleware

- `pkg/msad_zone_helper.go` — MSAD request builders (`toMSADCreateAuthZoneRequest`, `toMSADUpdateForwardZoneRequest`, etc.), validators
- `pkg/interceptor_handlers.go` — handler structs (`AuthZoneCreateHandler`, `ForwardZoneUpdateHandler`, etc.), lifecycle methods
- `pkg/zone_helper.go` — general zone diffing/conversion helpers
- `pkg/msadcollector/msadcollector.go` — gRPC client instantiation
- `pkg/mocks/` — mock clients for `MockCloudProxyClient`, `msadcollector` mocks
- `*_test.go` + sqlmock — unit and DB-context tests

### ddi.msad.collector

- `pkg/svc/zones/zones.go` — Create/Update/Delete/List gRPC handlers; calls `GetErrorCode()` to map errors
- `pkg/util/util.go` — `GetErrorCode(errMsg string) string`, `ErrorCodeToStatus(code string) error`
- `pkg/mocks/msadconnectproxy_mock/` — mock for the downstream proxy
- `zones_test.go` — table-driven tests with `[]struct{ Setup func(...) }` pattern, gomock

### ddi.msad.agent

- `MSADAgent/Agent/Core/RequestHandlers/DnsZoneRequestHandler.cs` — `IsValidCreateDnsZoneRequest()`/`IsValidUpdateDnsZoneRequest()`/`IsValidReplicationScopeValue()`: centralized request validation (including replication-scope allow-list, added DDIDNS-10521/PR #617) before dispatch to per-zone-type controllers
- `MSADAgent/Agent/Core/DnsInfoControllers/DnsInfoZoneControllers/DnsPrimaryZoneController.cs` — `Create()` / `Update()` for Primary zones; validation happens upstream in `DnsZoneRequestHandler`, not here
- `MSADAgent/Agent/Core/DnsInfoControllers/DnsInfoZoneControllers/DnsConditionalForwarderZoneController.cs` — `Create()` / `Update()` for Forward zones; validation happens upstream in `DnsZoneRequestHandler`, not here
- `MSADAgent/Agent/Helpers/CommonDnsMethod.cs` — shared helpers (zone-name validation, AD lookup)
- `MSADAgent/Agent.Tests/UnitTests/RequestHandlersTests/DnsZoneRequestHandlerRoutingTests.cs` — replication-scope allow-list test cases (table-driven `[Theory]`/`[InlineData]`)
- `MSADAgent/Agent.Tests/` — xUnit unit + integration tests

---

## Per-Repository Commands & Conventions

### CRITICAL: Read CLAUDE.md and Makefile First

**Before implementing any change:**

1. **Read `<repo>/CLAUDE.md`** — authoritative guide for that repo (purpose, build/test, coding rules, pitfalls, safety rules)
2. **Check `<repo>/Makefile`** — defines the actual commands to use:
   - `make fmt` (repo-specific formatter)
   - `make lint` (repo-specific linter)
   - `make test` (repo-specific test command)
   - `make vendor` (dependency management, Go repos)

**Do not use generic commands.** Always use Makefile targets.

### Build / Test / Lint Commands

### Setup: Docker for All Services

All repos with PostgreSQL or other services run them via Docker. **Do not install PostgreSQL locally.**

```bash
# Standard pattern for any repo needing services:
cd <repo>
docker-compose up -d            # start PostgreSQL, Redis, etc.
make test                       # tests assume services are running
docker-compose down             # cleanup
```

### Format & Lint Workflow (All Repos)

After code changes, run these **in order** and fix errors before proceeding:

```bash
make fmt                        # format code (repo-specific)
make lint                       # check for issues (repo-specific)
make test                       # run tests (repo-specific)
```

**Go repos only:** Before committing, also run:
```bash
go fix ./...                    # handle Go version migrations, deprecated APIs
make fmt                        # re-format after go fix
```

### ddi.dns.config (Go)

```bash
# Vendor management
make vendor                     # go mod tidy + download

# Test (requires docker-compose)
docker-compose up -d            # start PostgreSQL and other services
make test                       # runs gofmt check, then go test ./...
docker-compose down

# Race detection (optional, recommended for concurrent code)
docker-compose up -d
go test -race ./...
docker-compose down

# Profiling (when performance investigation needed)
go test -cpuprofile=cpu.prof -memprofile=mem.prof ./...
go tool pprof cpu.prof          # interactive CPU profile analysis
go tool pprof mem.prof          # interactive memory profile analysis

# Lint
golangci-lint run ./...         # via CI workflow
```

### ddi.cloud.proxy.middleware (Go)

```bash
# Vendor management
make vendor

# Test (requires docker-compose)
docker-compose up -d
make test
docker-compose down

# Race detection (recommended for interceptor & middleware code)
docker-compose up -d
go test -race ./...
docker-compose down

# Profiling (when investigating latency or memory issues)
go test -cpuprofile=cpu.prof -memprofile=mem.prof ./...
go tool pprof cpu.prof

# Lint
golangci-lint run ./...
```

### ddi.msad.collector (Go)

```bash
# Vendor management
make vendor

# Test (requires docker-compose)
docker-compose up -d
make test                       # runs fmt-atlas, then go test with flags
docker-compose down

# Race detection (critical for gRPC service code)
docker-compose up -d
go test -race ./...
docker-compose down

# Profiling (when investigating gRPC request latency)
go test -cpuprofile=cpu.prof -memprofile=mem.prof ./...
go tool pprof -http=:8080 cpu.prof   # web UI for profile visualization

# Lint
golangci-lint run --timeout=10m --verbose --new-issues-only
nilaway ./...                   # nil-safety static analysis (CI only on changed files)
```

### ddi.msad.agent (C#/.NET 8)

```bash
# Build
dotnet build MSADAgent\MSADAgent.sln -c Debug

# Test (local on Windows only)
dotnet test MSADAgent\Agent.Tests\Agent.Tests.csproj

# Coverage (Windows only)
dotnet test --collect:"XPlat Code Coverage"

# OR via build script
.\build_project.bat             # full build + MSI packaging (requires WiX 3.14)

# CI: Jenkins windows_node_ddi_msad_agent_label
# Runs: dotnet test MSADAgent\Agent.Tests\Agent.Tests.csproj (with coverage)
```

---

## Coverage & Integration Testing Requirements

### Coverage Thresholds (Non-Negotiable)

| Stack | Overall | New Code | Exempt Paths |
|---|---|---|---|
| **Go** (all repos) | ≥75% | ≥80% | None (but integration tests can cover gaps) |
| **C#** (ddi.msad.agent) | ≥70% | ≥75% | Windows-only cmdlet wrappers (must be flagged in PR) |

**How to measure & report:**

Go:
```bash
docker-compose up -d
go test -coverprofile=coverage.out ./...
go tool cover -func=coverage.out    # per-function breakdown
go tool cover -html=coverage.out    # open in browser for visual
docker-compose down
```

Report: "Overall coverage: XY%. New files: [list with %]. Files below threshold: [list with %; add integration tests to fix]."

C#:
```bash
dotnet test --collect:"XPlat Code Coverage"
# Coverage % shown in test result summary
```

### Integration Tests (When Mandatory)

Integration tests are **required** (not optional) when:

1. **DB schema changes** — new columns, constraints, or queries. Test: schema migration runs, data persists across restarts, queries return correct results.
2. **gRPC service changes** — new methods, request/response shape, error handling. Test: client builds correct request, server processes it, response matches contract.
3. **Error-code mapping changes** — new error codes or status mappings. Test: agent error → collector GetErrorCode() → ErrorCodeToStatus() → correct gRPC status.
4. **Proto changes** — collector or agent protos. Test: generated code compiles, contract respected by both sides.
5. **Middleware interceptor changes** — request/response transformation. Test: request routed correctly, interceptor transforms it, downstream service receives expected shape.
6. **Replication-scope validation changes** — new scope values, new validation rules. Test: zone create with each scope value, validator accepts/rejects correctly, DB stores scope.

**Pattern:**
```bash
# 1. Start full stack
docker-compose up -d

# 2. Run integration test (not just unit test)
# Example: drive zone creation through middleware → collector → DB
make test

# 3. Assert at multiple stages
# - Request validation passed
# - gRPC call succeeded
# - Collector response mapped to DB
# - Zone exists in DB with correct replication-scope
# - Retry/idempotency works

docker-compose down
```

**Red flags (escalate to user):**
- Change spans multiple repos (collector proto + middleware consumer) → integration test mandatory in both repos
- Change involves zone creation/update flow → include full-path integration test (API → middleware → collector → DB)
- Coverage drops below threshold without integration tests → surface and ask for integration tests, not just unit tests

---

## Known Conventions

### Source of Truth: Per-Repo CLAUDE.md

**Every repo (Go and C#) has a CLAUDE.md at the root.** This is the authoritative guide for that repo. Read it before making any changes.

CLAUDE.md contains:
- Repo purpose and architecture overview
- Build/test/lint/fmt commands (exact Makefile targets to use)
- Coding rules: error handling, logging, naming, package structure, safety rules
- Pitfalls and gotchas (e.g., "Registry access must go through Settings")
- Links to docs-manifest.yaml, taxonomy.yaml (Go repos)
- Any repo-specific tools or setup

**If CLAUDE.md says something different from this document, follow CLAUDE.md.**

### ddi.msad.agent (C#/.NET 8)

- **CLAUDE.md** at repo root: authoritative guide (build, test, coding rules, pitfalls)
  - Example rule: "Registry access must go through Settings library — core safety rule"
- **docs-manifest.yaml**, **taxonomy.yaml** — machine-readable doc indexes
- **Makefile** or build scripts: use `make lint`, `make fmt`, `make test` (or equivalent from CLAUDE.md)
- Proto committed alongside generated code (no separate codegen step)
- Logging/metrics conventions documented in CLAUDE.md
- xUnit for testing; follow naming conventions in Agent.Tests

### All Go repos (dns.config, middleware, collector, msadconnect.proxy)

- **CLAUDE.md** at repo root: authoritative. Makefile points to docs-manifest.yaml and taxonomy.yaml
- **Makefile** targets are normative:
  - `make fmt` (exact formatter for this repo)
  - `make lint` (exact linter(s) for this repo, e.g., golangci-lint, nilaway)
  - `make test` (exact test command)
  - `make vendor` (dependency management via go mod tidy + download)
  - Don't call `go test` or `golangci-lint` directly unless CLAUDE.md says to
- **Testing patterns (from inspection, but check CLAUDE.md):**
  - **sqlmock** for DB-context tests (middleware, collector, dns.config)
  - **gomock** for gRPC/interface mocks (`go.uber.org/mock`, not golang/mock)
  - **Table-driven tests** via `[]struct{ ... }` patterns with nested `Setup` functions (collector in particular)
  - **testify** for assertions
- **Code quality:**
  - `go fix ./...` before committing (handles Go version migrations, deprecated APIs)
  - Run `make fmt` after `go fix` to ensure consistent formatting
- **go.mod** declares the module; `make vendor` refreshes `vendor/` directory

---

## Git Commit Discipline

See **[git-commit-discipline.md](git-commit-discipline.md)** for detailed guidance on:
- Separating additions, modifications, deletions into separate commits
- Commit message format and structure
- No force-push policy
- Workflow examples (bad and good)

Quick summary:
- **Additions only** — new files, new tests (no changes to existing code)
- **Modifications only** — changes to existing code (no new files, no deletions)
- **Deletions only** — remove dead code (proven safe by grep)
- Each type gets its own commit
- Commit messages reference Jira ticket and explain why
- Never force-push; use `git revert` to undo mistakes
- Tests pass, coverage ≥ threshold before committing

---

## Cross-Repo Contracts to Watch

1. **Collector proto → Middleware client:** any change to `ddi.msad.collector/api/protobuf-spec/service.proto` must trigger `make protobuf` in the middleware to regenerate `pkg/pb/`.
2. **Error-code addition in collector:** if a new `ZONE-00x` agent error code is created, `ddi.msad.collector/pkg/util/util.go:ErrorCodeToStatus()` must be updated and tested (e.g., DDIDNS-10543 added `ZONE-005` → `codes.InvalidArgument`).
3. **Replication-scope validator change:** any update to `isValidMSADReplicationScope*` in the middleware must be echoed in validators across **both** `dns.config` and `dns.data` (currently mirrors in dns.config; dns.data mirrors will need parity once surveyed). Since the middleware is consumed by two independent WAPI services, validator-sync is now a 3-repo discipline, not 2-repo.
4. **Middleware consumed by two services:** `ddi.cloud.proxy.middleware` is now a shared dependency of both `ddi.dns.config` and `ddi.dns.data`. Changes to its request builders, interceptors, or error mappings require validation in both consumers to ensure consistent behavior.

---

## Dependency Repos (Not Core, Not Modified by Default)

These repos are **not part of the six-repo core list**, but are referenced/imported by them. Changes to these repos may affect MSAD epic work, but this toolkit does not own or modify them.

| Repo | Dependency Of | Local Path | Role | How to Update |
|---|---|---|---|---|
| **atlas.onprem.rpc.server** | ddi.msadconnect.proxy (dial target); ddi.msad.agent (proto contract) | `~/atlas.onprem.rpc.server` | Windows RPC/gRPC dispatcher server; proto-contract dependency for internal command routing | Changes to MSADAgent/Agent/Protos/RpcServer/service.proto may require syncing proto definitions or regenerating Go code from this repo's `pkg/pb/`. Check `ddi.msad.agent` and `ddi.msadconnect.proxy` protos for `go_package` headers pointing to this repo. |
| **atlas.onprem.common** | ddi.msadconnect.proxy (go.mod import) | `~/atlas.onprem.common` | Common utilities and types for Atlas services | Direct go.mod dependency; upgrade via `go get github.com/Infoblox-CTO/atlas.onprem.common@<version>` in ddi.msadconnect.proxy. |

### How to Discover More Dependency Repos

If a task scope expands beyond the six core repos, use these methods to find hidden dependencies (so this list doesn't go stale):

1. **grep go.mod/go.sum for Infoblox-CTO imports:**
   ```bash
   for repo in ddi.dns.config ddi.dns.data ddi.cloud.proxy.middleware ddi.msad.collector ddi.msadconnect.proxy ddi.msad.agent; do
     echo "=== $repo ===" 
     grep "github.com/Infoblox-CTO/" ~/$repo/go.mod | grep -v "^#"
   done
   ```
   List any `Infoblox-CTO/` imports not in the six-repo list.

2. **grep proto files for go_package headers:**
   ```bash
   find ~/ddi.msadconnect.proxy ~/ddi.msad.agent -name "*.proto" -exec grep "^option go_package" {} + | grep -v "ddi\." | grep -v "cloud.proxy"
   ```
   Any `go_package` pointing to a repo outside the five list indicates a proto-contract dependency.

3. **Check docs-manifest.yaml for dependencies:**
   ```bash
   grep -A 5 "dependencies:" ~/ddi.msadconnect.proxy/docs-manifest.yaml
   grep -A 5 "services:" ~/ddi.msadconnect.proxy/docs-manifest.yaml
   ```

**Don't assume a repo present under `~/` is a dependency** — confirm it via one of these signals first (go.mod import, proto go_package, or docs-manifest.yaml reference).

---

## Sync / Discovery Repos (MSAD Topology — Reverse Direction)

The six core repos above handle the **DDI → MSAD** direction (create/update/delete zones initiated from the Portal/API). A separate pair of repos handles the **MSAD → DDI** direction: discovering and syncing the state of *existing* Microsoft DNS zones (including ones created directly in AD, outside DDI) back into DDI. These are part of the MSAD topology and may be in scope for tasks about zone discovery, sync reconciliation, or reporting existing zone state (e.g., Legacy-scope zones, which can only ever arrive via sync — they are never creatable through the DDI → MSAD path; see `local path` / creation rules above).

| Repo | Local Path | Stack | Role | Build | Test |
|---|---|---|---|---|---|
| **cq-source-msad** | `~/cq-source-msad` | Go | CloudQuery source plugin — fetches zones/records from the MSAD collector service (`msad_collector_endpoint`), including `replication_scope` as reported by the live AD environment (no allow-list validation — reports whatever scope the zone actually has, including `legacy`) | `go build` | `make test` (`go test -timeout 10m ./...`), `make lint` |
| **cloud.discovery** | `~/cloud.discovery` | Go | Discovers resources from 20+ providers (including MSAD via `cq-source-msad`) and fans out to BloxOne DDI (via the `b1ddi` overlay adapter), IPAM, ClickHouse, Global Search. The MSAD-specific fetch/transform logic lives in `pkg/adapters/overlay/msad/cq_fetchers.go`; the DDI-write side is `pkg/adapters/overlay/b1ddi/` | `make generate` (proto), standard `go build` | `make test` (`lint-resourceMapping` + `unit-test`) |

**Key distinction for replication-scope work:** `cq-source-msad` and `cloud.discovery` are **read-only with respect to replication scope** — they report the scope Microsoft DNS already has (including `legacy`, for zones that predate DDI management or were never migrated). They do not validate or reject values; validation only happens on the **write** path (dns.config, middleware, agent — the six core repos), where `legacy` is correctly rejected at zone **creation** (a user can never create a new `legacy`-scope zone through DDI) but a zone with an existing `legacy` scope can still be synced in and displayed.

**Fork pattern:** Both repos already follow the standard fork setup (`origin` = personal fork, `upstream` = Infoblox-CTO) — see `CLAUDE.md` for the general pattern.

---

## Existing PR Discovery

When planning MSAD work, check for related open/merged PRs to avoid duplicating or conflicting with ongoing work. Use these commands (requires `gh` authenticated with GitHub):

### Core Six-Repo PRs

```bash
# List open PRs in each core repo
gh pr list --repo Infoblox-CTO/ddi.dns.config --state open --limit 15
gh pr list --repo Infoblox-CTO/ddi.dns.data --state open --limit 15
gh pr list --repo Infoblox-CTO/ddi.cloud.proxy.middleware --state open --limit 15
gh pr list --repo Infoblox-CTO/ddi.msad.collector --state open --limit 15
gh pr list --repo Infoblox-CTO/ddi.msadconnect.proxy --state open --limit 15
gh pr list --repo Infoblox-CTO/ddi.msad.agent --state open --limit 15

# Search for PRs mentioning a specific Jira ID (e.g., DDIDNS-7732)
gh pr list --repo Infoblox-CTO/ddi.dns.config --search "DDIDNS-7732" --limit 15
gh pr list --repo Infoblox-CTO/ddi.dns.data --search "DDIDNS-7732" --limit 15
```

### Dependency Repo PRs

If the task touches `ddi.msadconnect.proxy` or `ddi.msad.agent`, also check the dependency repos:

```bash
gh pr list --repo Infoblox-CTO/atlas.onprem.rpc.server --state open --limit 15
gh pr list --repo Infoblox-CTO/atlas.onprem.common --state open --limit 15
```

---

## MSAD Collector Test Client (cmd/testclient)

**Location:** `ddi.msad.collector/cmd/testclient/main.go`

**Purpose:** Standalone gRPC CLI for directly testing MSAD Collector Zones and Records services (full CRUD). Bypasses WAPI v3 and middleware, enabling fast collector-layer checks.

**When to use:** Faster than `msad-e2e-verify` for focused collector tests (e.g., validating a new replication-scope value, error-code mapping, or proto-level changes without spinning up the full dns.config + middleware stack).

**Setup Requirements:**

1. Start the collector server (in `~/ddi.msad.collector`):
   ```bash
   go run ./cmd/server --logging.level=debug --redis.enable=false
   ```
   Server listens on `localhost:9090` by default (insecure gRPC, no TLS needed for local testing).

2. Determine a valid MSAD Agent GUID to use as `--agent-id`. For testing:
   ```bash
   AGENT_ID="00000000-0000-0000-0000-000000000001"  # any valid GUID format
   ```

**Invocation Examples:**

```bash
cd ~/ddi.msad.collector

# List zones (requires server-ips flag, can be empty or mock IPs)
go run ./cmd/testclient --endpoint localhost:9090 --agent-id $AGENT_ID \
  zone list --server-ips 192.168.1.10,192.168.1.11

# Create a primary zone with replication scope
go run ./cmd/testclient --endpoint localhost:9090 --agent-id $AGENT_ID \
  zone create --zone-name example.com --zone-type 1 --comment "Test zone" \
  --replication-scope domain

# Create an A record
go run ./cmd/testclient --endpoint localhost:9090 --agent-id $AGENT_ID \
  record create --zone-name example.com --record-name www --record-type A \
  --address 192.168.1.100 --ttl 300

# JSON output mode (for scripting)
go run ./cmd/testclient --endpoint localhost:9090 --agent-id $AGENT_ID --json \
  zone create --zone-name example.com --zone-type 1 | jq .
```

**Supported Commands:**
- `zone list`, `zone create`, `zone update`, `zone delete`
- `record list`, `record get`, `record create`, `record update`, `record delete`

**Key Flags:**
- `--endpoint <host:port>` — collector gRPC address (default: localhost:9090)
- `--agent-id <guid>` — MSAD Agent Windows GUID (required)
- `--json` — output in JSON format
- `--timeout <duration>` — request timeout (default: 30s)
- `--replication-scope <local|domain|forest>` — zone replication scope (zone create only)
- `--zone-type <1-4>` — zone type (1=Primary, 2=Secondary, 3=Stub, 4=Forwarder)

**Known Documentation Gap:** This repo's `docs-manifest.yaml` still has a stale comment `# cli: — no CLI tool` under the `operations:` section. This is a follow-up for that repo's maintainers to update. The toolkit documents it here for reference.
