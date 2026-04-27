#!/bin/bash

################################################################################
# VPS Management Module - VPS-Manager
# Integrates provider-specific functions for creating, listing, and managing VPS instances
################################################################################

set -euo pipefail

# Source configuration if available
CONFIG_DIR="${HOME}/.vps-manager"
SERVERS_DB="${CONFIG_DIR}/servers.json"
KEYS_DIR="${CONFIG_DIR}/keys"

# Source provider modules
# These are sourced by the main script, so no need to source here again if this is called as a function
# If this module is run directly, these would need to be sourced.
# For now, assume main script handles sourcing.

# ============================================================================
# COLOR DEFINITIONS
# ============================================================================

readonly RED=\'\\033[0;31m\'
readonly GREEN=\'\\033[0;32m\'
readonly YELLOW=\'\\033[1;33m\'
readonly BLUE=\'\\033[0;34m\'
readonly CYAN=\'\\033[0;36m\'
readonly RESET=\'\\033[0m\'
readonly BOLD=\'\\033[1m\'

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

print_success() {
    echo -e "${GREEN}✓ $1${RESET}"
}

print_error() {
    echo -e "${RED}✗ $1${RESET}"
}

print_info() {
    echo -e "${CYAN}ℹ $1${RESET}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${RESET}"
}

# Helper for selecting options from an array
select_option() {
    local options=("$@")
    local PS3="$(print_color "${BOLD}${YELLOW}" "Enter your choice: ")"
    select opt in "${options[@]}"; do
        if [[ -n "$opt" ]]; then
            echo "$REPLY"
            return 0
        else
            print_error "Invalid option. Please try again."
        fi
    done
    return 1
}

# Get server details from servers.json
get_server_details() {
    local server_name="$1"
    if [[ ! -f "${SERVERS_DB}" ]]; then
        print_error "Servers database not found."
        return 1
    fi
    
    local server_info=$(jq -r ".[] | select(.name == \"${server_name}\")" "${SERVERS_DB}")
    if [[ -z "$server_info" ]]; then
        print_error "Server not found: ${server_name}"
        return 1
    fi
    echo "$server_info"
}

# ============================================================================
# VPS MANAGEMENT FUNCTIONS
# ============================================================================

# List all VPS instances (from local database)
list_vps_instances() {
    print_info "Listing all registered VPS instances..."
    if [[ ! -f "${SERVERS_DB}" ]] || [[ ! -s "${SERVERS_DB}" ]] || [[ "$(cat "${SERVERS_DB}")" == "[]" ]]; then
        print_warning "No VPS instances found in local database. Create one to get started!"
        return 1
    fi
    
    echo -e "${BOLD}Registered VPS Instances:${RESET}\n"
    jq -r ".[] | \"Name: \(.name), IP: \(.ip), User: \(.user), Port: \(.port), Key: \(.key)\"" "${SERVERS_DB}"
    echo ""
    return 0
}

