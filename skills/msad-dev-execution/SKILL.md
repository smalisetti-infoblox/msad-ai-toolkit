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

**Preference: Complete existing PRs before creating new ones.** If the plan's context section documents an existing draft/open PR for a task, dispatch `msad-backend-dev` against that PR's branch (checkout PR, add missing work, push updates). Only create new PRs if no existing PR is found.

Dispatch `msad-backend-dev` agents strictly per the plan's **"Parallel Execution Batches"** section (added by `/msad-dev-planning` Step 5a). This section computes batches by combining the cross-repo dependency DAG (Step 5) with file-level conflict analysis (Step 5a); it ensures no two packages that touch the same file are placed in the same parallel batch.

1. **For each batch in the plan:**
   - If batch size = 1 (sequential), dispatch that one agent and await completion.
   - If batch size > 1 (parallel), dispatch all agents in the batch in a single message (multiple `Agent` tool calls) and await all completions.
   - **Per package:** If existing PR exists (from plan's PR context), dispatch agent against PR branch; if not, agent creates new branch/PR

2. **Await agent completion per agent.** Agent returns: files changed, test results, implementation log.

3. **Record in the execution log:** which files were touched, test status, any flags the agent raised, per package.

State at start:
> Step 2 — Implementing. Plan has `<N>` batches, `<M>` total work packages.

State after each batch:
> Batch `<i>`/`<N>` done. `<K>` packages: `<task-ids>`. Tests: `<all pass/any fail>`.

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

## Step 4: Validation Loop (Bounded Code Review)

Execute the **bounded review loop** defined in `references/bounded-review-loop.md` with these parameters:

- **artifact:** "code diff" (the branch just implemented)
- **reviewer:** `msad-code-review` agent
- **max_rounds:** 3
- **severity_scheme:** MUST / SHOULD / MAY
- **convergence_condition:** zero MUST findings; SHOULD findings are either fixed or justified-and-logged
- **escalation_on_non_convergence:** stop at round 3, surface all findings + ledger to user; user decides (proceed / revise / abandon)

**Starting context for the code-review loop:** The approved plan (from `/msad-dev-planning`) contains:
- Existing PR context (blocking findings from prior reviews, current coverage/test status)
- Scenario→Test traceability table (what Gherkin ACs must be tested)
- This context informs what blockers *must* be addressed (not discovered fresh) and what prior attempts have been made

### Per iteration of the loop:

1. **Run `msad-code-review`** on the current branch (check the diff). Record findings.

2. **Triage findings** into MUST-fix, SHOULD-fix, MAY-fix.

3. **Apply fixes** for MUST-fix. For SHOULD-fix, either fix or record one-line justification in the ledger (requires user approval at end).

4. **Loop condition:**
   - If zero MUST and all SHOULD are fixed-or-justified → **CONVERGED**, exit loop, proceed to Step 5.
   - If MUST or unfixed SHOULD remain and iteration < 3 → loop again (fix → re-review).
   - If iteration ≥ 3 and MUST or unfixed SHOULD remain → **NON-CONVERGED**, surface to user with ledger.

### Implementation Critique Checklist (for msad-code-review to verify)

- [ ] Diff matches approved plan; out-of-scope changes flagged/removed
- [ ] New file paths and names follow repo conventions
- [ ] All MUST findings fixed or justified
- [ ] All SHOULD findings triaged
- [ ] Tests still pass after fixes
- [ ] No merge conflicts with origin main
- [ ] Every Gherkin scenario in the linked plan file's traceability table has a corresponding test in the diff (or is explicitly deferred)

**State per iteration:**
> Code-review round `<i>`/3 — `<F>` findings. Status: `<MUST/SHOULD counts, converged-or-continue>`.

**State on exit:**
> Validation converged after `<i>` round(s). `<F>` fixes, `<J>` justified. (Or: Non-converged after 3 rounds; see ledger.)

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

## Step 5a: Git Commit Discipline

Before opening a PR, commit changes in **strict order**: additions → modifications → deletions (separate commits per the plan).

### Commit Order

For each work package:

1. **Additions commit(s):**
   ```bash
   git add <new files, new test cases>
   git commit -m "Add <what>. New files: [list]. Purpose: [AC/reason]."
   ```
   Example: `Add replication-scope validator tests. New files: zones_test.go additions.`

2. **Modifications commit(s):**
   ```bash
   git add <changed files>
   git commit -m "Update/Fix <what>. Changed: [list]. Reason: [AC/reason]."
   ```
   Example: `Update zone validator to accept domain/forest scopes. Changed: stub_zone.go.`

3. **Deletions commit(s)** (if any):
   ```bash
   git add <deletions>
   git commit -m "Remove <what>. Deleted: [list]. Reason: [safe to remove]."
   ```

### Before Committing

1. **Review diff:** `git diff --cached` (no unintended changes)
2. **Check for secrets:** grep for credentials, tokens, API keys
3. **Run tests:** `make test` (all pass)
4. **Run lint:** `make fmt` && `make lint` (no errors)
5. **Verify coverage:** report % (if below threshold, add tests)
6. **Ask the user** before committing

### NO Force-Push

- **Never** use `git push --force` or `git push -f`
- **Never** use `git reset --hard origin/main`
- If you need to undo a commit after pushing, use `git revert` or create a new fixup commit
- If push fails due to a hook, investigate and fix the issue (don't use `--no-verify`)

---

## Step 6: PR Creation

For each work package's repo, open a **draft PR** via `gh pr create --draft`:

**PR Title:** `<TASK-ID>: <imperative summary>` (e.g., `DDIDNS-10519: Validate Domain/Forest replication scope in middleware`)

**PR body includes:**

```markdown
## What Changed
<Bullet list of concrete changes, file-by-file or concern-by-concern. Derived from the approved plan's "Changes (by type)" — additions / modifications / deletions.>

## Why It's Needed
<1-3 sentences: the user-facing or system problem this solves, linked to the story's Gherkin scenario(s) / AC(s). Reference: "Implements Scenario: <name> (Jira: DDIDNS-XXXXX AC#)".>

## How It's Implemented
<Short technical narrative: key functions/files touched, the approach taken (e.g., "extended the allow-list in isValidMSADReplicationScopeForZoneCreate() and mirrored the change in dns.config's validateStubZoneReplicationScopeNotLegacy()"). Cross-repo/contract notes (proto regen, validator sync) called out explicitly.>

## Acceptance Criteria / Scenario Traceability
| Scenario / AC | Test(s) |
|---|---|
| AC1 (Scenario: Domain scope) | pkg/msad_zone_helper_test.go:TestZoneCreate_DomainScope |
| AC2 (Scenario: Legacy scope rejected) | pkg/service/application/stub_zone_test.go:TestReject_LegacyScope |

## Tests
- Unit: <pass/fail>, coverage: <X%> (threshold: <Y%>)
- Integration: <pass/fail/n/a>
- Race detection: <pass/n/a>
- E2E: <run/n/a>

## Future Work / Deferred
<Anything explicitly out of scope for this PR, with a linked follow-up ticket if one exists. "None" if truly nothing deferred.>

## Optimizations / Trade-offs Considered
<Any performance/design trade-offs made and why (e.g., "chose allow-list over regex validation for readability; no measurable perf difference per profiling"). "None" if not applicable.>

## Known Issues / Deferred Review Findings
<Any SHOULD-level findings from the bounded code-review loop that were justified rather than fixed, with the justification. From the review ledger.>

## Cross-Repo Links
<"Part of DDIDNS-XXXXX" / "Depends-On DDIDNS-YYYYY" / "Tracked in DDIDNS-ZZZZZ">
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
