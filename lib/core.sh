#!/usr/bin/env bash

################################################################################
# Core Utilities Library
#
# Provides: Logging, error handling, utility functions
################################################################################

# Color codes for output
declare -r COLOR_RESET='\033[0m'
declare -r COLOR_RED='\033[0;31m'
declare -r COLOR_GREEN='\033[0;32m'
declare -r COLOR_YELLOW='\033[0;33m'
declare -r COLOR_BLUE='\033[0;34m'
declare -r COLOR_MAGENTA='\033[0;35m'
declare -r COLOR_CYAN='\033[0;36m'
declare -r COLOR_WHITE='\033[0;37m'
declare -r COLOR_BOLD='\033[1m'

# Unicode symbols
declare -r SYMBOL_CHECK="✓"
declare -r SYMBOL_CROSS="✗"
declare -r SYMBOL_ARROW="→"
declare -r SYMBOL_INFO="ℹ"
declare -r SYMBOL_WARNING="⚠"

################################################################################
# Logging Functions
################################################################################

# Initialize logging
init_logging() {
    # Create log directory if it doesn't exist
    local log_dir="${BASE_DIR}/logs"
    if [[ ! -d "$log_dir" ]]; then
        mkdir -p "$log_dir"
    fi

    # Create or clear log files
    : > "${INSTALL_LOG}"
    : > "${ERROR_LOG}"

    # Log session start
    {
        echo "================================================================================"
        echo "Session started: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "================================================================================"
    } >> "${INSTALL_LOG}"
}

# Log to file
log_to_file() {
    local message="$1"
    local log_file="${2:-${INSTALL_LOG}}"

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" >> "$log_file"
}

# Info message (blue)
log_info() {
    local message="$1"
    echo -e "${COLOR_BLUE}${SYMBOL_INFO}${COLOR_RESET} ${message}"
    log_to_file "INFO: $message"
}

# Success message (green)
log_success() {
    local message="$1"
    echo -e "${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} ${message}"
    log_to_file "SUCCESS: $message"
}

# Warning message (yellow)
log_warning() {
    local message="$1"
    echo -e "${COLOR_YELLOW}${SYMBOL_WARNING}${COLOR_RESET} ${message}"
    log_to_file "WARNING: $message"
}

# Error message (red)
log_error() {
    local message="$1"
    echo -e "${COLOR_RED}${SYMBOL_CROSS}${COLOR_RESET} ${message}" >&2
    log_to_file "ERROR: $message" "${ERROR_LOG}"
    log_to_file "ERROR: $message" "${INSTALL_LOG}"

    # Exit if error
    exit 1
}

# Header message (bold cyan)
log_header() {
    local message="$1"
    echo
    echo -e "${COLOR_BOLD}${COLOR_CYAN}╔════════════════════════════════════════════════════════════════╗${COLOR_RESET}"
    printf "${COLOR_BOLD}${COLOR_CYAN}║${COLOR_RESET} %-62s ${COLOR_BOLD}${COLOR_CYAN}║${COLOR_RESET}\n" "$message"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}╚════════════════════════════════════════════════════════════════╝${COLOR_RESET}"
    echo
    log_to_file "HEADER: $message"
}

# Phase message (bold)
log_phase() {
    local message="$1"
    echo
    echo -e "${COLOR_BOLD}${COLOR_MAGENTA}▶ ${message}${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_MAGENTA}$(printf '─%.0s' {1..70})${COLOR_RESET}"
    log_to_file "PHASE: $message"
}

# Step message (simple arrow)
log_step() {
    local message="$1"
    echo -e "  ${COLOR_CYAN}${SYMBOL_ARROW}${COLOR_RESET} ${message}"
    log_to_file "STEP: $message"
}

# Progress indicator
show_progress() {
    local message="$1"
    echo -ne "${COLOR_BLUE}${message}...${COLOR_RESET} "
}

# Complete progress
complete_progress() {
    echo -e "${COLOR_GREEN}Done${COLOR_RESET}"
}

