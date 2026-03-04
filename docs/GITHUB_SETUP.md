# GitHub Repository Setup

This guide applies repository hardening after the repo is created on GitHub.

## Prerequisites
- `gh` installed and authenticated
- repository created on GitHub
- local branch pushed (including CI workflow)

## 1) Push Repository
From `<repo-root>`:

```bash
git branch -M main
git remote add origin git@github.com:<owner>/<repo>.git
git push -u origin main
```

## 2) Apply Hardening via Script

```bash
OWNER=<owner> REPO=<repo> ./scripts/github/apply_repo_hardening.sh
```

Default branch target is `main`.
To target a different branch:

```bash
OWNER=<owner> REPO=<repo> BRANCH=main ./scripts/github/apply_repo_hardening.sh
```

Optional metadata overrides:

```bash
OWNER=<owner> REPO=<repo> \
REPO_DESCRIPTION="TP-Link Archer TBE550E (MT7927/MT6639) Linux enablement" \
TOPICS="tp-link,tbe550e,mt7927,mt6639,mediatek,wifi7,bluetooth,linux,kernel,driver,ubuntu" \
./scripts/github/apply_repo_hardening.sh
```

## 3) What the Script Configures
- merge strategy policy
  - squash enabled
  - merge commits disabled
  - rebase enabled
  - auto-delete merged branches enabled
- repository settings
  - projects/wiki disabled
  - auto-merge enabled
  - web commit signoff required
  - repository description updated
  - repository topics/tags updated
- security features (best effort)
  - vulnerability alerts
  - automated security fixes
  - private vulnerability reporting
- branch protection
  - required status check: `CI / validate`
  - strict status checks
  - admins enforced
  - 1 required approving review
  - code owner reviews required
  - stale approvals dismissed
  - conversation resolution required
  - force-push and delete blocked
  - linear history required

## 4) Validate in GitHub UI
Verify under:
- Settings -> General
- Settings -> Security
- Settings -> Branches

If API calls are partially rejected (plan/permission constraints), rerun after adjusting repo permissions.
