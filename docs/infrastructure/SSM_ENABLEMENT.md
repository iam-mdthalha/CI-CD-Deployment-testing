# AWS Systems Manager (SSM) Enablement Guide

## Overview

This document provides instructions to enable AWS Systems Manager Session Manager for secure, SSH-free access to EC2 instances.

---

## 1. Prerequisites

| Requirement     | Description                             |
| --------------- | --------------------------------------- |
| IAM Role        | EC2 instance must have SSM permissions  |
| SSM Agent       | Must be installed and running           |
| Outbound Access | Instance needs internet or VPC endpoint |
| AWS CLI v2      | Required for local Session Manager      |

---

## 2. Step 1: Create IAM Role for SSM

### Option A: Use AWS Managed Policy (Recommended)

#### Create Role via Console

```
IAM → Roles → Create role
```

| Setting            | Value                          |
| ------------------ | ------------------------------ |
| **Trusted entity** | AWS service                    |
| **Use case**       | EC2                            |
| **Policy**         | `AmazonSSMManagedInstanceCore` |
| **Role name**      | `EC2-SSM-Role`                 |

#### Policy: `AmazonSSMManagedInstanceCore`

This AWS managed policy includes:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm: DescribeAssociation",
        "ssm:GetDeployablePatchSnapshotForInstance",
        "ssm:GetDocument",
        "ssm: DescribeDocument",
        "ssm:GetManifest",
        "ssm:GetParameter",
        "ssm:GetParameters",
        "ssm:ListAssociations",
        "ssm:ListInstanceAssociations",
        "ssm:PutInventory",
        "ssm: PutComplianceItems",
        "ssm:PutConfigurePackageResult",
        "ssm:UpdateAssociationStatus",
        "ssm:UpdateInstanceAssociationStatus",
        "ssm: UpdateInstanceInformation"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ssmmessages:CreateControlChannel",
        "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel",
        "ssmmessages:OpenDataChannel"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2messages:AcknowledgeMessage",
        "ec2messages:DeleteMessage",
        "ec2messages:FailMessage",
        "ec2messages:GetEndpoint",
        "ec2messages:GetMessages",
        "ec2messages:SendReply"
      ],
      "Resource": "*"
    }
  ]
}
```

### Option B: Create Custom Policy

#### Policy Name: `EC2-SSM-Custom-Policy`

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "SSMCorePermissions",
      "Effect": "Allow",
      "Action": [
        "ssm:UpdateInstanceInformation",
        "ssmmessages:CreateControlChannel",
        "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel",
        "ssmmessages:OpenDataChannel",
        "ec2messages:AcknowledgeMessage",
        "ec2messages:DeleteMessage",
        "ec2messages:FailMessage",
        "ec2messages:GetEndpoint",
        "ec2messages:GetMessages",
        "ec2messages:SendReply"
      ],
      "Resource": "*"
    },
    {
      "Sid": "SSMSessionLogging",
      "Effect": "Allow",
      "Action": ["s3:PutObject", "s3:GetEncryptionConfiguration"],
      "Resource": [
        "arn:aws:s3:::your-ssm-logs-bucket/*",
        "arn:aws:s3:::your-ssm-logs-bucket"
      ]
    },
    {
      "Sid": "CloudWatchLogging",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ],
      "Resource": "*"
    }
  ]
}
```

---

## 3. Step 2: Attach IAM Role to EC2

### Via AWS Console

```
EC2 Dashboard → Instances → Select your instance
→ Actions → Security → Modify IAM role
→ Select "EC2-SSM-Role" → Update IAM role
```

### Via AWS CLI

```bash
# Create instance profile (if not exists)
aws iam create-instance-profile --instance-profile-name EC2-SSM-Profile

# Add role to instance profile
aws iam add-role-to-instance-profile \
    --instance-profile-name EC2-SSM-Profile \
    --role-name EC2-SSM-Role

# Attach to EC2 instance
aws ec2 associate-iam-instance-profile \
    --instance-id i-xxxxxxxxxxxxxxxxx \
    --iam-instance-profile Name=EC2-SSM-Profile
```