# Create a new VPS instance
create_vps() {
    print_info "Starting new VPS creation process..."
    
    read -p "$(print_color "${BOLD}${YELLOW}" "Enter desired VPS name: ")" vps_name
    if [[ -z "$vps_name" ]]; then
        print_error "VPS name cannot be empty."
        return 1
    fi
    
    # Check if VPS name already exists
    if jq -e ".[] | select(.name == \"${vps_name}\")" "${SERVERS_DB}" &>/dev/null; then
        print_error "A VPS with name \"${vps_name}\" already exists. Please choose a different name."
        return 1
    fi
    
    echo -e "${BOLD}Select a Cloud Provider:${RESET}\n"
    local providers=("Oracle Cloud" "Google Cloud Platform" "AWS" "Azure")
    local provider_choice_idx=$(select_option "${providers[@]}")
    if [[ "$provider_choice_idx" -eq 0 ]]; then
        print_info "VPS creation cancelled."
        return 1
    fi
    local provider_name="${providers[$((provider_choice_idx-1))]}"
    
    read -p "$(print_color "${BOLD}${YELLOW}" "Enter path to SSH public key (e.g., ~/.ssh/id_rsa.pub or ~/.vps-manager/keys/my_key.pub): ")" ssh_public_key_path
    if [[ ! -f "${ssh_public_key_path}" ]]; then
        print_error "SSH public key not found at: ${ssh_public_key_path}"
        print_info "Please generate one using the SSH Connection Manager or provide a valid path."
        return 1
    fi
    
    case "$provider_name" in
        "Oracle Cloud")
            # Source the oracle.sh module and call its create function
            if [[ -f "${MODULES_DIR}/providers/oracle.sh" ]]; then
                source "${MODULES_DIR}/providers/oracle.sh"
                create_oracle_vps "$vps_name" "$ssh_public_key_path"
            else
                print_error "Oracle Cloud provider module not found."
            fi
            ;;
        "Google Cloud Platform")
            if [[ -f "${MODULES_DIR}/providers/gcp.sh" ]]; then
                source "${MODULES_DIR}/providers/gcp.sh"
                create_gcp_vps "$vps_name" "$ssh_public_key_path"
            else
                print_error "Google Cloud Platform provider module not found."
            fi
            ;;
        "AWS")
            if [[ -f "${MODULES_DIR}/providers/aws.sh" ]]; then
                source "${MODULES_DIR}/providers/aws.sh"
                # AWS create_aws_vps expects key name, not path
                local key_name=$(basename "${ssh_public_key_path}" .pub)
                create_aws_vps "$vps_name" "$key_name"
            else
                print_error "AWS provider module not found."
            fi
            ;;
        "Azure")
            if [[ -f "${MODULES_DIR}/providers/azure.sh" ]]; then
                source "${MODULES_DIR}/providers/azure.sh"
                create_azure_vps "$vps_name" "$ssh_public_key_path"
            else
                print_error "Azure provider module not found."
            fi
            ;;
        *)
            print_error "Unsupported cloud provider."
            ;;
    esac
}

# Select a VPS from the list
select_vps() {
    local vps_names=($(jq -r ".[] | .name" "${SERVERS_DB}"))
    if [[ ${#vps_names[@]} -eq 0 ]]; then
        print_warning "No VPS instances found."
        return 1
    fi
    
    echo -e "${BOLD}Select a VPS instance:${RESET}\n"
    local vps_choice_idx=$(select_option "${vps_names[@]}")
    if [[ "$vps_choice_idx" -eq 0 ]]; then
        return 1
    fi
    echo "${vps_names[$((vps_choice_idx-1))]}"
    return 0
}

# Configure a VPS (placeholder for now)
configure_vps() {
    print_info "This feature is under development. Manual configuration via SSH is recommended."
    local selected_vps=$(select_vps)
    if [[ -z "$selected_vps" ]]; then
        print_info "No VPS selected for configuration."
        return 1
    fi
    print_info "Configuring VPS: ${selected_vps}"
    # Future: Offer options to install common software, set up firewall, etc.
    # This would likely involve calling functions from deploy_services.sh via ssh_exec
}

# Start a VPS instance
start_vps() {
    local selected_vps=$(select_vps)
    if [[ -z "$selected_vps" ]]; then
        print_info "No VPS selected to start."
        return 1
    fi
    
    local server_info=$(get_server_details "$selected_vps")
    local provider=$(echo "$server_info" | jq -r ".provider") # Assuming provider field will be added to servers.json
    local instance_id=$(echo "$server_info" | jq -r ".instance_id") # Assuming instance_id field will be added
    local region=$(echo "$server_info" | jq -r ".region") # Assuming region field will be added
    local zone=$(echo "$server_info" | jq -r ".zone") # Assuming zone field will be added
    local resource_group=$(echo "$server_info" | jq -r ".resource_group") # Assuming resource_group field will be added
    
    case "$provider" in
        "Oracle Cloud")
            if [[ -f "${MODULES_DIR}/providers/oracle.sh" ]]; then
                source "${MODULES_DIR}/providers/oracle.sh"
                start_oracle_vps "$instance_id"
            else
                print_error "Oracle Cloud provider module not found."
            fi
            ;;
        "Google Cloud Platform")
            if [[ -f "${MODULES_DIR}/providers/gcp.sh" ]]; then
                source "${MODULES_DIR}/providers/gcp.sh"
                start_gcp_vps "$selected_vps" "$zone"
            else
                print_error "Google Cloud Platform provider module not found."
            fi
            ;;
        "AWS")
            if [[ -f "${MODULES_DIR}/providers/aws.sh" ]]; then
                source "${MODULES_DIR}/providers/aws.sh"
                start_aws_vps "$instance_id" "$region"
            else
                print_error "AWS provider module not found."
            fi
            ;;
        "Azure")
            if [[ -f "${MODULES_DIR}/providers/azure.sh" ]]; then
                source "${MODULES_DIR}/providers/azure.sh"
                start_azure_vps "$selected_vps" "$resource_group"
            else
                print_error "Azure provider module not found."
            }
            ;;
        *)
            print_error "Unsupported cloud provider for starting VPS."
            ;;
    esac
}

