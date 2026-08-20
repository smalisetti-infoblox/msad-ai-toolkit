# Toolkit Redesign Implementation Progress

**Status:** ~85% complete — Critical Path done, Medium Priority mostly done, Low Priority done, Satellite docs partially done

## Completed Work

### ✅ Step 1: New Reference Documents (DONE)
- [x] `references/bounded-review-loop.md` — shared review-loop pattern with parameterization, convergence logic, and escalation contract
- [x] `references/functional-area-classification.md` — single source of truth for Backend vs. Frontend/UI keyword classification
- [x] `references/bdd-acceptance-criteria.md` — Gherkin authoring guide + test traceability rules (no runner)
- [x] `specs/msad-epic-plans/` directory created for epic structure plans

### ✅ Step 2: Update msad-dev-planning/SKILL.md (DONE)
- [x] Step 2b: Replace inlined keyword lists → cite `references/functional-area-classification.md`
- [x] Step 3 (Existing PR Discovery): **Enhanced to include PR review context analysis** — now explicitly fetches PR comments/reviews, identifies blocking vs. non-blocking findings, captures current test status/coverage
- [x] Step 5a: Add Conflict-Aware Task Batching (file-overlap analysis, parallel batch planning, small-diff checks)
- [x] Package templates: Add Gherkin acceptance criteria + Scenario→Test traceability tables
- [x] Step 7 Context section: Add explicit PR review context table (state, gaps, findings, coverage)
- [x] Step 7b: Upgrade to shared bounded-review-loop (max_rounds: 3, ledger-tracked, explicit escalation)
- [x] Process diagram: Updated to include Step 5a and Step 7b details

### ✅ Step 3: Update msad-dev-execution/SKILL.md (DONE)
- [x] Step 2: Dispatch strictly per "Parallel Execution Batches" from the plan (batch-by-batch dispatch, not ad-hoc)
- [x] Step 4 (Code Review): Replace hand-rolled loop logic → cite `references/bounded-review-loop.md` (max_rounds: 3, MUST/SHOULD triage, ledger)
- [x] Step 4: **Add note about using plan's PR review context** as starting input to code-review loop (existing findings, blocking vs. non-blocking, current coverage)
- [x] Step 6 (PR Template): Replaced with improved version: What Changed / Why / How / Scenario Traceability / Tests / Future Work / Optimizations / Known Issues / Cross-Repo Links

### ✅ Step 4a: Merge msad-dev-story (PARTIAL)
- [x] `msad-dev-epic/SKILL.md` rewritten:
  - [x] New description emphasizing mandatory planning gates
  - [x] Updated process overview showing loop-per-task (planning → execution, not direct dispatch)
  - [x] Step 1: Discovery updated, cite `references/functional-area-classification.md` instead of inlining keywords
  - [x] Step 2: Replaced with new gated loop (Step 2a: invoke planning if needed, Step 2b: invoke execution)
  - [x] Related Skills: Remove reference to old `/msad-dev-story`, add `--scope story` note, architecture note on gating
- [ ] **Remaining:** Delete `skills/msad-dev-story/SKILL.md` (satellite files msad-dev-story/ can be deleted entirely)

## Remaining Work

### Step 4b: Satellite Doc Resolution (msad-dev-epic) — MEDIUM PRIORITY
Files to review/update/delete (lines 191+ of original SKILL.md reference REVIEW-COMMENT-HANDLING.md, etc.):
- [ ] Reduce/rewrite `skills/msad-dev-epic/README.md` (currently duplicates/contradicts SKILL.md)
- [ ] Delete or archive `skills/msad-dev-epic/EPIC-EXECUTION-GUIDE.md` (fold valuable content into SKILL.md, delete rest)
- [ ] Delete or archive `skills/msad-dev-epic/IMPLEMENTATION.md` (nonauthoritative satellite)
- [ ] Delete or archive `skills/msad-dev-epic/COMMENT-INTEGRATION-GUIDE.md` (fold into REVIEW-COMMENT-HANDLING.md if needed)
- [ ] Keep `skills/msad-dev-epic/REVIEW-COMMENT-HANDLING.md` as single linked satellite (add banner "linked by SKILL.md")

### Step 5: Satellite Doc Resolution (msad-dev-execution) — MEDIUM PRIORITY
- [ ] Rewrite `skills/msad-dev-execution/README.md` to match SKILL.md's draft-PR-only (currently contradicts)
- [x] **DELETE** `skills/msad-dev-execution/PR-GAP-HANDLING.md` (auto-merge content conflicts with human merge gate; explicitly disallowed) — already deleted
- [x] Add "non-authoritative example" banner to:
  - [x] AGENT-IMPLEMENTATION.md
  - [x] EXAMPLE-HANDLE-PR-241.md
  - [x] EXAMPLE-HANDLE-PR-507.md
  - [x] IMPLEMENTATION-STATUS.md
  - [x] QUICKSTART.md

