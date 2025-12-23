# Architecture & Guardrails Document

## 1. Infrastructure Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         AWS EC2 (Ubuntu)                            │
│                         Region: ap-south-1                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                 NGINX (HOST - NOT DOCKER)                   │    │
│  │                 Ports: 80, 443                              │    │
│  │                 SSL:  Certbot                               │    │
│  └─────────────────────┬───────────────────────────────────────┘    │
│                        │                                            │
│                        ▼                                            │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │              DOCKER NETWORK:  app-network                   │    │
│  │                                                             │    │
│  │   ┌──────────────────────┐    ┌──────────────────────┐      │    │
│  │   │  BLUE ENVIRONMENT    │    │  GREEN ENVIRONMENT   │      │    │
│  │   │                      │    │                      │      │    │
│  │   │  ecommerce-frontend  │    │  ecommerce-frontend  │      │    │
│  │   │  Port: 3001          │    │  Port: 3002          │      │    │
│  │   │                      │    │                      │      │    │
│  │   └──────────────────────┘    └──────────────────────┘      │    │
│  │                                                             │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘

Traffic Flow:
Internet → Nginx (80/443) → Active Environment (Blue OR Green) → Container
```

## 2. Service Registry

| Service            | Internal Port | Blue Port | Green Port | Subdomain (Future) | Health Endpoint |
| ------------------ | ------------- | --------- | ---------- | ------------------ | --------------- |
| ecommerce-frontend | 3000          | 3001      | 3002       | app.u-clo.com      | /health         |

## 3. Technology Stack

| Component         | Technology     | Version/Tag       |
| ----------------- | -------------- | ----------------- |
| OS                | Ubuntu         | 22.04 LTS         |
| Container Runtime | Docker         | Latest Stable     |
| Reverse Proxy     | Nginx          | Host Installation |
| SSL               | Certbot        | Latest            |
| CI/CD             | GitHub Actions | N/A               |
| Image Registry    | Docker Hub     | N/A               |
| Server Access     | AWS SSM        | N/A               |
| Frontend Runtime  | Node.js        | 20-alpine         |

## 4. Repository Information

| Field           | Value                    |
| --------------- | ------------------------ |
| GitHub Org/User | iam-mdthalha             |
| Repository      | CI-CD-Deployment-testing |
| Docker Hub User | jmdthalha                |
| AWS Region      | ap-south-1               |

## 5. Non-Negotiable Guardrails

### 5.1 Security Guardrails

- [ ] **G-SEC-01**: NO secrets in code — all secrets via `.env` files or GitHub Secrets
- [ ] **G-SEC-02**: NO SSH access — SSM only
- [ ] **G-SEC-03**: Security groups allow ONLY ports 80 and 443 from internet
- [ ] **G-SEC-04**: Docker Hub credentials stored in GitHub Secrets only
- [ ] **G-SEC-05**: No `latest` tag — all images version-tagged

### 5.2 Deployment Guardrails

- [ ] **G-DEP-01**: CI must pass before CD can run
- [ ] **G-DEP-02**: PR approval required before merge to main
- [ ] **G-DEP-03**: Blue-Green deployment mandatory — no in-place updates
- [ ] **G-DEP-04**: Health check must pass before traffic switch
- [ ] **G-DEP-05**: Previous version retained for instant rollback

### 5.3 Infrastructure Guardrails

- [ ] **G-INF-01**: Nginx runs on HOST — never in Docker
- [ ] **G-INF-02**: Single Docker network: `app-network`
- [ ] **G-INF-03**: All containers must have health checks
- [ ] **G-INF-04**: All services expose `/health` endpoint

## 6. Deployment Contracts

### Contract 1: Version Tagging

```
Format: {service}-{branch}-{short-sha}-{timestamp}
Example: ecommerce-frontend-main-a1b2c3d-20251223120000
```

### Contract 2: Blue-Green Port Mapping

```
Blue Environment:   Base Port + 1  (3000 → 3001)
Green Environment: Base Port + 2  (3000 → 3002)
```

### Contract 3: Traffic Switch Sequence

```
1. Pull new image
2. Start new container (inactive environment)
3. Wait for container healthy (30s timeout)
4. Health check:  curl http://localhost:{port}/health
5. If healthy:  switch Nginx upstream
6. If unhealthy: abort, keep current active
7. Keep old container running (for rollback)
```

### Contract 4: Rollback Sequence

```
1. Switch Nginx upstream back to previous environment
2. Reload Nginx
3. Verify health of previous environment
4. Done (rollback complete in <10 seconds)
```

## 7. Environment Files Contract

### Required GitHub Secrets

| Secret Name           | Description                     |
| --------------------- | ------------------------------- |
| DOCKERHUB_USERNAME    | Docker Hub username (jmdthalha) |
| DOCKERHUB_TOKEN       | Docker Hub access token         |
| AWS_ACCESS_KEY_ID     | AWS access key for SSM          |
| AWS_SECRET_ACCESS_KEY | AWS secret key for SSM          |
| AWS_REGION            | ap-south-1                      |
| EC2_INSTANCE_ID       | Target EC2 instance ID          |

### Server-Side . env File Location

```
/opt/app/.env
```

## 8. Rollback Rules

### Rule 1: Rollback is ALWAYS Simpler Than Deploy

| Action   | Steps | Time    |
| -------- | ----- | ------- |
| Deploy   | 7     | 2-5 min |
| Rollback | 2     | <10 sec |

### Rule 2: Rollback Triggers

- Health check fails after deployment
- Manual trigger by operator
- Error rate spike detected (future: monitoring)

### Rule 3: Rollback Does NOT Require

- New Docker pull
- New container start
- CI/CD pipeline run

### Rule 4: Rollback ONLY Requires

- Nginx upstream switch
- Nginx reload

## 9. Directory Structure Contract

```
/opt/app/                    # Application root
├── .env                     # Environment variables
├── docker-compose.yml       # Docker compose file
├── scripts/                 # Deployment scripts
│   ├── deploy.sh
│   ├── rollback.sh
│   ├── health-check.sh
│   └── switch-traffic.sh
└── state/                   # Deployment state
    └── active-environment   # Contains "blue" or "green"

