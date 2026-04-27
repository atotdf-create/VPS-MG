#!/bin/bash

################################################################################
# SSH Manager Module - VPS-Manager
# Handles SSH key generation, server profile management, and connections
################################################################################

set -euo pipefail

# Source configuration if available
CONFIG_DIR="${HOME}/.vps-manager"
SERVERS_DB="${CONFIG_DIR}/servers.json"
KEYS_DIR="${CONFIG_DIR}/keys"

# ============================================================================
# COLOR DEFINITIONS
# ============================================================================

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly RESET='\033[0m'
readonly BOLD='\033[1m'

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

# ============================================================================
# SSH KEY MANAGEMENT
# ============================================================================

# Generate a new SSH key pair
generate_ssh_keypair() {
    local key_name="${1:-id_rsa}"
    local key_type="${2:-rsa}"
    local key_bits="${3:-4096}"
    
    if [[ ! -d "${KEYS_DIR}" ]]; then
        mkdir -p "${KEYS_DIR}"
    fi
    
    local key_path="${KEYS_DIR}/${key_name}"
    
    if [[ -f "${key_path}" ]]; then
        print_warning "Key already exists at ${key_path}"
        return 1
    fi
    
    print_info "Generating ${key_type} SSH key pair (${key_bits} bits)..."
    
    if ssh-keygen -t "${key_type}" -b "${key_bits}" -f "${key_path}" -N "" -C "vps-manager-${key_name}" 2>/dev/null; then
        chmod 600 "${key_path}"
        chmod 644 "${key_path}.pub"
        print_success "SSH key pair generated successfully!"
        print_info "Private key: ${key_path}"
        print_info "Public key: ${key_path}.pub"
        return 0
    else
        print_error "Failed to generate SSH key."
        return 1
    fi
}

# List all available SSH keys
list_ssh_keys() {
    if [[ ! -d "${KEYS_DIR}" ]]; then
        print_warning "No SSH keys directory found."
        return 1
    fi
    
    echo -e "${BOLD}Available SSH Keys:${RESET}\n"
    
    if [[ -z "$(ls -A "${KEYS_DIR}" 2>/dev/null)" ]]; then
        print_warning "No SSH keys found."
        return 1
    fi
    
    local count=1
    while IFS= read -r key_file; do
        if [[ ! "$key_file" =~ \.pub$ ]]; then
            local key_name=$(basename "$key_file")
            local key_size=$(ssh-keygen -l -f "$key_file" 2>/dev/null | awk '{print $1}')
            local key_fingerprint=$(ssh-keygen -l -f "$key_file" 2>/dev/null | awk '{print $2}')
            
            echo -e "${GREEN}${count})${RESET} ${key_name}"
            echo "   Bits: ${key_size}, Fingerprint: ${key_fingerprint}"
            ((count++))
        fi
    done < <(find "${KEYS_DIR}" -type f ! -name "*.pub" 2>/dev/null)
    
    return 0
}

# Delete an SSH key
delete_ssh_key() {
    local key_name="$1"
    local key_path="${KEYS_DIR}/${key_name}"
    
    if [[ ! -f "${key_path}" ]]; then
        print_error "SSH key not found: ${key_name}"
        return 1
    fi
    
    print_warning "This will delete the SSH key: ${key_name}"
    read -p "Are you sure? (y/n): " confirm
    
    if [[ "$confirm" == "y" ]]; then
        rm -f "${key_path}" "${key_path}.pub"
        print_success "SSH key deleted: ${key_name}"
        return 0
    else
        print_info "Deletion cancelled."
        return 1
    fi
}

# ============================================================================
# SERVER PROFILE MANAGEMENT
# ============================================================================

# Initialize servers database if it doesn't exist
init_servers_db() {
    if [[ ! -d "${CONFIG_DIR}" ]]; then
        mkdir -p "${CONFIG_DIR}"
    fi
    
    if [[ ! -f "${SERVERS_DB}" ]]; then
        echo "[]" > "${SERVERS_DB}"
        print_info "Initialized servers database."
    fi
}

