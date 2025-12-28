#!/bin/bash
# =============================================================================
# UFW Firewall Configuration Script
# =============================================================================

set -e

echo "=========================================="
echo "       UFW FIREWALL SETUP                "
echo "=========================================="
echo ""

# Step 1: Reset UFW to defaults (optional - be careful!)
# sudo ufw --force reset

# Step 2: Set default policies
echo "=== Setting default policies ==="
sudo ufw default deny incoming
sudo ufw default allow outgoing
echo "✅ Default policies set"

# Step 3: Allow required ports
echo ""
echo "=== Allowing required ports ==="

# SSH (temporary)
sudo ufw allow 22/tcp comment 'SSH - Remove after SSM migration'
echo "✅ Port 22 (SSH) allowed"

# HTTP
sudo ufw allow 80/tcp comment 'HTTP - Nginx'
echo "✅ Port 80 (HTTP) allowed"

# HTTPS
sudo ufw allow 443/tcp comment 'HTTPS - Nginx SSL'
echo "✅ Port 443 (HTTPS) allowed"

# Step 4: Enable UFW
echo ""
echo "=== Enabling UFW ==="
sudo ufw --force enable
echo "✅ UFW enabled"

# Step 5: Show status
echo ""
echo "=== Current UFW Status ==="
sudo ufw status verbose

echo ""
echo "=========================================="
echo "       UFW SETUP COMPLETE ✅             "
echo "=========================================="