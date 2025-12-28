# Security Groups Configuration Guide

## Overview

This document defines security group rules for the E-Commerce Frontend infrastructure following AWS security best practices.

---

## 1. Security Groups Summary

| Security Group          | Purpose                | Attached To      |
| ----------------------- | ---------------------- | ---------------- |
| `ecommerce-sg-public`   | Public web traffic     | EC2 (Production) |
| `ecommerce-sg-admin`    | Administrative access  | EC2 (SSH access) |
| `ecommerce-sg-internal` | Internal communication | Future services  |

---

## 2. Production Security Group

### Name: `ecommerce-sg-public`

### Purpose

Allow public web traffic (HTTP/HTTPS) to the application.

### Inbound Rules (Production - Strict)

| Type  | Protocol | Port | Source    | Description        |
| ----- | -------- | ---- | --------- | ------------------ |
| HTTP  | TCP      | 80   | 0.0.0.0/0 | Public web traffic |
| HTTPS | TCP      | 443  | 0.0.0.0/0 | Secure web traffic |

### Outbound Rules

| Type        | Protocol | Port | Destination | Description        |
| ----------- | -------- | ---- | ----------- | ------------------ |
| All traffic | All      | All  | 0.0.0.0/0   | Allow all outbound |

### Create via AWS Console

```
EC2 Dashboard → Security Groups → Create security group
```

| Setting                 | Value                                      |
| ----------------------- | ------------------------------------------ |
| **Security group name** | `ecommerce-sg-public`                      |
| **Description**         | Public web traffic for E-Commerce Frontend |
| **VPC**                 | Default VPC                                |

### Create via AWS CLI

```bash
# Create security group
aws ec2 create-security-group \
    --group-name ecommerce-sg-public \
    --description "Public web traffic for E-Commerce Frontend" \
    --vpc-id vpc-xxxxxxxx

# Add HTTP rule
aws ec2 authorize-security-group-ingress \
    --group-name ecommerce-sg-public \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0

# Add HTTPS rule
aws ec2 authorize-security-group-ingress \
    --group-name ecommerce-sg-public \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0
```

---

## 3. Admin Security Group

### Name: `ecommerce-sg-admin`

### Purpose

Restrict SSH access to authorized IP addresses only.

### Inbound Rules

| Type | Protocol | Port | Source            | Description      |
| ---- | -------- | ---- | ----------------- | ---------------- |
| SSH  | TCP      | 22   | YOUR_IP/32        | Admin SSH access |
| SSH  | TCP      | 22   | GITHUB_ACTIONS_IP | CI/CD deployment |

### GitHub Actions IP Ranges

GitHub Actions uses dynamic IPs. Options:

**Option A: Allow GitHub Actions IPs (Recommended)**

```bash
# Get GitHub Actions IP ranges
curl -s https://api.github.com/meta | jq '.actions'
```

**Option B: Use GitHub Self-Hosted Runner**

- Run GitHub Actions runner on your own infrastructure
- More control over IP addresses

**Option C: Use AWS Systems Manager (No SSH needed)**

- No inbound SSH required
- More secure approach

### Create via AWS Console

```
EC2 Dashboard → Security Groups → Create security group
```

| Setting                 | Value                                    |
| ----------------------- | ---------------------------------------- |
| **Security group name** | `ecommerce-sg-admin`                     |
| **Description**         | Admin SSH access for E-Commerce Frontend |
| **VPC**                 | Default VPC                              |

### Create via AWS CLI

```bash
# Create security group
aws ec2 create-security-group \
    --group-name ecommerce-sg-admin \
    --description "Admin SSH access for E-Commerce Frontend" \
    --vpc-id vpc-xxxxxxxx

# Add SSH rule (replace YOUR_IP)
aws ec2 authorize-security-group-ingress \
    --group-name ecommerce-sg-admin \
    --protocol tcp \
    --port 22 \
    --cidr YOUR_IP/32
```

---

## 4. Development Security Group (Non-Production)

### Name: `ecommerce-sg-dev`

### Purpose

Additional ports for development/testing (NOT for production).

### Inbound Rules (Development Only)

| Type   | Protocol | Port | Source     | Description            |
| ------ | -------- | ---- | ---------- | ---------------------- |
| HTTP   | TCP      | 80   | 0.0.0.0/0  | Web traffic            |
| HTTPS  | TCP      | 443  | 0.0.0.0/0  | Secure web traffic     |
| SSH    | TCP      | 22   | YOUR_IP/32 | Admin access           |
| Custom | TCP      | 3000 | 0.0.0.0/0  | Node.js app (dev only) |
| Custom | TCP      | 3001 | YOUR_IP/32 | Blue container (dev)   |
| Custom | TCP      | 3002 | YOUR_IP/32 | Green container (dev)  |

> ⚠️ **WARNING:** Do NOT use this in production. Expose only 80/443.

---

## 5. Security Group Rules Matrix

### Production Environment

