#!/bin/bash

#=============================================================================
# N8N COMPLETE BACKUP SCRIPT
# Purpose: Backup all n8n workflows, configurations, credentials, and user data
# Features: Database backup, workflow export, configuration backup, GitHub upload
#=============================================================================

# Configuration
BACKUP_DIR="/root/n8n_backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="n8n_complete_backup_$TIMESTAMP"
LOG_FILE="/var/log/n8n_backup.log"
N8N_DIR="/root/.n8n"
GITHUB_REPO="vitalykirkpatrick/server-recovery-toolkit"

# GitHub token from environment or config file
if [ -f "/root/.github_token" ]; then
    GITHUB_TOKEN=$(cat /root/.github_token)
elif [ -n "$GITHUB_TOKEN" ]; then
    # Use environment variable
    GITHUB_TOKEN="$GITHUB_TOKEN"
else
    GITHUB_TOKEN=""
fi

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging function
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

log_success() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - SUCCESS: $1" >> "$LOG_FILE"
    echo -e "${GREEN}✅ SUCCESS:${NC} $1"
}

log_warning() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - WARNING: $1" >> "$LOG_FILE"
    echo -e "${YELLOW}⚠️  WARNING:${NC} $1"
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: $1" >> "$LOG_FILE"
    echo -e "${RED}❌ ERROR:${NC} $1"
}

# Function to check if n8n is running
check_n8n_status() {
    if pm2 list | grep -q "n8n.*online"; then
        return 0
    else
        return 1
    fi
}

# Function to export workflows via n8n CLI
export_workflows() {
    local export_dir="$1"
    
    log_message "Exporting n8n workflows..."
    
    # Create workflows export directory
    mkdir -p "$export_dir/workflows"
    mkdir -p "$export_dir/credentials"
    
    # Export all workflows
    if command -v n8n >/dev/null 2>&1; then
        cd /root
        
        # Export workflows to JSON
        n8n export:workflow --all --output="$export_dir/workflows/" 2>/dev/null || {
            log_warning "n8n CLI export failed, using database backup instead"
            return 1
        }
        
        # Export credentials (encrypted)
        n8n export:credentials --all --output="$export_dir/credentials/" 2>/dev/null || {
            log_warning "Credentials export failed"
        }
        
        log_success "Workflows exported via n8n CLI"
        return 0
    else
        log_warning "n8n CLI not available"
        return 1
    fi
}

# Function to backup n8n database
backup_database() {
    local backup_dir="$1"
    
    log_message "Backing up n8n database..."
    
    if [ -f "$N8N_DIR/database.sqlite" ]; then
        # Stop n8n temporarily for consistent backup
        local n8n_was_running=false
        if check_n8n_status; then
            n8n_was_running=true
            log_message "Stopping n8n for database backup..."
            pm2 stop n8n >/dev/null 2>&1
            sleep 2
        fi
        
        # Copy database
        cp "$N8N_DIR/database.sqlite" "$backup_dir/database.sqlite"
        
        # Create database dump for readability
        if command -v sqlite3 >/dev/null 2>&1; then
            sqlite3 "$N8N_DIR/database.sqlite" .dump > "$backup_dir/database_dump.sql"
            log_success "Database dump created"
        fi
        
        # Restart n8n if it was running
        if [ "$n8n_was_running" = true ]; then
            log_message "Restarting n8n..."
            pm2 start n8n >/dev/null 2>&1
            sleep 3
        fi
        
        log_success "Database backup completed"
        return 0
    else
        log_error "n8n database not found at $N8N_DIR/database.sqlite"
        return 1
    fi
}

