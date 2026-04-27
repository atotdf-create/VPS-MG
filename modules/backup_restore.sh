#!/bin/bash

################################################################################
# Backup & Restore Module - VPS-Manager
# Manages server configuration backups and restoration
################################################################################

set -euo pipefail

# Source configuration if available
CONFIG_DIR="${HOME}/.vps-manager"
SERVERS_DB="${CONFIG_DIR}/servers.json"
BACKUPS_DIR="${CONFIG_DIR}/backups"

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

# Initialize backups directory
init_backups_dir() {
    if [[ ! -d "${BACKUPS_DIR}" ]]; then
        mkdir -p "${BACKUPS_DIR}"
        print_info "Created backups directory: ${BACKUPS_DIR}"
    fi
}

# Get server connection details
get_server_connection() {
    local server_name="$1"
    
    if [[ ! -f "${SERVERS_DB}" ]]; then
        print_error "Servers database not found."
        return 1
    fi
    
    if ! grep -q "\"name\":\"${server_name}\"" "${SERVERS_DB}"; then
        print_error "Server not found: ${server_name}"
        return 1
    fi
    
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
    
    echo "${ip}|${user}|${port}|${key}"
}

# Execute SSH command
ssh_exec() {
    local server_name="$1"
    local command="$2"
    
    local connection=$(get_server_connection "$server_name") || return 1
    
    IFS='|' read -r ip user port key <<< "$connection"
    
    if [[ -n "$key" ]] && [[ -f "$key" ]]; then
        ssh -i "$key" -p "$port" -o ConnectTimeout=5 "${user}@${ip}" "$command"
    else
        ssh -p "$port" -o ConnectTimeout=5 "${user}@${ip}" "$command"
    fi
}

# ============================================================================
# BACKUP FUNCTIONS
# ============================================================================

# Create a backup of server configuration
backup_server_config() {
    local server_name="$1"
    
    init_backups_dir
    
    print_info "Creating backup for: ${server_name}"
    
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_name="${server_name}_backup_${timestamp}"
    local backup_dir="${BACKUPS_DIR}/${backup_name}"
    
    mkdir -p "${backup_dir}"
    
    print_info "Backing up system information..."
    
    # Backup system information
    ssh_exec "$server_name" "uname -a" > "${backup_dir}/system_info.txt" 2>/dev/null || true
    
    # Backup hostname
    ssh_exec "$server_name" "hostname" > "${backup_dir}/hostname.txt" 2>/dev/null || true
    
    # Backup network configuration
    ssh_exec "$server_name" "ip addr show" > "${backup_dir}/network_config.txt" 2>/dev/null || true
    
    # Backup installed packages
    ssh_exec "$server_name" "dpkg -l" > "${backup_dir}/installed_packages.txt" 2>/dev/null || true
    
    # Backup environment variables
    ssh_exec "$server_name" "env" > "${backup_dir}/environment.txt" 2>/dev/null || true
    
    # Backup SSH configuration
    ssh_exec "$server_name" "cat /etc/ssh/sshd_config" > "${backup_dir}/sshd_config.txt" 2>/dev/null || true
    
    # Backup firewall rules
    ssh_exec "$server_name" "ufw status numbered" > "${backup_dir}/firewall_rules.txt" 2>/dev/null || true
    
    # Backup cron jobs
    ssh_exec "$server_name" "crontab -l" > "${backup_dir}/crontab.txt" 2>/dev/null || true
    
    # Create tar archive
    print_info "Compressing backup..."
    tar -czf "${backup_dir}.tar.gz" -C "${BACKUPS_DIR}" "${backup_name}" 2>/dev/null || {
        print_error "Failed to compress backup."
        return 1
    }
    
    # Remove uncompressed directory
    rm -rf "${backup_dir}"
    
    print_success "Backup created successfully!"
    print_info "Backup location: ${backup_dir}.tar.gz"
    print_info "Backup size: $(du -h "${backup_dir}.tar.gz" | cut -f1)"
}

