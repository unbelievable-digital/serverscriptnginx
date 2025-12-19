#!/usr/bin/env bash

################################################################################
# SSL/TLS Management Library
#
# Provides: SSL certificate installation and management with Let's Encrypt
################################################################################

install_ssl() {
    local domain="$1"

    log_header "SSL Certificate Installation"

    if ! command_exists certbot; then
        log_error "Certbot is not installed. Please run installation first."
    fi

    log_info "Installing SSL certificate for: ${domain}"
    echo

    # Verify domain is configured in Nginx
    if [[ ! -f "/etc/nginx/sites-available/${domain}" ]]; then
        log_error "No Nginx configuration found for ${domain}"
    fi

    # Ensure site is enabled
    if [[ ! -L "/etc/nginx/sites-enabled/${domain}" ]]; then
        ln -s "/etc/nginx/sites-available/${domain}" "/etc/nginx/sites-enabled/${domain}"
        reload_service nginx
    fi

    # Get email for Let's Encrypt
    local email
    read -p "Enter email address for SSL certificate notifications: " email

    if [[ -z "$email" ]]; then
        log_error "Email address is required"
    fi

    # Install certificate
    log_step "Requesting SSL certificate from Let's Encrypt"

    if certbot --nginx -d "$domain" -d "www.${domain}" \
        --non-interactive --agree-tos --email "$email" \
        --redirect &>/dev/null; then
        log_success "SSL certificate installed successfully"
        log_info "Your site is now accessible at: https://${domain}"
    else
        log_error "Failed to install SSL certificate. Please check domain DNS settings."
    fi
}

renew_ssl() {
    log_step "Renewing SSL certificates"

    if certbot renew --quiet; then
        log_success "SSL certificates renewed"
    else
        log_warning "Some certificates could not be renewed"
    fi
}

setup_ssl_renewal() {
    log_step "Setting up automatic SSL renewal"

    # Certbot already creates a systemd timer for renewal
    if systemctl list-timers | grep -q certbot; then
        log_success "Automatic SSL renewal is configured"
    else
        log_warning "Certbot renewal timer not found"
    fi
}

list_certificates() {
    log_header "SSL Certificates"

    if command_exists certbot; then
        certbot certificates
    else
        log_error "Certbot not installed"
    fi
}

export -f install_ssl renew_ssl setup_ssl_renewal list_certificates
