# Firewall Rules Configuration Guide

## Overview

This document provides instructions for configuring host-level firewall (UFW) on EC2 instances for defense in depth security.

---

## 1. Defense in Depth

| Layer   | Component                    | Purpose                |
| ------- | ---------------------------- | ---------------------- |
| Layer 1 | AWS Security Group           | Network-level firewall |
| Layer 2 | UFW (Uncomplicated Firewall) | Host-level firewall    |
| Layer 3 | Application                  | Input validation       |

---

## 2. Port Requirements

### Production Environment

| Port | Protocol | Service     | Status                          |
| ---- | -------- | ----------- | ------------------------------- |
| 22   | TCP      | SSH         | ⚠️ Temporary (Remove after SSM) |
| 80   | TCP      | HTTP/Nginx  | ✅ Required                     |
| 443  | TCP      | HTTPS/Nginx | ✅ Required                     |
| 3000 | TCP      | Node.js App | ❌ Internal only                |

### After SSM Migration (Secured)

| Port | Protocol | Service     | Status      |
| ---- | -------- | ----------- | ----------- |
| 22   | TCP      | SSH         | ❌ Removed  |
| 80   | TCP      | HTTP/Nginx  | ✅ Required |
| 443  | TCP      | HTTPS/Nginx | ✅ Required |

---

## 3. UFW Setup Commands

### Initial Setup

```bash
# Set defaults
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow ports
sudo ufw allow 22/tcp comment 'SSH'
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'

# Enable
sudo ufw enable

# Verify
sudo ufw status verbose
```

### Remove SSH (After SSM Migration)

```bash
# Remove SSH rule
sudo ufw delete allow 22/tcp

# Verify
sudo ufw status
```

---

## 4. Security Group vs UFW

```
┌────────────────────┬────────────────────┬────────────────────┐
│                    │  Security Group    │  UFW               │
├────────────────────┼────────────────────┼────────────────────┤
│ Level              │  AWS/Network       │  OS/Host           │
│ Stateful           │  Yes               │  Yes               │
│ Default            │  Deny all inbound  │  Configurable      │
│ Managed by         │  AWS Console/CLI   │  Linux commands    │
│ Logs               │  VPC Flow Logs     │  /var/log/ufw.log  │
└────────────────────┴────────────────────┴────────────────────┘
```

---

## 5. Common Commands

### Status & Rules

```bash
# Check status
sudo ufw status
sudo ufw status verbose
sudo ufw status numbered

# List rules
sudo ufw show added
```

### Add Rules

```bash
# Allow port
sudo ufw allow PORT/tcp

# Allow from specific IP
sudo ufw allow from IP_ADDRESS to any port PORT

# Rate limit
sudo ufw limit PORT/tcp
```

### Delete Rules

```bash
# Delete by rule
sudo ufw delete allow PORT/tcp

# Delete by number
sudo ufw status numbered
sudo ufw delete NUMBER
```

### Enable/Disable

```bash
# Enable
sudo ufw enable

# Disable (careful!)
sudo ufw disable

# Reset to defaults
sudo ufw reset
```

---

## 6. Logging

### Enable Logging

```bash
# Levels: off, low, medium, high, full
sudo ufw logging medium
```

### View Logs

```bash
# Real-time
sudo tail -f /var/log/ufw.log

# Recent blocks
sudo grep "UFW BLOCK" /var/log/syslog | tail -10
```

---

## 7. Troubleshooting

### Cannot Connect After Enabling UFW

```bash
# If locked out, use AWS EC2 Serial Console or SSM
# Then disable UFW
sudo ufw disable

# Check rules and fix
sudo ufw status
# Add missing rules, then re-enable
```

### Application Not Accessible

```bash
# Check if port is allowed
sudo ufw status | grep PORT

# Add if missing
sudo ufw allow PORT/tcp
```

### UFW Not Starting on Boot

```bash
# Enable UFW on boot
sudo systemctl enable ufw
```

---

## 8. Verification Checklist

- [ ] UFW installed
- [ ] Default deny incoming
- [ ] Default allow outgoing
- [ ] Port 22 allowed (temporary)
- [ ] Port 80 allowed
- [ ] Port 443 allowed
- [ ] UFW enabled
- [ ] UFW logging enabled
- [ ] Tested connectivity

---

## 9. Final State (After Stage 7)

```
┌─────────────────────────────────────────────────────────────────┐
│                    FINAL UFW RULES                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  To                         Action      From                    │
│  --                         ------      ----                    │
│  80/tcp                     ALLOW IN    Anywhere                │
│  443/tcp                    ALLOW IN    Anywhere                │
│                                                                 │
│  Default:  deny (incoming), allow (outgoing)                    │
│                                                                 │
│  SSH (22):  ❌ REMOVED                                          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```
