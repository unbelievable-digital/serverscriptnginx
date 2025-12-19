#!/usr/bin/env bash

################################################################################
# Installation Library
#
# Provides: Package installation functions for LEMP stack components
################################################################################

# Debian frontend noninteractive to prevent prompts
export DEBIAN_FRONTEND=noninteractive

################################################################################
# System Update
################################################################################

update_system() {
    log_step "Updating package lists"

    if apt-get update -qq; then
        log_success "Package lists updated"
    else
        log_error "Failed to update package lists"
    fi
}

upgrade_system() {
    log_step "Upgrading installed packages (this may take a while)"

    if apt-get upgrade -y -qq; then
        log_success "System upgraded"
    else
        log_warning "System upgrade had some issues, continuing..."
    fi
}

################################################################################
# Dependencies Installation
################################################################################

install_dependencies() {
    log_step "Installing common dependencies"

    local packages=(
        software-properties-common
        apt-transport-https
        ca-certificates
        curl
        wget
        git
        unzip
        zip
        gnupg
        lsb-release
        ufw
        htop
    )

    if apt-get install -y -qq "${packages[@]}"; then
        log_success "Common dependencies installed"
    else
        log_error "Failed to install dependencies"
    fi
}

################################################################################
# Repository Management
################################################################################

add_repositories() {
    log_step "Adding required repositories"

    # Add Ondrej PHP PPA
    if ! grep -rq "ondrej/php" /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null; then
        log_info "Adding Ondrej PHP PPA"

        # Install software-properties-common if not present
        if ! command_exists add-apt-repository; then
            apt-get install -y software-properties-common &>/dev/null
        fi

        # Add the PPA
        if add-apt-repository -y ppa:ondrej/php; then
            log_success "Ondrej PHP PPA added successfully"
        else
            log_error "Failed to add Ondrej PHP PPA"
        fi
    else
        log_info "Ondrej PHP PPA already added"
    fi

    # Add MariaDB repository
    if [[ ${MARIADB_INSTALLED:-0} != 1 ]]; then
        log_info "Adding MariaDB repository"

        # Get MariaDB repository setup script
        curl -LsS https://r.mariadb.com/downloads/mariadb_repo_setup | \
            bash -s -- --mariadb-server-version=10.11 &>/dev/null || \
            log_warning "Could not add MariaDB repository, will use default"
    fi

    # Update package lists after adding repositories
    log_step "Updating package lists"
    if apt-get update -qq; then
        log_success "Package lists updated"
    else
        log_warning "Package list update had issues, continuing..."
    fi

    log_success "Repositories configured"
}

################################################################################
# Nginx Installation
################################################################################

install_nginx() {
    log_step "Installing Nginx"

    if apt-get install -y -qq nginx; then
        NGINX_VERSION=$(nginx -v 2>&1 | grep -oP 'nginx/\K[0-9.]+')
        log_success "Nginx ${NGINX_VERSION} installed"

        # Start and enable Nginx
        start_enable_service nginx

        # Test Nginx configuration
        if nginx -t &>/dev/null; then
            log_success "Nginx configuration test passed"
        else
            log_warning "Nginx configuration test failed"
        fi
    else
        log_error "Failed to install Nginx"
    fi
}

################################################################################
# MariaDB Installation
################################################################################

install_mariadb() {
    log_step "Installing MariaDB"

    # Install MariaDB server and client
    if apt-get install -y -qq mariadb-server mariadb-client; then
        MARIADB_VERSION=$(mariadb --version | grep -oP 'Distrib \K[0-9.]+')
        log_success "MariaDB ${MARIADB_VERSION} installed"

        # Start and enable MariaDB
        start_enable_service mariadb

        # Wait for MariaDB to be ready
        sleep 3

        log_success "MariaDB is running"
    else
        log_error "Failed to install MariaDB"
    fi
}

################################################################################
# PHP Installation
################################################################################

install_php() {
    log_step "Installing PHP ${PHP_MAJOR_VERSION} and extensions"

    # PHP packages to install
    local php_packages=(
        "php${PHP_MAJOR_VERSION}-fpm"
        "php${PHP_MAJOR_VERSION}-mysql"
        "php${PHP_MAJOR_VERSION}-curl"
        "php${PHP_MAJOR_VERSION}-gd"
        "php${PHP_MAJOR_VERSION}-mbstring"
        "php${PHP_MAJOR_VERSION}-xml"
        "php${PHP_MAJOR_VERSION}-xmlrpc"
        "php${PHP_MAJOR_VERSION}-soap"
        "php${PHP_MAJOR_VERSION}-intl"
        "php${PHP_MAJOR_VERSION}-zip"
        "php${PHP_MAJOR_VERSION}-bcmath"
        "php${PHP_MAJOR_VERSION}-imagick"
        "php${PHP_MAJOR_VERSION}-redis"
        "php${PHP_MAJOR_VERSION}-opcache"
        "php${PHP_MAJOR_VERSION}-cli"
        "php${PHP_MAJOR_VERSION}-common"
    )

    if apt-get install -y -qq "${php_packages[@]}"; then
        PHP_VERSION=$(php -r 'echo PHP_VERSION;')
        log_success "PHP ${PHP_VERSION} and extensions installed"

        # Start and enable PHP-FPM
        start_enable_service "php${PHP_MAJOR_VERSION}-fpm"

        # Verify PHP-FPM is running
        if is_service_running "php${PHP_MAJOR_VERSION}-fpm"; then
            log_success "PHP-FPM is running"
        else
            log_warning "PHP-FPM is not running"
        fi

        # Display installed PHP modules
        log_info "Installed PHP modules:"
        php -m | grep -E '(mysql|curl|gd|mbstring|xml|redis|imagick|opcache)' | \
            sed 's/^/    /'

    else
        log_error "Failed to install PHP"
    fi
}