# Stop a VPS instance
stop_vps() {
    local selected_vps=$(select_vps)
    if [[ -z "$selected_vps" ]]; then
        print_info "No VPS selected to stop."
        return 1
    fi
    
    local server_info=$(get_server_details "$selected_vps")
    local provider=$(echo "$server_info" | jq -r ".provider")
    local instance_id=$(echo "$server_info" | jq -r ".instance_id")
    local region=$(echo "$server_info" | jq -r ".region")
    local zone=$(echo "$server_info" | jq -r ".zone")
    local resource_group=$(echo "$server_info" | jq -r ".resource_group")
    
    case "$provider" in
        "Oracle Cloud")
            if [[ -f "${MODULES_DIR}/providers/oracle.sh" ]]; then
                source "${MODULES_DIR}/providers/oracle.sh"
                stop_oracle_vps "$instance_id"
            else
                print_error "Oracle Cloud provider module not found."
            fi
            ;;
        "Google Cloud Platform")
            if [[ -f "${MODULES_DIR}/providers/gcp.sh" ]]; then
                source "${MODULES_DIR}/providers/gcp.sh"
                stop_gcp_vps "$selected_vps" "$zone"
            else
                print_error "Google Cloud Platform provider module not found."
            fi
            ;;
        "AWS")
            if [[ -f "${MODULES_DIR}/providers/aws.sh" ]]; then
                source "${MODULES_DIR}/providers/aws.sh"
                stop_aws_vps "$instance_id" "$region"
            else
                print_error "AWS provider module not found."
            fi
            ;;
        "Azure")
            if [[ -f "${MODULES_DIR}/providers/azure.sh" ]]; then
                source "${MODULES_DIR}/providers/azure.sh"
                stop_azure_vps "$selected_vps" "$resource_group"
            else
                print_error "Azure provider module not found."
            fi
            ;;
        *)
            print_error "Unsupported cloud provider for stopping VPS."
            ;;
    esac
}

# Restart a VPS instance
restart_vps() {
    local selected_vps=$(select_vps)
    if [[ -z "$selected_vps" ]]; then
        print_info "No VPS selected to restart."
        return 1
    fi
    
    local server_info=$(get_server_details "$selected_vps")
    local provider=$(echo "$server_info" | jq -r ".provider")
    local instance_id=$(echo "$server_info" | jq -r ".instance_id")
    local region=$(echo "$server_info" | jq -r ".region")
    local zone=$(echo "$server_info" | jq -r ".zone")
    local resource_group=$(echo "$server_info" | jq -r ".resource_group")
    
    case "$provider" in
        "Oracle Cloud")
            if [[ -f "${MODULES_DIR}/providers/oracle.sh" ]]; then
                source "${MODULES_DIR}/providers/oracle.sh"
                reboot_oracle_vps "$instance_id"
            else
                print_error "Oracle Cloud provider module not found."
            fi
            ;;
        "Google Cloud Platform")
            if [[ -f "${MODULES_DIR}/providers/gcp.sh" ]]; then
                source "${MODULES_DIR}/providers/gcp.sh"
                reboot_gcp_vps "$selected_vps" "$zone"
            else
                print_error "Google Cloud Platform provider module not found."
            fi
            ;;
        "AWS")
            if [[ -f "${MODULES_DIR}/providers/aws.sh" ]]; then
                source "${MODULES_DIR}/providers/aws.sh"
                reboot_aws_vps "$instance_id" "$region"
            else
                print_error "AWS provider module not found."
            fi
            ;;
        "Azure")
            if [[ -f "${MODULES_DIR}/providers/azure.sh" ]]; then
                source "${MODULES_DIR}/providers/azure.sh"
                reboot_azure_vps "$selected_vps" "$resource_group"
            else
                print_error "Azure provider module not found."
            fi
            ;;
        *)
            print_error "Unsupported cloud provider for rebooting VPS."
            ;;
    esac
}

