# MSAD AI Toolkit Redesign — Implementation Roadmap

**Current Status:** ~60% complete (Phases 1-2 done, Phase 3 in progress)

---

## Phases Completed ✅

### Phase 1: Foundation References (100%)
- ✅ `references/bounded-review-loop.md`
- ✅ `references/functional-area-classification.md`
- ✅ `references/bdd-acceptance-criteria.md`
- ✅ `specs/msad-epic-plans/` directory created

### Phase 2: Core Skills Rewritten (100%)
- ✅ `msad-dev-planning/SKILL.md` — conflict-aware batching, bounded review loop, PR context analysis
- ✅ `msad-dev-execution/SKILL.md` — batch-driven dispatch, bounded code-review, rich PR template
- ✅ `msad-dev-epic/SKILL.md` — gated loop architecture (planning → execution), no direct dispatch
- ✅ Deleted: `skills/msad-dev-story/`, `skills/msad-dev-execution/PR-GAP-HANDLING.md`
- ✅ Updated: `skills/msad-dev-execution/README.md` (draft-PR-only, non-authoritative)

---

## Remaining Work (Estimated ~3 hours)

### 🔴 CRITICAL PATH (Do these first)

**1. msad-plan-epic/SKILL.md** (~30 min)
- [ ] Add Step 7b: Structure-Plan Bounded Review (max_rounds: 2, via references/bounded-review-loop.md)
- [ ] Add Gherkin scenario authoring to Step 3 (story/task generation templates)
- [ ] Add Step 7 Context section: structure plan template with artifact details
- [ ] Add disk-write + approval gate: write to `specs/msad-epic-plans/YYYY-MM-DD-<epic>-structure-plan.md`, status: draft|approved
- [ ] Gate `--create` flag on `status: approved`
- [ ] Add Step 8: User Approval Gate (hard stop until status: approved)

**2. Toolkit root README.md** (~30 min)
- [ ] Rewrite Quick Start section to show FULLY GATED pipeline:
  - `/msad-plan-epic` → structure-plan review (≤2 rounds) → approval
  - → `/msad-plan-epic --create` (creates stories)
  - → per-story `/msad-dev-planning` → dev-plan review (≤3 rounds) → approval
  - → `/msad-dev-execution` (implementation + code-review + draft PRs)
- [ ] Remove framing suggesting "fast path that skips planning"
- [ ] Clarify: every task requires approved plan before any code

### 🟡 MEDIUM PRIORITY (Do next)

**3. references/plan-reviewer-prompt.md** (~20 min)
- [ ] Split into TWO variants:
  - "Structure Plan Review" — reviews epic→story/task decomposition
  - "Dev Plan Review" — reviews per-story implementation plan (existing, rename)
- [ ] Both cite `references/bounded-review-loop.md` (parameterized per variant)

**4. msad-dev-epic satellite docs** (~45 min)
- [ ] Rewrite `skills/msad-dev-epic/README.md` — non-authoritative pointer, references SKILL.md
- [ ] Delete or archive:
  - `EPIC-EXECUTION-GUIDE.md` (fold valuable content into SKILL.md)
  - `IMPLEMENTATION.md` (nonauthoritative)
  - `COMMENT-INTEGRATION-GUIDE.md` (merge into REVIEW-COMMENT-HANDLING.md if needed)
- [ ] Keep `REVIEW-COMMENT-HANDLING.md` — add banner "Linked by SKILL.md Step 2"

**5. msad-code-review.agent.md** (~15 min)
- [ ] Add MUST checklist item: "Every Gherkin scenario in the plan file's traceability table has a corresponding test in the diff (or is explicitly deferred with ticket)"
- [ ] Note: plan file (passed by msad-dev-execution) is source of truth for ACs; no Atlassian MCP needed for scenario coverage check

### 🟢 LOW PRIORITY (Polish)

**6. msad-backend-dev.agent.md** (~15 min)
- [ ] Replace inlined git-commit-discipline section → cite `references/git-commit-discipline.md`
- [ ] Make TDD a hard gate: "must refuse to write implementation code before failing test exists"
- [ ] Add Gherkin-traceability comment convention: `// Scenario: "<name>" (Jira AC#)`

**7. msad-developer/SKILL.md** (~10 min)
- [ ] Update routing table: add `/msad-dev-epic --scope story|epic`
- [ ] Remove now-incorrect "route directly to msad-dev-planning" framing
- [ ] Add architecture note: `/msad-dev-epic` internally loops through planning+approval+execution

