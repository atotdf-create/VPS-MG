#!/bin/bash

################################################################################
# Google Cloud Platform Provider Module - VPS-Manager
# Handles VPS creation, configuration, and management on Google Cloud Platform
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

# Check for gcloud CLI installation
check_gcloud_cli() {
    if ! command -v gcloud &> /dev/null; then
        print_error "gcloud CLI is not installed. Please install it first."
        print_info "Visit: https://cloud.google.com/sdk/docs/install"
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
# GOOGLE CLOUD PLATFORM SPECIFIC FUNCTIONS
# ============================================================================

# Get GCP projects
get_gcp_projects() {
    check_gcloud_cli || return 1
    print_info "Fetching Google Cloud projects..."
    gcloud projects list --format="json" | jq -r ".[].projectId"
}

# Get GCP zones
get_gcp_zones() {
    check_gcloud_cli || return 1
    local project_id="$1"
    print_info "Fetching Google Cloud zones..."
    gcloud compute zones list --project="$project_id" --format="json" | jq -r ".[].name"
}

# Create GCP VPS instance
create_gcp_vps() {
    local vps_name="$1"
    local ssh_public_key_path="$2"
    
    check_gcloud_cli || return 1
    
    if [[ ! -f "${ssh_public_key_path}" ]]; then
        print_error "SSH public key not found at: ${ssh_public_key_path}"
        return 1
    fi
    
    print_info "Starting Google Cloud VPS creation for: ${vps_name}"
    
    # 1. Select Project
    local projects=($(get_gcp_projects))
    if [[ ${#projects[@]} -eq 0 ]]; then
        print_error "No Google Cloud projects found or gcloud not configured."
        return 1
    fi
    
    echo -e "${BOLD}Select a Project:${RESET}\n"
    select_option "${projects[@]}"
    local project_choice=$?
    local project_id="${projects[$((project_choice-1))]}"
    print_info "Selected Project: ${project_id}"
    
    gcloud config set project "$project_id"
    
    # 2. Select Zone
    local zones=($(get_gcp_zones "$project_id"))
    if [[ ${#zones[@]} -eq 0 ]]; then
        print_error "No Google Cloud zones found."
        return 1
    fi
    
    echo -e "${BOLD}Select a Zone:${RESET}\n"
    select_option "${zones[@]}"
    local zone_choice=$?
    local zone="${zones[$((zone_choice-1))]}"
    print_info "Selected Zone: ${zone}"
    
    gcloud config set compute/zone "$zone"
    
    # 3. Choose Machine Type (e2-micro for free tier)
    local machine_type="e2-micro"
    print_info "Using machine type: ${machine_type} (Google Cloud Free Tier)"
    
    # 4. Choose Image (Debian or Ubuntu recommended)
    local image_project="debian-cloud"
    local image_family="debian-11"
    read -p "$(print_color "${BOLD}${YELLOW}" "Enter image family (default: debian-11): ")" user_image_family
    image_family="${user_image_family:-debian-11}"
    print_info "Using image family: ${image_family} from project: ${image_project}"
    
    # 5. Create instance
    print_info "Creating instance... This may take a few minutes."
    
    local create_command="gcloud compute instances create \"${vps_name}\" \
        --project=\"${project_id}\" \
        --zone=\"${zone}\" \
        --machine-type=\"${machine_type}\" \
        --image-family=\"${image_family}\" \
        --image-project=\"${image_project}\" \
        --boot-disk-size=\"30GB\" \
        --boot-disk-type=\"pd-standard\" \
        --metadata=ssh-keys=\"$(whoami):$(cat "${ssh_public_key_path}")\" \
        --network-interface=network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=default \
        --provisioning-model=STANDARD \
        --no-restart-on-failure \
        --maintenance-policy=MIGRATE \
        --tags=http-server,https-server \
        --format=json"
    
    local instance_json=$(eval "$create_command" 2>&1)
    local instance_status=$(echo "$instance_json" | jq -r ".[0].status")
    local public_ip=$(echo "$instance_json" | jq -r ".[0].networkInterfaces[0].accessConfigs[0].natIP")
    
    if [[ "$instance_status" != "RUNNING" ]]; then
        print_error "Failed to create Google Cloud VPS. Status: ${instance_status}. Error: ${instance_json}"
        return 1
    fi
    
    print_success "Google Cloud VPS \"${vps_name}\" created successfully!"
    print_info "Public IP: ${public_ip}"
    
    # Add to servers.json (simplified, assuming root user for now)
    local server_entry="{\"name\":\"${vps_name}\",\"ip\":\"${public_ip}\",\"user\":\"$(whoami)\",\"port\":22,\"key\":\"${ssh_public_key_path}\"}"
    
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

# List GCP VPS instances
list_gcp_vps() {
    check_gcloud_cli || return 1
    print_info "Listing Google Cloud VPS instances..."
    gcloud compute instances list --format="json" | jq -r ".[] | {name: .name, status: .status, zone: .zone, externalIp: .networkInterfaces[0].accessConfigs[0].natIP}"
}

# Start GCP VPS instance
start_gcp_vps() {
    local vps_name="$1"
    local zone="$2"
    check_gcloud_cli || return 1
    print_info "Starting Google Cloud VPS instance: ${vps_name} in zone ${zone}"
    gcloud compute instances start "$vps_name" --zone="$zone" --format="json"
    print_success "Instance started: ${vps_name}"
}

# Stop GCP VPS instance
stop_gcp_vps() {
    local vps_name="$1"
    local zone="$2"
    check_gcloud_cli || return 1
    print_info "Stopping Google Cloud VPS instance: ${vps_name} in zone ${zone}"
    gcloud compute instances stop "$vps_name" --zone="$zone" --format="json"
    print_success "Instance stopped: ${vps_name}"
}

# Reboot GCP VPS instance
reboot_gcp_vps() {
    local vps_name="$1"
    local zone="$2"
    check_gcloud_cli || return 1
    print_info "Rebooting Google Cloud VPS instance: ${vps_name} in zone ${zone}"
    gcloud compute instances reset "$vps_name" --zone="$zone" --format="json"
    print_success "Instance rebooted: ${vps_name}"
}

# Delete GCP VPS instance
delete_gcp_vps() {
    local vps_name="$1"
    local zone="$2"
    check_gcloud_cli || return 1
    print_warning "This will permanently delete Google Cloud VPS instance: ${vps_name} in zone ${zone}"
    read -p "Are you sure? (y/n): " confirm
    if [[ "$confirm" == "y" ]]; then
        gcloud compute instances delete "$vps_name" --zone="$zone" --format="json" --quiet
        print_success "Instance deleted: ${vps_name}"
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
            create_gcp_vps "${2:-}" "${3:-}"
            ;;
        list)
            list_gcp_vps
            ;;
        start)
            start_gcp_vps "${2:-}" "${3:-}"
            ;;
        stop)
            stop_gcp_vps "${2:-}" "${3:-}"
            ;;
        reboot)
            reboot_gcp_vps "${2:-}" "${3:-}"
            ;;
        delete)
            delete_gcp_vps "${2:-}" "${3:-}"
            ;;
        *)
            echo "Google Cloud Platform Provider Module - VPS-Manager"
            echo ""
            echo "Usage: $0 <command> [options]"
            echo ""
            echo "Commands:"
            echo "  create [vps_name] [ssh_public_key_path]  Create new GCP VPS"
            echo "  list                                     List all GCP VPS instances"
            echo "  start [vps_name] [zone]                  Start GCP VPS instance"
            echo "  stop [vps_name] [zone]                   Stop GCP VPS instance"
            echo "  reboot [vps_name] [zone]                 Reboot GCP VPS instance"
            echo "  delete [vps_name] [zone]                 Delete GCP VPS instance"
            ;;
    esac
fi
