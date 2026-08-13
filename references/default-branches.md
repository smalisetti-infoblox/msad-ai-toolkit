# Default Branches — Infoblox-CTO MSAD Repos

When contributing to Infoblox-CTO repos, always target the repo's **actual default branch**, not a hardcoded `main`.

## Default Branch Reference

| Repo | Default Branch | Canonical URL |
|---|---|---|
| **ddi.dns.config** | `main` | https://github.com/Infoblox-CTO/ddi.dns.config |
| **ddi.cloud.proxy.middleware** | `master` | https://github.com/Infoblox-CTO/ddi.cloud.proxy.middleware |
| **ddi.msad.collector** | `main` | https://github.com/Infoblox-CTO/ddi.msad.collector |
| **ddi.msadconnect.proxy** | `master` | https://github.com/Infoblox-CTO/ddi.msadconnect.proxy |
| **ddi.msad.agent** | `main` | https://github.com/Infoblox-CTO/ddi.msad.agent |

---

## Discovering Default Branch Dynamically

If the reference above becomes stale, agents and contributors should discover the default branch at runtime:

```bash
# After cloning and configuring upstream remote:
git symbolic-ref refs/remotes/upstream/HEAD | sed 's|refs/remotes/upstream/||'

# Output: "main" or "master" (depending on repo)
```

---

## Why It Matters

- **Different conventions:** Infoblox-CTO repos follow different branching conventions (some legacy `master`, some modern `main`)
- **Future-proof:** If a repo's default branch changes, agents automatically use the new one
- **Accuracy:** Hardcoding `main` causes PRs to target the wrong branch, violating contribution policy
- **Scale:** With many repos, dynamic discovery is more reliable than manual per-repo configuration

---

## Agent Integration

The toolkit's agents:
- Read this reference during setup
- Discover the default branch at runtime via `git symbolic-ref`
- Use `$DEFAULT_BRANCH` in all branch/fetch/PR operations
- Never assume `main` or `master`

See **[CLAUDE.md](../CLAUDE.md)** for implementation details.
