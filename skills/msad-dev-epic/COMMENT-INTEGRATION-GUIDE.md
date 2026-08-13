# Integration Guide: Review Comments into Epic Execution

**Status:** Detailed guide for integrating PR review comment analysis into `/msad-dev-epic`

---

## Overview

Integrate review comment discovery and analysis into the existing epic execution workflow:

```
Step 1: Discovery (Jira + GitHub)
  ├─ Fetch epic + tasks
  ├─ Discover existing PRs
  └─ NEW: Fetch PR review comments & analyze
  
Step 2: Classification
  ├─ Classify PRs: partial/complete/not-started
  └─ NEW: Classify by review feedback: blocking/non-blocking
  
Step 3: Agent Dispatch
  └─ NEW: Pass comment context to agents
  
Step 4: Execution
  └─ Agents address gaps + comments in priority order
  
Step 5: Result Collection
  └─ NEW: Report on comment resolution
  
Step 6: Reporting
  └─ NEW: PR body documents addressed comments
```

---

## Phase 1: Enhanced Discovery

### Current Discovery Flow

```bash
# Discover PR 507
gh pr view 507 --repo Infoblox-CTO/ddi.cloud.proxy.middleware \
  --json number,title,state,body,author,createdAt,updatedAt
```

### Enhanced Discovery Flow

Add review comment fetching:

```bash
# Fetch PR with comments
gh pr view 507 --repo Infoblox-CTO/ddi.cloud.proxy.middleware \
  --json number,title,state,body,author,createdAt,reviews,comments

# Sample output includes:
# {
#   "reviews": [
#     {
#       "author": {"login": "alice"},
#       "state": "COMMENTED",
#       "body": "Coverage is 87%, need ≥92% for interceptor code",
#       "createdAt": "2026-08-12T06:22:44Z"
#     },
#     {
#       "author": {"login": "bob"},
#       "state": "REQUESTED_CHANGES",
#       "body": "Missing test for scope validation edge case: empty string",
#       "createdAt": "2026-08-12T15:22:09Z"
#     }
#   ]
# }
```

### Implementation: Enhanced PR Discovery Function

```python
def discover_pr_with_full_context(pr_number, repo):
    """
    Discover PR metadata, gaps, and review comments
    """
    
    # 1. Fetch PR metadata
    pr_json = subprocess.run(
        ["gh", "pr", "view", str(pr_number), 
         "--repo", f"Infoblox-CTO/{repo}",
         "--json", "number,title,state,body,author,createdAt,updatedAt,reviews,comments"],
        capture_output=True, text=True
    )
    
    pr_data = json.loads(pr_json.stdout)
    
    # 2. Identify gaps from PR description
    gaps = extract_gaps_from_body(pr_data['body'])
    
    # 3. Analyze review comments
    blocking_comments = []
    non_blocking_comments = []
    informational_comments = []
    
    for review in pr_data.get('reviews', []):
        comment_obj = {
            'author': review['author']['login'],
            'state': review['state'],  # COMMENTED, APPROVED, REQUESTED_CHANGES
            'body': review['body'],
            'created': review['createdAt'],
        }
        
        # Classify by review state and keywords
        if review['state'] == 'REQUESTED_CHANGES':
            blocking_comments.append(comment_obj)
        elif 'must' in review['body'].lower() or 'need' in review['body'].lower():
            blocking_comments.append(comment_obj)
        elif any(kw in review['body'].lower() for kw in ['consider', 'might', 'suggest']):
            non_blocking_comments.append(comment_obj)
        else:
            informational_comments.append(comment_obj)
    
    # 4. Return comprehensive PR context
    return {
        'pr_number': pr_data['number'],
        'title': pr_data['title'],
        'state': pr_data['state'],
        'author': pr_data['author']['login'],
        'created': pr_data['createdAt'],
        'updated': pr_data['updatedAt'],
        'gaps': gaps,
        'blocking_comments': blocking_comments,
        'non_blocking_comments': non_blocking_comments,
        'informational_comments': informational_comments,
        'total_feedback_items': len(blocking_comments) + len(non_blocking_comments),
    }
```

---

## Phase 2: Enhanced Classification

### Current Classification

```python
def classify_pr(pr_data):
    if pr_data.state == 'DRAFT' and pr_data.gaps:
        return 'PARTIAL'
    elif pr_data.state == 'DRAFT':
        return 'COMPLETE'
    else:
        return 'MERGED'
```

### Enhanced Classification

