# BDD Acceptance Criteria — Gherkin Authoring + Test Traceability

This document defines how the toolkit uses Gherkin Given/When/Then acceptance criteria (descriptive, BDD-style) alongside imperative TDD test-first discipline (code-level, test-first execution). Gherkin scenarios are **authored** at the story level, **imported** (not re-authored) at the task level, and **traced** (not literally executed) to native TDD tests.

## Why This Approach

- **Descriptive (BDD) + Imperative (TDD):** Gherkin governs *what* a story must collectively demonstrate (requirement/AC level); TDD governs *how* a single test is written (code level, red-green-refactor). Both are satisfied without introducing a Gherkin runner (cucumber/godog/SpecFlow) across six differently-stacked repos (Go + C#).
- **No new tooling:** Uses native test frameworks (Go table-driven tests, xUnit for C#).
- **Auditable traceability:** Plan file documents the Scenario→Test mapping; code-review checklist verifies every scenario has a test.

## Format: Gherkin Given/When/Then

Scenarios are embedded as a fenced markdown block in the Jira story description (and imported verbatim into the dev plan file). One scenario per acceptance-criterion bullet.

```gherkin
Feature: Domain/Forest replication scope on zone creation

  Scenario: User creates a zone with Domain replication scope
    Given a WAPI v3 client authenticated for account <account_id>
    When the client submits a zone-create request with replication_scope = "domain"
    Then the middleware validates and forwards the scope to the MSAD collector
    And the collector maps any scope-validation error to ZONE-005
    And the created zone record in the DB has replication_scope = "domain"

  Scenario: User attempts to create a zone with a legacy replication scope
    Given a WAPI v3 client authenticated for account <account_id>
    When the client submits a zone-create request with replication_scope = "legacy"
    Then dns.config rejects the request before it reaches the middleware
    And no zone record is created
```

## Authoring Location

**Primary:** `msad-plan-epic` at story-creation time (Step 3 / Step 7).
- The planner analyzes the epic and recommends Backend stories with AC bullets.
- Each AC bullet is then expanded into a Gherkin scenario by the skill's story template.
- Result: story description in Jira contains the Gherkin block (or the planner outputs a template for the user to paste).

**Import (not re-author):** `msad-dev-planning` at Step 2 (Jira analysis).
- Fetch the story from Jira; extract the Gherkin block verbatim from the description.
- If a story lacks Gherkin ACs (e.g., legacy backfill), `msad-dev-planning` drafts them at Step 2b and asks the user to confirm / push back to Jira.

## Traceability: Scenario → Test

Gherkin scenarios are **not executed literally** via a test runner. Instead, traceability is enforced via:

### 1. Test-Name and Comment Convention

Each test function/test case is annotated with a comment referencing the scenario:

**Go (table-driven):**
```go
// TestZoneCreate validates zone creation with various scopes.
// Implements scenarios (DDIDNS-10562 AC1–2):
//   - User creates zone with Domain scope (AC1)
//   - User creates zone with Forest scope (AC1)
//   - User rejects legacy scope (AC2)
func TestZoneCreate(t *testing.T) {
  cases := []struct {
    name string
    scope string
    expectErr string
  }{
    {
      name: "Scenario: Domain scope accepted",  // AC1
      scope: "domain",
      expectErr: "",
    },
    {
      name: "Scenario: Legacy scope rejected",  // AC2
      scope: "legacy",
      expectErr: "ZONE-005",
    },
  }
  // ... table execution
}
```

**C# (xUnit):**
```csharp
// Implements scenario (DDIDNS-10521 AC1): 
// "Agent validates replication scope before PowerShell"
[Fact]
public void ValidateReplicationScope_RejectLegacy_Test()
{
    // Arrange, Act, Assert
    var result = _controller.ValidateReplicationScope("legacy");
    Assert.False(result.IsValid);  // AC1: legacy rejected
}
```

### 2. Scenario → Test Mapping Table in the Plan

The dev plan's per-package template includes an explicit table mapping scenarios to test cases. Added as part of Step 7 (Write Plan):

```markdown
## Acceptance Criteria / Scenario Traceability

| Scenario / AC | Repository | Test File | Test Function |
|---|---|---|---|
| AC1: User creates zone with Domain scope | ddi.dns.config | pkg/service/application/stub_zone_test.go | TestZoneCreate_DomainScope |
| AC1: User creates zone with Forest scope | ddi.cloud.proxy.middleware | pkg/msad_zone_helper_test.go | TestZoneCreate_ForestScope |
| AC2: User rejects legacy scope | ddi.dns.config | pkg/service/application/stub_zone_test.go | TestReject_LegacyScope |
```

This table is generated at plan-write time (Step 7) by matching test-name comments in the code to scenarios in the Gherkin block.

### 3. Code-Review Checklist Item

`msad-code-review` agent receives the plan file (which contains the Gherkin block and traceability table) and runs this MUST checklist:

**MUST:** Every Gherkin scenario in the linked story's acceptance criteria is traceable to at least one test case in the code diff (name/comment match + traceability table entry), OR is explicitly deferred with a linked follow-up ticket (e.g., "DDIDNS-10565 to add integration test for error-code handling").

This closes the loop: code-review verifies AC coverage using the plan file (which already contains both Gherkin text and mapping), without needing direct Jira/Atlassian MCP access.

## Enforcement Points

### At Plan Write Time (msad-dev-planning Step 7)
- Gherkin scenarios are imported from Jira story (or drafted if missing).
- Traceability table is generated / scaffolded for the user to fill in.
- Plan cannot be marked `status: approved` if traceability table has gaps (checked by the bounded-review-loop plan reviewer).

### At Implementation Time (msad-backend-dev)
- TDD hard gate: "write failing test first" (existing requirement, now linked to the scenario-being-tested).
- Test-name convention: comment each test with `// Scenario: "<name>" (Jira AC#)`.

### At Code-Review Time (msad-code-review)
- Checklist item: verify every scenario maps to a test in the diff.
- Plan file is passed as context so the reviewer can see the full mapping.

## Native Test Patterns (No Gherkin Runner)

### Go: Table-Driven Tests

```go
func TestZoneCreate(t *testing.T) {
  cases := []struct {
    name         string
    scope        string
    expectErr    string
  }{
    // Scenario: Domain scope accepted (DDIDNS-10562 AC1)
    {"domain_scope", "domain", ""},
    // Scenario: Legacy scope rejected (DDIDNS-10562 AC2)
    {"legacy_scope", "legacy", "ZONE-005"},
  }
  for _, tc := range cases {
    t.Run(tc.name, func(t *testing.T) {
      result := ValidateScope(tc.scope)
      if tc.expectErr != "" {
        assert.Error(t, result)
      } else {
        assert.NoError(t, result)
      }
    })
  }
}
```

### C# / xUnit

```csharp
public class DnsPrimaryZoneControllerTests
{
  // Scenario: Agent validates scope before PowerShell (DDIDNS-10521 AC1)
  [Theory]
  [InlineData("local", true)]
  [InlineData("domain", true)]
  [InlineData("forest", true)]
  [InlineData("legacy", false)]
  public void ValidateReplicationScope_Returns(string scope, bool expected)
  {
    var result = _controller.ValidateReplicationScope(scope);
    Assert.Equal(expected, result.IsValid);
  }
}
```

Both patterns are **native to their stacks, already in use in the MSAD repos**, and can be annotated with scenario names / AC references via comments.

## When to Defer a Scenario

If a scenario cannot be tested in the current PR (e.g., Windows-only agent testing, or a follow-up story), mark it explicitly in the traceability table and file a follow-up ticket:

| Scenario | Test | Status |
|---|---|---|
| AC1: Domain scope | pkg/msad_zone_helper_test.go:TestDomainScope | ✅ Implemented |
| AC3: Stage testing with real MSAD | (DDIDNS-10565) | 🔄 Deferred to Phase 2 |

The code-review checklist allows deferral *only* if a linked ticket exists.

## Summary

- **Gherkin scenarios:** Authored once in the Jira story description; imported/traced (not re-executed) downstream.
- **TDD tests:** Native, table-driven / xUnit; annotated with scenario names / AC references.
- **Traceability table:** Plan file documents the Scenario→Test mapping; code-review verifies it.
- **No new tooling:** cucumber / godog / SpecFlow not introduced.
- **Auditable:** Plan file + traceability table + code-review ledger form a complete audit trail of which AC is tested by which test.
