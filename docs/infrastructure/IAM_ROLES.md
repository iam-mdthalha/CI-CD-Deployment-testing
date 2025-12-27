# IAM Roles & Policies Guide

## Overview

This document defines IAM roles, policies, and permissions required for the E-Commerce Frontend CI/CD pipeline.

---

## 1. IAM Roles Summary

| Role Name                 | Attached To         | Purpose                          |
| ------------------------- | ------------------- | -------------------------------- |
| `EC2-ECommerce-Role`      | EC2 Instance        | Allow EC2 to access AWS services |
| `github-actions-deployer` | IAM User (Optional) | CI/CD pipeline access            |

---

## 2. EC2 Instance Role

### Role Name: `EC2-ECommerce-Role`

### Purpose

Allow EC2 instance to:

- Pull images from ECR (if used)
- Send logs to CloudWatch
- Use Systems Manager for management

### Step 1: Create IAM Role

```
AWS Console → IAM → Roles → Create role
```

| Setting                 | Value       |
| ----------------------- | ----------- |
| **Trusted entity type** | AWS service |
| **Use case**            | EC2         |

### Step 2: Attach Policies

| Policy Name                          | Purpose                    |
| ------------------------------------ | -------------------------- |
| `AmazonSSMManagedInstanceCore`       | Systems Manager access     |
| `CloudWatchAgentServerPolicy`        | CloudWatch logging         |
| `AmazonEC2ContainerRegistryReadOnly` | ECR pull access (optional) |

### Step 3: Role Details

| Setting         | Value                                          |
| --------------- | ---------------------------------------------- |
| **Role name**   | `EC2-ECommerce-Role`                           |
| **Description** | IAM role for E-Commerce Frontend EC2 instances |

### Step 4: Attach Role to EC2

```
EC2 Dashboard → Select Instance → Actions → Security → Modify IAM role
→ Select "EC2-ECommerce-Role" → Update IAM role
```

---

## 3. Custom Policy: EC2 ECommerce Policy

### Policy Name: `EC2-ECommerce-Policy`

### Policy Document (JSON)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "CloudWatchLogs",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams"
      ],
      "Resource": ["arn:aws:logs:*:*:log-group:/ecommerce/*"]
    },
    {
      "Sid": "CloudWatchMetrics",
      "Effect": "Allow",
      "Action": [
        "cloudwatch:PutMetricData",
        "cloudwatch:GetMetricStatistics",
        "cloudwatch:ListMetrics"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "cloudwatch:namespace": "ECommerce/Frontend"
        }
      }
    },
    {
      "Sid": "ECRPull",
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr: GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ],
      "Resource": "*"
    },
    {
      "Sid": "SSMAccess",
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter",
        "ssm:GetParameters",
        "ssm: GetParametersByPath"
      ],
      "Resource": ["arn:aws:ssm:*:*:parameter/ecommerce/*"]
    }
  ]
}
```

### Create Custom Policy

```
IAM → Policies → Create policy → JSON tab → Paste above → Next
→ Policy name:  EC2-ECommerce-Policy → Create policy
```

---

## 4. GitHub Actions IAM User (Optional)

> **Note:** Our current setup uses SSH keys stored in GitHub Secrets.
> This IAM user is optional and only needed if using AWS CLI in workflows.

### User Name: `github-actions-deployer`

### Step 1: Create IAM User

```
IAM → Users → Add users
```

| Setting         | Value                     |
| --------------- | ------------------------- |
| **User name**   | `github-actions-deployer` |
| **Access type** | Programmatic access only  |

### Step 2: Create Access Keys

```
IAM → Users → github-actions-deployer → Security credentials
→ Create access key → Application running outside AWS
→ Create → Download .csv file
```

### Step 3: Attach Policy

#### Policy Name: `GitHubActionsDeployerPolicy`

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ECRAccess",
      "Effect": "Allow",
      "Action": [
        "ecr: GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr: InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "*"
    },
    {
      "Sid": "EC2Describe",
      "Effect": "Allow",
      "Action": ["ec2:DescribeInstances", "ec2:DescribeInstanceStatus"],
      "Resource": "*"
    }
  ]
}
```

### Step 4: Store in GitHub Secrets (If Using)

| Secret Name             | Value                     |
| ----------------------- | ------------------------- |
| `AWS_ACCESS_KEY_ID`     | From downloaded CSV       |
| `AWS_SECRET_ACCESS_KEY` | From downloaded CSV       |
| `AWS_REGION`            | `us-east-1` (your region) |

---

## 5. Trust Relationships

### EC2 Role Trust Policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

---

## 6. Security Best Practices

### ✅ DO

| Practice                           | Reason                          |
| ---------------------------------- | ------------------------------- |
| Use IAM roles for EC2              | No hardcoded credentials        |
| Principle of least privilege       | Grant only required permissions |
| Use resource-level permissions     | Restrict to specific resources  |
| Enable MFA for IAM users           | Additional security layer       |
| Rotate access keys regularly       | Reduce exposure window          |
| Use GitHub Secrets for credentials | Never commit credentials        |

### ❌ DON'T

| Anti-Pattern              | Risk                  |
| ------------------------- | --------------------- |
| Use root account          | Full account access   |
| Hardcode credentials      | Exposed in code       |
| Use `*` for all resources | Over-permissive       |
| Share access keys         | Accountability issues |
| Skip key rotation         | Long-term exposure    |

---

## 7. IAM Permissions Summary

### EC2 Instance Permissions

```
┌─────────────────────────────────────────────────────────────────┐
│  EC2-ECommerce-Role Permissions                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  CloudWatch:                                                    │
│  ├── logs:CreateLogGroup              ✅                        │
│  ├── logs:CreateLogStream             ✅                        │
│  ├── logs:PutLogEvents                ✅                        │
│  └── cloudwatch:PutMetricData         ✅                        │
│                                                                 │
│  ECR (Optional):                                                │
│  ├── ecr:GetAuthorizationToken        ✅                        │
│  ├── ecr:BatchGetImage                ✅                        │
│  └── ecr:GetDownloadUrlForLayer       ✅                        │
│                                                                 │
│  SSM:                                                           │
│  ├── ssm:GetParameter                 ✅                        │
│  └── ssm:GetParameters                ✅                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 8. Verification Checklist

- [ ] EC2 IAM role created (`EC2-ECommerce-Role`)
- [ ] Custom policy created (`EC2-ECommerce-Policy`)
- [ ] Role attached to EC2 instance
- [ ] GitHub Actions user created (optional)
- [ ] Access keys stored in GitHub Secrets (optional)
- [ ] Trust relationships configured
- [ ] Tested permissions work correctly

---

## 9. Troubleshooting

### "Access Denied" Errors

```bash
# Check attached role on EC2
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/

# Should return role name if attached
```

### Role Not Showing in EC2

1. Verify role has EC2 trust relationship
2. Check role is created in same region
3. Try refreshing EC2 console

### CloudWatch Logs Not Working

1. Verify CloudWatch agent installed
2. Check policy includes `logs:*` permissions
3. Verify log group name matches policy resource

---

## Next Steps

After IAM setup:

1. Configure Security Groups (see `SECURITY_GROUPS.md`)
2. Test deployment pipeline
3. Verify CloudWatch logging works