# Delete a VPS instance
delete_vps() {
    local selected_vps=$(select_vps)
    if [[ -z "$selected_vps" ]]; then
        print_info "No VPS selected to delete."
        return 1
    }
    
    local server_info=$(get_server_details "$selected_vps")
    local provider=$(echo "$server_info" | jq -r ".provider")
    local instance_id=$(echo "$server_info" | jq -r ".instance_id")
    local region=$(echo "$server_info" | jq -r ".region")
    local zone=$(echo "$server_info" | jq -r ".zone")
    local resource_group=$(echo "$server_info" | jq -r ".resource_group")
    
    print_warning "This action will permanently delete the VPS instance: ${selected_vps}"
    read -p "Are you absolutely sure you want to delete this VPS? (y/N): " confirm_delete
    if [[ "$confirm_delete" != "y" ]]; then
        print_info "VPS deletion cancelled."
        return 0
    fi
    
    case "$provider" in
        "Oracle Cloud")
            if [[ -f "${MODULES_DIR}/providers/oracle.sh" ]]; then
                source "${MODULES_DIR}/providers/oracle.sh"
                terminate_oracle_vps "$instance_id"
            else
                print_error "Oracle Cloud provider module not found."
            fi
            ;;
        "Google Cloud Platform")
            if [[ -f "${MODULES_DIR}/providers/gcp.sh" ]]; then
                source "${MODULES_DIR}/providers/gcp.sh"
                delete_gcp_vps "$selected_vps" "$zone"
            else
                print_error "Google Cloud Platform provider module not found."
            fi
            ;;
        "AWS")
            if [[ -f "${MODULES_DIR}/providers/aws.sh" ]]; then
                source "${MODULES_DIR}/providers/aws.sh"
                terminate_aws_vps "$instance_id" "$region"
            else
                print_error "AWS provider module not found."
            fi
            ;;
        "Azure")
            if [[ -f "${MODULES_DIR}/providers/azure.sh" ]]; then
                source "${MODULES_DIR}/providers/azure.sh"
                delete_azure_vps "$selected_vps" "$resource_group"
            else
                print_error "Azure provider module not found."
            fi
            ;;
        *)
            print_error "Unsupported cloud provider for deleting VPS."
            ;;
    esac
    
    # Remove from local database after successful deletion from cloud
    if [[ "$?" -eq 0 ]]; then
        local temp_file="${SERVERS_DB}.tmp"
        jq "del(.[] | select(.name == \"${selected_vps}\"))" "${SERVERS_DB}" > "${temp_file}" && mv "${temp_file}" "${SERVERS_DB}"
        print_success "VPS \"${selected_vps}\" removed from local database."
    fi
}

# ============================================================================
# MAIN EXECUTION (if script is called directly)
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script was called directly
    case "${1:-help}" in
        list)
            list_vps_instances
            ;;
        create)
            create_vps
            ;;
        configure)
            configure_vps
            ;;
        start)
            start_vps
            ;;
        stop)
            stop_vps
            ;;
        restart)
            restart_vps
            ;;
        delete)
            delete_vps
            ;;
        *)
            echo "VPS Management Module - VPS-Manager"
            echo ""
            echo "Usage: $0 <command>"
            echo ""
            echo "Commands:"
            echo "  list          List all registered VPS instances"
            echo "  create        Create a new VPS instance"
            echo "  configure     Configure an existing VPS instance"
            echo "  start         Start a VPS instance"
            echo "  stop          Stop a VPS instance"
            echo "  restart       Restart a VPS instance"
            echo "  delete        Delete a VPS instance"
            ;;
    esac
fi
