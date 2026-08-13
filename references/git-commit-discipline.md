# Git Commit Discipline

Guidelines for clean, reviewable, bisectable commits in the MSAD ecosystem.

## Core Principle: Separate Concerns

Every commit should have a single, clear purpose. **Do not mix additions, modifications, and deletions in a single commit.**

### Commit Types

#### 1. Additions Only

**Scope:** New files, new functions, new tests. **No changes to existing code.**

```bash
git add <new files>
git commit -m "Add <what>.

New files: [list].
Purpose: [AC number and description].
"
```

**Example:**
```bash
git commit -m "Add replication-scope validator tests.

New file: pkg/service/application/stub_zone_test.go.
Tests cover local, domain, forest scopes per DDIDNS-10519 AC1.
"
```

**Review checklist:**
- [ ] New code follows repo conventions (from CLAUDE.md)
- [ ] Tests pass (coverage ≥ threshold)
- [ ] No changes to existing code in the diff
- [ ] New files are in the right location

#### 2. Modifications Only

**Scope:** Changes to existing files (logic updates, bug fixes, refactoring). **No new files, no deletions.**

```bash
git add <changed files>
git commit -m "Update/Fix <what>.

Changed: [list of files].
Reason: [AC number, bug description, refactor motivation].

Before: [old behavior].
After: [new behavior].
"
```

**Example:**
```bash
git commit -m "Update zone validator to accept domain/forest scopes.

Changed: pkg/service/application/stub_zone.go.
Satisfies: DDIDNS-10519 AC1-2.

Before: validateStubZoneReplicationScopeNotLegacy() allowed only 'local'.
After: Now allows 'local', 'domain', 'forest'; rejects 'legacy' at creation.
"
```

**Review checklist:**
- [ ] Diff is focused (no unrelated changes)
- [ ] Tests still pass (including regression tests)
- [ ] Coverage maintained or improved
- [ ] All review findings addressed

#### 3. Deletions Only

**Scope:** Remove dead code, unused imports, deprecated functions. **No modifications to remaining code, no additions.**

```bash
git add -u <deleted files>
git commit -m "Remove <what>.

Deleted: [list of files/symbols].
Reason: [why safe to remove; e.g., 'No longer used after DDIDNS-10562 refactor'].
Verified: [grep results showing no references].
"
```

**Example:**
```bash
git commit -m "Remove legacy replication-scope validator.

Deleted: pkg/legacy_scope.go (165 lines).
Reason: Replaced by new allow-list in DDIDNS-10562; no references remain.
Verified: grep -r 'legacy_scope' found no uses.
"
```

