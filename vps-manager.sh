#!/bin/bash

################################################################################
# VPS-Manager - Professional Free-Tier VPS Management Tool for Termux
# Author: Manus AI
# Description: A feature-rich CLI tool for managing VPS instances across
#              multiple cloud providers (Oracle Cloud, GCP, AWS, Azure)
################################################################################

set -euo pipefail

# ============================================================================
# CONFIGURATION AND CONSTANTS
# ============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CONFIG_DIR="${HOME}/.vps-manager"
readonly SERVERS_DB="${CONFIG_DIR}/servers.json"
readonly SETTINGS_CONF="${CONFIG_DIR}/settings.conf"
readonly MODULES_DIR="${SCRIPT_DIR}/modules"
readonly VERSION="1.0.0"

# ============================================================================
# COLOR DEFINITIONS (ANSI Escape Codes)
# ============================================================================

# Text Colors
readonly RED=\'\033[0;31m\'
readonly GREEN=\'\033[0;32m\'
readonly YELLOW=\'\033[1;33m\'
readonly BLUE=\'\033[0;34m\'
readonly MAGENTA=\'\033[0;35m\'
readonly CYAN=\'\033[0;36m\'
readonly WHITE=\'\033[1;37m\'
readonly GRAY=\'\033[0;37m\'

# Background Colors
readonly BG_RED=\'\033[41m\'
readonly BG_GREEN=\'\033[42m\'
readonly BG_YELLOW=\'\033[43m\'
readonly BG_BLUE=\'\033[44m\'

# Text Styles
readonly BOLD=\'\033[1m\'
readonly DIM=\'\033[2m\'
readonly ITALIC=\'\033[3m\'
readonly UNDERLINE=\'\033[4m\'
readonly BLINK=\'\033[5m\'

# Reset
readonly RESET=\'\033[0m\'

# ============================================================================
# UTILITY FUNCTIONS - OUTPUT AND FORMATTING
# ============================================================================

# Print colored text
print_color() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${RESET}"
}

# Print success message
print_success() {
    echo -e "${GREEN}✓ $1${RESET}"
}

# Print error message
print_error() {
    echo -e "${RED}✗ $1${RESET}"
}

# Print warning message
print_warning() {
    echo -e "${YELLOW}⚠ $1${RESET}"
}

# Print info message
print_info() {
    echo -e "${CYAN}ℹ $1${RESET}"
}

# Print debug message (only if DEBUG is set)
print_debug() {
    if [[ "${DEBUG:-0}" == "1" ]]; then
        echo -e "${GRAY}[DEBUG] $1${RESET}"
    fi
}

# Print a separator line
print_separator() {
    local char="${1:-─}"
    local length="${2:-80}"
    printf ‘%*s\n’ "$length" | tr ‘ ’ "$char"
}

# Print a section header
print_header() {
    echo ""
    print_color "${BOLD}${CYAN}" "╔$(printf ‘═%.0s’ {1..78})╗"
    print_color "${BOLD}${CYAN}" "║ $1"
    print_color "${BOLD}${CYAN}" "╚$(printf ‘═%.0s’ {1..78})╝"
    echo ""
}

# Print a subsection header
print_subheader() {
    echo ""
    print_color "${BOLD}${BLUE}" "▶ $1"
    print_separator "─" 80
}