# ============================================================================
# RESTORE FUNCTIONS
# ============================================================================

# Restore server configuration from backup
restore_server_config() {
    local backup_file="$1"
    local server_name="$2"
    
    if [[ ! -f "${backup_file}" ]]; then
        print_error "Backup file not found: ${backup_file}"
        return 1
    fi
    
    print_warning "This will restore configuration to: ${server_name}"
    read -p "Are you sure? (y/n): " confirm
    
    if [[ "$confirm" != "y" ]]; then
        print_info "Restoration cancelled."
        return 1
    fi
    
    print_info "Extracting backup..."
    
    local temp_dir=$(mktemp -d)
    tar -xzf "${backup_file}" -C "${temp_dir}" || {
        print_error "Failed to extract backup."
        rm -rf "${temp_dir}"
        return 1
    }
    
    print_info "Restoring configuration to server..."
    
    # Extract backup directory name
    local backup_dir=$(ls "${temp_dir}" | head -n1)
    local backup_path="${temp_dir}/${backup_dir}"
    
    # Restore SSH configuration
    if [[ -f "${backup_path}/sshd_config.txt" ]]; then
        print_info "Restoring SSH configuration..."
        scp -P "$(get_server_connection "$server_name" | cut -d'|' -f3)" \
            "${backup_path}/sshd_config.txt" \
            "$(get_server_connection "$server_name" | cut -d'|' -f2)@$(get_server_connection "$server_name" | cut -d'|' -f1):/etc/ssh/sshd_config.backup" 2>/dev/null || true
    fi
    
    # Display restored information
    echo ""
    echo -e "${BOLD}Restored Configuration:${RESET}"
    echo ""
    
    if [[ -f "${backup_path}/system_info.txt" ]]; then
        echo -e "${BOLD}System Info:${RESET}"
        cat "${backup_path}/system_info.txt"
        echo ""
    fi
    
    if [[ -f "${backup_path}/network_config.txt" ]]; then
        echo -e "${BOLD}Network Configuration:${RESET}"
        cat "${backup_path}/network_config.txt"
        echo ""
    fi
    
    # Cleanup
    rm -rf "${temp_dir}"
    
    print_success "Restoration completed!"
    print_warning "Please verify the restored configuration on the server."
}

# ============================================================================
# BACKUP MANAGEMENT
# ============================================================================

# List all backups
list_backups() {
    init_backups_dir
    
    if [[ -z "$(ls -A "${BACKUPS_DIR}" 2>/dev/null)" ]]; then
        print_warning "No backups found."
        return 1
    fi
    
    echo -e "${BOLD}Available Backups:${RESET}\n"
    
    local count=1
    while IFS= read -r backup_file; do
        local backup_name=$(basename "$backup_file")
        local backup_size=$(du -h "$backup_file" | cut -f1)
        local backup_date=$(stat -c %y "$backup_file" 2>/dev/null | cut -d' ' -f1-2 || stat -f "%Sm" "$backup_file" 2>/dev/null || echo "Unknown")
        
        echo -e "${GREEN}${count})${RESET} ${backup_name}"
        echo "   Size: ${backup_size}, Date: ${backup_date}"
        ((count++))
    done < <(find "${BACKUPS_DIR}" -maxdepth 1 -name "*.tar.gz" -type f 2>/dev/null | sort -r)
    
    return 0
}

# Delete a backup
delete_backup() {
    local backup_name="$1"
    
    init_backups_dir
    
    local backup_file="${BACKUPS_DIR}/${backup_name}"
    
    if [[ ! -f "${backup_file}" ]]; then
        # Try with .tar.gz extension
        backup_file="${BACKUPS_DIR}/${backup_name}.tar.gz"
        
        if [[ ! -f "${backup_file}" ]]; then
            print_error "Backup not found: ${backup_name}"
            return 1
        fi
    fi
    
    print_warning "This will delete the backup: $(basename "$backup_file")"
    read -p "Are you sure? (y/n): " confirm
    
    if [[ "$confirm" == "y" ]]; then
        rm -f "${backup_file}"
        print_success "Backup deleted successfully!"
        return 0
    else
        print_info "Deletion cancelled."
        return 1
    fi
}

