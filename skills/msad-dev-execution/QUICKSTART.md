# Quick Start: MSAD Dev Execution Agent

**Want to try the agent?** Follow these steps.

## 1. Run Simulation (No Real Changes)

```bash
cd /Users/smalisetti/msad-ai-toolkit

# Run the execution agent on the DDIDNS-7732 plan
python3 skills/msad-dev-execution/executor.py \
  specs/msad-dev-plans/2026-08-13-DDIDNS-7732-WITH-PR-GAPS.md
```

**What happens:**
- Agent loads the execution plan
- Simulates executing 4 PRs (fixing gaps, running tests, merging)
- Shows what would happen without touching real repos
- Reports final metrics

**Expected output:**
```
[21:46:55] ══════════════════════════════════════════════════════════════════════
[21:46:55] PHASE 1: STARTUP & CONTEXT
...
[21:46:56] ✅ EXECUTION COMPLETE - All PRs merged successfully
```

## 2. Understand the Plan

The execution plan contains:
- **PR 507:** Partial (85% done) — needs Conditional Forwarder handler tests
- **PR 508:** Complete (100%) — ready to merge
- **PR 241:** Partial (95% done) — needs ZONE-005 test cases
- **PR 6300:** Complete (100%) — ready to merge

The agent:
1. Fixes gaps in partial PRs (add tests, verify coverage)
2. Merges complete PRs (no changes needed)
3. Reports results

## 3. See the Detailed Execution Flow

Read the dry-run simulation:
```bash
cat specs/msad-dev-plans/EXECUTION-SIMULATION-DDIDNS-7732.md
```

This shows exactly what would happen in real execution:
- Git checkout and branch operations
- Test generation and execution
- Coverage verification
- Commit and push workflow
- CI checks and PR merge

## 4. Implement Real Execution (Future)

To enable real git operations:

1. **Edit `executor.py`** to implement real git methods (see `AGENT-IMPLEMENTATION.md`)
2. **Set environment variable:**
   ```bash
   export MSAD_EXECUTOR_MODE=real
   ```
3. **Run the agent:**
   ```bash
   python3 skills/msad-dev-execution/executor.py plan.md
   ```

## 5. Extend for Your Own Plans

The agent works with any execution plan following the format:

```markdown
---
jira: DDIDNS-XXXXX
status: ready-for-execution
---

# Plan Name

## Per-PR Review Details

### PR XXX: <Task> — <Description>

**Gap identified in plan:**
- <gap description>

**Planned fix:**
- <what the agent should do>
```

Then run:
```bash
python3 executor.py /path/to/your-plan.md
```

---

## Files to Explore

- **`README.md`** — Skill overview and capabilities
- **`PR-GAP-HANDLING.md`** — 11-step systematic workflow
- **`EXAMPLE-HANDLE-PR-507.md`** — Concrete example (add handler tests)
- **`EXAMPLE-HANDLE-PR-241.md`** — Concrete example (add test cases)
- **`AGENT-IMPLEMENTATION.md`** — How to extend to real operations
- **`executor.py`** — Agent source code
- **`EXECUTION-SIMULATION-DDIDNS-7732.md`** — Full dry-run simulation

---

## Next Steps

1. **Run the simulation** to see the workflow in action
2. **Read the implementation guide** to understand how to extend it
3. **Generate a real execution plan** for your epic using `msad-dev-planning`
4. **Implement real git operations** in `executor.py`
5. **Execute against real PRs** when ready

---

## Questions?

- **What does the agent do?** See `README.md`
- **How does it work step-by-step?** See `PR-GAP-HANDLING.md`
- **What would real execution look like?** See `EXECUTION-SIMULATION-DDIDNS-7732.md`
- **How do I extend it?** See `AGENT-IMPLEMENTATION.md`