/etc/nginx/                  # Nginx configuration
├── nginx.conf
├── sites-available/
│   └── app.conf
└── sites-enabled/
    └── app. conf -> ../sites-available/app.conf

/var/log/nginx/              # Nginx logs
├── access.log
└── error.log
```

## 10. CI/CD Pipeline Contract

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   PR Open   │────▶│  CI Runs    │────▶│  CI Pass?   │
└─────────────┘     └─────────────┘     └──────┬──────┘
                                               │
                         ┌─────────────────────┴─────────────────────┐
                         │                                           │
                         ▼                                           ▼
                   ┌───────────┐                               ┌───────────┐
                   │  CI Fail  │                               │  CI Pass  │
                   │  PR Block │                               │  Await    │
                   └───────────┘                               │  Approval │
                                                               └─────┬─────┘
                                                                     │
                                                                     ▼
                                                               ┌───────────┐
                                                               │ Approved? │
                                                               └─────┬─────┘
                                                                     │
                         ┌─────────────────────┴─────────────────────┐
                         │                                           │
                         ▼                                           ▼
                   ┌───────────┐                               ┌───────────┐
                   │  Reject   │                               │  Merge    │
                   │  PR Block │                               └─────┬─────┘
                   └───────────┘                                     │
                                                                     ▼
                                                               ┌───────────┐
                                                               │  CD Runs  │
                                                               │  Deploy   │
                                                               └───────────┘
```

## 11. Health Check Contract

### Endpoint Specification

```
Path:      /health
Method:   GET
Response: 200 OK
Body:     { "status": "healthy", "service": "{service-name}", "version": "{version}" }
```

### Health Check Timing

| Parameter     | Value |
| ------------- | ----- |
| Initial Delay | 10s   |
| Interval      | 30s   |
| Timeout       | 5s    |
| Retries       | 3     |
| Start Period  | 30s   |

## 12. Future-Ready Placeholders (NOT ACTIVE)

The following are documented for future implementation:

- Terraform for infrastructure as code
- Ansible for configuration management
- Kubernetes for container orchestration
- Prometheus for metrics
- Grafana for dashboards
- AlertManager for alerting

**These are NOT implemented in this project.**

## 13. Notification Contract

| Event                | Notification Target              |
| -------------------- | -------------------------------- |
| PR Opened            | iam. alphabit.notifier@gmail.com |
| PR Approved          | iam. alphabit.notifier@gmail.com |
| CI Failed            | iam.alphabit.notifier@gmail.com  |
| Deployment Started   | iam. alphabit.notifier@gmail.com |
| Deployment Succeeded | iam.alphabit.notifier@gmail.com  |
| Deployment Failed    | iam. alphabit.notifier@gmail.com |
| Rollback Triggered   | iam. alphabit.notifier@gmail.com |

## 14. Approvers

| GitHub Username | Role              |
| --------------- | ----------------- |
| iam-mdthalha    | Required Approver |
