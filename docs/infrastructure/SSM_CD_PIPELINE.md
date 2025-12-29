# SSM-Based CD Pipeline Guide

## Overview

This document describes the SSM-based CD pipeline that enables secure deployments without SSH access.

---

## 1. Architecture

```
GitHub Actions → AWS SSM → EC2 Instance
                  │
                  └── No SSH port required!
```

---

## 2. Prerequisites

| Requirement    | Description                                    |
| -------------- | ---------------------------------------------- |
| IAM User       | `github-actions-deployer` with SSM permissions |
| IAM Policy     | `GitHubActions-SSM-Deploy-Policy`              |
| EC2 IAM Role   | `AmazonSSMManagedInstanceCore`                 |
| SSM Agent      | Running on EC2                                 |
| GitHub Secrets | AWS credentials configured                     |

---

## 3. GitHub Secrets Required

| Secret                  | Description                  |
| ----------------------- | ---------------------------- |
| `AWS_ACCESS_KEY_ID`     | IAM user access key          |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret key          |
| `AWS_REGION`            | AWS region (e.g., us-east-1) |
| `EC2_INSTANCE_ID`       | EC2 instance ID              |
| `DOCKERHUB_USERNAME`    | DockerHub username           |
| `DOCKERHUB_TOKEN`       | DockerHub access token       |

---

## 4. Deployment Flow

1. Push to `main` branch triggers CD
2. Build and push Docker image to DockerHub
3. Send SSM command to EC2
4. EC2 runs Blue-Green deployment
5. Health check verification
6. Traffic switch

---

## 5. Security Benefits

| Feature               | Benefit                        |
| --------------------- | ------------------------------ |
| No SSH port           | Eliminates brute force attacks |
| IAM authentication    | Centralized access control     |
| CloudTrail logging    | Full audit trail               |
| No SSH keys in GitHub | Reduced secret exposure        |

---

## 6. Troubleshooting

### SSM Command Failed

```bash
# Check command output
aws ssm get-command-invocation \
  --command-id "COMMAND_ID" \
  --instance-id "INSTANCE_ID" \
  --query 'StandardErrorContent' \
  --output text
```

### Instance Not in SSM

1. Check SSM Agent is running
2. Verify IAM role is attached
3. Check instance has internet access
