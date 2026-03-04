#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   OWNER=your-user REPO=tbe550e-mt7927-linux-enablement ./scripts/github/apply_repo_hardening.sh
# Optional:
#   BRANCH=main

OWNER="${OWNER:?OWNER is required}"
REPO="${REPO:?REPO is required}"
BRANCH="${BRANCH:-main}"
REPO_DESCRIPTION="${REPO_DESCRIPTION:-TP-Link Archer TBE550E (MT7927/MT6639) Linux enablement, PCI 14c3:7927, BT USB 0489:e116}"
TOPICS="${TOPICS:-tp-link,tbe550e,mt7927,mt6639,mediatek,wifi7,bluetooth,linux,kernel,driver,ubuntu}"

REQUIRED_CHECK="CI / validate"

echo "Applying repository settings to ${OWNER}/${REPO}"

# Core repository settings
gh api --method PATCH "/repos/${OWNER}/${REPO}" \
  -f description="${REPO_DESCRIPTION}" \
  -f allow_squash_merge=true \
  -f allow_merge_commit=false \
  -f allow_rebase_merge=true \
  -f delete_branch_on_merge=true \
  -f allow_auto_merge=true \
  -f has_issues=true \
  -f has_projects=false \
  -f has_wiki=false \
  -f web_commit_signoff_required=true >/dev/null

# Repository topics/tags (replace full set)
TOPICS_JSON="$(printf '%s' "$TOPICS" | awk -F, '
  BEGIN { printf "[" }
  {
    for (i = 1; i <= NF; i++) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i)
      if (length($i)) {
        if (count++) printf ","
        printf "\"%s\"", $i
      }
    }
  }
  END { printf "]" }
')"
gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  "/repos/${OWNER}/${REPO}/topics" \
  --input - <<JSON >/dev/null
{
  "names": ${TOPICS_JSON}
}
JSON

# Security features (best effort depending on plan/repo visibility)
for endpoint in \
  "/repos/${OWNER}/${REPO}/vulnerability-alerts" \
  "/repos/${OWNER}/${REPO}/automated-security-fixes" \
  "/repos/${OWNER}/${REPO}/private-vulnerability-reporting"
do
  gh api --method PUT "$endpoint" >/dev/null 2>&1 || true
done

# Branch protection for main branch (best effort: may require paid plan for private repos)
if ! gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  "/repos/${OWNER}/${REPO}/branches/${BRANCH}/protection" \
  --input - <<JSON
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["${REQUIRED_CHECK}"]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": true,
    "required_approving_review_count": 1,
    "require_last_push_approval": true
  },
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": false,
  "required_conversation_resolution": true,
  "lock_branch": false,
  "allow_fork_syncing": true
}
JSON
then
  echo "Warning: branch protection could not be applied (likely plan/visibility limitation)."
fi

# Optional: protect tags from accidental move/delete (best effort)
# gh api --method POST "/repos/${OWNER}/${REPO}/rulesets" ...

echo "Done. Branch protection and repository hardening applied."
