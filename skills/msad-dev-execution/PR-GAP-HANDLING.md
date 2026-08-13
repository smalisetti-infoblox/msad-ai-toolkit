# PR Gap Handling Workflow

When the execution plan identifies gaps in existing PRs, the execution skill handles them systematically.

## Overview

```
Plan identifies PR gaps:
  "PR 507: Missing Conditional Forwarder handler tests"
  ↓
Execution agent:
  1. Checkout PR branch
  2. Analyze gap (what tests are missing, what pattern to follow)
  3. Generate/write test code
  4. Run tests locally
  5. Verify coverage
  6. Commit changes
  7. Push to PR branch
  8. Wait for CI
  9. Merge PR
```

---

## Step-by-Step Process

### Step 1: Understand the Gap (From Plan)

Read the plan file and extract gap details:

```yaml
PR: 507
Task: DDIDNS-10519
Gap: "Conditional Forwarder scope validation not tested"
Specifics:
  - Missing: DnsConditionalForwarderZoneController handler test
  - Patterns: Table-driven test with sqlmock (like Auth/Forward tests)
  - Test scope values: domain, forest
  - Assertion: scope round-trips to DDI write handler
  
Planned fix:
  - Add: Test_DnsConditionalForwarderZoneController_Create_DomainScope
  - Add: Test_DnsConditionalForwarderZoneController_Create_ForestScope
  - File: pkg/interceptor_handlers_test.go
  - Expected coverage improvement: 87% → 92%
```

### Step 2: Checkout PR Branch

```bash
# Clone repo if not already cloned
git clone https://github.com/Infoblox-CTO/ddi.cloud.proxy.middleware.git
cd ddi.cloud.proxy.middleware

# Fetch all PR branches
git fetch origin

# Checkout the PR branch
git checkout origin/507/branch  # or whatever branch name the PR uses
```

### Step 3: Analyze Existing Patterns

Before writing new tests, read existing tests to match the pattern:

```bash
# Read existing handler tests to understand pattern
grep -A 30 "func Test_DnsAuthZoneController_Create_DomainScope" pkg/interceptor_handlers_test.go
```

Expected pattern:
```go
func Test_DnsAuthZoneController_Create_DomainScope(t *testing.T) {
    // Setup
    mockCollector := /* mock with domain scope request */
    
    // Execute
    handler := &AuthZoneCreateHandler{}
    result := handler.Handle(ctx, request)
    
    // Assert
    assert.NoError(t, result.Err)
    mockCollector.AssertCalled(t, "Create", matchDomainScope)
}
```

### Step 4: Generate Test Code

Write new test code following the existing pattern.

**For PR 507 - Conditional Forwarder handler tests:**

```go
func Test_DnsConditionalForwarderZoneController_Create_DomainScope(t *testing.T) {
    // Setup: mock MSAD collector expecting domain scope
    mockCollector := new(mocks.MockZonesClient)
    mockCollector.On("Create", mock.MatchedBy(func(req *pb.CreateZoneRequest) bool {
        return req.ReplicationScope == "domain"
    })).Return(&pb.CreateZoneResponse{ZoneId: "test-zone-1"}, nil)
    
    // Execute: create zone with domain scope
    handler := &ConditionalForwarderZoneCreateHandler{
        collector: mockCollector,
    }
    ctx := context.Background()
    req := &pb.CreateZoneRequest{
        ZoneName: "example.com",
        ZoneType: pb.ZoneType_CONDITIONAL_FORWARDER,
        ReplicationScope: "domain",
    }
    resp, err := handler.Handle(ctx, req)
    
    // Assert: scope propagates correctly
    assert.NoError(t, err)
    assert.NotNil(t, resp)
    mockCollector.AssertCalled(t, "Create")
    // Verify scope made it to DB write
    assert.Equal(t, "domain", resp.ReplicationScope)
}

func Test_DnsConditionalForwarderZoneController_Create_ForestScope(t *testing.T) {
    // Similar to above, but with forest scope
    // ...
}
```

### Step 5: Add Tests to File

