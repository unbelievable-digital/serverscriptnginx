#!/usr/bin/env bash

################################################################################
# Interactive Menu Library
#
# Provides: Menu-driven interface for WordPress LEMP server management
################################################################################

show_main_menu() {
    while true; do
        clear
        cat << "EOF"
╔════════════════════════════════════════════════════════════════╗
║           WordPress LEMP Server Management                     ║
╚════════════════════════════════════════════════════════════════╝
EOF
        echo
        echo "  1. Install New WordPress Site"
        echo "  2. List All WordPress Sites"
        echo "  3. Manage Existing Site"
        echo "  4. Reconfigure All Sites (Fix MIME types & optimize)"
        echo "  5. System Status & Monitoring"
        echo "  6. Backup Management"
        echo "  7. Performance Tuning"
        echo "  8. Security Management"
        echo "  9. Exit"
        echo
        read -p "Enter choice [1-9]: " choice

        case $choice in
            1) menu_add_site ;;
            2) menu_list_sites ;;
            3) menu_manage_site ;;
            4) reconfigure_all_sites; pause ;;
            5) menu_system_status ;;
            6) menu_backup ;;
            7) menu_performance ;;
            8) menu_security ;;
            9) exit 0 ;;
            *) log_error "Invalid option" ;;
        esac
    done
}

menu_add_site() {
    clear
    add_wordpress_site
    pause
}

menu_list_sites() {
    clear
    list_sites
    pause
}

menu_manage_site() {
    clear
    list_sites
    echo
    read -p "Enter domain to manage: " domain

    if [[ -z "$domain" ]]; then
        return
    fi

    while true; do
        clear
        echo "Managing: $domain"
        echo
        echo "  1. Install SSL Certificate"
        echo "  2. Backup Site"
        echo "  3. Reconfigure Nginx (Fix MIME types & optimize)"
        echo "  4. Remove Site"
        echo "  5. Back to Main Menu"
        echo
        read -p "Enter choice [1-5]: " choice

        case $choice in
            1) install_ssl "$domain"; pause ;;
            2) backup_site "$domain"; pause ;;
            3) reconfigure_site "$domain"; pause ;;
            4) remove_site "$domain"; pause; break ;;
            5) break ;;
            *) log_error "Invalid option"; pause ;;
        esac
    done
}

menu_system_status() {
    clear
    display_system_status
    echo
    echo "Service Status:"
    systemctl status nginx --no-pager -l | head -10
    echo
    systemctl status mariadb --no-pager -l | head -10
    pause
}

menu_backup() {
    clear
    echo "Backup Management"
    echo
    echo "  1. Backup All Sites"
    echo "  2. Backup Single Site"
    echo "  3. List Backups"
    echo "  4. Back to Main Menu"
    echo
    read -p "Enter choice [1-4]: " choice

    case $choice in
        1) backup_all_sites; pause ;;
        2)
            read -p "Enter domain: " domain
            backup_site "$domain"
            pause
            ;;
        3)
            ls -lh "${BASE_DIR}/backups/" 2>/dev/null || echo "No backups found"
            pause
            ;;
        4) return ;;
    esac
}