################################################################################
# Error Handling
################################################################################

# Cleanup function (called on error or exit)
cleanup() {
    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        echo
        log_warning "Script interrupted or encountered an error"
        log_info "Check logs at: ${INSTALL_LOG}"
        log_info "Error log: ${ERROR_LOG}"
    fi

    # Don't actually exit here, let the script exit naturally
    return $exit_code
}

# Handle errors gracefully
handle_error() {
    local line_num="$1"
    local error_code="${2:-1}"

    log_error "Error occurred in script at line ${line_num} (exit code: ${error_code})"
}

################################################################################
# System Checks
################################################################################

# Check if running as root or with sudo
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root or with sudo"
    fi
}

# Check internet connectivity
check_internet() {
    log_step "Checking internet connectivity"

    if ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
        log_success "Internet connection: OK"
        return 0
    else
        log_error "No internet connection. Please check your network settings."
    fi
}

# Check disk space
check_disk_space() {
    log_step "Checking available disk space"

    local available_gb=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')

    if [[ $available_gb -lt 10 ]]; then
        log_error "Insufficient disk space. Required: 10GB, Available: ${available_gb}GB"
    fi

    log_success "Available disk space: ${available_gb}GB"
}

################################################################################
# Directory Management
################################################################################

# Create necessary directories
create_dirs() {
    log_step "Creating directory structure"

    local dirs=(
        "${BASE_DIR}/lib"
        "${BASE_DIR}/templates/nginx"
        "${BASE_DIR}/templates/php"
        "${BASE_DIR}/templates/mysql"
        "${BASE_DIR}/templates/redis"
        "${BASE_DIR}/scripts"
        "${BASE_DIR}/config"
        "${BASE_DIR}/logs"
        "${BASE_DIR}/backups/databases"
        "${BASE_DIR}/backups/files"
        "/var/www"
        "/var/cache/nginx"
    )

    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
        fi
    done

    log_success "Directory structure created"
}

################################################################################
# Utility Functions
################################################################################

# Generate random password
generate_password() {
    local length="${1:-32}"
    tr -dc 'A-Za-z0-9!@#$%^&*' < /dev/urandom | head -c "$length"
}

# Generate random alphanumeric string
generate_random_string() {
    local length="${1:-16}"
    tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$length"
}

# Validate domain name
validate_domain() {
    local domain="$1"

    # Basic domain validation regex
    local domain_regex='^([a-zA-Z0-9]([-a-zA-Z0-9]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$'

    if [[ $domain =~ $domain_regex ]]; then
        return 0
    else
        return 1
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" &>/dev/null
}

# Check if service is running
is_service_running() {
    local service="$1"
    systemctl is-active --quiet "$service"
}

# Check if service is enabled
is_service_enabled() {
    local service="$1"
    systemctl is-enabled --quiet "$service"
}

# Start and enable service
start_enable_service() {
    local service="$1"

    if ! is_service_running "$service"; then
        systemctl start "$service"
        log_success "Started ${service}"
    fi

    if ! is_service_enabled "$service"; then
        systemctl enable "$service" &>/dev/null
        log_success "Enabled ${service} to start on boot"
    fi
}

# Restart service
restart_service() {
    local service="$1"
    systemctl restart "$service"
    log_success "Restarted ${service}"
}

# Reload service
reload_service() {
    local service="$1"
    systemctl reload "$service"
    log_success "Reloaded ${service}"
}

################################################################################
# File Operations
################################################################################

# Backup file before modifying
backup_file() {
    local file="$1"
    local backup_suffix=".backup.$(date +%Y%m%d_%H%M%S)"

    if [[ -f "$file" ]]; then
        cp "$file" "${file}${backup_suffix}"
        log_step "Backed up: $file"
    fi
}

# Create file from template with variable substitution
create_from_template() {
    local template="$1"
    local output="$2"
    shift 2
    local -n vars=$1

    if [[ ! -f "$template" ]]; then
        log_error "Template not found: $template"
    fi

    # Read template
    local content
    content=$(cat "$template")

    # Replace variables
    for var in "${!vars[@]}"; do
        content="${content//\{${var}\}/${vars[$var]}}"
    done

    # Write output
    echo "$content" > "$output"
}

