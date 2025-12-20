#!/usr/bin/env bash

################################################################################
# Configuration Library
#
# Provides: Configuration file generation from templates with variable substitution
################################################################################

################################################################################
# Nginx Configuration
################################################################################

generate_nginx_main() {
    log_step "Generating Nginx main configuration"

    local nginx_conf="/etc/nginx/nginx.conf"
    local template="${TEMPLATE_DIR}/nginx/nginx.conf.tpl"

    # Backup existing configuration
    if [[ -f "$nginx_conf" ]]; then
        backup_file "$nginx_conf"
    fi

    # If template doesn't exist, create inline
    if [[ ! -f "$template" ]]; then
        log_warning "Template not found, creating default configuration"

        cat > "$nginx_conf" <<EOF
user www-data;
worker_processes ${NGINX_WORKERS};
pid /run/nginx.pid;
error_log /var/log/nginx/error.log;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 2048;
    multi_accept on;
    use epoll;
}

http {
    # Basic Settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;
    client_max_body_size ${UPLOAD_MAX_SIZE};

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # SSL Settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    # Logging Settings
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    # Gzip Settings
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript application/json application/javascript application/xml+rss application/rss+xml font/truetype font/opentype application/vnd.ms-fontobject image/svg+xml;

    # FastCGI Cache
    fastcgi_cache_path /var/cache/nginx levels=1:2 keys_zone=WORDPRESS:100m inactive=60m;
    fastcgi_cache_key "\$scheme\$request_method\$host\$request_uri";
    fastcgi_cache_use_stale error timeout invalid_header http_500;
    fastcgi_ignore_headers Cache-Control Expires Set-Cookie;

    # Virtual Host Configs
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF
    fi

    log_success "Nginx main configuration generated"
}

