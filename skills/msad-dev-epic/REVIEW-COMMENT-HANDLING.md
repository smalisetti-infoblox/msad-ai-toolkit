# PR Review Comment Handling

**Enhancement:** Toolkit should discover and address existing review comments on draft PRs, not just identified gaps.

---

## Overview

When discovering existing PRs, toolkit should also:
1. Fetch existing review comments (via `gh pr view --comments`)
2. Analyze comments for actionable feedback (requests to change, suggestions, questions)
3. Classify comments by severity (blocking, non-blocking, informational)
4. Prioritize gaps to address based on reviewer feedback
5. Report back on addressed vs. deferred comments

---

## Discovery Phase: Enhanced PR Analysis

### Current (Gap-Only)
```
PR 507: DRAFT, 85% complete
Gap: "Conditional Forwarder handler tests missing"
Action: Add handler tests
```

### Enhanced (Gap + Comments)
```
PR 507: DRAFT, 85% complete
Gap: "Conditional Forwarder handler tests missing"

Review Comments:
  ├─ BLOCKING (must address):
  │  ├─ "Coverage is 87%, need ≥92% for interceptor code" (reviewer: alice)
  │  └─ "Missing test for scope validation edge case: empty string" (reviewer: bob)
  │
  ├─ NON-BLOCKING (should address):
  │  ├─ "Consider refactoring duplicate validation logic in toMSADCreateAuthZoneRequest" (reviewer: alice)
  │  └─ "Add comment explaining replication-scope allow-list rationale" (reviewer: bob)
  │
  └─ INFORMATIONAL (nice-to-have):
     └─ "Great work on error handling!" (reviewer: charlie)

Action: 
  1. Add handler tests (closes gap)
  2. Verify coverage ≥92% (addresses blocking comment)
  3. Add edge case test: empty string scope (addresses blocking comment)
  4. Refactor duplicate validation logic (addresses non-blocking)
  5. Add explanatory comment (addresses non-blocking)
```

---

## Review Comment Classification

### Blocking Comments
- **Pattern:** "must", "need to", "required", "before merge"
- **Action:** Toolkit must address before PR is ready
- **Example:** "Coverage must be ≥92%"

### Non-Blocking Comments
- **Pattern:** "consider", "might", "could", "nice to have", "suggestion"
- **Action:** Toolkit should address, but can defer if time-constrained
- **Example:** "Consider refactoring duplicate logic"

### Informational Comments
- **Pattern:** "good job", "looks great", "fyi", "note that"
- **Action:** No action needed, document in PR body
- **Example:** "Great test coverage!"

### Questions
- **Pattern:** "why did you", "have you considered", "what about"
- **Action:** Address with code or explanation comment
- **Example:** "Why not use the existing validator function?"

---

## Implementation: Enhanced Discovery

### Step 1: Fetch PR Comments

```bash
gh pr view 507 --json comments,reviews --jq '.comments, .reviews'
```

**Output:**
```json
[
  {
    "author": "alice",
    "body": "Coverage is 87%, need ≥92% for interceptor code",
    "createdAt": "2026-08-12T06:22:44Z",
    "isMinimized": false
  },
  {
    "author": "bob", 
    "body": "Missing test for scope validation edge case: empty string",
    "createdAt": "2026-08-12T15:22:09Z",
    "isMinimized": false
  }
]
```

### Step 2: Analyze Comments

```python
def classify_review_comments(comments):
    blocking = []
    non_blocking = []
    informational = []
    
    for comment in comments:
        text = comment['body'].lower()
        
        # Blocking keywords
        if any(kw in text for kw in ['must', 'need to', 'required', 'before merge', 'fix']):
            blocking.append(comment)
        # Non-blocking keywords
        elif any(kw in text for kw in ['consider', 'might', 'could', 'suggestion', 'refactor']):
            non_blocking.append(comment)
        # Questions
        elif any(kw in text for kw in ['why', 'have you', 'what about', '?']):
            blocking.append(comment)  # Treat questions as blocking
        # Informational
        else:
            informational.append(comment)
    
    return blocking, non_blocking, informational
```

### Step 3: Link Comments to Gaps

```python
def match_comments_to_gaps(comments, identified_gaps):
    """
    Link review comments to identified gaps for prioritization
    """
    
    # Comment: "Coverage is 87%, need ≥92%"
    # Gap: "Coverage gap (87% → 92.3%)"
    # Match: YES - both address coverage
    
    # Comment: "Missing test for empty string scope"
    # Gap: "Handler tests missing"
    # Match: YES - both address tests
    
    # Comment: "Refactor duplicate validation logic"
    # Gap: (no corresponding gap identified)
    # Match: PARTIAL - suggests additional work
    
    return matched_gaps, additional_work_from_comments
```

