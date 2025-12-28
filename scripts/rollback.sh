#!/bin/bash
# =============================================================================
# Rollback Script - Switch back to previous version
# =============================================================================

set -e

STATE_FILE="/var/lib/deployment/state.json"
NGINX_BACKEND_CONF="/etc/nginx/conf.d/active-backend.conf"
BLUE_PORT=3001
GREEN_PORT=3002

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

# Check root
if [ "$EUID" -ne 0 ]; then
    error "This script must be run as root (use sudo)"
    exit 1
fi

echo ""
echo "============================================================================="
echo "               ROLLBACK DEPLOYMENT"
echo "============================================================================="
echo ""

# Get current state
if [ !  -f "$STATE_FILE" ]; then
    error "State file not found:  $STATE_FILE"
    exit 1
fi

CURRENT_ACTIVE=$(cat "$STATE_FILE" | grep -o '"active":"[^"]*"' | cut -d'"' -f4)
PREVIOUS_ACTIVE=$(cat "$STATE_FILE" | grep -o '"previous_active":"[^"]*"' | cut -d'"' -f4)

if [ -z "$PREVIOUS_ACTIVE" ]; then
    error "No previous deployment found to rollback to"
    exit 1
fi

log "Current active: $CURRENT_ACTIVE"
log "Rolling back to:  $PREVIOUS_ACTIVE"

# Determine ports
if [ "$PREVIOUS_ACTIVE" == "blue" ]; then
    ROLLBACK_PORT=$BLUE_PORT
else
    ROLLBACK_PORT=$GREEN_PORT
fi

# Check if rollback target is healthy
log "Checking rollback target health..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$ROLLBACK_PORT/health" 2>/dev/null || echo "000")

if [ "$HTTP_CODE" != "200" ]; then
    error "Rollback target is not healthy (HTTP $HTTP_CODE)"
    error "Cannot rollback to an unhealthy container"
    exit 1
fi

log "✅ Rollback target is healthy"

# Confirm rollback
echo ""
warn "This will switch traffic from $CURRENT_ACTIVE to $PREVIOUS_ACTIVE"
read -p "Continue with rollback? (y/n): " -n 1 -r
echo ""

if [[ !  $REPLY =~ ^[Yy]$ ]]; then
    log "Rollback cancelled"
    exit 0
fi

# Update Nginx config
log "Updating Nginx configuration..."

cat > "$NGINX_BACKEND_CONF" << EOF
# Active Backend Configuration
# ROLLBACK at $(date)
# Active: $PREVIOUS_ACTIVE

upstream active_backend {
    server 127.0.0.1:$ROLLBACK_PORT;  # Rollback to:  ${PREVIOUS_ACTIVE^^}
    keepalive 32;
}
EOF

# Test and reload Nginx
if nginx -t; then
    systemctl reload nginx
    log "✅ Nginx reloaded"
else
    error "Nginx config invalid!"
    exit 1
fi

# Update state file
cat > "$STATE_FILE" << EOF
{
    "active":  "$PREVIOUS_ACTIVE",
    "blue_port": $BLUE_PORT,
    "green_port": $GREEN_PORT,
    "previous_active": "$CURRENT_ACTIVE",
    "last_rollback_time": "$(date -Iseconds)"
}
EOF

log "✅ State updated"

# Verify
log "Verifying rollback..."
PROD_CODE=$(curl -sk -o /dev/null -w "%{http_code}" "https://localhost/health" 2>/dev/null || echo "000")

if [ "$PROD_CODE" == "200" ]; then
    log "✅ Production health check passed"
else
    warn "Production returned HTTP $PROD_CODE"
fi

echo ""
echo "============================================================================="
echo "               ROLLBACK COMPLETE"
echo "============================================================================="
echo ""
echo "  Previous Active: $CURRENT_ACTIVE"
echo "  Current Active:  $PREVIOUS_ACTIVE (port $ROLLBACK_PORT)"
echo ""
echo "============================================================================="
echo ""