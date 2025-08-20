#!/bin/bash

# ============================================================================
# SERVER RESTORATION SCRIPT
# ============================================================================
# Purpose: Restore server from minimal or full backups stored remotely
# Supports: Google Drive (minimal) and GitHub (full) backup restoration
# Usage: Run via VNC console when server is completely wiped
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
RESTORE_LOG="/var/log/server_restore.log"
TEMP_DIR="/tmp/restore_$(date +%Y%m%d_%H%M%S)"
BACKUP_TYPE=""
BACKUP_FILE=""

# Logging functions
log() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$RESTORE_LOG"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$RESTORE_LOG"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$RESTORE_LOG"; }
error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$RESTORE_LOG"; }
info() { echo -e "${CYAN}[INFO]${NC} $1" | tee -a "$RESTORE_LOG"; }

# ============================================================================
# GOOGLE DRIVE FUNCTIONS (FOR MINIMAL BACKUPS)
# ============================================================================

setup_google_credentials() {
    log "🔑 Setting up Google Drive credentials..."
    
    echo "Please provide your Google Drive credentials:"
    read -p "Google Client ID: " GOOGLE_CLIENT_ID
    read -p "Google Client Secret: " GOOGLE_CLIENT_SECRET
    read -p "Google Refresh Token: " GOOGLE_REFRESH_TOKEN
    
    # Create .env file
    cat > /root/.env << EOF
GOOGLE_CLIENT_ID="$GOOGLE_CLIENT_ID"
GOOGLE_CLIENT_SECRET="$GOOGLE_CLIENT_SECRET"
GOOGLE_REFRESH_TOKEN="$GOOGLE_REFRESH_TOKEN"
EOF
    
    chmod 600 /root/.env
    success "Google credentials saved to /root/.env"
}

get_google_access_token() {
    log "🔑 Getting Google Drive access token..."
    
    if [ ! -f /root/.env ]; then
        setup_google_credentials
    fi
    
    source /root/.env
    
    TOKEN_RESPONSE=$(curl -s -X POST "https://oauth2.googleapis.com/token" \
        -d client_id="$GOOGLE_CLIENT_ID" \
        -d client_secret="$GOOGLE_CLIENT_SECRET" \
        -d refresh_token="$GOOGLE_REFRESH_TOKEN" \
        -d grant_type=refresh_token)
    
    ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r .access_token)
    
    if [[ "$ACCESS_TOKEN" == "null" || -z "$ACCESS_TOKEN" ]]; then
        error "Failed to get Google Drive access token"
        echo "$TOKEN_RESPONSE"
        exit 1
    fi
    
    success "Google Drive access token obtained"
}

list_google_drive_backups() {
    log "📋 Listing available backups from Google Drive..."
    
    get_google_access_token
    
    # Google Drive folder ID for backups
    DRIVE_FOLDER_ID="1-MX-npKbEj6lsEXjzoRbLmlPUu8O--kI"
    
    # List files in the backup folder
    RESPONSE=$(curl -s -H "Authorization: Bearer $ACCESS_TOKEN" \
        "https://www.googleapis.com/drive/v3/files?q='$DRIVE_FOLDER_ID'+in+parents&fields=files(id,name,modifiedTime,size)")
    
    echo "$RESPONSE" | jq -r '.files[] | select(.name | test("n8n_.*backup.*\\.tar\\.gz")) | "\(.modifiedTime) \(.name) \(.id) \(.size)"' | sort -r > "$TEMP_DIR/google_backups.txt"
    
    if [ -s "$TEMP_DIR/google_backups.txt" ]; then
        log "📋 Available Google Drive backups:"
        cat "$TEMP_DIR/google_backups.txt" | head -10 | nl
    else
        warning "No backups found in Google Drive"
    fi
}

download_from_google_drive() {
    local file_id="$1"
    local file_name="$2"
    local output_path="$3"
    
    log "⬇️ Downloading $file_name from Google Drive..."
    
    curl -L -H "Authorization: Bearer $ACCESS_TOKEN" \
        "https://www.googleapis.com/drive/v3/files/$file_id?alt=media" \
        -o "$output_path"
    
    if [ -f "$output_path" ]; then
        success "Downloaded: $file_name"
        return 0
    else
        error "Failed to download: $file_name"
        return 1
    fi
}

