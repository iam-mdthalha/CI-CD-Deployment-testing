# CI Quick Reference Card

## Trigger CI

| Method | How                               |
| ------ | --------------------------------- |
| PR     | Open/update PR to `main` or `dev` |
| Manual | Actions → ci → Run workflow       |

## Check Status

| Location  | URL                                                      |
| --------- | -------------------------------------------------------- |
| Actions   | github.com/iam-mdthalha/CI-CD-Deployment-testing/actions |
| PR Checks | Bottom of PR page                                        |

## Jobs (in order)

| Job           | Duration  | Blocks Merge |
| ------------- | --------- | ------------ |
| lint          | ~1. 5 min | ✅ Yes       |
| test          | ~2 min    | ✅ Yes       |
| build         | ~3 min    | ✅ Yes       |
| docker-build  | ~5 min    | ✅ Yes       |
| security-scan | ~1 min    | ⚠️ No        |
| ci-summary    | ~0.5 min  | ✅ Yes       |

## Local Testing

```bash
npm run lint          # Check lint
npm test              # Run tests
npm run build         # Build React
docker build -t app .  # Build Docker
```