menu_performance() {
    while true; do
        clear
        echo "Performance Tuning"
        echo
        echo "  1. Show All Performance Settings"
        echo "  2. Show PHP Configuration"
        echo "  3. Show MySQL Configuration"
        echo "  4. Show Nginx Configuration"
        echo "  5. Show Redis Configuration"
        echo "  6. Recalculate Resources"
        echo "  7. Clear All Caches"
        echo "  8. Save Configuration Report"
        echo "  9. Back to Main Menu"
        echo
        read -p "Enter choice [1-9]: " choice

        case $choice in
            1)
                show_all_performance_settings
                pause
                ;;
            2)
                show_php_settings
                pause
                ;;
            3)
                show_mysql_settings
                pause
                ;;
            4)
                show_nginx_settings
                pause
                ;;
            5)
                show_redis_settings
                pause
                ;;
            6)
                detect_cpu
                detect_ram
                calculate_resources
                display_system_info
                pause
                ;;
            7)
                log_info "Clearing caches..."
                redis-cli FLUSHALL &>/dev/null
                rm -rf /var/cache/nginx/*
                log_success "Caches cleared"
                pause
                ;;
            8)
                save_performance_report
                pause
                ;;
            9) return ;;
            *)
                log_error "Invalid option"
                sleep 1
                ;;
        esac
    done
}

################################################################################
# Performance Settings Display Functions
################################################################################

show_php_settings() {
    clear
    log_header "PHP Configuration Settings"

    # Detect PHP version if not set
    local php_version="${PHP_MAJOR_VERSION:-}"
    if [[ -z "$php_version" ]]; then
        if command_exists php; then
            php_version=$(php -r 'echo PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION;' 2>/dev/null)
        fi
    fi

    if [[ -z "$php_version" ]]; then
        log_error "PHP not found"
        return 1
    fi

    local php_ini="/etc/php/${php_version}/fpm/php.ini"
    local pool_conf="/etc/php/${php_version}/fpm/pool.d/www.conf"

    echo -e "${COLOR_CYAN}PHP Version:${COLOR_RESET} ${php_version}"
    echo -e "${COLOR_CYAN}Configuration File:${COLOR_RESET} ${php_ini}"
    echo

    # Display key PHP settings
    echo -e "${COLOR_YELLOW}Memory & Limits:${COLOR_RESET}"
    grep -E "^memory_limit|^upload_max_filesize|^post_max_size|^max_execution_time|^max_input_time" "$php_ini" 2>/dev/null | sed 's/^/  /'
    echo

    echo -e "${COLOR_YELLOW}OPcache Settings:${COLOR_RESET}"
    grep -E "^opcache\." "$php_ini" 2>/dev/null | grep -v "^;" | sed 's/^/  /' | head -10
    echo

    if [[ -f "$pool_conf" ]]; then
        echo -e "${COLOR_YELLOW}PHP-FPM Pool Settings:${COLOR_RESET}"
        echo -e "${COLOR_CYAN}Pool Configuration:${COLOR_RESET} ${pool_conf}"
        echo
        grep -E "^pm =|^pm\.max_children|^pm\.start_servers|^pm\.min_spare|^pm\.max_spare|^pm\.max_requests" "$pool_conf" 2>/dev/null | sed 's/^/  /'
        echo
    fi

    # Show loaded PHP modules
    echo -e "${COLOR_YELLOW}Critical PHP Modules:${COLOR_RESET}"
    php -m 2>/dev/null | grep -E "mysqli|curl|gd|mbstring|xml|redis|imagick|opcache|zip" | sed 's/^/  ✓ /'
    echo
}

show_mysql_settings() {
    clear
    log_header "MariaDB/MySQL Configuration Settings"

    # Check if MySQL is installed
    if ! command_exists mysql && ! command_exists mariadb; then
        log_error "MariaDB/MySQL not found"
        return 1
    fi

    # Get MySQL version
    local mysql_version=""
    if command_exists mariadb; then
        mysql_version=$(mariadb --version 2>/dev/null | grep -oP 'Distrib \K[0-9.]+')
        echo -e "${COLOR_CYAN}MariaDB Version:${COLOR_RESET} ${mysql_version}"
    else
        mysql_version=$(mysql --version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        echo -e "${COLOR_CYAN}MySQL Version:${COLOR_RESET} ${mysql_version}"
    fi
    echo

    # Show configuration file
    local mysql_conf="/etc/mysql/mariadb.conf.d/99-custom.cnf"
    if [[ -f "$mysql_conf" ]]; then
        echo -e "${COLOR_CYAN}Custom Configuration:${COLOR_RESET} ${mysql_conf}"
        echo
        echo -e "${COLOR_YELLOW}InnoDB Settings:${COLOR_RESET}"
        grep -E "^innodb_buffer_pool_size|^innodb_log_file_size|^innodb_file_per_table|^innodb_flush" "$mysql_conf" 2>/dev/null | sed 's/^/  /'
        echo

        echo -e "${COLOR_YELLOW}Connection & Performance:${COLOR_RESET}"
        grep -E "^max_connections|^table_open_cache|^tmp_table_size|^max_heap_table_size" "$mysql_conf" 2>/dev/null | sed 's/^/  /'
        echo

        echo -e "${COLOR_YELLOW}Logging:${COLOR_RESET}"
        grep -E "^slow_query_log|^long_query_time" "$mysql_conf" 2>/dev/null | sed 's/^/  /'
        echo
    fi

    # Show live MySQL variables
    echo -e "${COLOR_YELLOW}Current Runtime Values:${COLOR_RESET}"
    mysql -e "SHOW VARIABLES LIKE 'innodb_buffer_pool_size';" 2>/dev/null | tail -1 | awk '{printf "  innodb_buffer_pool_size = %s\n", $2}'
    mysql -e "SHOW VARIABLES LIKE 'max_connections';" 2>/dev/null | tail -1 | awk '{printf "  max_connections = %s\n", $2}'
    echo
}

show_nginx_settings() {
    clear
    log_header "Nginx Configuration Settings"

    if ! command_exists nginx; then
        log_error "Nginx not found"
        return 1
    fi

    # Get Nginx version
    local nginx_version=$(nginx -v 2>&1 | grep -oP 'nginx/\K[0-9.]+')
    echo -e "${COLOR_CYAN}Nginx Version:${COLOR_RESET} ${nginx_version}"
    echo -e "${COLOR_CYAN}Configuration File:${COLOR_RESET} /etc/nginx/nginx.conf"
    echo

    # Show worker processes
    echo -e "${COLOR_YELLOW}Worker Configuration:${COLOR_RESET}"
    grep -E "^worker_processes|^worker_connections" /etc/nginx/nginx.conf 2>/dev/null | sed 's/^/  /'
    echo

    # Show cache settings
    echo -e "${COLOR_YELLOW}FastCGI Cache:${COLOR_RESET}"
    grep -E "fastcgi_cache_path|fastcgi_cache_key" /etc/nginx/nginx.conf 2>/dev/null | sed 's/^/  /'
    echo

    # Show client settings
    echo -e "${COLOR_YELLOW}Client Settings:${COLOR_RESET}"
    grep -E "client_max_body_size|keepalive_timeout" /etc/nginx/nginx.conf 2>/dev/null | sed 's/^/  /'
    echo

    # Show gzip settings
    echo -e "${COLOR_YELLOW}Gzip Compression:${COLOR_RESET}"
    grep -E "^    gzip " /etc/nginx/nginx.conf 2>/dev/null | sed 's/^/  /' | head -5
    echo

    # List enabled sites
    echo -e "${COLOR_YELLOW}Enabled Sites:${COLOR_RESET}"
    ls -1 /etc/nginx/sites-enabled/ 2>/dev/null | sed 's/^/  ✓ /'
    echo
}

show_redis_settings() {
    clear
    log_header "Redis Configuration Settings"

    if ! command_exists redis-server; then
        log_error "Redis not found"
        return 1
    fi

    # Get Redis version
    local redis_version=$(redis-server --version 2>/dev/null | grep -oP 'v=\K[0-9.]+')
    echo -e "${COLOR_CYAN}Redis Version:${COLOR_RESET} ${redis_version}"
    echo -e "${COLOR_CYAN}Configuration File:${COLOR_RESET} /etc/redis/redis.conf"
    echo

    # Show memory settings
    echo -e "${COLOR_YELLOW}Memory Settings:${COLOR_RESET}"
    grep -E "^maxmemory " /etc/redis/redis.conf 2>/dev/null | sed 's/^/  /'
    grep -E "^maxmemory-policy" /etc/redis/redis.conf 2>/dev/null | sed 's/^/  /'
    echo

    # Show persistence settings
    echo -e "${COLOR_YELLOW}Persistence:${COLOR_RESET}"
    if grep -E "^save " /etc/redis/redis.conf &>/dev/null; then
        echo -e "  ${COLOR_GREEN}Enabled${COLOR_RESET}"
        grep -E "^save " /etc/redis/redis.conf 2>/dev/null | sed 's/^/    /'
    else
        echo -e "  ${COLOR_YELLOW}Disabled (optimized for object cache)${COLOR_RESET}"
    fi
    echo

    # Show runtime info
    echo -e "${COLOR_YELLOW}Runtime Information:${COLOR_RESET}"
    if redis-cli ping &>/dev/null; then
        echo -e "  Status: ${COLOR_GREEN}Running${COLOR_RESET}"
        redis-cli INFO memory 2>/dev/null | grep -E "used_memory_human|maxmemory_human" | sed 's/^/  /'
        redis-cli INFO stats 2>/dev/null | grep -E "total_connections_received|total_commands_processed" | sed 's/^/  /'
    else
        echo -e "  Status: ${COLOR_RED}Not Running${COLOR_RESET}"
    fi
    echo
}

show_all_performance_settings() {
    clear
    log_header "Complete Performance Configuration"

    # System Resources
    echo -e "${COLOR_CYAN}=== System Resources ===${COLOR_RESET}"
    echo
    detect_cpu &>/dev/null
    detect_ram &>/dev/null
    detect_disk &>/dev/null
    table_row "CPU Cores" "${CPU_CORES:-N/A}"
    table_row "Total RAM" "${TOTAL_RAM_MB:-N/A}MB"
    table_row "Available Disk" "${AVAILABLE_DISK_GB:-N/A}GB"
    echo

    # Calculated values
    calculate_resources &>/dev/null
    echo -e "${COLOR_CYAN}=== Calculated Resource Allocations ===${COLOR_RESET}"
    echo
    table_row "Nginx Workers" "${NGINX_WORKERS:-N/A}"
    table_row "PHP Max Children" "${PHP_MAX_CHILDREN:-N/A}"
    table_row "PHP Start Servers" "${PHP_START_SERVERS:-N/A}"
    table_row "PHP Memory Limit" "${PHP_MEMORY_LIMIT:-N/A}"
    table_row "Upload Max Size" "${UPLOAD_MAX_SIZE:-N/A}"
    table_row "InnoDB Buffer Pool" "${INNODB_BUFFER_POOL:-N/A}M"
    table_row "MySQL Max Connections" "${MAX_CONNECTIONS:-N/A}"
    table_row "Redis Max Memory" "${REDIS_MAXMEMORY:-N/A}MB"
    echo

    # Service status
    echo -e "${COLOR_CYAN}=== Service Status ===${COLOR_RESET}"
    echo
    for service in nginx mariadb redis-server; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            echo -e "  ${COLOR_GREEN}✓${COLOR_RESET} ${service} - Running"
        else
            echo -e "  ${COLOR_RED}✗${COLOR_RESET} ${service} - Stopped"
        fi
    done

    # PHP-FPM
    local php_version="${PHP_MAJOR_VERSION:-}"
    if [[ -z "$php_version" ]] && command_exists php; then
        php_version=$(php -r 'echo PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION;' 2>/dev/null)
    fi
    if [[ -n "$php_version" ]]; then
        if systemctl is-active --quiet "php${php_version}-fpm" 2>/dev/null; then
            echo -e "  ${COLOR_GREEN}✓${COLOR_RESET} php${php_version}-fpm - Running"
        else
            echo -e "  ${COLOR_RED}✗${COLOR_RESET} php${php_version}-fpm - Stopped"
        fi
    fi
    echo

    echo -e "${COLOR_YELLOW}Tip: Use options 2-5 to view detailed settings for each component${COLOR_RESET}"
    echo
}

save_performance_report() {
    clear
    log_step "Generating performance configuration report"

    local report_file="${BASE_DIR}/logs/performance-report-$(date +%Y%m%d_%H%M%S).txt"

    # Detect resources
    detect_cpu &>/dev/null
    detect_ram &>/dev/null
    detect_disk &>/dev/null
    calculate_resources &>/dev/null

    # Detect PHP version
    local php_version="${PHP_MAJOR_VERSION:-}"
    if [[ -z "$php_version" ]] && command_exists php; then
        php_version=$(php -r 'echo PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION;' 2>/dev/null)
    fi

    cat > "$report_file" <<EOF
================================================================================
WordPress LEMP Server - Performance Configuration Report
================================================================================
Generated: $(date '+%Y-%m-%d %H:%M:%S')

================================================================================
SYSTEM RESOURCES
================================================================================
CPU Cores:              ${CPU_CORES:-N/A}
Total RAM:              ${TOTAL_RAM_MB:-N/A}MB (~$((${TOTAL_RAM_MB:-0} / 1024))GB)
Available Disk:         ${AVAILABLE_DISK_GB:-N/A}GB
OS:                     $(lsb_release -d 2>/dev/null | cut -f2)

================================================================================
CALCULATED RESOURCE ALLOCATIONS
================================================================================
Nginx Workers:          ${NGINX_WORKERS:-N/A}
PHP Max Children:       ${PHP_MAX_CHILDREN:-N/A}
PHP Start Servers:      ${PHP_START_SERVERS:-N/A}
PHP Min Spare:          ${PHP_MIN_SPARE:-N/A}
PHP Max Spare:          ${PHP_MAX_SPARE:-N/A}
PHP Memory Limit:       ${PHP_MEMORY_LIMIT:-N/A}
Upload Max Size:        ${UPLOAD_MAX_SIZE:-N/A}
Post Max Size:          ${POST_MAX_SIZE:-N/A}
InnoDB Buffer Pool:     ${INNODB_BUFFER_POOL:-N/A}M
InnoDB Log File Size:   ${INNODB_LOG_FILE_SIZE:-N/A}M
MySQL Max Connections:  ${MAX_CONNECTIONS:-N/A}
Redis Max Memory:       ${REDIS_MAXMEMORY:-N/A}MB

================================================================================
PHP CONFIGURATION
================================================================================
PHP Version:            ${php_version:-N/A}
Configuration File:     /etc/php/${php_version}/fpm/php.ini

Key Settings:
$(grep -E "^memory_limit|^upload_max_filesize|^post_max_size|^max_execution_time" /etc/php/${php_version}/fpm/php.ini 2>/dev/null | sed 's/^/  /')

PHP-FPM Pool (/etc/php/${php_version}/fpm/pool.d/www.conf):
$(grep -E "^pm =|^pm\.max_children|^pm\.start_servers|^pm\.min_spare|^pm\.max_spare" /etc/php/${php_version}/fpm/pool.d/www.conf 2>/dev/null | sed 's/^/  /')

Loaded Modules:
$(php -m 2>/dev/null | grep -E "mysqli|curl|gd|mbstring|xml|redis|imagick|opcache" | sed 's/^/  /')

================================================================================
NGINX CONFIGURATION
================================================================================
Version:                $(nginx -v 2>&1 | grep -oP 'nginx/\K[0-9.]+')
Configuration:          /etc/nginx/nginx.conf

Worker Settings:
$(grep -E "^worker_processes|^worker_connections" /etc/nginx/nginx.conf 2>/dev/null | sed 's/^/  /')

FastCGI Cache:
$(grep -E "fastcgi_cache_path" /etc/nginx/nginx.conf 2>/dev/null | sed 's/^/  /')

Client Settings:
$(grep -E "client_max_body_size|keepalive_timeout" /etc/nginx/nginx.conf 2>/dev/null | sed 's/^/  /')

Enabled Sites:
$(ls -1 /etc/nginx/sites-enabled/ 2>/dev/null | sed 's/^/  /')

================================================================================
MARIADB/MYSQL CONFIGURATION
================================================================================
Version:                $(mariadb --version 2>/dev/null | grep -oP 'Distrib \K[0-9.]+' || mysql --version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
Custom Configuration:   /etc/mysql/mariadb.conf.d/99-custom.cnf

InnoDB Settings:
$(grep -E "^innodb_buffer_pool_size|^innodb_log_file_size|^innodb_file_per_table" /etc/mysql/mariadb.conf.d/99-custom.cnf 2>/dev/null | sed 's/^/  /')

Connection Settings:
$(grep -E "^max_connections" /etc/mysql/mariadb.conf.d/99-custom.cnf 2>/dev/null | sed 's/^/  /')

================================================================================
REDIS CONFIGURATION
================================================================================
Version:                $(redis-server --version 2>/dev/null | grep -oP 'v=\K[0-9.]+')
Configuration:          /etc/redis/redis.conf

Memory Settings:
$(grep -E "^maxmemory|^maxmemory-policy" /etc/redis/redis.conf 2>/dev/null | sed 's/^/  /')

Runtime Stats:
$(redis-cli INFO memory 2>/dev/null | grep -E "used_memory_human|maxmemory_human" | sed 's/^/  /')

================================================================================
SERVICE STATUS
================================================================================
$(systemctl is-active nginx &>/dev/null && echo "Nginx:              Running" || echo "Nginx:              Stopped")
$(systemctl is-active mariadb &>/dev/null && echo "MariaDB:            Running" || echo "MariaDB:            Stopped")
$(systemctl is-active redis-server &>/dev/null && echo "Redis:              Running" || echo "Redis:              Stopped")
$(systemctl is-active php${php_version}-fpm &>/dev/null && echo "PHP-FPM:            Running" || echo "PHP-FPM:            Stopped")

================================================================================
NOTES
================================================================================
- This report was automatically generated based on detected system resources
- Resource allocations are optimized for WordPress hosting workloads
- All configurations can be manually adjusted if needed
- Configuration files are backed up before modifications

For detailed component settings, use the menu options 2-5 in Performance Tuning.

================================================================================
EOF

    log_success "Performance report saved to: $report_file"
    echo
    echo -e "${COLOR_CYAN}Report location:${COLOR_RESET} $report_file"
    echo
    read -p "View report now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        less "$report_file"
    fi
}

menu_security() {
    clear
    echo "Security Management"
    echo
    echo "  1. Show Firewall Status"
    echo "  2. List SSL Certificates"
    echo "  3. Renew SSL Certificates"
    echo "  4. Back to Main Menu"
    echo
    read -p "Enter choice [1-4]: " choice

    case $choice in
        1) ufw status verbose; pause ;;
        2) list_certificates; pause ;;
        3) renew_ssl; pause ;;
        4) return ;;
    esac
}

export -f show_main_menu menu_add_site menu_list_sites menu_manage_site
export -f menu_system_status menu_backup menu_performance menu_security
export -f show_php_settings show_mysql_settings show_nginx_settings show_redis_settings
export -f show_all_performance_settings save_performance_report