**8. Satellite doc banners** (~10 min)
- [ ] Add "Non-authoritative example. See SKILL.md for current process." to:
  - `skills/msad-dev-execution/AGENT-IMPLEMENTATION.md`
  - `skills/msad-dev-execution/EXAMPLE-HANDLE-PR-241.md`
  - `skills/msad-dev-execution/EXAMPLE-HANDLE-PR-507.md`
  - `skills/msad-dev-execution/IMPLEMENTATION-STATUS.md`
  - `skills/msad-dev-execution/QUICKSTART.md`

### 🔵 VERIFICATION (Final step)

**9. Verification checks** (~30 min)
```bash
# No dangling references to deleted skills
grep -r "msad-dev-story" --include="*.md" .

# No inlined keyword duplication
grep -r "portal.*frontend.*selector" --include="*.md" skills/ agents/

# No inlined git-discipline duplication  
grep -r "Additions commit" --include="*.md" agents/

# No PR-GAP-HANDLING references
grep -r "PR-GAP-HANDLING" --include="*.md" .
```

**10. Manual trace** (~30 min)
- On paper, trace one hypothetical epic (e.g., DDIDNS-7732) through full pipeline:
  1. `/msad-plan-epic DDIDNS-7732` → structure plan
  2. Structure-plan bounded review (≤2 rounds)
  3. User approval (status: approved)
  4. `/msad-plan-epic --create` → creates stories in Jira
  5. Per story: `/msad-dev-planning <story-id>` → dev plan (Gherkin + conflict batches)
  6. Dev-plan bounded review (≤3 rounds)
  7. User approval (status: approved)
  8. `/msad-dev-execution <plan>` → implementation (parallel batches) → bounded code-review (≤3 rounds) → draft PRs
  9. Verify every stage has a gate, no code path skips planning approval

---

## Key Design Principles (Already Implemented)

✅ **Structural gating:** No code path reaches implementation without approved, bounded-reviewed plan  
✅ **PR context integration:** Planning captures existing PR state, blocking findings, coverage  
✅ **Prefer PR completion over duplication:** If PR exists (draft/open), complete it; only create new PR if none found  
✅ **BDD + TDD:** Gherkin at story level, traced to native tests (no new runners)  
✅ **Conflict-aware parallelization:** Step 5a (planning) computes safe parallel batches, Step 2 (execution) dispatches per batches  
✅ **Shared bounded-loop:** All three review sites cite same pattern doc  
✅ **Rich PR template:** What/Why/How/Scenario-Traceability/Tests/Future-Work/Optimizations/Known Issues  
✅ **Doc consistency:** SKILL.md authoritative; satellites are banners/links/archives  

---

## Success Criteria

When complete, the toolkit will:

1. ✅ **Gate every task:** Epic structure plan → reviewed → Story dev plan → reviewed → Execution (plan-mandatory, no skips)
2. ✅ **Capture PR history:** Planning step documents existing PRs, their review context, blocking/non-blocking findings
3. ✅ **Enable parallel work:** Conflict-aware batching prevents edit conflicts, improves parallelization
4. ✅ **Simplify reviews:** Small, single-concern PRs with rich context (what/why/how/traceability)
5. ✅ **Track decisions:** Bounded-review loop creates ledger (fixed / justified / escalated) for every finding
6. ✅ **Support BDD + TDD:** Gherkin ACs at story level, traced to unit tests, executable via bounded code-review

---

## Timeline

- **Critical path (items 1-2):** 1 hour → enables full gated pipeline demo
- **Medium priority (items 3-5):** 1.5 hours → resolves contradictions, completes agent updates
- **Polish (items 6-8):** 45 min → final consistency pass
- **Verification (items 9-10):** 1 hour → confirm no regressions

**Total: ~4 hours for complete implementation**

---

## Next Action

Start with **Phase 3 Critical Path (items 1-2):**
1. Open `skills/msad-plan-epic/SKILL.md`
2. Add Step 7b (structure-plan bounded review)
3. Add Gherkin authoring to story/task templates
4. Add Step 7 context section (structure plan artifact)
5. Add Step 8 (approval gate)
6. Then: Update toolkit root `README.md`

These two files unlock the full gated pipeline demo.
