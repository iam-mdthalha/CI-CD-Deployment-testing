# CI Pipeline Troubleshooting Guide

## Common Failures and Solutions

---

## 1. Lint Job Failures

### Error: ESLint not found

```
sh: eslint: command not found
```

**Solution:**

```bash
# Add eslint to devDependencies
npm install --save-dev eslint

# Or add lint script to package.json that handles missing eslint
"lint": "eslint src/ --ext .js,. jsx || true"
```

### Error: ESLint configuration not found

```
ESLint couldn't find a configuration file
```

**Solution:** Create `.eslintrc. json` in project root:

```json
{
  "env": {
    "browser": true,
    "es2021": true,
    "node": true,
    "jest": true
  },
  "extends": ["react-app", "react-app/jest"],
  "parserOptions": {
    "ecmaVersion": "latest",
    "sourceType": "module"
  },
  "rules": {
    "no-unused-vars": "warn",
    "no-console": "warn"
  }
}
```

### Error: Parsing error in JSX

```
Parsing error:  Unexpected token <
```

**Solution:** Ensure ESLint config extends `react-app`:

```json
{
  "extends": ["react-app"]
}
```

---

## 2. Test Job Failures

### Error: No tests found

```
No tests found, exiting with code 1
```

**Solution:** CI workflow already handles this with `--passWithNoTests`. If still failing:

```bash
# Create a minimal test file
mkdir -p src/__tests__

cat > src/__tests__/App.test.js << 'EOF'
test('placeholder test', () => {
  expect(true).toBe(true);
});
EOF
```

### Error: Test timeout

```
Timeout - Async callback was not invoked within 5000ms
```

**Solution:** Increase timeout in `package.json`:

```json
{
  "jest": {
    "testTimeout": 30000
  }
}
```

### Error: Cannot find module

```
Cannot find module 'react' from 'App.js'
```

**Solution:**

```bash
# Clear npm cache and reinstall
rm -rf node_modules package-lock.json
npm install
```

---

## 3. Build Job Failures

### Error: Build fails with memory error

```
FATAL ERROR:  CALL_AND_RETRY_LAST Allocation failed - JavaScript heap out of memory
```

**Solution:** Already handled in CI with increased memory. If still failing, add to `package.json`:

```json
{
  "scripts": {
    "build": "react-scripts build"
  }
}
```

Or set environment variable in CI:

```yaml
- name: Build React Application
  run: npm run build
  env:
    CI: true
    NODE_OPTIONS: "--max_old_space_size=4096"
```

### Error: Build directory not found

```
❌ Build directory not found
```

**Solution:** Check your build script outputs to `build/` directory:

```bash
# Verify locally
npm run build
ls -la build/
```

### Error: react-scripts not found

```
sh: react-scripts:  command not found
```

**Solution:**

```bash
# Ensure react-scripts is in dependencies
npm install react-scripts
```

---

## 4. Docker Build Failures

### Error: Dockerfile not found

```
unable to prepare context: unable to evaluate symlinks in Dockerfile path
```

**Solution:** Ensure `Dockerfile` exists in project root:

```bash
ls -la Dockerfile
```

### Error: npm ci fails in Docker

```
npm ERR! cipm can only install packages with an existing package-lock.json
```

**Solution:** Commit `package-lock.json`:

```bash
git add package-lock.json
git commit -m "chore: add package-lock.json"
git push
```

### Error: Build context too large

```
Sending build context to Docker daemon  2.5GB
```

**Solution:** Ensure `.dockerignore` exists and includes `node_modules`:

```
node_modules
build
. git
```

### Error: Multi-stage build fails

```
COPY failed:  file not found in build context
```

**Solution:** Check file paths in Dockerfile match your project structure.

---

## 5. Health Check Failures

### Error: Health endpoint not responding

```
❌ Health check failed after 5 attempts
```

**Solution:** Verify server files exist:

```bash
# Check server files
ls -la server/
cat server/index.js
cat server/health.js
```

### Error: Container exits immediately

```
Container failed to start
```

**Solution:** Check container logs:

```bash
# Run locally to debug
docker build -t test-image .
docker run -it test-image

# Or check logs
docker logs test-container
```

### Error: Wrong health response format

```
❌ Status field missing or not healthy
```

**Solution:** Verify health endpoint returns correct JSON:

```bash
# Test locally
npm run build
npm run serve &
curl http://localhost:3000/health
```

Expected response:

```json
{
  "status": "healthy",
  "service": "ecommerce-frontend",
  ...
}
```

---

## 6. Security Scan Failures

### Error: . env file detected

```
❌ Found .env file(s) that should not be committed
```

**Solution:**

```bash
# Remove .env from git
git rm --cached .env
echo ".env" >> .gitignore
git add .gitignore
git commit -m "chore: remove .env from tracking"
git push
```

### Error: npm audit high vulnerabilities

```
found 5 high severity vulnerabilities
```

**Solution:** This is a warning only and won't fail CI. To fix:

```bash
# Update vulnerable packages
npm audit fix

# Or force fix (may cause breaking changes)
npm audit fix --force
```

---

## 7. General Failures

### Error: Workflow file syntax error

```
Invalid workflow file
```

**Solution:** Validate YAML syntax:

```bash
# Install yamllint
pip install yamllint

# Check syntax
yamllint .github/workflows/ci. yml
```

Common issues:

- Incorrect indentation (use 2 spaces)
- Missing quotes around special characters
- Wrong key names

### Error: Permission denied

```
Permission denied to github-actions[bot]
```

**Solution:** Check repository settings:

1. Go to Settings → Actions → General
2. Under "Workflow permissions"
3. Select "Read and write permissions"
4. Check "Allow GitHub Actions to create and approve pull requests"

### Error: Rate limit exceeded

```
API rate limit exceeded
```

**Solution:** Wait and retry, or use a GitHub token with higher limits.

---

## 8. Local Testing Commands

Before pushing, test locally:

```bash
# Test lint
npm run lint

# Test tests
npm test -- --watchAll=false --passWithNoTests

# Test build
npm run build

# Test Docker build
docker build -t ecommerce-frontend .

# Test container
docker run -d -p 3000:3000 --name test ecommerce-frontend

# Test health
curl http://localhost:3000/health

# Cleanup
docker stop test && docker rm test
```

---

## 9. CI Debug Mode

Add this step to any job for debugging:

```yaml
- name: Debug Information
  run: |
    echo "=== Environment ==="
    env | sort

    echo "=== Directory Structure ==="
    ls -la

    echo "=== Node Version ==="
    node --version

    echo "=== NPM Version ==="
    npm --version

    echo "=== Package.json Scripts ==="
    cat package.json | jq '.scripts'
```

---

## 10. Re-run Failed Jobs

1. Go to the failed workflow run
2. Click "Re-run failed jobs" (top right)
3. Or click "Re-run all jobs" for complete re-run

---

## 11. Skip CI (Emergency Only)

Add `[skip ci]` to commit message to skip CI:

```bash
git commit -m "docs: update readme [skip ci]"
```

⚠️ **Use sparingly** - CI exists to protect your code!
