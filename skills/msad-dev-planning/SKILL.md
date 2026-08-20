---
name: msad-dev-planning
description: "Produces an MSAD implementation plan for a Jira epic/story/task. Reads the ticket, gathers repo context, identifies per-repo work packages, surfaces clarifying questions, writes a plan file, and hard-gates on user approval. Use when working on an MSAD feature. Don't use for one-off code edits — invoke /msad-dev-planning for any MSAD task first."
version: 0.1.0
created_by:
  name: Claude Code
  role: AI SDLC for MSAD epic
---

# MSAD Developer — Planning

Produces a structured, reviewable implementation plan for an MSAD Jira epic, story, or task. Writes the plan to disk so it survives `/clear` and can be picked up by `/msad-dev-execution`.

## Inputs

- **jira_id** (required): Jira issue ID, e.g., `DDIDNS-7732` (epic) or `DDIDNS-10519` (task)

## Output

A plan file at `specs/msad-dev-plans/YYYY-MM-DD-<jira-id>-plan.md` with frontmatter:

```yaml
---
jira: DDIDNS-XXXXX
repos: [ddi.dns.config, ddi.cloud.proxy.middleware]    # affected repos
status: draft                                           # set to "approved" by user
created: YYYY-MM-DD
---
```

## Process

```
Step 1: Intake
  ↓
Step 2: Jira analysis (epic + linked stories/tasks + Backend/Frontend classification)
  ↓
Step 3: Repo context (grep prior work, test patterns)
  ↓
Step 4: Per-repo impact (what changes in each repo, explicit 'touches' files)
  ↓
Step 5: Identify cross-repo dependencies (proto, validators, etc. — builds DAG)
  ↓
Step 5a: Conflict-aware task batching (file-overlap analysis, parallel batch plan)
  ↓
Step 6: Clarifying questions (if any)
  ↓
Step 7: Write plan (including Gherkin scenarios + traceability table per package)
  ↓
Step 7b: Bounded plan review (≤3 rounds, fresh-context reviewer, ledger-tracked)
  ↓
Step 8: USER APPROVAL GATE
  ├─ Approve as-is → done, status → approved
  ├─ Approve with edits → revise plan, re-run review, re-present
  └─ Reject → return to step 6
```

## Step 1 — Intake (Deduplication Check)

1. Classify the input:
   - **Jira ID matching `^DDIDNS-\d+$`**: proceed to step 2.
   - **Jira URL containing a matching ID**: extract the ID; proceed to step 2.
   - **Prose with no ticket**: ask the user for a `DDIDNS-XXXXX` ID before proceeding — don't guess.
   - **Anything else**: ask the user which Jira ID to plan against.

2. **DEDUPLICATION CHECK** (prevent duplicate plans):
   - Search `specs/msad-dev-plans/` for existing plan file: `*-<jira-id>-plan.md`
   - If found:
     - Show file path, creation date, and `status` field (draft or approved)
     - If `status: approved`: "Plan already exists and is approved. Use `/msad-dev-execution <path>` to run it."
     - If `status: draft`: "Plan already exists (draft). Improve it? Show plan for review. Or create new? (yes/no/show-existing)"
     - If user says Yes (create new): proceed with new plan file (timestamped suffix distinguishes)
     - If user says No: reuse existing plan, offer to review/update it

3. Detect primary repo mapping via `references/repo-topology.md`:
   - Service/component mentioned in the task maps to one or more repos.
   - Note all repos involved (may be multi-repo epic).

4. State: *"Step 1 — Intake. Repos: `<list>`, ticket: `<jira-id>`. Existing plan: [none/draft/approved]."*

## Step 2 — Jira Analysis

Use Atlassian MCP tools:
- `getJiraIssue` for the ticket (summary, description, AC, components, status, fix versions)
- `getJiraIssue` for parent epic if this is a story/task
- `getJiraIssue` for each linked ticket (blocks / blocked-by / relates-to)

Produce a structured summary: **fact** (verbatim from Jira), **inference** (derived), **assumption** (proceeding without confirmation).

