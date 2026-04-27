#!/bin/bash

################################################################################
# Azure Provider Module - VPS-Manager
# Handles VPS creation, configuration, and management on Microsoft Azure
################################################################################

set -euo pipefail

# Source configuration if available
CONFIG_DIR="${HOME}/.vps-manager"
SERVERS_DB="${CONFIG_DIR}/servers.json"
KEYS_DIR="${CONFIG_DIR}/keys"

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

# Check for Azure CLI installation
check_az_cli() {
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed. Please install it first."
        print_info "Run: curl -sL https://aka.ms/InstallAzureCLIDeb | bash"
        return 1
    fi
    return 0
}

# Get server connection details (from main script or ssh_manager module)
get_server_connection() {
    local server_name="$1"
    
    if [[ ! -f "${SERVERS_DB}" ]]; then
        print_error "Servers database not found."
        return 1
    fi
    
    if ! grep -q "\\"name\\":\\"${server_name}\\"" "${SERVERS_DB}"; then
        print_error "Server not found: ${server_name}"
        return 1
    fi
    
    local server_line=$(grep "\\"name\\":\\"${server_name}\\"" "${SERVERS_DB}")
    
    local ip="" user="root" port="22" key=""
    
    if [[ "$server_line" =~ \\"ip\\":\\"([^\\]+)\\"" ]]; then
        ip="${BASH_REMATCH[1]}"
    fi
    
    if [[ "$server_line" =~ \\"user\\":\\"([^\\]+)\\"" ]]; then
        user="${BASH_REMATCH[1]}"
    fi
    
    if [[ "$server_line" =~ \\"port\\":([0-9]+) ]]; then
        port="${BASH_REMATCH[1]}"
    fi
    
    if [[ "$server_line" =~ \\"key\\":\\"([^\\]+)\\"" ]] && [[ "${BASH_REMATCH[1]}" != "" ]]; then
        key="${BASH_REMATCH[1]}"
    fi
    
    if [[ -z "$ip" ]]; then
        print_error "Could not extract server IP."
        return 1
    fi
    
    echo "${ip}|${user}|${port}|${key}"
}

# Execute SSH command
ssh_exec() {
    local server_name="$1"
    local command="$2"
    
    local connection=$(get_server_connection "$server_name") || return 1
    
    IFS=\'|\' read -r ip user port key <<< "$connection"
    
    if [[ -n "$key" ]] && [[ -f "$key" ]]; then
        ssh -i "$key" -p "$port" -o ConnectTimeout=5 "${user}@${ip}" "$command"
    else
        ssh -p "$port" -o ConnectTimeout=5 "${user}@${ip}" "$command"
    fi
}

# Helper for selecting options from an array
select_option() {
    local options=("$@")
    local PS3="$(print_color "${BOLD}${YELLOW}" "Enter your choice: ")"
    select opt in "${options[@]}"; do
        if [[ -n "$opt" ]]; then
            return $((REPLY))
        else
            print_error "Invalid option. Please try again."
        fi
    done
}

# ============================================================================
# AZURE SPECIFIC FUNCTIONS
# ============================================================================

# Get Azure locations
get_azure_locations() {
    check_az_cli || return 1
    print_info "Fetching Azure locations..."
    az account list-locations --query "[].name" -o tsv
}

# Get Azure images (Ubuntu)
get_azure_images() {
    check_az_cli || return 1
    local location="$1"
    print_info "Fetching Azure images for location ${location}..."
    az vm image list --location "$location" --publisher Canonical --offer UbuntuServer --sku 20.04-LTS --all --query "[].urn" -o tsv
}

# Create Azure Resource Group
create_azure_resource_group() {
    check_az_cli || return 1
    local rg_name="$1"
    local location="$2"
    
    print_info "Creating resource group \"${rg_name}\" in location ${location}..."
    az group create --name "$rg_name" --location "$location" -o tsv || {
        print_warning "Resource group \"${rg_name}\" might already exist."
    }
    print_success "Resource group \"${rg_name}\" created/exists."
}

# Create Azure VPS instance
create_azure_vps() {
    local vps_name="$1"
    local ssh_public_key_path="$2"
    
    check_az_cli || return 1
    
    if [[ ! -f "${ssh_public_key_path}" ]]; then
        print_error "SSH public key not found at: ${ssh_public_key_path}"
        return 1
    fi
    
    print_info "Starting Azure VPS creation for: ${vps_name}"
    
    # 1. Select Location
    local locations=($(get_azure_locations))
    if [[ ${#locations[@]} -eq 0 ]]; then
        print_error "No Azure locations found or Azure CLI not configured."
        return 1
    fi
    
    echo -e "${BOLD}Select a Location:${RESET}\n"
    select_option "${locations[@]}"
    local location_choice=$?
    local location="${locations[$((location_choice-1))]}"
    print_info "Selected Location: ${location}"
    
    # 2. Create Resource Group
    local resource_group_name="${vps_name}-rg"
    create_azure_resource_group "$resource_group_name" "$location"
    
    # 3. Choose Image (Ubuntu 20.04 LTS)
    local image_urn="Canonical:UbuntuServer:20.04-LTS:latest"
    print_info "Using image: ${image_urn}"
    
    # 4. Choose VM Size (B1s for free tier)
    local vm_size="Standard_B1s"
    print_info "Using VM size: ${vm_size} (Azure Free Tier)"
    
    # 5. Create instance
    print_info "Creating instance... This may take a few minutes."
    
    local create_command="az vm create \
        --resource-group \"${resource_group_name}\" \
        --name \"${vps_name}\" \
        --image \"${image_urn}\" \
        --size \"${vm_size}\" \
        --admin-username azureuser \
        --ssh-key-values \"$(cat "${ssh_public_key_path}")\" \
        --location \"${location}\" \
        --public-ip-sku Standard \
        --output json"
    
    local instance_json=$(eval "$create_command" 2>&1)
    local public_ip=$(echo "$instance_json" | jq -r ".publicIpAddress")
    local vm_id=$(echo "$instance_json" | jq -r ".id")
    
    if [[ -z "$public_ip" ]]; then
        print_error "Failed to create Azure VPS. Error: ${instance_json}"
        return 1
    fi
    
    print_success "Azure VPS \"${vps_name}\" created successfully!"
    print_info "Public IP: ${public_ip}"
    print_info "VM ID: ${vm_id}"
    
    # Add to servers.json (assuming azureuser for Azure Ubuntu VMs)
    local server_entry="{\"name\":\"${vps_name}\",\"ip\":\"${public_ip}\",\"user\":\"azureuser\",\"port\":22,\"key\":\"${ssh_public_key_path/%.pub/}\"}"
    
    # Append to database (simple implementation without jq)
    local temp_file="${SERVERS_DB}.tmp"
    
    # Remove trailing ]
    head -c -2 "${SERVERS_DB}" > "${temp_file}"
    
    # Add comma and new entry
    if [[ $(wc -c < "${temp_file}") -gt 1 ]]; then
        echo "," >> "${temp_file}"
    fi
    
    echo "${server_entry}]" >> "${temp_file}"
    mv "${temp_file}" "${SERVERS_DB}"
    
    print_success "Server profile added to VPS-Manager."
    
    # Automated setup (install common packages, configure firewall, etc.)
    print_info "Running automated setup on new VPS..."
    ssh_exec "$vps_name" "sudo apt-get update && sudo apt-get install -y curl wget git ufw && sudo ufw allow OpenSSH && sudo ufw --force enable" || {
        print_warning "Automated setup failed. Please check connectivity and run manually."
    }
    print_success "Automated setup complete."
    
    return 0
}

# List Azure VPS instances
list_azure_vps() {
    check_az_cli || return 1
    print_info "Listing Azure VPS instances..."
    az vm list --query "[].{Name:name,ResourceGroup:resourceGroup,Location:location,PowerState:powerState,PublicIpAddress:networkProfile.networkInterfaces[0].ipConfigurations[0].publicIpAddress.ipAddress}" -o json
}

# Start Azure VPS instance
start_azure_vps() {
    local vps_name="$1"
    local resource_group_name="$2"
    check_az_cli || return 1
    print_info "Starting Azure VPS instance: ${vps_name} in resource group ${resource_group_name}"
    az vm start --resource-group "$resource_group_name" --name "$vps_name" -o tsv
    print_success "Instance started: ${vps_name}"
}

# Stop Azure VPS instance
stop_azure_vps() {
    local vps_name="$1"
    local resource_group_name="$2"
    check_az_cli || return 1
    print_info "Stopping Azure VPS instance: ${vps_name} in resource group ${resource_group_name}"
    az vm stop --resource-group "$resource_group_name" --name "$vps_name" -o tsv
    print_success "Instance stopped: ${vps_name}"
}

# Reboot Azure VPS instance
reboot_azure_vps() {
    local vps_name="$1"
    local resource_group_name="$2"
    check_az_cli || return 1
    print_info "Rebooting Azure VPS instance: ${vps_name} in resource group ${resource_group_name}"
    az vm restart --resource-group "$resource_group_name" --name "$vps_name" -o tsv
    print_success "Instance rebooted: ${vps_name}"
}

# Delete Azure VPS instance
delete_azure_vps() {
    local vps_name="$1"
    local resource_group_name="$2"
    check_az_cli || return 1
    print_warning "This will permanently delete Azure VPS instance: ${vps_name} and its resource group ${resource_group_name}"
    read -p "Are you sure? (y/n): " confirm
    if [[ "$confirm" == "y" ]]; then
        az group delete --name "$resource_group_name" --yes --no-wait -o tsv
        print_success "Instance and resource group deleted: ${vps_name}"
    else
        print_info "Deletion cancelled."
    fi
}

# ============================================================================
# MAIN EXECUTION (if script is called directly)
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script was called directly
    case "${1:-help}" in
        create)
            create_azure_vps "${2:-}" "${3:-}"
            ;;
        list)
            list_azure_vps
            ;;
        start)
            start_azure_vps "${2:-}" "${3:-}"
            ;;
        stop)
            stop_azure_vps "${2:-}" "${3:-}"
            ;;
        reboot)
            reboot_azure_vps "${2:-}" "${3:-}"
            ;;
        delete)
            delete_azure_vps "${2:-}" "${3:-}"
            ;;
        *)
            echo "Azure Provider Module - VPS-Manager"
            echo ""
            echo "Usage: $0 <command> [options]"
            echo ""
            echo "Commands:"
            echo "  create [vps_name] [ssh_public_key_path]  Create new Azure VPS"
            echo "  list                                     List all Azure VPS instances"
            echo "  start [vps_name] [resource_group]        Start Azure VPS instance"
            echo "  stop [vps_name] [resource_group]         Stop Azure VPS instance"
            echo "  reboot [vps_name] [resource_group]       Reboot Azure VPS instance"
            echo "  delete [vps_name] [resource_group]       Delete Azure VPS instance"
            ;;
    esac
fi
