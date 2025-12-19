#!/usr/bin/env bash

################################################################################
# System Detection Library
#
# Provides: System resource detection, software detection, resource calculation
################################################################################

# Global variables for detected values
declare -g CPU_CORES
declare -g TOTAL_RAM_MB
declare -g AVAILABLE_DISK_GB
declare -g OS_NAME
declare -g OS_VERSION
declare -g OS_CODENAME

# Software installation flags
declare -g NGINX_INSTALLED
declare -g NGINX_VERSION
declare -g MARIADB_INSTALLED
declare -g MARIADB_VERSION
declare -g PHP_INSTALLED
declare -g PHP_VERSION
declare -g REDIS_INSTALLED
declare -g REDIS_VERSION
declare -g CERTBOT_INSTALLED

# Calculated configuration values
declare -g NGINX_WORKERS
declare -g PHP_MAX_CHILDREN
declare -g PHP_START_SERVERS
declare -g PHP_MIN_SPARE
declare -g PHP_MAX_SPARE
declare -g PHP_MEMORY_LIMIT
declare -g UPLOAD_MAX_SIZE
declare -g POST_MAX_SIZE
declare -g INNODB_BUFFER_POOL
declare -g INNODB_LOG_FILE_SIZE
declare -g MAX_CONNECTIONS
declare -g REDIS_MAXMEMORY

################################################################################
# Operating System Detection
################################################################################

detect_os() {
    log_step "Detecting operating system"

    # Check if running on Ubuntu
    if [[ ! -f /etc/os-release ]]; then
        log_error "Cannot detect operating system. /etc/os-release not found."
    fi

    # Source OS information
    source /etc/os-release

    OS_NAME="$NAME"
    OS_VERSION="$VERSION_ID"
    OS_CODENAME="${VERSION_CODENAME:-unknown}"

    # Verify Ubuntu
    if [[ "$ID" != "ubuntu" ]]; then
        log_error "This script only supports Ubuntu. Detected: $OS_NAME"
    fi

    # Check Ubuntu version
    case "$OS_VERSION" in
        20.04|22.04|24.04)
            log_success "Detected: $OS_NAME $OS_VERSION ($OS_CODENAME)"
            ;;
        *)
            log_warning "Ubuntu $OS_VERSION detected. Recommended: 20.04 LTS, 22.04 LTS, or 24.04 LTS"
            log_warning "Script may work but is not officially tested on this version"
            ;;
    esac
}

################################################################################
# Hardware Detection
################################################################################

detect_cpu() {
    log_step "Detecting CPU information"

    # Get number of CPU cores
    CPU_CORES=$(nproc)

    if [[ -z "$CPU_CORES" ]] || [[ "$CPU_CORES" -lt 1 ]]; then
        log_warning "Could not detect CPU cores, defaulting to 1"
        CPU_CORES=1
    fi

    log_success "CPU Cores: ${CPU_CORES}"
}

detect_ram() {
    log_step "Detecting RAM"

    # Get total RAM in MB
    TOTAL_RAM_MB=$(free -m | awk '/^Mem:/{print $2}')

    if [[ -z "$TOTAL_RAM_MB" ]] || [[ "$TOTAL_RAM_MB" -lt 512 ]]; then
        log_error "Insufficient RAM detected. Minimum 512MB required."
    fi

    # Convert to GB for display
    local ram_gb=$((TOTAL_RAM_MB / 1024))

    log_success "Total RAM: ${TOTAL_RAM_MB}MB (~${ram_gb}GB)"

    # Warn if low memory
    if [[ $TOTAL_RAM_MB -lt 1024 ]]; then
        log_warning "Low RAM detected. WordPress may run slowly with less than 1GB RAM"
    fi
}

detect_disk() {
    log_step "Detecting disk space"

    # Get available disk space in GB
    AVAILABLE_DISK_GB=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')

    if [[ -z "$AVAILABLE_DISK_GB" ]]; then
        log_error "Could not detect available disk space"
    fi

    log_success "Available Disk Space: ${AVAILABLE_DISK_GB}GB"
}

################################################################################
# Software Detection
################################################################################

check_nginx() {
    log_step "Checking for Nginx"

    if command_exists nginx; then
        NGINX_INSTALLED=1
        NGINX_VERSION=$(nginx -v 2>&1 | grep -oP 'nginx/\K[0-9.]+')
        log_info "Nginx ${NGINX_VERSION} is already installed"
    else
        NGINX_INSTALLED=0
        log_info "Nginx not installed"
    fi
}

