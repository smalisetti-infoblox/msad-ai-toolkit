# MSAD Developer — Execution

Executes MSAD development plans, including:
- Implementing new features
- **Completing partial PRs** (new: gaps identified in planning phase)
- Running tests and verification
- Merging code when ready

## Input

Plan file from `/msad-ai-toolkit/specs/msad-dev-plans/YYYY-MM-DD-DDIDNS-XXXXX-WITH-PR-GAPS.md`

The plan contains:
- List of work packages (new implementation vs. existing PRs)
- For existing PRs: identified gaps + planned fixes
- Dependencies and merge order

## Output

- ✅ Code changes committed to PR branches
- ✅ Tests passing, coverage verified
- ✅ PRs merged to main
- ✅ Execution report with results

## Workflow

```
Step 1: Parse Plan
  ├─ Identify existing PRs with gaps
  ├─ Identify new implementation tasks
  └─ Determine execution order

Step 2: Handle Existing PRs (With Gaps)
  ├─ For each PR with gaps:
  │  ├─ Checkout PR branch
  │  ├─ Apply gap fixes (add tests, complete implementation)
  │  ├─ Run tests locally (make test / dotnet test)
  │  ├─ Verify coverage meets threshold
  │  ├─ Commit changes
  │  ├─ Push to PR branch
  │  ├─ Wait for CI (checks, linting)
  │  └─ Merge PR when ready
  │
  └─ For each PR without gaps:
     ├─ Code review (via review agent)
     ├─ Verify CI passing
     └─ Merge PR

Step 3: Handle New Implementation (No PR Yet)
  ├─ For each new task:
  │  ├─ Create feature branch
  │  ├─ Implement per plan
  │  ├─ Run tests
  │  ├─ Verify coverage
  │  ├─ Commit with discipline (additions → modifications → deletions)
  │  ├─ Create PR
  │  ├─ Wait for CI
  │  └─ Merge PR

Step 4: Verification & Reporting
  ├─ Verify all PRs merged
  ├─ Verify no broken main branch
  └─ Report completion
```

## Key Capabilities

### 1. PR Gap Completion

For PRs with identified gaps (e.g., "missing Conditional Forwarder handler tests"):

```
Input: PR 507 with gap "Add handler tests for Conditional Forwarder"
  ↓
Checkout PR branch
  ↓
Generate test code (based on gap description + existing test patterns)
  ↓
Add tests to files specified in plan
  ↓
Run: make test (verify compilation + test pass)
  ↓
Check coverage: ensure ≥80% (or repo threshold)
  ↓
Commit: "DDIDNS-10519: Add Conditional Forwarder handler tests"
  ↓
Push to PR branch
  ↓
Wait for CI (linting, tests on main)
  ↓
Merge when checks pass
```

### 2. Test Generation

Agent can read existing test patterns and generate new tests:

Example: PR 507 needs Conditional Forwarder handler tests

Agent reads existing tests in `pkg/interceptor_handlers_test.go`:
- Pattern: table-driven test with sqlmock
- Naming: `Test_<HandlerType>_<Operation>_<Scenario>`
- Structure: setup → execute → assert

Generates new tests following same pattern:
```go
func Test_DnsConditionalForwarderZoneController_Create_DomainScope(t *testing.T) {
    // Pattern: copy Auth Zone Create test for Conditional Forwarder
    // Change: scope = domain (not local)
    // Assert: scope propagates to collector + DDI write
}
```

### 3. Coverage Verification

Agent runs coverage checks and reports:

```bash
go test -coverprofile=coverage.out ./...
go tool cover -func=coverage.out | grep -E "total:|<function_name>"
```

Output:
```
Coverage: 92% (was 87%, improved by 5%)
Threshold: ≥80% ✅ PASS
```

### 4. CI Integration

Agent waits for CI on PR branch:

```bash
gh pr checks <PR_NUMBER> --repo <REPO> --watch
```

When CI passes, agent can merge:

```bash
gh pr merge <PR_NUMBER> --repo <REPO> --squash
```

### 5. Git Commit Discipline

Agent follows commit discipline (additions → modifications → deletions):

```bash
# If PR 507 needs new test file:
git add pkg/new_test.go
git commit -m "DDIDNS-10519: Add Conditional Forwarder handler tests
New files: pkg/test_conditional_forwarder.go
Pattern: Table-driven test with sqlmock, matching Auth Zone Create tests
Tests cover: domain scope, forest scope, scope propagation to DDI write"

# If PR 507 modifies existing file:
git add pkg/interceptor_handlers_test.go
git commit -m "DDIDNS-10519: Add handler test cases for Conditional Forwarder

Changed: pkg/interceptor_handlers_test.go
Added 2 test cases: domain scope, forest scope
Tests verify scope validation and propagation for Conditional Forwarder zones"
```

---

## Implementation Steps

### For Developers Building on This Skill

1. **Read the plan** (identifies PRs + gaps)
2. **For each PR with gaps:**
   - `git clone <repo> && git fetch origin`
   - `git checkout origin/<pr_branch>`
   - Implement gap fixes (add test files, modify test functions)
   - `make test` (or equivalent for the repo)
   - Verify coverage: `go tool cover -func=coverage.out | tail -1`
   - `git add <files>` + `git commit` (per discipline)
   - `git push origin <pr_branch>:<pr_branch>`
   - `gh pr checks <pr_num> --repo <repo> --watch`
   - `gh pr merge <pr_num> --repo <repo>` when ready
3. **For each PR without gaps:**
   - Run code review (via reviewer agent)
   - Wait for CI
   - Merge

### For LLM Agents Using This Skill

The skill enables you to:

- **Read execution plan** → understand PR gaps
- **Checkout PR branches** → work on existing PRs, not main
- **Generate code** → write tests following existing patterns
- **Run tests** → verify locally before pushing
- **Commit intelligently** → follow git discipline
- **Push & wait for CI** → integrate with GitHub/CI system
- **Merge PRs** → finalize when ready

---

## Safety Guards

The execution skill must ensure:

- ✅ **Never work on main branch** — always checkout PR branches
- ✅ **Never force-push** — use normal push; if conflict, resolve or ask
- ✅ **Always run tests locally first** — before pushing to PR
- ✅ **Verify coverage meets threshold** — don't merge if coverage drops
- ✅ **Follow commit discipline** — separate additions/modifications/deletions
- ✅ **Wait for CI to pass** — don't merge until GitHub checks pass
- ✅ **Explicit merge decision** — ask before merging, or verify readiness

---

## Status

This skill is being implemented to handle DDIDNS-7732 Phase 1 execution.

Capabilities being added:
- [ ] Read execution plan with PR gaps
- [ ] Checkout PR branches
- [ ] Generate/add test code
- [ ] Run tests and verify coverage
- [ ] Commit with discipline
- [ ] Push to PR branch
- [ ] Wait for CI
- [ ] Merge PRs
- [ ] Report results

See `lib/` directory for specific implementations.
