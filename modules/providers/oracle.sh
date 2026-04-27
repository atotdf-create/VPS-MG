#!/bin/bash

################################################################################
# Oracle Cloud Provider Module - VPS-Manager
# Handles VPS creation, configuration, and management on Oracle Cloud
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

# Check for OCI CLI installation
check_oci_cli() {
    if ! command -v oci &> /dev/null; then
        print_error "OCI CLI is not installed. Please install it first."
        print_info "Run: pip3 install oci-cli"
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

# ============================================================================
# ORACLE CLOUD SPECIFIC FUNCTIONS
# ============================================================================

# Get Oracle Cloud compartments
get_oci_compartments() {
    check_oci_cli || return 1
    print_info "Fetching Oracle Cloud compartments..."
    oci identity compartment list --all --query "data[?\"lifecycle-state\" == \'ACTIVE\'].{\"name\":name,\"id\":id}" --output json
}

# Get Oracle Cloud ADs
get_oci_availability_domains() {
    check_oci_cli || return 1
    local compartment_id="$1"
    print_info "Fetching Oracle Cloud Availability Domains..."
    oci iam availability-domain list --compartment-id "$compartment_id" --query "data[].{\"name\":name}" --output json
}

# Get Oracle Cloud images
get_oci_images() {
    check_oci_cli || return 1
    local compartment_id="$1"
    print_info "Fetching Oracle Cloud images..."
    oci compute image list --compartment-id "$compartment_id" --operating-system "Canonical Ubuntu" --query "data[?\"lifecycle-state\" == \'AVAILABLE\'].{\"display-name\":\"display-name\",\"id\":id}" --output json
}

# Get Oracle Cloud shapes
get_oci_shapes() {
    check_oci_cli || return 1
    local compartment_id="$1"
    print_info "Fetching Oracle Cloud shapes..."
    oci compute shape list --compartment-id "$compartment_id" --query "data[?contains(\"shape\", \'VM.Standard.A1.Flex\')].{\"shape\":shape,\"ocpus\":\"ocpus\",\"memory_in_gbs\":\"memory-in-gbs\"}" --output json
}

# Create Oracle Cloud VPS instance
create_oracle_vps() {
    local vps_name="$1"
    local ssh_public_key_path="$2"
    
    check_oci_cli || return 1
    
    if [[ ! -f "${ssh_public_key_path}" ]]; then
        print_error "SSH public key not found at: ${ssh_public_key_path}"
        return 1
    fi
    
    print_info "Starting Oracle Cloud VPS creation for: ${vps_name}"
    
    # 1. Select Compartment
    local compartments_json=$(get_oci_compartments)
    if [[ -z "$compartments_json" ]]; then
        print_error "No compartments found or OCI CLI not configured."
        return 1
    fi
    
    echo -e "${BOLD}Select a Compartment:${RESET}\n"
    local compartment_names=($(echo "$compartments_json" | jq -r ".[].name"))
    local compartment_ids=($(echo "$compartments_json" | jq -r ".[].id"))
    
    select_option "${compartment_names[@]}"
    local compartment_choice=$?
    local compartment_id="${compartment_ids[$((compartment_choice-1))]}"
    local compartment_name="${compartment_names[$((compartment_choice-1))]}"
    print_info "Selected Compartment: ${compartment_name}"
    
    # 2. Select Availability Domain
    local ads_json=$(get_oci_availability_domains "$compartment_id")
    if [[ -z "$ads_json" ]]; then
        print_error "No Availability Domains found."
        return 1
    fi
    
    echo -e "${BOLD}Select an Availability Domain:${RESET}\n"
    local ad_names=($(echo "$ads_json" | jq -r ".[].name"))
    
    select_option "${ad_names[@]}"
    local ad_choice=$?
    local availability_domain="${ad_names[$((ad_choice-1))]}"
    print_info "Selected Availability Domain: ${availability_domain}"
    
    # 3. Select Image
    local images_json=$(get_oci_images "$compartment_id")
    if [[ -z "$images_json" ]]; then
        print_error "No images found."
        return 1
    fi
    
    echo -e "${BOLD}Select an Image (Ubuntu recommended):${RESET}\n"
    local image_display_names=($(echo "$images_json" | jq -r ".[].\"display-name\""))
    local image_ids=($(echo "$images_json" | jq -r ".[].id"))
    
    select_option "${image_display_names[@]}"
    local image_choice=$?
    local image_id="${image_ids[$((image_choice-1))]}"
    local image_name="${image_display_names[$((image_choice-1))]}"
    print_info "Selected Image: ${image_name}"
    
    # 4. Select Shape
    local shapes_json=$(get_oci_shapes "$compartment_id")
    if [[ -z "$shapes_json" ]]; then
        print_error "No compatible shapes found (VM.Standard.A1.Flex recommended for free tier)."
        return 1
    fi
    
    echo -e "${BOLD}Select a Shape (VM.Standard.A1.Flex recommended):${RESET}\n"
    local shape_names=($(echo "$shapes_json" | jq -r ".[].shape"))
    local shape_ocpus=($(echo "$shapes_json" | jq -r ".[].ocpus"))
    local shape_memory=($(echo "$shapes_json" | jq -r ".[].memory_in_gbs"))
    
    local shape_options=()
    for i in "${!shape_names[@]}"; do
        shape_options+=("${shape_names[$i]} (OCPUs: ${shape_ocpus[$i]}, RAM: ${shape_memory[$i]}GB)")
    done
    
    select_option "${shape_options[@]}"
    local shape_choice=$?
    local shape="${shape_names[$((shape_choice-1))]}"
    print_info "Selected Shape: ${shape}"
    
    # 5. Provide VCN and Subnet (simplified, assume default or user input)
    read -p "$(print_color "${BOLD}${YELLOW}" "Enter VCN OCID (or leave empty for default in compartment): ")" vcn_id
    read -p "$(print_color "${BOLD}${YELLOW}" "Enter Subnet OCID (or leave empty for default in VCN): ")" subnet_id
    
    # 6. Create instance
    print_info "Creating instance... This may take a few minutes."
    
    local create_command="oci compute instance launch \
        --availability-domain \"${availability_domain}\" \
        --compartment-id \"${compartment_id}\" \
        --shape \"${shape}\" \
        --image-id \"${image_id}\" \
        --display-name \"${vps_name}\" \
        --ssh-authorized-keys-file \"${ssh_public_key_path}\" \
        --subnet-id \"${subnet_id}\" \
        --assign-public-ip true \
        --wait-for-state RUNNING"
    
    if [[ -n "$vcn_id" ]]; then
        create_command="${create_command} --vcn-id \"${vcn_id}\""
    fi
    
    local instance_json=$(eval "$create_command" 2>&1)
    local instance_id=$(echo "$instance_json" | jq -r ".data.id")
    local public_ip=$(echo "$instance_json" | jq -r ".data.\"public-ip\"")
    
    if [[ -z "$instance_id" ]]; then
        print_error "Failed to create Oracle Cloud VPS. Error: ${instance_json}"
        return 1
    fi
    
    print_success "Oracle Cloud VPS \"${vps_name}\" created successfully!"
    print_info "Instance ID: ${instance_id}"
    print_info "Public IP: ${public_ip}"
    
    # Add to servers.json (simplified, assuming root user for now)
    local server_entry="{\"name\":\"${vps_name}\",\"ip\":\"${public_ip}\",\"user\":\"ubuntu\",\"port\":22,\"key\":\"${ssh_public_key_path/%.pub/}\"}"
    
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

# List Oracle Cloud VPS instances
list_oracle_vps() {
    check_oci_cli || return 1
    print_info "Listing Oracle Cloud VPS instances..."
    oci compute instance list --all --query "data[].{\"display-name\":\"display-name\",\"id\":id,\"lifecycle-state\":\"lifecycle-state\",\"public-ip\":\"public-ip\"}" --output json
}

# Start Oracle Cloud VPS instance
start_oracle_vps() {
    local instance_id="$1"
    check_oci_cli || return 1
    print_info "Starting Oracle Cloud VPS instance: ${instance_id}"
    oci compute instance action --action START --instance-id "$instance_id" --wait-for-state RUNNING
    print_success "Instance started: ${instance_id}"
}

# Stop Oracle Cloud VPS instance
stop_oracle_vps() {
    local instance_id="$1"
    check_oci_cli || return 1
    print_info "Stopping Oracle Cloud VPS instance: ${instance_id}"
    oci compute instance action --action STOP --instance-id "$instance_id" --wait-for-state STOPPED
    print_success "Instance stopped: ${instance_id}"
}

# Reboot Oracle Cloud VPS instance
reboot_oracle_vps() {
    local instance_id="$1"
    check_oci_cli || return 1
    print_info "Rebooting Oracle Cloud VPS instance: ${instance_id}"
    oci compute instance action --action SOFTRESET --instance-id "$instance_id" --wait-for-state RUNNING
    print_success "Instance rebooted: ${instance_id}"
}

# Terminate Oracle Cloud VPS instance
terminate_oracle_vps() {
    local instance_id="$1"
    check_oci_cli || return 1
    print_warning "This will permanently terminate Oracle Cloud VPS instance: ${instance_id}"
    read -p "Are you sure? (y/n): " confirm
    if [[ "$confirm" == "y" ]]; then
        oci compute instance terminate --instance-id "$instance_id" --preserve-boot-volume false --wait-for-state TERMINATED
        print_success "Instance terminated: ${instance_id}"
    else
        print_info "Termination cancelled."
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
# MAIN EXECUTION (if script is called directly)
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script was called directly
    case "${1:-help}" in
        create)
            create_oracle_vps "${2:-}" "${3:-}"
            ;;
        list)
            list_oracle_vps
            ;;
        start)
            start_oracle_vps "${2:-}"
            ;;
        stop)
            stop_oracle_vps "${2:-}"
            ;;
        reboot)
            reboot_oracle_vps "${2:-}"
            ;;
        terminate)
            terminate_oracle_vps "${2:-}"
            ;;
        *)
            echo "Oracle Cloud Provider Module - VPS-Manager"
            echo ""
            echo "Usage: $0 <command> [options]"
            echo ""
            echo "Commands:"
            echo "  create [vps_name] [ssh_public_key_path]  Create new Oracle Cloud VPS"
            echo "  list                                     List all Oracle Cloud VPS instances"
            echo "  start [instance_id]                      Start Oracle Cloud VPS instance"
            echo "  stop [instance_id]                       Stop Oracle Cloud VPS instance"
            echo "  reboot [instance_id]                     Reboot Oracle Cloud VPS instance"
            echo "  terminate [instance_id]                  Terminate Oracle Cloud VPS instance"
            ;;
    esac
fi