check_mariadb() {
    log_step "Checking for MariaDB/MySQL"

    if command_exists mariadb; then
        MARIADB_INSTALLED=1
        MARIADB_VERSION=$(mariadb --version | grep -oP 'Distrib \K[0-9.]+')
        log_info "MariaDB ${MARIADB_VERSION} is already installed"
    elif command_exists mysql; then
        MARIADB_INSTALLED=1
        MARIADB_VERSION=$(mysql --version | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        log_info "MySQL ${MARIADB_VERSION} is already installed"
    else
        MARIADB_INSTALLED=0
        log_info "MariaDB/MySQL not installed"
    fi
}

check_php() {
    log_step "Checking for PHP"

    if command_exists php; then
        PHP_INSTALLED=1
        PHP_VERSION=$(php -r 'echo PHP_VERSION;' 2>/dev/null)
        PHP_MAJOR_VERSION=$(echo "$PHP_VERSION" | cut -d. -f1-2)
        log_info "PHP ${PHP_VERSION} is already installed"

        # Check if it's a supported version
        case "$PHP_MAJOR_VERSION" in
            8.1|8.2|8.3)
                log_success "PHP version is supported"
                ;;
            *)
                log_warning "PHP ${PHP_MAJOR_VERSION} detected. Recommended: 8.1, 8.2, or 8.3"
                ;;
        esac
    else
        PHP_INSTALLED=0
        PHP_MAJOR_VERSION="8.2"  # Default to 8.2
        log_info "PHP not installed (will install PHP ${PHP_MAJOR_VERSION})"
    fi
}

check_redis() {
    log_step "Checking for Redis"

    if command_exists redis-server; then
        REDIS_INSTALLED=1
        REDIS_VERSION=$(redis-server --version | grep -oP 'v=\K[0-9.]+')
        log_info "Redis ${REDIS_VERSION} is already installed"
    else
        REDIS_INSTALLED=0
        log_info "Redis not installed"
    fi
}

check_certbot() {
    log_step "Checking for Certbot"

    if command_exists certbot; then
        CERTBOT_INSTALLED=1
        log_info "Certbot is already installed"
    else
        CERTBOT_INSTALLED=0
        log_info "Certbot not installed"
    fi
}

################################################################################
# Resource Calculation
################################################################################

calculate_resources() {
    log_step "Calculating optimal configuration values"

    # CPU-based calculations
    NGINX_WORKERS=$CPU_CORES

    # RAM-based calculations
    if [[ $TOTAL_RAM_MB -lt 2048 ]]; then
        # Less than 2GB RAM
        PHP_MAX_CHILDREN=10
        PHP_START_SERVERS=$((CPU_CORES * 2))
        PHP_MIN_SPARE=$CPU_CORES
        PHP_MAX_SPARE=$((CPU_CORES * 3))
        PHP_MEMORY_LIMIT="256M"
        UPLOAD_MAX_SIZE="64M"
        INNODB_BUFFER_POOL=400
        REDIS_MAXMEMORY=128

    elif [[ $TOTAL_RAM_MB -lt 4096 ]]; then
        # 2GB - 4GB RAM
        PHP_MAX_CHILDREN=20
        PHP_START_SERVERS=$((CPU_CORES * 2))
        PHP_MIN_SPARE=$CPU_CORES
        PHP_MAX_SPARE=$((CPU_CORES * 3))
        PHP_MEMORY_LIMIT="256M"
        UPLOAD_MAX_SIZE="128M"
        INNODB_BUFFER_POOL=800
        REDIS_MAXMEMORY=128

    elif [[ $TOTAL_RAM_MB -lt 8192 ]]; then
        # 4GB - 8GB RAM
        PHP_MAX_CHILDREN=30
        PHP_START_SERVERS=$((CPU_CORES * 2))
        PHP_MIN_SPARE=$((CPU_CORES * 1))
        PHP_MAX_SPARE=$((CPU_CORES * 3))
        PHP_MEMORY_LIMIT="384M"
        UPLOAD_MAX_SIZE="256M"
        INNODB_BUFFER_POOL=1800
        REDIS_MAXMEMORY=256

    else
        # 8GB+ RAM
        PHP_MAX_CHILDREN=60
        PHP_START_SERVERS=$((CPU_CORES * 3))
        PHP_MIN_SPARE=$((CPU_CORES * 2))
        PHP_MAX_SPARE=$((CPU_CORES * 4))
        PHP_MEMORY_LIMIT="512M"
        UPLOAD_MAX_SIZE="512M"
        INNODB_BUFFER_POOL=$((TOTAL_RAM_MB * 45 / 100))  # 45% of RAM
        REDIS_MAXMEMORY=512
    fi

    # Ensure minimum values
    [[ $PHP_START_SERVERS -lt 2 ]] && PHP_START_SERVERS=2
    [[ $PHP_MIN_SPARE -lt 1 ]] && PHP_MIN_SPARE=1
    [[ $PHP_MAX_SPARE -lt 3 ]] && PHP_MAX_SPARE=3

    # Calculate POST max size (upload size + 8MB overhead)
    POST_MAX_SIZE="$((${UPLOAD_MAX_SIZE//M/} + 8))M"

    # Calculate InnoDB log file size (25% of buffer pool)
    INNODB_LOG_FILE_SIZE=$((INNODB_BUFFER_POOL / 4))

    # Calculate max connections (based on available RAM and PHP processes)
    MAX_CONNECTIONS=$((PHP_MAX_CHILDREN + 50))

    log_success "Configuration values calculated based on system resources"
}