```bash
# Open editor and add test functions to pkg/interceptor_handlers_test.go
# Add after existing Auth/Forward handler tests

# Or programmatically:
cat >> pkg/interceptor_handlers_test.go << 'EOF'

// Tests for Conditional Forwarder zone controller (DDIDNS-10519)
func Test_DnsConditionalForwarderZoneController_Create_DomainScope(t *testing.T) {
    // ... test code here ...
}

func Test_DnsConditionalForwarderZoneController_Create_ForestScope(t *testing.T) {
    // ... test code here ...
}
EOF
```

### Step 6: Run Tests Locally

```bash
# Start services (PostgreSQL, Redis, etc.)
docker-compose up -d

# Run tests
make test

# Check exit code
echo "Test result: $?"

# If tests fail, debug and fix
# If tests pass, continue to step 7
```

Example output:
```
go test ./...
ok      github.com/Infoblox-CTO/ddi.cloud.proxy.middleware/pkg  45.2s
PASS

Coverage: (go tool cover -func=coverage.out | tail -1)
total:  (statements)  92.3%
```

### Step 7: Verify Coverage

```bash
# Generate coverage report
go test -coverprofile=coverage.out ./...

# Check coverage percentage
go tool cover -func=coverage.out | tail -1
# Output: total: (statements) 92.3%

# Verify threshold
COVERAGE=$(go tool cover -func=coverage.out | tail -1 | awk '{print $3}' | sed 's/%//')
THRESHOLD=80
if (( $(echo "$COVERAGE >= $THRESHOLD" | bc -l) )); then
    echo "✅ Coverage OK: ${COVERAGE}% >= ${THRESHOLD}%"
else
    echo "❌ Coverage insufficient: ${COVERAGE}% < ${THRESHOLD}%"
    exit 1
fi
```

### Step 8: Commit Changes

Follow git commit discipline: **additions only** (new test code, no modifications to existing code)

```bash
# Stage the changes
git add pkg/interceptor_handlers_test.go

# Commit with disciplined message
git commit -m "DDIDNS-10519: Add handler tests for Conditional Forwarder scope validation

New test cases in pkg/interceptor_handlers_test.go:
- Test_DnsConditionalForwarderZoneController_Create_DomainScope
- Test_DnsConditionalForwarderZoneController_Create_ForestScope

Tests verify:
- Domain scope validation for Conditional Forwarder zones
- Forest scope validation for Conditional Forwarder zones
- Scope propagation to MSAD collector
- Scope round-trips to DDI write handler

Coverage improvement: 87% → 92% (+5%)
All tests passing.

Jira: DDIDNS-10519"
```

### Step 9: Push to PR Branch

```bash
# Push changes back to PR branch
git push origin HEAD:refs/heads/<pr_branch_name>

# Verify push succeeded
echo "Push exit code: $?"
```

### Step 10: Wait for CI

```bash
# Watch for CI checks to complete
gh pr checks <PR_NUMBER> --repo Infoblox-CTO/ddi.cloud.proxy.middleware --watch

# Wait until all checks are green
# (linting, tests, coverage, security)
```

Expected output:
```
Checks on PR #507
✓ Tests / unit (go test ./...)
✓ Linting / golangci-lint
✓ Coverage / codecov (92.3%)
✓ Security / gosec
All checks passed!
```

### Step 11: Merge PR

```bash
# Merge PR using GitHub CLI
gh pr merge 507 \
  --repo Infoblox-CTO/ddi.cloud.proxy.middleware \
  --squash \
  --delete-branch \
  --auto

# Verify merge
echo "Merge exit code: $?"
```

---

## Handling Different Gap Types

### Gap Type 1: Missing Test Cases

**Example:** PR 241 needs ZONE-005 test in Update and Delete paths

**Process:**
1. Read existing `TestUpdate` and `TestDelete` functions in `zones_test.go`
2. Copy test structure (table-driven pattern)
3. Add new case for ZONE-005 in both tables
4. Run tests
5. Commit: "Add ZONE-005 test case for Update/Delete paths"

### Gap Type 2: Missing Handler Tests

**Example:** PR 507 needs Conditional Forwarder handler tests

**Process:**
1. Read existing handler test (Auth Zone Create test)
2. Copy structure
3. Change handler type to ConditionalForwarder
4. Change assertions (if needed)
5. Run tests
6. Commit: "Add Conditional Forwarder handler tests"