```python
def classify_pr_with_feedback(pr_data):
    """
    Classify PR considering gaps AND review comments
    """
    
    base_status = 'PARTIAL' if pr_data['gaps'] else 'COMPLETE'
    
    # Priority based on blocking comments
    if pr_data['blocking_comments']:
        priority = 'HIGH'  # Must address blocking feedback
        feedback_status = 'WITH_BLOCKING_FEEDBACK'
    elif pr_data['non_blocking_comments']:
        priority = 'MEDIUM'  # Should address suggestions
        feedback_status = 'WITH_SUGGESTIONS'
    else:
        priority = 'NORMAL'
        feedback_status = 'NO_FEEDBACK'
    
    return {
        'status': base_status,
        'feedback_status': feedback_status,
        'priority': priority,
        'blocking_count': len(pr_data['blocking_comments']),
        'non_blocking_count': len(pr_data['non_blocking_comments']),
    }
```

### Ordering Agents by Priority

```python
def order_work_items_by_priority(prs):
    """
    Prioritize PRs/tasks by blocking feedback
    
    Execution order:
    1. HIGH priority (blocking comments)
    2. MEDIUM priority (suggestions)
    3. NORMAL priority (no feedback)
    """
    
    high_priority = [p for p in prs if p['priority'] == 'HIGH']
    medium_priority = [p for p in prs if p['priority'] == 'MEDIUM']
    normal_priority = [p for p in prs if p['priority'] == 'NORMAL']
    
    # Within each priority, sort by number of blocking items
    high_priority.sort(key=lambda p: -p['blocking_count'])
    
    return high_priority + medium_priority + normal_priority
```

---

## Phase 3: Enhanced Agent Dispatch

### Current Agent Prompt

```markdown
## Task: Complete PR 507 Gap

Gap: Conditional Forwarder handler tests missing

Workflow:
1. Checkout branch
2. Analyze test patterns
3. Generate tests
4. Verify coverage ≥92%
5. Commit & push
```

### Enhanced Agent Prompt

```markdown
## Task: Complete PR 507 Gap

Current Status: 85% complete
Gap: Conditional Forwarder handler tests missing

## Reviewer Feedback (3 items)

**BLOCKING (Must Address):**
1. **alice:** "Coverage is 87%, need ≥92% for interceptor code"
   - Severity: HIGH (coverage threshold blocking merge)
   - Action: Ensure new tests push coverage to ≥92%
   
2. **bob:** "Missing test for scope validation edge case: empty string"
   - Severity: HIGH (missing test case)
   - Action: Add test case for scope="" and verify it rejects with InvalidArgument

**NON-BLOCKING (Should Address if Time Permits):**
3. **alice:** "Consider adding comment explaining replication-scope allow-list"
   - Severity: MEDIUM (documentation)
   - Action: Add inline comment explaining why [local, domain, forest] are allowed

## Execution Priority

**MUST (in order):**
1. Add Conditional Forwarder handler tests
2. Add test case for scope="" edge case
3. Verify final coverage ≥92%

**SHOULD:**
4. Add explanatory comment about scope allow-list

## Workflow
1. Checkout PR 507 branch
2. Analyze existing handler test patterns (Auth Zone, Reverse Auth)
3. Generate Conditional Forwarder tests mirroring the pattern
4. ADD TEST CASE: scope="" should reject with InvalidArgument error
5. Run: make test (with docker-compose)
6. Verify: go tool cover -func=coverage.out shows ≥92% coverage
7. ADD COMMENT: Explain the allow-list (line X)
8. Commit in order:
   - "Add Conditional Forwarder handler tests"
   - "Add scope validation comment"
9. Push to PR branch

## Report Back
- What tests you added (count, pattern followed)
- Test results (pass/fail count)
- Coverage % (before/after)
- Which blocking comments you addressed
- Which non-blocking comments you addressed or deferred (and why)
- Final status: Ready for review?

## Success Criteria
- ✓ Coverage ≥92%
- ✓ All handler test methods passing
- ✓ Empty string scope test present and passing
- ✓ Coverage comment added
- ✓ All blocking feedback addressed
```

---

## Phase 4: Enhanced Execution

### Agent Implementation Changes