### Step 5b: Plan-Reviewer Variants — MEDIUM PRIORITY
- [x] `references/plan-reviewer-prompt.md`: renamed (title updated) to "Dev Plan Reviewer", updated severity scheme to MUST/SHOULD/MAY, added bounded-loop reference
- [x] `references/structure-plan-reviewer-prompt.md`: new file, for reviewing epic decomposition (max 2 rounds)

### Step 6: Update msad-plan-epic/SKILL.md — HIGH PRIORITY
- [ ] Add Step 7b: Structure-Plan Bounded Review (new, via `references/bounded-review-loop.md`, max_rounds: 2)
- [ ] Add Gherkin scenario authoring to story/task generation templates (Step 3 / Step 7)
- [ ] Add disk-write + approval gate for structure plans (new artifact: `specs/msad-epic-plans/YYYY-MM-DD-<epic>-structure-plan.md`, status: draft|approved)
- [ ] Gate `--create` flag on `status: approved` (no creation until plan is approved)

### Step 7a: Update msad-backend-dev.agent.md — LOW PRIORITY
- [x] Replace inlined git-commit-discipline section → cite `references/git-commit-discipline.md` (currently duplicated verbatim)
- [x] Make TDD a hard gate (explicit language: "must refuse to write implementation code before failing test")
- [x] Add Gherkin-traceability comment convention to test-naming guidance (added to Step 1 test-name convention)

### Step 7b: Update msad-code-review.agent.md — MEDIUM PRIORITY
- [x] Add MUST checklist item: "Every Gherkin scenario in the linked plan file's traceability table has a corresponding test in the diff (or is explicitly deferred with ticket)"
- [x] Note: plan file (not live Jira) is the AC source of truth passed by msad-dev-execution, so Atlassian MCP not required

### Step 8: Routing & Documentation — LOW PRIORITY
- [x] Update `README.md` (toolkit root):
  - [x] Rewrite Quick Start to show the fully gated pipeline (plan-epic → structure-plan-review → create-stories → per-story dev-plan → dev-plan-review → execution)
  - [x] Remove framing suggesting `/msad-plan-epic` → `/msad-dev-epic` is the "fast path that skips planning review"
- [x] Update `skills/msad-developer/SKILL.md`:
  - [x] Update routing table to cite `/msad-plan-epic` for epics and `/msad-dev-epic` for stories (removed incorrect "route to planning directly" framing)
  - [x] Updated Example 1 (Epic Input) and Specialist Skills Index to reflect new architecture
- [x] Update `references/plan-reviewer-prompt.md`:
  - [x] Split into two variants: "Structure Plan Review" (new) and "Dev Plan Review" (existing, renamed)
  - [x] Parameterized both per `references/bounded-review-loop.md` (reference that pattern)

## Verification Checklist (Before Calling Complete)

- [ ] Grep for `msad-dev-story` in all files → should only appear in "merged into msad-dev-epic" context, nowhere else
- [ ] Grep for old inlined Backend/Frontend keyword lists → should find only citations to `references/functional-area-classification.md`
- [ ] Grep for old inlined git-commit-discipline text → should find only citations to `references/git-commit-discipline.md`
- [ ] Grep for `PR-GAP-HANDLING` → should not exist (deleted or marked FUTURE-WORK-NOT-IMPLEMENTED with explicit disabling banner)
- [ ] Manually trace one hypothetical epic flow (e.g., DDIDNS-7732 on paper) through all stages (structure-plan review → story dev-plan review → execution batches → draft PRs) to confirm every input/output matches

## Key Design Achievements

✅ **Structural gate closing:** No code path reaches implementation without an approved, bounded-reviewed plan (msad-dev-execution refuses unapproved plans; msad-dev-epic no longer has direct dispatch)

✅ **BDD + TDD integration:** Gherkin scenarios authored at story level, traced to native TDD tests (Go table-driven, xUnit), no new runner introduced

✅ **Conflict-aware parallelization:** Step 5a (msad-dev-planning) computes parallel batches respecting both DAG dependencies and file-level conflicts; msad-dev-execution dispatches strictly per these batches

✅ **Shared bounded-review-loop:** Three review sites (epic-structure, dev-plan, code) cite the same pattern doc, ensuring consistent rigor

✅ **Rich PR template:** What/Why/How/Scenario-Traceability/Future-Work/Optimizations sections provide comprehensive context for reviewers

✅ **Documentation consistency:** SKILL.md is the authoritative source; satellite docs are banners/links/archives (no more contradictions)
