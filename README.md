# VPS-Manager - Professional Free-Tier VPS Management Tool

![Version](https://img.shields.io/badge/version-1.0.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Platform](https://img.shields.io/badge/platform-Termux%20%7C%20Linux-orange)

**VPS-Manager** is a powerful, feature-rich command-line tool designed to help users create and manage Virtual Private Server (VPS) instances across multiple free-tier cloud providers. Built specifically for Termux and Linux environments, it provides a polished user interface with ASCII art banners, colored menus, and step-by-step guidance.

## 🚀 Features

### Core Capabilities

- **Multi-Provider Support**: Manage VPS instances across Oracle Cloud, Google Cloud Platform, AWS, and Microsoft Azure
- **Professional UI**: Beautiful ASCII art banners, colored output, and interactive menus
- **SSH Management**: Generate, store, and manage SSH keys and server profiles
- **Server Monitoring**: Real-time monitoring of CPU, RAM, disk usage, and system metrics
- **Service Deployment**: One-click deployment of web servers, VPN, proxy, Docker, and more
- **Backup & Restore**: Automated backup and restoration of server configurations
- **Cloud Provider Setup**: Step-by-step guidance for setting up free-tier accounts

### Supported Cloud Providers

| Provider | Free Tier | Resources | Duration |
|----------|-----------|-----------|----------|
| **Oracle Cloud** | Always Free | 4 ARM cores, 24GB RAM, 200GB storage | Unlimited |
| **Google Cloud** | Free Tier | e2-micro instance, 30GB disk, 5GB storage | 12 months |
| **AWS** | Free Tier | t2.micro instance, 30GB EBS, 15GB transfer | 12 months |
| **Microsoft Azure** | Free Tier | B1s VM, 64GB disk, 750 hours compute | 12 months |

### Deployable Services

- **Web Servers**: Nginx, Apache
- **VPN**: OpenVPN
- **Proxy**: Squid
- **Containers**: Docker & Docker Compose
- **Runtimes**: Node.js, Python
- **Security**: UFW Firewall, Fail2Ban
- **Utilities**: Common system tools and utilities

## 📋 Requirements

### Minimum Requirements

- **OS**: Termux (Android) or Linux
- **Bash**: Version 4.0 or higher
- **SSH**: OpenSSH client and server
- **Utilities**: curl, wget, git, jq (optional)

### Recommended Setup

- 2GB+ RAM
- 500MB+ free storage
- Stable internet connection
- Active cloud provider account (free tier)

## 🔧 Installation

### Quick Install (Termux)

```bash
pkg install git -y
git clone https://github.com/atotdf-create/VPS-MG
cd VPS-MG
bash install.sh
bash vps-manager.sh
```

### Manual Installation

```bash
# 1. Install dependencies
pkg update && pkg install -y openssh curl wget git jq

# 2. Create installation directory
mkdir -p ~/.local/bin

# 3. Copy VPS-Manager
cp vps-manager.sh ~/.local/bin/vps-manager
chmod +x ~/.local/bin/vps-manager

# 4. Add to PATH (add to ~/.bashrc or ~/.zshrc)
export PATH="${PATH}:${HOME}/.local/bin"

# 5. Initialize configuration
mkdir -p ~/.vps-manager
echo "[]" > ~/.vps-manager/servers.json

# 6. Start VPS-Manager
vps-manager
```

### Linux Installation

```bash
# Install dependencies (Ubuntu/Debian)
sudo apt-get update
sudo apt-get install -y openssh-client openssh-server curl wget git jq

# Follow the same steps as manual installation above
```

## 📖 Usage Guide

### Starting VPS-Manager

```bash
vps-manager
```

This will display the main menu with the following options:

```
╔═══════════════════════════════════════════════════════════════════════════╗
║                        🚀 VPS-MANAGER v1.0.0 🚀                        ║
║              Professional Free-Tier VPS Management Tool                  ║
║                          For Termux & Linux                              ║
╚═══════════════════════════════════════════════════════════════════════════╝

Select an option:

1) Manage VPS Instances
2) SSH Connection Manager
3) Server Monitoring
4) Deploy Services
5) Backup & Restore
6) Cloud Provider Setup
7) Settings
8) About
0) Exit
```

### Main Menu Options

#### 1. Manage VPS Instances

Create, configure, and manage your VPS instances across cloud providers.

**Submenu**:
- List All VPS Instances
- Create New VPS
- Configure VPS
- Start VPS
- Stop VPS
- Restart VPS
- Delete VPS

**Example**:
```bash
# From main menu, select option 1
# Then select option 2 to create a new VPS
# Follow the prompts to select provider and configure instance
```

#### 2. SSH Connection Manager

Manage SSH keys and server profiles for easy connection management.

**Submenu**:
- Generate SSH Key Pair
- List Saved Servers
- Add New Server Profile
- Connect to Server
- Remove Server Profile
- Edit Server Profile

**Example**:
```bash
# Generate a new SSH key
vps-manager -> 2 -> 1 -> Enter key name

# Add a server profile
vps-manager -> 2 -> 3 -> Enter server details

# Connect to server
vps-manager -> 2 -> 4 -> Select server
```

#### 3. Server Monitoring

Monitor your VPS instances in real-time or on-demand.

**Submenu**:
- Check Server Status
- View CPU Usage
- View Memory Usage
- View Disk Usage
- View All Metrics
- Real-time Monitoring

**Example**:
```bash
# Check server status
vps-manager -> 3 -> 1 -> Select server

# Real-time monitoring (updates every 5 seconds)
vps-manager -> 3 -> 6 -> Select server
```

#### 4. Deploy Services

Deploy common services and applications to your VPS.

**Submenu**:
- Web Server (Nginx)
- Web Server (Apache)
- VPN Server (OpenVPN)
- Proxy Server (Squid)
- Docker & Docker Compose
- Node.js & npm
- Python & pip

**Example**:
```bash
# Deploy Nginx web server
vps-manager -> 4 -> 1 -> Select server

# Deploy Docker
vps-manager -> 4 -> 5 -> Select server
```

#### 5. Backup & Restore

Create and manage server configuration backups.

**Submenu**:
- Backup Server Configuration
- Restore Server Configuration
- List Backups
- Delete Backup

**Example**:
```bash
# Create a backup
vps-manager -> 5 -> 1 -> Select server

# List all backups
vps-manager -> 5 -> 3

# Restore from backup
vps-manager -> 5 -> 2 -> Select backup and server
```

#### 6. Cloud Provider Setup

Get step-by-step guidance for setting up free-tier cloud accounts.

**Submenu**:
- Oracle Cloud (Always Free Tier)
- Google Cloud Platform (e2-micro)
- Amazon Web Services (t2.micro)
- Microsoft Azure (B1s)

**Example**:
```bash
# Setup Oracle Cloud
vps-manager -> 6 -> 1
# Follow the displayed instructions
```

#### 7. Settings

Configure VPS-Manager preferences and behavior.

**Submenu**:
- Change Default SSH User
- Change Default SSH Port
- Change Preferred Provider
- Toggle Debug Mode
- View Current Settings

**Example**:
```bash
# Change default SSH user
vps-manager -> 7 -> 1 -> Enter new user

# View current settings
vps-manager -> 7 -> 5
```

## 🔑 SSH Key Management

### Generate SSH Keys

```bash
# Generate default key pair
vps-manager -> 2 -> 1 -> id_rsa

# Generate custom key
vps-manager -> 2 -> 1 -> my_custom_key
```

Keys are stored in `~/.vps-manager/keys/` with proper permissions (600 for private, 644 for public).

### Add Server Profile

```bash
vps-manager -> 2 -> 3
# Enter server details:
# - Server name: my-vps
# - Server IP: 123.45.67.89
# - SSH user: root
# - SSH port: 22
# - SSH key path: ~/.vps-manager/keys/id_rsa
```

### Connect to Server

```bash
vps-manager -> 2 -> 4
# Select server from list
# SSH connection established automatically
```

## 📊 Server Monitoring

### Real-Time Monitoring

```bash
vps-manager -> 3 -> 6
# Select server
# Monitoring updates every 5 seconds
# Press Ctrl+C to stop
```

### Metrics Displayed

- **System Uptime**: How long the server has been running
- **Load Average**: CPU load over 1, 5, and 15 minutes
- **CPU Usage**: Current CPU utilization percentage
- **Memory Usage**: RAM usage and percentage
- **Disk Usage**: Storage usage by partition
- **Network Interfaces**: Active network connections
- **Top Processes**: Memory-consuming processes

## 🚀 Service Deployment

### Deploy Web Server

```bash
# Deploy Nginx
vps-manager -> 4 -> 1 -> Select server

# Deploy Apache
vps-manager -> 4 -> 2 -> Select server
```

### Deploy VPN

```bash
# Deploy OpenVPN
vps-manager -> 4 -> 3 -> Select server
# Note: Manual configuration required after deployment
```

### Deploy Docker

```bash
# Deploy Docker and Docker Compose
vps-manager -> 4 -> 5 -> Select server
```

### Deploy Runtimes

```bash
# Deploy Node.js
vps-manager -> 4 -> 6 -> Select server

# Deploy Python
vps-manager -> 4 -> 7 -> Select server
```

## 💾 Backup & Restore

### Create Backup

```bash
vps-manager -> 5 -> 1 -> Select server
# Backup includes:
# - System information
# - Network configuration
# - Installed packages
# - SSH configuration
# - Firewall rules
# - Cron jobs
# - Environment variables
```

### Restore Backup

```bash
vps-manager -> 5 -> 2 -> Select backup -> Select server
# Restoration includes configuration files and system settings
```

### Schedule Automatic Backups

```bash
# Via command line
./modules/backup_restore.sh schedule my-vps daily
./modules/backup_restore.sh schedule my-vps weekly
./modules/backup_restore.sh schedule my-vps monthly
```

## 🛠️ Advanced Usage

### Using Modules Directly

Each module can be used independently:

```bash
# SSH Manager
./modules/ssh_manager.sh generate my-key
./modules/ssh_manager.sh add-server my-vps 123.45.67.89 root 22
./modules/ssh_manager.sh connect my-vps

# Monitoring
./modules/monitoring.sh status my-vps
./modules/monitoring.sh all my-vps
./modules/monitoring.sh realtime my-vps 10

# Deployment
./modules/deploy_services.sh nginx my-vps
./modules/deploy_services.sh docker my-vps

# Backup & Restore
./modules/backup_restore.sh backup my-vps
./modules/backup_restore.sh list
./modules/backup_restore.sh restore backup_file my-vps
```

### Configuration Files

**Main Configuration**: `~/.vps-manager/settings.conf`
```bash
DEFAULT_SSH_USER="root"
DEFAULT_SSH_PORT="22"
PREFERRED_PROVIDER="oracle"
DEBUG="0"
```

**Server Database**: `~/.vps-manager/servers.json`
```json
[
  {
    "name": "my-vps",
    "ip": "123.45.67.89",
    "user": "root",
    "port": 22,
    "key": "~/.vps-manager/keys/id_rsa"
  }
]
```

### Debug Mode

Enable debug mode to see detailed execution information:

```bash
vps-manager -> 7 -> 4  # Toggle debug mode
```

Or set manually:
```bash
sed -i 's/DEBUG="0"/DEBUG="1"/' ~/.vps-manager/settings.conf
```

## 🐛 Troubleshooting

### SSH Connection Issues

**Problem**: Cannot connect to server
```bash
# Check server status first
vps-manager -> 3 -> 1

# Verify SSH key permissions
ls -la ~/.vps-manager/keys/

# Check SSH configuration
cat ~/.vps-manager/servers.json
```

### Permission Denied

```bash
# Fix SSH key permissions
chmod 600 ~/.vps-manager/keys/id_rsa
chmod 644 ~/.vps-manager/keys/id_rsa.pub
```

### Module Not Found

```bash
# Ensure modules are in correct location
ls -la ~/.local/bin/vps-manager-modules/

# Or reinstall
bash install.sh
```

### Deployment Failures

```bash
# Check server connectivity
ssh -v user@server_ip

# Enable debug mode
vps-manager -> 7 -> 4

# Check server logs
vps-manager -> 3 -> 4  # View disk usage
```

## 📚 Cloud Provider Guides

### Oracle Cloud Setup

1. Visit: https://www.oracle.com/cloud/free/
2. Create account and verify email
3. Install OCI CLI: `pip3 install oci-cli`
4. Configure: `oci setup config`
5. Create VPS instance via VPS-Manager

### Google Cloud Setup

1. Visit: https://cloud.google.com/free
2. Create project and enable Compute Engine
3. Install gcloud: https://cloud.google.com/sdk/docs/install
4. Initialize: `gcloud init`
5. Create VPS instance via VPS-Manager

### AWS Setup

1. Visit: https://aws.amazon.com/free/
2. Create account and verify
3. Install AWS CLI: `pip3 install awscli`
4. Configure: `aws configure`
5. Create VPS instance via VPS-Manager

### Azure Setup

1. Visit: https://azure.microsoft.com/free/
2. Create account and verify
3. Install Azure CLI: `curl -sL https://aka.ms/InstallAzureCLIDeb | bash`
4. Login: `az login`
5. Create VPS instance via VPS-Manager

## 🔒 Security Best Practices

1. **SSH Keys**: Always use SSH keys instead of passwords
2. **Firewall**: Enable UFW firewall on all servers
3. **Fail2Ban**: Install Fail2Ban to prevent brute-force attacks
4. **Backups**: Regularly backup server configurations
5. **Updates**: Keep systems updated with latest patches
6. **Permissions**: Restrict file permissions appropriately

## 📝 File Structure

```
VPS-Manager/
├── vps-manager.sh              # Main script
├── install.sh                  # Installation script
├── README.md                   # This file
├── design_document.md          # Architecture documentation
└── modules/
    ├── ssh_manager.sh          # SSH key and server management
    ├── monitoring.sh           # Server monitoring
    ├── deploy_services.sh      # Service deployment
    └── backup_restore.sh       # Backup and restore
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 👨‍💻 Author

**Manus AI** - Professional VPS Management Tool

## 🙏 Acknowledgments

- Termux community for the amazing Android Linux environment
- Cloud providers for free-tier offerings
- Open-source community for tools and libraries

## 📞 Support

For issues, questions, or suggestions:

1. Check the troubleshooting section
2. Review the design documentation
3. Enable debug mode for detailed logs
4. Submit an issue on GitHub

## 🚀 Roadmap

- [ ] Web-based dashboard
- [ ] Kubernetes support
- [ ] Advanced networking features
- [ ] Multi-cloud orchestration
- [ ] Cost tracking and optimization
- [ ] Automated scaling
- [ ] Enhanced security features

## 📊 Statistics

- **Lines of Code**: 2000+
- **Modules**: 4 core + main script
- **Supported Providers**: 4
- **Deployable Services**: 10+
- **Monitoring Metrics**: 7+

---

**Made with ❤️ for the Termux and Linux community**

Last Updated: April 2026
Version: 1.0.0
