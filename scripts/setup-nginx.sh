#!/bin/bash
# =============================================================================
# Nginx Setup Script for E-Commerce Frontend
# =============================================================================

set -e

echo "=========================================="
echo "       NGINX SETUP SCRIPT                "
echo "=========================================="

# Step 1: Install Nginx
echo ""
echo "=== Installing Nginx ==="
sudo apt update
sudo apt install -y nginx
echo "✅ Nginx installed"

# Step 2: Create SSL directory
echo ""
echo "=== Setting up SSL ==="
sudo mkdir -p /etc/nginx/ssl

# Step 3: Generate self-signed certificate
echo "Generating self-signed certificate..."
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/selfsigned.key \
    -out /etc/nginx/ssl/selfsigned. crt \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"
echo "✅ SSL certificate created"

# Step 4: Generate DH parameters
echo "Generating DH parameters (this may take a while)..."
sudo openssl dhparam -out /etc/nginx/ssl/dhparam.pem 2048
echo "✅ DH parameters generated"

# Step 5: Remove default site
sudo rm -f /etc/nginx/sites-enabled/default

# Step 6: Create Nginx config
echo ""
echo "=== Creating Nginx configuration ==="
sudo tee /etc/nginx/sites-available/ecommerce > /dev/null << 'NGINXCONFIG'
# E-Commerce Frontend Nginx Configuration

upstream app_backend {
    server 127.0.0.1:3000;
    keepalive 32;
}

limit_req_zone $binary_remote_addr zone=app_limit:10m rate=10r/s;

server {
    listen 80;
    listen [::]:80;
    server_name _;
    
    location /. well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name _;
    
    ssl_certificate /etc/nginx/ssl/selfsigned.crt;
    ssl_certificate_key /etc/nginx/ssl/selfsigned.key;
    ssl_dhparam /etc/nginx/ssl/dhparam.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL: 50m;
    
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    access_log /var/log/nginx/ecommerce-access.log;
    error_log /var/log/nginx/ecommerce-error.log;
    
    gzip on;
    gzip_types text/plain text/css application/json application/javascript;
    
    location /nginx-health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
    
    location /health {
        proxy_pass http://app_backend;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        access_log off;
    }
    
    location / {
        limit_req zone=app_limit burst=20 nodelay;
        
        proxy_pass http://app_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
NGINXCONFIG

echo "✅ Nginx configuration created"

# Step 7: Enable site
sudo ln -sf /etc/nginx/sites-available/ecommerce /etc/nginx/sites-enabled/

# Step 8: Test and reload
echo ""
echo "=== Testing Nginx configuration ==="
sudo nginx -t

echo ""
echo "=== Reloading Nginx ==="
sudo systemctl reload nginx
sudo systemctl enable nginx

# Step 9: Show status
echo ""
echo "=== Nginx Status ==="
sudo systemctl status nginx --no-pager | head -10

echo ""
echo "=========================================="
echo "       NGINX SETUP COMPLETE ✅           "
echo "=========================================="
echo ""
echo "  HTTP:   http://YOUR_IP  (redirects to HTTPS)"
echo "  HTTPS:  https://YOUR_IP (self-signed cert)"
echo ""
echo "  Health: https://YOUR_IP/nginx-health"
echo "  App:    https://YOUR_IP/health"
echo ""
echo "  For production SSL, run:"
echo "  sudo certbot --nginx -d yourdomain.com"
echo ""