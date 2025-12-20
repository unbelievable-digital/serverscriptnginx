#!/usr/bin/env bash

################################################################################
# WordPress LEMP Stack Intelligent Build Script
#
# Description: Automated installation and management of WordPress sites on
#              Ubuntu with Nginx, MariaDB, PHP-FPM, and Redis
#
# Author: WordPress LEMP Server Project
# Version: 1.0.0
# License: MIT
################################################################################

set -euo pipefail

# Script directory and base path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="/opt/wpserver"
VERSION="1.0.0"

# Check if running from installed location or source directory
if [[ "$SCRIPT_DIR" == "/opt/wpserver" ]]; then
    BASE_DIR="$SCRIPT_DIR"
else
    # Running from source, use relative paths
    BASE_DIR="$SCRIPT_DIR"
fi

# Source library files
LIB_DIR="${BASE_DIR}/lib"

# Load core utilities first (logging, error handling)
if [[ -f "${LIB_DIR}/core.sh" ]]; then
    source "${LIB_DIR}/core.sh"
else
    echo "ERROR: core.sh not found at ${LIB_DIR}/core.sh"
    echo "Please ensure all library files are in the lib/ directory"
    exit 1
fi

# Load other library modules
for lib_file in detection install config wordpress ssl security backup menu; do
    lib_path="${LIB_DIR}/${lib_file}.sh"
    if [[ -f "$lib_path" ]]; then
        source "$lib_path"
    else
        log_warning "Library file not found: ${lib_file}.sh (some features may not work)"
    fi
done

################################################################################
# Global Variables
################################################################################

# Configuration file
CONFIG_FILE="${BASE_DIR}/config/wpserver.conf"
CREDENTIALS_FILE="/root/.wpserver-credentials"

# Log files
INSTALL_LOG="${BASE_DIR}/logs/install.log"
ERROR_LOG="${BASE_DIR}/logs/error.log"

# Template directory
TEMPLATE_DIR="${BASE_DIR}/templates"

################################################################################
# Helper Functions
################################################################################

# Display version information
show_version() {
    cat << EOF
WordPress LEMP Server Build Script
Version: ${VERSION}
Location: ${BASE_DIR}
EOF
}

# Display help/usage information
show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

OPTIONS:
    --install                Run full LEMP stack installation
    --menu                   Launch interactive menu system (default if no args)
    --add-site DOMAIN        Add new WordPress site
    --list-sites             List all WordPress sites
    --reconfigure DOMAIN     Reconfigure Nginx for a specific site (fix MIME types)
    --reconfigure-all        Reconfigure Nginx for all sites (fix MIME types)
    --backup-all             Backup all WordPress sites
    --system-status          Display system status and resource usage
    --performance            Show all performance settings and configurations
    --show-settings          Alias for --performance
    --update                 Update this script to latest version
    --version                Show version information
    -h, --help               Show this help message

EXAMPLES:
    # Run full installation (requires root)
    sudo ./build.sh --install

    # Launch interactive menu
    sudo ./build.sh --menu

    # Add new WordPress site
    sudo ./build.sh --add-site example.com

    # List all sites
    sudo ./build.sh --list-sites

    # Reconfigure Nginx for a specific site (fix MIME type issues)
    sudo ./build.sh --reconfigure example.com

    # Reconfigure Nginx for all sites (fix MIME type issues)
    sudo ./build.sh --reconfigure-all

    # Backup all sites
    sudo ./build.sh --backup-all

    # View performance settings
    sudo ./build.sh --performance

For more information, visit: https://github.com/yourusername/wpserverscript
EOF
}

