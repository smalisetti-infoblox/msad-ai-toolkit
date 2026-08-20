# Deduplication Safeguards — Prevent Duplicate Stories & Plans

**Status:** IMPLEMENTED  
**Requirement:** Toolkit should not recreate duplicate stories/plans and should improve existing work.

---

## Overview

The MSAD AI Toolkit now has **explicit deduplication checks** at three critical points to prevent recreating duplicate stories, tasks, and plans. The strategy is:

1. **Detect existing work** early (Step 1 checks)
2. **Prefer improving existing** (default behavior)
3. **Refuse to create duplicates** (safeguards at write points)
4. **Guide users** with clear messaging on how to improve instead

---

## Three Deduplication Points

### 1️⃣ `/msad-plan-epic` — Story Deduplication (Step 1 Discovery)

**Location:** `skills/msad-plan-epic/SKILL.md` → Step 1: Fetch & Analyze Epic

**Check:** After fetching the epic, query Jira for existing stories:
```
Query: parent = epic_id
For each existing story: record ID, title, status, linked tasks
```

**Behavior:**
- If NO existing stories → proceed with analysis
- If existing stories found → ask user:
  ```
  "This epic already has N stories. Review existing structure? (Y/N)"
  ```
  - **Yes:** Show existing story hierarchy, ask which to improve or create new
  - **No:** Proceed with creating new structure (will be checked for duplicates at --create time)

**Safeguard:** Prevents redundant structure analysis when stories already exist.

---

### 2️⃣ `/msad-plan-epic --create` — Story Creation Deduplication (Step 9)

**Location:** `skills/msad-plan-epic/SKILL.md` → Step 9: Gated Creation Workflow

**Check:** Before creating stories in Jira:
```
For each story in approved plan:
  - Query Jira: "parent = epic_id AND title = story_title"
  - If found: note existing story ID
  - If NOT found: mark for creation
```

**Behavior:**
- **Duplicate story detected:** Refuse to create and show user:
  ```
  "Story '[name]' already exists as DDIDNS-10562.
   To improve it, use: /msad-dev-epic DDIDNS-10562
   To create a new story, rename it in the plan and re-run --create"
  ```
- **No duplicate:** Proceed with creation
- **Final report:** 
  - "Created 3 stories (5 tasks) in DDIDNS-7732"
  - OR "0 stories (already exist); improved [N] existing"

**Safeguard:** **CRITICAL** — Prevents Jira story duplication at creation time.

---

### 3️⃣ `/msad-dev-planning` — Dev Plan Deduplication (Step 1 Intake)

**Location:** `skills/msad-dev-planning/SKILL.md` → Step 1: Intake (Deduplication Check)

**Check:** After validating Jira ID, search for existing plan:
```
Search: specs/msad-dev-plans/*-<jira-id>-plan.md
If found: read plan frontmatter, check status field
```

**Behavior:**
- **Approved plan found:**
  ```
  "Plan already exists and is APPROVED.
   Use: /msad-dev-execution <path> to run it."
  ```
  → Don't create new plan; execute existing

- **Draft plan found:**
  ```
  "Plan already exists (draft, created YYYY-MM-DD).
   Review existing? Use /msad-dev-execution to run it, or create new? (yes/no/show-existing)"
  ```
  - **Yes (create new):** Generate new plan with timestamp suffix (e.g., `2026-08-20-1-DDIDNS-10519-plan.md`)
  - **No:** Reuse existing draft plan, offer to review/update

- **No plan found:** Proceed with analysis and creation

**Safeguard:** Prevents redundant planning when a plan already exists (especially approved ones).

---

## Existing PR Deduplication (Already Implemented)

### `/msad-dev-epic` — PR Discovery (Step 1.4)

**Location:** `skills/msad-dev-epic/SKILL.md` → Step 1: Discovery

**Check:** For each Backend task, query GitHub for related PRs:
```
For each task: gh pr list --search <task-id>
For each PR: fetch details, parse comments, identify state + blocking findings
```

**Behavior:**
- **DRAFT or OPEN PR found:** 
  - Prefer to **complete/improve** it (checkout branch, add missing work)
  - Document existing findings in plan's "Existing PRs + Review Context" section
- **Only create new PR** if no existing PR found for that task

**Safeguard:** Prevents PR duplication at execution time.

---

### `/msad-dev-execution` — PR Branch Dispatch (Step 2)

