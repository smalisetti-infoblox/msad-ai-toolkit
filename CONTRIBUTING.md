# Contributing to MSAD AI Toolkit

Thank you for contributing! This toolkit uses a **fork-based model** to contribute code back to the canonical Infoblox-CTO repositories.

## Quick Start for Contributors

### 1. Fork the MSAD Repos

For each of the five repos you'll work on, create a personal fork in GitHub:

- Fork [`Infoblox-CTO/ddi.dns.config`](https://github.com/Infoblox-CTO/ddi.dns.config)
- Fork [`Infoblox-CTO/ddi.cloud.proxy.middleware`](https://github.com/Infoblox-CTO/ddi.cloud.proxy.middleware)
- Fork [`Infoblox-CTO/ddi.msad.collector`](https://github.com/Infoblox-CTO/ddi.msad.collector)
- Fork [`Infoblox-CTO/ddi.msadconnect.proxy`](https://github.com/Infoblox-CTO/ddi.msadconnect.proxy)
- Fork [`Infoblox-CTO/ddi.msad.agent`](https://github.com/Infoblox-CTO/ddi.msad.agent)

(Your forks will be at `github.com/YOUR-USERNAME/REPO-NAME`)

### 2. Clone from Canonical, Configure Fork

```bash
# For each repo:
git clone https://github.com/Infoblox-CTO/ddi.dns.config.git ~/ddi.dns.config
cd ~/ddi.dns.config

git remote rename origin upstream
git remote add origin https://github.com/YOUR-USERNAME/ddi.dns.config.git

# Verify
git remote -v
# origin    https://github.com/YOUR-USERNAME/ddi.dns.config.git
# upstream  https://github.com/Infoblox-CTO/ddi.dns.config.git
```

### 3. Install the Toolkit

```bash
git clone https://github.com/Infoblox-CTO/msad-ai-toolkit.git ~/msad-ai-toolkit

# In Claude Code: Settings → Plugins → Add Local Plugin
# Path: ~/msad-ai-toolkit
```

### 4. Run an Epic

```bash
/msad-dev-epic DDIDNS-7732
```

The toolkit will:
1. Clone/fetch repos from Infoblox-CTO (upstream)
2. Create branches and commit work
3. Push to your fork (origin)
4. Open PRs against Infoblox-CTO/main

---

## Development Workflow

### Starting New Work

```bash
cd ~/REPO-NAME

# Fetch from canonical org
git fetch upstream main

# Create branch from upstream (not your fork's main)
git checkout -b DDIDNS-XXXXX-description upstream/main
```

### Making Changes

Follow the repo's own CLAUDE.md for language-specific conventions:

**Go repos** (dns.config, middleware, collector, msadconnect.proxy):
```bash
make fmt
make lint
make test
```

**C# repo** (msad.agent):
```bash
dotnet format
dotnet test MSADAgent/Agent.Tests/Agent.Tests.csproj
```

### Committing

```bash
git commit -m "DDIDNS-XXXXX: Brief change description

Optional longer explanation of the change.

Co-Authored-By: Your Name <your.email@example.com>"
```

### Pushing & Opening PR

```bash
# Push to YOUR fork (origin)
git push origin DDIDNS-XXXXX-description

# Open PR against Infoblox-CTO (upstream)
gh pr create --repo Infoblox-CTO/REPO-NAME \
  --base main \
  --head YOUR-USERNAME:DDIDNS-XXXXX-description
```

---

## Using the Toolkit's Agents

The toolkit includes agents that automate the fork pattern:

### msad-backend-dev
Implements a full Jira task across the five-repo ecosystem:
```bash
/msad-ai-toolkit:msad-backend-dev DDIDNS-10562
```

**What it does:**
- Reads the Jira task and spec from architecture-hub
- Creates branches from Infoblox-CTO (upstream)
- Writes code using TDD (tests first)
- Pushes to your fork (origin)
- Opens PRs against Infoblox-CTO/main
- Never commits/pushes without your explicit approval

### msad-dev-epic
Orchestrates an entire epic across multiple tasks:
```bash
/msad-ai-toolkit:msad-dev-epic DDIDNS-7732
```

**Execution flow:**
1. Discover epic + linked tasks
2. Find existing PRs (complete and partial)
3. Dispatch parallel agents for gaps
4. Consolidate results
5. Report readiness for human review

---

## Quality Requirements

Before any PR is opened, agents verify:

| Check | Requirement | Tool |
|---|---|---|
| **Tests** | All pass, 0 failures | `make test` or `dotnet test` |
| **Coverage** | ≥80% (Go), ≥70% (C#) min; tasks may require ≥92% | Coverage report in test output |
| **Lint** | All checks pass | `make lint` or `dotnet format` |
| **Format** | Code is formatted | `make fmt` or `dotnet format` |
| **Git** | No uncommitted changes | `git status` |

---

## Common Questions

### "Why fork? Why not push directly to Infoblox-CTO?"

We use forks because:
1. **Safer** — Your changes don't land on main until reviewed
2. **Scalable** — Multiple contributors don't need direct repo access
3. **Standard** — Matches GitHub's recommended flow for open-source collaboration
4. **Reversible** — PRs can be abandoned without affecting main

### "Can I push directly to Infoblox-CTO?"

Only if you have admin/write access to that org. Otherwise, use your fork.

### "What if I don't have a fork yet?"

Create one on GitHub (click **Fork** on the Infoblox-CTO repo), then run the clone + configure steps above.

### "Can I use this toolkit on other epics?"

Yes! The toolkit works on any Jira epic linked to MSAD tasks. Usage:
```bash
/msad-dev-epic DDIDNS-YOUR-EPIC-ID
```

### "What if an agent fails?"

1. The agent will **stop and ask** before committing/pushing
2. Read the error message — it typically explains what to fix
3. Fix the issue locally
4. Resume the agent with more context, or
5. Manually continue the work and open a PR yourself

---

## Reviewing & Merging

When your PR is ready for review:

1. **Change from DRAFT to READY** (if applicable)
2. **Assign reviewers** from the relevant repo's maintainers
3. **Address review feedback** in new commits (don't amend)
4. **Wait for CI** to pass (GitHub Actions, Jenkins)
5. **Maintainer merges** once approved

PRs are merged into Infoblox-CTO/main. Your fork's main stays in sync via `git fetch upstream && git merge upstream/main`.

---

## Troubleshooting

### "fatal: Cannot push to this repository"

**Cause:** Your local `origin` points to Infoblox-CTO (read-only).

**Fix:**
```bash
git remote rename origin upstream
git remote add origin https://github.com/YOUR-USERNAME/REPO-NAME.git
git push origin BRANCH-NAME
```

### "My PR says 'Can merge' but tests are failing"

Check the PR's **Checks** tab (GitHub Actions). If CI is red, wait for it to complete and fix any failures before merge.

### "I want to contribute but don't have time for a full epic"

No problem! Pick a **single task** and work on it:

```bash
# Instead of the full epic
/msad-ai-toolkit:msad-backend-dev DDIDNS-10562
```

This implements just one task, not the whole epic.

---

## References

- **CLAUDE.md**: Fork pattern details and agent configuration
- **README.md**: Toolkit overview and quick start
- **references/repo-topology.md**: Build/test/lint commands per repo
- **Jira**: Your epic issue (e.g., DDIDNS-7732)

