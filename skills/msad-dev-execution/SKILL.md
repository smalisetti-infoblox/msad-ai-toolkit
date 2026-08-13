---
name: msad-dev-execution
description: "Executes an approved MSAD implementation plan task-by-task. Invokes msad-backend-dev agent in plan order, runs test suite, validates with bounded review loop, runs final checks, and opens draft PR. Use after /msad-dev-planning produces an approved plan file. Don't use without an approved plan — invoke /msad-dev-planning first."
version: 0.1.0
created_by:
  name: Claude Code
  role: AI SDLC for MSAD epic
---

# MSAD Developer — Execution

Reads an approved plan file and runs it end-to-end: implementation → bounded review validation loop → final checks → draft PR creation.

## Inputs

- **plan_identifier** (required): One of:
  - **Full path:** `/path/to/plan.md` (absolute path to approved plan file)
  - **Jira ID:** `DDIDNS-7732` (auto-discovers most recent `YYYY-MM-DD-DDIDNS-7732-plan.md` in `specs/msad-dev-plans/`)
  - **Plan name only:** `2026-08-13-DDIDNS-7732-plan.md` (searches `specs/msad-dev-plans/` for exact match)

## Process Overview

```
Read plan (status: approved)
  ↓
For each work package:
  ├─ Dispatch msad-backend-dev agent
  ├─ Run tests (go test / dotnet test)
  ├─ Validation loop (bounded, ≤ 3 rounds):
  │   ├─ Run msad-code-review
  │   ├─ Triage findings (fix or justify)
  │   ├─ Re-review until clean OR capped at 3
  │   └─ Surface if non-converged
  └─ [next package]
  ↓
Final checks: pre-push-checker (if available for Go repos)
  ↓
Open draft PR per repo
  ↓
Done
```

## Step 1: Resolve & Verify

1. **Resolve the plan file path:**
   - If input is an absolute path (starts with `/`), use it directly
   - If input is a Jira ID (e.g., `DDIDNS-7732`), search `specs/msad-dev-plans/` for the most recent `YYYY-MM-DD-DDIDNS-7732-plan.md`
   - If input is a filename (e.g., `2026-08-13-DDIDNS-7732-plan.md`), search `specs/msad-dev-plans/` for exact match
   - If no plan found, error and ask user for full path or correct Jira ID

2. **Verify the plan file:** Read the plan file and parse frontmatter.
   - Refuse to proceed unless `status: approved`. Tell the user to run `/msad-dev-planning <jira-id>` to create and approve a plan.
   - If multiple approved plans exist for the same Jira ID, ask user which one (or use most recent)

3. **Check autonomous flag:** If `autonomous: true`, skip the soft confirmation at Step 12.

## Step 2: Implementation

For each work package in the plan's implementation section:

1. **Dispatch an `msad-backend-dev` agent instance** for that repo/task, passing the task ID and repo path.
   - For independent work packages (no cross-repo dependency), dispatch multiple agents in parallel (single message, multiple `Agent` tool calls).
   - For dependent packages (e.g., proto change must land before middleware PR that consumes it), dispatch sequentially.

2. **Await agent completion.** Agent returns: files changed, test results, implementation log.

3. **Record in the execution log:** which files were touched, test status, any flags the agent raised.

State at start:
> Step 2 — Implementing. Plan has `<N>` work packages.

State after each:
> Package `<i>`/`<N>` done — `<repo>` `<task-id>`. Tests: `<pass/fail>`.

## Step 3: Per-Repo Testing & Validation

Before running tests, **agents must follow each repo's specific conventions** from its CLAUDE.md and Makefile:

- **Lint/Format workflow:** `make fmt` → `make lint` → `make test` (exact order, exact commands from Makefile)
- **Go-specific:** `go fix ./...` before committing (handles Go version migrations)
- **Coverage:** Report % and flag files below threshold
- **Race detection:** Required for concurrent code (middleware, interceptor, gRPC handlers)
- **Profiling:** Optional but recommended for latency-sensitive changes

