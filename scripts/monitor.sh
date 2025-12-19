#!/usr/bin/env bash

################################################################################
# System Monitoring Script
#
# Checks system resources and service status
################################################################################

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

# Source core libraries
source "${BASE_DIR}/lib/core.sh"
source "${BASE_DIR}/lib/detection.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo "========================================="
echo "WordPress LEMP Server - System Monitor"
echo "========================================="
echo

# System Resources
echo "System Resources:"
echo "-----------------"
echo "CPU Cores: $(nproc)"
echo "RAM Usage: $(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
echo "Disk Usage: $(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 " used)"}')"
echo

# Service Status
echo "Service Status:"
echo "---------------"

services=("nginx" "mariadb" "redis-server")
php_version=$(php -r 'echo PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION;' 2>/dev/null)
if [[ -n "$php_version" ]]; then
    services+=("php${php_version}-fpm")
fi

for service in "${services[@]}"; do
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        echo -e "${service}: ${GREEN}Running${NC}"
    else
        echo -e "${service}: ${RED}Stopped${NC}"
    fi
done
echo

# Connection Tests
echo "Connection Tests:"
echo "-----------------"

# Test Nginx
if curl -s -o /dev/null -w "%{http_code}" http://localhost | grep -q "200\|301\|302\|404"; then
    echo -e "Nginx HTTP: ${GREEN}OK${NC}"
else
    echo -e "Nginx HTTP: ${RED}FAIL${NC}"
fi

# Test MySQL
if mysql -e "SELECT 1;" &>/dev/null; then
    echo -e "MariaDB: ${GREEN}OK${NC}"
else
    echo -e "MariaDB: ${YELLOW}Check credentials${NC}"
fi

# Test Redis
if redis-cli ping &>/dev/null | grep -q "PONG"; then
    echo -e "Redis: ${GREEN}OK${NC}"
else
    echo -e "Redis: ${RED}FAIL${NC}"
fi
echo

# WordPress Sites
if [[ -f "${BASE_DIR}/config/wpserver.conf" ]]; then
    site_count=$(grep -v '^#' "${BASE_DIR}/config/wpserver.conf" | grep -c '|')
    echo "WordPress Sites: ${site_count}"
fi

echo
echo "Monitoring completed at: $(date '+%Y-%m-%d %H:%M:%S')"
