#!/bin/bash
set -e

# =============================================================================
# GitHub Branch Protection Setup Script
# =============================================================================
# This script documents the branch protection rules to be configured manually
# in GitHub repository settings. 
#
# Path: Repository → Settings → Branches → Add branch protection rule
# =============================================================================

cat << 'EOF'
=============================================================================
BRANCH PROTECTION SETUP GUIDE
=============================================================================

Repository: iam-mdthalha/CI-CD-Deployment-testing

Navigate to: 
https://github.com/iam-mdthalha/CI-CD-Deployment-testing/settings/branches

=============================================================================
RULE 1: Protect 'main' Branch
=============================================================================

Branch name pattern: main

☑️ Require a pull request before merging
   ☑️ Require approvals:  1
   ☑️ Dismiss stale pull request approvals when new commits are pushed
   ☑️ Require review from Code Owners

☑️ Require status checks to pass before merging
   ☑️ Require branches to be up to date before merging
   Status checks that are required: 
   - ci

☑️ Require conversation resolution before merging

☑️ Do not allow bypassing the above settings

☐ Allow force pushes (DISABLED)

☐ Allow deletions (DISABLED)

=============================================================================
RULE 2: Protect 'dev' Branch
=============================================================================

Branch name pattern: dev

☑️ Require a pull request before merging
   ☐ Require approvals: 0 (not required)

☑️ Require status checks to pass before merging
   ☑️ Require branches to be up to date before merging
   Status checks that are required: 
   - ci

☐ Allow force pushes (DISABLED)

☐ Allow deletions (DISABLED)

=============================================================================
ADDITIONAL SETTINGS
=============================================================================

Navigate to:
https://github.com/iam-mdthalha/CI-CD-Deployment-testing/settings

General → Pull Requests: 
☑️ Allow squash merging (DEFAULT)
☐ Allow merge commits (DISABLED)
☐ Allow rebase merging (DISABLED)
☑️ Automatically delete head branches

=============================================================================
NOTIFICATION SETTINGS
=============================================================================

Navigate to:
https://github.com/settings/notifications

Ensure email notifications are enabled for:
- iam.alphabit.notifier@gmail.com

Watching: 
- Watch the repository:  iam-mdthalha/CI-CD-Deployment-testing

=============================================================================
EOF

echo ""
echo "Branch protection rules documented. Configure manually in GitHub UI."
echo ""