# Set file ownership and permissions
set_ownership() {
    local path="$1"
    local owner="${2:-www-data:www-data}"
    local dir_perms="${3:-755}"
    local file_perms="${4:-644}"

    if [[ -d "$path" ]]; then
        chown -R "$owner" "$path"
        find "$path" -type d -exec chmod "$dir_perms" {} \;
        find "$path" -type f -exec chmod "$file_perms" {} \;
    elif [[ -f "$path" ]]; then
        chown "$owner" "$path"
        chmod "$file_perms" "$path"
    fi
}

################################################################################
# Confirmation Prompts
################################################################################

# Ask yes/no question
confirm() {
    local question="$1"
    local default="${2:-N}"

    local prompt
    if [[ $default == "Y" ]]; then
        prompt="[Y/n]"
    else
        prompt="[y/N]"
    fi

    read -p "$question $prompt " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Pause and wait for user
pause() {
    local message="${1:-Press any key to continue...}"
    read -n 1 -s -r -p "$message"
    echo
}

################################################################################
# Display Functions
################################################################################

# Display a table row
table_row() {
    local col1="$1"
    local col2="$2"
    printf "  %-30s : %s\n" "$col1" "$col2"
}

# Display system information
display_system_info() {
    log_header "System Information"

    table_row "CPU Cores" "${CPU_CORES:-N/A}"
    table_row "Total RAM" "${TOTAL_RAM_MB:-N/A} MB"
    table_row "Available Disk" "${AVAILABLE_DISK_GB:-N/A} GB"
    table_row "OS" "${OS_NAME:-N/A} ${OS_VERSION:-N/A}"
    table_row "Architecture" "$(uname -m)"

    if [[ -n "${NGINX_WORKERS:-}" ]]; then
        echo
        log_info "Calculated Configuration Values:"
        table_row "Nginx Workers" "${NGINX_WORKERS}"
        table_row "PHP Max Children" "${PHP_MAX_CHILDREN:-N/A}"
        table_row "InnoDB Buffer Pool" "${INNODB_BUFFER_POOL:-N/A} MB"
        table_row "Redis Max Memory" "${REDIS_MAXMEMORY:-N/A} MB"
    fi
}

# Display installation summary
display_installation_summary() {
    log_header "Installation Summary"

    echo -e "${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} LEMP Stack Components:"
    table_row "Nginx" "${NGINX_VERSION:-Installed}"
    table_row "MariaDB" "${MARIADB_VERSION:-Installed}"
    table_row "PHP-FPM" "${PHP_VERSION:-Installed}"
    table_row "Redis" "${REDIS_VERSION:-Installed}"

    echo
    echo -e "${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} Security:"
    table_row "Firewall (UFW)" "Configured"
    table_row "MySQL" "Secured"

    echo
    echo -e "${COLOR_GREEN}${SYMBOL_CHECK}${COLOR_RESET} Automation:"
    table_row "Daily Backups" "Scheduled (2 AM)"
    table_row "SSL Renewal" "Automated (certbot)"

    echo
    log_info "Credentials stored in: ${CREDENTIALS_FILE}"
    log_info "Logs directory: ${BASE_DIR}/logs"
    log_info "Configuration: ${CONFIG_FILE}"
}

################################################################################
# Export Functions
################################################################################

# Export all functions so they're available in subshells
export -f log_info log_success log_warning log_error log_header log_phase log_step
export -f show_progress complete_progress
export -f cleanup handle_error
export -f check_root check_internet check_disk_space
export -f create_dirs
export -f generate_password generate_random_string validate_domain
export -f command_exists is_service_running is_service_enabled
export -f start_enable_service restart_service reload_service
export -f backup_file create_from_template set_ownership
export -f confirm pause
export -f table_row display_system_info display_installation_summary