# ============================================================================
# GITHUB FUNCTIONS (FOR FULL BACKUPS)
# ============================================================================

setup_github_credentials() {
    log "🔑 Setting up GitHub credentials..."
    
    echo "Please provide your GitHub credentials:"
    read -p "GitHub Personal Access Token: " GITHUB_PAT
    read -p "GitHub Repository (owner/repo): " GITHUB_REPO
    read -p "GitHub Branch (default: main): " GITHUB_BRANCH
    
    GITHUB_BRANCH=${GITHUB_BRANCH:-main}
    
    # Add to .env file
    cat >> /root/.env << EOF
GITHUB_PAT="$GITHUB_PAT"
GITHUB_REPO="$GITHUB_REPO"
GITHUB_BRANCH="$GITHUB_BRANCH"
USE_GIT_LFS="false"
EOF
    
    success "GitHub credentials saved to /root/.env"
}

list_github_backups() {
    log "📋 Listing available backups from GitHub..."
    
    if [ ! -f /root/.env ]; then
        setup_github_credentials
    fi
    
    source /root/.env
    
    # List repository contents
    RESPONSE=$(curl -s -H "Authorization: token $GITHUB_PAT" \
        "https://api.github.com/repos/$GITHUB_REPO/contents?ref=$GITHUB_BRANCH")
    
    echo "$RESPONSE" | jq -r '.[] | select(.name | test("n8n_backup.*\\.tar\\.gz")) | "\(.name) \(.download_url) \(.size)"' > "$TEMP_DIR/github_backups.txt"
    
    if [ -s "$TEMP_DIR/github_backups.txt" ]; then
        log "📋 Available GitHub backups:"
        cat "$TEMP_DIR/github_backups.txt" | nl
    else
        warning "No backups found in GitHub repository"
    fi
}

download_from_github() {
    local download_url="$1"
    local file_name="$2"
    local output_path="$3"
    
    log "⬇️ Downloading $file_name from GitHub..."
    
    curl -L -H "Authorization: token $GITHUB_PAT" \
        "$download_url" -o "$output_path"
    
    if [ -f "$output_path" ]; then
        success "Downloaded: $file_name"
        return 0
    else
        error "Failed to download: $file_name"
        return 1
    fi
}

# ============================================================================
# SYSTEM PREPARATION FUNCTIONS
# ============================================================================

prepare_system() {
    log "🔧 Preparing system for restoration..."
    
    # Update package lists
    apt-get update
    
    # Install essential packages
    apt-get install -y curl wget jq tar gzip git
    
    # Create temp directory
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    # Create log file
    touch "$RESTORE_LOG"
    
    success "System prepared for restoration"
}

install_base_packages() {
    log "📦 Installing base packages..."
    
    # Essential packages for n8n server
    apt-get install -y \
        nginx \
        postgresql \
        postgresql-contrib \
        nodejs \
        npm \
        redis-server \
        certbot \
        python3-certbot-nginx \
        ufw \
        fail2ban \
        htop \
        nano \
        vim \
        unzip \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        gnupg \
        lsb-release
    
    # Install n8n globally
    npm install -g n8n
    
    success "Base packages installed"
}

# ============================================================================
# BACKUP RESTORATION FUNCTIONS
# ============================================================================

restore_minimal_backup() {
    log "🔄 Restoring from minimal backup..."
    
    # Extract backup
    tar -xzf "$BACKUP_FILE" -C /
    
    # Restore packages from manifest
    if [ -f /root/manual-packages.txt ]; then
        log "📦 Installing manually installed packages..."
        while read -r package; do
            if [ -n "$package" ]; then
                apt-get install -y "$package" || warning "Failed to install: $package"
            fi
        done < /root/manual-packages.txt
    fi
    
    # Restore nginx configuration
    if [ -d /etc/nginx ]; then
        log "🌐 Reloading nginx configuration..."
        nginx -t && systemctl reload nginx || warning "Nginx configuration test failed"
    fi
    
    # Restore network configuration
    if [ -d /etc/netplan ]; then
        log "🌐 Applying network configuration..."
        netplan apply || warning "Netplan apply failed"
    fi
    
    # Restore n8n configuration
    if [ -d /root/.n8n ]; then
        log "🤖 n8n configuration restored"
        chown -R root:root /root/.n8n
    fi
    
    success "Minimal backup restoration completed"
}

