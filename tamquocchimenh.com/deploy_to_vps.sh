#!/bin/bash

# Bash deployment script for tamquocchimenh.com website
# This script will deploy the website to VPS and set up SSH access

# Configuration
VPS_USER="devtech"
VPS_IP="103.77.214.231"
VPS_PATH="/www/wwwroot/tamquocchimenh.com"
SSH_KEY_PATH="$HOME/.ssh/id_rsa.pub"
SKIP_SSH_KEY=false
DRY_RUN=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}=== Website Deployment Script ===${NC}"
    echo -e "${YELLOW}VPS: $VPS_USER@$VPS_IP${NC}"
    echo -e "${YELLOW}Target Path: $VPS_PATH${NC}"
    echo -e "${YELLOW}SSH Key: $SSH_KEY_PATH${NC}"
    echo -e "${YELLOW}Dry Run: $DRY_RUN${NC}"
    echo ""
}

# Function to execute SSH commands
ssh_command() {
    local cmd="$1"
    local description="$2"
    
    echo -e "${CYAN}SSH: $description${NC}"
    if [ "$DRY_RUN" = true ]; then
        echo -e "  ${YELLOW}[DRY RUN] ssh $VPS_USER@$VPS_IP '$cmd'${NC}"
        return 0
    fi
    
    if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$VPS_USER@$VPS_IP" "$cmd" 2>/dev/null; then
        echo -e "  ${GREEN}✓ Success${NC}"
        return 0
    else
        echo -e "  ${RED}✗ Failed${NC}"
        return 1
    fi
}

# Function to copy files via SCP
scp_files() {
    local local_path="$1"
    local remote_path="$2"
    local description="$3"
    
    echo -e "${CYAN}SCP: $description${NC}"
    if [ "$DRY_RUN" = true ]; then
        echo -e "  ${YELLOW}[DRY RUN] scp -r '$local_path' $VPS_USER@$VPS_IP:$remote_path${NC}"
        return 0
    fi
    
    if scp -r -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$local_path" "$VPS_USER@$VPS_IP:$remote_path" 2>/dev/null; then
        echo -e "  ${GREEN}✓ Success${NC}"
        return 0
    else
        echo -e "  ${RED}✗ Failed${NC}"
        return 1
    fi
}

