# Branch Strategy & Protection Rules

## 1. Branch Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              BRANCH STRATEGY                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│                              ┌──────────┐                                   │
│                              │   main   │  ← Production Branch              │
│                              └────┬─────┘                                   │
│                                   │                                         │
│                                   │  PR + Approval Required                 │
│                                   │                                         │
│                              ┌────┴─────┐                                   │
│                              │   dev    │  ← Development Branch             │
│                              └────┬─────┘                                   │
│                                   │                                         │
│          ┌────────────────────────┼────────────────────────┐                │
│          │                        │                        │                │
│    ┌─────┴─────┐           ┌─────┴─────┐           ┌─────┴─────┐            │
│    │ feature/* │           │  bugfix/* │           │  hotfix/* │            │
│    └───────────┘           └───────────┘           └───────────┘            │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 2. Branch Definitions

| Branch      | Purpose                    | Deploys To            | Protection Level |
| ----------- | -------------------------- | --------------------- | ---------------- |
| `main`      | Production-ready code      | Production (EC2)      | 🔴 Highest       |
| `dev`       | Integration branch         | None (CI only)        | 🟡 Medium        |
| `feature/*` | New features               | None (CI only)        | 🟢 None          |
| `bugfix/*`  | Bug fixes                  | None (CI only)        | 🟢 None          |
| `hotfix/*`  | Emergency production fixes | Production (via main) | 🟢 None          |

## 3. Branch Naming Convention

### Format

```
{type}/{ticket-id}-{short-description}
```

### Examples

```
feature/EC-101-add-shopping-cart
bugfix/EC-202-fix-login-redirect
hotfix/EC-303-critical-payment-fix
```

### Types

| Type        | Use Case                  |
| ----------- | ------------------------- |
| `feature/`  | New functionality         |
| `bugfix/`   | Non-critical bug fixes    |
| `hotfix/`   | Critical production fixes |
| `docs/`     | Documentation updates     |
| `refactor/` | Code refactoring          |
| `test/`     | Test additions/updates    |

## 4. Workflow Rules

### 4.1 Feature Development Flow

```
1. Create branch from dev:
   git checkout dev
   git pull origin dev
   git checkout -b feature/EC-101-add-shopping-cart

2. Develop and commit:
   git add .
   git commit -m "feat: add shopping cart functionality"

3. Push branch:
   git push origin feature/EC-101-add-shopping-cart

4. Create PR to dev:
   - CI runs automatically
   - Request review

5. After approval, merge to dev:
   - Squash merge recommended

6. Create PR from dev to main:
   - CI runs automatically
   - Approval required from:  iam-mdthalha
   - CD runs after merge
```

### 4.2 Hotfix Flow (Emergency)

```
1. Create branch from main:
   git checkout main
   git pull origin main
   git checkout -b hotfix/EC-303-critical-fix

2. Fix and commit:
   git add .
   git commit -m "hotfix: fix critical payment issue"

3. Push branch:
   git push origin hotfix/EC-303-critical-fix

4. Create PR directly to main:
   - CI runs automatically
   - Expedited approval from: iam-mdthalha
   - CD runs after merge

5. Backport to dev:
   git checkout dev
   git merge main
   git push origin dev
```

## 5. Protection Rules for `main` Branch

### 5.1 Required Settings

| Setting                             | Value       | Reason                          |
| ----------------------------------- | ----------- | ------------------------------- |
| Require pull request before merging | ✅ Enabled  | No direct pushes                |
| Required approving reviews          | 1           | At least one approver           |
| Dismiss stale reviews               | ✅ Enabled  | New commits require re-approval |
| Require review from CODEOWNERS      | ✅ Enabled  | Designated reviewers            |
| Require status checks to pass       | ✅ Enabled  | CI must pass                    |
| Require branches to be up to date   | ✅ Enabled  | Must merge latest main          |
| Required status checks              | `ci`        | CI workflow must pass           |
| Require conversation resolution     | ✅ Enabled  | All comments addressed          |
| Do not allow bypassing settings     | ✅ Enabled  | Even admins follow rules        |
| Restrict who can push               | ✅ Enabled  | Only via PR                     |
| Allow force pushes                  | ❌ Disabled | Protect history                 |
| Allow deletions                     | ❌ Disabled | Cannot delete main              |

### 5.2 Required Status Checks

```
- ci (GitHub Actions workflow)
```

### 5.3 Required Reviewers

```
- iam-mdthalha
```

## 6. Protection Rules for `dev` Branch

### 6.1 Required Settings

| Setting                             | Value       | Reason                |
| ----------------------------------- | ----------- | --------------------- |
| Require pull request before merging | ✅ Enabled  | No direct pushes      |
| Required approving reviews          | 0           | Self-merge allowed    |
| Require status checks to pass       | ✅ Enabled  | CI must pass          |
| Required status checks              | `ci`        | CI workflow must pass |
| Allow force pushes                  | ❌ Disabled | Protect history       |
| Allow deletions                     | ❌ Disabled | Cannot delete dev     |

## 7. Commit Message Convention

### Format

```
{type}({scope}): {subject}

{body}

{footer}
```

### Types

| Type       | Description        |
| ---------- | ------------------ |
| `feat`     | New feature        |
| `fix`      | Bug fix            |
| `docs`     | Documentation      |
| `style`    | Formatting         |
| `refactor` | Code restructuring |
| `test`     | Tests              |
| `chore`    | Maintenance        |
| `ci`       | CI/CD changes      |
| `perf`     | Performance        |
| `hotfix`   | Emergency fix      |

### Examples

```
feat(cart): add shopping cart functionality

- Add cart component
- Add cart state management
- Add cart API integration

Closes #101
```

```
fix(auth): resolve login redirect issue

Users were not redirected after login.
Fixed by updating the auth callback handler.

Fixes #202
```

```
hotfix(payment): fix critical payment processing

CRITICAL: Payment was failing for international cards.
Immediate fix required.

Fixes #303
```

## 8. Pull Request Rules

### 8.1 PR Title Format

```
{type}({scope}): {description}
```

### 8.2 PR Requirements Checklist

- [ ] Branch is up to date with target branch
- [ ] CI passes
- [ ] No merge conflicts
- [ ] Self-review completed
- [ ] Tests added/updated (if applicable)
- [ ] Documentation updated (if applicable)
- [ ] PR description filled out

### 8.3 PR to `main` Additional Requirements

- [ ] Approved by: iam-mdthalha
- [ ] All conversations resolved
- [ ] Tested in dev environment

## 9. Merge Strategies

| Target Branch | Strategy     | Reason        |
| ------------- | ------------ | ------------- |
| `dev`         | Squash Merge | Clean history |
| `main`        | Squash Merge | Clean history |

## 10. Branch Cleanup

### Automatic Deletion

- Feature branches deleted after merge: ✅ Enabled
- Bugfix branches deleted after merge: ✅ Enabled
- Hotfix branches deleted after merge: ✅ Enabled

### Protected from Deletion

- `main`: Never delete
- `dev`: Never delete
