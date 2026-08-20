# MSAD Developer — Epic Execution

**Non-authoritative example document.** See [`SKILL.md`](SKILL.md) for the authoritative process.

Orchestrates a Backend epic or single story end-to-end: discovers tasks and existing PRs, ensures every Backend task has an approved dev plan (invoking `/msad-dev-planning` if needed), then executes it (invoking `/msad-dev-execution`). Frontend/UI tasks are classified and excluded, not dispatched.

## Quick Start

```bash
/msad-dev-epic DDIDNS-7732            # full epic
/msad-dev-epic DDIDNS-10562 --scope story   # single story, narrower/faster
```

## Key Points

- **Gated, not direct-dispatch:** this skill never calls `msad-backend-dev` itself — it loops per task through planning (if no approved plan exists) and then execution.
- **Existing PRs preferred:** discovers PRs by task ID, parses review comments for blocking/non-blocking findings, and completes them in place rather than opening duplicates.
- **Backend/Frontend/QA classification:** see `references/functional-area-classification.md` for the signal list.

**See `SKILL.md` for the full authoritative workflow, including discovery details, the per-task gating loop, and the consolidated report format.**
