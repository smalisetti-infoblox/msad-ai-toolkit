# Example: Execute PR 241 Gap (ZONE-005 Update/Delete Tests)

> **⚠️ Non-authoritative example.** This document is an example and may be out of date. See [`SKILL.md`](SKILL.md) for the authoritative execution process.

This example shows how the execution agent handles a different gap type: missing test cases in existing test functions.

## PR Summary

**PR #241 — DDIDNS-10543: Collector Error-Code Mapping for Update/Delete**

**Gap identified in plan:**
```
PR 241 is 95% complete.
Missing: ZONE-005 test cases in Update and Delete RPC test functions
Current: ZONE-005 unit test exists, but not integrated in Update/Delete paths
Current coverage: 85% (Create path has ZONE-005 case, Update/Delete don't)
Fix: Add table-driven test case for ZONE-005 in Update test, add in Delete test
Expected result: Coverage 85% → 92%
```

---

## Step 1: Understand What's Needed

From the plan, the agent understands:
- `pkg/svc/zones/zones_test.go` has table-driven tests for Create, Update, Delete
- Each test function has cases for: AlreadyExists, PermissionDenied, NotFound, etc.
- Missing: ZONE-005 case in Update and Delete test functions
- Each case should verify `ErrorCodeToStatus` maps ZONE-005 → `codes.InvalidArgument`

---

## Step 2: Checkout PR Branch

```bash
$ git clone https://github.com/Infoblox-CTO/ddi.msad.collector.git
$ cd ddi.msad.collector
$ git fetch origin
$ git checkout origin/241/error-code-mapping
Switched to a new branch '241/error-code-mapping'

$ git log --oneline -3
abc1234 DDIDNS-10543: map ZONE-00x agent error codes to gRPC status on Update/Delete
def5678 DDIDNS-10543: Add ZONE-005 case to ErrorCodeToStatus
ghi9012 merge main
```

---

## Step 3: Read Existing Test Pattern

The agent reads the existing test structure:

```bash
$ grep -A 30 "func TestUpdate" pkg/svc/zones/zones_test.go | head -40
```

**Output shows table-driven pattern:**

```go
func TestUpdate(t *testing.T) {
    testCases := []struct {
        name            string
        request         *pb.UpdateZoneRequest
        mockSetup       func(*mocks.MockProxy)
        expectedStatus  codes.Code
        expectedMessage string
    }{
        {
            name: "success",
            request: &pb.UpdateZoneRequest{ZoneId: "zone-1"},
            mockSetup: func(m *mocks.MockProxy) {
                m.On("Update", mock.Anything).Return(nil)
            },
            expectedStatus: codes.OK,
        },
        {
            name: "zone_already_exists",
            request: &pb.UpdateZoneRequest{ZoneId: "zone-1"},
            mockSetup: func(m *mocks.MockProxy) {
                m.On("Update", mock.Anything).Return(fmt.Errorf("ZONE-002: zone already exists"))
            },
            expectedStatus: codes.AlreadyExists,
        },
        {
            name: "permission_denied",
            mockSetup: func(m *mocks.MockProxy) {
                m.On("Update", mock.Anything).Return(fmt.Errorf("ZONE-003: insufficient permissions"))
            },
            expectedStatus: codes.PermissionDenied,
        },
        // ... more cases ...
    }
    
    for _, tc := range testCases {
        t.Run(tc.name, func(t *testing.T) {
            // Execute test case
            collector := NewZonesServer()
            mockProxy := new(mocks.MockProxy)
            tc.mockSetup(mockProxy)
            collector.proxy = mockProxy
            
            resp, err := collector.Update(context.Background(), tc.request)
            
            // Assert
            if err != nil {
                st, _ := status.FromError(err)
                assert.Equal(t, tc.expectedStatus, st.Code())
            }
        })
    }
}
```

**Pattern identified:**
- Table-driven test with struct for each case
- Each case: name, request, mockSetup, expectedStatus
- mockSetup returns error string like "ZONE-005: invalid zone name"
- Test verifies ErrorCodeToStatus maps error code to correct gRPC status code

---

## Step 4: Identify Missing Test Cases

The agent checks what cases exist:

```bash
$ grep -o 'name: "[^"]*"' pkg/svc/zones/zones_test.go | grep -i zone
name: "success"
name: "zone_already_exists"
name: "permission_denied"
name: "zone_not_found"
name: "unknown_error"
# Missing: "invalid_zone_name" (ZONE-005)
```

**Finding:** ZONE-005 case is missing from Update and Delete tests (but exists in Create test)

---

## Step 5: Generate Test Cases for ZONE-005

