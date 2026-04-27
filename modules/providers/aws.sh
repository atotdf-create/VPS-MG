#!/bin/bash

################################################################################
# AWS Provider Module - VPS-Manager
# Handles VPS creation, configuration, and management on Amazon Web Services
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

# Check for AWS CLI installation
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        print_info "Run: pip3 install awscli"
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
# AWS SPECIFIC FUNCTIONS
# ============================================================================

# Get AWS regions
get_aws_regions() {
    check_aws_cli || return 1
    print_info "Fetching AWS regions..."
    aws ec2 describe-regions --query "Regions[].RegionName" --output text
}

# Get AWS AMIs (Ubuntu)
get_aws_amis() {
    check_aws_cli || return 1
    local region="$1"
    print_info "Fetching AWS AMIs for region ${region}..."
    aws ec2 describe-images \
        --region "$region" \
        --owners 099720109477 \
        --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-*-20.04-amd64-server-*" \
        "Name=state,Values=available" \
        --query "reverse(sort_by(Images, &CreationDate))[0].ImageId" --output text
}

# Get AWS Key Pairs
get_aws_key_pairs() {
    check_aws_cli || return 1
    local region="$1"
    print_info "Fetching AWS Key Pairs for region ${region}..."
    aws ec2 describe-key-pairs --region "$region" --query "KeyPairs[].KeyName" --output text
}

# Create AWS Key Pair
create_aws_key_pair() {
    check_aws_cli || return 1
    local key_name="$1"
    local region="$2"
    local key_path="${KEYS_DIR}/${key_name}.pem"
    
    if [[ -f "${key_path}" ]]; then
        print_warning "Key pair already exists locally: ${key_path}"
        return 1
    fi
    
    print_info "Creating AWS key pair \"${key_name}\" in region ${region}..."
    aws ec2 create-key-pair --key-name "$key_name" --region "$region" --query "KeyMaterial" --output text > "${key_path}" || {
        print_error "Failed to create AWS key pair."
        return 1
    }
    chmod 400 "${key_path}"
    print_success "AWS key pair \"${key_name}\" created and saved to ${key_path}"
    return 0
}

# Create AWS Security Group
create_aws_security_group() {
    check_aws_cli || return 1
    local group_name="$1"
    local description="$2"
    local region="$3"
    
    print_info "Creating security group \"${group_name}\" in region ${region}..."
    local vpc_id=$(aws ec2 describe-vpcs --region "$region" --filters "Name=isDefault,Values=true" --query "Vpcs[0].VpcId" --output text)
    
    local group_id=$(aws ec2 create-security-group \
        --group-name "$group_name" \
        --description "$description" \
        --vpc-id "$vpc_id" \
        --region "$region" \
        --query "GroupId" --output text) || {
        print_error "Failed to create security group. It might already exist."
        return 1
    }
    
    print_info "Authorizing SSH (port 22) and HTTP (port 80) ingress..."
    aws ec2 authorize-security-group-ingress \
        --group-id "$group_id" \
        --protocol tcp \
        --port 22 \
        --cidr 0.0.0.0/0 \
        --region "$region" || true # Ignore if rule already exists
        
    aws ec2 authorize-security-group-ingress \
        --group-id "$group_id" \
        --protocol tcp \
        --port 80 \
        --cidr 0.0.0.0/0 \
        --region "$region" || true # Ignore if rule already exists
        
    print_success "Security group \"${group_name}\" created with ID ${group_id}"
    echo "$group_id"
    return 0
}

