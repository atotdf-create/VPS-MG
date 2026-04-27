# VPS-Manager Design Document

## 1. Introduction

This document outlines the design and architecture for the `VPS-Manager` Termux tool. The tool aims to provide a user-friendly command-line interface (CLI) for creating and managing free-tier Virtual Private Server (VPS) instances across various cloud providers, specifically Oracle Cloud, Google Cloud Platform, AWS, and Azure. The tool will feature a polished UI with ASCII art banners, colored menus, and step-by-step guidance for users.

## 2. Architecture Overview

The `VPS-Manager` will be a pure bash script, designed for compatibility with Termux. It will follow a modular architecture to ensure maintainability and extensibility. The core script (`vps-manager.sh`) will handle the main menu, UI rendering, and dispatching calls to various sub-modules. Configuration and server profiles will be stored in `~/.vps-manager/`.

```
VPS-Manager/
├── vps-manager.sh          # Main script, UI, menu handling
├── install.sh              # Termux installation script
├── README.md               # Documentation
└── modules/
    ├── providers/          # Cloud provider specific modules
    │   ├── oracle.sh
    │   ├── gcp.sh
    │   ├── aws.sh
    │   └── azure.sh
    ├── vps_management.sh   # Create, configure, delete VPS
    ├── ssh_manager.sh      # SSH connection management
    ├── monitoring.sh       # Server monitoring
    ├── deploy_services.sh  # Service deployment (web, VPN, proxy)
    └── backup_restore.sh   # Backup and restore configurations
└── config/
    └── servers.json        # JSON-like format for server profiles
    └── settings.conf       # General tool settings
```

## 3. User Interface (UI) Design

The UI will be a key aspect of `VPS-Manager`, focusing on a professional and interactive experience.

### 3.1. Banners and Colors
- **ASCII Art Banner**: A prominent ASCII art banner will be displayed at the start of the tool.
- **Colored Output**: ANSI escape codes will be used extensively for:
    - Menu options (e.g., green for active, yellow for warnings)
    - Status messages (e.g., green for success, red for error, yellow for info)
    - Loading animations (simple animated dots or spinners)

### 3.2. Menus
- **Main Menu**: The central navigation point, allowing users to select major functionalities (e.g., Manage VPS, SSH Manager, Deploy Services).
- **Sub-menus**: Each major functionality will have its own sub-menu for specific actions.
- **Interactive Selection**: The `select` command or similar bash constructs will be used for interactive menu navigation.

### 3.3. Input and Validation
- **Clear Prompts**: User input will be requested with clear and concise prompts.
- **Input Validation**: Basic input validation will be implemented to ensure data integrity (e.g., checking for empty inputs, valid numbers).

## 4. Core Functionalities

### 4.1. Installation (`install.sh`)
- Checks for Termux environment.
- Installs necessary Termux packages (openssh, curl, wget, jq, etc.).
- Creates the `~/.vps-manager/` directory structure.
- Copies `vps-manager.sh` and `modules/` to appropriate locations.
- Sets up necessary permissions.

### 4.2. Main Script (`vps-manager.sh`)
- Displays banner and main menu.
- Handles user input for menu selection.
- Dispatches calls to relevant modules based on user choice.
- Includes global error handling and exit routines.

### 4.3. Provider Modules (`modules/providers/*.sh`)
- Each provider module will contain functions specific to that cloud provider.
- **Account Setup Guidance**: Provides step-by-step instructions and links for users to sign up for free-tier accounts.
- **CLI Installation**: Guides users to install and configure the respective cloud provider CLIs (OCI CLI, gcloud, aws cli, az cli).
- **VPS Creation/Configuration**: Functions to create, list, stop, start, and terminate VPS instances using the provider CLIs.
- **Automated VPS Setup**: Scripts to install common packages, configure firewalls, and set up SSH keys on newly created VPS instances.

### 4.4. VPS Management (`modules/vps_management.sh`)
- Lists all managed VPS instances.
- Provides options to create, configure, start, stop, restart, and delete VPS instances.
- Integrates with provider-specific modules for actual cloud operations.

### 4.5. SSH Connection Manager (`modules/ssh_manager.sh`)
- Generates and manages SSH key pairs.
- Saves and lists server connection profiles (IP, user, key path).
- Facilitates SSH connections to managed VPS instances.

### 4.6. Server Monitoring (`modules/monitoring.sh`)
- Connects to a specified VPS via SSH.
- Executes commands to retrieve system metrics (CPU, RAM, disk usage).
- Displays monitoring data in a user-friendly format.

### 4.7. Deploy Common Services (`modules/deploy_services.sh`)
- Offers a menu of common services (web server, VPN server, proxy server).
- Provides automated scripts to deploy and configure selected services on a target VPS.

### 4.8. Backup and Restore (`modules/backup_restore.sh`)
- Backs up server configurations (e.g., dotfiles, service configurations) from a VPS.
- Restores configurations to a VPS.

## 5. Configuration Management

- **Config Directory**: `~/.vps-manager/` will store all tool-specific configurations.
- **Server Profiles**: `~/.vps-manager/servers.json` will store details of managed VPS instances in a JSON-like format (using `jq` for parsing).
- **Tool Settings**: `~/.vps-manager/settings.conf` will store general tool settings (e.g., default SSH user, preferred cloud provider).

## 6. Technical Considerations

- **Pure Bash**: All scripts will be written in pure bash for maximum compatibility within Termux.
- **Error Handling**: Robust error handling will be implemented using `set -e`, `trap`, and explicit error checks.
- **Input Validation**: User inputs will be validated to prevent common errors and security vulnerabilities.
- **SSH Key Management**: Secure generation and storage of SSH keys.

## 7. Next Steps

1. Develop the `install.sh` script.
2. Implement the core `vps-manager.sh` script with the main menu and UI elements.
3. Create the `modules/` directory and initial empty module files.
4. Begin implementing the `ssh_manager.sh` module for key generation and connection management.