restore_full_backup() {
    log "🔄 Restoring from full backup..."
    
    # Extract backup (preserving absolute paths)
    tar -xzf "$BACKUP_FILE" -C /
    
    # Restore systemd services
    if [ -d /etc/systemd/system ]; then
        log "🔧 Reloading systemd services..."
        systemctl daemon-reload
    fi
    
    # Restore nginx configuration
    if [ -d /etc/nginx ]; then
        log "🌐 Testing and reloading nginx..."
        nginx -t && systemctl reload nginx || warning "Nginx configuration test failed"
    fi
    
    # Restore Docker if present
    if [ -d /var/lib/docker ]; then
        log "🐳 Docker data restored"
        systemctl restart docker || warning "Docker restart failed"
    fi
    
    # Restore n8n configuration
    if [ -d /root/.n8n ]; then
        log "🤖 n8n configuration restored"
        chown -R root:root /root/.n8n
    fi
    
    success "Full backup restoration completed"
}

# ============================================================================
# SERVICE CONFIGURATION FUNCTIONS
# ============================================================================

configure_services() {
    log "🔧 Configuring services..."
    
    # Enable and start essential services
    systemctl enable nginx
    systemctl enable postgresql
    systemctl enable redis-server
    
    systemctl start postgresql
    systemctl start redis-server
    systemctl start nginx
    
    # Configure firewall
    ufw --force enable
    ufw allow ssh
    ufw allow 'Nginx Full'
    
    # Start n8n service if configuration exists
    if [ -d /root/.n8n ]; then
        log "🤖 Starting n8n service..."
        
        # Create n8n systemd service
        cat > /etc/systemd/system/n8n.service << 'EOF'
[Unit]
Description=n8n
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/n8n start
Restart=on-failure
Environment=N8N_BASIC_AUTH_ACTIVE=true
Environment=N8N_BASIC_AUTH_USER=admin
Environment=N8N_BASIC_AUTH_PASSWORD=n8n_1752790771
Environment=N8N_HOST=0.0.0.0
Environment=N8N_PORT=5678
Environment=N8N_PROTOCOL=http
WorkingDirectory=/root

[Install]
WantedBy=multi-user.target
EOF
        
        systemctl daemon-reload
        systemctl enable n8n
        systemctl start n8n
    fi
    
    success "Services configured and started"
}

verify_restoration() {
    log "✅ Verifying restoration..."
    
    # Check service status
    log "📊 Service Status:"
    systemctl status nginx --no-pager -l || true
    systemctl status postgresql --no-pager -l || true
    systemctl status n8n --no-pager -l || true
    
    # Check network connectivity
    log "🌐 Network Status:"
    ip addr show | grep inet
    
    # Check disk usage
    log "💾 Disk Usage:"
    df -h
    
    # Check listening ports
    log "🔌 Listening Ports:"
    netstat -tlnp | grep -E ":(22|80|443|5678|5432)"
    
    success "Restoration verification completed"
}

# ============================================================================
# INTERACTIVE MENU FUNCTIONS
# ============================================================================

show_menu() {
    echo ""
    echo "============================================"
    echo "🔄 SERVER RESTORATION SCRIPT"
    echo "============================================"
    echo "1. Restore from Minimal Backup (Google Drive)"
    echo "2. Restore from Full Backup (GitHub)"
    echo "3. List Available Backups"
    echo "4. Setup Credentials Only"
    echo "5. Install Base Packages Only"
    echo "6. Exit"
    echo "============================================"
}

select_backup_from_list() {
    local backup_list_file="$1"
    local backup_type="$2"
    
    if [ ! -s "$backup_list_file" ]; then
        error "No backups available"
        return 1
    fi
    
    echo "Select a backup to restore:"
    cat "$backup_list_file" | nl
    
    read -p "Enter backup number: " backup_num
    
    if [[ "$backup_num" =~ ^[0-9]+$ ]] && [ "$backup_num" -ge 1 ]; then
        local selected_line=$(sed -n "${backup_num}p" "$backup_list_file")
        
        if [ -n "$selected_line" ]; then
            if [ "$backup_type" = "google" ]; then
                # Format: timestamp filename file_id size
                local file_id=$(echo "$selected_line" | awk '{print $3}')
                local file_name=$(echo "$selected_line" | awk '{print $2}')
                BACKUP_FILE="$TEMP_DIR/$file_name"
                download_from_google_drive "$file_id" "$file_name" "$BACKUP_FILE"
            elif [ "$backup_type" = "github" ]; then
                # Format: filename download_url size
                local download_url=$(echo "$selected_line" | awk '{print $2}')
                local file_name=$(echo "$selected_line" | awk '{print $1}')
                BACKUP_FILE="$TEMP_DIR/$file_name"
                download_from_github "$download_url" "$file_name" "$BACKUP_FILE"
            fi
            return 0
        fi
    fi
    
    error "Invalid selection"
    return 1
}