# Main deployment function
main() {
    print_status
    
    # Check if required tools are available
    if ! command -v ssh &> /dev/null; then
        echo -e "${RED}Error: ssh command not found. Please install OpenSSH.${NC}"
        exit 1
    fi
    
    if ! command -v scp &> /dev/null; then
        echo -e "${RED}Error: scp command not found. Please install OpenSSH.${NC}"
        exit 1
    fi
    
    # Check if SSH key exists
    if [ "$SKIP_SSH_KEY" = false ] && [ ! -f "$SSH_KEY_PATH" ]; then
        echo -e "${YELLOW}Warning: SSH public key not found at $SSH_KEY_PATH${NC}"
        echo -e "${YELLOW}You can generate one with: ssh-keygen -t rsa -b 4096 -C 'your_email@example.com'${NC}"
        SKIP_SSH_KEY=true
    fi
    
    # Step 1: Test SSH connection
    echo -e "${MAGENTA}Step 1: Testing SSH connection...${NC}"
    if ! ssh_command "echo 'SSH connection successful'" "Testing connection"; then
        echo -e "${RED}Failed to connect to VPS. Please check:${NC}"
        echo -e "${RED}  - VPS IP address and username are correct${NC}"
        echo -e "${RED}  - VPS is running and accessible${NC}"
        echo -e "${RED}  - SSH service is running on the VPS${NC}"
        exit 1
    fi
    
    # Step 2: Add SSH key to authorized_keys
    if [ "$SKIP_SSH_KEY" = false ]; then
        echo -e "${MAGENTA}Step 2: Adding SSH public key...${NC}"
        ssh_key_content=$(cat "$SSH_KEY_PATH")
        
        # Create .ssh directory if it doesn't exist
        ssh_command "mkdir -p ~/.ssh" "Creating .ssh directory"
        
        # Add key to authorized_keys
        add_key_cmd="echo '$ssh_key_content' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && chmod 700 ~/.ssh"
        if ssh_command "$add_key_cmd" "Adding SSH key to authorized_keys"; then
            echo -e "  ${GREEN}✓ SSH key added successfully${NC}"
        else
            echo -e "  ${YELLOW}⚠ SSH key addition failed, but continuing with deployment${NC}"
        fi
    fi
    
    # Step 3: Create target directory
    echo -e "${MAGENTA}Step 3: Setting up target directory...${NC}"
    ssh_command "sudo mkdir -p $VPS_PATH" "Creating target directory"
    ssh_command "sudo chown -R $VPS_USER:$VPS_USER $VPS_PATH" "Setting ownership"
    
    # Step 4: Backup existing files (if any)
    echo -e "${MAGENTA}Step 4: Creating backup...${NC}"
    backup_path="/www/wwwroot/tamquocchimenh.com.backup.$(date +%Y%m%d-%H%M%S)"
    ssh_command "if [ -d '$VPS_PATH' ] && [ \$(ls -A '$VPS_PATH' 2>/dev/null) ]; then sudo cp -r '$VPS_PATH' '$backup_path'; echo 'Backup created at $backup_path'; else echo 'No existing files to backup'; fi" "Creating backup"
    
    # Step 5: Deploy website files
    echo -e "${MAGENTA}Step 5: Deploying website files...${NC}"
    
    # Create a temporary directory for deployment
    temp_dir="temp_deploy_$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$temp_dir"
    
    # Copy all website files to temp directory
    echo -e "  ${CYAN}Preparing files for deployment...${NC}"
    cp *.html "$temp_dir/" 2>/dev/null || true
    cp *.txt "$temp_dir/" 2>/dev/null || true
    cp -r assets "$temp_dir/" 2>/dev/null || true
    cp -r imgs "$temp_dir/" 2>/dev/null || true
    cp -r dac-sac "$temp_dir/" 2>/dev/null || true
    cp -r faq "$temp_dir/" 2>/dev/null || true
    cp -r huong-dan "$temp_dir/" 2>/dev/null || true
    cp -r su-kien "$temp_dir/" 2>/dev/null || true
    cp -r tin-tuc "$temp_dir/" 2>/dev/null || true
    cp -r scripts "$temp_dir/" 2>/dev/null || true
    
    echo -e "  ${GREEN}✓ Files prepared in $temp_dir${NC}"
    
    # Upload files to VPS
    if scp_files "$temp_dir/*" "$VPS_PATH/" "Uploading website files"; then
        echo -e "  ${GREEN}✓ Website files uploaded successfully${NC}"
    else
        echo -e "  ${RED}✗ Failed to upload website files${NC}"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    # Set proper permissions
    ssh_command "sudo chown -R www-data:www-data $VPS_PATH" "Setting web server permissions"
    ssh_command "sudo chmod -R 755 $VPS_PATH" "Setting file permissions"
    
    # Clean up temporary directory
    rm -rf "$temp_dir"
    echo -e "  ${GREEN}✓ Temporary files cleaned up${NC}"
    
    # Step 6: Configure web server (optional)
    echo -e "${MAGENTA}Step 6: Web server configuration...${NC}"
    echo -e "  ${YELLOW}Note: You may need to configure your web server (Apache/Nginx) to serve files from $VPS_PATH${NC}"
    echo -e "  ${YELLOW}Example Nginx configuration:${NC}"
    echo -e "    ${YELLOW}server {${NC}"
    echo -e "        ${YELLOW}listen 80;${NC}"
    echo -e "        ${YELLOW}server_name tamquocchimenh.com www.tamquocchimenh.com;${NC}"
    echo -e "        ${YELLOW}root $VPS_PATH;${NC}"
    echo -e "        ${YELLOW}index index.html;${NC}"
    echo -e "    ${YELLOW}}${NC}"
    
    # Step 7: Test deployment
    echo -e "${MAGENTA}Step 7: Testing deployment...${NC}"
    if ssh_command "ls -la $VPS_PATH" "Listing deployed files"; then
        echo -e "  ${GREEN}✓ Deployment verification successful${NC}"
    fi
    
    # Summary
    echo ""
    echo -e "${GREEN}=== Deployment Summary ===${NC}"
    echo -e "${GREEN}✓ Website deployed to: $VPS_USER@$VPS_IP:$VPS_PATH${NC}"
    if [ "$SKIP_SSH_KEY" = false ]; then
        echo -e "${GREEN}✓ SSH key added to authorized_keys${NC}"
    fi
    echo -e "${GREEN}✓ Backup created at: $backup_path${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo -e "${YELLOW}1. Configure your web server to serve files from $VPS_PATH${NC}"
    echo -e "${YELLOW}2. Set up domain DNS to point to $VPS_IP${NC}"
    echo -e "${YELLOW}3. Test the website at http://$VPS_IP${NC}"
    echo -e "${YELLOW}4. Consider setting up SSL certificate for HTTPS${NC}"
    echo ""
    echo -e "${GREEN}Deployment completed successfully! 🎉${NC}"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-ssh-key)
            SKIP_SSH_KEY=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --skip-ssh-key    Skip adding SSH key to authorized_keys"
            echo "  --dry-run         Show what would be done without executing"
            echo "  --help            Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Run main function
main