**Location:** `skills/msad-dev-execution/SKILL.md` → Step 2: Implementation

**Check:** Plan's "Existing PRs + Review Context" table contains:
- PR ID (if found)
- Current state (DRAFT/OPEN/MERGED)
- Existing findings + blocking issues
- Current test status / coverage

**Behavior:**
```
If existing PR exists (from plan's PR context):
  - Dispatch msad-backend-dev against PR's branch
  - Checkout PR, add missing work, push updates
If NO existing PR:
  - Agent creates new branch/PR
```

**Safeguard:** Respects in-progress work; avoids creating parallel PRs for the same task.

---

## User Guidance Messages

### When Deduplication Safeguard Prevents Creation:

**Story duplicate (--create fails):**
```
❌ ERROR: Story 'Backend — Support Domain/Forest Replication Scope' already exists as DDIDNS-10562

To improve the existing story:
  /msad-dev-epic DDIDNS-10562

To create a new story with a different name, edit the plan file and re-run:
  /msad-plan-epic DDIDNS-7732 --create
```

**Plan duplicate (planning detects existing approved):**
```
✓ Approved plan already exists: specs/msad-dev-plans/2026-08-15-DDIDNS-10519-plan.md

To execute this plan:
  /msad-dev-execution /path/to/plan.md
  
To create a new plan anyway:
  /msad-dev-planning DDIDNS-10519  (will create with new timestamp)
```

**PR duplicate (execution respects existing):**
```
✓ Existing PR found for DDIDNS-10519: #507 (DRAFT, blocking issues: coverage ≥92%)
  Checking out branch, will add missing work to existing PR
```

---

## Strategy: Prefer Existing Over New

| Situation | Action | Reason |
|-----------|--------|--------|
| Story exists for epic | Improve it (via `/msad-dev-epic`) | Avoids duplicate Jira issues |
| Dev plan exists (approved) | Execute it (via `/msad-dev-execution`) | Plan is frozen; no need to re-plan |
| Dev plan exists (draft) | Reuse or create new (user choice) | May be incomplete; offer update path |
| PR exists for task | Complete it (checkout, add work) | Respects in-progress effort; avoids parallel work |
| No prior work | Create new | Only create when nothing exists |

---

## Impact on User Workflow

### Old (Before Deduplication)
1. User runs `/msad-plan-epic DDIDNS-7732` twice
   - Recreates stories silently or fails confusingly
2. User runs `/msad-dev-planning DDIDNS-10519` twice
   - Creates two plan files; which one to use?
3. User runs `/msad-dev-execution` twice
   - Creates duplicate PRs for the same task

### New (After Deduplication)
1. User runs `/msad-plan-epic DDIDNS-7732` twice
   - First time: "Existing stories found. Improve?" → Guide to existing
   - Second time (--create): "Story DDIDNS-10562 already exists. Use /msad-dev-epic to improve."
   
2. User runs `/msad-dev-planning DDIDNS-10519` twice
   - First time: "No plan found. Creating..."
   - Second time: "Approved plan exists. Use /msad-dev-execution instead."

3. User runs `/msad-dev-execution` twice
   - First time: "Discovering existing PRs...PR #507 found. Will complete it."
   - Second time: "Existing PR #507 already has all changes. No new commits needed."

---

## Verification Checklist

- [x] `/msad-plan-epic` detects existing stories in Step 1
- [x] `/msad-plan-epic --create` refuses to create duplicates
- [x] `/msad-dev-planning` detects existing plans in Step 1
- [x] `/msad-dev-execution` prefers completing existing PRs
- [x] Error messages guide users to improvement paths
- [x] Approved plans cannot be recreated (only draft plans can be)
- [x] Duplicate stories are caught before Jira creation
- [x] Duplicate plans are caught before file write

---

## How This Protects The Pipeline

**Before (No Deduplication):**
- Messy Jira with duplicate stories
- Multiple plan files for same task (which one is current?)
- Duplicate PRs for same task (review confusion)
- Wasted effort re-doing work

**After (With Deduplication):**
- Single source of truth per story/task/plan
- Clear guidance: improve existing or create new (user choice)
- Approved plans are locked (can only be executed, not replaced)
- Existing PRs are respected and improved
- **Toolkit becomes idempotent and safe to run repeatedly**

---

**Result:** Users can safely run toolkit skills multiple times on the same epic/story/task. Duplicate work is detected and blocked with clear guidance on how to improve instead.