# Simple loading animation
show_loading() {
    local message="$1"
    local duration="${2:-3}"
    local chars=( \'⠋\' \'⠙\' \'⠹\' \'⠸\' \'⠼\' \'⠴\' \'⠦\' \'⠧\' \'⠇\' \'⠏\' )
    local end=$((SECONDS + duration))
    
    while [ $SECONDS -lt $end ]; do
        for char in "${chars[@]}"; do
            echo -ne "\r${CYAN}${char}${RESET} ${message}"
            sleep 0.1
        done
    done
    echo -ne "\r"
}

# ============================================================================
# BANNER AND WELCOME
# ============================================================================

display_banner() {
    clear
    print_color "${BOLD}${MAGENTA}" "
    ╔═══════════════════════════════════════════════════════════════════════════╗
    ║                                                                           ║
    ║                        🚀 VPS-MANAGER v${VERSION} 🚀                        ║
    ║                                                                           ║
    ║              Professional Free-Tier VPS Management Tool                  ║
    ║                          For Termux & Linux                              ║
    ║                                                                           ║
    ║  Manage VPS instances across Oracle Cloud, GCP, AWS, and Azure           ║
    ║                                                                           ║
    ╚═══════════════════════════════════════════════════════════════════════════╝
    "
}

# ============================================================================
# INITIALIZATION AND SETUP
# ============================================================================

# Initialize configuration directory and files
init_config() {
    if [[ ! -d "${CONFIG_DIR}" ]]; then
        print_info "Creating configuration directory: ${CONFIG_DIR}"
        mkdir -p "${CONFIG_DIR}"
    fi
    
    # Initialize servers database if it doesn\'t exist
    if [[ ! -f "${SERVERS_DB}" ]]; then
        print_info "Initializing servers database..."
        echo "[]" > "${SERVERS_DB}"
    fi
    
    # Initialize settings file if it doesn\'t exist
    if [[ ! -f "${SETTINGS_CONF}" ]]; then
        print_info "Initializing settings file..."
        cat > "${SETTINGS_CONF}" << \'EOF\'
# VPS-Manager Configuration File
# Default SSH user for connections
DEFAULT_SSH_USER="root"

# Default SSH port
DEFAULT_SSH_PORT="22"

# Preferred cloud provider (oracle, gcp, aws, azure)
PREFERRED_PROVIDER="oracle"

# Enable debug mode (0 or 1)
DEBUG="0"
EOF
    fi
    
    print_success "Configuration initialized"
}

# Load settings from configuration file
load_settings() {
    if [[ -f "${SETTINGS_CONF}" ]]; then
        # shellcheck source=/dev/null
        source "${SETTINGS_CONF}"
    fi
}

# ============================================================================
# MENU FUNCTIONS
# ============================================================================

# Main menu
main_menu() {
    while true; do
        display_banner
        print_header "MAIN MENU"
        
        echo -e "${BOLD}Select an option:${RESET}\n"
        echo -e "${GREEN}1)${RESET} Manage VPS Instances"
        echo -e "${GREEN}2)${RESET} SSH Connection Manager"
        echo -e "${GREEN}3)${RESET} Server Monitoring"
        echo -e "${GREEN}4)${RESET} Deploy Services"
        echo -e "${GREEN}5)${RESET} Backup & Restore"
        echo -e "${GREEN}6)${RESET} Cloud Provider Setup"
        echo -e "${GREEN}7)${RESET} Settings"
        echo -e "${GREEN}8)${RESET} About"
        echo -e "${RED}0)${RESET} Exit"
        echo ""
        
        read -p "$(print_color "${BOLD}${YELLOW}" "Enter your choice [0-8]: ")" choice
        
        case "$choice" in
            1) manage_vps_menu ;;
            2) ssh_manager_menu ;;
            3) server_monitoring_menu ;;
            4) deploy_services_menu ;;
            5) backup_restore_menu ;;
            6) provider_setup_menu ;;
            7) settings_menu ;;
            8) show_about ;;
            0) 
                print_info "Thank you for using VPS-Manager. Goodbye!"
                exit 0
                ;;
            *)
                print_error "Invalid choice. Please try again."
                sleep 2
                ;;
        esac
    done
}

# VPS Management submenu
manage_vps_menu() {
    # Source the vps_management module
    source "${MODULES_DIR}/vps_management.sh"
    
    while true; do
        print_header "VPS MANAGEMENT"
        
        echo -e "${BOLD}Select an option:${RESET}\n"
        echo -e "${GREEN}1)${RESET} List All VPS Instances"
        echo -e "${GREEN}2)${RESET} Create New VPS"
        echo -e "${GREEN}3)${RESET} Configure VPS"
        echo -e "${GREEN}4)${RESET} Start VPS"
        echo -e "${GREEN}5)${RESET} Stop VPS"
        echo -e "${GREEN}6)${RESET} Restart VPS"
        echo -e "${GREEN}7)${RESET} Delete VPS"
        echo -e "${RED}0)${RESET} Back to Main Menu"
        echo ""
        
        read -p "$(print_color "${BOLD}${YELLOW}" "Enter your choice [0-7]: ")" choice
        
        case "$choice" in
            1) list_vps_instances ;;
            2) create_vps ;;
            3) configure_vps ;;
            4) start_vps ;;
            5) stop_vps ;;
            6) restart_vps ;;
            7) delete_vps ;;
            0) break ;;
            *)
                print_error "Invalid choice. Please try again."
                sleep 1
                ;;
        esac
    done
}

