#!/usr/bin/env bash

################################################################################
# Backup Management Library
#
# Provides: Backup and restore operations for WordPress sites
################################################################################

backup_site() {
    local domain="$1"

    if [[ -z "$domain" ]]; then
        log_error "Domain name required"
    fi

    log_header "Backing up WordPress Site: ${domain}"

    local site_root="/var/www/${domain}/public_html"
    if [[ ! -d "$site_root" ]]; then
        log_error "Site not found: ${domain}"
    fi

    # Get database name
    local db_name=$(grep "^${domain}|" "$CONFIG_FILE" | cut -d'|' -f2)

    if [[ -z "$db_name" ]]; then
        log_error "Database name not found for ${domain}"
    fi

    # Create backup directory
    local backup_dir="${BASE_DIR}/backups/$(date +%Y%m%d_%H%M%S)_${domain}"
    mkdir -p "$backup_dir"

    # Backup database
    log_step "Backing up database: ${db_name}"
    mysqldump "$db_name" | gzip > "${backup_dir}/database.sql.gz"
    log_success "Database backed up"

    # Backup files
    log_step "Backing up files"
    tar -czf "${backup_dir}/files.tar.gz" -C "/var/www/${domain}" public_html &>/dev/null
    log_success "Files backed up"

    # Backup Nginx configuration
    if [[ -f "/etc/nginx/sites-available/${domain}" ]]; then
        cp "/etc/nginx/sites-available/${domain}" "${backup_dir}/nginx.conf"
    fi

    # Create backup manifest
    cat > "${backup_dir}/manifest.txt" <<EOF
Backup Date: $(date '+%Y-%m-%d %H:%M:%S')
Domain: ${domain}
Database: ${db_name}
Files: files.tar.gz
Database: database.sql.gz
Nginx Config: nginx.conf
EOF

    log_success "Backup completed: ${backup_dir}"
    echo "Backup location: ${backup_dir}"
}

backup_all_sites() {
    log_header "Backing up All WordPress Sites"

    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_warning "No sites to backup"
        return
    fi

    local count=0
    while IFS='|' read -r domain _; do
        # Skip comment lines
        [[ "$domain" =~ ^#.*  ]] && continue

        log_info "Backing up: ${domain}"
        backup_site "$domain"
        ((count++))
        echo
    done < "$CONFIG_FILE"

    log_success "Backed up ${count} sites"
}

setup_auto_backup() {
    log_step "Setting up automated backups"

    local cron_file="/etc/cron.d/wpserver-backup"

    cat > "$cron_file" <<EOF
# WordPress LEMP Server - Automated Backups
# Daily backup at 2 AM

0 2 * * * root ${BASE_DIR}/scripts/daily-backup.sh >> ${BASE_DIR}/logs/backup.log 2>&1
EOF

    chmod 644 "$cron_file"

    log_success "Automated backup configured (daily at 2 AM)"
}

cleanup_old_backups() {
    log_step "Cleaning up old backups"

    local backup_root="${BASE_DIR}/backups"
    local retention_days=7

    # Remove backups older than retention period
    find "$backup_root" -type d -mtime +$retention_days -exec rm -rf {} \; 2>/dev/null

    log_success "Old backups cleaned up (retention: ${retention_days} days)"
}

export -f backup_site backup_all_sites setup_auto_backup cleanup_old_backups