```python
def execute_pr_with_comment_awareness(pr_context):
    """
    Agent aware of review comments, addresses them systematically
    """
    
    # 1. Checkout and analyze
    checkout_pr_branch(pr_context['pr_number'])
    
    # 2. Identify work items from gaps and comments
    work_items = []
    
    # Add gap-related work
    for gap in pr_context['gaps']:
        work_items.append({
            'type': 'gap',
            'description': gap,
            'priority': 'MUST',
        })
    
    # Add blocking comment work
    for comment in pr_context['blocking_comments']:
        work_items.append({
            'type': 'blocking_comment',
            'description': comment['body'],
            'author': comment['author'],
            'priority': 'MUST',
        })
    
    # Add non-blocking comment work
    for comment in pr_context['non_blocking_comments']:
        work_items.append({
            'type': 'non_blocking_comment',
            'description': comment['body'],
            'author': comment['author'],
            'priority': 'SHOULD',
        })
    
    # 3. Execute in priority order
    executed = []
    skipped = []
    
    for item in work_items:
        if item['priority'] == 'MUST':
            # Must address
            result = execute_work_item(item)
            executed.append((item, result))
        elif item['priority'] == 'SHOULD':
            # Should address if time permits
            if time_remains():
                result = execute_work_item(item)
                executed.append((item, result))
            else:
                skipped.append(item)
    
    # 4. Run tests and verify
    test_results = run_tests()
    coverage = verify_coverage()
    
    # 5. Commit with clear messages linking to comments
    for item, result in executed:
        commit_message = f"PR {pr_context['pr_number']}: {item['description']}"
        if item['type'] == 'blocking_comment':
            commit_message += f"\n\nAddresses feedback from @{item['author']}"
        git_commit(commit_message)
    
    # 6. Push
    git_push()
    
    # 7. Report
    return {
        'pr_number': pr_context['pr_number'],
        'gaps_addressed': len([i for i, _ in executed if i['type'] == 'gap']),
        'blocking_comments_addressed': len([i for i, _ in executed if i['type'] == 'blocking_comment']),
        'non_blocking_comments_addressed': len([i for i, _ in executed if i['type'] == 'non_blocking_comment']),
        'work_deferred': len(skipped),
        'deferred_items': [i['description'] for i in skipped],
        'test_results': test_results,
        'coverage': coverage,
        'ready_for_review': coverage >= 80 and test_results['pass'],
    }
```

---

## Phase 5: Enhanced Result Collection

### Collect Detailed Feedback Resolution

```python
def collect_results_with_comment_resolution(agent_results, original_pr):
    """
    Aggregate results showing which comments were addressed
    """
    
    return {
        'pr_number': agent_results['pr_number'],
        'gaps_closed': agent_results['gaps_addressed'],
        'blocking_comments_resolved': {
            'addressed': agent_results['blocking_comments_addressed'],
            'deferred': 0,
            'total': len(original_pr['blocking_comments']),
        },
        'non_blocking_comments_resolved': {
            'addressed': agent_results['non_blocking_comments_addressed'],
            'deferred': agent_results['work_deferred'],
            'total': len(original_pr['non_blocking_comments']),
        },
        'all_blocking_addressed': (
            agent_results['blocking_comments_addressed'] == 
            len(original_pr['blocking_comments'])
        ),
        'test_results': agent_results['test_results'],
        'coverage': agent_results['coverage'],
        'ready_for_review': agent_results['ready_for_review'],
    }
```

---

## Phase 6: Enhanced Reporting

### PR Body with Comment Resolution

When updating PR, include comment resolution details:

```markdown
# PR 507: Support Domain/Forest Replication Scope for Auth Zone

## Summary
Added Conditional Forwarder handler tests to support Domain/Forest replication scope validation in zone creation requests.

## Changes
- Added `TestConditionalForwarderCreate` handler test (12 test cases)
- Added edge case test: scope="" rejects with InvalidArgument
- Added explanatory comment on scope allow-list

## Reviewer Feedback Resolution

### Blocking Comments (All Resolved ✓)
- [x] **alice:** "Coverage ≥92%" → **RESOLVED** Coverage improved from 87% → 92.3%
- [x] **bob:** "Test empty string scope" → **RESOLVED** Added test case verifying rejection

### Non-Blocking Suggestions (All Addressed ✓)
- [x] **alice:** "Add scope allow-list explanation" → **ADDRESSED** Added inline comment (line 42-45)

### Test Results
- ✅ All 12 handler tests PASSING
- ✅ Coverage: 92.3% (was 87%)
- ✅ Lint/fmt: PASS
- ✅ CI: All checks passing

### Readiness
- [x] All blocking feedback addressed
- [x] Coverage threshold met
- [x] Tests passing
- [x] Ready for human review & merge
```

### Final Report to User

```
PR 507 (DDIDNS-10519): Complete ✅

Status: All gaps closed + all blocking feedback addressed

Gaps Addressed: 1/1 ✅
  ✓ Conditional Forwarder handler tests added

Blocking Comments Addressed: 2/2 ✅
  ✓ Coverage improved (87% → 92.3%)
  ✓ Edge case test added (scope="")

Non-Blocking Suggestions Addressed: 1/1 ✅
  ✓ Explanatory comment added

Test Results: PASS ✅
Coverage: 92.3% ✅

Status: Ready for human review & merge
```

---

## Summary Checklist

- [ ] **Discovery:** Fetch PR review comments via `gh pr view --comments`
- [ ] **Classification:** Analyze comments for blocking vs. non-blocking
- [ ] **Prioritization:** Order PRs by blocking comment count (high priority first)
- [ ] **Prompt Enhancement:** Pass comment context and priority to agents
- [ ] **Execution:** Agents address gaps + blocking comments systematically
- [ ] **Tracking:** Track which comments are addressed vs. deferred
- [ ] **Reporting:** Document comment resolution in PR body
- [ ] **Final Status:** Report "All blocking comments addressed?" as merge readiness gate

---

**Status:** Implementation guide ready for toolkit integration