---

## 4. Step 3: Verify SSM Agent

### Check if SSM Agent is Installed

Ubuntu 22.04 comes with SSM Agent pre-installed. Verify:

```bash
# SSH into instance (temporarily, before disabling SSH)
ssh -i your-key.pem ubuntu@YOUR_EC2_IP

# Check SSM Agent status
sudo systemctl status snap.amazon-ssm-agent. amazon-ssm-agent. service

# Or on older systems
sudo systemctl status amazon-ssm-agent
```

### Expected Output

```
● snap.amazon-ssm-agent. amazon-ssm-agent.service - Service for snap application amazon-ssm-agent
     Loaded: loaded
     Active: active (running)
```

### If Not Installed

```bash
# Install SSM Agent on Ubuntu
sudo snap install amazon-ssm-agent --classic

# Start the agent
sudo systemctl start snap.amazon-ssm-agent. amazon-ssm-agent.service

# Enable on boot
sudo systemctl enable snap. amazon-ssm-agent.amazon-ssm-agent.service
```

### Manual Installation (Alternative)

```bash
# Download SSM Agent
wget https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_amd64/amazon-ssm-agent. deb

# Install
sudo dpkg -i amazon-ssm-agent.deb

# Start
sudo systemctl start amazon-ssm-agent
sudo systemctl enable amazon-ssm-agent
```

---

## 5. Step 4: Verify Instance in SSM

### Via AWS Console

```
AWS Console → Systems Manager → Fleet Manager
```

Your instance should appear in the managed instances list.

### Via AWS CLI

```bash
# List managed instances
aws ssm describe-instance-information --query 'InstanceInformationList[*].[InstanceId,PingStatus,AgentVersion]' --output table
```

### Expected Output

```
-------------------------------------------------
|          DescribeInstanceInformation          |
+----------------------+----------+-------------+
|  i-xxxxxxxxxxxxxxxxx |  Online  |  3.2.x. x    |
+----------------------+----------+-------------+
```

---

## 6. Step 5: Connect via Session Manager

### Option A: AWS Console

```
Systems Manager → Session Manager → Start session
→ Select your instance → Start session
```

A browser-based terminal opens.

### Option B: AWS CLI

```bash
# Install Session Manager plugin (one-time setup)
# For Ubuntu/Debian
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb"
sudo dpkg -i session-manager-plugin.deb

# Start session
aws ssm start-session --target i-xxxxxxxxxxxxxxxxx
```

### Option C: SSH over SSM (Hybrid)

```bash
# Add to ~/.ssh/config
Host i-* mi-*
    ProxyCommand sh -c "aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters 'portNumber=%p'"

# Then SSH normally (still uses SSM tunnel)
ssh -i your-key.pem ubuntu@i-xxxxxxxxxxxxxxxxx
```

---

## 7. Step 6: Enable Session Logging (Recommended)

### Create S3 Bucket for Logs

```bash
# Create bucket
aws s3 mb s3://ecommerce-ssm-logs-YOUR_ACCOUNT_ID --region us-east-1

# Enable encryption
aws s3api put-bucket-encryption \
    --bucket ecommerce-ssm-logs-YOUR_ACCOUNT_ID \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            }
        }]
    }'
```

### Configure Session Manager Preferences

```
Systems Manager → Session Manager → Preferences → Edit
```

| Setting                | Value                                |
| ---------------------- | ------------------------------------ |
| **S3 bucket**          | `ecommerce-ssm-logs-YOUR_ACCOUNT_ID` |
| **S3 key prefix**      | `sessions/`                          |
| **CloudWatch logging** | Enable                               |
| **Log group**          | `/ssm/sessions`                      |

### Via AWS CLI