---

## Execution: Address Comments

### Dispatch Agents with Comment Context

**Old prompt:**
```
PR 507: Add Conditional Forwarder handler tests
Gap: Missing tests
```

**Enhanced prompt:**
```
PR 507: Add Conditional Forwarder handler tests

Gap: Missing handler tests for Conditional Forwarder

Review Comments (blocking):
  ✓ "Coverage is 87%, need ≥92%" 
    → Action: Ensure new tests improve coverage to ≥92%
  
  ✓ "Missing test for scope validation edge case: empty string"
    → Action: Add test case for empty string scope value

Review Comments (non-blocking):
  ○ "Consider refactoring duplicate validation logic"
    → Action: Refactor if time permits (note in PR body if deferred)
  
  ○ "Add comment explaining replication-scope allow-list"
    → Action: Add inline comment explaining why [local, domain, forest] are allowed

Execution order:
  1. Add handler tests (closes gap)
  2. Add edge case test for empty string (closes blocking comment)
  3. Verify coverage ≥92% (closes blocking comment)
  4. Refactor duplicate logic if time permits (non-blocking)
  5. Add explanatory comment (non-blocking)
```

### Agent Handles Comments

Agent workflow:
```
1. Checkout PR branch
2. Read existing review comments (github API / gh pr view)
3. Identify what needs to be addressed:
   - Blocking: MUST fix
   - Non-blocking: SHOULD fix (time permitting)
4. Generate code addressing each blocking comment
5. Run tests, verify coverage
6. Make commits addressing each comment type
7. Push to PR branch
8. Report: "Addressed 3 blocking comments, deferred 2 non-blocking"
```

---

## Reporting: Comments Addressed

### Final PR Status Report

**Before (Gap-Only):**
```
PR 507 Status:
  - Gap: Conditional Forwarder handler tests missing
  - Action: COMPLETED (tests added, coverage 87% → 92.3%)
  - Status: Ready for review
```

**After (Gap + Comments):**
```
PR 507 Status:
  - Gap: Conditional Forwarder handler tests missing
  - Action: COMPLETED (tests added, coverage 87% → 92.3%)
  
  Review Comments Addressed:
  ✅ BLOCKING (3/3 addressed):
     ✓ "Coverage ≥92%" → Coverage now 92.3%
     ✓ "Test empty string edge case" → Added test case
     ✓ "Explain replication-scope allow-list" → Added inline comment
  
  ○ NON-BLOCKING (1/2 deferred, 1/2 addressed):
     ✓ "Add explanatory comment" → ADDRESSED
     ○ "Refactor duplicate validation logic" → DEFERRED (non-critical, PR scope)
  
  ℹ️  INFORMATIONAL:
     "Great test coverage!" → Acknowledged
  
  - Status: Ready for review (all blocking comments addressed)
```

---

## Integration Points

### 1. Discovery Phase

```python
# msad-dev-epic: Step 2 (Discovery)

def discover_pr_with_comments(pr_number, repo):
    """
    Discover PR and its review comments
    """
    
    # Fetch PR metadata
    pr = gh.pr_view(pr_number, repo)
    
    # Fetch review comments
    comments = gh.pr_view_comments(pr_number, repo)
    
    # Classify comments
    blocking, non_blocking, info = classify_review_comments(comments)
    
    # Link to gaps
    pr_gaps = identify_pr_gaps(pr)
    matched, additional = match_comments_to_gaps(comments, pr_gaps)
    
    return {
        "pr_number": pr_number,
        "status": pr.status,
        "gaps": pr_gaps,
        "blocking_comments": blocking,
        "non_blocking_comments": non_blocking,
        "additional_work": additional,  # Work suggested by comments but not identified as gap
    }
```

### 2. Classification Phase

```python
def classify_pr_status_with_comments(prs):
    """
    Classify PR status including review comments
    """
    
    for pr in prs:
        if pr.status == "DRAFT":
            # Has gaps?
            if pr.gaps:
                # Has blocking comments?
                if pr.blocking_comments:
                    pr.classification = "PARTIAL_WITH_BLOCKING_FEEDBACK"
                    pr.priority = "HIGH"  # Address blocking first
                else:
                    pr.classification = "PARTIAL"
                    pr.priority = "NORMAL"
            else:
                # No gaps, but has review comments?
                if pr.blocking_comments:
                    pr.classification = "COMPLETE_WITH_BLOCKING_FEEDBACK"
                    pr.priority = "HIGH"
                elif pr.non_blocking_comments:
                    pr.classification = "COMPLETE_WITH_SUGGESTIONS"
                    pr.priority = "LOW"
                else:
                    pr.classification = "COMPLETE"
                    pr.priority = "NORMAL"
```