################################################################################
# Display Functions
################################################################################

display_software_status() {
    log_header "Software Status"

    echo -e "${COLOR_CYAN}Component Status:${COLOR_RESET}"
    echo

    # Nginx
    if [[ ${NGINX_INSTALLED:-0} == 1 ]]; then
        echo -e "  ${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} Nginx ${NGINX_VERSION:-unknown} (installed)"
    else
        echo -e "  ${COLOR_YELLOW}○${COLOR_RESET} Nginx (will be installed)"
    fi

    # MariaDB
    if [[ ${MARIADB_INSTALLED:-0} == 1 ]]; then
        echo -e "  ${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} MariaDB/MySQL ${MARIADB_VERSION:-unknown} (installed)"
    else
        echo -e "  ${COLOR_YELLOW}○${COLOR_RESET} MariaDB (will be installed)"
    fi

    # PHP
    if [[ ${PHP_INSTALLED:-0} == 1 ]]; then
        echo -e "  ${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} PHP ${PHP_VERSION:-unknown} (installed)"
    else
        echo -e "  ${COLOR_YELLOW}○${COLOR_RESET} PHP ${PHP_MAJOR_VERSION:-8.2} (will be installed)"
    fi

    # Redis
    if [[ ${REDIS_INSTALLED:-0} == 1 ]]; then
        echo -e "  ${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} Redis ${REDIS_VERSION:-unknown} (installed)"
    else
        echo -e "  ${COLOR_YELLOW}○${COLOR_RESET} Redis (will be installed)"
    fi

    # Certbot
    if [[ ${CERTBOT_INSTALLED:-0} == 1 ]]; then
        echo -e "  ${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} Certbot (installed)"
    else
        echo -e "  ${COLOR_YELLOW}○${COLOR_RESET} Certbot (will be installed)"
    fi

    echo
}

display_system_status() {
    log_header "System Status"

    # Detect resources if not already done
    [[ -z "${CPU_CORES:-}" ]] && detect_cpu
    [[ -z "${TOTAL_RAM_MB:-}" ]] && detect_ram
    [[ -z "${AVAILABLE_DISK_GB:-}" ]] && detect_disk

    # System info
    table_row "CPU Cores" "$CPU_CORES"
    table_row "Total RAM" "${TOTAL_RAM_MB}MB"
    table_row "Available Disk" "${AVAILABLE_DISK_GB}GB"
    table_row "OS" "${OS_NAME:-$(lsb_release -d | cut -f2)}"
    echo

    # Check services if installed
    echo -e "${COLOR_CYAN}Service Status:${COLOR_RESET}"
    echo

    # Detect PHP version if not set
    [[ -z "${PHP_MAJOR_VERSION:-}" ]] && check_php

    local services=("nginx" "mariadb" "mysql" "redis-server")

    # Add PHP-FPM service if version is known
    if [[ -n "${PHP_MAJOR_VERSION:-}" ]]; then
        services+=("php${PHP_MAJOR_VERSION}-fpm")
    fi

    for service in "${services[@]}"; do
        if systemctl list-unit-files | grep -q "^${service}.service"; then
            if is_service_running "$service"; then
                echo -e "  ${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} ${service} (running)"
            else
                echo -e "  ${COLOR_RED}${SYMBOL_CROSS}${COLOR_RESET} ${service} (stopped)"
            fi
        fi
    done

    echo
}

################################################################################
# System Requirements Validation
################################################################################

validate_requirements() {
    local errors=0

    log_step "Validating system requirements"

    # Check minimum RAM
    if [[ $TOTAL_RAM_MB -lt 512 ]]; then
        log_error "Minimum 512MB RAM required"
        ((errors++))
    fi

    # Check minimum disk space
    if [[ $AVAILABLE_DISK_GB -lt 10 ]]; then
        log_error "Minimum 10GB free disk space required"
        ((errors++))
    fi

    # Check Ubuntu version
    case "$OS_VERSION" in
        20.04|22.04|24.04)
            ;;
        *)
            log_warning "Ubuntu version $OS_VERSION is not officially supported"
            ;;
    esac

    if [[ $errors -gt 0 ]]; then
        log_error "System does not meet minimum requirements"
    else
        log_success "System requirements validated"
    fi
}

################################################################################
# Export Functions
################################################################################

export -f detect_os detect_cpu detect_ram detect_disk
export -f check_nginx check_mariadb check_php check_redis check_certbot
export -f calculate_resources
export -f display_software_status display_system_status
export -f validate_requirements