```bash
aws ssm update-document \
    --name "SSM-SessionManagerRunShell" \
    --document-version '$LATEST' \
    --content '{
        "schemaVersion":  "1.0",
        "description": "Session Manager Settings",
        "sessionType": "Standard_Stream",
        "inputs": {
            "s3BucketName": "ecommerce-ssm-logs-YOUR_ACCOUNT_ID",
            "s3KeyPrefix": "sessions/",
            "cloudWatchLogGroupName": "/ssm/sessions",
            "cloudWatchEncryptionEnabled": true
        }
    }'
```

---

## 8. SSM Benefits Summary

```
┌─────────────────────────────────────────────────────────────────┐
│                    SSM BENEFITS                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Security:                                                      │
│  ├── No SSH port (22) exposed          ✅                       │
│  ├── IAM-based authentication          ✅                       │
│  ├── No SSH key management             ✅                       │
│  └── Encrypted communication           ✅                       │
│                                                                 │
│  Compliance:                                                    │
│  ├── Full session recording            ✅                       │
│  ├── CloudTrail integration            ✅                       │
│  ├── Audit logging                     ✅                       │
│  └── Access control via IAM            ✅                       │
│                                                                 │
│  Operations:                                                    │
│  ├── Browser-based access              ✅                       │
│  ├── No bastion host needed            ✅                       │
│  ├── Works in private subnets          ✅                       │
│  └── Run commands at scale             ✅                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 9. IAM Policy for Users (Admin Access)

Grant team members SSM access:

### Policy Name: `SSM-SessionManager-User-Policy`

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "StartSession",
      "Effect": "Allow",
      "Action": ["ssm:StartSession"],
      "Resource": [
        "arn:aws:ec2:*:*:instance/i-xxxxxxxxxxxxxxxxx",
        "arn:aws:ssm:*:*: document/AWS-StartSSHSession"
      ]
    },
    {
      "Sid": "TerminateSession",
      "Effect": "Allow",
      "Action": ["ssm: TerminateSession", "ssm:ResumeSession"],
      "Resource": ["arn:aws:ssm: *:*:session/${aws:username}-*"]
    },
    {
      "Sid": "DescribeSessions",
      "Effect": "Allow",
      "Action": [
        "ssm: DescribeSessions",
        "ssm:GetConnectionStatus",
        "ssm: DescribeInstanceInformation",
        "ec2:DescribeInstances"
      ],
      "Resource": "*"
    }
  ]
}
```

---

## 10. Troubleshooting

### Instance Not Showing in Fleet Manager

```bash
# Check SSM Agent is running
sudo systemctl status snap.amazon-ssm-agent. amazon-ssm-agent.service

# Check IAM role is attached
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/

# Check outbound connectivity
curl -I https://ssm.us-east-1.amazonaws.com
```

### "Access Denied" When Starting Session

1.  Verify IAM user has `ssm:StartSession` permission
2.  Check instance IAM role has `AmazonSSMManagedInstanceCore`
3.  Verify instance ID in IAM policy matches

### Session Manager Plugin Not Found

```bash
# Verify installation
session-manager-plugin --version

# Reinstall if needed
sudo dpkg -i session-manager-plugin.deb
```

---

## 11. Verification Checklist

- [ ] IAM role created (`EC2-SSM-Role`)
- [ ] Policy attached (`AmazonSSMManagedInstanceCore`)
- [ ] Role attached to EC2 instance
- [ ] SSM Agent running on instance
- [ ] Instance visible in Fleet Manager
- [ ] Can start session from Console
- [ ] Session Manager plugin installed (CLI)
- [ ] Can start session from CLI
- [ ] Session logging enabled (optional)

---

## Next Steps

After SSM enablement:

1. Disable SSH access (see `SSH_DISABLE. md`)
2. Configure firewall rules (see `FIREWALL_RULES.md`)
3. Run hardening script (see `HARDENING_SCRIPT.md`)