### 3. Dispatch Phase

```python
# msad-dev-epic: Step 3 (Dispatch)

def create_agent_prompt_with_comments(pr):
    """
    Create enhanced agent prompt including review comments
    """
    
    prompt = f"""
    Task: Complete PR {pr.number} ({pr.task})
    
    Current Status: {pr.status}% complete
    
    Identified Gaps:
    {format_gaps(pr.gaps)}
    
    Review Comments (Blocking - MUST address):
    {format_blocking_comments(pr.blocking_comments)}
    
    Review Comments (Non-Blocking - SHOULD address):
    {format_non_blocking_comments(pr.non_blocking_comments)}
    
    Priority Order:
    1. Address all identified gaps
    2. Close all blocking review comments
    3. Address non-blocking comments if time permits
    4. Add explanatory comments where suggested
    
    Report back:
    - Gaps closed (what + why)
    - Blocking comments addressed (which + how)
    - Non-blocking comments: addressed or deferred (and why if deferred)
    - Final coverage % and test results
    """
    
    return prompt
```

### 4. Collection Phase

```python
def collect_pr_results_with_comments(agent_result, original_pr):
    """
    Collect results including comment resolution
    """
    
    result = {
        "pr_number": agent_result.pr_number,
        "gaps_addressed": agent_result.gaps_closed,
        "blocking_comments_addressed": agent_result.blocking_resolved,
        "non_blocking_comments_addressed": agent_result.non_blocking_resolved,
        "deferred_work": agent_result.deferred_comments,
        "deferred_reason": agent_result.defer_reason,
        "test_results": agent_result.tests,
        "coverage": agent_result.coverage,
        "ready_for_review": all_blocking_addressed(agent_result),
    }
    
    return result
```

---

## PR Body Enhancement

When agent opens/updates PR, include comment resolution:

```markdown
## Changes

### Gaps Addressed
- [x] Added Conditional Forwarder handler tests
- [x] Improved coverage: 87% → 92.3%

### Review Comments Addressed

**Blocking Comments (All Addressed ✓):**
- [x] "Coverage ≥92%" — Coverage now 92.3% (added 15 test cases)
- [x] "Test empty string edge case" — Added test case for scope="", expects InvalidArgument
- [x] "Explain replication-scope rationale" — Added inline comment explaining allow-list

**Non-Blocking Comments:**
- [x] "Add explanatory comment" — Added (line 42-45)
- [x] "Refactor duplicate validation logic" — Implemented (consolidates 3 validators into 1)

### Deferred
- (None - all feedback addressed)

---

## Test Results
- Unit: PASS (all 12 handler tests)
- Coverage: 92.3% (was 87%)
- Lint: PASS (gofmt, golangci-lint)
- CI: PASS (GitHub checks)
```

---

## Benefits

1. **Discovers existing feedback** — Don't duplicate work, address what reviewers asked for
2. **Prioritizes blocking issues** — Handles must-address comments first
3. **Acknowledges suggestions** — Shows non-blocking comments are considered
4. **Closer to ready** — Addresses not just gaps but also reviewer concerns
5. **Fewer re-review cycles** — Blocking comments closed upfront
6. **Better PR body** — Documents what feedback was addressed

---

## Implementation Checklist

- [ ] Discovery: Fetch PR review comments via `gh pr view --comments`
- [ ] Classification: Categorize comments (blocking, non-blocking, info)
- [ ] Linking: Match comments to identified gaps for prioritization
- [ ] Prompt generation: Enhanced agent prompts with comment context
- [ ] Agent execution: Address comments in priority order
- [ ] Result collection: Report on comment resolution
- [ ] PR body: Document addressed vs. deferred comments
- [ ] Reporting: Final status includes "all blocking comments addressed?"

---

## Example: PR 507 with Comments

**Discovery:**
```
PR 507: DRAFT, 85% complete
Gap: Handler tests missing

Review Comments:
  BLOCKING:
    - alice: "Coverage ≥92%" (blocking)
    - bob: "Test empty string scope" (blocking)
  NON-BLOCKING:
    - alice: "Add comment explaining allow-list"
```

**Execution:**
```
Agent:
  1. Add Conditional Forwarder handler tests
  2. Add test case for scope="" edge case (closes bob's comment)
  3. Verify coverage: 92.3% (closes alice's comment)
  4. Add inline comment explaining scope logic (closes alice's non-blocking)
  5. Commit & push

Result:
  - Gaps: 1/1 closed
  - Blocking comments: 2/2 addressed
  - Non-blocking comments: 1/1 addressed
  - Coverage: 92.3%
  - Status: Ready for review (all blocking feedback resolved)
```

---

**Status:** This enhancement makes the toolkit more intelligent about completing PRs with existing reviewer feedback.
