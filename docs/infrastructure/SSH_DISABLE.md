# Disable SSH & Secure Access Guide

## Overview

This document provides instructions to disable SSH access and rely solely on AWS Systems Manager (SSM) for server access.

---

## Prerequisites

Before disabling SSH, ensure:

- [ ] SSM Agent is running on EC2
- [ ] IAM Role with `AmazonSSMManagedInstanceCore` attached
- [ ] Instance visible in Systems Manager → Fleet Manager
- [ ] Successfully tested SSM session connection

---

## Why Disable SSH?

| Risk                | With SSH Open   | With SSH Disabled     |
| ------------------- | --------------- | --------------------- |
| Brute force attacks | ❌ Vulnerable   | ✅ Protected          |
| Key management      | ❌ Complex      | ✅ Not needed         |
| Audit trail         | ❌ Limited      | ✅ Full CloudTrail    |
| Port exposure       | ❌ Port 22 open | ✅ No ports for admin |

---

## Disable SSH Steps

### Step 1: Verify SSM Works

```bash
# Via AWS CLI
aws ssm start-session --target i-xxxxxxxxxxxxxxxxx

# Or via AWS Console
# Systems Manager → Session Manager → Start session
```

### Step 2: Disable SSH Service

```bash
# Stop SSH
sudo systemctl stop ssh

# Disable on boot
sudo systemctl disable ssh

# Verify
sudo systemctl status ssh
```

### Step 3: Block in Firewall

```bash
# Remove UFW rule
sudo ufw delete allow 22/tcp

# Verify
sudo ufw status
```

### Step 4: Remove from Security Group

```
AWS Console → EC2 → Security Groups
→ Edit inbound rules → Delete port 22 rule → Save
```

---

## Emergency SSH Re-enable

If you need SSH access again (via SSM session):

```bash
# Run the emergency script
/home/ubuntu/enable-ssh. sh

# Or manually:
sudo systemctl start ssh
sudo systemctl enable ssh
sudo ufw allow 22/tcp
```

Then add port 22 back to Security Group.

---

## Verification

### SSH Should Fail

```bash
ssh -i key.pem ubuntu@EC2_IP -o ConnectTimeout=5
# Expected: Connection timed out
```

### SSM Should Work

```bash
aws ssm start-session --target i-xxxxxxxxxxxxxxxxx
# Expected: Terminal session opens
```

---

## Access Methods After Hardening

| Method              | Status       | Use Case       |
| ------------------- | ------------ | -------------- |
| SSH (Port 22)       | ❌ Disabled  | Not available  |
| SSM Session Manager | ✅ Enabled   | Admin access   |
| SSM Run Command     | ✅ Enabled   | Automation     |
| AWS Console         | ✅ Available | EC2 management |

---

## Security Group Rules (Final)

| Type  | Port | Source    | Status     |
| ----- | ---- | --------- | ---------- |
| HTTP  | 80   | 0.0.0.0/0 | ✅ Open    |
| HTTPS | 443  | 0.0.0.0/0 | ✅ Open    |
| SSH   | 22   | Any       | ❌ Removed |

---

## Troubleshooting

### Lost Access to Instance

1. Go to AWS Console → EC2 → Instance
2. Use EC2 Serial Console (if enabled)
3. Or create AMI → Launch new instance with SSH enabled

### SSM Session Not Working

1. Check IAM role is attached
2. Verify SSM Agent is running
3. Check instance has outbound internet access
4. Verify instance appears in Fleet Manager

---

## Rollback Plan

If needed, re-enable SSH:

```bash
# Via SSM session
/home/ubuntu/enable-ssh. sh

# Then in AWS Console
# Add port 22 to Security Group inbound rules
```
