#!/bin/bash
# =============================================================================
# Post-Deployment Validation Script
# =============================================================================

STATE_FILE="/var/lib/deployment/state.json"
BLUE_PORT=3001
GREEN_PORT=3002

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASSED=0
FAILED=0
WARNINGS=0

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASSED++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAILED++))
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    ((WARNINGS++))
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

section() {
    echo ""
    echo -e "${BLUE}=== $1 ===${NC}"
    echo ""
}

# =============================================================================
# CHECKS
# =============================================================================

echo ""
echo "=============================================================="
echo "           POST-DEPLOYMENT VALIDATION"
echo "=============================================================="
echo ""
echo "Timestamp: $(date)"
echo "Host: $(hostname)"
echo ""

# 1. State File
section "1.  DEPLOYMENT STATE"

if [ -f "$STATE_FILE" ]; then
    log_pass "State file exists:  $STATE_FILE"
    
    ACTIVE=$(cat "$STATE_FILE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('active', ''))" 2>/dev/null)
    
    if [ -n "$ACTIVE" ]; then
        log_pass "Active environment: $ACTIVE"
    else
        log_fail "Cannot determine active environment"
    fi
    
    log_info "State file contents:"
    cat "$STATE_FILE" | sed 's/^/    /'
else
    log_fail "State file not found:  $STATE_FILE"
fi

# 2. Docker Containers
section "2. DOCKER CONTAINERS"

if docker info &>/dev/null; then
    log_pass "Docker daemon is running"
else
    log_fail "Docker daemon is not running"
fi

if docker ps --format '{{.Names}}' | grep -q "ecommerce-blue"; then
    log_pass "Blue container is running"
else
    log_info "Blue container is not running (may be standby)"
fi

if docker ps --format '{{.Names}}' | grep -q "ecommerce-green"; then
    log_pass "Green container is running"
else
    log_info "Green container is not running (may be standby)"
fi

log_info "Container status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | grep -E "(NAMES|ecommerce)" | sed 's/^/    /'

# 3. Health Endpoints
section "3. HEALTH ENDPOINTS"

ACTIVE=$(cat "$STATE_FILE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('active', 'blue'))" 2>/dev/null)
if [ "$ACTIVE" == "green" ]; then
    ACTIVE_PORT=$GREEN_PORT
else
    ACTIVE_PORT=$BLUE_PORT
fi

log_info "Testing active container (port $ACTIVE_PORT)..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$ACTIVE_PORT/health" 2>/dev/null || echo "000")

if [ "$HTTP_CODE" == "200" ]; then
    log_pass "Active container health:  HTTP $HTTP_CODE"
else
    log_fail "Active container health failed:  HTTP $HTTP_CODE"
fi

log_info "Testing Nginx health..."
NGINX_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost/nginx-health" 2>/dev/null || echo "000")

if [ "$NGINX_CODE" == "200" ]; then
    log_pass "Nginx health: HTTP $NGINX_CODE"
elif [ "$NGINX_CODE" == "301" ] || [ "$NGINX_CODE" == "302" ]; then
    log_pass "Nginx health:  HTTP $NGINX_CODE (redirect to HTTPS - OK)"
else
    log_fail "Nginx health failed: HTTP $NGINX_CODE"
fi

log_info "Testing HTTPS endpoint..."
HTTPS_CODE=$(curl -sk -o /dev/null -w "%{http_code}" "https://localhost/health" 2>/dev/null || echo "000")

if [ "$HTTPS_CODE" == "200" ]; then
    log_pass "HTTPS health: HTTP $HTTPS_CODE"
else
    log_warn "HTTPS health: HTTP $HTTPS_CODE"
fi

# 4. Nginx Status
section "4. NGINX STATUS"

if systemctl is-active --quiet nginx; then
    log_pass "Nginx service is running"
else
    log_fail "Nginx service is not running"
fi

if nginx -t 2>&1 | grep -q "syntax is ok"; then
    log_pass "Nginx configuration is valid"
else
    log_fail "Nginx configuration is invalid"
fi

if [ -f "/etc/nginx/conf.d/active-backend.conf" ]; then
    log_pass "Active backend config exists"
    log_info "Current backend:"
    cat /etc/nginx/conf.d/active-backend.conf | grep server | sed 's/^/    /'
else
    log_fail "Active backend config not found"
fi

# 5. System Resources
section "5. SYSTEM RESOURCES"

DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -lt 80 ]; then
    log_pass "Disk usage:  ${DISK_USAGE}%"
elif [ "$DISK_USAGE" -lt 90 ]; then
    log_warn "Disk usage: ${DISK_USAGE}% (Warning)"
else
    log_fail "Disk usage:  ${DISK_USAGE}% (Critical)"
fi

MEM_USAGE=$(free | awk '/Mem:/ {printf "%.0f", $3/$2 * 100}')
if [ "$MEM_USAGE" -lt 80 ]; then
    log_pass "Memory usage: ${MEM_USAGE}%"
else
    log_warn "Memory usage: ${MEM_USAGE}%"
fi

# 6. Summary
section "SUMMARY"

echo ""
echo "=============================================================="
echo ""
echo -e "  ${GREEN}Passed: ${NC}   $PASSED"
echo -e "  ${RED}Failed:${NC}   $FAILED"
echo -e "  ${YELLOW}Warnings:${NC} $WARNINGS"
echo ""
echo "=============================================================="
echo ""

if [ "$FAILED" -eq 0 ]; then
    echo -e "  ${GREEN}✅ DEPLOYMENT VALIDATION PASSED${NC}"
    echo ""
    exit 0
else
    echo -e "  ${RED}❌ DEPLOYMENT VALIDATION FAILED${NC}"
    echo ""
    echo "  To rollback:  sudo /usr/local/bin/rollback.sh"
    echo ""
    exit 1
fi