# SSH Manager submenu
ssh_manager_menu() {
    # Source the ssh_manager module
    source "${MODULES_DIR}/ssh_manager.sh"
    
    while true; do
        print_header "SSH CONNECTION MANAGER"
        
        echo -e "${BOLD}Select an option:${RESET}\n"
        echo -e "${GREEN}1)${RESET} Generate SSH Key Pair"
        echo -e "${GREEN}2)${RESET} List Saved Servers"
        echo -e "${GREEN}3)${RESET} Add New Server Profile"
        echo -e "${GREEN}4)${RESET} Connect to Server"
        echo -e "${GREEN}5)${RESET} Remove Server Profile"
        echo -e "${GREEN}6)${RESET} Edit Server Profile"
        echo -e "${RED}0)${RESET} Back to Main Menu"
        echo ""
        
        read -p "$(print_color "${BOLD}${YELLOW}" "Enter your choice [0-6]: ")" choice
        
        case "$choice" in
            1) 
                read -p "$(print_color "${BOLD}${YELLOW}" "Enter key name (default: id_rsa): ")" key_name
                generate_ssh_keypair "${key_name:-id_rsa}"
                read -p "Press Enter to continue..."
                ;;
            2) 
                list_servers
                read -p "Press Enter to continue..."
                ;;
            3) 
                read -p "$(print_color "${BOLD}${YELLOW}" "Enter server name: ")" server_name
                read -p "$(print_color "${BOLD}${YELLOW}" "Enter server IP/hostname: ")" server_ip
                read -p "$(print_color "${BOLD}${YELLOW}" "Enter SSH user (default: ${DEFAULT_SSH_USER}): ")" ssh_user
                ssh_user="${ssh_user:-${DEFAULT_SSH_USER}}"
                read -p "$(print_color "${BOLD}${YELLOW}" "Enter SSH port (default: ${DEFAULT_SSH_PORT}): ")" ssh_port
                ssh_port="${ssh_port:-${DEFAULT_SSH_PORT}}"
                read -p "$(print_color "${BOLD}${YELLOW}" "Enter SSH key path (optional, e.g., ~/.vps-manager/keys/id_rsa): ")" ssh_key
                add_server "$server_name" "$server_ip" "$ssh_user" "$ssh_port" "$ssh_key"
                read -p "Press Enter to continue..."
                ;;
            4) 
                local selected_server=$(select_server_from_list)
                if [[ -n "$selected_server" ]]; then
                    ssh_connect "$selected_server"
                fi
                read -p "Press Enter to continue..."
                ;;
            5) 
                local selected_server=$(select_server_from_list)
                if [[ -n "$selected_server" ]]; then
                    remove_server "$selected_server"
                fi
                read -p "Press Enter to continue..."
                ;;
            6) 
                print_info "Editing server profiles is not yet implemented. Please edit ${SERVERS_DB} manually."
                read -p "Press Enter to continue..."
                ;;
            0) break ;;
            *)
                print_error "Invalid choice. Please try again."
                sleep 1
                ;;
        esac
    done
}

