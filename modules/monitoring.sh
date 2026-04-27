#!/bin/bash

################################################################################
# Server Monitoring Module - VPS-Manager
# Monitors VPS instances for CPU, RAM, disk usage, and other metrics
################################################################################

set -euo pipefail

# Source configuration if available
CONFIG_DIR="${HOME}/.vps-manager"
SERVERS_DB="${CONFIG_DIR}/servers.json"

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
    
    # Output connection details
    echo "${ip}|${user}|${port}|${key}"
}

# Execute SSH command with proper error handling
ssh_exec() {
    local server_name="$1"
    local command="$2"
    
    local connection=$(get_server_connection "$server_name") || return 1
    
    IFS='|' read -r ip user port key <<< "$connection"
    
    if [[ -n "$key" ]] && [[ -f "$key" ]]; then
        ssh -i "$key" -p "$port" -o ConnectTimeout=5 -o StrictHostKeyChecking=no "${user}@${ip}" "$command" 2>/dev/null
    else
        ssh -p "$port" -o ConnectTimeout=5 -o StrictHostKeyChecking=no "${user}@${ip}" "$command" 2>/dev/null
    fi
}

# ============================================================================
# MONITORING FUNCTIONS
# ============================================================================

# Check if server is online
check_server_status() {
    local server_name="$1"
    
    print_info "Checking server status: ${server_name}"
    
    local connection=$(get_server_connection "$server_name") || return 1
    
    IFS='|' read -r ip user port key <<< "$connection"
    
    if timeout 5 bash -c "echo > /dev/tcp/${ip}/${port}" 2>/dev/null; then
        print_success "Server is ONLINE"
        return 0
    else
        print_error "Server is OFFLINE"
        return 1
    fi
}

# Get CPU usage
get_cpu_usage() {
    local server_name="$1"
    
    print_info "Fetching CPU usage for: ${server_name}"
    
    local cpu_info=$(ssh_exec "$server_name" "top -bn1 | grep 'Cpu(s)' | sed 's/.*, *\([0-9.]*\)%* id.*/\1/' | awk '{print 100 - \$1}'" 2>/dev/null) || {
        print_error "Failed to retrieve CPU usage."
        return 1
    }
    
    echo ""
    echo -e "${BOLD}CPU Usage:${RESET}"
    echo -e "  Current: ${CYAN}${cpu_info}%${RESET}"
    
    # Color-code the usage
    if (( $(echo "$cpu_info > 80" | bc -l) )); then
        print_warning "CPU usage is high!"
    elif (( $(echo "$cpu_info > 50" | bc -l) )); then
        print_info "CPU usage is moderate."
    else
        print_success "CPU usage is normal."
    fi
}

# Get memory usage
get_memory_usage() {
    local server_name="$1"
    
    print_info "Fetching memory usage for: ${server_name}"
    
    local mem_info=$(ssh_exec "$server_name" "free -h | grep Mem | awk '{print \$3, \$2}'" 2>/dev/null) || {
        print_error "Failed to retrieve memory usage."
        return 1
    }
    
    echo ""
    echo -e "${BOLD}Memory Usage:${RESET}"
    echo -e "  Used: ${CYAN}$(echo $mem_info | awk '{print $1}')${RESET}"
    echo -e "  Total: ${CYAN}$(echo $mem_info | awk '{print $2}')${RESET}"
    
    # Calculate percentage
    local used=$(echo $mem_info | awk '{print $1}' | sed 's/G//' | sed 's/M//')
    local total=$(echo $mem_info | awk '{print $2}' | sed 's/G//' | sed 's/M//')
    
    if [[ ! -z "$used" ]] && [[ ! -z "$total" ]]; then
        local percent=$(echo "scale=2; ($used / $total) * 100" | bc -l 2>/dev/null || echo "0")
        echo -e "  Usage: ${CYAN}${percent}%${RESET}"
        
        if (( $(echo "$percent > 80" | bc -l) )); then
            print_warning "Memory usage is high!"
        fi
    fi
}

# Get disk usage
get_disk_usage() {
    local server_name="$1"
    
    print_info "Fetching disk usage for: ${server_name}"
    
    echo ""
    echo -e "${BOLD}Disk Usage:${RESET}\n"
    
    ssh_exec "$server_name" "df -h | tail -n +2 | awk '{printf \"  %-20s %10s %10s %10s %6s\n\", \$1, \$2, \$3, \$4, \$5}'" 2>/dev/null || {
        print_error "Failed to retrieve disk usage."
        return 1
    }
}

# Get network information
get_network_info() {
    local server_name="$1"
    
    print_info "Fetching network information for: ${server_name}"
    
    echo ""
    echo -e "${BOLD}Network Interfaces:${RESET}\n"
    
    ssh_exec "$server_name" "ip addr show | grep -E 'inet |inet6 ' | awk '{print \$2}' | sed 's/\\/[0-9]*//'" 2>/dev/null || {
        print_error "Failed to retrieve network information."
        return 1
    }
}

# Get system uptime
get_uptime() {
    local server_name="$1"
    
    print_info "Fetching uptime for: ${server_name}"
    
    local uptime=$(ssh_exec "$server_name" "uptime -p" 2>/dev/null) || {
        print_error "Failed to retrieve uptime."
        return 1
    }
    
    echo ""
    echo -e "${BOLD}System Uptime:${RESET}"
    echo -e "  ${CYAN}${uptime}${RESET}"
}

