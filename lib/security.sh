#!/usr/bin/env bash

################################################################################
# Security Hardening Library
#
# Provides: Security configuration and hardening functions
################################################################################

secure_mysql() {
    log_step "Securing MariaDB installation"

    # Generate root password
    local mysql_root_pass="$(generate_password 32)"

    # Run mysql_secure_installation equivalent
    mysql -e "UPDATE mysql.user SET Password=PASSWORD('${mysql_root_pass}') WHERE User='root';" 2>/dev/null
    mysql -e "DELETE FROM mysql.user WHERE User='';" 2>/dev/null
    mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');" 2>/dev/null
    mysql -e "DROP DATABASE IF EXISTS test;" 2>/dev/null
    mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';" 2>/dev/null
    mysql -e "FLUSH PRIVILEGES;" 2>/dev/null

    # Store root password in /root/.my.cnf
    cat > /root/.my.cnf <<EOF
[client]
user=root
password=${mysql_root_pass}
EOF
    chmod 600 /root/.my.cnf

    # Store in credentials file
    cat >> "$CREDENTIALS_FILE" <<EOF

## MariaDB Root Password
Created: $(date '+%Y-%m-%d %H:%M:%S')
Password: ${mysql_root_pass}
---
EOF

    log_success "MariaDB secured and root password stored in /root/.my.cnf"
}

configure_firewall() {
    log_step "Configuring firewall (UFW)"

    # Install UFW if not present
    if ! command_exists ufw; then
        apt-get install -y -qq ufw
    fi

    # Configure firewall rules
    ufw --force reset &>/dev/null
    ufw default deny incoming &>/dev/null
    ufw default allow outgoing &>/dev/null

    # Allow SSH
    ufw allow 22/tcp &>/dev/null

    # Allow HTTP and HTTPS
    ufw allow 80/tcp &>/dev/null
    ufw allow 443/tcp &>/dev/null

    # Enable firewall
    ufw --force enable &>/dev/null

    log_success "Firewall configured (SSH, HTTP, HTTPS allowed)"
}

set_permissions() {
    log_step "Setting secure file permissions"

    # Nginx directories
    if [[ -d /var/www ]]; then
        chown -R www-data:www-data /var/www
        find /var/www -type d -exec chmod 755 {} \;
        find /var/www -type f -exec chmod 644 {} \;
    fi

    # Nginx configuration
    if [[ -d /etc/nginx ]]; then
        chown -R root:root /etc/nginx
        chmod -R 644 /etc/nginx/*
        chmod 755 /etc/nginx
    fi

    log_success "File permissions set"
}

disable_php_functions() {
    local php_ini="/etc/php/${PHP_MAJOR_VERSION}/fpm/php.ini"

    if [[ ! -f "$php_ini" ]]; then
        return
    fi

    log_step "Disabling dangerous PHP functions"

    local disabled_functions="exec,passthru,shell_exec,system,proc_open,popen,parse_ini_file,show_source"

    sed -i "s/^disable_functions = .*/disable_functions = ${disabled_functions}/" "$php_ini"

    log_success "Dangerous PHP functions disabled"
}

harden_wordpress() {
    local site_root="$1"

    log_step "Hardening WordPress installation"

    # Set wp-config.php permissions
    if [[ -f "${site_root}/wp-config.php" ]]; then
        chmod 440 "${site_root}/wp-config.php"
        chown www-data:www-data "${site_root}/wp-config.php"
    fi

    # Remove write permissions from WordPress root
    chmod 755 "$site_root"

    # Protect wp-includes
    if [[ -d "${site_root}/wp-includes" ]]; then
        find "${site_root}/wp-includes" -type f -exec chmod 644 {} \;
    fi

    log_success "WordPress installation hardened"
}

export -f secure_mysql configure_firewall set_permissions
export -f disable_php_functions harden_wordpress
