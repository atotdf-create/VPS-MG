#!/bin/bash

################################################################################
# VPS-Manager Installation Script for Termux
# Installs and configures VPS-Manager tool
################################################################################

set -euo pipefail

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

print_banner() {
    clear
    echo -e "${BOLD}${MAGENTA}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════════════════╗
║                                                                           ║
║                    VPS-Manager Installation Script                       ║
║                                                                           ║
║              Professional Free-Tier VPS Management Tool                  ║
║                                                                           ║
╚═══════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${RESET}"
}

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

print_step() {
    echo ""
    echo -e "${BOLD}${BLUE}▶ $1${RESET}"
    echo -e "${BLUE}$(printf '─%.0s' {1..80})${RESET}"
}

# ============================================================================
# ENVIRONMENT DETECTION
# ============================================================================

detect_environment() {
    if [[ -n "${TERMUX_VERSION:-}" ]]; then
        print_success "Detected Termux environment"
        return 0
    elif [[ -f "/system/build.prop" ]]; then
        print_success "Detected Android environment"
        return 0
    else
        print_warning "Not running in Termux/Android environment"
        print_info "This tool is optimized for Termux but can run on Linux"
        return 1
    fi
}

# ============================================================================
# DEPENDENCY CHECKING
# ============================================================================

check_command() {
    local cmd="$1"
    if command -v "$cmd" &> /dev/null; then
        print_success "Found: $cmd"
        return 0
    else
        print_error "Missing: $cmd"
        return 1
    fi
}

check_dependencies() {
    print_step "Checking Dependencies"
    
    local missing_deps=()
    
    # Check required commands
    local required_cmds=("bash" "ssh" "ssh-keygen" "scp" "curl" "wget")
    
    for cmd in "${required_cmds[@]}"; do
        if ! check_command "$cmd"; then
            missing_deps+=("$cmd")
        fi
    done
    
    # Check optional commands
    print_info "Checking optional dependencies..."
    local optional_cmds=("jq" "docker" "git")
    
    for cmd in "${optional_cmds[@]}"; do
        if check_command "$cmd"; then
            :
        else
            print_warning "Optional: $cmd (not required)"
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        return 1
    fi
    
    print_success "All required dependencies found"
    return 0
}

# ============================================================================
# PACKAGE INSTALLATION
# ============================================================================

install_dependencies() {
    print_step "Installing Dependencies"
    
    # Detect package manager
    if command -v apt-get &> /dev/null; then
        print_info "Using apt package manager"
        
        print_info "Updating package lists..."
        apt-get update -qq || {
            print_warning "Failed to update package lists"
        }
        
        print_info "Installing required packages..."
        apt-get install -y \
            openssh-client \
            openssh-server \
            curl \
            wget \
            git \
            jq \
            nano \
            vim \
            tmux \
            screen \
            net-tools \
            dnsutils \
            traceroute \
            zip \
            unzip \
            tar \
            gzip || {
            print_warning "Some packages failed to install"
        }
        
        print_success "Dependencies installed"
        
    elif command -v pkg &> /dev/null; then
        print_info "Using Termux pkg package manager"
        
        print_info "Updating package lists..."
        pkg update -y || {
            print_warning "Failed to update package lists"
        }
        
        print_info "Installing required packages..."
        pkg install -y \
            openssh \
            curl \
            wget \
            git \
            jq \
            nano \
            vim \
            tmux \
            screen \
            net-tools \
            dnsutils \
            traceroute \
            zip \
            unzip \
            tar \
            gzip || {
            print_warning "Some packages failed to install"
        }
        
        print_success "Dependencies installed"
        
    else
        print_warning "No supported package manager found"
        print_info "Please install dependencies manually:"
        echo "  - openssh (ssh, ssh-keygen, scp)"
        echo "  - curl"
        echo "  - wget"
        echo "  - git"
        echo "  - jq (optional)"
    fi
}

# ============================================================================
# INSTALLATION
# ============================================================================

create_installation_directory() {
    print_step "Creating Installation Directory"
    
    local install_dir="${HOME}/.local/bin"
    
    if [[ ! -d "${install_dir}" ]]; then
        mkdir -p "${install_dir}"
        print_success "Created directory: ${install_dir}"
    else
        print_info "Directory already exists: ${install_dir}"
    fi
    
    echo "${install_dir}"
}

