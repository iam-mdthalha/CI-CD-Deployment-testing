#!/bin/bash
# =============================================================================
# Log Viewer Script - Easy access to all logs
# =============================================================================
# Usage: view-logs.sh [type] [options]
# Types: app, nginx, deploy, system, all
# Options:  --follow, --lines=N, --errors
# =============================================================================

TYPE=${1:-help}
LINES=50
FOLLOW=false
ERRORS_ONLY=false

# Parse options
for arg in "$@"; do
    case $arg in
        --follow|-f)
            FOLLOW=true
            ;;
        --lines=*)
            LINES="${arg#*=}"
            ;;
        --errors|-e)
            ERRORS_ONLY=true
            ;;
    esac
done

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

STATE_FILE="/var/lib/deployment/state.json"

show_help() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                    LOG VIEWER${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "  Usage: view-logs. sh [type] [options]"
    echo ""
    echo "  Types:"
    echo "    app       - Application container logs"
    echo "    nginx     - Nginx access and error logs"
    echo "    deploy    - Deployment logs"
    echo "    system    - System logs (syslog)"
    echo "    all       - Summary of all logs"
    echo ""
    echo "  Options:"
    echo "    --follow, -f     - Follow log output (tail -f)"
    echo "    --lines=N        - Number of lines to show (default: 50)"
    echo "    --errors, -e     - Show only errors"
    echo ""
    echo "  Examples:"
    echo "    view-logs.sh app --follow"
    echo "    view-logs.sh nginx --errors --lines=100"
    echo "    view-logs.sh deploy"
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

view_app_logs() {
    echo ""
    echo -e "${BLUE}=== APPLICATION LOGS ===${NC}"
    echo ""
    
    # Get active container
    ACTIVE=$(cat "$STATE_FILE" 2>/dev/null | python3 -c "import sys, json; print(json.load(sys.stdin).get('active', 'blue'))" 2>/dev/null)
    CONTAINER="ecommerce-$ACTIVE"
    
    echo -e "${BLUE}Active container:  $CONTAINER${NC}"
    echo ""
    
    if [ "$FOLLOW" == "true" ]; then
        docker logs -f "$CONTAINER" 2>&1
    elif [ "$ERRORS_ONLY" == "true" ]; then
        docker logs --tail $LINES "$CONTAINER" 2>&1 | grep -iE "(error|exception|fatal|warn)" --color=always
    else
        docker logs --tail $LINES "$CONTAINER" 2>&1
    fi
}

view_nginx_logs() {
    echo ""
    echo -e "${BLUE}=== NGINX LOGS ===${NC}"
    echo ""
    
    if [ "$ERRORS_ONLY" == "true" ]; then
        echo -e "${YELLOW}--- Error Log ---${NC}"
        if [ "$FOLLOW" == "true" ]; then
            sudo tail -f /var/log/nginx/ecommerce-error.log
        else
            sudo tail -n $LINES /var/log/nginx/ecommerce-error.log
        fi
    else
        echo -e "${GREEN}--- Access Log (last $LINES lines) ---${NC}"
        sudo tail -n $LINES /var/log/nginx/ecommerce-access.log
        echo ""
        echo -e "${YELLOW}--- Error Log (last $LINES lines) ---${NC}"
        sudo tail -n $LINES /var/log/nginx/ecommerce-error.log
        
        if [ "$FOLLOW" == "true" ]; then
            echo ""
            echo -e "${BLUE}Following access log...  (Ctrl+C to stop)${NC}"
            sudo tail -f /var/log/nginx/ecommerce-access.log
        fi
    fi
}

view_deploy_logs() {
    echo ""
    echo -e "${BLUE}=== DEPLOYMENT LOGS ===${NC}"
    echo ""
    
    # List recent deployment logs
    echo -e "${BLUE}Recent deployment logs: ${NC}"
    ls -lt /var/log/deployment/*.log 2>/dev/null | head -5
    echo ""
    
    # Show latest deployment log
    LATEST=$(ls -t /var/log/deployment/*.log 2>/dev/null | head -1)
    if [ -n "$LATEST" ]; then
        echo -e "${GREEN}Latest deployment log:  $LATEST${NC}"
        echo ""
        tail -n $LINES "$LATEST"
    else
        echo -e "${YELLOW}No deployment logs found${NC}"
    fi
}

view_system_logs() {
    echo ""
    echo -e "${BLUE}=== SYSTEM LOGS ===${NC}"
    echo ""
    
    if [ "$ERRORS_ONLY" == "true" ]; then
        echo -e "${YELLOW}--- Errors in syslog ---${NC}"
        sudo grep -iE "(error|fail|crit)" /var/log/syslog | tail -n $LINES
    else
        echo -e "${GREEN}--- Syslog (last $LINES lines) ---${NC}"
        sudo tail -n $LINES /var/log/syslog
        
        if [ "$FOLLOW" == "true" ]; then
            echo ""
            echo -e "${BLUE}Following syslog... (Ctrl+C to stop)${NC}"
            sudo tail -f /var/log/syslog
        fi
    fi
}

view_all_logs() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                    LOG SUMMARY${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # App logs summary
    ACTIVE=$(cat "$STATE_FILE" 2>/dev/null | python3 -c "import sys, json; print(json.load(sys.stdin).get('active', 'blue'))" 2>/dev/null)
    CONTAINER="ecommerce-$ACTIVE"
    
    echo -e "${BLUE}─── APP LOGS ($CONTAINER) ───${NC}"
    docker logs --tail 10 "$CONTAINER" 2>&1 | tail -5
    echo ""
    
    # Nginx access summary
    echo -e "${BLUE}─── NGINX ACCESS ───${NC}"
    sudo tail -5 /var/log/nginx/ecommerce-access.log 2>/dev/null || echo "No access logs"
    echo ""
    
    # Nginx errors
    echo -e "${BLUE}─── NGINX ERRORS (recent) ───${NC}"
    sudo tail -5 /var/log/nginx/ecommerce-error.log 2>/dev/null || echo "No error logs"
    echo ""
    
    # Deployment logs
    echo -e "${BLUE}─── RECENT DEPLOYMENTS ───${NC}"
    ls -lt /var/log/deployment/*.log 2>/dev/null | head -3 || echo "No deployment logs"
    echo ""
    
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "  For detailed logs, use:"
    echo "    view-logs.sh app --follow"
    echo "    view-logs.sh nginx --errors"
    echo ""
}

# Main
case $TYPE in
    app|application)
        view_app_logs
        ;;
    nginx|web)
        view_nginx_logs
        ;;
    deploy|deployment)
        view_deploy_logs
        ;;
    system|syslog)
        view_system_logs
        ;;
    all|summary)
        view_all_logs
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo -e "${RED}Unknown log type: $TYPE${NC}"
        show_help
        exit 1
        ;;
esac