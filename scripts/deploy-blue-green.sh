#!/bin/bash
# =============================================================================
# Blue-Green Deployment Script
# =============================================================================
#
# Usage: sudo ./deploy-blue-green.sh <docker-image>
# Example: sudo ./deploy-blue-green.sh myuser/myapp:latest
#
# =============================================================================

set -e

# =============================================================================
# CONFIGURATION
# =============================================================================

BLUE_PORT=3001
GREEN_PORT=3002
BLUE_CONTAINER="ecommerce-blue"
GREEN_CONTAINER="ecommerce-green"
STATE_FILE="/var/lib/deployment/state.json"
NGINX_BACKEND_CONF="/etc/nginx/conf. d/active-backend. conf"
HEALTH_ENDPOINT="/health"
HEALTH_TIMEOUT=60
HEALTH_INTERVAL=5
LOG_FILE="/var/log/deployment/deploy-$(date +%Y%m%d-%H%M%S).log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
    echo "[WARNING] $1" >> "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    echo "[ERROR] $1" >> "$LOG_FILE"
}

section() {
    echo ""
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo ""
}

# =============================================================================
# PRE-FLIGHT CHECKS
# =============================================================================

preflight_checks() {
    section "PRE-FLIGHT CHECKS"
    
    # Check root
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root (use sudo)"
        exit 1
    fi
    log "✅ Running as root"
    
    # Check Docker image argument
    if [ -z "$1" ]; then
        error "Usage: $0 <docker-image>"
        error "Example: $0 myuser/ecommerce-frontend:latest"
        exit 1
    fi
    DOCKER_IMAGE="$1"
    log "✅ Docker image: $DOCKER_IMAGE"
    
    # Create log directory
    mkdir -p /var/log/deployment
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed"
        exit 1
    fi
    log "✅ Docker available"
    
    # Check Nginx
    if !  command -v nginx &> /dev/null; then
        error "Nginx is not installed"
        exit 1
    fi
    log "✅ Nginx available"
    
    # Check state file
    if [ ! -f "$STATE_FILE" ]; then
        warn "State file not found, creating default"
        mkdir -p /var/lib/deployment
        echo '{"active":"blue","blue_port":3001,"green_port":3002}' > "$STATE_FILE"
    fi
    log "✅ State file exists"
}

# =============================================================================
# GET CURRENT STATE
# =============================================================================

get_current_state() {
    section "CURRENT STATE"
    
    CURRENT_ACTIVE=$(cat "$STATE_FILE" | grep -o '"active":"[^"]*"' | cut -d'"' -f4)
    
    if [ "$CURRENT_ACTIVE" == "blue" ]; then
        ACTIVE_PORT=$BLUE_PORT
        ACTIVE_CONTAINER=$BLUE_CONTAINER
        STANDBY_PORT=$GREEN_PORT
        STANDBY_CONTAINER=$GREEN_CONTAINER
        STANDBY_COLOR="green"
    else
        ACTIVE_PORT=$GREEN_PORT
        ACTIVE_CONTAINER=$GREEN_CONTAINER
        STANDBY_PORT=$BLUE_PORT
        STANDBY_CONTAINER=$BLUE_CONTAINER
        STANDBY_COLOR="blue"
    fi
    
    log "Current active: $CURRENT_ACTIVE (port $ACTIVE_PORT)"
    log "Standby target: $STANDBY_COLOR (port $STANDBY_PORT)"
}

# =============================================================================
# PULL NEW IMAGE
# =============================================================================

pull_image() {
    section "PULLING NEW IMAGE"
    
    log "Pulling:  $DOCKER_IMAGE"
    
    if docker pull "$DOCKER_IMAGE"; then
        log "✅ Image pulled successfully"
    else
        error "Failed to pull image:  $DOCKER_IMAGE"
        exit 1
    fi
}

# =============================================================================
# DEPLOY TO STANDBY
# =============================================================================

deploy_to_standby() {
    section "DEPLOYING TO STANDBY ($STANDBY_COLOR)"
    
    # Stop existing standby container if running
    log "Stopping existing standby container (if any)..."
    docker stop "$STANDBY_CONTAINER" 2>/dev/null || true
    docker rm "$STANDBY_CONTAINER" 2>/dev/null || true
    
    # Start new container on standby port
    log "Starting new container on port $STANDBY_PORT..."
    
    docker run -d \
        --name "$STANDBY_CONTAINER" \
        --restart unless-stopped \
        -p "$STANDBY_PORT: 3000" \
        -e NODE_ENV=production \
        --health-cmd="curl -f http://localhost:3000/health || exit 1" \
        --health-interval=10s \
        --health-timeout=5s \
        --health-retries=3 \
        "$DOCKER_IMAGE"
    
    if [ $? -eq 0 ]; then
        log "✅ Container started:  $STANDBY_CONTAINER"
    else
        error "Failed to start container"
        exit 1
    fi
}

# =============================================================================
# HEALTH CHECK
# =============================================================================