# Get load average
get_load_average() {
    local server_name="$1"
    
    print_info "Fetching load average for: ${server_name}"
    
    local load=$(ssh_exec "$server_name" "cat /proc/loadavg | awk '{print \$1, \$2, \$3}'" 2>/dev/null) || {
        print_error "Failed to retrieve load average."
        return 1
    }
    
    echo ""
    echo -e "${BOLD}Load Average (1m, 5m, 15m):${RESET}"
    echo -e "  ${CYAN}${load}${RESET}"
}

# Get process information
get_top_processes() {
    local server_name="$1"
    
    print_info "Fetching top processes for: ${server_name}"
    
    echo ""
    echo -e "${BOLD}Top 5 Processes by Memory:${RESET}\n"
    
    ssh_exec "$server_name" "ps aux --sort=-%mem | head -n 6 | awk '{printf \"  %-10s %8s %8s %s\n\", \$1, \$3, \$4, \$11}'" 2>/dev/null || {
        print_error "Failed to retrieve process information."
        return 1
    }
}

# Get all system metrics
get_all_metrics() {
    local server_name="$1"
    
    print_info "Fetching all metrics for: ${server_name}"
    echo ""
    
    # Check status
    if check_server_status "$server_name"; then
        echo ""
        
        # Get all metrics
        get_uptime "$server_name" || true
        echo ""
        
        get_load_average "$server_name" || true
        echo ""
        
        get_cpu_usage "$server_name" || true
        echo ""
        
        get_memory_usage "$server_name" || true
        echo ""
        
        get_disk_usage "$server_name" || true
        echo ""
        
        get_network_info "$server_name" || true
        echo ""
        
        get_top_processes "$server_name" || true
    fi
}

# Real-time monitoring (continuous)
realtime_monitoring() {
    local server_name="$1"
    local interval="${2:-5}"
    
    print_info "Starting real-time monitoring for: ${server_name}"
    print_info "Refresh interval: ${interval} seconds"
    print_info "Press Ctrl+C to stop"
    echo ""
    
    while true; do
        clear
        echo -e "${BOLD}${CYAN}Real-Time Monitoring - ${server_name}${RESET}"
        echo -e "${BOLD}$(date)${RESET}\n"
        
        if check_server_status "$server_name" 2>/dev/null; then
            get_uptime "$server_name" 2>/dev/null || true
            echo ""
            
            get_load_average "$server_name" 2>/dev/null || true
            echo ""
            
            get_cpu_usage "$server_name" 2>/dev/null || true
            echo ""
            
            get_memory_usage "$server_name" 2>/dev/null || true
            echo ""
            
            get_disk_usage "$server_name" 2>/dev/null || true
        else
            print_error "Server is offline"
        fi
        
        echo ""
        echo -e "${GRAY}Refreshing in ${interval} seconds... (Press Ctrl+C to stop)${RESET}"
        sleep "$interval"
    done
}

# List all servers
list_servers() {
    if [[ ! -f "${SERVERS_DB}" ]] || [[ ! -s "${SERVERS_DB}" ]] || [[ "$(cat "${SERVERS_DB}")" == "[]" ]]; then
        print_warning "No server profiles found."
        return 1
    fi
    
    echo -e "${BOLD}Available Servers:${RESET}\n"
    
    local count=1
    while IFS= read -r line; do
        if [[ "$line" =~ \"name\":\"([^\"]+)\" ]]; then
            local name="${BASH_REMATCH[1]}"
            echo -e "${GREEN}${count})${RESET} ${name}"
            ((count++))
        fi
    done < <(grep -o '{[^}]*}' "${SERVERS_DB}")
    
    return 0
}

# ============================================================================
# MAIN EXECUTION (if script is called directly)
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script was called directly
    case "${1:-help}" in
        status)
            check_server_status "${2:-}"
            ;;
        cpu)
            get_cpu_usage "${2:-}"
            ;;
        memory)
            get_memory_usage "${2:-}"
            ;;
        disk)
            get_disk_usage "${2:-}"
            ;;
        network)
            get_network_info "${2:-}"
            ;;
        uptime)
            get_uptime "${2:-}"
            ;;
        load)
            get_load_average "${2:-}"
            ;;
        processes)
            get_top_processes "${2:-}"
            ;;
        all)
            get_all_metrics "${2:-}"
            ;;
        realtime)
            realtime_monitoring "${2:-}" "${3:-5}"
            ;;
        list)
            list_servers
            ;;
        *)
            echo "Server Monitoring Module - VPS-Manager"
            echo ""
            echo "Usage: $0 <command> [server_name] [options]"
            echo ""
            echo "Commands:"
            echo "  status [server]       Check if server is online"
            echo "  cpu [server]          Get CPU usage"
            echo "  memory [server]       Get memory usage"
            echo "  disk [server]         Get disk usage"
            echo "  network [server]      Get network information"
            echo "  uptime [server]       Get system uptime"
            echo "  load [server]         Get load average"
            echo "  processes [server]    Get top processes"
            echo "  all [server]          Get all metrics"
            echo "  realtime [server] [interval]  Real-time monitoring"
            echo "  list                  List all servers"
            ;;
    esac
fi