generate_nginx_site() {
    local domain="$1"
    local site_root="${2:-/var/www/${domain}/public_html}"

    # Detect PHP version if not set
    if [[ -z "${PHP_MAJOR_VERSION:-}" ]]; then
        if command -v php &>/dev/null; then
            PHP_MAJOR_VERSION=$(php -r 'echo PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION;' 2>/dev/null)
        else
            # Fallback: try to find any installed PHP-FPM version
            for version in 8.3 8.2 8.1 8.0 7.4; do
                if [[ -f "/run/php/php${version}-fpm.sock" ]]; then
                    PHP_MAJOR_VERSION="$version"
                    break
                fi
            done
            # Ultimate fallback
            PHP_MAJOR_VERSION="${PHP_MAJOR_VERSION:-8.2}"
        fi
    fi

    local php_sock="/run/php/php${PHP_MAJOR_VERSION}-fpm.sock"

    local config_file="/etc/nginx/sites-available/${domain}"
    local template="${TEMPLATE_DIR}/nginx/wordpress-site.conf.tpl"

    log_step "Generating Nginx configuration for ${domain}"

    # Create configuration
    cat > "$config_file" <<'EOF'
# WordPress site configuration for DOMAIN_PLACEHOLDER
# Generated: TIMESTAMP_PLACEHOLDER
# Optimized for WordPress performance and security

server {
    listen 80;
    listen [::]:80;
    server_name DOMAIN_PLACEHOLDER www.DOMAIN_PLACEHOLDER;

    root SITE_ROOT_PLACEHOLDER;
    index index.php index.html index.htm;

    access_log /var/www/DOMAIN_PLACEHOLDER/logs/access.log;
    error_log /var/www/DOMAIN_PLACEHOLDER/logs/error.log;

    # Maximum file upload size
    client_max_body_size 128M;

    # FastCGI Cache settings
    set $skip_cache 0;

    # POST requests and URLs with a query string should always go to PHP
    if ($request_method = POST) {
        set $skip_cache 1;
    }
    if ($query_string != "") {
        set $skip_cache 1;
    }

    # Don't cache URIs containing the following segments
    if ($request_uri ~* "/wp-admin/|/xmlrpc.php|wp-.*.php|/feed/|index.php|sitemap(_index)?.xml") {
        set $skip_cache 1;
    }

    # Don't use the cache for logged in users or recent commenters
    if ($http_cookie ~* "comment_author|wordpress_[a-f0-9]+|wp-postpass|wordpress_no_cache|wordpress_logged_in") {
        set $skip_cache 1;
    }

    # Deny access to hidden files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    # Deny access to sensitive files
    location ~* /(?:uploads|files)/.*\.php$ {
        deny all;
    }

    location ~* ^/wp-content/uploads/.*.(html|htm|shtml|php|js|swf)$ {
        deny all;
    }

    # Block access to xmlrpc.php
    location = /xmlrpc.php {
        deny all;
        access_log off;
        log_not_found off;
    }

    # WordPress main location
    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    # PHP processing with FastCGI
    location ~ \.php$ {
        try_files $uri =404;
        include fastcgi_params;
        fastcgi_intercept_errors on;
        fastcgi_pass unix:PHP_SOCK_PLACEHOLDER;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_index index.php;

        # FastCGI timeouts
        fastcgi_read_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_connect_timeout 300;

        # FastCGI buffer settings
        fastcgi_buffer_size 128k;
        fastcgi_buffers 256 16k;
        fastcgi_busy_buffers_size 256k;
        fastcgi_temp_file_write_size 256k;

        # FastCGI cache
        fastcgi_cache_bypass $skip_cache;
        fastcgi_no_cache $skip_cache;
        fastcgi_cache WORDPRESS;
        fastcgi_cache_valid 200 60m;
        fastcgi_cache_valid 404 10m;
        add_header X-FastCGI-Cache $upstream_cache_status;
    }

    # Favicon and robots.txt
    location = /favicon.ico {
        log_not_found off;
        access_log off;
        expires max;
    }

    location = /robots.txt {
        allow all;
        log_not_found off;
        access_log off;
    }

    # CSS and JavaScript files - CRITICAL for MIME types
    location ~* \.(css)$ {
        add_header Content-Type text/css;
        expires 30d;
        add_header Cache-Control "public, must-revalidate, proxy-revalidate";
        add_header X-Content-Type-Options "nosniff" always;
        access_log off;
    }

    location ~* \.(js)$ {
        add_header Content-Type application/javascript;
        expires 30d;
        add_header Cache-Control "public, must-revalidate, proxy-revalidate";
        add_header X-Content-Type-Options "nosniff" always;
        access_log off;
    }

    # Image files
    location ~* \.(jpg|jpeg|png|gif|ico|svg|webp|avif)$ {
        expires max;
        add_header Cache-Control "public, immutable";
        log_not_found off;
        access_log off;
    }

    # Font files
    location ~* \.(woff|woff2|ttf|ttc|otf|eot)$ {
        expires max;
        add_header Cache-Control "public, immutable";
        add_header Access-Control-Allow-Origin "*";
        log_not_found off;
        access_log off;
    }

    # Media files
    location ~* \.(mp4|webm|ogg|mp3|wav|flac|aac|m4a)$ {
        expires max;
        add_header Cache-Control "public, immutable";
        log_not_found off;
        access_log off;
    }

    # Document files
    location ~* \.(pdf|doc|docx|xls|xlsx|ppt|pptx)$ {
        expires 30d;
        add_header Cache-Control "public, must-revalidate, proxy-revalidate";
        log_not_found off;
        access_log off;
    }

    # Archive files
    location ~* \.(zip|tar|gz|rar|7z)$ {
        expires 30d;
        add_header Cache-Control "public, must-revalidate, proxy-revalidate";
        log_not_found off;
        access_log off;
    }

    # Deny access to backup and log files
    location ~* \.(bak|config|sql|fla|psd|ini|log|sh|inc|swp|dist|sql\.gz)$ {
        deny all;
        access_log off;
        log_not_found off;
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;

    # Disable server tokens
    server_tokens off;
}
EOF

    # Replace placeholders
    sed -i "s|DOMAIN_PLACEHOLDER|${domain}|g" "$config_file"
    sed -i "s|SITE_ROOT_PLACEHOLDER|${site_root}|g" "$config_file"
    sed -i "s|PHP_SOCK_PLACEHOLDER|${php_sock}|g" "$config_file"
    sed -i "s|TIMESTAMP_PLACEHOLDER|$(date '+%Y-%m-%d %H:%M:%S')|g" "$config_file"

    # Enable site
    if [[ ! -L "/etc/nginx/sites-enabled/${domain}" ]]; then
        ln -s "$config_file" "/etc/nginx/sites-enabled/${domain}"
        log_success "Nginx site configuration created and enabled for ${domain}"
    else
        log_success "Nginx site configuration updated for ${domain}"
    fi
}

################################################################################
# PHP Configuration
################################################################################

generate_php_ini() {
    log_step "Generating PHP configuration"

    local php_ini="/etc/php/${PHP_MAJOR_VERSION}/fpm/php.ini"

    if [[ ! -f "$php_ini" ]]; then
        log_error "PHP configuration file not found: $php_ini"
    fi

    # Backup original
    backup_file "$php_ini"

    # Update PHP settings
    sed -i "s/^memory_limit = .*/memory_limit = ${PHP_MEMORY_LIMIT}/" "$php_ini"
    sed -i "s/^upload_max_filesize = .*/upload_max_filesize = ${UPLOAD_MAX_SIZE}/" "$php_ini"
    sed -i "s/^post_max_size = .*/post_max_size = ${POST_MAX_SIZE}/" "$php_ini"
    sed -i "s/^max_execution_time = .*/max_execution_time = 300/" "$php_ini"
    sed -i "s/^max_input_time = .*/max_input_time = 300/" "$php_ini"

    # OPcache settings
    sed -i "s/^;opcache.enable=.*/opcache.enable=1/" "$php_ini"
    sed -i "s/^;opcache.memory_consumption=.*/opcache.memory_consumption=128/" "$php_ini"
    sed -i "s/^;opcache.interned_strings_buffer=.*/opcache.interned_strings_buffer=16/" "$php_ini"
    sed -i "s/^;opcache.max_accelerated_files=.*/opcache.max_accelerated_files=10000/" "$php_ini"

    log_success "PHP.ini configured with optimized settings"
}

generate_php_fpm_pool() {
    log_step "Generating PHP-FPM pool configuration"

    local pool_conf="/etc/php/${PHP_MAJOR_VERSION}/fpm/pool.d/www.conf"

    if [[ ! -f "$pool_conf" ]]; then
        log_error "PHP-FPM pool configuration not found: $pool_conf"
    fi

    # Backup original
    backup_file "$pool_conf"

    # Update pool settings
    sed -i "s/^pm = .*/pm = dynamic/" "$pool_conf"
    sed -i "s/^pm.max_children = .*/pm.max_children = ${PHP_MAX_CHILDREN}/" "$pool_conf"
    sed -i "s/^pm.start_servers = .*/pm.start_servers = ${PHP_START_SERVERS}/" "$pool_conf"
    sed -i "s/^pm.min_spare_servers = .*/pm.min_spare_servers = ${PHP_MIN_SPARE}/" "$pool_conf"
    sed -i "s/^pm.max_spare_servers = .*/pm.max_spare_servers = ${PHP_MAX_SPARE}/" "$pool_conf"
    sed -i "s/^;pm.max_requests = .*/pm.max_requests = 500/" "$pool_conf"

    log_success "PHP-FPM pool configured with optimized settings"
}

################################################################################
# MySQL/MariaDB Configuration
################################################################################

generate_mysql_config() {
    log_step "Generating MariaDB configuration"

    local mysql_conf="/etc/mysql/mariadb.conf.d/99-custom.cnf"

    # Create custom configuration file
    cat > "$mysql_conf" <<EOF
# Custom MariaDB configuration
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
# Optimized for ${TOTAL_RAM_MB}MB RAM

[mysqld]
# InnoDB Settings
innodb_buffer_pool_size = ${INNODB_BUFFER_POOL}M
innodb_log_file_size = ${INNODB_LOG_FILE_SIZE}M
innodb_file_per_table = 1
innodb_flush_log_at_trx_commit = 2
innodb_flush_method = O_DIRECT

# Connection Settings
max_connections = ${MAX_CONNECTIONS}

# Query Cache (disabled in modern MariaDB)
query_cache_type = 0
query_cache_size = 0

# Performance
table_open_cache = 4000
tmp_table_size = 64M
max_heap_table_size = 64M

# Logging
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow-query.log
long_query_time = 2

# Binary Logging (optional, for replication)
#log_bin = /var/log/mysql/mysql-bin.log
#expire_logs_days = 7
#max_binlog_size = 100M
EOF

    log_success "MariaDB configuration generated"
}

################################################################################
# Redis Configuration
################################################################################

generate_redis_config() {
    log_step "Generating Redis configuration"

    local redis_conf="/etc/redis/redis.conf"

    if [[ ! -f "$redis_conf" ]]; then
        log_warning "Redis configuration not found, skipping"
        return
    fi

    # Backup original
    backup_file "$redis_conf"

    # Update Redis settings for object cache
    sed -i "s/^# maxmemory <bytes>/maxmemory ${REDIS_MAXMEMORY}mb/" "$redis_conf"
    sed -i "s/^# maxmemory-policy .*/maxmemory-policy allkeys-lru/" "$redis_conf"

    # Disable persistence for object cache (optional)
    sed -i 's/^save /# save /' "$redis_conf"

    log_success "Redis configuration generated"
}

################################################################################
# Apply Configurations
################################################################################

apply_configs() {
    log_step "Applying configurations and restarting services"

    # Test Nginx configuration
    if nginx -t &>/dev/null; then
        reload_service nginx
    else
        log_warning "Nginx configuration test failed, not reloading"
    fi

    # Test PHP-FPM configuration
    if php-fpm${PHP_MAJOR_VERSION} -t &>/dev/null; then
        restart_service "php${PHP_MAJOR_VERSION}-fpm"
    else
        log_warning "PHP-FPM configuration test failed, not restarting"
    fi

    # Restart MariaDB
    restart_service mariadb

    # Restart Redis
    restart_service redis-server

    log_success "All configurations applied"
}

################################################################################
# Configuration Validation
################################################################################

validate_nginx_config() {
    local domain="$1"
    local config_file="/etc/nginx/sites-available/${domain}"

    if [[ ! -f "$config_file" ]]; then
        log_error "Nginx configuration not found for ${domain}"
        return 1
    fi

    if nginx -t &>/dev/null; then
        log_success "Nginx configuration valid"
        return 0
    else
        log_error "Nginx configuration test failed"
        nginx -t
        return 1
    fi
}

################################################################################
# Export Functions
################################################################################

export -f generate_nginx_main generate_nginx_site
export -f generate_php_ini generate_php_fpm_pool
export -f generate_mysql_config generate_redis_config
export -f apply_configs validate_nginx_config
