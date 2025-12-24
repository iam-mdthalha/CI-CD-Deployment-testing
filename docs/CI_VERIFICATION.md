# CI Pipeline Verification Guide

## 1. Prerequisites Checklist

Before CI can run successfully, verify:

| Check | Command/Action                    | Expected              |
| ----- | --------------------------------- | --------------------- |
| ✅    | `.github/workflows/ci.yml` exists | File present          |
| ✅    | `Dockerfile` exists in root       | File present          |
| ✅    | `server/index.js` exists          | File present          |
| ✅    | `server/health.js` exists         | File present          |
| ✅    | `package.json` has `build` script | `npm run build` works |
| ✅    | `package.json` has `test` script  | `npm test` works      |
| ✅    | No `.env` file committed          | Only `.env.example`   |

## 2. Trigger CI Pipeline

### Method 1: Create a Pull Request

```bash
# Create a new branch
git checkout -b feature/test-ci-pipeline

# Make a small change (e.g., update README)
echo "# CI Test" >> README. md

# Commit and push
git add .
git commit -m "test: verify CI pipeline"
git push origin feature/test-ci-pipeline
```

Then create PR via GitHub UI:

- Go to: https://github.com/iam-mdthalha/CI-CD-Deployment-testing/pulls
- Click "New Pull Request"
- Select `feature/test-ci-pipeline` → `dev` (or `main`)
- Create PR

### Method 2: Manual Trigger (workflow_dispatch)

1. Go to: https://github.com/iam-mdthalha/CI-CD-Deployment-testing/actions
2. Select "ci" workflow
3. Click "Run workflow"
4. Select branch
5. Click "Run workflow"

## 3. Expected CI Outcomes

### 3.1 Successful Run

```
┌─────────────────────────────────────────────────────────────┐
│                    CI PIPELINE - SUCCESS                    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ✅ lint              (1m 30s)                              │
│     ├── Checkout Code                                       │
│     ├── Setup Node.js                                       │
│     ├── Install Dependencies                                │
│     ├── Run ESLint                                          │
│     └── Check for Console Logs                              │
│                                                             │
│  ✅ test              (2m 00s)                              │
│     ├── Checkout Code                                       │
│     ├── Setup Node.js                                       │
│     ├── Install Dependencies                                │
│     ├── Run Tests                                           │
│     └── Upload Coverage Report                              │
│                                                             │
│  ✅ build             (3m 00s)                              │
│     ├── Checkout Code                                       │
│     ├── Setup Node. js                                      │
│     ├── Install Dependencies                                │
│     ├── Build React Application                             │
│     ├── Verify Build Output                                 │
│     └── Upload Build Artifact                               │
│                                                             │
│  ✅ docker-build      (5m 00s)                              │
│     ├── Checkout Code                                       │
│     ├── Set up Docker Buildx                                │
│     ├── Generate Image Tag                                  │
│     ├── Build Docker Image                                  │
│     ├── Verify Docker Image                                 │
│     ├── Test Container Startup                              │
│     ├── Test Health Endpoint                                │
│     ├── Validate Health Response                            │
│     └── Cleanup Test Container                              │
│                                                             │
│  ✅ security-scan     (1m 00s)                              │
│     ├── Checkout Code                                       │
│     ├── Setup Node.js                                       │
│     ├── Install Dependencies                                │
│     ├── Run npm audit                                       │
│     ├── Check for Secrets in Code                           │
│     └── Check . env files not committed                     │
│                                                             │
│  ✅ ci-summary        (0m 30s)                              │
│     ├── Check Job Results                                   │
│     ├── Determine Overall Status                            │
│     └── Post PR Comment (Success)                           │
│                                                             │
└─────────────────────────────────────────────────────────────┘

Total Time: ~8-12 minutes
```

### 3.2 PR Comment (Success)

After successful CI, this comment appears on your PR:

```markdown
## ✅ CI Pipeline Passed

| Check         | Status    |
| ------------- | --------- |
| Lint          | ✅ Passed |
| Test          | ✅ Passed |
| Build         | ✅ Passed |
| Docker Build  | ✅ Passed |
| Security Scan | ✅ Passed |

**Ready for review! **

---

_Commit: a1b2c3d4e5f6_
```

### 3.3 PR Comment (Failure)

If CI fails, this comment appears:

```markdown
## ❌ CI Pipeline Failed

| Check         | Status    |
| ------------- | --------- |
| Lint          | ✅ Passed |
| Test          | ❌ Failed |
| Build         | ✅ Passed |
| Docker Build  | ❌ Failed |
| Security Scan | ✅ Passed |

**Please fix the failing checks before merging.**

---

_Commit: a1b2c3d4e5f6_
```

## 4. GitHub Actions UI Navigation

### View Workflow Runs

```
https://github.com/iam-mdthalha/CI-CD-Deployment-testing/actions/workflows/ci.yml
```

### View Specific Run

```
https://github.com/iam-mdthalha/CI-CD-Deployment-testing/actions/runs/{RUN_ID}
```

### View Job Logs

1. Click on workflow run
2. Click on job name (e.g., "docker-build")
3. Expand step to see logs

## 5. Artifacts Generated

| Artifact          | Contents                  | Retention |
| ----------------- | ------------------------- | --------- |
| `coverage-report` | Test coverage HTML report | 7 days    |
| `build-output`    | React production build    | 7 days    |

### Download Artifacts

1. Go to workflow run
2. Scroll to "Artifacts" section
3. Click to download

## 6. Branch Protection Verification

After CI runs successfully at least once:

1. Go to: https://github.com/iam-mdthalha/CI-CD-Deployment-testing/settings/branches
2. Edit `main` branch rule
3. Under "Require status checks to pass":
   - Search for "ci"
   - Select "ci-summary" (or individual jobs)
4. Save changes

Now PRs cannot merge until CI passes.