health_check() {
    section "HEALTH CHECK"
    
    log "Waiting for container to be healthy..."
    log "Endpoint: http://localhost:$STANDBY_PORT$HEALTH_ENDPOINT"
    log "Timeout: ${HEALTH_TIMEOUT}s"
    
    ELAPSED=0
    
    while [ $ELAPSED -lt $HEALTH_TIMEOUT ]; do
        # Check HTTP health
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$STANDBY_PORT$HEALTH_ENDPOINT" 2>/dev/null || echo "000")
        
        if [ "$HTTP_CODE" == "200" ]; then
            log "✅ Health check passed (HTTP $HTTP_CODE)"
            return 0
        fi
        
        log "Waiting...  (${ELAPSED}s elapsed, HTTP:  $HTTP_CODE)"
        sleep $HEALTH_INTERVAL
        ELAPSED=$((ELAPSED + HEALTH_INTERVAL))
    done
    
    error "Health check failed after ${HEALTH_TIMEOUT}s"
    error "Rolling back..."
    
    # Cleanup failed deployment
    docker stop "$STANDBY_CONTAINER" 2>/dev/null || true
    docker rm "$STANDBY_CONTAINER" 2>/dev/null || true
    
    exit 1
}

# =============================================================================
# SWITCH TRAFFIC
# =============================================================================

switch_traffic() {
    section "SWITCHING TRAFFIC"
    
    log "Updating Nginx to route to $STANDBY_COLOR (port $STANDBY_PORT)..."
    
    # Update Nginx active backend config
    cat > "$NGINX_BACKEND_CONF" << EOF
# Active Backend Configuration
# Updated by deployment script at $(date)
# Active:  $STANDBY_COLOR

upstream active_backend {
    server 127.0.0.1:$STANDBY_PORT;  # Currently: ${STANDBY_COLOR^^}
    keepalive 32;
}
EOF
    
    # Test Nginx config
    if nginx -t; then
        log "✅ Nginx config valid"
    else
        error "Nginx config invalid!"
        # Restore previous config
        cat > "$NGINX_BACKEND_CONF" << EOF
upstream active_backend {
    server 127.0.0.1:$ACTIVE_PORT;  # Restored: ${CURRENT_ACTIVE^^}
    keepalive 32;
}
EOF
        exit 1
    fi
    
    # Reload Nginx
    systemctl reload nginx
    
    if [ $? -eq 0 ]; then
        log "✅ Nginx reloaded - traffic switched to $STANDBY_COLOR"
    else
        error "Failed to reload Nginx"
        exit 1
    fi
}

# =============================================================================
# UPDATE STATE
# =============================================================================

update_state() {
    section "UPDATING STATE"
    
    # Update state file
    cat > "$STATE_FILE" << EOF
{
    "active":  "$STANDBY_COLOR",
    "blue_port": $BLUE_PORT,
    "green_port":  $GREEN_PORT,
    "previous_active": "$CURRENT_ACTIVE",
    "last_deployment": "$DOCKER_IMAGE",
    "last_deployment_time": "$(date -Iseconds)"
}
EOF
    
    log "✅ State updated:  active=$STANDBY_COLOR"
}

# =============================================================================
# VERIFY DEPLOYMENT
# =============================================================================

verify_deployment() {
    section "VERIFYING DEPLOYMENT"
    
    log "Testing production endpoint..."
    
    # Test through Nginx
    HTTP_CODE=$(curl -sk -o /dev/null -w "%{http_code}" "https://localhost/health" 2>/dev/null || echo "000")
    
    if [ "$HTTP_CODE" == "200" ]; then
        log "✅ Production health check passed (HTTP $HTTP_CODE)"
    else
        warn "Production health check returned HTTP $HTTP_CODE"
    fi
    
    # Show container status
    log ""
    log "Container Status:"
    docker ps --format "table {{. Names}}\t{{.Status}}\t{{. Ports}}" | grep -E "(NAMES|ecommerce)"
}

# =============================================================================
# CLEANUP OLD CONTAINER (Optional)
# =============================================================================

cleanup_old() {
    section "CLEANUP (KEEPING OLD FOR ROLLBACK)"
    
    log "Old container ($ACTIVE_CONTAINER) kept for rollback"
    log "To remove manually: docker rm -f $ACTIVE_CONTAINER"
    
    # Optionally stop old container after verification window
    # Uncomment below to stop old container after 5 minutes
    # (sleep 300 && docker stop "$ACTIVE_CONTAINER") &
}

# =============================================================================
# GENERATE REPORT
# =============================================================================

generate_report() {
    section "DEPLOYMENT COMPLETE"
    
    cat << EOF

=============================================================================
                     DEPLOYMENT REPORT
=============================================================================

  Timestamp:       $(date)
  Image:          $DOCKER_IMAGE
  
  BEFORE: 
  ───────
  Active:         $CURRENT_ACTIVE (port $ACTIVE_PORT)
  
  AFTER: 
  ──────
  Active:        $STANDBY_COLOR (port $STANDBY_PORT)
  Standby:       $CURRENT_ACTIVE (port $ACTIVE_PORT) - Ready for rollback
  
  CONTAINERS:
  ───────────
$(docker ps --format "  {{.Names}}:  {{.Status}}" | grep ecommerce)

  ENDPOINTS:
  ──────────
  Production:   https://YOUR_DOMAIN/
  Health:       https://YOUR_DOMAIN/health
  Blue Health:  https://YOUR_DOMAIN/blue-health
  Green Health:  https://YOUR_DOMAIN/green-health
  
  ROLLBACK:
  ─────────
  To rollback, run: sudo /home/ubuntu/scripts/rollback.sh

=============================================================================

EOF
    
    log "Deployment log:  $LOG_FILE"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    echo ""
    echo "============================================================================="
    echo "               BLUE-GREEN DEPLOYMENT"
    echo "============================================================================="
    echo ""
    
    preflight_checks "$1"
    get_current_state
    pull_image
    deploy_to_standby
    health_check
    switch_traffic
    update_state
    verify_deployment
    cleanup_old
    generate_report
    
    log "🚀 DEPLOYMENT SUCCESSFUL!"
}

# Run main function
main "$@"