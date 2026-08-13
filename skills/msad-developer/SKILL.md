---
name: msad-developer
description: "Entry-point router for MSAD development tasks. Classifies the input (epic, story, task list, or 'execute plan X') and suggests the right downstream skill (/msad-dev-planning or /msad-dev-execution). Use as the starting point for any MSAD team dev task. Don't use for one-off code edits, ad-hoc questions, or non-MSAD work — invoke the specialist skill directly."
version: 0.1.0
created_by:
  name: Claude Code
  role: AI SDLC for MSAD epic
---

# MSAD Developer — Router

Entry-point skill for MSAD development work spanning six repos (ddi.dns.config, ddi.dns.data, ddi.cloud.proxy.middleware, ddi.msad.collector, ddi.msadconnect.proxy, ddi.msad.agent).

Classifies the input and suggests the correct downstream skill. Freehand MSAD implementation work is forbidden — the specialist skills exist for a reason.

## Routing Workflow

```
User invokes /msad-developer with input
  ↓
Classify: epic vs. story vs. task list vs. "execute plan"
  ↓
Match against routing table (below)
  ↓
Suggest downstream skill
  ↓
User invokes suggested skill; you don't auto-chain
```

## Routing Table

| Input | Suggested Skill | Rationale |
|---|---|---|
| Jira Epic ID (DDIDNS-XXXXX, type=Epic) | `/msad-dev-planning` | Epics go directly to planning; we write a plan for the epic's scope (multi-repo work packages) |
| Jira Story ID (type=Story) with clear AC and 1–3 repos involved | `/msad-dev-planning` | Stories go to planning to produce a work plan before execution |
| Jira Task ID (type=Task) in isolation | `/msad-dev-planning` | Tasks are subtasks of stories/epics; planning reads parent context and scopes the work |
| Plain-text task list (no Jira ticket) | `/msad-dev-planning` | Planning can ingest prose; will create a Jira story if needed or proceed ad-hoc with clear assumptions |
| "execute the plan at `<path>`" | `/msad-dev-execution` | Execution skill consumes an approved plan file and runs it end-to-end |
| "run end-to-end test for replication scope changes" or similar API-level verification | `/msad-e2e-verify` | E2E skill brings up the API stack and drives zone creation/update flows via WAPI v3 without the Windows agent |
| Ambiguous or multi-faceted | Ask the user | If unclear whether epic or story, or if scope spans multiple independent initiatives, ask which skill to invoke |

## Classification Guide

### Epic vs. Story vs. Task

- **Epic** (type=Epic in Jira): broad initiative (e.g., DDIDNS-7732 "Microsoft DNS zone creation / replication scope"). Scope: multiple stories/tasks across multiple repos. Multiple ACs (user stories). **Route to planning.**
- **Story** (type=Story): single user-facing feature (e.g., DDIDNS-10562 "Backend: support Domain/Forest replication scope on Microsoft DNS zone creation"). Scope: usually 1–3 repos. Acceptance criteria. **Route to planning.**
- **Task** (type=Task): subtask of a story/epic; implementation-focused (e.g., DDIDNS-10519 "ddi.cloud.proxy.middleware: support Domain/Forest replication scope for Auth, Reverse Auth, and Forward zone creation"). Usually 1 repo. **Route to planning** (planning reads the parent story/epic for context).

### Input Shape Recognition

1. **Jira ID given?** Use Atlassian MCP `getJiraIssue` to check `issueType` and linked epic/parent.
2. **No Jira ID, prose description given?** Classify by counting "repos" mentioned (e.g., "add validation in the agent and the middleware" → 2 repos). If vague, ask.
3. **"execute plan at `<path>`"?** Immediately route to `/msad-dev-execution`; don't invoke planning.

### Repo Detection

Load `references/repo-topology.md` from this toolkit. Service/component names in the input map to repos:

- "ddi.dns.config", "WAPI v3", "zone creation API" → `ddi.dns.config`
- "ddi.dns.data", "WAPI v3 data layer", "zone data retrieval" → `ddi.dns.data`
- "ddi.cloud.proxy.middleware", "cloud proxy", "MSAD interceptor" → `ddi.cloud.proxy.middleware` (consumed by both dns.config and dns.data)
- "ddi.msad.collector", "error code mapping", "gRPC service" → `ddi.msad.collector`
- "ddi.msadconnect.proxy", "proxy", "RPC bridge" → `ddi.msadconnect.proxy`
- "ddi.msad.agent", "PowerShell", "Windows Service", "zone controller" → `ddi.msad.agent`

If a task mentions a service/component that doesn't map to the six repos, tell the user which repo(s) you think are involved and ask for confirmation.

## How This Skill Works

