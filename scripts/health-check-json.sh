#!/bin/bash
# =============================================================================
# Health Status Script - Quick health overview
# =============================================================================
# Usage: health-status.sh [--json]
# =============================================================================

JSON_OUTPUT=false
if [ "$1" == "--json" ]; then
    JSON_OUTPUT=true
fi

# Colors (only for non-JSON output)
if [ "$JSON_OUTPUT" == "false" ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
fi

# Configuration
STATE_FILE="/var/lib/deployment/state.json"
BLUE_PORT=3001
GREEN_PORT=3002

# Get current state
get_active() {
    if [ -f "$STATE_FILE" ]; then
        cat "$STATE_FILE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('active', 'unknown'))" 2>/dev/null
    else
        echo "unknown"
    fi
}

# Check endpoint health
check_health() {
    local url=$1
    local timeout=${2:-5}
    curl -sf -o /dev/null -w "%{http_code}" --connect-timeout $timeout "$url" 2>/dev/null || echo "000"
}

# Get response time
get_response_time() {
    local url=$1
    curl -sf -o /dev/null -w "%{time_total}" --connect-timeout 5 "$url" 2>/dev/null || echo "0"
}

# Main checks
ACTIVE=$(get_active)
BLUE_STATUS=$(check_health "http://localhost:$BLUE_PORT/health")
GREEN_STATUS=$(check_health "http://localhost:$GREEN_PORT/health")
NGINX_STATUS=$(check_health "http://localhost/nginx-health")
HTTPS_STATUS=$(check_health "https://localhost/health" 5)
ACTIVE_PORT=$( [ "$ACTIVE" == "green" ] && echo $GREEN_PORT || echo $BLUE_PORT )
RESPONSE_TIME=$(get_response_time "http://localhost:$ACTIVE_PORT/health")

# Docker status
BLUE_CONTAINER=$(docker ps --format '{{.Status}}' --filter name=ecommerce-blue 2>/dev/null | head -1)
GREEN_CONTAINER=$(docker ps --format '{{.Status}}' --filter name=ecommerce-green 2>/dev/null | head -1)

# System resources
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
MEM_USAGE=$(free | awk '/Mem:/ {printf "%.0f", $3/$2 * 100}')
LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')

if [ "$JSON_OUTPUT" == "true" ]; then
    # JSON output
    cat << EOF
{
    "timestamp": "$(date -Iseconds)",
    "active_environment": "$ACTIVE",
    "endpoints": {
        "blue": {"port": $BLUE_PORT, "status":  $BLUE_STATUS},
        "green":  {"port": $GREEN_PORT, "status": $GREEN_STATUS},
        "nginx": {"status": $NGINX_STATUS},
        "https": {"status": $HTTPS_STATUS}
    },
    "response_time_seconds": $RESPONSE_TIME,
    "containers": {
        "blue": "$(echo $BLUE_CONTAINER | tr -d '\n')",
        "green": "$(echo $GREEN_CONTAINER | tr -d '\n')"
    },
    "system": {
        "disk_percent": $DISK_USAGE,
        "memory_percent":  $MEM_USAGE,
        "load_average": "$LOAD_AVG"
    }
}
EOF
else
    # Human-readable output
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                    HEALTH STATUS DASHBOARD${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${BLUE}Timestamp: ${NC}  $(date)"
    echo -e "  ${BLUE}Active: ${NC}     $ACTIVE"
    echo ""
    echo -e "${BLUE}─── ENDPOINTS ───────────────────────────────────────────────────${NC}"
    echo ""
    
    # Blue endpoint
    if [ "$BLUE_STATUS" == "200" ]; then
        echo -e "  Blue  (:  $BLUE_PORT):  ${GREEN}● HEALTHY${NC} (HTTP $BLUE_STATUS)"
    elif [ "$BLUE_STATUS" == "000" ]; then
        echo -e "  Blue  (: $BLUE_PORT):  ${YELLOW}○ OFFLINE${NC} (standby)"
    else
        echo -e "  Blue  (:$BLUE_PORT):  ${RED}✖ UNHEALTHY${NC} (HTTP $BLUE_STATUS)"
    fi
    
    # Green endpoint
    if [ "$GREEN_STATUS" == "200" ]; then
        echo -e "  Green (:$GREEN_PORT):  ${GREEN}● HEALTHY${NC} (HTTP $GREEN_STATUS)"
    elif [ "$GREEN_STATUS" == "000" ]; then
        echo -e "  Green (:$GREEN_PORT):  ${YELLOW}○ OFFLINE${NC} (standby)"
    else
        echo -e "  Green (:$GREEN_PORT):  ${RED}✖ UNHEALTHY${NC} (HTTP $GREEN_STATUS)"
    fi
    
    # Nginx
    if [ "$NGINX_STATUS" == "200" ] || [ "$NGINX_STATUS" == "301" ]; then
        echo -e "  Nginx (: 80):   ${GREEN}● HEALTHY${NC} (HTTP $NGINX_STATUS)"
    else
        echo -e "  Nginx (:80):   ${RED}✖ UNHEALTHY${NC} (HTTP $NGINX_STATUS)"
    fi
    
    # HTTPS
    if [ "$HTTPS_STATUS" == "200" ]; then
        echo -e "  HTTPS (:443):  ${GREEN}● HEALTHY${NC} (HTTP $HTTPS_STATUS)"
    else
        echo -e "  HTTPS (:443):  ${RED}✖ UNHEALTHY${NC} (HTTP $HTTPS_STATUS)"
    fi
    
    echo ""
    echo -e "${BLUE}─── CONTAINERS ──────────────────────────────────────────────────${NC}"
    echo ""
    
    if [ -n "$BLUE_CONTAINER" ]; then
        echo -e "  Blue:    ${GREEN}$BLUE_CONTAINER${NC}"
    else
        echo -e "  Blue:   ${YELLOW}Not running${NC}"
    fi
    
    if [ -n "$GREEN_CONTAINER" ]; then
        echo -e "  Green:  ${GREEN}$GREEN_CONTAINER${NC}"
    else
        echo -e "  Green:  ${YELLOW}Not running${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}─── PERFORMANCE ─────────────────────────────────────────────────${NC}"
    echo ""
    echo -e "  Response Time:   ${RESPONSE_TIME}s"
    echo -e "  Disk Usage:      ${DISK_USAGE}%"
    echo -e "  Memory Usage:    ${MEM_USAGE}%"
    echo -e "  Load Average:    ${LOAD_AVG}"
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
fi