install_vps_manager() {
    print_step "Installing VPS-Manager"
    
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local install_dir=$(create_installation_directory)
    
    # Copy main script
    if [[ -f "${script_dir}/vps-manager.sh" ]]; then
        cp "${script_dir}/vps-manager.sh" "${install_dir}/vps-manager"
        chmod +x "${install_dir}/vps-manager"
        print_success "Installed: vps-manager"
    else
        print_error "Main script not found: ${script_dir}/vps-manager.sh"
        return 1
    fi
    
    # Copy modules
    if [[ -d "${script_dir}/modules" ]]; then
        mkdir -p "${install_dir}/vps-manager-modules"
        cp -r "${script_dir}/modules"/* "${install_dir}/vps-manager-modules/"
        chmod +x "${install_dir}/vps-manager-modules"/*.sh
        print_success "Installed modules"
    else
        print_warning "Modules directory not found"
    fi
    
    # Create configuration directory
    local config_dir="${HOME}/.vps-manager"
    if [[ ! -d "${config_dir}" ]]; then
        mkdir -p "${config_dir}"
        print_success "Created config directory: ${config_dir}"
    fi
    
    # Initialize servers database
    if [[ ! -f "${config_dir}/servers.json" ]]; then
        echo "[]" > "${config_dir}/servers.json"
        print_success "Initialized servers database"
    fi
    
    # Initialize settings
    if [[ ! -f "${config_dir}/settings.conf" ]]; then
        cat > "${config_dir}/settings.conf" << 'SETTINGS'
# VPS-Manager Configuration File
# Default SSH user for connections
DEFAULT_SSH_USER="root"

# Default SSH port
DEFAULT_SSH_PORT="22"

# Preferred cloud provider (oracle, gcp, aws, azure)
PREFERRED_PROVIDER="oracle"

# Enable debug mode (0 or 1)
DEBUG="0"
SETTINGS
        print_success "Initialized settings file"
    fi
    
    echo "${install_dir}"
}

# ============================================================================
# PATH CONFIGURATION
# ============================================================================

configure_path() {
    print_step "Configuring PATH"
    
    local install_dir="$1"
    local shell_profile=""
    
    # Detect shell
    if [[ -n "${BASH_VERSION:-}" ]]; then
        if [[ -f "${HOME}/.bashrc" ]]; then
            shell_profile="${HOME}/.bashrc"
        elif [[ -f "${HOME}/.bash_profile" ]]; then
            shell_profile="${HOME}/.bash_profile"
        fi
    elif [[ -n "${ZSH_VERSION:-}" ]]; then
        shell_profile="${HOME}/.zshrc"
    fi
    
    if [[ -z "${shell_profile}" ]]; then
        print_warning "Could not determine shell profile"
        return 1
    fi
    
    # Check if PATH is already configured
    if grep -q "vps-manager" "${shell_profile}" 2>/dev/null; then
        print_info "PATH already configured"
        return 0
    fi
    
    # Add to PATH
    cat >> "${shell_profile}" << EOF

# VPS-Manager PATH Configuration
export PATH="\${PATH}:${install_dir}"
EOF
    
    print_success "PATH configured in: ${shell_profile}"
    print_info "Run: source ${shell_profile}"
    print_info "Or restart your terminal"
}

# ============================================================================
# POST-INSTALLATION
# ============================================================================

create_symlink() {
    print_step "Symlink Creation (Skipped for Termux)"
    print_warning "Symlink creation to /usr/local/bin is skipped for Termux compatibility."
    print_info "Please ensure the installation directory is in your PATH. The script will be installed to ${HOME}/.local/bin."
}

setup_ssh_keys() {
    print_step "Setting Up SSH Keys"
    
    local keys_dir="${HOME}/.vps-manager/keys"
    
    if [[ ! -d "${keys_dir}" ]]; then
        mkdir -p "${keys_dir}"
        print_success "Created SSH keys directory: ${keys_dir}"
    fi
    
    if [[ ! -f "${keys_dir}/id_rsa" ]]; then
        print_info "Generating default SSH key pair..."
        ssh-keygen -t rsa -b 4096 -f "${keys_dir}/id_rsa" -N "" -C "vps-manager-default" 2>/dev/null || {
            print_warning "Failed to generate SSH key"
            return 1
        }
        chmod 600 "${keys_dir}/id_rsa"
        chmod 644 "${keys_dir}/id_rsa.pub"
        print_success "SSH key pair generated"
    else
        print_info "SSH key pair already exists"
    fi
}

# ============================================================================
# VERIFICATION
# ============================================================================

verify_installation() {
    print_step "Verifying Installation"
    
    local install_dir="$1"
    
    if [[ -f "${install_dir}/vps-manager" ]] && [[ -x "${install_dir}/vps-manager" ]]; then
        print_success "VPS-Manager executable found and is executable"
    else
        print_error "VPS-Manager executable not found or not executable"
        return 1
    fi
    
    if [[ -d "${HOME}/.vps-manager" ]]; then
        print_success "Configuration directory exists"
    else
        print_error "Configuration directory not found"
        return 1
    fi
    
    if [[ -f "${HOME}/.vps-manager/servers.json" ]]; then
        print_success "Servers database initialized"
    else
        print_error "Servers database not found"
        return 1
    fi
    
    if [[ -f "${HOME}/.vps-manager/settings.conf" ]]; then
        print_success "Settings file initialized"
    else
        print_error "Settings file not found"
        return 1
    fi
    
    print_success "Installation verified successfully!"
}

# ============================================================================
# MAIN INSTALLATION FLOW
# ============================================================================

main() {
    print_banner
    
    # Check environment
    detect_environment || {
        print_warning "Running outside Termux - some features may not work"
    }
    
    # Check dependencies
    if ! check_dependencies; then
        print_step "Installing Missing Dependencies"
        install_dependencies
    fi
    
    # Install VPS-Manager
    local install_dir
    install_dir=$(install_vps_manager) || {
        print_error "Installation failed"
        exit 1
    }
    
    # Configure PATH
    configure_path "${install_dir}"
    
    # Create symlink
    create_symlink "${install_dir}"
    
    # Setup SSH keys
    setup_ssh_keys
    
    # Verify installation
    verify_installation "${install_dir}"
    
    # Final instructions
    print_step "Installation Complete!"
    echo ""
    echo -e "${BOLD}Next Steps:${RESET}"
    echo ""
    echo "1. Reload your shell configuration:"
    echo -e "   ${CYAN}source ~/.bashrc${RESET}  (or ~/.zshrc for zsh)"
    echo ""
    echo "2. Start VPS-Manager:"
    echo -e "   ${CYAN}vps-manager${RESET}"
    echo ""
    echo "3. First time setup:"
    echo "   - Go to 'Cloud Provider Setup' to configure your cloud provider"
    echo "   - Add SSH keys and server profiles"
    echo "   - Start managing your VPS instances!"
    echo ""
    echo -e "${GREEN}Thank you for installing VPS-Manager!${RESET}"
    echo ""
}

# Run installation
main "$@"
