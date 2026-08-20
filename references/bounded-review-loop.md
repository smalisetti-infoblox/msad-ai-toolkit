# Bounded Review Loop — Shared Pattern

A reusable review-and-fix loop used by three different skills: `msad-plan-epic` (structure-plan review), `msad-dev-planning` (dev-plan review), and `msad-dev-execution` (code review). Each caller parametrizes the loop and supplies its own reviewer prompt/checklist, but the loop mechanics are shared to ensure consistent rigor and escalation behavior.

## Parameters (Each Caller Instantiates These)

- **artifact** (string): what's under review — "epic structure plan" / "dev plan" / "code diff"
- **reviewer** (function/prompt): which agent/prompt performs the review (plan-reviewer-prompt.md variant, msad-code-review agent, etc.)
- **max_rounds** (integer, default 3): maximum number of review iterations; structure-plan overrides to 2
- **severity_scheme** (enum): MUST/SHOULD/MAY (code reviews) or Blocking/Should-Fix/Minor (plan reviews) — shapes the triage language
- **convergence_condition** (predicate): stops looping when met; typically "zero MUST/Blocking findings outstanding; SHOULD/Should-Fix may be justified-and-logged"
- **escalation_on_non_convergence** (behavior): what happens if loop exits without convergence after `max_rounds` — always surfaces full finding list + ledger to user and requires an explicit human decision (proceed-with-justification / revise-manually / abandon)

## State

An append-only `ledger` tracking every finding + its resolution (fixed / justified-deferred / escalated). Attached to:
- Plan files: in frontmatter or a "Known Issues / Deferred Findings" section
- PR: in the "Known Issues / Deferred Review Findings" section of the PR body

The ledger is what makes non-convergence auditable — a future reader can see why a SHOULD-level finding wasn't addressed.

## Generic Loop (Pseudocode)

```
round = 0
ledger = []

loop:
  round += 1
  findings = reviewer.review(artifact)
  if findings is empty:
    return CONVERGED(round, ledger)
  
  triage(findings) -> {must_fix, should_fix_unjustified, should_fix_justified, may_fix}
  
  # Record all findings in ledger
  for each finding in findings:
    if finding.status == "fixed_in_this_round":
      ledger.append({finding, resolution: "fixed", round})
    elif finding.status == "justified_deferred":
      ledger.append({finding, resolution: "deferred", justification: "...", round})
    elif finding.status == "may_fix":
      ledger.append({finding, resolution: "acknowledged", round})
  
  # Triage and act
  if must_fix.count() == 0 and should_fix_unjustified.count() == 0:
    # Convergence achieved
    return CONVERGED(round, ledger)
  
  if round >= max_rounds:
    # Non-convergence; escalate
    return ESCALATE(round, must_fix, should_fix_unjustified, ledger)
  
  # Not converged and rounds remain; apply fixes and loop
  apply_fixes_and_justifications(must_fix, should_fix_justified)
  goto loop
```

## Return Values

### CONVERGED(round, ledger)
- **Artifact is approved** — zero MUST/Blocking outstanding; any SHOULD/Should-Fix items were either fixed or explicitly justified-and-logged.
- **Ledger is final** — appended to the artifact (plan file or PR) for future auditing.
- **Next stage proceeds** (e.g., dev-plan review → execution; code review → merge gate).

### ESCALATE(round, must_fix, should_fix_unjustified, ledger)
- **Loop stopped at max_rounds without convergence** — MUST/Blocking findings or unjustified SHOULD items remain.
- **User sees**: full finding list + ledger + current artifact state.
- **User decides** (explicit choice required):
  1. **Proceed with justification** — "I accept the SHOULD findings; log them and proceed" (ledger updated with user's justification, artifact approved).
  2. **Revise manually** — "I'll fix this locally and re-enter the loop" (reviewer re-runs, round counter continues).
  3. **Abandon** — "Skip this artifact / reject the plan / don't merge the PR" (loop exits cleanly; artifact rejected).
- **Never silent, never unbounded** — there is always a human decision point if the loop doesn't converge.

## Severity Scheme Alignment

### Code Reviews (via msad-code-review agent)
- **MUST**: correctness bug, security issue, or missing acceptance-criteria coverage. Fix before merge.
- **SHOULD**: design/performance/readability improvement; low-risk. Can be deferred if justified (e.g., "addressed in follow-up ticket DDIDNS-XXXXX").
- **MAY**: nit or suggestion. Acknowledge and move on.

### Plan Reviews (via plan-reviewer-prompt.md variants)
- **Blocking**: scope gap, unclear dependency, or assumption-without-verification. Revise before approval.
- **Should-Fix**: useful feedback, but not blocking if addressed carefully (e.g., "flagged in ledger for implementation").
- **Minor**: nit or suggestion.

**Convergence rule for both:** zero MUST/Blocking outstanding. All SHOULD/Should-Fix must be either fixed or explicitly justified-deferred-with-ledger-entry.

## Usage Sites

### 1. msad-plan-epic (Step 7b: Structure-Plan Bounded Review)
```
Parameters:
  artifact: "epic structure plan" (markdown file at specs/msad-epic-plans/...)
  reviewer: fresh-context agent with plan-reviewer-prompt.md "structure-plan" variant
  max_rounds: 2 (structure plans are cheap to redo)
  severity_scheme: Blocking/Should-Fix/Minor
  convergence_condition: zero Blocking findings
  escalation_on_non_convergence: surface findings + ledger, user decides (approve-with-justification / revise / reject)
Output: plan file with status: draft -> approved (or rejected)
```

### 2. msad-dev-planning (Step 7b: Dev-Plan Bounded Review)
```
Parameters:
  artifact: "dev plan" (markdown file at specs/msad-dev-plans/...)
  reviewer: fresh-context agent with plan-reviewer-prompt.md "dev-plan" variant
  max_rounds: 3
  severity_scheme: Blocking/Should-Fix/Minor
  convergence_condition: zero Blocking findings
  escalation_on_non_convergence: surface findings + ledger, user decides (approve-with-justification / revise / reject)
Output: plan file with status: draft -> approved (or rejected)
```

### 3. msad-dev-execution (Step 4: Code-Review Bounded Loop)
```
Parameters:
  artifact: "code diff" (pull request)
  reviewer: msad-code-review agent
  max_rounds: 3
  severity_scheme: MUST/SHOULD/MAY
  convergence_condition: zero MUST findings; SHOULD items are either fixed or justified-deferred
  escalation_on_non_convergence: surface findings + ledger, user decides (proceed / revise / abandon)
Output: PR with "Known Issues / Deferred Review Findings" section updated; moves to draft-PR stage or loops
```

## Properties

- **Consistent across all three sites**: same loop shape, same escalation contract, same ledger-as-audit-trail.
- **Locally parameterized**: each site sets its own max_rounds, severity_scheme, and reviewer prompt. No global governance.
- **Always bounded**: never loops unbounded. Never silently proceeds without human approval when non-convergence occurs.
- **Auditable**: ledger is permanent; a future reader can see which findings were fixed, which were deferred-with-justification, and which escalated to user decision.

## Anti-Patterns

- **Don't loop unbounded if convergence fails.** Always stop at `max_rounds` and escalate.
- **Don't proceed silently when MUST/Blocking items remain.** Always surface them to the user and get an explicit decision.
- **Don't lose the ledger.** Attach it to the artifact so it survives merges and handoffs.
- **Don't redefine convergence_condition per-site.** The shared rule is: zero MUST/Blocking, SHOULD is justified-or-fixed.
