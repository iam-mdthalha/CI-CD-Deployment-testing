#!/bin/bash
# =============================================================================
# Rollback Script - Switch to Previous Version (FINAL)
# =============================================================================
# Usage: sudo /opt/ecommerce/scripts/rollback.sh [--force]
# =============================================================================

set -e

# =============================================================================
# COLORS
# =============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# =============================================================================
# CONFIGURATION
# =============================================================================
STATE_FILE="/var/lib/deployment/state.json"
NGINX_BACKEND_CONF="/etc/nginx/conf.d/active-backend.conf"
BLUE_PORT=3001
GREEN_PORT=3002
ROLLBACK_LOG="/var/log/deployment/rollback-$(date +%Y%m%d-%H%M%S).log"

# =============================================================================
# LOGGING SAFETY (CRITICAL)
# =============================================================================
mkdir -p /var/log/deployment
touch "$ROLLBACK_LOG"

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================
log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$ROLLBACK_LOG"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo "[ERROR] $1" >> "$ROLLBACK_LOG"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    echo "[WARNING] $1" >> "$ROLLBACK_LOG"
}

# =============================================================================
# PREFLIGHT
# =============================================================================
preflight() {
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root"
        exit 1
    fi

    if [ ! -f "$STATE_FILE" ]; then
        error "State file not found: $STATE_FILE"
        exit 1
    fi
}

# =============================================================================
# READ STATE (WHITESPACE SAFE)
# =============================================================================
get_state() {
    CURRENT_ACTIVE=$(grep -o '"active"[[:space:]]*:[[:space:]]*"[^"]*"' "$STATE_FILE" \
        | cut -d'"' -f4 || true)

    PREVIOUS_ACTIVE=$(grep -o '"previous_active"[[:space:]]*:[[:space:]]*"[^"]*"' "$STATE_FILE" \
        | cut -d'"' -f4 || true)

    if [ -z "$CURRENT_ACTIVE" ]; then
        error "Cannot determine current active environment"
        exit 1
    fi

    if [ -z "$PREVIOUS_ACTIVE" ]; then
        error "No previous deployment found to rollback to"
        exit 1
    fi

    if [ "$PREVIOUS_ACTIVE" = "blue" ]; then
        ROLLBACK_PORT=$BLUE_PORT
    else
        ROLLBACK_PORT=$GREEN_PORT
    fi

    # 🔥 Detect container by port (name-agnostic)
    ROLLBACK_CONTAINER=$(docker ps \
        --filter "publish=$ROLLBACK_PORT" \
        --format "{{.Names}}" | head -n 1 || true)

    if [ -z "$ROLLBACK_CONTAINER" ]; then
        error "No running container found exposing port $ROLLBACK_PORT"
        exit 1
    fi
}

# =============================================================================
# HEALTH CHECK
# =============================================================================
check_rollback_target() {
    log "Checking rollback target health..."

    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        "http://localhost:$ROLLBACK_PORT/health" || echo "000")

    if [ "$HTTP_CODE" = "200" ]; then
        log "Rollback target is healthy (HTTP 200)"
    else
        error "Rollback target unhealthy (HTTP $HTTP_CODE)"
        exit 1
    fi
}

# =============================================================================
# CONFIRMATION
# =============================================================================
confirm_rollback() {
    if [ "$1" = "--force" ]; then
        log "Force flag detected — skipping confirmation"
        return
    fi

    echo ""
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}                    ROLLBACK CONFIRMATION${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "  Current active:   $CURRENT_ACTIVE"
    echo "  Rollback to:     $PREVIOUS_ACTIVE (port $ROLLBACK_PORT)"
    echo ""
    echo -e "${YELLOW}  This will switch production traffic to the previous version.${NC}"
    echo ""

    read -p "  Continue with rollback? (yes/no): " CONFIRM

    if [ "$CONFIRM" != "yes" ]; then
        log "Rollback cancelled by user"
        exit 0
    fi
}

# =============================================================================
# PERFORM ROLLBACK
# =============================================================================
perform_rollback() {
    log "Starting rollback..."
    log "Updating Nginx configuration..."

    cat > "$NGINX_BACKEND_CONF" <<EOF
# Rollback at $(date)
upstream active_backend {
    server 127.0.0.1:$ROLLBACK_PORT;
    keepalive 32;
}
EOF

    log "Testing Nginx configuration..."
    nginx -t &>/dev/null || { error "Nginx configuration invalid"; exit 1; }

    log "Reloading Nginx..."
    systemctl reload nginx
    log "Nginx reloaded successfully"

    log "Updating state file..."
    cat > "$STATE_FILE" <<EOF
{
    "active": "$PREVIOUS_ACTIVE",
    "blue_port": $BLUE_PORT,
    "green_port": $GREEN_PORT,
    "previous_active": "$CURRENT_ACTIVE",
    "last_rollback_time": "$(date -Iseconds)",
    "rollback_reason": "manual"
}
EOF

    log "State file updated"
}

# =============================================================================
# VERIFY
# =============================================================================
verify_rollback() {
    log "Verifying rollback..."
    sleep 2

    HTTP_CODE=$(curl -sk -o /dev/null -w "%{http_code}" \
        "https://localhost/health" || echo "000")

    if [ "$HTTP_CODE" = "200" ]; then
        log "Production health check passed (HTTP 200)"
    else
        warn "Production health check returned HTTP $HTTP_CODE"
    fi

    log "Container status:"
    docker ps --format "table {{.Names}}\t{{.Status}}" \
        | grep -E "(NAMES|ecommerce|quirky_|green|blue)"
}

# =============================================================================
# SUMMARY
# =============================================================================
summary() {
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}                    ROLLBACK COMPLETE${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "  Previous active: $CURRENT_ACTIVE"
    echo "  Current active:  $PREVIOUS_ACTIVE (port $ROLLBACK_PORT)"
    echo ""
    echo "  Log file: $ROLLBACK_LOG"
    echo ""
}

# =============================================================================
# MAIN
# =============================================================================
main() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "                    ROLLBACK DEPLOYMENT"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    preflight
    get_state
    check_rollback_target
    confirm_rollback "$1"
    perform_rollback
    verify_rollback
    summary

    log "Rollback completed successfully"
}

main "$@"
