# Post-Deployment Validation & Rollback Guide

## Overview

This document describes the validation process after deployment and rollback procedures if issues are detected.

---

## 1. Validation Script

### Location

```
/usr/local/bin/validate-deployment.sh
```

### Usage

```bash
sudo /usr/local/bin/validate-deployment.sh
```

### Checks Performed

| Check             | Description                            |
| ----------------- | -------------------------------------- |
| Deployment State  | Verify state file exists and is valid  |
| Docker Containers | Check containers are running           |
| Health Endpoints  | Test /health endpoints                 |
| Nginx Status      | Verify Nginx is running and configured |
| Response Time     | Measure endpoint response time         |
| Error Logs        | Check for errors in logs               |
| Disk Space        | Verify sufficient disk space           |
| SSL Certificate   | Check certificate validity             |

### Output

```
✅ PASS - Check passed
❌ FAIL - Check failed (critical)
⚠️ WARN - Warning (non-critical)
```

---

## 2. Rollback Script

### Location

```
/usr/local/bin/rollback.sh
```

### Usage

```bash
# Interactive rollback (with confirmation)
sudo /usr/local/bin/rollback.sh

# Force rollback (no confirmation)
sudo /usr/local/bin/rollback.sh --force
```

### What It Does

1. Checks previous version is healthy
2. Updates Nginx to point to previous version
3. Reloads Nginx
4. Updates state file
5. Verifies rollback was successful

---

## 3. Image Cleanup

### Location

```
/usr/local/bin/cleanup-images.sh
```

### Usage

```bash
# Dry run (see what would be deleted)
sudo /usr/local/bin/cleanup-images.sh --dry-run

# Actual cleanup
sudo /usr/local/bin/cleanup-images.sh
```

### Retention Policy

- Keeps latest 3 images
- Removes older images
- Cleans up dangling images

---

## 4. Validation Checklist (Manual)

### Pre-Deployment

- [ ] Backup current state file
- [ ] Note current active environment
- [ ] Verify standby container is stopped

### Post-Deployment

- [ ] Health endpoint returns 200
- [ ] Response time < 500ms
- [ ] No errors in container logs
- [ ] Nginx config is valid
- [ ] SSL certificate is valid
- [ ] Disk space > 20% free

### Rollback Decision Matrix

| Condition             | Action                         |
| --------------------- | ------------------------------ |
| Health check fails    | Rollback immediately           |
| Response time > 2s    | Investigate, consider rollback |
| Error rate > 5%       | Rollback immediately           |
| Partial functionality | Investigate, then decide       |

---

## 5. Quick Commands

```bash
# Validate deployment
sudo /usr/local/bin/validate-deployment. sh

# Rollback to previous version
sudo /usr/local/bin/rollback.sh

# Check container status
docker ps | grep ecommerce

# Check current active environment
cat /var/lib/deployment/state.json

# View deployment logs
ls -la /var/log/deployment/

# Cleanup old images
sudo /usr/local/bin/cleanup-images.sh --dry-run
```

---

## 6. Troubleshooting

### Validation Failed

```bash
# Check detailed logs
cat /var/log/deployment/validation-*. log | tail -50

# Check container logs
docker logs ecommerce-blue --tail 50
docker logs ecommerce-green --tail 50
```

### Rollback Failed

```bash
# Manual Nginx switch
sudo nano /etc/nginx/conf.d/active-backend.conf
# Change port to working container (3001 or 3002)
sudo nginx -t && sudo systemctl reload nginx
```

### Container Not Starting

```bash
# Check container logs
docker logs ecommerce-blue 2>&1 | tail -50

# Check if port is in use
sudo lsof -i : 3001
sudo lsof -i :3002
```
