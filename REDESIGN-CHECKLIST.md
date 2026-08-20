# MSAD AI Toolkit Redesign — Implementation Checklist

## Status: 60% Complete (Phase 1 & 2 Done, Phase 3 In Progress)

---

## COMPLETED ✅

### Phase 1: Foundation (New Reference Docs)
- [x] `references/bounded-review-loop.md` — parameterized loop pattern (artifact, reviewer, max_rounds, convergence, escalation, ledger)
- [x] `references/functional-area-classification.md` — Backend vs. Frontend/UI keyword single source of truth
- [x] `references/bdd-acceptance-criteria.md` — Gherkin authoring + test traceability (no runner)
- [x] `specs/msad-epic-plans/` directory created

### Phase 2: Core Skills Rewritten
- [x] `msad-dev-planning/SKILL.md` — Step 5a (conflict batching), Step 7b (bounded loop), traceability tables, cite references
- [x] `msad-dev-execution/SKILL.md` — batch-driven dispatch, bounded-loop code-review, rich PR template
- [x] `msad-dev-epic/SKILL.md` — loop-through-planning architecture (NO direct dispatch), gating logic, cite references
- [x] Deleted `skills/msad-dev-story/` (merged into msad-dev-epic)
- [x] Deleted `skills/msad-dev-execution/PR-GAP-HANDLING.md` (conflicts with human gate)
- [x] Updated `skills/msad-dev-execution/README.md` (draft-PR-only, points to SKILL.md)

### Phase 2.5: Satellite Doc Cleanup (Partial)
- [x] Delete conflicting msad-dev-story/SKILL.md ✅
- [x] Delete conflicting PR-GAP-HANDLING.md ✅
- [x] Update msad-dev-execution/README.md ✅
- [ ] Rewrite msad-dev-epic/README.md (still contradicts)
- [ ] Delete/archive msad-dev-epic/*.md extras (EPIC-EXECUTION-GUIDE.md, etc.)
- [ ] Add "non-authoritative" banners to example/satellite docs

---

## IN PROGRESS 🔄

### Phase 3: Complete Remaining Skills + Docs

**HIGH PRIORITY:**
- [ ] `msad-plan-epic/SKILL.md` — Add Step 7b (structure-plan review), Gherkin authoring, disk-write + approval gate
- [ ] `README.md` (toolkit root) — Rewrite Quick Start (fully gated pipeline, no plan-skipping path)

**MEDIUM PRIORITY:**
- [ ] `references/plan-reviewer-prompt.md` — Split into Structure/Dev variants, cite bounded-loop pattern
- [ ] `msad-code-review.agent.md` — Add scenario-traceability MUST checklist item
- [ ] `skills/msad-dev-epic/` satellite docs — Rewrite README.md, delete/archive EPIC-EXECUTION-GUIDE.md, etc.

**LOW PRIORITY:**
- [ ] `msad-backend-dev.agent.md` — Cite git-commit-discipline reference, TDD hard gate language
- [ ] `msad-developer/SKILL.md` — Update routing for merged msad-dev-story
- [ ] Add "non-authoritative example" banners to satellite docs

---

## NOT STARTED 🔲

- [ ] Verification: grep checks for duplicates/dangling references
- [ ] Verification: manual trace of one epic through full pipeline (paper exercise)

---

## Key Files Modified

| File | Status | Key Changes |
|------|--------|-------------|
| `references/bounded-review-loop.md` | ✅ NEW | Parameterized loop pattern (used by all 3 review sites) |
| `references/functional-area-classification.md` | ✅ NEW | Backend/Frontend keyword single source of truth |
| `references/bdd-acceptance-criteria.md` | ✅ NEW | Gherkin + test traceability (no runner) |
| `msad-dev-planning/SKILL.md` | ✅ DONE | Step 5a (conflict batching), Step 7b (bounded loop), traceability tables |
| `msad-dev-execution/SKILL.md` | ✅ DONE | Batch dispatch, bounded code-review, rich PR template |
| `msad-dev-epic/SKILL.md` | ✅ DONE | Gating loop architecture, cite references |
| `msad-plan-epic/SKILL.md` | 🔄 IN PROGRESS | Step 7b, Gherkin authoring, disk-write + approval |
| `README.md` (toolkit root) | 🔄 IN PROGRESS | Rewrite Quick Start |
| `skills/msad-dev-epic/README.md` | 🔄 IN PROGRESS | Rewrite (currently contradicts SKILL.md) |
| `skills/msad-dev-epic/SKILL.md` | ✅ DONE | — |
| `skills/msad-dev-execution/README.md` | ✅ DONE | Now matches SKILL.md, draft-PR-only |
| `skills/msad-dev-story/` | ✅ DELETED | Merged into msad-dev-epic |
| `skills/msad-dev-execution/PR-GAP-HANDLING.md` | ✅ DELETED | Conflicts with human gate |
| `skills/msad-developer/SKILL.md` | 🔄 IN PROGRESS | Update routing |
| `agents/msad-backend-dev.agent.md` | 🔄 IN PROGRESS | Cite git-discipline, TDD hard gate |
| `agents/msad-code-review.agent.md` | 🔄 IN PROGRESS | Scenario-traceability checklist |
| `references/plan-reviewer-prompt.md` | 🔄 IN PROGRESS | Split variants, cite bounded-loop |

---

## Critical Path to Completion

1. **msad-plan-epic/SKILL.md** (~30 min) — enables structure-plan gating
2. **README.md** (~30 min) — communicates new architecture to users
3. **Reference doc split** (~20 min) — clean up reviewer prompts
4. **Satellite doc cleanup** (~60 min) — resolve contradictions
5. **Final agent updates** (~30 min) — polish
6. **Verification** (~30 min) — grep + trace + confirm

**Total:** ~3 hours for remaining work

---

## Testing the Redesign

Once all steps complete, trace one hypothetical epic (e.g., DDIDNS-7732) through the full pipeline:

1. `/msad-plan-epic DDIDNS-7732` → structure plan (stories + Backend/Frontend split)
2. Plan → bounded-review loop (≤2 rounds) → user approval (status: approved)
3. `/msad-plan-epic --create` → create stories in Jira
4. Per story: `/msad-dev-planning <story-id>` → dev plan (Gherkin + conflict batches)
5. Dev plan → bounded-review loop (≤3 rounds) → user approval
6. `/msad-dev-execution <plan>` → implementation (parallel batches) → bounded code-review → draft PRs
7. PRs ready for human review/merge

**Every stage has a bounded-review gate. No code path skips planning approval.**