**Review checklist:**
- [ ] Deletion is safe (search confirms no references)
- [ ] Tests pass (deletion doesn't break anything)
- [ ] No accidental modifications in the delete commit
- [ ] Commit message explains why it was safe to remove

---

## Commit Message Format

```
<Subject line (imperative, ≤70 chars)>

<Body (wrap at 72 chars)>
- <Detail 1: what changed, file list, or commit type>
- <Detail 2: why (AC number, bug, refactor goal)>
- <Detail 3: any caveats, deferred work, or cross-repo notes>

Jira: DDIDNS-XXXXX
[Optional: Closes, Relates-To, Depends-On]
```

### Subject Line Rules

- **Imperative mood:** "Add", "Update", "Fix", "Remove" (not "Added", "Updates", "Fixed")
- **≤70 characters** (git log --oneline fits in 80)
- **No period at end**
- **Capitalize first letter**

### Body Rules

- **Wrap at 72 characters** (readable in all terminals)
- **Explain WHY, not WHAT** (the code shows what; commit explains why)
- **Reference Jira** (e.g., "DDIDNS-10519 AC1")
- **Note cross-repo impacts** (e.g., "Middleware must regenerate pkg/pb/ after this")
- **Deferred work:** flag follow-ups (e.g., "DDIDNS-10541 handles error-code mapping separately")

### Jira Line

**Always include:** `Jira: DDIDNS-XXXXX`

**Optional:**
- `Closes: DDIDNS-XXXXX` (closes the ticket when merged)
- `Relates-To: DDIDNS-YYYYY` (related ticket, not closed by this)
- `Depends-On: DDIDNS-ZZZZZ` (this commit depends on another ticket being done first)

---

## Workflow: Adding, Modifying, Deleting a Feature

**Example:** Add replication-scope support (add validator, update handler, remove old code).

### Step 1: Plan (per plan file)

```
## Changes (by type)

**Additions:**
- New file: test cases for validator (table-driven, all scopes)

**Modifications:**
- Update validator function to accept domain/forest
- Update middleware interceptor to call updated validator
- Update error handling (new error codes)

**Deletions:**
- Remove old legacy-scope-only code (no longer used)
```

### Step 2: Implement in Order

```bash
# 1. Write tests first (but don't modify existing code yet)
# Add new test file: zones_test.go (new lines only)
git add zones_test.go
git commit -m "Add replication-scope validator tests. [...]"

# 2. Implement the changes
# Modify: stub_zone.go, interceptor_handlers.go, error_handling.go
git add stub_zone.go interceptor_handlers.go error_handling.go
git commit -m "Update zone validator and middleware to support domain/forest scopes. [...]"

# 3. Clean up (delete old code)
# Remove: legacy_scope.go
git rm legacy_scope.go
git commit -m "Remove legacy-scope validator (replaced in step 2). [...]"

# 4. Final checks
make fmt && make lint && make test
# All clean? Push.
```

### Step 3: Push (No Force)

```bash
git push origin <branch-name>
# Opens PR (manually via gh pr create or via CI)
```

**If push fails:**
- **Pre-commit hook error?** Fix the issue, `git add -A`, `git commit --amend` (wait, no!). Instead: fix locally, `git commit` (new commit, don't amend), then push.
- **Branch behind origin?** `git pull --rebase` (rebase is safer than merge for local changes), then push.
- **Need to undo a pushed commit?** `git revert <hash>`, then push the revert commit. Do NOT force-push.

---

## Red Flags

🚩 **Force-push** (`git push --force`, `git push -f`)
- **Never do this.** If you pushed something bad, use `git revert`.

🚩 **Amending after push**
- **Avoid.** Creates confusion. Use `git revert` or create a new fixup commit instead.

🚩 **Mixing additions, modifications, deletions in one commit**
- **Don't do this.** Review is harder, bisect is slower, blame history is muddled.

🚩 **Generic commit messages** ("fix", "update", "work in progress")
- **Avoid.** Always reference the Jira ticket and explain why.

🚩 **Committing without tests passing**
- **Don't do this.** `make test` + `make lint` must pass before git commit.

🚩 **Committing code with coverage below threshold**
- **Don't do this.** Add tests until ≥75% (Go) or ≥70% (C#).

---

## Examples

### Good: Additions Only

```
Add table-driven tests for zone validator.

New file: pkg/service/application/zones_test.go.
Tests cover:
- Local scope (existing)
- Domain scope (new, DDIDNS-10519 AC1)
- Forest scope (new, DDIDNS-10519 AC2)
- Legacy scope (properly rejected at creation)

Tests use sqlmock for DB context; all pass.
Coverage of validateStubZoneReplicationScopeNotLegacy(): 100%.

Jira: DDIDNS-10519
```

### Good: Modifications Only

```
Update zone validator to accept domain/forest scopes.

Changed: pkg/service/application/stub_zone.go.
- validateStubZoneReplicationScopeNotLegacy(): expanded allow-list from {local} to {local, domain, forest}
- isADRestrictedScope(): no change (still rejects local for AD zones)

Satisfies DDIDNS-10519 AC1-2.
Tests pass. Coverage: 100%.

Note: Middleware must mirror this change (DDIDNS-10562 dependency).

Jira: DDIDNS-10519
```

### Good: Deletions Only

```
Remove legacy-only zone validator.

Deleted: pkg/legacy/legacy_zone_validator.go (245 lines).
Reason: Replaced by modern validator in DDIDNS-10562. No references remain.

Verified:
- grep -r "legacy_zone_validator" found 0 uses
- Removal does not break any tests

Jira: DDIDNS-10562
```

### Bad: Mixed Commit ❌

```
Update zone validator + add tests + remove legacy.

Changed: stub_zone.go
Added: zones_test.go
Removed: legacy_zone_validator.go

[Large diff mixing three concerns; hard to review, bisect, understand]
```

---

## References

- **Git docs:** https://git-scm.com/book/en/v2/Git-Basics-Viewing-the-Commit-History
- **Conventional Commits:** https://www.conventionalcommits.org/ (informational; this guide is normative)
- **Atomic commits:** https://en.wikipedia.org/wiki/Atomic_commit (background reading)
