# EC2 Provisioning Guide

## Overview

This document provides step-by-step instructions to provision an EC2 instance for the E-Commerce Frontend application.

---

## Prerequisites

- AWS Account with appropriate permissions
- AWS CLI configured (optional)
- SSH key pair for EC2 access

---

## 1. Launch EC2 Instance

### Step 1: Navigate to EC2 Dashboard

```
AWS Console → Services → EC2 → Launch Instance
```

### Step 2: Configure Instance

| Setting           | Value                                             |
| ----------------- | ------------------------------------------------- |
| **Name**          | `ecommerce-frontend-prod`                         |
| **AMI**           | Ubuntu Server 22.04 LTS (HVM), SSD Volume Type    |
| **Architecture**  | 64-bit (x86)                                      |
| **Instance Type** | `t2.micro` (Free Tier) or `t3.small` (Production) |

### Step 3: Key Pair

| Setting           | Value                                                |
| ----------------- | ---------------------------------------------------- |
| **Key pair name** | `ecommerce-frontend-key`                             |
| **Key pair type** | RSA                                                  |
| **Format**        | `.pem` (for Linux/Mac) or `.ppk` (for Windows/PuTTY) |

> ⚠️ **IMPORTANT:** Download and securely store the key pair. You cannot download it again.

### Step 4: Network Settings

| Setting                   | Value                                   |
| ------------------------- | --------------------------------------- |
| **VPC**                   | Default VPC                             |
| **Subnet**                | Default subnet (any AZ)                 |
| **Auto-assign Public IP** | Enable                                  |
| **Security Group**        | Create new (see Security Group section) |

### Step 5: Storage

| Setting                   | Value             |
| ------------------------- | ----------------- |
| **Size**                  | 20 GiB            |
| **Volume Type**           | gp3               |
| **IOPS**                  | 3000 (default)    |
| **Delete on termination** | Yes               |
| **Encrypted**             | Yes (recommended) |

### Step 6: Launch Instance

Click **"Launch Instance"** and wait for initialization.

---

## 2. Post-Launch Configuration

### Step 1: Note Instance Details

After launch, record the following:

```
Instance ID:       i-xxxxxxxxxxxxxxxxx
Public IPv4:      xx.xx.xx.xx
Private IPv4:     10.x.x.x
Availability Zone: us-east-1a (example)
```

### Step 2: Connect to Instance

```bash
# Set key permissions
chmod 400 ~/path/to/ecommerce-frontend-key.pem

# Connect via SSH
ssh -i ~/path/to/ecommerce-frontend-key.pem ubuntu@<PUBLIC_IP>
```

### Step 3: Update System

```bash
# Update package lists
sudo apt update

# Upgrade packages
sudo apt upgrade -y

# Install essential tools
sudo apt install -y curl wget git htop
```

### Step 4: Install Docker

```bash
# Install prerequisites
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common

# Add Docker GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Add user to docker group
sudo usermod -aG docker ubuntu

# Apply group changes
newgrp docker

# Verify installation
docker --version
```

### Step 5: Configure Firewall (UFW)

```bash
# Enable UFW
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw --force enable

# Verify
sudo ufw status
```

---

## 3. Instance Tagging

Apply these tags for resource management:

| Key           | Value                     |
| ------------- | ------------------------- |
| `Name`        | `ecommerce-frontend-prod` |
| `Environment` | `production`              |
| `Project`     | `ecommerce-frontend`      |
| `ManagedBy`   | `github-actions`          |
| `Owner`       | `your-team-name`          |

---

## 4. Elastic IP (Recommended for Production)

### Why?

- Public IP changes on instance stop/start
- Elastic IP remains constant

### Steps:

```
EC2 Dashboard → Elastic IPs → Allocate Elastic IP address
→ Allocate → Associate Elastic IP address
→ Select your instance → Associate
```

---

## 5. Instance Specifications Summary

### Development/Testing

| Resource | Specification      |
| -------- | ------------------ |
| Instance | t2.micro           |
| vCPU     | 1                  |
| Memory   | 1 GB               |
| Storage  | 20 GB gp3          |
| Cost     | Free Tier eligible |

### Production

| Resource | Specification |
| -------- | ------------- |
| Instance | t3.small      |
| vCPU     | 2             |
| Memory   | 2 GB          |
| Storage  | 30 GB gp3     |
| Cost     | ~$15/month    |

---

## 6. Verification Checklist

- [ ] EC2 instance running
- [ ] Public IP assigned
- [ ] SSH connection successful
- [ ] Docker installed and running
- [ ] User added to docker group
- [ ] Firewall configured
- [ ] Tags applied

---

## 7. Troubleshooting

### Cannot SSH to Instance

```bash
# Check key permissions
ls -la ~/path/to/key.pem
# Should be:  -r-------- (400)

# Fix permissions
chmod 400 ~/path/to/key.pem
```

### Docker Permission Denied

```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Logout and login again, or run:
newgrp docker
```

### Instance Not Reachable

1. Check Security Group allows inbound SSH (port 22)
2. Check instance is in "running" state
3. Verify you're using correct Public IP
4. Check Network ACLs in VPC

---

## Next Steps

After EC2 provisioning:

1. Configure IAM roles (see `IAM_ROLES.md`)
2. Setup Security Groups (see `SECURITY_GROUPS.md`)
3. Add GitHub Secrets for deployment