################################################################################
# Redis Installation
################################################################################

install_redis() {
    log_step "Installing Redis"

    if apt-get install -y -qq redis-server; then
        REDIS_VERSION=$(redis-server --version | grep -oP 'v=\K[0-9.]+')
        log_success "Redis ${REDIS_VERSION} installed"

        # Start and enable Redis
        start_enable_service redis-server

        # Test Redis connection
        if redis-cli ping &>/dev/null; then
            log_success "Redis is responding"
        else
            log_warning "Redis is not responding"
        fi
    else
        log_error "Failed to install Redis"
    fi
}

################################################################################
# Certbot Installation
################################################################################

install_certbot() {
    log_step "Installing Certbot (Let's Encrypt)"

    local certbot_packages=(
        certbot
        python3-certbot-nginx
    )

    if apt-get install -y -qq "${certbot_packages[@]}"; then
        log_success "Certbot installed"

        # Verify certbot works
        if certbot --version &>/dev/null; then
            local certbot_version=$(certbot --version 2>&1 | grep -oP '[0-9.]+')
            log_info "Certbot version: ${certbot_version}"
        fi
    else
        log_warning "Failed to install Certbot (SSL certificates may not work)"
    fi
}

################################################################################
# Monitoring Tools Installation
################################################################################

install_monitoring() {
    log_step "Installing monitoring tools"

    local monitoring_packages=(
        htop
        iotop
        nethogs
        vnstat
    )

    if apt-get install -y -qq "${monitoring_packages[@]}" &>/dev/null; then
        log_success "Monitoring tools installed"
    else
        log_warning "Some monitoring tools could not be installed (optional)"
    fi
}

################################################################################
# WP-CLI Installation
################################################################################

install_wpcli() {
    log_step "Installing WP-CLI"

    # Download WP-CLI
    if curl -sS https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -o /tmp/wp-cli.phar; then
        # Make it executable
        chmod +x /tmp/wp-cli.phar

        # Move to bin directory
        mv /tmp/wp-cli.phar /usr/local/bin/wp

        # Verify installation
        if wp --info &>/dev/null; then
            local wp_version=$(wp cli version | grep -oP 'WP-CLI \K[0-9.]+')
            log_success "WP-CLI ${wp_version} installed"
        else
            log_warning "WP-CLI installed but verification failed"
        fi
    else
        log_warning "Failed to install WP-CLI (optional, but recommended)"
    fi
}

################################################################################
# Complete Stack Installation
################################################################################

install_lemp_stack() {
    log_header "Installing LEMP Stack"

    # Update system first
    update_system

    # Install dependencies
    install_dependencies

    # Add repositories
    add_repositories

    # Install Nginx if not present
    if [[ ${NGINX_INSTALLED:-0} != 1 ]]; then
        install_nginx
    else
        log_info "Nginx already installed, skipping"
    fi

    # Install MariaDB if not present
    if [[ ${MARIADB_INSTALLED:-0} != 1 ]]; then
        install_mariadb
    else
        log_info "MariaDB/MySQL already installed, skipping"
    fi

    # Install PHP if not present
    if [[ ${PHP_INSTALLED:-0} != 1 ]]; then
        install_php
    else
        log_info "PHP already installed, skipping"
    fi

    # Install Redis if not present
    if [[ ${REDIS_INSTALLED:-0} != 1 ]]; then
        install_redis
    else
        log_info "Redis already installed, skipping"
    fi

    # Install Certbot if not present
    if [[ ${CERTBOT_INSTALLED:-0} != 1 ]]; then
        install_certbot
    else
        log_info "Certbot already installed, skipping"
    fi

    # Install monitoring tools
    install_monitoring

    # Install WP-CLI
    install_wpcli

    log_success "LEMP stack installation complete"
}

################################################################################
# Package Cleanup
################################################################################

cleanup_packages() {
    log_step "Cleaning up package cache"

    apt-get autoremove -y -qq &>/dev/null
    apt-get autoclean -y -qq &>/dev/null

    log_success "Package cleanup complete"
}

################################################################################
# Verify Installation
################################################################################

verify_installation() {
    log_step "Verifying LEMP stack installation"

    local errors=0

    # Check Nginx
    if ! command_exists nginx; then
        log_error "Nginx verification failed"
        ((errors++))
    fi

    # Check MariaDB/MySQL
    if ! command_exists mariadb && ! command_exists mysql; then
        log_error "MariaDB/MySQL verification failed"
        ((errors++))
    fi

    # Check PHP
    if ! command_exists php; then
        log_error "PHP verification failed"
        ((errors++))
    fi

    # Check Redis
    if ! command_exists redis-server; then
        log_error "Redis verification failed"
        ((errors++))
    fi

    # Check services are running
    for service in nginx mariadb "php${PHP_MAJOR_VERSION}-fpm" redis-server; do
        if systemctl list-unit-files | grep -q "^${service}.service"; then
            if ! is_service_running "$service"; then
                log_warning "Service $service is not running"
            fi
        fi
    done

    if [[ $errors -eq 0 ]]; then
        log_success "All components verified successfully"
        return 0
    else
        log_error "Installation verification failed with $errors errors"
        return 1
    fi
}

################################################################################
# Export Functions
################################################################################

export -f update_system upgrade_system install_dependencies
export -f add_repositories
export -f install_nginx install_mariadb install_php install_redis install_certbot
export -f install_monitoring install_wpcli
export -f install_lemp_stack cleanup_packages verify_installation