# Helper function to select a server from the list for SSH Manager
select_server_from_list() {
    local server_names=($(jq -r ".[] | .name" "${SERVERS_DB}"))
    if [[ ${#server_names[@]} -eq 0 ]]; then
        print_warning "No server profiles found."
        return 1
    fi
    
    echo -e "${BOLD}Select a server:${RESET}\n"
    local PS3="$(print_color "${BOLD}${YELLOW}" "Enter your choice: ")"
    select server_name in "${server_names[@]}"; do
        if [[ -n "$server_name" ]]; then
            echo "$server_name"
            return 0
        else
            print_error "Invalid option. Please try again."
        fi
    done
    return 1
}

# Server Monitoring submenu
server_monitoring_menu() {
    # Source the monitoring module
    source "${MODULES_DIR}/monitoring.sh"
    
    while true; do
        print_header "SERVER MONITORING"
        
        echo -e "${BOLD}Select an option:${RESET}\n"
        echo -e "${GREEN}1)${RESET} Check Server Status"
        echo -e "${GREEN}2)${RESET} View CPU Usage"
        echo -e "${GREEN}3)${RESET} View Memory Usage"
        echo -e "${GREEN}4)${RESET} View Disk Usage"
        echo -e "${GREEN}5)${RESET} View All Metrics"
        echo -e "${GREEN}6)${RESET} Real-time Monitoring"
        echo -e "${RED}0)${RESET} Back to Main Menu"
        echo ""
        
        read -p "$(print_color "${BOLD}${YELLOW}" "Enter your choice [0-6]: ")" choice
        
        case "$choice" in
            1) 
                local selected_server=$(select_server_from_list)
                if [[ -n "$selected_server" ]]; then
                    check_server_status "$selected_server"
                fi
                read -p "Press Enter to continue..."
                ;;
            2) 
                local selected_server=$(select_server_from_list)
                if [[ -n "$selected_server" ]]; then
                    get_cpu_usage "$selected_server"
                fi
                read -p "Press Enter to continue..."
                ;;
            3) 
                local selected_server=$(select_server_from_list)
                if [[ -n "$selected_server" ]]; then
                    get_memory_usage "$selected_server"
                fi
                read -p "Press Enter to continue..."
                ;;
            4) 
                local selected_server=$(select_server_from_list)
                if [[ -n "$selected_server" ]]; then
                    get_disk_usage "$selected_server"
                fi
                read -p "Press Enter to continue..."
                ;;
            5) 
                local selected_server=$(select_server_from_list)
                if [[ -n "$selected_server" ]]; then
                    get_all_metrics "$selected_server"
                fi
                read -p "Press Enter to continue..."
                ;;
            6) 
                local selected_server=$(select_server_from_list)
                if [[ -n "$selected_server" ]]; then
                    read -p "$(print_color "${BOLD}${YELLOW}" "Enter refresh interval in seconds (default: 5): ")" interval
                    realtime_monitoring "$selected_server" "${interval:-5}"
                fi
                ;;
            0) break ;;
            *)
                print_error "Invalid choice. Please try again."
                sleep 1
                ;;
        esac
    done
}

# Deploy Services submenu
deploy_services_menu() {
    # Source the deploy_services module
    source "${MODULES_DIR}/deploy_services.sh"
    
    while true; do
        print_header "DEPLOY SERVICES"
        
        echo -e "${BOLD}Select a service to deploy:${RESET}\n"
        echo -e "${GREEN}1)${RESET} Web Server (Nginx)"
        echo -e "${GREEN}2)${RESET} Web Server (Apache)"
        echo -e "${GREEN}3)${RESET} VPN Server (OpenVPN)"
        echo -e "${GREEN}4)${RESET} Proxy Server (Squid)"
        echo -e "${GREEN}5)${RESET} Docker & Docker Compose"
        echo -e "${GREEN}6)${RESET} Node.js & npm"
        echo -e "${GREEN}7)${RESET} Python & pip"
        echo -e "${GREEN}8)${RESET} UFW Firewall"
        echo -e "${GREEN}9)${RESET} Fail2Ban"
        echo -e "${GREEN}10)${RESET} Common Utilities"
        echo -e "${RED}0)${RESET} Back to Main Menu"
        echo ""
        
        read -p "$(print_color "${BOLD}${YELLOW}" "Enter your choice [0-10]: ")" choice
        
        local selected_server
        if [[ "$choice" -ne 0 ]]; then
            selected_server=$(select_server_from_list)
            if [[ -z "$selected_server" ]]; then
                print_info "No VPS selected for deployment."
                sleep 1
                continue
            fi
        fi
        
        case "$choice" in
            1) deploy_nginx "$selected_server" ;;
            2) deploy_apache "$selected_server" ;;
            3) deploy_openvpn "$selected_server" ;;
            4) deploy_squid "$selected_server" ;;
            5) deploy_docker "$selected_server" ;;
            6) deploy_nodejs "$selected_server" ;;
            7) deploy_python "$selected_server" ;;
            8) deploy_ufw "$selected_server" ;;
            9) deploy_fail2ban "$selected_server" ;;
            10) deploy_utilities "$selected_server" ;;
            0) break ;;
            *)
                print_error "Invalid choice. Please try again."
                sleep 1
                ;;
        esac
        read -p "Press Enter to continue..."
    done
}

