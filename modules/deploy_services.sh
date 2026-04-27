#!/bin/bash

################################################################################
# Service Deployment Module - VPS-Manager
# Deploys and configures common services on VPS instances
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
# WEB SERVER DEPLOYMENT
# ============================================================================

# Deploy Nginx
deploy_nginx() {
    local server_name="$1"
    
    print_info "Deploying Nginx on: ${server_name}"
    
    local install_script='
#!/bin/bash
set -e
echo "Installing Nginx..."
apt-get update -qq
apt-get install -y nginx
systemctl enable nginx
systemctl start nginx
echo "Nginx installed and started successfully!"
'
    
    ssh_exec "$server_name" "$install_script" || {
        print_error "Failed to deploy Nginx."
        return 1
    }
    
    print_success "Nginx deployed successfully!"
    print_info "Access your server at: http://$(get_server_connection "$server_name" | cut -d'|' -f1)"
}

# Deploy Apache
deploy_apache() {
    local server_name="$1"
    
    print_info "Deploying Apache on: ${server_name}"
    
    local install_script='
#!/bin/bash
set -e
echo "Installing Apache..."
apt-get update -qq
apt-get install -y apache2
systemctl enable apache2
systemctl start apache2
echo "Apache installed and started successfully!"
'
    
    ssh_exec "$server_name" "$install_script" || {
        print_error "Failed to deploy Apache."
        return 1
    }
    
    print_success "Apache deployed successfully!"
    print_info "Access your server at: http://$(get_server_connection "$server_name" | cut -d'|' -f1)"
}

# ============================================================================
# VPN DEPLOYMENT
# ============================================================================

# Deploy OpenVPN
deploy_openvpn() {
    local server_name="$1"
    
    print_info "Deploying OpenVPN on: ${server_name}"
    
    local install_script='
#!/bin/bash
set -e
echo "Installing OpenVPN..."
apt-get update -qq
apt-get install -y openvpn easy-rsa

# Initialize PKI
mkdir -p /etc/openvpn/easy-rsa
cd /etc/openvpn/easy-rsa
./easyrsa init-pki
./easyrsa build-ca nopass
./easyrsa gen-req server nopass
./easyrsa sign-req server server

# Generate DH parameters
openssl dhparam -out /etc/openvpn/dh.pem 2048

# Enable IP forwarding
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p

systemctl enable openvpn
echo "OpenVPN installed successfully!"
echo "Note: Configuration and client setup required manually."
'
    
    ssh_exec "$server_name" "$install_script" || {
        print_error "Failed to deploy OpenVPN."
        return 1
    }
    
    print_success "OpenVPN deployed successfully!"
    print_warning "Manual configuration required. Please complete the setup on the server."
}

# ============================================================================
# PROXY DEPLOYMENT
# ============================================================================

# Deploy Squid Proxy
deploy_squid() {
    local server_name="$1"
    
    print_info "Deploying Squid Proxy on: ${server_name}"
    
    local install_script='
#!/bin/bash
set -e
echo "Installing Squid..."
apt-get update -qq
apt-get install -y squid

# Basic Squid configuration
cat > /etc/squid/squid.conf << EOF
acl localnet src 0.0.0.1-0.255.255.255
acl localnet src 10.0.0.0/8
acl localnet src 100.64.0.0/10
acl localnet src 169.254.0.0/16
acl localnet src 172.16.0.0/12
acl localnet src 192.168.0.0/16
acl localnet src fc00::/7
acl localnet src fe80::/10

acl SSL_ports port 443
acl Safe_ports port 80
acl Safe_ports port 21
acl Safe_ports port 443
acl Safe_ports port 70
acl Safe_ports port 210
acl Safe_ports port 1025-65535
acl Safe_ports port 280
acl Safe_ports port 488
acl Safe_ports port 591
acl Safe_ports port 777

http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports
http_access allow localhost manager
http_access deny manager
http_access allow localnet
http_access allow localhost
http_access deny all

http_port 3128

coredump_dir /var/spool/squid
EOF

systemctl enable squid
systemctl start squid
echo "Squid installed and started successfully!"
'
    
    ssh_exec "$server_name" "$install_script" || {
        print_error "Failed to deploy Squid."
        return 1
    }
    
    print_success "Squid Proxy deployed successfully!"
    print_info "Proxy address: $(get_server_connection "$server_name" | cut -d'|' -f1):3128"
}

# ============================================================================
# CONTAINER DEPLOYMENT
# ============================================================================

# Deploy Docker
deploy_docker() {
    local server_name="$1"
    
    print_info "Deploying Docker on: ${server_name}"
    
    local install_script='
#!/bin/bash
set -e
echo "Installing Docker..."
apt-get update -qq
apt-get install -y curl gnupg lsb-release

# Add Docker GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
apt-get update -qq
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Enable Docker
systemctl enable docker
systemctl start docker

# Add current user to docker group
usermod -aG docker root

echo "Docker installed successfully!"
docker --version
'
    
    ssh_exec "$server_name" "$install_script" || {
        print_error "Failed to deploy Docker."
        return 1
    }
    
    print_success "Docker deployed successfully!"
}

# ============================================================================
# RUNTIME DEPLOYMENT
# ============================================================================