The agent creates table entries for ZONE-005 case in Update test:

```go
// For Update test - add to testCases slice:
{
    name: "invalid_zone_name",
    request: &pb.UpdateZoneRequest{ZoneId: ""},
    mockSetup: func(m *mocks.MockProxy) {
        m.On("Update", mock.Anything).Return(fmt.Errorf("ZONE-005: invalid zone name"))
    },
    expectedStatus: codes.InvalidArgument,
},

// Same for Delete test
{
    name: "invalid_zone_name",
    request: &pb.DeleteZoneRequest{ZoneId: ""},
    mockSetup: func(m *mocks.MockProxy) {
        m.On("Delete", mock.Anything).Return(fmt.Errorf("ZONE-005: invalid zone name"))
    },
    expectedStatus: codes.InvalidArgument,
},
```

---

## Step 6: Add Test Cases to File

The agent locates the test functions and inserts the new cases:

```bash
# Find Update test function
$ grep -n "func TestUpdate" pkg/svc/zones/zones_test.go
123:func TestUpdate(t *testing.T) {

# Find where testCases ends (before the for loop)
$ sed -n '123,200p' pkg/svc/zones/zones_test.go | grep -n "for _, tc := range testCases"
50:for _, tc := range testCases

# So testCases slice ends at line ~173 (123 + 50)
# Insert before that line
```

The agent uses a text editor or script to add the ZONE-005 case:

```bash
$ cat > update_test.patch << 'EOF'
--- a/pkg/svc/zones/zones_test.go
+++ b/pkg/svc/zones/zones_test.go
@@ -171,6 +171,15 @@ func TestUpdate(t *testing.T) {
             expectedStatus: codes.Unknown,
         },
+        {
+            name: "invalid_zone_name",
+            request: &pb.UpdateZoneRequest{ZoneId: ""},
+            mockSetup: func(m *mocks.MockProxy) {
+                m.On("Update", mock.Anything).Return(fmt.Errorf("ZONE-005: invalid zone name"))
+            },
+            expectedStatus: codes.InvalidArgument,
+        },
     }
     
     for _, tc := range testCases {
EOF

$ patch < update_test.patch

# Repeat for Delete test function
```

Or directly edit the file:

```bash
# Edit pkg/svc/zones/zones_test.go in TestUpdate function
# Add this case before the closing brace of testCases:

        {
            name: "invalid_zone_name",
            request: &pb.UpdateZoneRequest{ZoneId: ""},
            mockSetup: func(m *mocks.MockProxy) {
                m.On("Update", mock.Anything).Return(fmt.Errorf("ZONE-005: invalid zone name"))
            },
            expectedStatus: codes.InvalidArgument,
        },

# Repeat for TestDelete function with same pattern but for Delete RPC
```

---

## Step 7: Run Tests Locally

```bash
$ docker-compose up -d
Creating network "ddi.msad.collector_default" ...
Creating postgres, redis ... done

$ make test
go fmt ./...
go test ./... -race
ok      github.com/Infoblox-CTO/ddi.msad.collector/pkg/svc  51.3s

All tests PASSED ✅

# Specifically run just zones tests
$ go test ./pkg/svc/zones/... -v
=== RUN   TestUpdate
=== RUN   TestUpdate/success
=== RUN   TestUpdate/zone_already_exists
=== RUN   TestUpdate/permission_denied
=== RUN   TestUpdate/invalid_zone_name      <- NEW TEST CASE
--- PASS: TestUpdate/invalid_zone_name (0.02s)
=== RUN   TestDelete
=== RUN   TestDelete/invalid_zone_name      <- NEW TEST CASE
--- PASS: TestDelete/invalid_zone_name (0.02s)
```

---

## Step 8: Verify Coverage

```bash
$ go test -coverprofile=coverage.out ./...
ok      github.com/Infoblox-CTO/ddi.msad.collector/pkg/svc  52.1s

$ go tool cover -func=coverage.out | tail -5
github.com/Infoblox-CTO/ddi.msad.collector/pkg/svc/zones/zones.go:100   Update         88.5%
github.com/Infoblox-CTO/ddi.msad.collector/pkg/svc/zones/zones.go:150   Delete         89.1%
github.com/Infoblox-CTO/ddi.msad.collector/pkg/svc/zones/zones.go:200   GetErrorCode   95.2%
github.com/Infoblox-CTO/ddi.msad.collector/pkg/svc                       92.1%

# Before: 85%, After: 92.1%
$ COVERAGE=$(go tool cover -func=coverage.out | tail -1 | awk '{print $3}' | sed 's/%//')
$ echo "Coverage improved: 85% → ${COVERAGE}%"
Coverage improved: 85% → 92.1%
```