# Self-install to /opt/wpserver
self_install() {
    log_info "Installing WordPress LEMP Server to /opt/wpserver..."

    # Create base directory if it doesn't exist
    if [[ ! -d "/opt/wpserver" ]]; then
        mkdir -p /opt/wpserver
        log_success "Created /opt/wpserver directory"
    fi

    # Copy all files if not already there
    if [[ "$BASE_DIR" != "/opt/wpserver" ]]; then
        log_info "Copying files to /opt/wpserver..."
        cp -r "${SCRIPT_DIR}"/* /opt/wpserver/
        chmod +x /opt/wpserver/build.sh

        # Create symlink in /usr/local/bin for easy access
        if [[ ! -f "/usr/local/bin/wpserver" ]]; then
            ln -s /opt/wpserver/build.sh /usr/local/bin/wpserver
            log_success "Created symlink: /usr/local/bin/wpserver"
        fi

        log_success "Installation complete! You can now run: wpserver --menu"
    else
        log_info "Already installed at /opt/wpserver"
    fi
}

################################################################################
# Main Installation Workflow
################################################################################

run_installation() {
    log_header "WordPress LEMP Stack Installation"
    log_info "Version: ${VERSION}"
    echo

    # Phase 1: Pre-flight Checks
    log_phase "Phase 1: Pre-flight Checks"
    check_root
    check_internet
    detect_os
    check_disk_space
    create_dirs
    echo

    # Phase 2: System Resource Detection
    log_phase "Phase 2: System Resource Detection"
    detect_cpu
    detect_ram
    detect_disk
    calculate_resources
    display_system_info
    echo

    # Phase 3: Software Detection
    log_phase "Phase 3: Software Detection"
    check_nginx
    check_mariadb
    check_php
    check_redis
    check_certbot
    display_software_status
    echo

    # Confirmation before proceeding
    if [[ "${AUTO_CONFIRM:-0}" != "1" ]]; then
        echo
        read -p "Continue with installation? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_warning "Installation cancelled by user"
            exit 0
        fi
    fi

    # Phase 4: Package Installation
    log_phase "Phase 4: Package Installation"
    update_system
    install_dependencies
    add_repositories

    # Re-detect PHP version after adding repositories (to find versions from PPA)
    if [[ "${PHP_INSTALLED:-0}" != "1" ]]; then
        detect_best_php_version
        log_info "Will install PHP ${PHP_MAJOR_VERSION}"
    fi

    # Install only what's needed
    [[ "${NGINX_INSTALLED:-0}" != "1" ]] && install_nginx
    [[ "${MARIADB_INSTALLED:-0}" != "1" ]] && install_mariadb
    [[ "${PHP_INSTALLED:-0}" != "1" ]] && install_php
    [[ "${REDIS_INSTALLED:-0}" != "1" ]] && install_redis
    [[ "${CERTBOT_INSTALLED:-0}" != "1" ]] && install_certbot
    install_monitoring
    echo

    # Phase 5: Service Configuration
    log_phase "Phase 5: Service Configuration"
    generate_nginx_main
    generate_php_ini
    generate_php_fpm_pool
    generate_mysql_config
    generate_redis_config
    apply_configs
    echo

    # Phase 6: Security Hardening
    log_phase "Phase 6: Security Hardening"
    secure_mysql
    configure_firewall
    set_permissions
    echo

    # Phase 7: Setup Automation
    log_phase "Phase 7: Setup Automation"
    setup_auto_backup
    setup_ssl_renewal
    echo

    # Installation Complete
    log_header "Installation Complete!"
    log_success "WordPress LEMP stack has been successfully installed"
    echo

    # Display summary
    display_installation_summary

    # Offer to add first WordPress site
    echo
    read -p "Would you like to add your first WordPress site now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        add_wordpress_site
    else
        log_info "You can add WordPress sites later using: wpserver --add-site domain.com"
        log_info "Or launch the menu: wpserver --menu"
    fi
}

################################################################################
# Command Line Argument Parsing
################################################################################

parse_arguments() {
    # No arguments provided, show menu
    if [[ $# -eq 0 ]]; then
        check_root
        if type -t show_main_menu &>/dev/null; then
            show_main_menu
        else
            log_error "Menu system not available. Run --install first."
        fi
        exit 0
    fi

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --install)
                check_root
                self_install
                run_installation
                exit 0
                ;;
            --menu)
                check_root
                if type -t show_main_menu &>/dev/null; then
                    show_main_menu
                else
                    log_error "Menu system not available. Run --install first."
                fi
                exit 0
                ;;
            --add-site)
                check_root
                if [[ -n "${2:-}" ]]; then
                    DOMAIN="$2"
                    add_wordpress_site "$DOMAIN"
                    shift
                else
                    log_error "Please specify a domain name"
                fi
                exit 0
                ;;
            --list-sites)
                if type -t list_sites &>/dev/null; then
                    list_sites
                else
                    log_error "WordPress management not available. Run --install first."
                fi
                exit 0
                ;;
            --reconfigure)
                check_root
                if [[ -n "${2:-}" ]]; then
                    DOMAIN="$2"
                    if type -t reconfigure_site &>/dev/null; then
                        reconfigure_site "$DOMAIN"
                    else
                        log_error "Site reconfiguration not available. Run --install first."
                    fi
                    shift
                else
                    log_error "Please specify a domain name"
                fi
                exit 0
                ;;
            --reconfigure-all)
                check_root
                if type -t reconfigure_all_sites &>/dev/null; then
                    reconfigure_all_sites
                else
                    log_error "Site reconfiguration not available. Run --install first."
                fi
                exit 0
                ;;
            --backup-all)
                check_root
                if type -t backup_all_sites &>/dev/null; then
                    backup_all_sites
                else
                    log_error "Backup system not available. Run --install first."
                fi
                exit 0
                ;;
            --system-status)
                if type -t display_system_status &>/dev/null; then
                    display_system_status
                else
                    detect_cpu
                    detect_ram
                    detect_disk
                    display_system_info
                fi
                exit 0
                ;;
            --performance|--show-settings)
                if type -t show_all_performance_settings &>/dev/null; then
                    show_all_performance_settings
                    echo
                    read -p "Save detailed report? (y/N): " -n 1 -r
                    echo
                    if [[ $REPLY =~ ^[Yy]$ ]]; then
                        save_performance_report
                    fi
                else
                    log_error "Performance viewing not available. Run --install first."
                fi
                exit 0
                ;;
            --update)
                check_root
                log_info "Update feature coming soon"
                exit 0
                ;;
            --version)
                show_version
                exit 0
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                echo
                show_help
                exit 1
                ;;
        esac
        shift
    done
}

################################################################################
# Main Entry Point
################################################################################

main() {
    # Set up error handling
    trap cleanup ERR EXIT

    # Initialize logging
    init_logging

    # Parse and execute commands
    parse_arguments "$@"
}

# Run main function
main "$@"