```
┌─────────────────────────────────────────────────────────────────┐
│                    PRODUCTION RULES                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  INBOUND:                                                       │
│  ┌────────┬──────────┬────────┬─────────────┬─────────────────┐ │
│  │ Type   │ Protocol │ Port   │ Source      │ Status          │ │
│  ├────────┼──────────┼────────┼─────────────┼─────────────────┤ │
│  │ HTTP   │ TCP      │ 80     │ 0.0.0.0/0   │ ✅ REQUIRED     │ │
│  │ HTTPS  │ TCP      │ 443    │ 0.0.0.0/0   │ ✅ REQUIRED     │ │
│  │ SSH    │ TCP      │ 22     │ Admin IP    │ ✅ RESTRICTED   │ │
│  │ Custom │ TCP      │ 3000   │ 0.0.0.0/0   │ ❌ REMOVE       │ │
│  └────────┴──────────┴────────┴─────────────┴─────────────────┘ │
│                                                                 │
│  OUTBOUND:                                                      │
│  ┌────────┬──────────┬────────┬─────────────┬─────────────────┐ │
│  │ Type   │ Protocol │ Port   │ Destination │ Status          │ │
│  ├────────┼──────────┼────────┼─────────────┼─────────────────┤ │
│  │ All    │ All      │ All    │ 0.0.0.0/0   │ ✅ ALLOW        │ │
│  └────────┴──────────┴────────┴─────────────┴─────────────────┘ │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 6. Applying Security Groups to EC2

### Via AWS Console

```
EC2 Dashboard → Instances → Select Instance
→ Actions → Security → Change security groups
→ Select security groups → Save
```

### Via AWS CLI

```bash
# Apply security groups to instance
aws ec2 modify-instance-attribute \
    --instance-id i-xxxxxxxxxxxxxxxxx \
    --groups sg-xxxxxxxx sg-yyyyyyyy
```

### Multiple Security Groups

You can attach multiple security groups to one EC2:

```
EC2 Instance
├── ecommerce-sg-public   (HTTP/HTTPS)
└── ecommerce-sg-admin    (SSH)
```

Rules from all groups are combined (union).

---

## 7. Security Best Practices

### ✅ DO

| Practice                        | Reason                      |
| ------------------------------- | --------------------------- |
| Use specific IP ranges for SSH  | Prevent unauthorized access |
| Remove port 3000 in production  | Use Nginx reverse proxy     |
| Use HTTPS (443) in production   | Encrypted traffic           |
| Regularly audit security groups | Remove unused rules         |
| Use descriptive names           | Easy identification         |
| Tag security groups             | Resource management         |

### ❌ DON'T

| Anti-Pattern                 | Risk                     |
| ---------------------------- | ------------------------ |
| Open SSH (22) to 0.0.0.0/0   | Brute force attacks      |
| Open database ports publicly | Data breach              |
| Use default security group   | Over-permissive          |
| Keep unused rules            | Increased attack surface |
| Open application port (3000) | Bypass Nginx security    |

---

## 8. Port Reference

| Port | Service         | Production    | Development   |
| ---- | --------------- | ------------- | ------------- |
| 22   | SSH             | Restricted IP | Restricted IP |
| 80   | HTTP            | ✅ Open       | ✅ Open       |
| 443  | HTTPS           | ✅ Open       | ✅ Open       |
| 3000 | Node.js App     | ❌ Closed     | ⚠️ Optional   |
| 3001 | Blue Container  | ❌ Closed     | ⚠️ Optional   |
| 3002 | Green Container | ❌ Closed     | ⚠️ Optional   |

---

## 9. Transitioning to Production

### Current Setup (Development)

```
Internet → : 3000 → Node.js App
```

### Production Setup (Recommended)

```
Internet → :80/: 443 → Nginx → :3000 → Node.js App
```

### Steps to Transition

1. Install Nginx on EC2
2. Configure Nginx reverse proxy
3. Remove port 3000 from security group
4. Test via port 80/443
5. Setup SSL certificate (Let's Encrypt)

---

## 10. Nginx Configuration (Preview)

This will be covered in Stage 6, but here's a preview:

```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_cache_bypass $http_upgrade;
    }
}
```

---

## 11. Security Group Tags

Apply these tags for management:

| Key           | Value                 |
| ------------- | --------------------- |
| `Name`        | `ecommerce-sg-public` |
| `Environment` | `production`          |
| `Project`     | `ecommerce-frontend`  |
| `ManagedBy`   | `manual`              |

---

## 12. Verification Checklist

- [ ] Production security group created
- [ ] HTTP (80) rule added
- [ ] HTTPS (443) rule added
- [ ] SSH (22) restricted to admin IP
- [ ] Port 3000 removed for production
- [ ] Security groups attached to EC2
- [ ] Tags applied
- [ ] Tested connectivity

---

## 13. Troubleshooting

### Cannot Access Website

```bash
# Check security group rules
aws ec2 describe-security-groups --group-names ecommerce-sg-public

# Verify port 80/443 is open
# Check instance is running
# Verify Nginx is running (if using)
```

### SSH Connection Timeout

```bash
# Verify your current IP
curl ifconfig.me

# Check if IP matches security group rule
# Update rule if IP changed
```

### Port 3000 Not Accessible (Production)

This is expected! Use port 80/443 through Nginx.

---

## 14. Quick Commands Reference

```bash
# List all security groups
aws ec2 describe-security-groups --query 'SecurityGroups[*].[GroupName,GroupId]' --output table

# Get rules for specific group
aws ec2 describe-security-groups --group-names ecommerce-sg-public

# Add rule
aws ec2 authorize-security-group-ingress \
    --group-name ecommerce-sg-public \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0

# Remove rule
aws ec2 revoke-security-group-ingress \
    --group-name ecommerce-sg-public \
    --protocol tcp \
    --port 3000 \
    --cidr 0.0.0.0/0
```

---

## Next Steps

After security group setup:

1. Proceed to Stage 6 (Blue-Green Deployment)
2. Install and configure Nginx
3. Setup SSL/TLS certificates
4. Remove port 3000 from security group
