#!/bin/bash
# =============================================================================
# Health Check Script
# =============================================================================

BLUE_PORT=3001
GREEN_PORT=3002
STATE_FILE="/var/lib/deployment/state.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

check_health() {
    local name=$1
    local port=$2
    
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$port/health" 2>/dev/null || echo "000")
    
    if [ "$HTTP_CODE" == "200" ]; then
        echo -e "  $name (port $port): ${GREEN}✅ HEALTHY${NC} (HTTP $HTTP_CODE)"
        return 0
    else
        echo -e "  $name (port $port): ${RED}❌ UNHEALTHY${NC} (HTTP $HTTP_CODE)"
        return 1
    fi
}

echo ""
echo "============================================================================="
echo "                    HEALTH CHECK STATUS"
echo "============================================================================="
echo ""

# Get current state
if [ -f "$STATE_FILE" ]; then
    CURRENT_ACTIVE=$(cat "$STATE_FILE" | grep -o '"active":"[^"]*"' | cut -d'"' -f4)
    echo "  Current Active: ${YELLOW}${CURRENT_ACTIVE^^}${NC}"
    echo ""
fi

echo "  Container Health:"
echo "  ─────────────────"
check_health "BLUE " $BLUE_PORT
check_health "GREEN" $GREEN_PORT

echo ""
echo "  Nginx Health:"
echo "  ─────────────"

NGINX_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost/nginx-health" 2>/dev/null || echo "000")
if [ "$NGINX_CODE" == "200" ]; then
    echo -e "  Nginx:            ${GREEN}✅ HEALTHY${NC} (HTTP $NGINX_CODE)"
else
    echo -e "  Nginx:            ${RED}❌ UNHEALTHY${NC} (HTTP $NGINX_CODE)"
fi

echo ""
echo "  Production Health:"
echo "  ──────────────────"

PROD_CODE=$(curl -sk -o /dev/null -w "%{http_code}" "https://localhost/health" 2>/dev/null || echo "000")
if [ "$PROD_CODE" == "200" ]; then
    echo -e "  HTTPS /health:   ${GREEN}✅ HEALTHY${NC} (HTTP $PROD_CODE)"
else
    echo -e "  HTTPS /health:   ${RED}❌ UNHEALTHY${NC} (HTTP $PROD_CODE)"
fi

echo ""
echo "  Docker Containers:"
echo "  ──────────────────"
docker ps --format "  {{. Names}}: {{. Status}}" 2>/dev/null | grep -E "ecommerce" || echo "  No containers found"

echo ""
echo "============================================================================="
echo ""