# Create AWS VPS instance
create_aws_vps() {
    local vps_name="$1"
    local ssh_key_name="$2"
    
    check_aws_cli || return 1
    
    print_info "Starting AWS VPS creation for: ${vps_name}"
    
    # 1. Select Region
    local regions=($(get_aws_regions))
    if [[ ${#regions[@]} -eq 0 ]]; then
        print_error "No AWS regions found or AWS CLI not configured."
        return 1
    fi
    
    echo -e "${BOLD}Select a Region:${RESET}\n"
    select_option "${regions[@]}"
    local region_choice=$?
    local region="${regions[$((region_choice-1))]}"
    print_info "Selected Region: ${region}"
    
    # 2. Get AMI (Ubuntu 20.04 LTS)
    local ami_id=$(get_aws_amis "$region")
    if [[ -z "$ami_id" ]]; then
        print_error "Could not find a suitable Ubuntu AMI in region ${region}."
        return 1
    fi
    print_info "Using AMI: ${ami_id}"
    
    # 3. Check/Create Key Pair
    local key_pairs=($(get_aws_key_pairs "$region"))
    local selected_key_name=""
    if [[ -z "$ssh_key_name" ]]; then
        echo -e "${BOLD}Select an existing Key Pair or create a new one:${RESET}\n"
        key_pairs+=("[Create New Key Pair]")
        select_option "${key_pairs[@]}"
        local key_choice=$?
        if [[ "${key_pairs[$((key_choice-1))]}" == "[Create New Key Pair]" ]]; then
            read -p "$(print_color "${BOLD}${YELLOW}" "Enter new key pair name: ")" new_key_name
            if [[ -z "$new_key_name" ]]; then
                print_error "Key pair name cannot be empty."
                return 1
            fi
            create_aws_key_pair "$new_key_name" "$region" || return 1
            selected_key_name="$new_key_name"
        else
            selected_key_name="${key_pairs[$((key_choice-1))]}"
        fi
    else
        selected_key_name="$ssh_key_name"
        if ! echo "${key_pairs[@]}" | grep -q "\b${selected_key_name}\b"; then
            print_warning "Key pair \"${selected_key_name}\" not found in AWS. Creating a new one."
            create_aws_key_pair "$selected_key_name" "$region" || return 1
        fi
    fi
    
    if [[ -z "$selected_key_name" ]]; then
        print_error "No SSH key pair selected or created."
        return 1
    fi
    print_info "Using Key Pair: ${selected_key_name}"
    
    # 4. Create Security Group
    local security_group_name="${vps_name}-sg"
    local security_group_id=$(create_aws_security_group "$security_group_name" "Security group for ${vps_name}" "$region") || return 1
    
    # 5. Create instance (t2.micro for free tier)
    print_info "Creating instance... This may take a few minutes."
    
    local instance_json=$(aws ec2 run-instances \
        --image-id "$ami_id" \
        --count 1 \
        --instance-type t2.micro \
        --key-name "$selected_key_name" \
        --security-group-ids "$security_group_id" \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${vps_name}}]" \
        --region "$region" \
        --query "Instances[0]" --output json)
        
    local instance_id=$(echo "$instance_json" | jq -r ".InstanceId")
    
    if [[ -z "$instance_id" ]]; then
        print_error "Failed to create AWS VPS. Error: ${instance_json}"
        return 1
    fi
    
    print_info "Waiting for instance ${instance_id} to be running..."
    aws ec2 wait instance-running --instance-ids "$instance_id" --region "$region"
    
    local public_ip=$(aws ec2 describe-instances \
        --instance-ids "$instance_id" \
        --region "$region" \
        --query "Reservations[0].Instances[0].PublicIpAddress" --output text)
        
    if [[ -z "$public_ip" ]]; then
        print_error "Could not retrieve public IP for instance ${instance_id}."
        return 1
    fi
    
    print_success "AWS VPS \"${vps_name}\" created successfully!"
    print_info "Instance ID: ${instance_id}"
    print_info "Public IP: ${public_ip}"
    
    # Add to servers.json (assuming ubuntu user for AWS Ubuntu AMIs)
    local server_entry="{\"name\":\"${vps_name}\",\"ip\":\"${public_ip}\",\"user\":\"ubuntu\",\"port\":22,\"key\":\"${KEYS_DIR}/${selected_key_name}.pem\"}"
    
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

# List AWS VPS instances
list_aws_vps() {
    check_aws_cli || return 1
    print_info "Listing AWS VPS instances..."
    aws ec2 describe-instances \
        --filters "Name=instance-state-name,Values=running,stopped,pending" \
        --query "Reservations[].Instances[].{Name:Tags[?Key==`Name`]|[0].Value,InstanceId:InstanceId,State:State.Name,PublicIpAddress:PublicIpAddress,InstanceType:InstanceType,Region:`${AWS_DEFAULT_REGION:-us-east-1}`}" \
        --output json
}

# Start AWS VPS instance
start_aws_vps() {
    local instance_id="$1"
    local region="$2"
    check_aws_cli || return 1
    print_info "Starting AWS VPS instance: ${instance_id} in region ${region}"
    aws ec2 start-instances --instance-ids "$instance_id" --region "$region" --query "StartingInstances[0].CurrentState.Name" --output text
    print_success "Instance started: ${instance_id}"
}

# Stop AWS VPS instance
stop_aws_vps() {
    local instance_id="$1"
    local region="$2"
    check_aws_cli || return 1
    print_info "Stopping AWS VPS instance: ${instance_id} in region ${region}"
    aws ec2 stop-instances --instance-ids "$instance_id" --region "$region" --query "StoppingInstances[0].CurrentState.Name" --output text
    print_success "Instance stopped: ${instance_id}"
}

# Reboot AWS VPS instance
reboot_aws_vps() {
    local instance_id="$1"
    local region="$2"
    check_aws_cli || return 1
    print_info "Rebooting AWS VPS instance: ${instance_id} in region ${region}"
    aws ec2 reboot-instances --instance-ids "$instance_id" --region "$region"
    print_success "Instance rebooted: ${instance_id}"
}

# Terminate AWS VPS instance
terminate_aws_vps() {
    local instance_id="$1"
    local region="$2"
    check_aws_cli || return 1
    print_warning "This will permanently terminate AWS VPS instance: ${instance_id} in region ${region}"
    read -p "Are you sure? (y/n): " confirm
    if [[ "$confirm" == "y" ]]; then
        aws ec2 terminate-instances --instance-ids "$instance_id" --region "$region" --query "TerminatingInstances[0].CurrentState.Name" --output text
        print_success "Instance terminated: ${instance_id}"
    else
        print_info "Termination cancelled."
    fi
}

# ============================================================================
# MAIN EXECUTION (if script is called directly)
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script was called directly
    case "${1:-help}" in
        create)
            create_aws_vps "${2:-}" "${3:-}"
            ;;
        list)
            list_aws_vps
            ;;
        start)
            start_aws_vps "${2:-}" "${3:-}"
            ;;
        stop)
            stop_aws_vps "${2:-}" "${3:-}"
            ;;
        reboot)
            reboot_aws_vps "${2:-}" "${3:-}"
            ;;
        terminate)
            terminate_aws_vps "${2:-}" "${3:-}"
            ;;
        *)
            echo "AWS Provider Module - VPS-Manager"
            echo ""
            echo "Usage: $0 <command> [options]"
            echo ""
            echo "Commands:"
            echo "  create [vps_name] [ssh_key_name]         Create new AWS VPS"
            echo "  list                                     List all AWS VPS instances"
            echo "  start [instance_id] [region]             Start AWS VPS instance"
            echo "  stop [instance_id] [region]              Stop AWS VPS instance"
            echo "  reboot [instance_id] [region]            Reboot AWS VPS instance"
            echo "  terminate [instance_id] [region]         Terminate AWS VPS instance"
            ;;
    esac
fi
