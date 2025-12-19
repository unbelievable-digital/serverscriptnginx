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
        echo "  4. System Status & Monitoring"
        echo "  5. Backup Management"
        echo "  6. Performance Tuning"
        echo "  7. Security Management"
        echo "  8. Exit"
        echo
        read -p "Enter choice [1-8]: " choice

        case $choice in
            1) menu_add_site ;;
            2) menu_list_sites ;;
            3) menu_manage_site ;;
            4) menu_system_status ;;
            5) menu_backup ;;
            6) menu_performance ;;
            7) menu_security ;;
            8) exit 0 ;;
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
        echo "  3. Remove Site"
        echo "  4. Back to Main Menu"
        echo
        read -p "Enter choice [1-4]: " choice

        case $choice in
            1) install_ssl "$domain"; pause ;;
            2) backup_site "$domain"; pause ;;
            3) remove_site "$domain"; pause; break ;;
            4) break ;;
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
    clear
    echo "Performance Tuning"
    echo
    echo "  1. Show Current Configuration"
    echo "  2. Recalculate Resources"
    echo "  3. Clear All Caches"
    echo "  4. Back to Main Menu"
    echo
    read -p "Enter choice [1-4]: " choice

    case $choice in
        1)
            display_system_info
            pause
            ;;
        2)
            detect_cpu
            detect_ram
            calculate_resources
            display_system_info
            pause
            ;;
        3)
            log_info "Clearing caches..."
            redis-cli FLUSHALL &>/dev/null
            rm -rf /var/cache/nginx/*
            log_success "Caches cleared"
            pause
            ;;
        4) return ;;
    esac
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
