# Blue-Green Deployment Guide

## Overview

Blue-Green deployment enables zero-downtime deployments by maintaining two identical environments (Blue and Green) and switching traffic between them. 

---

## 1. Architecture

```
                    NGINX (Port 443)
                         │
                         ▼
        ┌────────────────┴────────────────┐
        │                                 │
        ▼                                 ▼
   ┌─────────┐                       ┌─────────┐
   │  BLUE   │                       │  GREEN  │
   │  : 3001 │                       │  :3002  │
   │         │                       │         │
   │ ACTIVE  │                       │ STANDBY │
   └─────────┘                       └─────────┘
```

---

## 2. Port Assignments

| Environment | Container Name | Port | Status |
|-------------|----------------|------|--------|
| Blue | ecommerce-blue | 3001 | Active/Standby |
| Green | ecommerce-green | 3002 | Active/Standby |

---

## 3. Scripts

| Script | Purpose |
|--------|---------|
| `setup-blue-green. sh` | Initial setup (run once) |
| `deploy-blue-green.sh` | Deploy new version |
| `health-check.sh` | Check all endpoints |
| `rollback.sh` | Rollback to previous version |

---

## 4. Usage

### Deploy New Version

```bash
sudo ./deploy-blue-green.sh username/image:tag
```

### Check Health

```bash
./health-check.sh
```

### Rollback

```bash
sudo ./rollback.sh
```

---

## 5. Deployment Flow

1. Identify standby environment
2. Pull new Docker image
3. Deploy to standby container
4. Health check standby
5. Switch Nginx to standby
6. Verify production
7. Keep old container for rollback

---

## 6. State File

Location: `/var/lib/deployment/state. json`

```json
{
    "active": "blue",
    "blue_port": 3001,
    "green_port": 3002,
    "previous_active": "green",
    "last_deployment": "user/image:v1.2.0",
    "last_deployment_time":  "2025-12-28T10:00:00Z"
}
```

---

## 7. Health Endpoints

| Endpoint | Purpose |
|----------|---------|
| `/health` | Active backend health |
| `/blue-health` | Blue container health |
| `/green-health` | Green container health |
| `/nginx-health` | Nginx health |

---

## 8. Troubleshooting

### Deployment Failed

```bash
# Check container logs
docker logs ecommerce-blue
docker logs ecommerce-green

# Check deployment logs
ls -la /var/log/deployment/
```

### Rollback Failed

```bash
# Manually switch Nginx
sudo nano /etc/nginx/conf.d/active-backend.conf
# Change port to working container
sudo nginx -t && sudo systemctl reload nginx
```