### Gap Type 3: Coverage Gaps

**Example:** PR has tests but coverage is 87% instead of 92%

**Process:**
1. Identify uncovered code: `go tool cover -html=coverage.out`
2. Write tests for uncovered lines
3. Verify coverage improves to ≥80%
4. Commit: "Improve test coverage to 92%"

### Gap Type 4: Edge Cases

**Example:** PR doesn't handle scope validation for zone type X

**Process:**
1. Identify missing edge case
2. Write test for the edge case
3. If test fails, fix implementation
4. Commit: Add test + fix (separate commits if both add and modify)

---

## Error Handling

### If Tests Fail

```bash
# Run tests with verbose output
make test -v

# Identify failure
# Fix the test code or implementation
# Re-run tests until passing
# Only then commit
```

### If Coverage Drops Below Threshold

```bash
# Check coverage
go tool cover -html=coverage.out

# Identify gaps
# Write tests for uncovered code
# Re-run until threshold met
```

### If Lint/Fmt Fails

```bash
# Run formatter
make fmt

# Re-run linter
make lint

# Fix issues
# Commit: "Fix lint/fmt issues"
```

### If CI Fails on Push

```bash
# Check CI logs via GitHub
gh pr checks 507 --repo Infoblox-CTO/ddi.cloud.proxy.middleware

# Identify failure (lint, test, coverage, security)
# Fix locally
# Commit and push again
```

---

## Summary Checklist

For each PR with gaps:

- [ ] Understand gap (from plan)
- [ ] Checkout PR branch
- [ ] Analyze existing patterns (read similar tests)
- [ ] Generate test code (write new tests)
- [ ] Add tests to file
- [ ] Run tests locally (`make test`)
- [ ] Verify coverage ≥ threshold
- [ ] Commit with discipline
- [ ] Push to PR branch
- [ ] Wait for CI to pass
- [ ] Merge PR
- [ ] Verify main branch healthy
- [ ] Report completion

When all checks pass: PR is ready to merge and part of Phase 1 completion.

---

## Example: Full Execution for PR 507

```bash
#!/bin/bash
set -e

# Step 1: Clone & checkout
git clone https://github.com/Infoblox-CTO/ddi.cloud.proxy.middleware.git
cd ddi.cloud.proxy.middleware
git fetch origin
git checkout origin/507/branch

# Step 2-4: Analyze pattern & generate tests
# (Read existing tests, write new tests to pkg/interceptor_handlers_test.go)
# ... edit file ...

# Step 5-6: Run tests
docker-compose up -d
make test
RESULT=$?

if [ $RESULT -ne 0 ]; then
    echo "Tests failed!"
    docker-compose down
    exit 1
fi

# Step 7: Verify coverage
COVERAGE=$(go tool cover -func=coverage.out | tail -1 | awk '{print $3}' | sed 's/%//')
echo "Coverage: ${COVERAGE}%"

if (( $(echo "$COVERAGE < 80" | bc -l) )); then
    echo "Coverage below threshold!"
    docker-compose down
    exit 1
fi

docker-compose down

# Step 8: Commit
git add pkg/interceptor_handlers_test.go
git commit -m "DDIDNS-10519: Add Conditional Forwarder handler tests

Coverage: 87% → 92%"

# Step 9: Push
git push origin HEAD:refs/heads/<pr_branch>

# Step 10: Wait for CI
gh pr checks 507 --repo Infoblox-CTO/ddi.cloud.proxy.middleware --watch

# Step 11: Merge
gh pr merge 507 --repo Infoblox-CTO/ddi.cloud.proxy.middleware --squash

echo "✅ PR 507 merged successfully"
```

---

## For LLM Agents

When handling PR gaps, you have these capabilities:

1. **Read execution plan** — understand what tests are needed
2. **Read existing code** — patterns to follow
3. **Generate test code** — write table-driven tests, handler tests, etc.
4. **Run local tests** — verify before pushing
5. **Make git commits** — follow discipline
6. **Push and wait** — integrate with GitHub CI
7. **Merge PRs** — finalize when ready

Use these systematically to close gaps and complete partial PRs.