### Test Suite Execution (Docker-Based) with Coverage Validation

For each work package's repo, run the standard test suite with Docker for all service dependencies, then validate coverage.

### Go Repos (ddi.dns.config, ddi.cloud.proxy.middleware, ddi.msad.collector, ddi.msadconnect.proxy)

```bash
cd <repo>
docker-compose up -d            # starts PostgreSQL, Redis, etc. — do NOT use local database
make test                       # runs tests against docker services
docker-compose down             # cleanup
```

**Coverage check (required):**
```bash
docker-compose up -d
go test -coverprofile=coverage.out ./...
go tool cover -func=coverage.out | grep total         # see overall %
go tool cover -html=coverage.out                      # visual report
docker-compose down
```

**Thresholds:**
- **Overall:** ≥75% (Go)
- **New/changed files:** ≥80%
- **Report:** per-file breakdown; flag any file below threshold

**Race detection (required for concurrent code):**
```bash
docker-compose up -d
go test -race ./...              # for middleware, collector, interceptor code
docker-compose down
```
If race detector finds a data race, stop and hand back to agent: "Race detected in [function]. Fix and re-test with `-race`."

**Performance profiling (if latency-sensitive code changed):**
```bash
# CPU profile: zone creation, interceptor, error-code mapping
docker-compose up -d
go test -cpuprofile=cpu.prof -memprofile=mem.prof -run TestZoneCreate ./...
go tool pprof -http=:8080 cpu.prof
docker-compose down
```
Report: "Profiling shows [top functions]. No regressions detected." Or if regression: escalate to user with findings.

**Failure handling:**
- If PostgreSQL fails to start, check `docker-compose logs postgres` for errors. Common: port 5432 in use — run `docker-compose down && docker-compose up -d`.
- If tests hang on DB connection, add explicit wait: `docker-compose up -d && sleep 5 && make test`.
- If coverage is below threshold: **do not proceed**. Hand back to agent with: "Coverage is XY%; need ≥75% overall, ≥80% for new code. Add integration tests to cover the gap."

### Integration Tests (When Required)

Integration tests are **mandatory** when changes cross service/layer boundaries:

**Trigger cases:**
- DB schema changes (new columns, new tables)
- gRPC service changes (new methods, request/response changes)
- Error-code mapping changes (new error codes added/changed)
- Proto changes (collector or agent protos)
- Request/response transformation (middleware interceptor changes)

**Pattern:**
1. Start docker stack (postgres, mocked downstream services)
2. Drive full flow through the changed code path
3. Assert on results at multiple stages: request validation → service call → DB write → response
4. Example: zone creation with replication scope → validate request → gRPC call → collector response → DB read → assert scope persisted

**Tools:** sqlmock for DB context, gomock for gRPC/interface mocks, existing test fixtures in the repo.

### C# Agent (ddi.msad.agent)

```bash
# Windows-only. Local testing not possible on Mac.
# This runs on Windows CI: jenkins windows_node_ddi_msad_agent_label
# Coverage is checked by Windows CI before merge.
dotnet test MSADAgent\Agent.Tests\Agent.Tests.csproj  # for documentation; won't run on Mac
```

**State:**
> Tests: unit `<pass/fail>`, integration `<pass/fail/required>`. Coverage: `<X>%` (threshold: ≥75%). Services via Docker ✓

Stop and surface if any test fails that wasn't caught by the agent. Fix or hand back to the agent for a second attempt. **Do not proceed if coverage is below threshold without explicit justification.**

## Step 4: Validation Loop (Bounded)

A **bounded loop with `msad-code-review` as the validator.** Hard cap: **3 iterations.**

### Per iteration:

1. **Run `msad-code-review`** on the current branch (or the changed files if tool supports scoping to a range). Record findings.

