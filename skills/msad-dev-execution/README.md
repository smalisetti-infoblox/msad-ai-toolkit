# MSAD Developer — Execution

**Non-authoritative example document.** See `SKILL.md` for the authoritative process.

Executes MSAD development plans end-to-end:
- Implements new features per approved plan
- Runs tests and validation loops (bounded, ≤3 rounds code review)
- Opens **draft PRs** (never auto-merges — human review gate always applies)

## Input

Approved plan file from `/msad-ai-toolkit/specs/msad-dev-plans/YYYY-MM-DD-DDIDNS-XXXXX-plan.md` with `status: approved`.

The plan contains:
- Gherkin acceptance criteria (Scenario → Test traceability)
- Per-repo work packages (additions/modifications/deletions)
- Parallel Execution Batches (conflict-aware task ordering)
- Cross-repo dependencies and risk assessment

## Output

- ✅ Code changes committed per git-commit-discipline (atomic, additions → mods → deletions)
- ✅ Tests passing locally, coverage ≥80% (or repo threshold)
- ✅ Bounded code-review loop converged (zero MUST, SHOULD justified)
- ✅ **Draft PR(s) opened** per repo (ready for human review/merge)
- ✅ Execution report with results, coverage, test status

## Workflow (Sketch)

**Full authoritative workflow:** See SKILL.md Step 1–6.

```
Step 1: Resolve & Verify Plan
  ├─ Find plan file (by path, Jira ID, or filename)
  └─ Confirm status: approved (refuse if status: draft)

Step 2: Implement (Parallel Batches)
  ├─ For each batch in the plan's "Parallel Execution Batches":
  │  └─ Dispatch msad-backend-dev agents in parallel (within batch)
  └─ Await all batches to complete

Step 3: Per-Repo Testing & Validation
  ├─ Run tests per repo (docker-compose, make test)
  └─ Verify coverage meets threshold

Step 4: Bounded Code Review (≤3 rounds)
  ├─ Run msad-code-review on the diff
  ├─ Triage findings: MUST-fix, SHOULD-fix, MAY-fix
  ├─ Apply fixes (or justify deferred)
  ├─ Loop until convergence (zero MUST, SHOULD justified)
  └─ If non-convergence after 3 rounds → surface to user

Step 5: Final Checks
  └─ Pre-push validation (linting, vet)

Step 5a: Git Commit Discipline
  └─ Commit per plan: additions commit, mods commit, deletions commit (separate, atomic)

Step 6: PR Creation
  ├─ For each repo/package → open draft PR via `gh pr create --draft`
  └─ Include rich template: What/Why/How/Scenario-Traceability/Tests/Future Work/Optimizations/Known Issues
```

## Key Points

**Draft PRs only:** This skill opens draft PRs. It does NOT auto-merge or push to main. Human review and merge is always the final gate.

**Bounded review loop:** The code-review step (Step 4) uses `references/bounded-review-loop.md` pattern — max 3 rounds, hard stop if non-convergent, escalation to user.

**Scenario traceability:** Every Gherkin scenario in the plan's acceptance criteria must map to a test in the code (or be explicitly deferred with a linked follow-up ticket).

**Conflict-aware parallelization:** Dispatch order per "Parallel Execution Batches" in the plan (Step 5a of `/msad-dev-planning`), not ad-hoc.

**See SKILL.md for full authoritative details.**
