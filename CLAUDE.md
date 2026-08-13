# MSAD AI Toolkit — Contributing with the Fork Pattern

This toolkit automates epic development across the five-repo MSAD ecosystem. All work uses the **fork-based contribution pattern** to contribute back to the canonical Infoblox-CTO organization.

## Canonical Repos (Infoblox-CTO Organization)

The toolkit operates on these repos in the **Infoblox-CTO** org:

| Repo | Canonical URL |
|---|---|
| **ddi.dns.config** | `https://github.com/Infoblox-CTO/ddi.dns.config` |
| **ddi.cloud.proxy.middleware** | `https://github.com/Infoblox-CTO/ddi.cloud.proxy.middleware` |
| **ddi.msad.collector** | `https://github.com/Infoblox-CTO/ddi.msad.collector` |
| **ddi.msadconnect.proxy** | `https://github.com/Infoblox-CTO/ddi.msadconnect.proxy` |
| **ddi.msad.agent** | `https://github.com/Infoblox-CTO/ddi.msad.agent` |

## Default Branches Per Repo

⚠️ **Important:** Not all repos use `main`. Check the actual default branch:

| Repo | Default Branch |
|---|---|
| ddi.dns.config | `main` |
| ddi.cloud.proxy.middleware | `master` |
| ddi.msad.collector | `main` |
| ddi.msadconnect.proxy | `master` |
| ddi.msad.agent | `main` |

**Agents discover the default branch dynamically** — they do NOT assume `main`.

---

## Fork-Based Contribution Workflow

### 1. Setup (One-Time)

For **each repo**, clone from Infoblox-CTO and configure your fork:

```bash
# Clone from canonical org
git clone https://github.com/Infoblox-CTO/ddi.dns.config.git ~/ddi.dns.config
cd ~/ddi.dns.config

# Add your fork as origin (requires a personal fork at GitHub)
git remote rename origin upstream
git remote add origin https://github.com/YOUR-USERNAME/ddi.dns.config.git

# Verify
git remote -v
# origin   https://github.com/YOUR-USERNAME/ddi.dns.config.git (fetch/push)
# upstream https://github.com/Infoblox-CTO/ddi.dns.config.git (fetch)

# Discover the default branch (important!)
git symbolic-ref refs/remotes/upstream/HEAD
# refs/remotes/upstream/main  (or "master", etc.)
```

### 2. Working on Features

When the toolkit agents work on tasks:

```bash
# Agents discover the default branch
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/upstream/HEAD | sed 's|refs/remotes/upstream/||')

# Agents fetch from upstream (Infoblox-CTO)
git fetch upstream $DEFAULT_BRANCH

# Agents create a branch from upstream/<default-branch>
git checkout -b DDIDNS-10562-feature upstream/$DEFAULT_BRANCH

# Agents commit and push to YOUR FORK (origin)
git push origin DDIDNS-10562-feature

# Open PR against Infoblox-CTO/<default-branch>
gh pr create --repo Infoblox-CTO/ddi.dns.config \
  --base $DEFAULT_BRANCH \
  --head YOUR-USERNAME:DDIDNS-10562-feature
```

### 3. Integration with Agents

Agents in this toolkit:
- **Discover** the default branch per repo (not hardcoded to `main`)
- **Always fetch** from Infoblox-CTO (upstream)
- **Always push** to your personal fork (origin)
- **Always open PRs** against Infoblox-CTO/<detected-default-branch>

### 4. Keeping Your Fork Synced

Before starting new work:

```bash
cd ~/ddi.dns.config
git fetch upstream
git checkout main
git merge upstream/main
git push origin main
```

---

## Agent Configuration

Agents are configured to:

1. **Clone/pull** from Infoblox-CTO (read-only, upstream)
2. **Push** to your personal fork (read-write, origin)
3. **Open PRs** to Infoblox-CTO/main from your fork

### Key Variables

Each agent has access to:
- `GITHUB_USERNAME`: Your GitHub username (used for fork URLs)
- `UPSTREAM_ORG`: "Infoblox-CTO" (canonical organization)
- `REPO_TOPOLOGY_PATH`: Path to `references/repo-topology.md` for repo metadata

---

## Toolkit-Specific Conventions

### Repo Paths

Agents expect repos cloned to `~/REPO-NAME`:
- `~/ddi.dns.config`
- `~/ddi.cloud.proxy.middleware`
- `~/ddi.msad.collector`
- `~/ddi.msadconnect.proxy`
- `~/ddi.msad.agent`

### PR Workflow

When agents open PRs:
1. Commit messages include `Co-Authored-By: Claude ... <noreply@anthropic.com>`
2. PR titles reference the Jira task ID (e.g., "DDIDNS-10562: ...")
3. PR descriptions include acceptance criteria mapping
4. All PRs default to **DRAFT** until explicitly marked ready for review

### Quality Gates

Before opening a PR, agents verify:
- ✅ Tests pass (`make test` or `dotnet test`)
- ✅ Coverage ≥80% for Go, ≥70% for C# (minimum; tasks may require ≥92%)
- ✅ Linting passes (`make fmt`, `make lint` or `dotnet format`)
- ✅ `git status` clean (no uncommitted changes)

---

## Manual Contribution (Without Agents)

If you manually contribute using the toolkit's standards:

### Before Starting

```bash
# For any of the five repos:
cd ~/REPO-NAME
git fetch upstream main
git checkout -b DDIDNS-XXXXX-description upstream/main
```

### When Committing

Use the format agents use:
```bash
git commit -m "DDIDNS-XXXXX: Brief description

Co-Authored-By: Your Name <you@example.com>"
```

### When Opening a PR

```bash
git push origin DDIDNS-XXXXX-description

# Open PR against Infoblox-CTO/main (not your fork's main)
gh pr create --repo Infoblox-CTO/REPO-NAME \
  --base main \
  --head YOUR-USERNAME:DDIDNS-XXXXX-description
```

---

## Troubleshooting

### "Cannot push to Infoblox-CTO directly"

**Expected.** You have read-only access to Infoblox-CTO (upstream). Push to your fork (origin) instead, then open a PR.

```bash
git remote -v  # Verify origin points to your fork, upstream to Infoblox-CTO
git push origin BRANCH-NAME
```

### "PR says 'Can merge' but CI gates fail"

PRs require CI to pass before merge. Check the PR's CI status (GitHub Actions, Jenkins). Agents will not mark a PR as review-ready if tests fail.

### "My fork is behind upstream"

Sync before starting new work:
```bash
git fetch upstream main
git checkout main
git merge upstream/main
git push origin main
```

---

## References

- **Repo Topology:** See `references/repo-topology.md` for build/test commands, key files, and validation points per repo
- **Epic Execution:** See `README.md` for `/msad-dev-epic` usage
- **Agent Details:** See `agents/README.md` for available agents and triggers

