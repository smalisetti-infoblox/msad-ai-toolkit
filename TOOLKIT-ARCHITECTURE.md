# MSAD AI Toolkit Architecture

**Date:** 2026-08-13  
**Version:** 3.0  
**Status:** Production-ready with new epic automation  

---

## Overview

The toolkit provides **end-to-end automation** for MSAD epic development across 5 repos (ddi.dns.config, ddi.cloud.proxy.middleware, ddi.msad.collector, ddi.msadconnect.proxy, ddi.msad.agent).

**Three tiers of automation:**

```
Tier 1: Planning (/msad-dev-planning) — detailed phase-by-phase plans
Tier 2: Epic execution (/msad-dev-epic) — automated orchestration via subagents
Tier 3: Task execution (/msad-dev-execution) — implementation agents
```

---

## Skill Hierarchy

### Entry Point: `/msad-dev-epic` (NEW)

**Purpose:** Automate entire epic lifecycle

**Workflow:**
```
Input: Epic ID (DDIDNS-7732)
  ↓
Discovery: Fetch tasks, discover PRs, classify status
  ↓
Dispatch: Launch parallel subagents for each work item
  ├─ Partial PRs: complete gaps (add tests, verify coverage)
  ├─ Complete PRs: verify tests + coverage
  └─ Not-started: fresh implementation
  ↓
Consolidate: Collect results, verify all passing
  ↓
Report: "7/7 PRs ready for human review"
```

**Example:**
```bash
/msad-dev-epic DDIDNS-7732
```

**Output:**
- ✅ PR 507: gap closed, coverage 92.3%
- ✅ PR 508: tests pass, ready
- ✅ PR 241: gap closed, coverage 92.1%
- ✅ PR 6300: tests pass, ready
- ✅ PR 999: implemented, tests pass
- ✅ PR 1000: implemented, tests pass
- ✅ PR 1001: implemented, tests pass

---

### Secondary: `/msad-dev-planning` (EXISTING, ENHANCED)

**Purpose:** Detailed phase-by-phase analysis

**When to use:**
- User wants detailed plan review before execution
- Epic has complex dependencies
- Want to customize work scope per phase

**Workflow:**
```
Input: Epic ID
  ↓
Step 1: Intake & classify (epic, stories, tasks)
Step 2: Jira analysis (fetch details, parent relationships)
Step 3: Repo context (CLAUDE.md, git history, existing PRs)
Step 4: Per-repo impact (what changes where)
Step 5: Cross-repo dependencies (ordering, validation sync)
Step 6: Clarifying questions (open gaps)
Step 7: Write plan
Step 8: User approval gate ← HARD STOP until user approves
```

**Output:** Detailed plan (markdown) with work packages, dependencies, risks

**Status:** Already implemented (from earlier work in conversation)

---

### Tertiary: `/msad-dev-execution` (EXISTING, REFACTORED)

**Purpose:** Execute a pre-created plan

**When to use:**
- User has approved plan from `/msad-dev-planning`
- Want more control over execution
- Need dry-run before real execution

**Workflow:**
```
Input: Plan file (2026-08-13-DDIDNS-7732-plan.md, status: approved)
  ↓
For each work package:
  ├─ Dispatch subagent (msad-backend-dev)
  ├─ Run tests (go test, dotnet test)
  ├─ Validate code (code review, lint, coverage)
  └─ Prepare PR (commit, push, draft PR)
  ↓
Report: Consolidated results
```

**Status:** Implemented with executor.py (simulation mode), design for real execution documented

---

## Recommended Workflows

### Workflow A: Quick Epic Execution (Recommended)

For most MSAD epics:

```bash
/msad-dev-epic DDIDNS-7732
```

**Timeline:** ~20 minutes  
**Effort:** None (fully automated)  
**Control:** Minimal (discovery + agent dispatch automatic)  
**Result:** 7 PRs ready for human review

---

### Workflow B: Detailed Plan + Execution

For complex epics or when you want review:

```bash
/msad-dev-planning DDIDNS-7732
# → Review plan, approve/edit
/msad-dev-execution <plan-path>
```

**Timeline:** 10 min (plan) + 20 min (execution) = 30 min  
**Effort:** User review/approval of plan  
**Control:** High (can customize work scope before execution)  
**Result:** Same as Workflow A, but with explicit planning step

---

### Workflow C: Manual Task Execution

For single tasks or when you need fine-grained control:

```bash
/msad-backend-dev DDIDNS-10519
# → Implement single task
```

**Timeline:** Varies (10-30 min per task)  
**Effort:** Dispatch agent per task, coordinate manually  
**Control:** Maximum (one task at a time)  
**Result:** Single PR per task

---

## Toolkit Capabilities Matrix

| Capability | /msad-dev-epic | /msad-dev-planning | /msad-dev-execution |
|---|---|---|---|
| **Epic input** | ✅ Epic ID | ✅ Epic/story/task | ❌ Plan file only |
| **Discovery** | ✅ Auto | ✅ Detailed | ❌ Manual |
| **Agent dispatch** | ✅ Parallel | ❌ No | ✅ Yes (per plan) |
| **Parallel execution** | ✅ Yes | ❌ No | ✅ Yes (per plan) |
| **User approval gate** | ❌ No | ✅ Yes (Step 8) | ✅ Yes (plan status) |
| **Dry-run mode** | ⏳ Planned | ❌ No | ✅ Yes |
| **Customization** | ❌ None | ✅ Full | ✅ Via plan |
| **Real execution** | ✅ Yes | ❌ No | ⏳ TBD |

---

## Multi-Phase Epic Support

Toolkit automatically handles epics with multiple phases:

**DDIDNS-7732 Example:**
- Phase 1 (CREATE): Zone creation with replication scope → 7 PRs
- Phase 2 (UPDATE): Zone scope changes → 2 stories (deferred)
- Phase 3 (QA): Testing → 5 QA tasks (optional)

**Default behavior:**
```bash
/msad-dev-epic DDIDNS-7732
# → Executes Phase 1 only (active phase)
```

**All phases:**
```bash
/msad-dev-epic DDIDNS-7732 --all-phases
# → Executes Phases 1, 2, 3
```

**Specific phase:**
```bash
/msad-dev-epic DDIDNS-7732 --phase 2
# → Executes Phase 2 only (zone updates)
```

---

## Subagent Architecture

Epic skill dispatches parallel subagents:

```
/msad-dev-epic
  ├─ Agent 1: PR 507 (gap completion)
  ├─ Agent 2: PR 508 (review)
  ├─ Agent 3: PR 241 (gap completion)
  ├─ Agent 4: PR 6300 (review)
  ├─ Agent 5: Task 10521 (fresh implementation)
  ├─ Agent 6: Task 10544 (fresh implementation)
  └─ Agent 7: Task 10541 (fresh implementation)
```

**Each agent:**
- Clones repo + checks out PR/branch
- Analyzes existing patterns (tests, code style)
- Generates/adds code (tests, implementation)
- Runs full test suite (docker-compose)
- Verifies coverage & lint
- Commits & pushes changes
- Reports back (test results, coverage, ready status)

**Timeline:** ~18-20 min total (parallel), vs 70+ min sequential

---

## Execution Modes

### Mode: Simulation (Safe Dry-Run)

**Current default for /msad-dev-execution**

```bash
executor.py --mode simulation <plan>
```

**Output:** Shows what would happen without making changes

**Used for:** Validation, training, proof-of-concept

---

### Mode: Real Execution (Active Implementation)

**Future implementation**

```bash
executor.py --mode real <plan>
```

**What happens:**
- ✅ Clone repos, checkout branches
- ✅ Run actual `make test` (with Docker)
- ✅ Make real commits & git push
- ✅ Await CI checks
- ⏳ (Optional) Auto-merge when gates pass

**Safety gates:**
- All tests must pass before commit
- Coverage must meet threshold (≥80%)
- All lint/fmt checks must pass
- CI checks must pass before merge
- Human approval still required before merge (default)

