#!/bin/bash
# =============================================================================
# SSH Disable Script
# Run this ONLY after verifying SSM works!
# =============================================================================

set -e

echo "=========================================="
echo "       SSH DISABLE SCRIPT                "
echo "=========================================="
echo ""

# Step 1: Verify SSM Agent
echo "=== Step 1: Checking SSM Agent ==="
if systemctl is-active --quiet snap.amazon-ssm-agent.amazon-ssm-agent.service; then
    echo "✅ SSM Agent is running"
else
    echo "❌ SSM Agent is NOT running!"
    echo "Please enable SSM first before disabling SSH"
    exit 1
fi

# Step 2: Create emergency re-enable script
echo ""
echo "=== Step 2: Creating emergency SSH re-enable script ==="
cat > /home/ubuntu/enable-ssh.sh << 'SCRIPT'
#!/bin/bash
# Emergency SSH re-enable script
sudo systemctl start ssh
sudo systemctl enable ssh
sudo ufw allow 22/tcp
echo "✅ SSH re-enabled on port 22"
SCRIPT
chmod +x /home/ubuntu/enable-ssh.sh
echo "✅ Created /home/ubuntu/enable-ssh.sh"

# Step 3: Disable SSH service
echo ""
echo "=== Step 3: Disabling SSH service ==="
sudo systemctl stop ssh
sudo systemctl disable ssh
echo "✅ SSH service disabled"

# Step 4: Block SSH in UFW
echo ""
echo "=== Step 4: Blocking SSH in firewall ==="
sudo ufw delete allow 22/tcp 2>/dev/null || echo "SSH rule already removed"
sudo ufw delete allow OpenSSH 2>/dev/null || echo "OpenSSH rule already removed"
echo "✅ SSH blocked in UFW"

# Step 5: Show final status
echo ""
echo "=== Final Status ==="
echo ""
echo "SSH Service:"
sudo systemctl status ssh --no-pager | head -5

echo ""
echo "Firewall Status:"
sudo ufw status

echo ""
echo "=========================================="
echo "       SSH DISABLED SUCCESSFULLY ✅      "
echo "=========================================="
echo ""
echo "⚠️  IMPORTANT: Now remove port 22 from AWS Security Group!"
echo ""
echo "To re-enable SSH (via SSM):"
echo "  /home/ubuntu/enable-ssh.sh"
echo ""