# Deploy Node.js
deploy_nodejs() {
    local server_name="$1"
    
    print_info "Deploying Node.js on: ${server_name}"
    
    local install_script='
#!/bin/bash
set -e
echo "Installing Node.js..."
apt-get update -qq
apt-get install -y curl

# Install Node.js using NodeSource repository
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt-get install -y nodejs

echo "Node.js installed successfully!"
node --version
npm --version
'
    
    ssh_exec "$server_name" "$install_script" || {
        print_error "Failed to deploy Node.js."
        return 1
    }
    
    print_success "Node.js deployed successfully!"
}

# Deploy Python
deploy_python() {
    local server_name="$1"
    
    print_info "Deploying Python on: ${server_name}"
    
    local install_script='
#!/bin/bash
set -e
echo "Installing Python..."
apt-get update -qq
apt-get install -y python3 python3-pip python3-venv

# Install common Python packages
pip3 install --upgrade pip setuptools wheel

echo "Python installed successfully!"
python3 --version
pip3 --version
'
    
    ssh_exec "$server_name" "$install_script" || {
        print_error "Failed to deploy Python."
        return 1
    }
    
    print_success "Python deployed successfully!"
}

# ============================================================================
# SECURITY DEPLOYMENT
# ============================================================================

# Deploy UFW Firewall
deploy_ufw() {
    local server_name="$1"
    
    print_info "Deploying UFW Firewall on: ${server_name}"
    
    local install_script='
#!/bin/bash
set -e
echo "Installing and configuring UFW..."
apt-get update -qq
apt-get install -y ufw

# Allow SSH
ufw allow 22/tcp

# Allow HTTP and HTTPS
ufw allow 80/tcp
ufw allow 443/tcp

# Enable UFW
ufw --force enable

echo "UFW firewall configured successfully!"
ufw status
'
    
    ssh_exec "$server_name" "$install_script" || {
        print_error "Failed to deploy UFW."
        return 1
    }
    
    print_success "UFW Firewall deployed successfully!"
}

# Deploy Fail2Ban
deploy_fail2ban() {
    local server_name="$1"
    
    print_info "Deploying Fail2Ban on: ${server_name}"
    
    local install_script='
#!/bin/bash
set -e
echo "Installing Fail2Ban..."
apt-get update -qq
apt-get install -y fail2ban

# Create local configuration
cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
EOF

systemctl enable fail2ban
systemctl start fail2ban

echo "Fail2Ban installed and started successfully!"
'
    
    ssh_exec "$server_name" "$install_script" || {
        print_error "Failed to deploy Fail2Ban."
        return 1
    }
    
    print_success "Fail2Ban deployed successfully!"
}

# ============================================================================
# SYSTEM UTILITIES DEPLOYMENT
# ============================================================================

# Deploy common utilities
deploy_utilities() {
    local server_name="$1"
    
    print_info "Installing common utilities on: ${server_name}"
    
    local install_script='
#!/bin/bash
set -e
echo "Installing common utilities..."
apt-get update -qq
apt-get install -y \
    curl \
    wget \
    git \
    vim \
    nano \
    htop \
    tmux \
    screen \
    net-tools \
    dnsutils \
    traceroute \
    telnet \
    zip \
    unzip \
    tar \
    gzip

echo "Common utilities installed successfully!"
'
    
    ssh_exec "$server_name" "$install_script" || {
        print_error "Failed to install utilities."
        return 1
    }
    
    print_success "Common utilities installed successfully!"
}

# ============================================================================
# MAIN EXECUTION (if script is called directly)
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script was called directly
    case "${1:-help}" in
        nginx)
            deploy_nginx "${2:-}"
            ;;
        apache)
            deploy_apache "${2:-}"
            ;;
        openvpn)
            deploy_openvpn "${2:-}"
            ;;
        squid)
            deploy_squid "${2:-}"
            ;;
        docker)
            deploy_docker "${2:-}"
            ;;
        nodejs)
            deploy_nodejs "${2:-}"
            ;;
        python)
            deploy_python "${2:-}"
            ;;
        ufw)
            deploy_ufw "${2:-}"
            ;;
        fail2ban)
            deploy_fail2ban "${2:-}"
            ;;
        utilities)
            deploy_utilities "${2:-}"
            ;;
        *)
            echo "Service Deployment Module - VPS-Manager"
            echo ""
            echo "Usage: $0 <service> <server_name>"
            echo ""
            echo "Web Servers:"
            echo "  nginx [server]        Deploy Nginx"
            echo "  apache [server]       Deploy Apache"
            echo ""
            echo "VPN & Proxy:"
            echo "  openvpn [server]      Deploy OpenVPN"
            echo "  squid [server]        Deploy Squid Proxy"
            echo ""
            echo "Containers & Runtimes:"
            echo "  docker [server]       Deploy Docker"
            echo "  nodejs [server]       Deploy Node.js"
            echo "  python [server]       Deploy Python"
            echo ""
            echo "Security:"
            echo "  ufw [server]          Deploy UFW Firewall"
            echo "  fail2ban [server]     Deploy Fail2Ban"
            echo ""
            echo "Utilities:"
            echo "  utilities [server]    Install common utilities"
            ;;
    esac
fi