# Function to backup configuration files
backup_configurations() {
    local backup_dir="$1"
    
    log_message "Backing up n8n configurations..."
    
    # Create config backup directory
    mkdir -p "$backup_dir/config"
    
    # Backup n8n directory structure
    if [ -d "$N8N_DIR" ]; then
        # Copy entire .n8n directory
        cp -r "$N8N_DIR" "$backup_dir/n8n_directory"
        
        # Copy specific config files
        [ -f "$N8N_DIR/config.json" ] && cp "$N8N_DIR/config.json" "$backup_dir/config/"
        [ -f "$N8N_DIR/config" ] && cp "$N8N_DIR/config" "$backup_dir/config/"
        
        log_success "n8n directory backed up"
    else
        log_error "n8n directory not found at $N8N_DIR"
        return 1
    fi
    
    # Backup environment file
    if [ -f "/root/.env" ]; then
        cp "/root/.env" "$backup_dir/config/n8n.env"
        log_success "Environment file backed up"
    fi
    
    # Backup PM2 ecosystem file
    if [ -f "/root/n8n-ecosystem.json" ]; then
        cp "/root/n8n-ecosystem.json" "$backup_dir/config/"
        log_success "PM2 ecosystem file backed up"
    fi
    
    # Backup nginx configuration
    if [ -f "/etc/nginx/sites-available/n8n" ]; then
        cp "/etc/nginx/sites-available/n8n" "$backup_dir/config/nginx_n8n.conf"
        log_success "nginx configuration backed up"
    fi
    
    return 0
}