# ============================================================================
# MAIN EXECUTION FUNCTIONS
# ============================================================================

restore_minimal() {
    log "🎯 STARTING MINIMAL BACKUP RESTORATION"
    
    BACKUP_TYPE="minimal"
    
    prepare_system
    install_base_packages
    list_google_drive_backups
    
    if select_backup_from_list "$TEMP_DIR/google_backups.txt" "google"; then
        restore_minimal_backup
        configure_services
        verify_restoration
        success "Minimal backup restoration completed successfully!"
    else
        error "Failed to select or download backup"
        exit 1
    fi
}

restore_full() {
    log "🎯 STARTING FULL BACKUP RESTORATION"
    
    BACKUP_TYPE="full"
    
    prepare_system
    install_base_packages
    list_github_backups
    
    if select_backup_from_list "$TEMP_DIR/github_backups.txt" "github"; then
        restore_full_backup
        configure_services
        verify_restoration
        success "Full backup restoration completed successfully!"
    else
        error "Failed to select or download backup"
        exit 1
    fi
}

list_all_backups() {
    log "📋 LISTING ALL AVAILABLE BACKUPS"
    
    prepare_system
    
    echo ""
    echo "=== GOOGLE DRIVE BACKUPS (MINIMAL) ==="
    list_google_drive_backups
    
    echo ""
    echo "=== GITHUB BACKUPS (FULL) ==="
    list_github_backups
}

setup_credentials() {
    log "🔑 SETTING UP CREDENTIALS"
    
    prepare_system
    
    echo "Choose credential type to setup:"
    echo "1. Google Drive (for minimal backups)"
    echo "2. GitHub (for full backups)"
    echo "3. Both"
    
    read -p "Enter choice (1-3): " cred_choice
    
    case $cred_choice in
        1)
            setup_google_credentials
            ;;
        2)
            setup_github_credentials
            ;;
        3)
            setup_google_credentials
            setup_github_credentials
            ;;
        *)
            error "Invalid choice"
            ;;
    esac
}

# ============================================================================
# MAIN SCRIPT LOGIC
# ============================================================================

main() {
    log "🚀 SERVER RESTORATION SCRIPT STARTED"
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root (use sudo)"
        exit 1
    fi
    
    # Handle command line arguments
    case "${1:-}" in
        --minimal)
            restore_minimal
            ;;
        --full)
            restore_full
            ;;
        --list)
            list_all_backups
            ;;
        --setup-creds)
            setup_credentials
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "OPTIONS:"
            echo "  --minimal       Restore from minimal backup (Google Drive)"
            echo "  --full          Restore from full backup (GitHub)"
            echo "  --list          List all available backups"
            echo "  --setup-creds   Setup credentials only"
            echo "  --help, -h      Show this help message"
            echo ""
            echo "Default: Interactive menu"
            ;;
        *)
            # Interactive menu
            while true; do
                show_menu
                read -p "Enter your choice (1-6): " choice
                
                case $choice in
                    1)
                        restore_minimal
                        break
                        ;;
                    2)
                        restore_full
                        break
                        ;;
                    3)
                        list_all_backups
                        ;;
                    4)
                        setup_credentials
                        ;;
                    5)
                        prepare_system
                        install_base_packages
                        ;;
                    6)
                        log "👋 Exiting..."
                        exit 0
                        ;;
                    *)
                        error "Invalid choice. Please enter 1-6."
                        ;;
                esac
            done
            ;;
    esac
    
    success "🎉 SERVER RESTORATION SCRIPT COMPLETED"
}

# Run main function with all arguments
main "$@"