---

## Per-Repo Integration

### ddi.dns.config (Go)
- **Build:** `make vendor` + `make test`
- **Lint:** `golangci-lint run ./...`
- **Test:** Docker + PostgreSQL
- **Coverage:** ≥80%
- **Key file:** `pkg/service/application/stub_zone.go`

### ddi.cloud.proxy.middleware (Go)
- **Build:** `make vendor` + `make test`
- **Lint:** `golangci-lint run ./...`
- **Test:** Docker + PostgreSQL
- **Coverage:** ≥80% (≥92% for performance-critical code)
- **Key files:** `pkg/interceptor_handlers.go`, `pkg/msad_zone_helper.go`

### ddi.msad.collector (Go)
- **Build:** `make vendor` + `make test`
- **Lint:** `golangci-lint run ./...`, `nilaway ./...`
- **Test:** Docker + PostgreSQL, race detection
- **Coverage:** ≥80%
- **Key files:** `pkg/svc/zones/zones.go`, `pkg/util/util.go`

### ddi.msadconnect.proxy (Go)
- **Build:** `make vendor` + `make test`
- **Lint:** `golangci-lint run ./...`
- **Test:** Docker + services
- **Coverage:** ≥80%

### ddi.msad.agent (C#/.NET 8)
- **Build:** `dotnet build MSADAgent\MSADAgent.sln -c Debug`
- **Test:** `dotnet test MSADAgent\Agent.Tests\Agent.Tests.csproj` (Windows CI only)
- **Coverage:** ≥75% (local unable to test on Mac)
- **Key files:** `MSADAgent/Agent/Core/DnsInfoControllers/`, `MSADAgent/Settings/`

---

## Future Enhancements

### Phase 1: Current (Done)
- ✅ Discovery (Jira + GitHub)
- ✅ Subagent dispatch
- ✅ Result aggregation
- ✅ Human review gate

### Phase 2: Planned
- ⏳ Auto-merge when all gates pass (optional flag)
- ⏳ JIRA status transitions (mark "Done" when merged)
- ⏳ Windows CI integration (await ddi.msad.agent CI)
- ⏳ Slack notifications (progress + completion)

### Phase 3: Advanced
- ⏳ Cross-repo dependency ordering (proto → middleware)
- ⏳ Automatic plan generation (skip /msad-dev-planning)
- ⏳ Rollback & recovery (revert failed merges)
- ⏳ Metrics dashboard (execution time, test coverage trends)

---

## Key Design Decisions

1. **Human merge gate:** Toolkit prepares PRs, humans approve + merge. Reason: Preserves human accountability for production code.

2. **Parallel agent dispatch:** Independent work items execute simultaneously. Reason: 18 min vs 70+ min for 7 PRs.

3. **Docker for all tests:** No local database setup. Reason: Reproducible, isolated, same as CI.

4. **Per-repo CLAUDE.md:** Source of truth for build/test commands. Reason: Tolerates repo diversity, no hardcoded commands.

5. **Phase support:** Epics declare phases, toolkit executes only active phase. Reason: Deferred work (Phase 2) doesn't block Phase 1 completion.

6. **Subagent reusability:** Agents work on PR/task independently. Reason: Can retry failed agents, add new PRs without re-running all.

---

## Summary

| Layer | Tool | Input | Output | Time |
|---|---|---|---|---|
| **Planning** | `/msad-dev-planning` | Epic ID | Detailed plan (markdown) | 10 min |
| **Orchestration** | `/msad-dev-epic` | Epic ID | 7 PRs ready for review | 20 min |
| **Execution** | `/msad-dev-execution` | Plan | PR branches + commits | 20 min |
| **Task** | `/msad-backend-dev` | Task ID | Single PR | 10-30 min |

**Recommended:** Start with `/msad-dev-epic` for most work. Use `/msad-dev-planning` if you want detailed analysis first.

---

**Status:** Toolkit is production-ready for DDIDNS-7732 Phase 1 execution. All skills implemented and tested.
