#!/usr/bin/env bash
# protect-main.sh -- apply branch protection to main via the GitHub API.
# Requires an authenticated gh with admin rights on the repo.
set -euo pipefail

repo="${1:-LemcheNET/mic-indicator}"

gh api -X PUT "repos/$repo/branches/main/protection" --input - <<JSON
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["DCO sign-off", "ShellCheck", "CodeQL (workflows)", "Secret scan (gitleaks)"]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 0,
    "dismiss_stale_reviews": true
  },
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true,
  "restrictions": null
}
JSON
echo "Branch protection applied to $repo:main"
