# MSAD Repo Topology & Build Reference

This document maps the five-repo ecosystem supporting the DDIDNS-7732 epic (Microsoft DNS zone creation / replication scope), lists build/test/lint commands, and identifies key files where replication-scope validation lives at each layer.

## Repo Summary Table

| Repo | Stack | Role | Local path | Build | Test |
|---|---|---|---|---|---|
| **ddi.dns.config** | Go 1.23+ | WAPI v3 API surface; owns replication-scope validation | `~/ddi.dns.config` | `make vendor` | `make test` |
| **ddi.cloud.proxy.middleware** | Go 1.23+ | gRPC interceptor library; MSAD request translation | `~/ddi.cloud.proxy.middleware` | `make vendor` | `make test` |
| **ddi.msad.collector** | Go 1.23+ | gRPC microservice; error-code mapping | `~/ddi.msad.collector` | `make vendor` | `make test` |
| **ddi.msadconnect.proxy** | Go (not yet surveyed) | Windows RPC/LDAP bridge | `~/ddi.msadconnect.proxy` | `make vendor` | `make test` |
| **ddi.msad.agent** | C#/.NET 8 (net8.0-windows) | Windows Service; PowerShell zone controllers | `~/ddi.msad.agent` | `dotnet build MSADAgent\MSADAgent.sln -c Debug` | `dotnet test MSADAgent\Agent.Tests\Agent.Tests.csproj` |

**Windows CI note:** `ddi.msad.agent` tests run on a Jenkins node labeled `windows_node_ddi_msad_agent_label` — the only way to verify PowerShell/LDAP cmdlet execution. No local Mac/Linux execution possible.

---

## Request Flow & Validation Points

```
WAPI v3 (dns.config)
  ↓ [zone create/update]
Cloud Proxy Middleware (ddi.cloud.proxy.middleware)
  ↓ [gRPC call]
MSAD Collector (ddi.msad.collector)
  ↓ [gRPC call]
MSAD Connect Proxy (ddi.msadconnect.proxy)
  ↓ [Windows RPC/LDAP]
MSAD Agent (ddi.msad.agent)
  ↓ [PowerShell]
Add-DnsServerPrimaryZone / Set-DnsServerPrimaryZone
```

### Replication-Scope Validation Today

| Layer | File(s) | Validation | Issue |
|---|---|---|---|
| **dns.config** | `pkg/service/application/stub_zone.go:~1198` | `validateStubZoneReplicationScopeNotLegacy()`, `isADRestrictedScope()` — allows `local`/`domain`/`forest`, rejects `legacy` at creation; scope-change mostly forbidden except in stub zones | Partial — Auth zones don't allow scope changes (DDIDNS-10547 work in progress) |
| **middleware** | `pkg/msad_zone_helper.go:187,200` | `isValidMSADReplicationScopeForZoneCreate()`, `isValidMSADReplicationScopeForStubZone()` — allow-list is `local`/`domain`/`forest` | Correct (mirrors dns.config) |
| **collector** | `pkg/svc/zones/zones.go` | No validation; passes `ErrorCodeToStatus` mapping but doesn't reject bad scopes | Correct (validation is upstream responsibility) |
| **proxy** | TBD | TBD | TBD |
| **agent** | `MSADAgent/Agent/Core/DnsInfoControllers/DnsPrimaryZoneController.cs:~line ~80-110` | **NONE** — passes `replicationScope` straight into PowerShell `-ReplicationScope "{replicationScope}"` with no allow-list check | **DDIDNS-10521 gap** — validation needed |

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

- `MSADAgent/Agent/Core/DnsInfoControllers/DnsInfoZoneControllers/DnsPrimaryZoneController.cs` — `Create()` / `Update()` for Primary zones; **no replication-scope validation**
- `MSADAgent/Agent/Core/DnsInfoControllers/DnsInfoZoneControllers/DnsConditionalForwarderZoneController.cs` — `Create()` / `Update()` for Forward zones; **no replication-scope validation**
- `MSADAgent/Agent/Helpers/CommonDnsMethod.cs` — shared helpers (zone-name validation, AD lookup)
- `MSADAgent/Agent.Tests/` — xUnit unit + integration tests

---

## Build / Test / Lint Commands

### ddi.dns.config (Go)

```bash
# Vendor management
make vendor                     # go mod tidy + download

# Test
make test                       # runs gofmt check, then go test ./...

# Lint
golangci-lint run ./...         # via CI workflow
```

### ddi.cloud.proxy.middleware (Go)

```bash
# Vendor management
make vendor

# Test
make test

# Lint
golangci-lint run ./...
```

### ddi.msad.collector (Go)

```bash
# Vendor management
make vendor

# Test
make test                       # runs fmt-atlas, then go test with flags

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

# OR via build script
.\build_project.bat             # full build + MSI packaging (requires WiX 3.14)

# CI: Jenkins windows_node_ddi_msad_agent_label
# Runs: dotnet test MSADAgent\Agent.Tests\Agent.Tests.csproj
```

---

## Known Conventions

### ddi.msad.agent

- **CLAUDE.md** at repo root: concise AI-assistant guide (repo purpose, build/test, coding rules, pitfalls)
- **docs-manifest.yaml**, **taxonomy.yaml** — machine-readable doc indexes
- Registry access: **must go through Settings library** — core safety rule
- Proto committed alongside generated code (no separate codegen step)
- Logging/metrics conventions documented in CLAUDE.md

### All Go repos

- **CLAUDE.md** points to `docs-manifest.yaml` and `taxonomy.yaml` as authoritative
- **Makefile** targets are normative (test, vendor, lint commands defined there, not inline)
- **sqlmock** for DB-context tests (middleware, collector, dns.config)
- **gomock** for gRPC/interface mocks (`go.uber.org/mock`, not golang/mock)
- **Table-driven tests** via `[]struct{ ... }` patterns with nested `Setup` functions (collector in particular)
- **testify** for assertions
- **go.mod** declares the module; `make vendor` refreshes `vendor/` directory

---

## Cross-Repo Contracts to Watch

1. **Collector proto → Middleware client:** any change to `ddi.msad.collector/api/protobuf-spec/service.proto` must trigger `make protobuf` in the middleware to regenerate `pkg/pb/`.
2. **Error-code addition in collector:** if a new `ZONE-00x` agent error code is created, `ddi.msad.collector/pkg/util/util.go:ErrorCodeToStatus()` must be updated and tested (e.g., DDIDNS-10543 added `ZONE-005` → `codes.InvalidArgument`).
3. **Replication-scope validator change:** any update to `isValidMSADReplicationScope*` in the middleware must be echoed in `dns.config`'s equivalent validators to stay in sync (currently they're mirrors).
