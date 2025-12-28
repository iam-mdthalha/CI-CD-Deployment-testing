#!/bin/bash
# =============================================================================
# Blue-Green Setup Script - Run once to initialize
# =============================================================================

set -e

echo "============================================================================="
echo "               BLUE-GREEN SETUP"
echo "============================================================================="

# Create directories
sudo mkdir -p /var/lib/deployment
sudo mkdir -p /var/log/deployment
sudo mkdir -p /etc/nginx/conf.d

# Create initial state file
sudo tee /var/lib/deployment/state.json > /dev/null << 'EOF'
{
    "active": "blue",
    "blue_port": 3001,
    "green_port": 3002,
    "last_deployment": "",
    "last_deployment_time": ""
}
EOF

# Create initial Nginx active backend config
sudo tee /etc/nginx/conf.d/active-backend.conf > /dev/null << 'EOF'
# Active Backend Configuration
# Initial setup - Blue is active

upstream active_backend {
    server 127.0.0.1:3001;  # Currently:  BLUE
    keepalive 32;
}
EOF

# Set permissions
sudo chmod 755 /var/lib/deployment
sudo chmod 644 /var/lib/deployment/state.json
sudo chmod 755 /var/log/deployment

echo ""
echo "✅ Blue-Green infrastructure initialized!"
echo ""
echo "  State file:    /var/lib/deployment/state.json"
echo "  Nginx config:  /etc/nginx/conf.d/active-backend.conf"
echo "  Log directory: /var/log/deployment/"
echo ""
echo "  Initial active: BLUE (port 3001)"
echo ""
echo "  Next steps:"
echo "  1. Start initial blue container: docker run -d --name ecommerce-blue -p 3001:3000 your-image"
echo "  2. Test Nginx config: sudo nginx -t"
echo "  3. Reload Nginx: sudo systemctl reload nginx"
echo ""
