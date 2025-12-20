#!/usr/bin/env bash

################################################################################
# WordPress Management Library
#
# Provides: WordPress installation, site management, and operations
################################################################################

################################################################################
# WordPress Site Installation
################################################################################

add_wordpress_site() {
    local domain="${1:-}"

    log_header "WordPress Site Installation"

    # Get domain if not provided
    if [[ -z "$domain" ]]; then
        echo
        read -p "Enter domain name (e.g., example.com): " domain
    fi

    # Validate domain
    if ! validate_domain "$domain"; then
        log_error "Invalid domain name: $domain"
    fi

    # Check if site already exists
    if [[ -d "/var/www/${domain}" ]]; then
        log_warning "Site directory already exists at /var/www/${domain}"
        echo
        echo "This could be from an incomplete installation. Options:"
        echo "  1. Remove and start fresh (recommended for incomplete installations)"
        echo "  2. Cancel and keep existing files"
        echo
        read -p "Enter choice [1-2]: " choice

        case $choice in
            1)
                log_warning "Removing existing site directory..."
                # Get database name if it exists in config
                local old_db_name=$(grep "^${domain}|" "$CONFIG_FILE" 2>/dev/null | cut -d'|' -f2)
                local old_db_user=$(grep "^${domain}|" "$CONFIG_FILE" 2>/dev/null | cut -d'|' -f3)

                # Remove database if exists
                if [[ -n "$old_db_name" ]]; then
                    mysql -e "DROP DATABASE IF EXISTS ${old_db_name};" 2>/dev/null
                    mysql -e "DROP USER IF EXISTS '${old_db_user}'@'localhost';" 2>/dev/null
                    log_info "Removed old database: ${old_db_name}"
                fi

                # Remove directory
                rm -rf "/var/www/${domain}"

                # Remove from registry
                sed -i "/^${domain}|/d" "$CONFIG_FILE" 2>/dev/null

                # Remove nginx config
                rm -f "/etc/nginx/sites-enabled/${domain}" 2>/dev/null
                rm -f "/etc/nginx/sites-available/${domain}" 2>/dev/null

                log_success "Old installation removed, starting fresh..."
                echo
                ;;
            2)
                log_info "Installation cancelled"
                return 0
                ;;
            *)
                log_error "Invalid choice"
                ;;
        esac
    fi

    log_info "Setting up WordPress site for: ${domain}"
    echo

    # Generate database credentials
    local db_name="wp_$(generate_random_string 8)"
    local db_user="wp_$(generate_random_string 8)"
    local db_pass="$(generate_password 32)"
    local wp_admin_pass="$(generate_password 16)"

    # Create directory structure
    log_step "Creating directory structure"
    local site_root="/var/www/${domain}"
    mkdir -p "${site_root}"/{public_html,logs,ssl}
    log_success "Directories created at ${site_root}"

    # Create database and user
    log_step "Creating database and user"
    mysql -e "CREATE DATABASE IF NOT EXISTS ${db_name};" 2>/dev/null
    mysql -e "CREATE USER IF NOT EXISTS '${db_user}'@'localhost' IDENTIFIED BY '${db_pass}';" 2>/dev/null
    mysql -e "GRANT ALL PRIVILEGES ON ${db_name}.* TO '${db_user}'@'localhost';" 2>/dev/null
    mysql -e "FLUSH PRIVILEGES;" 2>/dev/null
    log_success "Database '${db_name}' and user '${db_user}' created"

    # Download WordPress
    log_step "Downloading WordPress"
    cd "${site_root}/public_html"
    if command_exists wp; then
        wp core download --allow-root &>/dev/null
    else
        curl -sS https://wordpress.org/latest.tar.gz | tar -xz --strip-components=1
    fi
    log_success "WordPress downloaded"

    # Generate wp-config.php
    log_step "Configuring WordPress"
    if command_exists wp; then
        wp config create \
            --dbname="$db_name" \
            --dbuser="$db_user" \
            --dbpass="$db_pass" \
            --dbhost="localhost" \
            --allow-root &>/dev/null
    else
        cp wp-config-sample.php wp-config.php
        sed -i "s/database_name_here/${db_name}/" wp-config.php
        sed -i "s/username_here/${db_user}/" wp-config.php
        sed -i "s/password_here/${db_pass}/" wp-config.php
    fi

    # Get WordPress salts
    log_step "Adding security keys"
    local salts=$(curl -sS https://api.wordpress.org/secret-key/1.1/salt/)
    if [[ -n "$salts" ]]; then
        # Save salts to temporary file
        echo "$salts" > /tmp/wp-salts.txt

        # Remove existing salt definitions
        sed -i "/define( *'AUTH_KEY'/,/define( *'NONCE_SALT'/d" wp-config.php

        # Insert new salts after DB_COLLATE line using a more reliable method
        # Find the line number of DB_COLLATE
        local insert_line=$(grep -n "DB_COLLATE" wp-config.php | cut -d: -f1)
        if [[ -n "$insert_line" ]]; then
            # Split file at insertion point and insert salts
            head -n "$insert_line" wp-config.php > /tmp/wp-config-part1.php
            echo "" >> /tmp/wp-config-part1.php
            cat /tmp/wp-salts.txt >> /tmp/wp-config-part1.php
            echo "" >> /tmp/wp-config-part1.php
            tail -n +$((insert_line + 1)) wp-config.php >> /tmp/wp-config-part1.php
            mv /tmp/wp-config-part1.php wp-config.php
        fi

        # Clean up temp file
        rm -f /tmp/wp-salts.txt
    fi

    # Add Redis configuration
    cat >> wp-config.php <<'REDIS_CONFIG'

// Redis Object Cache Configuration
define('WP_REDIS_HOST', '127.0.0.1');
define('WP_REDIS_PORT', 6379);
define('WP_CACHE', true);

// Security
define('DISALLOW_FILE_EDIT', true);
define('FORCE_SSL_ADMIN', true);

// WordPress Auto-Updates
define('WP_AUTO_UPDATE_CORE', 'minor');
REDIS_CONFIG

    log_success "WordPress configured"

    # Set permissions
    log_step "Setting file permissions"
    chown -R www-data:www-data "${site_root}/public_html"
    find "${site_root}/public_html" -type d -exec chmod 755 {} \;
    find "${site_root}/public_html" -type f -exec chmod 644 {} \;
    chmod 440 "${site_root}/public_html/wp-config.php"
    log_success "Permissions set"

    # Create Nginx configuration
    log_step "Creating Nginx configuration"
    generate_nginx_site "$domain" "${site_root}/public_html"

    # Test Nginx configuration
    if validate_nginx_config "$domain"; then
        reload_service nginx
    else
        log_error "Nginx configuration invalid"
    fi

    # Register site in config
    register_site "$domain" "$db_name" "$db_user"

    # Store credentials
    store_credentials "$domain" "$db_name" "$db_user" "$db_pass" "$wp_admin_pass"

    # Auto-install WordPress if WP-CLI is available
    local wp_admin_user=""
    local wp_admin_email=""
    local site_title=""

    if command_exists wp; then
        log_step "Installing WordPress automatically"

        # Get WordPress admin details
        read -p "WordPress admin username [admin]: " wp_admin_user
        wp_admin_user="${wp_admin_user:-admin}"

        read -p "WordPress admin email: " wp_admin_email
        while [[ -z "$wp_admin_email" ]]; do
            read -p "Email is required. WordPress admin email: " wp_admin_email
        done

        read -p "Site title [${domain}]: " site_title
        site_title="${site_title:-${domain}}"

        # Install WordPress
        cd "${site_root}/public_html"
        if wp core install \
            --url="http://${domain}" \
            --title="$site_title" \
            --admin_user="$wp_admin_user" \
            --admin_password="$wp_admin_pass" \
            --admin_email="$wp_admin_email" \
            --allow-root &>/dev/null; then

            log_success "WordPress installed successfully!"

            # Install and activate Redis Object Cache plugin
            log_step "Installing Redis Object Cache plugin"
            wp plugin install redis-cache --activate --allow-root &>/dev/null
            wp redis enable --allow-root &>/dev/null
            log_success "Redis Object Cache enabled"
        else
            log_warning "WordPress auto-install failed, you can complete it manually"
        fi
    else
        log_info "WP-CLI not available, WordPress installation must be completed via web browser"
    fi

    # Create detailed installation report
    local report_file="${BASE_DIR}/logs/site-${domain}-$(date +%Y%m%d_%H%M%S).txt"

    cat > "$report_file" <<EOF
================================================================================
WordPress Site Installation Report
================================================================================

Installation Date: $(date '+%Y-%m-%d %H:%M:%S')
Server: $(hostname)
Server IP: $(hostname -I | awk '{print $1}')

================================================================================
SITE INFORMATION
================================================================================

Domain:              ${domain}
Site Title:          ${site_title:-"Not installed"}
Site URL:            http://${domain}
Site Root:           ${site_root}/public_html
Logs Directory:      ${site_root}/logs
SSL Directory:       ${site_root}/ssl

================================================================================
DATABASE CREDENTIALS
================================================================================

Database Name:       ${db_name}
Database User:       ${db_user}
Database Password:   ${db_pass}
Database Host:       localhost

================================================================================
WORDPRESS ADMIN CREDENTIALS
================================================================================

Admin Username:      ${wp_admin_user:-"Setup via browser"}
Admin Password:      ${wp_admin_pass}
Admin Email:         ${wp_admin_email:-"Setup via browser"}
Admin URL:           http://${domain}/wp-admin

================================================================================
SERVER CONFIGURATION
================================================================================

Nginx Config:        /etc/nginx/sites-available/${domain}
Nginx Enabled:       /etc/nginx/sites-enabled/${domain}
PHP Version:         ${PHP_VERSION:-${PHP_MAJOR_VERSION}}
PHP-FPM Socket:      /run/php/php${PHP_MAJOR_VERSION}-fpm.sock

WordPress Version:   $(cd "${site_root}/public_html" && wp core version --allow-root 2>/dev/null || echo "Latest")
Redis Enabled:       Yes
FastCGI Cache:       Enabled

================================================================================
FILE PERMISSIONS
================================================================================

Owner:               www-data:www-data
Directories:         755
Files:               644
wp-config.php:       440

================================================================================
NEXT STEPS
================================================================================

1. DNS Configuration:
   Point your domain to: $(hostname -I | awk '{print $1}')

   A Record:
   Host: @
   Value: $(hostname -I | awk '{print $1}')

   CNAME Record (optional):
   Host: www
   Value: ${domain}

2. SSL Certificate:
   Run: sudo ./build.sh --menu
   Then select: Manage Existing Site → Install SSL Certificate
   Or run: sudo certbot --nginx -d ${domain} -d www.${domain}

3. WordPress Setup:
   $(if [[ -n "$wp_admin_user" ]]; then
       echo "Already installed! Visit: http://${domain}/wp-admin"
       echo "   Username: ${wp_admin_user}"
       echo "   Password: ${wp_admin_pass}"
   else
       echo "Visit: http://${domain}"
       echo "   Complete the WordPress installation wizard"
   fi)

4. Redis Object Cache:
   $(if [[ -n "$wp_admin_user" ]]; then
       echo "Already enabled!"
   else
       echo "Install 'Redis Object Cache' plugin from WordPress admin"
       echo "   Activate and click 'Enable Object Cache'"
   fi)

5. Security:
   - Update WordPress admin password after first login
   - Keep WordPress core, themes, and plugins updated
   - Regular backups are scheduled at 2 AM daily

================================================================================
IMPORTANT FILES
================================================================================

This Report:         ${report_file}
All Credentials:     ${CREDENTIALS_FILE}
Installation Log:    ${INSTALL_LOG}
Error Log:           ${ERROR_LOG}
Backup Location:     ${BASE_DIR}/backups/

================================================================================
TROUBLESHOOTING
================================================================================

Check site status:
  sudo systemctl status nginx
  sudo systemctl status php${PHP_MAJOR_VERSION}-fpm
  sudo systemctl status mariadb
  sudo systemctl status redis-server

View error logs:
  sudo tail -f ${site_root}/logs/error.log
  sudo tail -f /var/log/nginx/error.log
  sudo tail -f /var/log/php${PHP_MAJOR_VERSION}-fpm.log

Test Nginx config:
  sudo nginx -t

Reload Nginx:
  sudo systemctl reload nginx

================================================================================
SUPPORT
================================================================================

For issues or questions, check the logs above or run:
  sudo ./build.sh --menu

Monitor system: ${BASE_DIR}/scripts/monitor.sh
List all sites: sudo ./build.sh --list-sites

================================================================================
EOF

    # Success message
    log_header "WordPress Site Created Successfully!"
    echo
    echo -e "${COLOR_GREEN}Site Details:${COLOR_RESET}"
    table_row "Domain" "$domain"
    table_row "Site URL" "http://${domain}"
    table_row "Admin URL" "http://${domain}/wp-admin"
    if [[ -n "$wp_admin_user" ]]; then
        table_row "Admin User" "$wp_admin_user"
        table_row "Admin Password" "$wp_admin_pass"
    fi
    table_row "Database" "$db_name"
    echo
    echo -e "${COLOR_CYAN}Installation Report:${COLOR_RESET}"
    echo "  ${COLOR_GREEN}✓${COLOR_RESET} Detailed report saved to:"
    echo "    ${report_file}"
    echo
    echo -e "${COLOR_CYAN}Next Steps:${COLOR_RESET}"
    echo "  1. Point your domain DNS to this server's IP: $(hostname -I | awk '{print $1}')"
    if [[ -n "$wp_admin_user" ]]; then
        echo "  2. Visit http://${domain}/wp-admin to login"
        echo "  3. Install SSL certificate (recommended)"
    else
        echo "  2. Visit http://${domain} to complete WordPress installation"
        echo "  3. Install SSL certificate (recommended)"
    fi
    echo
    log_info "All credentials saved to: ${CREDENTIALS_FILE}"
    log_success "Installation report: ${report_file}"
    echo

    # Offer SSL installation
    if confirm "Would you like to install SSL certificate now?"; then
        install_ssl "$domain"
    fi
}