# Function to create backup manifest
create_backup_manifest() {
    local backup_dir="$1"
    local manifest_file="$backup_dir/BACKUP_MANIFEST.txt"
    
    log_message "Creating backup manifest..."
    
    cat > "$manifest_file" << EOF
N8N COMPLETE BACKUP MANIFEST
============================
Backup Date: $(date)
Backup Name: $BACKUP_NAME
Server: $(hostname)
n8n Version: $(n8n --version 2>/dev/null || echo "Unknown")
Node.js Version: $(node --version 2>/dev/null || echo "Unknown")

BACKUP CONTENTS:
===============

📁 Database:
- database.sqlite: Complete n8n database
- database_dump.sql: Human-readable database dump

📁 Workflows:
- workflows/: Exported workflow JSON files
- credentials/: Exported credentials (encrypted)

📁 Configuration:
- n8n_directory/: Complete .n8n directory copy
- config/: Individual configuration files
  - config.json: n8n configuration
  - n8n.env: Environment variables
  - n8n-ecosystem.json: PM2 configuration
  - nginx_n8n.conf: nginx configuration

📁 System Info:
- system_info.txt: System information at backup time

RESTORATION INSTRUCTIONS:
========================

1. Install fresh n8n server using setup script
2. Stop n8n: pm2 stop n8n
3. Restore database: cp database.sqlite /root/.n8n/
4. Restore config: cp config/* to appropriate locations
5. Set permissions: chown -R root:root /root/.n8n
6. Start n8n: pm2 start n8n

BACKUP STATISTICS:
=================
Total Files: $(find "$backup_dir" -type f | wc -l)
Total Size: $(du -sh "$backup_dir" | cut -f1)
Workflows Count: $(find "$backup_dir/workflows" -name "*.json" 2>/dev/null | wc -l)
Database Size: $(du -sh "$backup_dir/database.sqlite" 2>/dev/null | cut -f1 || echo "N/A")

EOF

    # Add system information
    cat >> "$manifest_file" << EOF

SYSTEM INFORMATION:
==================
$(uname -a)
$(free -h)
$(df -h /)
$(pm2 list 2>/dev/null || echo "PM2 not available")

EOF

    log_success "Backup manifest created"
}

# Function to upload to GitHub
upload_to_github() {
    local backup_file="$1"
    
    if [ -z "$GITHUB_TOKEN" ]; then
        log_warning "GitHub token not configured, skipping upload"
        log_warning "To enable GitHub upload, set GITHUB_TOKEN environment variable or create /root/.github_token file"
        return 1
    fi
    
    log_message "Uploading backup to GitHub..."
    
    # Create a simple upload script
    cat > /tmp/github_upload.py << 'PYEOF'
import requests
import base64
import json
import sys
import os

def upload_to_github(file_path, github_path, token, repo):
    with open(file_path, 'rb') as f:
        content = f.read()
    
    encoded_content = base64.b64encode(content).decode('utf-8')
    
    url = f"https://api.github.com/repos/{repo}/contents/{github_path}"
    headers = {
        "Authorization": f"token {token}",
        "Accept": "application/vnd.github.v3+json"
    }
    
    # Check if file exists
    response = requests.get(url, headers=headers)
    sha = None
    if response.status_code == 200:
        sha = response.json()["sha"]
    
    data = {
        "message": f"n8n backup {os.path.basename(file_path)}",
        "content": encoded_content,
        "branch": "main"
    }
    
    if sha:
        data["sha"] = sha
    
    response = requests.put(url, headers=headers, data=json.dumps(data))
    return response.status_code in [200, 201]

if __name__ == "__main__":
    file_path = sys.argv[1]
    github_path = sys.argv[2]
    token = sys.argv[3]
    repo = sys.argv[4]
    
    if upload_to_github(file_path, github_path, token, repo):
        print("Upload successful")
        sys.exit(0)
    else:
        print("Upload failed")
        sys.exit(1)
PYEOF

    # Try to upload
    if python3 /tmp/github_upload.py "$backup_file" "backups/n8n/$(basename "$backup_file")" "$GITHUB_TOKEN" "$GITHUB_REPO" 2>/dev/null; then
        log_success "Backup uploaded to GitHub"
        rm -f /tmp/github_upload.py
        return 0
    else
        log_warning "GitHub upload failed"
        rm -f /tmp/github_upload.py
        return 1
    fi
}

# Main backup function
main() {
    echo "💾 N8N COMPLETE BACKUP SCRIPT"
    echo "============================="
    echo "Backup Name: $BACKUP_NAME"
    echo "Timestamp: $(date)"
    echo ""
    
    log_message "Starting n8n complete backup"
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    local current_backup_dir="$BACKUP_DIR/$BACKUP_NAME"
    mkdir -p "$current_backup_dir"
    
    # Check if n8n directory exists
    if [ ! -d "$N8N_DIR" ]; then
        log_error "n8n directory not found at $N8N_DIR"
        exit 1
    fi
    
    # Perform backups
    local backup_success=true
    
    # Backup database
    if ! backup_database "$current_backup_dir"; then
        backup_success=false
    fi
    
    # Export workflows
    export_workflows "$current_backup_dir" || log_warning "Workflow export had issues"
    
    # Backup configurations
    if ! backup_configurations "$current_backup_dir"; then
        backup_success=false
    fi
    
    # Create manifest
    create_backup_manifest "$current_backup_dir"
    
    # Create compressed archive
    log_message "Creating compressed backup archive..."
    cd "$BACKUP_DIR"
    tar -czf "${BACKUP_NAME}.tar.gz" "$BACKUP_NAME"
    
    if [ $? -eq 0 ]; then
        log_success "Backup archive created: ${BACKUP_NAME}.tar.gz"
        
        # Remove uncompressed directory
        rm -rf "$current_backup_dir"
        
        # Upload to GitHub
        upload_to_github "$BACKUP_DIR/${BACKUP_NAME}.tar.gz"
        
    else
        log_error "Failed to create backup archive"
        backup_success=false
    fi
    
    # Cleanup old backups (keep last 10)
    log_message "Cleaning up old backups..."
    cd "$BACKUP_DIR"
    ls -t n8n_complete_backup_*.tar.gz | tail -n +11 | xargs -r rm
    log_success "Old backups cleaned up"
    
    # Final status
    if [ "$backup_success" = true ]; then
        log_success "n8n complete backup completed successfully"
        echo ""
        echo "✅ Backup Location: $BACKUP_DIR/${BACKUP_NAME}.tar.gz"
        echo "📋 Manifest: Check BACKUP_MANIFEST.txt in archive"
        echo "📊 Size: $(du -sh "$BACKUP_DIR/${BACKUP_NAME}.tar.gz" | cut -f1)"
        
        # Show GitHub token setup info if not configured
        if [ -z "$GITHUB_TOKEN" ]; then
            echo ""
            echo "ℹ️  To enable GitHub backup upload:"
            echo "   echo 'your_github_token' > /root/.github_token"
            echo "   or export GITHUB_TOKEN='your_github_token'"
        fi
        
        exit 0
    else
        log_error "n8n backup completed with errors"
        exit 1
    fi
}

# Run main function
main "$@"

