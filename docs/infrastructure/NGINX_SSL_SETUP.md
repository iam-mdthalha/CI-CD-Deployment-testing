# Nginx & SSL Setup Guide

## Overview

This document provides instructions for setting up Nginx as a reverse proxy with SSL/TLS for the E-Commerce Frontend application.

---

## 1. Architecture

```
Internet → : 443 (HTTPS) → Nginx → :3000 (App Container)
Internet → :80 (HTTP) → Redirect → :443 (HTTPS)
```

---

## 2. Installation

```bash
# Install Nginx
sudo apt update
sudo apt install -y nginx

# Start and enable
sudo systemctl start nginx
sudo systemctl enable nginx
```

---

## 3. SSL Options

### Option A: Let's Encrypt (Production)

```bash
# Install Certbot
sudo apt install -y certbot python3-certbot-nginx

# Get certificate
sudo certbot --nginx -d yourdomain.com

# Auto-renewal (already configured)
sudo certbot renew --dry-run
```

### Option B: Self-Signed (Development)

```bash
# Generate certificate
sudo openssl req -x509 -nodes -days 365 -newkey rsa: 2048 \
    -keyout /etc/nginx/ssl/selfsigned. key \
    -out /etc/nginx/ssl/selfsigned.crt
```

---

## 4. Configuration Files

| File                                   | Purpose           |
| -------------------------------------- | ----------------- |
| `/etc/nginx/sites-available/ecommerce` | Main config       |
| `/etc/nginx/sites-enabled/ecommerce`   | Symlink (enabled) |
| `/etc/nginx/ssl/`                      | SSL certificates  |
| `/var/log/nginx/ecommerce-*. log`      | Logs              |

---

## 5. Common Commands

```bash
# Test configuration
sudo nginx -t

# Reload (apply changes)
sudo systemctl reload nginx

# Restart
sudo systemctl restart nginx

# View logs
sudo tail -f /var/log/nginx/ecommerce-access.log
sudo tail -f /var/log/nginx/ecommerce-error.log
```

---

## 6. Health Checks

| Endpoint        | Purpose            |
| --------------- | ------------------ |
| `/nginx-health` | Nginx health       |
| `/health`       | Application health |

---

## 7. Security Features

- TLS 1.2/1.3 only
- Strong cipher suites
- Security headers (X-Frame-Options, etc.)
- Rate limiting
- Gzip compression
- HTTP to HTTPS redirect

---

## 8. Troubleshooting

### 502 Bad Gateway

```bash
# Check if app is running
docker ps

# Check if app is on correct port
curl http://localhost:3000/health
```

### SSL Certificate Issues

```bash
# Check certificate
sudo openssl x509 -in /etc/nginx/ssl/selfsigned. crt -text -noout

# Renew Let's Encrypt
sudo certbot renew
```