1. **User invokes `/msad-developer` with input** (Jira ID, prose, or "execute plan").
2. **You classify** the input (epic / story / task / execute-plan).
3. **You suggest the downstream skill** with a one-line rationale.
4. **The user invokes the suggested skill** explicitly. You don't auto-chain.
5. **You wait.** The suggested skill takes over.

## Operating Rules

- **Only suggest**, never auto-chain. The user owns the decision to proceed.
- **For ambiguous inputs, ask.** Don't guess whether it's epic or story, or which repos are involved.
- **If the user resists routing** ("just do it freehand"), explain the cost: freehand work skips the planning gate (which catches scope creep, cross-repo coordination issues, and validation gaps), the multi-round review loop, and the structured PR template. That's a quality regression.
- **Red flags** (stop and re-think):
  - "This is small enough to freehand" — No. Use the suite.
  - "Skip planning, go straight to execution" — No. Plans are the gate that prevent out-of-scope thrashing.
  - "I'll handle the cross-repo coordination myself" — No. The planning step groups independent work packages and flags dependencies explicitly.

## Examples

### Example 1: Epic Input

**User says:** "Work on DDIDNS-7732" (or shares the epic URL).

**You:**
1. Fetch the epic via Atlassian MCP. Confirm `issuetype = Epic`.
2. Note the linked stories/tasks (DDIDNS-10519, DDIDNS-10521, etc.). Count repos (all 5).
3. Suggest: **`/msad-dev-planning DDIDNS-7732`** — "This is an Epic spanning 5 repos. Planning will break it into independent work packages per repo, identify dependencies, and write a plan. You approve the plan, then `/msad-dev-execution` runs it."

### Example 2: Task Input

**User says:** "Implement DDIDNS-10521" (validate replication scope in the agent).

**You:**
1. Fetch the task. It's a subtask of DDIDNS-10562 (story). Parent story is DDIDNS-10562.
2. Note: single repo (ddi.msad.agent). Scope is ~one method in one file.
3. Suggest: **`/msad-dev-planning DDIDNS-10521`** — "Planning will read the parent story for context, scope this task against the epic, write a focused plan, and get your approval before execution."

### Example 3: Execute Plan Input

**User says:** "Execute the plan at `/Users/smalisetti/msad-dev-plans/2026-08-13-DDIDNS-7732-plan.md`."

**You:**
1. Immediately suggest: **`/msad-dev-execution /Users/smalisetti/msad-dev-plans/2026-08-13-DDIDNS-7732-plan.md`** — no planning needed, the plan is approved.

### Example 4: E2E Test Input

**User says:** "Set up an end-to-end test for the replication scope flow — I want to drive zone creates with domain/forest scopes via the API without needing the Windows agent."

**You:**
1. Classify: E2E test harness (no code implementation, just test setup and scripts).
2. Suggest: **`/msad-e2e-verify`** — "This skill brings up the API stack (dns.config + mocked MSAD collector), drives zone create/update flows via WAPI v3, and asserts on replication-scope values in the DB and mocked collector responses."

## Anti-Patterns

- **"Let me just edit this one file."** — No. Route first. Plans prevent scope creep.
- **"Skip planning, the task is small."** — No. Small tasks become big; the planning step catches that early.
- **"I know what needs to change, let's go."** — No. Planning documents the scope, links it to AC, and surfaces risks upfront.
- **"The user wants speed."** — Speed comes from correct routing, not skipping it. Freehand work often needs rework; planning avoids that.

## Error Handling

- **Atlassian MCP unavailable / Jira lookup fails:** fall back to prose-shape classification. Ask the user to confirm whether the input is an epic, story, or task.
- **Input is a non-DDIDNS Jira ID** (e.g., DDIDHCP): the suite is MSAD-scoped. Tell the user this skill suite doesn't cover the project; suggest the appropriate team's workflow.
- **Input is ambiguous** (e.g., "add replication scope validation" with no Jira context): ask which of the six repos the change targets, or suggest running the Jira lookup first.
- **User insists on freehand work:** state the regression cost (no planning gate, no multi-round review, no structured PR) and proceed only if explicitly authorized. Record the override in the PR body.

## Specialist Skills Index

- **`/msad-dev-planning`** — writes a multi-repo work plan from a Jira epic/story/task, gates on user approval
- **`/msad-dev-execution`** — runs an approved plan: dispatch agents, validation loop, draft PRs
- **`/msad-e2e-verify`** — API-level end-to-end test suite (no Windows agent needed)
- **`/msad-backend-dev`** — implementation agent for a single task in a single repo (don't invoke directly; planning dispatches it)
- **`/msad-code-review`** — review agent for a single PR (don't invoke directly; execution dispatches it)
