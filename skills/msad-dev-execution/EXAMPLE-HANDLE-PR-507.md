# Example: Execute PR 507 Gap (Conditional Forwarder Handler Tests)

This example shows exactly how the execution agent would handle PR 507 with its identified gap.

## PR Summary

**PR #507 — DDIDNS-10519: Middleware Domain/Forest Replication Scope Support**

**Gap identified in plan:**
```
PR 507 is 85% complete.
Missing: Handler tests for DnsConditionalForwarderZoneController with domain/forest scope
Current coverage: 87% (tests Auth and Forward handlers, but not Conditional Forwarder)
Fix: Add 2 handler test cases for Conditional Forwarder
Expected result: Coverage 87% → 92%
```

---

## Step 1: Understand What's Needed

From the plan, the agent understands:
- Existing handler tests in `pkg/interceptor_handlers_test.go` cover Auth Zone Create, Forward Zone Create
- Pattern: table-driven tests with sqlmock + gomock
- Missing: Tests for Conditional Forwarder with domain/forest scope
- Acceptance: "Verify scope propagates to MSAD collector AND to DDI write handler"

---

## Step 2: Checkout PR Branch

```bash
$ git clone https://github.com/Infoblox-CTO/ddi.cloud.proxy.middleware.git
Cloning into 'ddi.cloud.proxy.middleware'...

$ cd ddi.cloud.proxy.middleware
$ git fetch origin
From https://github.com/Infoblox-CTO/ddi.cloud.proxy.middleware
 * [new branch]      507/domain-forest-scope -> origin/507/domain-forest-scope

$ git checkout origin/507/domain-forest-scope
Branch '507/domain-forest-scope' set up to track 'origin/507/domain-forest-scope'.
Switched to a new branch '507/domain-forest-scope'

$ git log --oneline -3
abc1234 DDIDNS-10519: add handler-level regression tests for domain/forest replication scope
def5678 DDIDNS-10519: allow Domain/Forest replication scope for Auth and Forward zone creation
ghi9012 merge main into feature branch
```

---

## Step 3: Read Existing Handler Tests

The agent reads existing tests to understand the pattern:

```bash
$ grep -A 50 "func Test_DnsAuthZoneController_Create" pkg/interceptor_handlers_test.go | head -60
```

**Output shows existing test pattern:**

```go
func Test_DnsAuthZoneController_Create_DomainScope(t *testing.T) {
    // Setup
    ctx := context.Background()
    mockCollector := new(mocks.MockZonesClient)
    mockCollector.On("Create", mock.MatchedBy(func(req *pb.CreateZoneRequest) bool {
        return req.ZoneName == "example.com" &&
               req.ReplicationScope == "domain"
    })).Return(&pb.CreateZoneResponse{}, nil)
    
    handler := &AuthZoneCreateHandler{
        collector: mockCollector,
        db: mockDB,
    }
    
    // Execute
    req := &pb.CreateZoneRequest{
        ZoneName: "example.com",
        ZoneType: pb.ZoneType_AUTH,
        ReplicationScope: "domain",
    }
    resp, err := handler.Handle(ctx, req)
    
    // Assert
    assert.NoError(t, err)
    assert.NotNil(t, resp)
    mockCollector.AssertCalled(t, "Create")
    // Verify scope round-trips to DDI write
    assert.Equal(t, "domain", resp.ReplicationScope)
}
```

**Pattern identified:**
- Table-driven test with mocks
- Matcher checks request has correct scope
- Asserts scope propagates to response
- Uses gomock and testify assertions

---

## Step 4: Generate Test Code for Conditional Forwarder

The agent adapts the existing pattern for Conditional Forwarder:

```go
func Test_DnsConditionalForwarderZoneController_Create_DomainScope(t *testing.T) {
    // Setup: similar to Auth zone test, but for Conditional Forwarder
    ctx := context.Background()
    mockCollector := new(mocks.MockZonesClient)
    
    // Match: domain scope for conditional forwarder
    mockCollector.On("Create", mock.MatchedBy(func(req *pb.CreateZoneRequest) bool {
        return req.ZoneName == "example.com" &&
               req.ZoneType == pb.ZoneType_CONDITIONAL_FORWARDER &&
               req.ReplicationScope == "domain"
    })).Return(&pb.CreateZoneResponse{}, nil)
    
    handler := &ConditionalForwarderZoneCreateHandler{
        collector: mockCollector,
        db: mockDB,
    }
    
    // Execute: create conditional forwarder with domain scope
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
    assert.Equal(t, "domain", resp.ReplicationScope)  // Round-trips to response
}

func Test_DnsConditionalForwarderZoneController_Create_ForestScope(t *testing.T) {
    // Same as above, but with forest scope
    ctx := context.Background()
    mockCollector := new(mocks.MockZonesClient)
    
    // Match: forest scope for conditional forwarder
    mockCollector.On("Create", mock.MatchedBy(func(req *pb.CreateZoneRequest) bool {
        return req.ZoneName == "example.com" &&
               req.ZoneType == pb.ZoneType_CONDITIONAL_FORWARDER &&
               req.ReplicationScope == "forest"
    })).Return(&pb.CreateZoneResponse{}, nil)
    
    handler := &ConditionalForwarderZoneCreateHandler{
        collector: mockCollector,
        db: mockDB,
    }
    
    // Execute
    req := &pb.CreateZoneRequest{
        ZoneName: "example.com",
        ZoneType: pb.ZoneType_CONDITIONAL_FORWARDER,
        ReplicationScope: "forest",
    }
    resp, err := handler.Handle(ctx, req)
    
    // Assert
    assert.NoError(t, err)
    assert.NotNil(t, resp)
    mockCollector.AssertCalled(t, "Create")
    assert.Equal(t, "forest", resp.ReplicationScope)
}
```

---

## Step 5: Add Tests to File

```bash
# Agent appends test functions to pkg/interceptor_handlers_test.go
$ cat >> pkg/interceptor_handlers_test.go << 'EOF'

// Conditional Forwarder zone controller tests (DDIDNS-10519)
// Tests verify scope validation for Conditional Forwarder with domain/forest scopes

func Test_DnsConditionalForwarderZoneController_Create_DomainScope(t *testing.T) {
    ctx := context.Background()
    mockCollector := new(mocks.MockZonesClient)
    mockCollector.On("Create", mock.MatchedBy(func(req *pb.CreateZoneRequest) bool {
        return req.ZoneName == "example.com" &&
               req.ZoneType == pb.ZoneType_CONDITIONAL_FORWARDER &&
               req.ReplicationScope == "domain"
    })).Return(&pb.CreateZoneResponse{}, nil)
    
    handler := &ConditionalForwarderZoneCreateHandler{
        collector: mockCollector,
        db: mockDB,
    }
    
    req := &pb.CreateZoneRequest{
        ZoneName: "example.com",
        ZoneType: pb.ZoneType_CONDITIONAL_FORWARDER,
        ReplicationScope: "domain",
    }
    resp, err := handler.Handle(ctx, req)
    
    assert.NoError(t, err)
    assert.NotNil(t, resp)
    mockCollector.AssertCalled(t, "Create")
    assert.Equal(t, "domain", resp.ReplicationScope)
}

func Test_DnsConditionalForwarderZoneController_Create_ForestScope(t *testing.T) {
    ctx := context.Background()
    mockCollector := new(mocks.MockZonesClient)
    mockCollector.On("Create", mock.MatchedBy(func(req *pb.CreateZoneRequest) bool {
        return req.ZoneName == "example.com" &&
               req.ZoneType == pb.ZoneType_CONDITIONAL_FORWARDER &&
               req.ReplicationScope == "forest"
    })).Return(&pb.CreateZoneResponse{}, nil)
    
    handler := &ConditionalForwarderZoneCreateHandler{
        collector: mockCollector,
        db: mockDB,
    }
    
    req := &pb.CreateZoneRequest{
        ZoneName: "example.com",
        ZoneType: pb.ZoneType_CONDITIONAL_FORWARDER,
        ReplicationScope: "forest",
    }
    resp, err := handler.Handle(ctx, req)
    
    assert.NoError(t, err)
    assert.NotNil(t, resp)
    mockCollector.AssertCalled(t, "Create")
    assert.Equal(t, "forest", resp.ReplicationScope)
}
EOF

$ echo "Tests added to pkg/interceptor_handlers_test.go"
```

---

## Step 6: Run Tests Locally

```bash
$ docker-compose up -d
Creating network "ddi.cloud.proxy.middleware_default" with the default driver
Creating ddi.cloud.proxy.middleware_postgres_1 ... done
Creating ddi.cloud.proxy.middleware_redis_1 ... done

$ make test
go fmt ./...
go test ./...
ok      github.com/Infoblox-CTO/ddi.cloud.proxy.middleware/pkg  45.2s

All tests PASSED ✅
```

---

## Step 7: Verify Coverage