2. **Triage findings:**
   - **MUST fix** — fix before next review iteration, OR record a one-line justification in the ledger (must be approved by user at end).
   - **SHOULD fix** — fix unless cost is clearly disproportionate; record any deferral in the ledger.
   - **MAY fix / INFO** — fix opportunistically or skip.

3. **Implementation Critique Checklist:**
   - [ ] Diff matches approved plan; out-of-scope changes flagged/removed
   - [ ] New file paths and names follow repo conventions
   - [ ] All MUST findings fixed or justified
   - [ ] All SHOULD findings triaged
   - [ ] Tests still pass after fixes
   - [ ] No merge conflicts with origin main

4. **Loop condition:**
   - If zero MUST and zero SHOULD remaining → **exit loop, proceed to final checks**
   - If findings remain but cost to fix is disproportionate → **document justification in ledger**
   - If iteration ≥ 3 and findings persist → **stop, surface to user** (non-convergence usually signals a design call)

State per iteration:
> Validation round `<i>` — `<F>` findings. Status: `<fixed / re-review>`.

State on exit:
> Validation converged after `<i>` iteration(s). `<F>` fixes, `<J>` justified.

## Step 5: Final Checks

### Pre-push Validation (Go repos only)

If the repo has a `ddi:pre-push-checker` skill or equivalent linter/build gate, run it:

```bash
make lint              # or per-repo command
go vet ./...
```

Fix any errors. If unrecoverable, surface and ask user how to proceed. Do not push if pre-push fails (unless explicitly requested for a draft PR with known issues).

### Windows CI Acknowledgment (ddi.msad.agent only)

For changes to `ddi.msad.agent`, acknowledge explicitly:

> `ddi.msad.agent` tests will run on Windows CI (`windows_node_ddi_msad_agent_label` Jenkins node). Local verification is not possible on Mac. PR will be reviewed, then CI-verified before landing.

## Step 6: PR Creation

For each work package's repo, open a **draft PR** via `gh pr create --draft`:

**PR body includes:**

```markdown
## Summary
<one paragraph: what + why, from approved plan>

## Jira
<link to task ID(s)>

## Changes
<file list grouped by area>

## Tests
- Unit: <pass/fail>
- Integration: <pass/fail/n/a>
- E2E: <run/n/a>

## MSAD-Specific Notes
<any idempotency/rollback notes, error-code mappings, replication-scope validation, etc. — from agent findings or code-review checklist>

## Cross-Repo Links
<if this package depends on or is depended-upon by another PR, link them with "Part of DDIDNS-XXXXX" or "Tracked in DDIDNS-XXXXX">

## Known Issues / Deferred
<any MUST/SHOULD findings that were justified + ledger entries>
```

**State:**

> Step 6 — PR opened: `<URL>` (draft).

## Anti-Patterns

- Don't run without an approved plan. Refuse if frontmatter `status` ≠ `approved`.
- Don't skip the validation loop. Review-before-PR is mandatory; bounded loop prevents infinite iteration.
- Don't push to main. Draft PRs only (`--draft` flag).
- Don't loop more than 3 iterations — surface to user instead.
- Don't silently skip pre-push checks — record deferral with reason.

## Error Handling

- **Plan frontmatter `status` ≠ `approved`**: refuse. Tell the user to invoke `/msad-dev-planning <plan-path>` first.
- **Agent dispatch fails:** surface the error. Ask user to retry agent or execute that step freehand.
- **Tests fail after implementation:** agent should have caught this; if not, fix and re-run agent or fix freehand + run tests again.
- **Validation loop doesn't converge after 3 iterations:** stop. Surface remaining MUST/SHOULD findings — usually signals a design call or scope issue.
- **Pre-push-checker fails:** never push. Offer to investigate, fix, or hand back.
- **Cross-repo dependency not met:** if PR A depends on PR B (landed first), hold PR A as draft until B merges.
- **`gh pr create --draft` fails:** surface the error (auth, branch protection, etc.) and offer to retry or draft manually.
