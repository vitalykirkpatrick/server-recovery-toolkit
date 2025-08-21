#!/bin/bash

#=============================================================================
# N8N COMPLETE RESTORATION SCRIPT
# Purpose: Restore n8n workflows, configurations, credentials, and user data
# Features: Database restore, workflow import, configuration restore
#=============================================================================

# Configuration
BACKUP_DIR="/root/n8n_backups"
LOG_FILE="/var/log/n8n_restore.log"
N8N_DIR="/root/.n8n"

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

# Function to list available backups
list_backups() {
    echo "📋 Available n8n Backups:"
    echo "========================="
    
    if [ -d "$BACKUP_DIR" ]; then
        local backups=($(ls -t "$BACKUP_DIR"/n8n_complete_backup_*.tar.gz 2>/dev/null))
        
        if [ ${#backups[@]} -eq 0 ]; then
            echo "No backups found in $BACKUP_DIR"
            return 1
        fi
        
        for i in "${!backups[@]}"; do
            local backup_file="${backups[$i]}"
            local backup_name=$(basename "$backup_file" .tar.gz)
            local backup_date=$(echo "$backup_name" | sed 's/n8n_complete_backup_//' | sed 's/_/ /' | sed 's/\(.*\)_\(.*\)/\1 \2/')
            local backup_size=$(du -sh "$backup_file" | cut -f1)
            
            echo "$((i+1)). $backup_name"
            echo "   Date: $backup_date"
            echo "   Size: $backup_size"
            echo "   File: $backup_file"
            echo ""
        done
        
        return 0
    else
        echo "Backup directory not found: $BACKUP_DIR"
        return 1
    fi
}

# Function to select backup
select_backup() {
    list_backups
    
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    local backups=($(ls -t "$BACKUP_DIR"/n8n_complete_backup_*.tar.gz 2>/dev/null))
    
    echo "Select backup to restore:"
    read -p "Enter backup number (1-${#backups[@]}): " selection
    
    if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le ${#backups[@]} ]; then
        SELECTED_BACKUP="${backups[$((selection-1))]}"
        log_message "Selected backup: $SELECTED_BACKUP"
        return 0
    else
        log_error "Invalid selection"
        return 1
    fi
}

# Function to extract backup
extract_backup() {
    local backup_file="$1"
    local extract_dir="/tmp/n8n_restore_$(date +%Y%m%d_%H%M%S)"
    
    log_message "Extracting backup: $(basename "$backup_file")"
    
    mkdir -p "$extract_dir"
    
    if tar -xzf "$backup_file" -C "$extract_dir"; then
        # Find the extracted directory
        EXTRACTED_DIR=$(find "$extract_dir" -maxdepth 1 -type d -name "n8n_complete_backup_*" | head -1)
        
        if [ -n "$EXTRACTED_DIR" ]; then
            log_success "Backup extracted to: $EXTRACTED_DIR"
            return 0
        else
            log_error "Could not find extracted backup directory"
            return 1
        fi
    else
        log_error "Failed to extract backup"
        return 1
    fi
}

# Function to stop n8n safely
stop_n8n() {
    log_message "Stopping n8n for restoration..."
    
    if pm2 list | grep -q "n8n.*online"; then
        pm2 stop n8n >/dev/null 2>&1
        sleep 3
        
        if pm2 list | grep -q "n8n.*stopped"; then
            log_success "n8n stopped successfully"
            return 0
        else
            log_warning "n8n may not have stopped properly"
            return 1
        fi
    else
        log_message "n8n is not running"
        return 0
    fi
}

# Function to backup current n8n data
backup_current_data() {
    log_message "Backing up current n8n data..."
    
    local current_backup_dir="/root/n8n_pre_restore_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$current_backup_dir"
    
    if [ -d "$N8N_DIR" ]; then
        cp -r "$N8N_DIR" "$current_backup_dir/"
        log_success "Current data backed up to: $current_backup_dir"
        return 0
    else
        log_message "No existing n8n data to backup"
        return 0
    fi
}

# Function to restore database
restore_database() {
    local extracted_dir="$1"
    
    log_message "Restoring n8n database..."
    
    # Create n8n directory if it doesn't exist
    mkdir -p "$N8N_DIR"
    
    # Restore database
    if [ -f "$extracted_dir/database.sqlite" ]; then
        cp "$extracted_dir/database.sqlite" "$N8N_DIR/"
        log_success "Database restored"
        return 0
    elif [ -f "$extracted_dir/n8n_directory/database.sqlite" ]; then
        cp "$extracted_dir/n8n_directory/database.sqlite" "$N8N_DIR/"
        log_success "Database restored from directory backup"
        return 0
    else
        log_error "Database file not found in backup"
        return 1
    fi
}

# Function to restore configurations
restore_configurations() {
    local extracted_dir="$1"
    
    log_message "Restoring n8n configurations..."
    
    # Restore entire .n8n directory if available
    if [ -d "$extracted_dir/n8n_directory" ]; then
        cp -r "$extracted_dir/n8n_directory"/* "$N8N_DIR/" 2>/dev/null
        log_success "n8n directory restored"
    fi
    
    # Restore individual config files
    if [ -d "$extracted_dir/config" ]; then
        # Restore n8n config
        if [ -f "$extracted_dir/config/config.json" ]; then
            cp "$extracted_dir/config/config.json" "$N8N_DIR/"
            log_success "n8n config.json restored"
        fi
        
        # Restore environment file
        if [ -f "$extracted_dir/config/n8n.env" ]; then
            cp "$extracted_dir/config/n8n.env" "/root/.env"
            log_success "Environment file restored"
        fi
        
        # Restore PM2 ecosystem
        if [ -f "$extracted_dir/config/n8n-ecosystem.json" ]; then
            cp "$extracted_dir/config/n8n-ecosystem.json" "/root/"
            log_success "PM2 ecosystem file restored"
        fi
        
        # Restore nginx config
        if [ -f "$extracted_dir/config/nginx_n8n.conf" ]; then
            cp "$extracted_dir/config/nginx_n8n.conf" "/etc/nginx/sites-available/n8n"
            log_success "nginx configuration restored"
        fi
    fi
    
    return 0
}

# Function to set proper permissions
set_permissions() {
    log_message "Setting proper permissions..."
    
    # Set ownership
    chown -R root:root "$N8N_DIR"
    chown root:root "/root/.env" 2>/dev/null
    chown root:root "/root/n8n-ecosystem.json" 2>/dev/null
    
    # Set permissions
    chmod 700 "$N8N_DIR"
    chmod 600 "/root/.env" 2>/dev/null
    chmod 644 "/root/n8n-ecosystem.json" 2>/dev/null
    
    log_success "Permissions set"
}

# Function to start n8n
start_n8n() {
    log_message "Starting n8n..."
    
    cd /root
    pm2 start n8n >/dev/null 2>&1
    sleep 5
    
    if pm2 list | grep -q "n8n.*online"; then
        log_success "n8n started successfully"
        return 0
    else
        log_error "Failed to start n8n"
        return 1
    fi
}

# Function to verify restoration
verify_restoration() {
    log_message "Verifying restoration..."
    
    # Check if n8n is responding
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        local response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5678 2>/dev/null || echo "000")
        
        if [[ "$response" =~ ^(200|401|302)$ ]]; then
            log_success "n8n is responding (HTTP $response)"
            break
        fi
        
        echo "   Waiting for n8n... ($attempt/$max_attempts)"
        sleep 2
        ((attempt++))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        log_error "n8n is not responding after restoration"
        return 1
    fi
    
    # Check database
    if [ -f "$N8N_DIR/database.sqlite" ]; then
        local db_size=$(du -sh "$N8N_DIR/database.sqlite" | cut -f1)
        log_success "Database file present (Size: $db_size)"
    else
        log_error "Database file missing"
        return 1
    fi
    
    return 0
}

# Function to show restoration summary
show_summary() {
    local extracted_dir="$1"
    
    echo ""
    echo "📊 RESTORATION SUMMARY"
    echo "====================="
    
    # Show manifest if available
    if [ -f "$extracted_dir/BACKUP_MANIFEST.txt" ]; then
        echo "📋 Backup Information:"
        head -20 "$extracted_dir/BACKUP_MANIFEST.txt"
        echo ""
    fi
    
    echo "🔧 Restored Components:"
    [ -f "$N8N_DIR/database.sqlite" ] && echo "✅ Database"
    [ -f "$N8N_DIR/config.json" ] && echo "✅ Configuration"
    [ -f "/root/.env" ] && echo "✅ Environment"
    [ -f "/root/n8n-ecosystem.json" ] && echo "✅ PM2 Config"
    
    echo ""
    echo "🌐 Access Information:"
    echo "URL: https://n8n.websolutionsserver.net"
    echo "Local: http://127.0.0.1:5678"
    
    echo ""
    echo "🛠️ Management Commands:"
    echo "Status: pm2 status"
    echo "Logs: pm2 logs n8n"
    echo "Restart: pm2 restart n8n"
}

# Main restoration function
main() {
    echo "🔄 N8N COMPLETE RESTORATION SCRIPT"
    echo "=================================="
    echo "Timestamp: $(date)"
    echo ""
    
    log_message "Starting n8n restoration"
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root"
        exit 1
    fi
    
    # Select backup to restore
    if [ -n "$1" ]; then
        SELECTED_BACKUP="$1"
        if [ ! -f "$SELECTED_BACKUP" ]; then
            log_error "Backup file not found: $SELECTED_BACKUP"
            exit 1
        fi
    else
        if ! select_backup; then
            exit 1
        fi
    fi
    
    echo ""
    echo "⚠️  WARNING: This will replace your current n8n data!"
    echo "Selected backup: $(basename "$SELECTED_BACKUP")"
    read -p "Continue with restoration? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_message "Restoration cancelled by user"
        exit 0
    fi
    
    # Extract backup
    if ! extract_backup "$SELECTED_BACKUP"; then
        exit 1
    fi
    
    # Stop n8n
    stop_n8n
    
    # Backup current data
    backup_current_data
    
    # Restore components
    local restoration_success=true
    
    if ! restore_database "$EXTRACTED_DIR"; then
        restoration_success=false
    fi
    
    restore_configurations "$EXTRACTED_DIR"
    set_permissions
    
    # Start n8n
    if ! start_n8n; then
        restoration_success=false
    fi
    
    # Verify restoration
    if ! verify_restoration; then
        restoration_success=false
    fi
    
    # Show summary
    show_summary "$EXTRACTED_DIR"
    
    # Cleanup
    rm -rf "$(dirname "$EXTRACTED_DIR")"
    
    # Final status
    if [ "$restoration_success" = true ]; then
        log_success "n8n restoration completed successfully"
        echo ""
        echo "🎉 Your n8n workflows and configurations have been restored!"
        exit 0
    else
        log_error "n8n restoration completed with errors"
        echo ""
        echo "⚠️  Restoration had issues. Check logs: $LOG_FILE"
        exit 1
    fi
}

# Show usage if requested
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "N8N Complete Restoration Script"
    echo "Usage: $0 [backup_file]"
    echo ""
    echo "Options:"
    echo "  backup_file    Path to backup file (optional, will prompt if not provided)"
    echo "  --help, -h     Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Interactive mode"
    echo "  $0 /root/n8n_backups/backup.tar.gz   # Restore specific backup"
    exit 0
fi

# Run main function
main "$@"