## Step 2b — Functional Area Classification (Backend vs. Frontend/UI)

Classify each linked ticket (epic's stories/tasks) as **Backend**, **Frontend/UI**, or **QA/Testing** using keyword matching against the ticket's summary/title. See `references/functional-area-classification.md` for the authoritative signal list (do not duplicate it here — cite the reference).

**Output:** A **Scope Boundaries** table marking each ticket:
- ✅ **Backend** (in scope for this toolkit, will be dispatched to `msad-backend-dev`)
- 🚫 **Frontend/UI** (out of scope, not implemented by `msad-backend-dev`, managed by a separate team/track)
- ❓ **QA/Testing** (handled separately, typically via `msad-e2e-verify` or excluded)

Example:

| Task | Classification | Summary | Notes |
|---|---|---|---|
| DDIDNS-10519 | ✅ Backend | Middleware: Domain/Forest scope | Will be dispatched |
| DDIDNS-10544 | 🚫 Frontend/UI | Portal selector for replication scope | Separate track, excluded from dispatch |
| DDIDNS-10546 | ✅ Backend | DNS Config: audit logging | Will be dispatched |

### Questions to Surface

- **Is this ticket part of DDIDNS-7732 (Microsoft DNS zone creation epic)?** If yes, run `gh pr list` (Step 3 below) to discover current related work dynamically, rather than using stale hardcoded PR numbers.
- **Does this change a replication-scope validator or create a new one?** If yes, flag that mirrors must be updated (dns.config ↔ middleware).
- **Does this touch a proto file?** If yes, flag that vendored generated code in downstream repos must be regenerated.
- **Does this involve the Windows agent (ddi.msad.agent)?** If yes, note that local testing is impossible; Windows CI is the verification gate.

## Step 3 — Repo Context (Backend-Only for This Toolkit)

Note: After Step 2b classification, Step 3 and onwards focus only on **Backend-classified tickets**. Frontend/UI tickets (🚫) are documented in the plan's Scope Boundaries but not analyzed for repo context or implementation details in this toolkit.

### Read Per-Repo CLAUDE.md (CRITICAL)

For each involved repo, **read the CLAUDE.md at the repo root.** This is the authoritative guide and contains:
- Repo purpose, architecture, build/test commands
- Coding rules and conventions specific to that repo
- Safety rules and pitfalls (e.g., ddi.msad.agent: "Registry access must go through Settings library")
- Links to docs-manifest.yaml, taxonomy.yaml

Recording example:
> - **ddi.dns.config/CLAUDE.md:** Zone validation happens in pkg/service/application/. Use table-driven tests with sqlmock. Replication-scope validators must stay in sync with middleware. See docs-manifest.yaml for architecture diagram.
> - **ddi.cloud.proxy.middleware/CLAUDE.md:** Interceptor code is performance-critical; profile before merging. Use gomock for gRPC mocks. Must regenerate pkg/pb/ when collector proto changes (`make protobuf`).

### Local Git Search

For each involved repo, search for prior similar work:

```bash
git log --grep '<keyword>' --oneline -n 20
git log -S '<symbol>' --oneline -n 20
grep -rn '<keyword>' --include='*.go' --include='*.cs' pkg/ | head -20
```

Record: likely files/packages, prior implementations, existing test patterns (table-driven in collector, sqlmock in middleware, xUnit in agent), relevant ADRs/docs.

### Existing PR Discovery + Review Analysis

Before writing the plan, discover related open/merged/draft PRs in the affected repos. Use `gh pr list` (see `references/repo-topology.md` "Existing PR Discovery" for exact commands and repo slugs):

```bash
# Example: search for PRs mentioning the epic ID
gh pr list --repo Infoblox-CTO/ddi.msad.collector --search "DDIDNS-7732" --limit 15
gh pr list --repo Infoblox-CTO/ddi.cloud.proxy.middleware --search "DDIDNS-7732" --limit 15
# ... repeat for all involved repos
```

**For each discovered PR (including draft PRs):**
1. **Fetch full PR details:** `gh pr view <PR-URL> --json title,body,state,reviews,comments`
2. **Parse PR comments/reviews:**
   - **Blocking findings** (must address before plan): "coverage below threshold", "missing tests", "validator drift"
   - **Non-blocking feedback** (should address, can be justified): "refactoring suggestion", "performance consideration"
   - **Informational** (acknowledge in plan): "design notes", "cross-repo implications"
3. **Record in plan's "Context" section:**
   - PR URL, current state (DRAFT/OPEN/MERGED), identified gaps (from PR description or comments)
   - Blocking vs. non-blocking feedback summary
   - Current test status / coverage from PR (if visible)

This gives the bounded-review-loop (Step 7b) and later the code-review loop (msad-dev-execution Step 4) starting context: what issues already exist, what's been tried, what must be addressed.

Cross-reference any related PRs in the plan's "Context" section (see Step 7 template below) instead of relying on hardcoded PR numbers that go stale.

### Dependency Repo Discovery

If the task involves `ddi.msadconnect.proxy` or `ddi.msad.agent`, apply the dependency-discovery methods from `references/repo-topology.md` "Dependency Repos" section to check whether `atlas.onprem.rpc.server` (proto contract) or `atlas.onprem.common` (go.mod dep) are in scope. Even if no code changes are needed there, surface them in the plan's Context section as "dependency repos in scope" for traceability.

## Step 4 — Per-Repo Impact

For each repo, identify what changes:

| Impact Area | Examples |
|---|---|
| **Validation** | New/changed replication-scope validator, error messages |
| **Request builders** | New gRPC request method (middleware), PowerShell cmdlet args (agent) |
| **Error handling** | New error code (agent) → new `ErrorCodeToStatus` mapping (collector) |
| **Tests** | Unit tests, integration tests, sqlmock fixtures |
| **Idempotency** | Pre-flight duplicate check, rollback pattern |
| **Docs / taxonomy** | Update `docs-manifest.yaml`, `taxonomy.yaml`, ADRs |
| **Build / lint / test** | Use the Makefile targets from CLAUDE.md (`make fmt`, `make lint`, `make test`) — do NOT assume generic commands work |

Per repo, classify each area as **likely**, **possible**, or **not-applicable** with a one-line reason.

**Important:** Note the specific Makefile targets each repo requires. For example:
- ddi.dns.config: `make fmt`, `make test`, `make lint`
- ddi.msad.agent: `dotnet build`, `dotnet test` (or `make` equivalents if defined)
- ddi.msad.collector: `make fmt`, `make test` (with nilaway checks in CI)

These are discovered from CLAUDE.md and Makefile; agents will run these exact commands during implementation.

## Step 5 — Cross-Repo Dependencies

Identify ordering constraints:

- **Proto change → downstream regeneration:** if collector proto changes, middleware must `make protobuf`.
- **Validator sync:** if a validator changes in one repo, mirrors in others must be updated in the same PR or a linked PR (flag explicitly).
- **Error-code addition:** if agent introduces a new code, collector's `ErrorCodeToStatus()` must be updated before/with the middleware PR that consumes it.

Document as a DAG (directed acyclic graph) of work packages:

```
Package A (collector proto change)
  ↓
Package B (middleware, consumes changed proto)
  ↓
Package C (dns.config, mirrors validator from B)
```

Parallel packages (no dependency) can be executed simultaneously via the execution skill.

## Step 5a — Conflict-Aware Task Batching

After the dependency DAG is complete, add a second dimension: **file/package overlap**.

For each work package, explicitly track which files it touches (already gathered informally in Step 4; now formalize it):
- `touches: [pkg/msad_zone_helper.go, pkg/interceptor_handlers.go]` per package

**Conflict rule:** Two work packages in the **same repo** conflict if:
- Their `touches` sets intersect (same file), OR
- Both require regenerating the same generated-code pair (e.g., both need `make protobuf`)

**Batching rule:** Conflicting packages are **never placed in the same parallel dispatch batch**, even if logically independent. Instead, sequence them so package B waits for package A's PR to land or at least branch to be pushed, allowing B to rebase.

Compute batches via topological layering (existing DAG) + greedy graph coloring on the conflict graph. Write a new "Parallel Execution Batches" plan section:

```
## Parallel Execution Batches

Batch 1 (parallel): Package A (dns.config), Package C (collector)   
  # no shared files, no dependency
  
Batch 2 (parallel): Package B (middleware)                          
  # depends on A; no file conflicts
  
Batch 3 (sequential, after B lands): Package D (middleware, same file as B)
  # file conflict with B; must sequence
```

**Small-diff bias:** Flag any single package whose `touches` set exceeds a threshold (e.g., >5 files or >2 distinct concerns) as a candidate for further splitting. Push back to Step 4 to decompose further — this directly serves "small, single-concern diffs" for easier review.

See `references/bounded-review-loop.md` for the execution model that consumes this section.

## Step 6 — Clarifying Questions

List open questions:

- **Blocking** — can't produce a sensible plan without it (changes scope or changes which repos are involved).
- **Non-blocking** — useful but a reasonable default exists.
- **Assumption** — proceeding unless corrected, record in ledger.

Ask only what can't be answered from Jira, the repo, or linked tickets. If the answer is in the repo, go answer it first.

**Red flag:** If you can't determine which repos are involved, or if the task is silent on replication-scope constraints (creation vs. update), ask explicitly.

## Step 7 — Write Plan with Explicit Scope Boundaries

Plan file template (mandatory sections — note: Scope Boundaries section is now mandatory and references the Step 2b classification):

```markdown
---
jira: DDIDNS-XXXXX
repos: [ddi.dns.config, ddi.cloud.proxy.middleware, ...]
status: draft
created: YYYY-MM-DD
---

# DDIDNS-XXXXX Plan

## Summary

<one paragraph: what the epic/story requires, why, intended outcome>

## Context

- **Jira:** ticket link + parent epic + linked tickets
- **Prior work:** related PRs (from `gh pr list`), commits, existing implementations
- **Existing PRs + Review Context:**
  - PR URL | State (DRAFT/OPEN/MERGED) | Identified Gaps | Blocking Findings | Non-Blocking Feedback | Coverage / Test Status
  - Example: `PR 507 (DRAFT) | gaps: handler tests | coverage 87% → need 92% | should add e2e | ...`
  - This context informs the plan's traceability table and helps the bounded-review-loop (Step 7b) and code-review loop (msad-dev-execution) understand what's been tried
- **Repos involved:** `<list>`, each with 1–2 sentence role
- **Dependency repos in scope:** (if any beyond the six core repos; e.g., atlas.onprem.rpc.server for agent/proxy work)
- **Constraints:** Windows-only testing? Proto-dependent? Cross-repo validator sync? Frontend/UI tasks deferred?

## Per-Repo Work Packages

### Git Commit Planning (Per-Package)

For each work package, plan changes as a sequence of **additions**, **modifications**, and **deletions** (separate commits):

**Additions** (new files, new functions, new tests):
- Minimal commit: only new code, no changes to existing code
- Example: "Add replication-scope validator tests (new test file)"

**Modifications** (changes to existing code):
- Separate from additions: only changes to existing files
- Example: "Update zone validator to accept domain/forest scopes"

**Deletions** (remove dead code):
- Only delete if certain (unused, deprecated, or provably safe)
- Example: "Remove legacy scope validator (no longer used)"

This makes commits clean, reviewable, and bisectable. State in the plan file which changes are additions vs. modifications vs. deletions.

### Package 1: ddi.dns.config

**Jira task:** DDIDNS-XXXXX

**Changes (by type):**

**Additions:**
- New file: `pkg/service/application/stub_zone_test.go` additions (table-driven test cases for new scopes)

**Modifications:**
- `pkg/service/application/stub_zone.go` — update `validateStubZoneReplicationScopeNotLegacy()` to allow `domain`/`forest` (currently allows only `local`)

**Deletions:**
- (none — scope expansion, no removals)

**Tests:**
- Unit test: table-driven cases for allow-list boundaries (see traceability table below)
- Integration: exercise via WAPI v3 (exercise via gRPC mock in middleware tests)

**Dependencies:** none (independent)

**Acceptance Criteria / Scenario Traceability**

| Scenario / AC | Test File | Test Function |
|---|---|---|
| AC1 (Scenario: Domain scope accepted) | pkg/service/application/stub_zone_test.go | TestZoneCreate_DomainScope |
| AC2 (Scenario: Forest scope accepted) | pkg/service/application/stub_zone_test.go | TestZoneCreate_ForestScope |

### Package 2: ddi.cloud.proxy.middleware

**Jira task:** DDIDNS-XXXXX

**Changes (by type):**

**Additions:**
- New test cases in `pkg/msad_zone_helper_test.go` and `pkg/interceptor_handlers_test.go` (sqlmock, table-driven)

**Modifications:**
- `pkg/msad_zone_helper.go` — update `isValidMSADReplicationScopeForZoneCreate()` to match dns.config's allow-list
- `pkg/interceptor_handlers.go` — update `AuthZoneCreateHandler.Handle` to enforce the new scope

**Deletions:**
- (none)

**Tests:**
- Unit test: scope validation with sqlmock
- Table-driven test cases in `interceptor_handlers_test.go` covering create with valid/invalid scopes (see traceability table below)

**Dependencies:** none (mirrors dns.config, which is independent)

**Acceptance Criteria / Scenario Traceability**

| Scenario / AC | Test File | Test Function |
|---|---|---|
| AC1–2 (Middleware validates scope) | pkg/msad_zone_helper_test.go | TestIsValidMSADReplicationScope |
| AC1–2 (Handler enforces scope) | pkg/interceptor_handlers_test.go | TestAuthZoneCreateHandler_ValidatesScope |

### Package 3: ddi.msad.agent (Windows-only)

**Jira task:** DDIDNS-10521

**Changes (by type):**

**Additions:**
- New method: `ValidateReplicationScope()` in `DnsPrimaryZoneController.cs`
- New test class in `MSADAgent/Agent.Tests` (xUnit) with validation test cases

**Modifications:**
- `DnsPrimaryZoneController.cs` — call `ValidateReplicationScope()` before using scope in PowerShell `-ReplicationScope` argument

**Deletions:**
- (none)

**Tests:**
- Unit test: scope validation (allow-list: local/domain/forest, reject legacy) (see traceability table below)
- Verified via Windows CI only (`windows_node_ddi_msad_agent_label`)

**Dependencies:** none (independent, but requires Windows CI for verification)

**Acceptance Criteria / Scenario Traceability**

| Scenario / AC | Test File | Test Function |
|---|---|---|
| AC1–2 (Agent validates scope before PowerShell) | MSADAgent/Agent.Tests/DnsPrimaryZoneControllerTests.cs | ValidateReplicationScope_ValidScopes_Test |
| AC1–2 (Agent rejects legacy) | MSADAgent/Agent.Tests/DnsPrimaryZoneControllerTests.cs | ValidateReplicationScope_RejectLegacy_Test |

## Cross-Repo Constraints

- **Validator sync:** `isValidMSADReplicationScopeForZoneCreate` in middleware MUST mirror `validateStubZoneReplicationScopeNotLegacy` in dns.config. Both allow `local`/`domain`/`forest`, reject `legacy`.
- **Idempotency (if applicable):** if this feature adds zone creation, PR #508's pattern (pre-flight duplicate check + rollback) must be present in the middleware package.

## Assumptions

- `make protobuf` in the middleware is not needed for this feature (no proto changes).
- Replication-scope validation is the only blocker; error handling (DDIDNS-10541) is a separate follow-up.
- Windows CI is the only verification for agent changes; local testing on Mac is not possible.

## Risks

- **Validator drift:** if one layer's validator is updated and another is missed, scopes could be silently rejected or corrupted across the stack. Mitigation: code review checklist, linked PRs.
- **Windows CI delay:** agent changes can't be verified locally; depends on Windows node availability.

## Open Questions

- (none for this minimal example)

## Test Plan (per package)

### ddi.dns.config

- Unit: scope validation boundaries (valid/invalid cases)
- Integration: create a zone via WAPI v3 with domain scope, assert DB row has correct scope

### ddi.cloud.proxy.middleware

- Unit: scope validation via sqlmock
- Table-driven: zone creation with domain/forest scope, mock MSAD collector response

### ddi.msad.agent

- Unit: scope validation (xUnit)
- CI: Windows node runs dotnet test (local Mac cannot run)

## Approval Gate

**Status: draft** — awaiting user approval.

Once approved, invoke `/msad-dev-execution <plan-path>` to implement.
```

## Step 7b — Bounded Plan Review

After writing the plan and before Step 8, execute the **bounded review loop** defined in `references/bounded-review-loop.md` with these parameters:

- **artifact:** "dev plan" (the markdown file just written)
- **reviewer:** fresh-context agent with `references/plan-reviewer-prompt.md` (Dev Plan Reviewer variant)
- **max_rounds:** 3
- **severity_scheme:** MUST / SHOULD / MAY
- **convergence_condition:** zero MUST findings; SHOULD items are either fixed or justified-and-logged
- **escalation_on_non_convergence:** surface all findings + ledger to user; user decides (approve-with-justification / revise-manually / abandon)

The loop will call the reviewer agent, triage findings, apply fixes if needed, and iterate up to 3 rounds. If convergence is achieved, the plan is marked `status: approved` and ready for Step 8 (user confirmation). If the loop exits non-converged after 3 rounds, the user is shown all findings + ledger and must make an explicit decision before proceeding.

Key reviewer checks:
- [ ] Per-repo work packages are correctly scoped (no massive "todo" tasks)
- [ ] Cross-repo dependencies are explicitly called out (proto, validator sync, error-code additions)
- [ ] Acceptance criteria are clearly mapped to implementation steps, and traceability table is complete
- [ ] Risk section is realistic (Windows testing gaps, cross-repo coordination, scope creep)
- [ ] Assumptions are clearly stated and justified (not silent)
- [ ] Questions are either answered or marked Blocking
- [ ] Every Gherkin scenario in the story's AC has a corresponding test in the traceability table (or is explicitly deferred)

---

## Step 8 — User Approval Gate

**HARD STOP.** Do not implement code until the user approves the plan.

Present to the user:

1. **The plan file** (full contents)
2. **The plan auto-reviewer's output** (findings, gaps, risks — verbatim)
3. **Approval question:**

> "This plan proposes `<N>` work packages across `<repos>`. Auto-review surfaced `<F>` findings (see below). Proceed with implementation, revise, or reject? (Approve / Approve with edits / Reject)"

Four possible responses:

1. **Approve as-is** — stamp `status: approved` in frontmatter; tell the user to invoke `/msad-dev-execution <plan-path>`.
2. **Approve with edits** — revise per feedback, re-run self-critique + auto-review, re-present.
3. **Reject** — return to Step 6 (or Step 4 if scope changed).
4. **Silence** is NOT approval. If response is ambiguous, ask explicitly.

## Anti-Patterns

- Don't skip any step 1–7 before auto-review. Step 7b (auto-review) is mandatory.
- Don't skip Step 8 (user approval). Plans are gated; implementation doesn't start without explicit approval.
- Don't assume a task is independent if replication-scope validation is in scope — that's a cross-repo sync point.
- Don't forget Windows testing constraints for agent changes.
- Don't silently assume "proto change required" — check the task description first.
- Don't let the auto-reviewer block the plan. Reviewer is advisory; user decides on Blocking issues.

## Error Handling

- **Atlassian MCP unavailable:** ask the user to paste the Jira summary, description, and AC verbatim. Mark all derived facts as `source: user-pasted`.
- **Repo not detected:** ask the user to confirm which of the six repos the task targets.
- **Clarifying questions can't be resolved:** list them as blocking in Step 6 and ask the user before proceeding.
- **User response to Step 8 is ambiguous:** ask explicitly which of the four options applies.