# Backup & Restore submenu
backup_restore_menu() {
    # Source the backup_restore module
    source "${MODULES_DIR}/backup_restore.sh"
    
    while true; do
        print_header "BACKUP & RESTORE"
        
        echo -e "${BOLD}Select an option:${RESET}\n"
        echo -e "${GREEN}1)${RESET} Backup Server Configuration"
        echo -e "${GREEN}2)${RESET} Restore Server Configuration"
        echo -e "${GREEN}3)${RESET} List Backups"
        echo -e "${GREEN}4)${RESET} Delete Backup"
        echo -e "${GREEN}5)${RESET} Schedule Automatic Backup"
        echo -e "${RED}0)${RESET} Back to Main Menu"
        echo ""
        
        read -p "$(print_color "${BOLD}${YELLOW}" "Enter your choice [0-5]: ")" choice
        
        local selected_server
        local backup_name
        
        case "$choice" in
            1) 
                selected_server=$(select_server_from_list)
                if [[ -n "$selected_server" ]]; then
                    backup_server_config "$selected_server"
                fi
                read -p "Press Enter to continue..."
                ;;
            2) 
                list_backups
                read -p "$(print_color "${BOLD}${YELLOW}" "Enter backup file name to restore (e.g., my-vps_backup_20231027_123456.tar.gz): ")" backup_file_name
                selected_server=$(select_server_from_list)
                if [[ -n "$backup_file_name" ]] && [[ -n "$selected_server" ]]; then
                    restore_server_config "${BACKUPS_DIR}/${backup_file_name}" "$selected_server"
                else
                    print_warning "Restore cancelled or invalid input."
                fi
                read -p "Press Enter to continue..."
                ;;
            3) 
                list_backups
                read -p "Press Enter to continue..."
                ;;
            4) 
                list_backups
                read -p "$(print_color "${BOLD}${YELLOW}" "Enter backup file name to delete: ")" backup_name
                if [[ -n "$backup_name" ]]; then
                    delete_backup "$backup_name"
                else
                    print_warning "Deletion cancelled."
                fi
                read -p "Press Enter to continue..."
                ;;
            5) 
                selected_server=$(select_server_from_list)
                if [[ -n "$selected_server" ]]; then
                    echo -e "${BOLD}Select backup frequency:${RESET}\n"
                    local frequencies=("daily" "weekly" "monthly")
                    local freq_choice_idx=$(select_option "${frequencies[@]}")
                    if [[ "$freq_choice_idx" -ne 0 ]]; then
                        schedule_backup "$selected_server" "${frequencies[$((freq_choice_idx-1))]}"
                    else
                        print_warning "Scheduling cancelled."
                    fi
                fi
                read -p "Press Enter to continue..."
                ;;
            0) break ;;
            *)
                print_error "Invalid choice. Please try again."
                sleep 1
                ;;
        esac
    done
}

# Provider Setup submenu
provider_setup_menu() {
    while true; do
        print_header "CLOUD PROVIDER SETUP"
        
        echo -e "${BOLD}Select a provider:${RESET}\n"
        echo -e "${GREEN}1)${RESET} Oracle Cloud (Always Free Tier)"
        echo -e "${GREEN}2)${RESET} Google Cloud Platform (e2-micro)"
        echo -e "${GREEN}3)${RESET} Amazon Web Services (t2.micro)"
        echo -e "${GREEN}4)${RESET} Microsoft Azure (B1s)"
        echo -e "${RED}0)${RESET} Back to Main Menu"
        echo ""
        
        read -p "$(print_color "${BOLD}${YELLOW}" "Enter your choice [0-4]: ")" choice
        
        case "$choice" in
            1) setup_oracle_cloud ;;
            2) setup_gcp ;;
            3) setup_aws ;;
            4) setup_azure ;;
            0) break ;;
            *)
                print_error "Invalid choice. Please try again."
                sleep 1
                ;;
        esac
    done
}

# Settings submenu
settings_menu() {
    while true; do
        print_header "SETTINGS"
        
        echo -e "${BOLD}Select an option:${RESET}\n"
        echo -e "${GREEN}1)${RESET} Change Default SSH User"
        echo -e "${GREEN}2)${RESET} Change Default SSH Port"
        echo -e "${GREEN}3)${RESET} Change Preferred Provider"
        echo -e "${GREEN}4)${RESET} Toggle Debug Mode"
        echo -e "${GREEN}5)${RESET} View Current Settings"
        echo -e "${RED}0)${RESET} Back to Main Menu"
        echo ""
        
        read -p "$(print_color "${BOLD}${YELLOW}" "Enter your choice [0-5]: ")" choice
        
        case "$choice" in
            1) change_ssh_user ;;
            2) change_ssh_port ;;
            3) change_preferred_provider ;;
            4) toggle_debug_mode ;;
            5) view_settings ;;
            0) break ;;
            *)
                print_error "Invalid choice. Please try again."
                sleep 1
                ;;
        esac
    done
}