---

## Step 9: Commit Changes

```bash
$ git status
On branch 241/error-code-mapping
Changes not staged for commit:
  modified:   pkg/svc/zones/zones_test.go

$ git add pkg/svc/zones/zones_test.go

$ git commit -m "DDIDNS-10543: Add ZONE-005 test cases for Update/Delete paths

Added table-driven test cases to verify ZONE-005 (invalid zone name) error mapping:
- TestUpdate: Added case for ZONE-005 → codes.InvalidArgument
- TestDelete: Added case for ZONE-005 → codes.InvalidArgument

Tests verify ErrorCodeToStatus correctly maps ZONE-005 in all three RPC paths:
- Create: already had ZONE-005 case
- Update: NEW (this commit)
- Delete: NEW (this commit)

Coverage improvement: 85% → 92.1% (+7.1%)
All tests passing, including new cases.

Jira: DDIDNS-10543"

[241/error-code-mapping def5678] DDIDNS-10543: Add ZONE-005 test cases for Update/Delete paths
 1 file changed, 20 insertions(+)
```

---

## Step 10: Push to PR Branch

```bash
$ git push origin HEAD:refs/heads/241/error-code-mapping
Enumerating objects: 3, done.
Counting objects: 100% (3/3), done.
Delta compression by 2 (delta 1), reused 1 (delta 0), pack-reused 0
To github.com:Infoblox-CTO/ddi.msad.collector.git
 abc1234..def5678 HEAD -> 241/error-code-mapping

$ git log --oneline -1
def5678 DDIDNS-10543: Add ZONE-005 test cases for Update/Delete paths
```

---

## Step 11: Wait for CI

```bash
$ gh pr checks 241 --repo Infoblox-CTO/ddi.msad.collector --watch
Watching checks on PR #241...

✓ Tests / unit (go test ./...)          [✓ PASSED]
✓ Tests / race (go test -race ./...)    [✓ PASSED]
✓ Linting / golangci-lint               [✓ PASSED]
✓ Linting / nilaway                     [✓ PASSED]
✓ Coverage / codecov (92.1%)            [✓ PASSED]
✓ Security / gosec                      [✓ PASSED]

All checks passed! ✅
```

---

## Step 12: Merge PR

```bash
$ gh pr merge 241 \
  --repo Infoblox-CTO/ddi.msad.collector \
  --squash \
  --delete-branch \
  --auto

Merging PR #241...
✓ PR merged successfully

Merge commit: ghi9012
Squashed 2 commits into 1
Branch 241/error-code-mapping deleted

$ git log --oneline -1
ghi9012 DDIDNS-10543: Add ZONE-005 test cases for Update/Delete paths
```

---

## Result

✅ **PR 241 Closed & Merged**

**Changes made:**
- Added 2 test cases for ZONE-005 error code (Update and Delete paths)
- Coverage: 85% → 92.1% (+7.1%)
- All tests passing, including race detection
- CI verified (linting, security, coverage)
- PR merged to main

**Key difference from PR 507:**
- PR 507: Added entirely new test functions (handler tests)
- PR 241: Added test cases to existing test functions (table-driven)

Both follow the same workflow, just different code patterns.

---

## What the Agent Accomplished

1. ✅ Understood the gap (ZONE-005 missing from Update/Delete)
2. ✅ Read existing test pattern (table-driven struct)
3. ✅ Generated appropriate test cases
4. ✅ Added cases to both Update and Delete test functions
5. ✅ Ran tests and verified they pass
6. ✅ Verified coverage improvement
7. ✅ Made a disciplined commit
8. ✅ Pushed to PR branch
9. ✅ Waited for CI (including race detection)
10. ✅ Merged PR when ready

**Total time:** ~12 minutes (mostly CI waiting)

The gap is now closed. PR 241 has complete coverage and contributes its full value to Phase 1.

---

## Summary: Two Gap Patterns Handled

| Gap Type | Example | Approach | Result |
|---|---|---|---|
| **New test functions** | PR 507: Add Conditional Forwarder handler tests | Read existing test function, copy structure, adapt for new handler type | 87% → 92.3% ✅ |
| **Missing test cases** | PR 241: Add ZONE-005 to Update/Delete | Read table-driven pattern, add new struct entry to existing table | 85% → 92.1% ✅ |

Both gaps closed by:
1. Understanding the pattern
2. Generating appropriate code
3. Running tests locally
4. Verifying coverage
5. Committing and pushing
6. Waiting for CI
7. Merging

The execution agent is now capable of handling both gap types and can systematically complete partial PRs.