################################################################################
# Site Management
################################################################################

list_sites() {
    log_header "WordPress Sites"

    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_warning "No sites registered yet"
        return 0
    fi

    echo -e "${COLOR_CYAN}Registered WordPress Sites:${COLOR_RESET}"
    echo

    local count=0
    while IFS='|' read -r domain db_name created rest; do
        # Skip empty lines
        [[ -z "$domain" ]] && continue

        # Skip comment lines
        [[ "$domain" =~ ^#.* ]] && continue

        # Increment count
        count=$((count + 1))

        echo -e "${COLOR_GREEN}${count}.${COLOR_RESET} ${COLOR_BOLD}${domain}${COLOR_RESET}"
        table_row "  Database" "$db_name"
        table_row "  Created" "$created"
        table_row "  Site Root" "/var/www/${domain}/public_html"

        # Check if site is enabled
        if [[ -L "/etc/nginx/sites-enabled/${domain}" ]]; then
            echo -e "  Status: ${COLOR_GREEN}Enabled${COLOR_RESET}"
        else
            echo -e "  Status: ${COLOR_YELLOW}Disabled${COLOR_RESET}"
        fi
        echo
    done < "$CONFIG_FILE"

    if [[ $count -eq 0 ]]; then
        log_info "No sites found"
    else
        log_info "Total sites: $count"
    fi

    return 0
}

remove_site() {
    local domain="$1"

    log_warning "Removing WordPress site: ${domain}"
    echo

    if ! confirm "Are you sure you want to remove ${domain}? This cannot be undone!"; then
        log_info "Site removal cancelled"
        return
    fi

    # Backup before removal
    log_step "Creating final backup"
    backup_site "$domain"

    # Remove Nginx configuration
    log_step "Removing Nginx configuration"
    rm -f "/etc/nginx/sites-enabled/${domain}"
    rm -f "/etc/nginx/sites-available/${domain}"

    # Get database name
    local db_name=$(grep "^${domain}|" "$CONFIG_FILE" | cut -d'|' -f2)

    # Remove database
    if [[ -n "$db_name" ]]; then
        log_step "Removing database: ${db_name}"
        mysql -e "DROP DATABASE IF EXISTS ${db_name};" 2>/dev/null
        local db_user=$(grep "^${domain}|" "$CONFIG_FILE" | cut -d'|' -f3)
        mysql -e "DROP USER IF EXISTS '${db_user}'@'localhost';" 2>/dev/null
    fi

    # Remove files
    log_step "Removing site files"
    rm -rf "/var/www/${domain}"

    # Remove from registry
    sed -i "/^${domain}|/d" "$CONFIG_FILE"

    # Reload Nginx
    reload_service nginx

    log_success "Site ${domain} removed successfully"
}

reconfigure_site() {
    local domain="$1"

    log_header "Reconfiguring WordPress Site: ${domain}"

    # Check if site exists
    if [[ ! -d "/var/www/${domain}" ]]; then
        log_error "Site directory not found: /var/www/${domain}"
    fi

    # Check if site is registered
    if ! grep -q "^${domain}|" "$CONFIG_FILE" 2>/dev/null; then
        log_warning "Site not found in registry: ${domain}"
        if ! confirm "Continue anyway?"; then
            return
        fi
    fi

    local site_root="/var/www/${domain}/public_html"

    # Backup existing Nginx configuration
    if [[ -f "/etc/nginx/sites-available/${domain}" ]]; then
        log_step "Backing up existing Nginx configuration"
        cp "/etc/nginx/sites-available/${domain}" "/etc/nginx/sites-available/${domain}.bak.$(date +%Y%m%d_%H%M%S)"
    fi

    # Regenerate Nginx configuration
    log_step "Regenerating Nginx configuration with optimized settings"
    generate_nginx_site "$domain" "$site_root"

    # Test Nginx configuration
    log_step "Testing Nginx configuration"
    if nginx -t 2>&1 | grep -q "successful"; then
        log_success "Nginx configuration is valid"

        # Reload Nginx
        log_step "Reloading Nginx"
        reload_service nginx

        log_success "Site ${domain} reconfigured successfully!"
        echo
        echo -e "${COLOR_CYAN}Changes applied:${COLOR_RESET}"
        echo "  - Updated Nginx configuration with WordPress best practices"
        echo "  - Fixed MIME type handling for CSS and JavaScript files"
        echo "  - Enhanced security headers"
        echo "  - Optimized FastCGI cache settings"
        echo "  - Improved static file caching"
        echo
        log_info "Configuration file: /etc/nginx/sites-available/${domain}"
        log_info "Backup saved to: /etc/nginx/sites-available/${domain}.bak.*"
    else
        log_error "Nginx configuration test failed!"
        echo
        echo "Running detailed test:"
        nginx -t
        echo
        log_warning "Restoring backup configuration"

        # Restore backup
        local backup=$(ls -t /etc/nginx/sites-available/${domain}.bak.* 2>/dev/null | head -1)
        if [[ -n "$backup" ]]; then
            cp "$backup" "/etc/nginx/sites-available/${domain}"
            log_info "Backup restored"
        fi

        return 1
    fi
}

reconfigure_all_sites() {
    log_header "Reconfiguring All WordPress Sites"

    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_warning "No sites registered yet"
        return 0
    fi

    echo -e "${COLOR_CYAN}This will regenerate Nginx configuration for all registered sites.${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}Backups will be created before making changes.${COLOR_RESET}"
    echo

    if ! confirm "Do you want to proceed?"; then
        log_info "Operation cancelled"
        return
    fi

    echo

    local count=0
    local success=0
    local failed=0

    while IFS='|' read -r domain db_name created rest; do
        # Skip empty lines
        [[ -z "$domain" ]] && continue

        # Skip comment lines
        [[ "$domain" =~ ^#.* ]] && continue

        count=$((count + 1))

        echo -e "${COLOR_BOLD}Processing site ${count}: ${domain}${COLOR_RESET}"
        echo

        if reconfigure_site "$domain"; then
            success=$((success + 1))
        else
            failed=$((failed + 1))
        fi

        echo
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo
    done < "$CONFIG_FILE"

    # Summary
    log_header "Reconfiguration Summary"
    echo
    table_row "Total sites" "$count"
    table_row "Successfully reconfigured" "$success"
    table_row "Failed" "$failed"
    echo

    if [[ $failed -eq 0 ]]; then
        log_success "All sites reconfigured successfully!"
    else
        log_warning "Some sites failed to reconfigure. Please check the errors above."
    fi
}

################################################################################
# Helper Functions
################################################################################

register_site() {
    local domain="$1"
    local db_name="$2"
    local db_user="${3:-}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Create config file if it doesn't exist
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "# WordPress Sites Registry" > "$CONFIG_FILE"
        echo "# Format: domain|database|user|created" >> "$CONFIG_FILE"
    fi

    # Add site to registry
    echo "${domain}|${db_name}|${db_user}|${timestamp}" >> "$CONFIG_FILE"

    log_info "Site registered in ${CONFIG_FILE}"
}

store_credentials() {
    local domain="$1"
    local db_name="$2"
    local db_user="$3"
    local db_pass="$4"
    local wp_admin_pass="${5:-}"

    # Create credentials file if it doesn't exist
    if [[ ! -f "$CREDENTIALS_FILE" ]]; then
        touch "$CREDENTIALS_FILE"
        chmod 600 "$CREDENTIALS_FILE"
    fi

    # Add credentials
    cat >> "$CREDENTIALS_FILE" <<EOF

## ${domain}
Domain: ${domain}
Database Name: ${db_name}
Database User: ${db_user}
Database Password: ${db_pass}
WordPress Admin Password: ${wp_admin_pass}
Created: $(date '+%Y-%m-%d %H:%M:%S')
---
EOF

    chmod 600 "$CREDENTIALS_FILE"
}

install_redis_plugin() {
    local site_root="$1"

    if command_exists wp; then
        cd "$site_root"
        wp plugin install redis-cache --activate --allow-root &>/dev/null
        wp redis enable --allow-root &>/dev/null
        log_success "Redis Object Cache plugin installed and enabled"
    else
        log_info "Install Redis Object Cache plugin manually from WordPress admin"
    fi
}

################################################################################
# Export Functions
################################################################################

export -f add_wordpress_site list_sites remove_site
export -f reconfigure_site reconfigure_all_sites
export -f register_site store_credentials install_redis_plugin