# Add a new server profile
add_server() {
    local server_name="$1"
    local server_ip="$2"
    local ssh_user="${3:-root}"
    local ssh_port="${4:-22}"
    local ssh_key="${5:-}"
    
    init_servers_db
    
    # Simple validation
    if [[ -z "$server_name" ]] || [[ -z "$server_ip" ]]; then
        print_error "Server name and IP are required."
        return 1
    fi
    
    # Check if server already exists
    if grep -q "\"name\":\"${server_name}\"" "${SERVERS_DB}"; then
        print_warning "Server already exists: ${server_name}"
        return 1
    fi
    
    # Create server entry (simplified JSON format)
    local server_entry="{\"name\":\"${server_name}\",\"ip\":\"${server_ip}\",\"user\":\"${ssh_user}\",\"port\":${ssh_port},\"key\":\"${ssh_key}\"}"
    
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
    
    print_success "Server profile added: ${server_name}"
    return 0
}

# List all server profiles
list_servers() {
    init_servers_db
    
    if [[ ! -s "${SERVERS_DB}" ]] || [[ "$(cat "${SERVERS_DB}")" == "[]" ]]; then
        print_warning "No server profiles found."
        return 1
    fi
    
    echo -e "${BOLD}Saved Server Profiles:${RESET}\n"
    
    # Display servers (simple parsing)
    local count=1
    while IFS= read -r line; do
        if [[ "$line" =~ \"name\":\"([^\"]+)\" ]]; then
            local name="${BASH_REMATCH[1]}"
            
            if [[ "$line" =~ \"ip\":\"([^\"]+)\" ]]; then
                local ip="${BASH_REMATCH[1]}"
            fi
            
            if [[ "$line" =~ \"user\":\"([^\"]+)\" ]]; then
                local user="${BASH_REMATCH[1]}"
            fi
            
            if [[ "$line" =~ \"port\":([0-9]+) ]]; then
                local port="${BASH_REMATCH[1]}"
            fi
            
            echo -e "${GREEN}${count})${RESET} ${name}"
            echo "   IP: ${ip}, User: ${user}, Port: ${port}"
            ((count++))
        fi
    done < <(grep -o '{[^}]*}' "${SERVERS_DB}")
    
    return 0
}

# Remove a server profile
remove_server() {
    local server_name="$1"
    
    init_servers_db
    
    if ! grep -q "\"name\":\"${server_name}\"" "${SERVERS_DB}"; then
        print_error "Server not found: ${server_name}"
        return 1
    fi
    
    print_warning "This will remove the server profile: ${server_name}"
    read -p "Are you sure? (y/n): " confirm
    
    if [[ "$confirm" == "y" ]]; then
        # Simple removal (remove the entry)
        local temp_file="${SERVERS_DB}.tmp"
        grep -v "\"name\":\"${server_name}\"" "${SERVERS_DB}" > "${temp_file}" || echo "[]" > "${temp_file}"
        mv "${temp_file}" "${SERVERS_DB}"
        print_success "Server profile removed: ${server_name}"
        return 0
    else
        print_info "Removal cancelled."
        return 1
    fi
}

# Get server details
get_server_details() {
    local server_name="$1"
    
    init_servers_db
    
    if ! grep -q "\"name\":\"${server_name}\"" "${SERVERS_DB}"; then
        print_error "Server not found: ${server_name}"
        return 1
    fi
    
    # Extract server details
    local server_line=$(grep "\"name\":\"${server_name}\"" "${SERVERS_DB}")
    
    if [[ "$server_line" =~ \"ip\":\"([^\"]+)\" ]]; then
        echo "${BASH_REMATCH[1]}"
    fi
}

# ============================================================================
# SSH CONNECTION
# ============================================================================

# Connect to a server via SSH
ssh_connect() {
    local server_name="$1"
    
    init_servers_db
    
    if ! grep -q "\"name\":\"${server_name}\"" "${SERVERS_DB}"; then
        print_error "Server not found: ${server_name}"
        return 1
    fi
    
    # Extract connection details
    local server_line=$(grep "\"name\":\"${server_name}\"" "${SERVERS_DB}")
    
    local ip="" user="root" port="22" key=""
    
    if [[ "$server_line" =~ \"ip\":\"([^\"]+)\" ]]; then
        ip="${BASH_REMATCH[1]}"
    fi
    
    if [[ "$server_line" =~ \"user\":\"([^\"]+)\" ]]; then
        user="${BASH_REMATCH[1]}"
    fi
    
    if [[ "$server_line" =~ \"port\":([0-9]+) ]]; then
        port="${BASH_REMATCH[1]}"
    fi
    
    if [[ "$server_line" =~ \"key\":\"([^\"]+)\" ]] && [[ "${BASH_REMATCH[1]}" != "" ]]; then
        key="${BASH_REMATCH[1]}"
    fi
    
    if [[ -z "$ip" ]]; then
        print_error "Could not extract server IP."
        return 1
    fi
    
    print_info "Connecting to ${server_name} (${ip})..."
    
    if [[ -n "$key" ]] && [[ -f "$key" ]]; then
        ssh -i "$key" -p "$port" "${user}@${ip}"
    else
        ssh -p "$port" "${user}@${ip}"
    fi
}

# Execute a command on a remote server
ssh_execute() {
    local server_name="$1"
    local command="$2"
    
    init_servers_db
    
    if ! grep -q "\"name\":\"${server_name}\"" "${SERVERS_DB}"; then
        print_error "Server not found: ${server_name}"
        return 1
    fi
    
    # Extract connection details
    local server_line=$(grep "\"name\":\"${server_name}\"" "${SERVERS_DB}")
    
    local ip="" user="root" port="22" key=""
    
    if [[ "$server_line" =~ \"ip\":\"([^\"]+)\" ]]; then
        ip="${BASH_REMATCH[1]}"
    fi
    
    if [[ "$server_line" =~ \"user\":\"([^\"]+)\" ]]; then
        user="${BASH_REMATCH[1]}"
    fi
    
    if [[ "$server_line" =~ \"port\":([0-9]+) ]]; then
        port="${BASH_REMATCH[1]}"
    fi
    
    if [[ "$server_line" =~ \"key\":\"([^\"]+)\" ]] && [[ "${BASH_REMATCH[1]}" != "" ]]; then
        key="${BASH_REMATCH[1]}"
    fi
    
    if [[ -z "$ip" ]]; then
        print_error "Could not extract server IP."
        return 1
    fi
    
    print_info "Executing command on ${server_name}..."
    
    if [[ -n "$key" ]] && [[ -f "$key" ]]; then
        ssh -i "$key" -p "$port" "${user}@${ip}" "$command"
    else
        ssh -p "$port" "${user}@${ip}" "$command"
    fi
}

# Copy file to remote server
ssh_copy_to() {
    local server_name="$1"
    local local_file="$2"
    local remote_path="$3"
    
    init_servers_db
    
    if ! grep -q "\"name\":\"${server_name}\"" "${SERVERS_DB}"; then
        print_error "Server not found: ${server_name}"
        return 1
    fi
    
    if [[ ! -f "$local_file" ]]; then
        print_error "Local file not found: ${local_file}"
        return 1
    fi
    
    # Extract connection details
    local server_line=$(grep "\"name\":\"${server_name}\"" "${SERVERS_DB}")
    
    local ip="" user="root" port="22" key=""
    
    if [[ "$server_line" =~ \"ip\":\"([^\"]+)\" ]]; then
        ip="${BASH_REMATCH[1]}"
    fi
    
    if [[ "$server_line" =~ \"user\":\"([^\"]+)\" ]]; then
        user="${BASH_REMATCH[1]}"
    fi
    
    if [[ "$server_line" =~ \"port\":([0-9]+) ]]; then
        port="${BASH_REMATCH[1]}"
    fi
    
    if [[ "$server_line" =~ \"key\":\"([^\"]+)\" ]] && [[ "${BASH_REMATCH[1]}" != "" ]]; then
        key="${BASH_REMATCH[1]}"
    fi
    
    if [[ -z "$ip" ]]; then
        print_error "Could not extract server IP."
        return 1
    fi
    
    print_info "Copying file to ${server_name}..."
    
    if [[ -n "$key" ]] && [[ -f "$key" ]]; then
        scp -i "$key" -P "$port" "$local_file" "${user}@${ip}:${remote_path}"
    else
        scp -P "$port" "$local_file" "${user}@${ip}:${remote_path}"
    fi
    
    print_success "File copied successfully."
}

# Copy file from remote server
ssh_copy_from() {
    local server_name="$1"
    local remote_file="$2"
    local local_path="$3"
    
    init_servers_db
    
    if ! grep -q "\"name\":\"${server_name}\"" "${SERVERS_DB}"; then
        print_error "Server not found: ${server_name}"
        return 1
    fi
    
    # Extract connection details
    local server_line=$(grep "\"name\":\"${server_name}\"" "${SERVERS_DB}")
    
    local ip="" user="root" port="22" key=""
    
    if [[ "$server_line" =~ \"ip\":\"([^\"]+)\" ]]; then
        ip="${BASH_REMATCH[1]}"
    fi
    
    if [[ "$server_line" =~ \"user\":\"([^\"]+)\" ]]; then
        user="${BASH_REMATCH[1]}"
    fi
    
    if [[ "$server_line" =~ \"port\":([0-9]+) ]]; then
        port="${BASH_REMATCH[1]}"
    fi
    
    if [[ "$server_line" =~ \"key\":\"([^\"]+)\" ]] && [[ "${BASH_REMATCH[1]}" != "" ]]; then
        key="${BASH_REMATCH[1]}"
    fi
    
    if [[ -z "$ip" ]]; then
        print_error "Could not extract server IP."
        return 1
    fi
    
    print_info "Copying file from ${server_name}..."
    
    if [[ -n "$key" ]] && [[ -f "$key" ]]; then
        scp -i "$key" -P "$port" "${user}@${ip}:${remote_file}" "$local_path"
    else
        scp -P "$port" "${user}@${ip}:${remote_file}" "$local_path"
    fi
    
    print_success "File copied successfully."
}

# ============================================================================
# MAIN EXECUTION (if script is called directly)
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script was called directly
    case "${1:-help}" in
        generate)
            generate_ssh_keypair "${2:-id_rsa}" "${3:-rsa}" "${4:-4096}"
            ;;
        list-keys)
            list_ssh_keys
            ;;
        delete-key)
            delete_ssh_key "${2:-}"
            ;;
        add-server)
            add_server "${2:-}" "${3:-}" "${4:-root}" "${5:-22}" "${6:-}"
            ;;
        list-servers)
            list_servers
            ;;
        remove-server)
            remove_server "${2:-}"
            ;;
        connect)
            ssh_connect "${2:-}"
            ;;
        execute)
            ssh_execute "${2:-}" "${3:-}"
            ;;
        copy-to)
            ssh_copy_to "${2:-}" "${3:-}" "${4:-}"
            ;;
        copy-from)
            ssh_copy_from "${2:-}" "${3:-}" "${4:-}"
            ;;
        *)
            echo "SSH Manager - VPS-Manager Module"
            echo ""
            echo "Usage: $0 <command> [options]"
            echo ""
            echo "Commands:"
            echo "  generate [name] [type] [bits]     Generate SSH key pair"
            echo "  list-keys                         List all SSH keys"
            echo "  delete-key [name]                 Delete SSH key"
            echo "  add-server [name] [ip] [user] [port] [key]  Add server profile"
            echo "  list-servers                      List all server profiles"
            echo "  remove-server [name]              Remove server profile"
            echo "  connect [name]                    Connect to server"
            echo "  execute [name] [command]          Execute command on server"
            echo "  copy-to [name] [local] [remote]   Copy file to server"
            echo "  copy-from [name] [remote] [local] Copy file from server"
            ;;
    esac
fi
