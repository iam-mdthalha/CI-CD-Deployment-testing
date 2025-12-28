# Server Hardening Script Guide

## Overview

This document describes the comprehensive server hardening script that implements security best practices for Ubuntu 22.04 LTS EC2 instances.

---

## 1. What Does the Script Do?

| Category             | Actions                                               |
| -------------------- | ----------------------------------------------------- |
| **System Updates**   | Install latest security patches                       |
| **User Security**    | Password policies, lock root, sudo logging            |
| **SSH Hardening**    | Disable password auth, root login, strong ciphers     |
| **Network Security** | Kernel hardening, anti-spoofing, SYN flood protection |
| **Firewall**         | UFW configuration, allow only 22/80/443               |
| **Fail2ban**         | Brute force protection for SSH/Nginx                  |
| **Auto Updates**     | Automatic security updates                            |
| **Auditd**           | System auditing and monitoring                        |
| **File Permissions** | Secure sensitive files                                |
| **Disable Services** | Remove unnecessary services                           |
| **Security Tools**   | Install rkhunter, ClamAV, lynis                       |

---

## 2. Prerequisites

Before running the hardening script:

- [ ] SSM Agent installed and working
- [ ] IAM Role attached with SSM permissions
- [ ] Tested SSM session connection
- [ ] Backup of important data
- [ ] Application tested and working

---

## 3. Usage

### Step 1: Upload Script to Server

```bash
# Via SCP
scp -i key.pem scripts/server-hardening.sh ubuntu@EC2_IP:/home/ubuntu/

# Or via SSM
# Copy-paste script content
```

### Step 2: Run Script

```bash
# SSH into server
ssh -i key.pem ubuntu@EC2_IP

# Make executable
chmod +x server-hardening.sh

# Run with sudo
sudo ./server-hardening.sh
```

### Step 3: Verify

```bash
# Check UFW
sudo ufw status

# Check Fail2ban
sudo fail2ban-client status

# Check SSH config
sudo sshd -t

# Run security scan
sudo lynis audit system
```

---

## 4. What Gets Configured

### SSH Hardening

```
• PermitRootLogin no
• PasswordAuthentication no
• MaxAuthTries 3
• X11Forwarding no
• Strong ciphers only
```

### Kernel Parameters

```
• IP spoofing protection
• SYN flood protection
• ICMP redirect disabled
• Source routing disabled
• Martian logging enabled
```

### Firewall Rules

```
• Default deny incoming
• Default allow outgoing
• Allow:  22/tcp (SSH)
• Allow: 80/tcp (HTTP)
• Allow: 443/tcp (HTTPS)
```

### Fail2ban Jails

```
• sshd:  3 failures = 1 hour ban
• nginx-http-auth: 3 failures = ban
• nginx-botsearch: 2 failures = ban
```

---

## 5. Backup & Rollback

### Backup Location

```
/root/hardening-backup-YYYYMMDD-HHMMSS/
```

### Rollback Steps

```bash
# Restore SSH config
sudo cp /root/hardening-backup-*/sshd_config. bak /etc/ssh/sshd_config
sudo rm /etc/ssh/sshd_config. d/hardening.conf
sudo systemctl restart sshd

# Restore sysctl
sudo rm /etc/sysctl.d/99-hardening.conf
sudo sysctl --system

# Disable UFW temporarily
sudo ufw disable
```

---

## 6. Post-Hardening Checklist

- [ ] SSH access still works
- [ ] Application accessible via HTTP/HTTPS
- [ ] Fail2ban running
- [ ] Auditd running
- [ ] UFW enabled
- [ ] Security scan completed

---

## 7. Security Scan

Run after hardening:

```bash
sudo lynis audit system
```

Review the report and address any warnings.

---

## 8. Monitoring Commands

```bash
# Check failed logins
sudo grep "Failed password" /var/log/auth.log | tail -10

# Check Fail2ban bans
sudo fail2ban-client status sshd

# Check audit logs
sudo ausearch -k sshd | tail -20

# Check UFW logs
sudo tail -f /var/log/ufw. log
```

---

## 9. Troubleshooting

### Locked Out of SSH

1. Use SSM Session Manager
2. Or use EC2 Serial Console
3. Restore backup SSH config

### Application Not Working

```bash
# Check if ports are open
sudo ufw status

# Check if app is running
sudo docker ps

# Check nginx
sudo systemctl status nginx
```

### Fail2ban Blocking Legitimate IPs

```bash
# Unban IP
sudo fail2ban-client set sshd unbanip IP_ADDRESS

# Check banned IPs
sudo fail2ban-client status sshd
```
