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

    # Success message
    log_header "WordPress Site Created Successfully!"
    echo
    echo -e "${COLOR_GREEN}Site Details:${COLOR_RESET}"
    table_row "Domain" "$domain"
    table_row "Site Root" "${site_root}/public_html"
    table_row "Database Name" "$db_name"
    table_row "Database User" "$db_user"
    table_row "Database Password" "$db_pass"
    echo
    echo -e "${COLOR_CYAN}Next Steps:${COLOR_RESET}"
    echo "  1. Point your domain DNS to this server's IP address"
    echo "  2. Visit http://${domain} to complete WordPress installation"
    echo "  3. Run: wpserver --add-ssl ${domain} (to install SSL certificate)"
    echo
    log_info "Credentials saved to: ${CREDENTIALS_FILE}"
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
        return
    fi

    echo -e "${COLOR_CYAN}Registered WordPress Sites:${COLOR_RESET}"
    echo

    local count=0
    while IFS='|' read -r domain db_name created; do
        ((count++))
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
export -f register_site store_credentials install_redis_plugin