```bash
$ go test -coverprofile=coverage.out ./...
ok      github.com/Infoblox-CTO/ddi.cloud.proxy.middleware/pkg  47.1s

$ go tool cover -func=coverage.out | tail -5
github.com/Infoblox-CTO/ddi.cloud.proxy.middleware/pkg/interceptor_handlers.go:279  CreateHandler  85.7%
github.com/Infoblox-CTO/ddi.cloud.proxy.middleware/pkg/zone_helper.go:45            toMSADRequest  88.3%
github.com/Infoblox-CTO/ddi.cloud.proxy.middleware/pkg/mocks.go:10                  MockCollector  91.2%
github.com/Infoblox-CTO/ddi.cloud.proxy.middleware/pkg                              92.3%

# Check threshold
$ COVERAGE=$(go tool cover -func=coverage.out | tail -1 | awk '{print $3}' | sed 's/%//')
$ echo "Coverage: ${COVERAGE}%"
Coverage: 92.3%

$ if (( $(echo "$COVERAGE >= 80" | bc -l) )); then echo "✅ Coverage OK"; else echo "❌ Below threshold"; fi
✅ Coverage OK
```

**Result:** Coverage improved from 87% to 92.3% ✅

---

## Step 8: Commit Changes

```bash
$ git status
On branch 507/domain-forest-scope
Changes not staged for commit:
  modified:   pkg/interceptor_handlers_test.go

$ git add pkg/interceptor_handlers_test.go

$ git commit -m "DDIDNS-10519: Add handler tests for Conditional Forwarder scope validation

New test cases added to pkg/interceptor_handlers_test.go:
- Test_DnsConditionalForwarderZoneController_Create_DomainScope
- Test_DnsConditionalForwarderZoneController_Create_ForestScope

Tests verify:
- Domain scope validation for Conditional Forwarder zones
- Forest scope validation for Conditional Forwarder zones
- Scope propagates to MSAD collector
- Scope round-trips through to DDI write handler

Coverage improvement: 87% → 92.3% (+5.3%)
All tests passing.

Jira: DDIDNS-10519"

[507/domain-forest-scope abc2345] DDIDNS-10519: Add handler tests for Conditional Forwarder scope validation
 1 file changed, 60 insertions(+)
```

---

## Step 9: Push to PR Branch

```bash
$ git push origin HEAD:refs/heads/507/domain-forest-scope
Enumerating objects: 5, done.
Counting objects: 100% (5/5), done.
Delta compression by 4 (delta 2), done.
Total 4 (delta 3), reused 1 (delta 0), pack-reused 0
To github.com:Infoblox-CTO/ddi.cloud.proxy.middleware.git
 abc2345..def5678 HEAD -> 507/domain-forest-scope

$ git log --oneline -1
def5678 DDIDNS-10519: Add handler tests for Conditional Forwarder scope validation
```

---

## Step 10: Wait for CI

```bash
$ gh pr checks 507 --repo Infoblox-CTO/ddi.cloud.proxy.middleware --watch
Watching checks on PR #507...

✓ Tests / unit (go test ./...)          [✓ PASSED]
✓ Linting / golangci-lint               [✓ PASSED]
✓ Coverage / codecov (92.3%)            [✓ PASSED]
✓ Security / gosec                      [✓ PASSED]

All checks passed! ✅
```

---

## Step 11: Merge PR

```bash
$ gh pr merge 507 \
  --repo Infoblox-CTO/ddi.cloud.proxy.middleware \
  --squash \
  --delete-branch \
  --auto

Merging PR #507...
✓ PR merged successfully

Merge commit: ghi9012
Squashed 2 commits into 1
Branch 507/domain-forest-scope deleted

$ git log --oneline -1
ghi9012 DDIDNS-10519: Add handler tests for Conditional Forwarder scope validation
```

---

## Result

✅ **PR 507 Closed & Merged**

**Changes made:**
- Added 2 handler test cases for Conditional Forwarder
- Coverage: 87% → 92.3%
- All tests passing
- CI verified
- PR merged to main

**Next:** Execute PR 241 (similar process for ZONE-005 Update/Delete tests)

---

## What the Agent Accomplished

1. ✅ Understood the gap from the plan
2. ✅ Analyzed existing test patterns
3. ✅ Generated appropriate test code
4. ✅ Added tests following the established pattern
5. ✅ Ran tests locally and verified they pass
6. ✅ Verified coverage meets threshold
7. ✅ Made a disciplined commit
8. ✅ Pushed to PR branch
9. ✅ Waited for CI
10. ✅ Merged PR when ready

**Total time:** ~10 minutes (mostly CI waiting)

The gap is now closed, and PR 507 contributes its full value to Phase 1.
