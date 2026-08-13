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
Step 2: Jira analysis (epic + linked stories/tasks)
  ↓
Step 3: Repo context (grep prior work, test patterns)
  ↓
Step 4: Per-repo impact (what changes in each repo)
  ↓
Step 5: Identify cross-repo dependencies (proto, validators, etc.)
  ↓
Step 6: Clarifying questions (if any)
  ↓
Step 7: Write plan
  ↓
Step 8: USER APPROVAL GATE
  ├─ Approve as-is → done
  ├─ Approve with edits → revise plan, re-present
  └─ Reject → return to step 6
```

## Step 1 — Intake

1. Classify the input:
   - **Jira ID matching `^DDIDNS-\d+$`**: proceed to step 2.
   - **Jira URL containing a matching ID**: extract the ID; proceed to step 2.
   - **Prose with no ticket**: ask the user for a `DDIDNS-XXXXX` ID before proceeding — don't guess.
   - **Anything else**: ask the user which Jira ID to plan against.

2. Detect primary repo mapping via `references/repo-topology.md`:
   - Service/component mentioned in the task maps to one or more repos.
   - Note all repos involved (may be multi-repo epic).

3. State: *"Step 1 — Intake. Repos: `<list>`, ticket: `<jira-id>`."*

## Step 2 — Jira Analysis

Use Atlassian MCP tools:
- `getJiraIssue` for the ticket (summary, description, AC, components, status, fix versions)
- `getJiraIssue` for parent epic if this is a story/task
- `getJiraIssue` for each linked ticket (blocks / blocked-by / relates-to)

Produce a structured summary: **fact** (verbatim from Jira), **inference** (derived), **assumption** (proceeding without confirmation).

### Questions to Surface

- **Is this ticket part of DDIDNS-7732 (Microsoft DNS zone creation epic)?** If yes, run `gh pr list` (Step 3 below) to discover current related work dynamically, rather than using stale hardcoded PR numbers.
- **Does this change a replication-scope validator or create a new one?** If yes, flag that mirrors must be updated (dns.config ↔ middleware).
- **Does this touch a proto file?** If yes, flag that vendored generated code in downstream repos must be regenerated.
- **Does this involve the Windows agent (ddi.msad.agent)?** If yes, note that local testing is impossible; Windows CI is the verification gate.

## Step 3 — Repo Context

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

### Existing PR Discovery

Before writing the plan, discover related open/merged PRs in the affected repos. Use `gh pr list` (see `references/repo-topology.md` "Existing PR Discovery" for exact commands and repo slugs):

```bash
# Example: search for PRs mentioning the epic ID
gh pr list --repo Infoblox-CTO/ddi.msad.collector --search "DDIDNS-7732" --limit 15
gh pr list --repo Infoblox-CTO/ddi.cloud.proxy.middleware --search "DDIDNS-7732" --limit 15
# ... repeat for all involved repos
```

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

## Step 6 — Clarifying Questions

List open questions:

- **Blocking** — can't produce a sensible plan without it (changes scope or changes which repos are involved).
- **Non-blocking** — useful but a reasonable default exists.
- **Assumption** — proceeding unless corrected, record in ledger.

Ask only what can't be answered from Jira, the repo, or linked tickets. If the answer is in the repo, go answer it first.

**Red flag:** If you can't determine which repos are involved, or if the task is silent on replication-scope constraints (creation vs. update), ask explicitly.

## Step 7 — Write Plan & Self-Critique

Plan file template (mandatory sections):

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
- **Repos involved:** `<list>`, each with 1–2 sentence role
- **Dependency repos in scope:** (if any beyond the five core repos; e.g., atlas.onprem.rpc.server for agent/proxy work)
- **Constraints:** Windows-only testing? Proto-dependent? Cross-repo validator sync?

## Per-Repo Work Packages

### Package 1: ddi.dns.config

**Jira task:** DDIDNS-XXXXX

**Changes:**
- `pkg/service/application/stub_zone.go` — update `validateStubZoneReplicationScopeNotLegacy()` to allow `domain`/`forest` (currently allows only `local`)
- `*_test.go` — add test cases for new scopes

**Tests:**
- Unit test: table-driven cases for allow-list boundaries
- Integration: exercise via WAPI v3 (exercise via gRPC mock in middleware tests)

**Dependencies:** none (independent)

**Acceptance criteria addressed:**
- [ ] AC1: "User can create Domain-replicated zones" — validated at dns.config layer
- [ ] AC2: "User can create Forest-replicated zones" — validated at dns.config layer

### Package 2: ddi.cloud.proxy.middleware

**Jira task:** DDIDNS-XXXXX

**Changes:**
- `pkg/msad_zone_helper.go` — update `isValidMSADReplicationScopeForZoneCreate()` to match dns.config's allow-list
- `pkg/interceptor_handlers.go` — update `AuthZoneCreateHandler.Handle` to enforce the new scope (or pass through if validation is already done)
- `*_test.go` — sqlmock test cases for create with domain/forest scope

**Tests:**
- Unit test: scope validation with sqlmock
- Table-driven test cases in `interceptor_handlers_test.go` covering create with valid/invalid scopes

**Dependencies:** none (mirrors dns.config, which is independent)

**Acceptance criteria addressed:**
- [ ] AC1–2: middleware validates scope before forwarding to MSAD collector

### Package 3: ddi.msad.agent (Windows-only)

**Jira task:** DDIDNS-10521

**Changes:**
- `MSADAgent/Agent/Core/DnsInfoControllers/DnsPrimaryZoneController.cs` — add `ValidateReplicationScope()` method that checks for `local`/`domain`/`forest` before using in PowerShell `-ReplicationScope` argument
- `MSADAgent/Agent.Tests` — xUnit test cases for scope validation

**Tests:**
- Unit test: scope validation (allow-list: local/domain/forest, reject legacy)
- Verified via Windows CI only (`windows_node_ddi_msad_agent_label`)

**Dependencies:** none (independent, but requires Windows CI for verification)

**Acceptance criteria addressed:**
- [ ] AC1–2: agent validates scope at Create time before passing to PowerShell

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

## Step 7b — Plan Auto-Review (Mandatory)

After writing the plan and before Step 8, dispatch a **fresh-context reviewer agent** to audit the plan independently. The reviewer is **advisory only** — it surfaces gaps for the user to decide on, never blocks the approval gate.

1. **Dispatch a new Claude Code agent** (not this skill, a fresh agent) with the prompt template from `references/plan-reviewer-prompt.md`.
   - Pass: plan file path, Jira ID, list of affected repos.
   - Expected output: Markdown report with findings (gaps, unclear steps, assumptions, risks).

2. **Reviewer scope:** check for:
   - [ ] Per-repo work packages are correctly scoped (no massive "todo" tasks)
   - [ ] Cross-repo dependencies are explicitly called out (proto, validator sync, error-code additions)
   - [ ] Acceptance criteria are clearly mapped to implementation steps
   - [ ] Risk section is realistic (Windows testing gaps, cross-repo coordination, scope creep)
   - [ ] Assumptions are clearly stated and justified (not silent)
   - [ ] Questions are either answered or marked Blocking

3. **Surface the reviewer's output verbatim** to the user in Step 8 alongside the plan.

The value: a fresh-context reviewer catches gaps that self-critique by the same model that wrote the plan tends to miss. If the reviewer surfaces Blocking issues, you can revise (Step 7 → Step 8 loop) before presenting to the user.

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
- **Repo not detected:** ask the user to confirm which of the five repos the task targets.
- **Clarifying questions can't be resolved:** list them as blocking in Step 6 and ask the user before proceeding.
- **User response to Step 8 is ambiguous:** ask explicitly which of the four options applies.