# ============================================================================
# CLOUD PROVIDER SETUP FUNCTIONS (PLACEHOLDERS - actual logic in provider modules)
# ============================================================================

setup_oracle_cloud() {
    print_header "ORACLE CLOUD SETUP"
    source "${MODULES_DIR}/providers/oracle.sh"
    print_info "Please follow the instructions below to set up Oracle Cloud."
    echo -e "${BOLD}Oracle Cloud Always Free Tier:${RESET}"
    echo "  • Up to 4 ARM-based Ampere A1 Compute instances"
    echo "  • 24 GB of RAM total"
    echo "  • 200 GB of Compute Block Volume storage"
    echo "  • 10 GB of Object Storage"
    echo ""
    print_info "Step 1: Sign up for Oracle Cloud"
    echo "  Visit: https://www.oracle.com/cloud/free/"
    echo ""
    print_info "Step 2: Install OCI CLI"
    echo "  Run: pip3 install oci-cli"
    echo ""
    print_info "Step 3: Configure OCI CLI"
    echo "  Run: oci setup config"
    echo ""
    read -p "Press Enter to continue..."
}

setup_gcp() {
    print_header "GOOGLE CLOUD PLATFORM SETUP"
    source "${MODULES_DIR}/providers/gcp.sh"
    print_info "Please follow the instructions below to set up Google Cloud Platform."
    echo -e "${BOLD}GCP Free Tier (e2-micro):${RESET}"
    echo "  • 1 e2-micro instance per month"
    echo "  • 30 GB standard persistent disk"
    echo "  • 5 GB Cloud Storage"
    echo "  • 1 GB egress per month"
    echo ""
    print_info "Step 1: Sign up for GCP"
    echo "  Visit: https://cloud.google.com/free"
    echo ""
    print_info "Step 2: Install gcloud CLI"
    echo "  Visit: https://cloud.google.com/sdk/docs/install"
    echo ""
    print_info "Step 3: Initialize gcloud"
    echo "  Run: gcloud init"
    echo ""
    read -p "Press Enter to continue..."
}

setup_aws() {
    print_header "AMAZON WEB SERVICES SETUP"
    source "${MODULES_DIR}/providers/aws.sh"
    print_info "Please follow the instructions below to set up Amazon Web Services."
    echo -e "${BOLD}AWS Free Tier (t2.micro):${RESET}"
    echo "  • 1 t2.micro instance for 12 months"
    echo "  • 30 GB EBS storage"
    echo "  • 15 GB data transfer"
    echo "  • 1 million API calls"
    echo ""
    print_info "Step 1: Sign up for AWS"
    echo "  Visit: https://aws.amazon.com/free/"
    echo ""
    print_info "Step 2: Install AWS CLI"
    echo "  Run: pip3 install awscli"
    echo ""
    print_info "Step 3: Configure AWS CLI"
    echo "  Run: aws configure"
    echo ""
    read -p "Press Enter to continue..."
}

setup_azure() {
    print_header "MICROSOFT AZURE SETUP"
    source "${MODULES_DIR}/providers/azure.sh"
    print_info "Please follow the instructions below to set up Microsoft Azure."
    echo -e "${BOLD}Azure Free Tier (B1s):${RESET}"
    echo "  • 1 B1s VM for 12 months"
    echo "  • 64 GB managed disk storage"
    echo "  • 15 GB data transfer"
    echo "  • 750 hours compute"
    echo ""
    print_info "Step 1: Sign up for Azure"
    echo "  Visit: https://azure.microsoft.com/free/"
    echo ""
    print_info "Step 2: Install Azure CLI"
    echo "  Run: curl -sL https://aka.ms/InstallAzureCLIDeb | bash"
    echo ""
    print_info "Step 3: Login to Azure"
    echo "  Run: az login"
    echo ""
    read -p "Press Enter to continue..."
}

# ============================================================================
# SETTINGS FUNCTIONS
# ============================================================================