# Get backup info
backup_info() {
    local backup_name="$1"
    
    local backup_file="${BACKUPS_DIR}/${backup_name}"
    
    if [[ ! -f "${backup_file}" ]]; then
        # Try with .tar.gz extension
        backup_file="${BACKUPS_DIR}/${backup_name}.tar.gz"
        
        if [[ ! -f "${backup_file}" ]]; then
            print_error "Backup not found: ${backup_name}"
            return 1
        fi
    fi
    
    echo -e "${BOLD}Backup Information:${RESET}\n"
    echo "Name: $(basename "$backup_file")"
    echo "Path: ${backup_file}"
    echo "Size: $(du -h "$backup_file" | cut -f1)"
    echo "Date: $(stat -c %y "$backup_file" 2>/dev/null | cut -d' ' -f1-2 || stat -f "%Sm" "$backup_file" 2>/dev/null || echo "Unknown")"
    echo ""
    
    # List contents
    echo -e "${BOLD}Contents:${RESET}\n"
    tar -tzf "${backup_file}" | head -20
    
    if [[ $(tar -tzf "${backup_file}" | wc -l) -gt 20 ]]; then
        echo "... and more files"
    fi
}

# ============================================================================
# SCHEDULED BACKUPS
# ============================================================================

# Schedule automatic backups
schedule_backup() {
    local server_name="$1"
    local frequency="${2:-daily}"
    
    print_info "Scheduling ${frequency} backup for: ${server_name}"
    
    local cron_job=""
    
    case "$frequency" in
        daily)
            cron_job="0 2 * * * ${SCRIPT_DIR}/modules/backup_restore.sh backup ${server_name} >> ${BACKUPS_DIR}/backup.log 2>&1"
            ;;
        weekly)
            cron_job="0 2 * * 0 ${SCRIPT_DIR}/modules/backup_restore.sh backup ${server_name} >> ${BACKUPS_DIR}/backup.log 2>&1"
            ;;
        monthly)
            cron_job="0 2 1 * * ${SCRIPT_DIR}/modules/backup_restore.sh backup ${server_name} >> ${BACKUPS_DIR}/backup.log 2>&1"
            ;;
        *)
            print_error "Invalid frequency: ${frequency}"
            return 1
            ;;
    esac
    
    # Add to crontab
    (crontab -l 2>/dev/null | grep -v "backup_restore.sh backup ${server_name}" || true; echo "$cron_job") | crontab -
    
    print_success "Backup scheduled successfully!"
    print_info "Frequency: ${frequency}"
}

# ============================================================================
# MAIN EXECUTION (if script is called directly)
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script was called directly
    case "${1:-help}" in
        backup)
            backup_server_config "${2:-}"
            ;;
        restore)
            restore_server_config "${2:-}" "${3:-}"
            ;;
        list)
            list_backups
            ;;
        delete)
            delete_backup "${2:-}"
            ;;
        info)
            backup_info "${2:-}"
            ;;
        schedule)
            schedule_backup "${2:-}" "${3:-daily}"
            ;;
        *)
            echo "Backup & Restore Module - VPS-Manager"
            echo ""
            echo "Usage: $0 <command> [options]"
            echo ""
            echo "Commands:"
            echo "  backup [server]           Create backup of server configuration"
            echo "  restore [backup] [server] Restore configuration from backup"
            echo "  list                      List all available backups"
            echo "  delete [backup]           Delete a backup"
            echo "  info [backup]             Show backup information"
            echo "  schedule [server] [freq]  Schedule automatic backups (daily/weekly/monthly)"
            ;;
    esac
fi