change_ssh_user() {
    print_header "CHANGE DEFAULT SSH USER"
    read -p "$(print_color "${BOLD}${YELLOW}" "Enter new default SSH user: ")" new_user
    
    if [[ -z "$new_user" ]]; then
        print_error "SSH user cannot be empty."
        return
    fi
    
    sed -i "s/^DEFAULT_SSH_USER=.*/DEFAULT_SSH_USER=\"${new_user}\"/" "${SETTINGS_CONF}"
    print_success "Default SSH user changed to: $new_user"
    load_settings # Reload settings after change
    sleep 2
}

change_ssh_port() {
    print_header "CHANGE DEFAULT SSH PORT"
    read -p "$(print_color "${BOLD}${YELLOW}" "Enter new default SSH port: ")" new_port
    
    if ! [[ "$new_port" =~ ^[0-9]+$ ]] || [[ "$new_port" -lt 1 ]] || [[ "$new_port" -gt 65535 ]]; then
        print_error "Invalid port number."
        return
    fi
    
    sed -i "s/^DEFAULT_SSH_PORT=.*/DEFAULT_SSH_PORT=\"${new_port}\"/" "${SETTINGS_CONF}"
    print_success "Default SSH port changed to: $new_port"
    load_settings # Reload settings after change
    sleep 2
}

change_preferred_provider() {
    print_header "CHANGE PREFERRED PROVIDER"
    
    echo -e "${BOLD}Available providers:${RESET}\n"
    echo "  1) Oracle Cloud"
    echo "  2) Google Cloud Platform"
    echo "  3) Amazon Web Services"
    echo "  4) Microsoft Azure"
    echo ""
    
    read -p "$(print_color "${BOLD}${YELLOW}" "Select provider [1-4]: ")" provider_choice
    
    local provider=""
    case "$provider_choice" in
        1) provider="oracle" ;;
        2) provider="gcp" ;;
        3) provider="aws" ;;
        4) provider="azure" ;;
        *)
            print_error "Invalid choice."
            return
            ;;
    esac
    
    sed -i "s/^PREFERRED_PROVIDER=.*/PREFERRED_PROVIDER=\"${provider}\"/" "${SETTINGS_CONF}"
    print_success "Preferred provider changed to: $provider"
    load_settings # Reload settings after change
    sleep 2
}

toggle_debug_mode() {
    print_header "TOGGLE DEBUG MODE"
    
    current_debug=$(grep "^DEBUG=" "${SETTINGS_CONF}" | cut -d\'=\' -f2 | tr -d \'"\')
    
    if [[ "$current_debug" == "1" ]]; then
        new_debug="0"
        status="disabled"
    else
        new_debug="1"
        status="enabled"
    fi
    
    sed -i "s/^DEBUG=.*/DEBUG=\"${new_debug}\"/" "${SETTINGS_CONF}"
    print_success "Debug mode $status"
    load_settings # Reload settings after change
    sleep 2
}

view_settings() {
    print_header "CURRENT SETTINGS"
    
    echo -e "${BOLD}VPS-Manager Settings:${RESET}\n"
    cat "${SETTINGS_CONF}"
    
    echo ""
    read -p "Press Enter to continue..."
}

# ============================================================================
# ABOUT AND INFO
# ============================================================================

show_about() {
    print_header "ABOUT VPS-MANAGER"
    
    cat << \'EOF\'
VPS-Manager v1.0.0
Professional Free-Tier VPS Management Tool for Termux

Description:
  VPS-Manager is a feature-rich command-line tool designed to help users
  create and manage Virtual Private Server (VPS) instances across multiple
  free-tier cloud providers.

Supported Providers:
  • Oracle Cloud (Always Free Tier)
  • Google Cloud Platform (e2-micro)
  • Amazon Web Services (t2.micro)
  • Microsoft Azure (B1s)

Features:
  • VPS instance management (create, configure, start, stop, delete)
  • SSH connection manager with key generation
  • Server monitoring (CPU, RAM, disk usage)
  • Service deployment (web servers, VPN, proxy)
  • Backup and restore configurations
  • Cloud provider setup guidance

Author: Manus AI
License: MIT
Repository: https://github.com/manus-ai/vps-manager

For more information and documentation, visit the README.md file.

EOF
    
    read -p "Press Enter to continue..."
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    # Initialize configuration
    init_config
    load_settings
    
    # Display banner and start main menu
    main_menu
}

# Run main function
main "$@"
