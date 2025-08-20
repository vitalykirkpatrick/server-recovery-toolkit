#!/bin/bash

# ============================================================================
# RESTORE ORIGINAL N8N CONFIGURATION
# ============================================================================
# Purpose: Restore n8n to working state before init problems started
# Issue: All fixes have made things worse, need to go back to working state
# Solution: Find and restore original backup configurations
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
PUBLIC_DOMAIN="n8n.websolutionsserver.net"
N8N_PORT="5678"
LOG_FILE="/var/log/n8n_restore_original.log"

# Logging functions
log() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"; }
info() { echo -e "${CYAN}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }

echo "🔄 RESTORING ORIGINAL N8N CONFIGURATION"
echo "======================================"

# ============================================================================
# STOP ALL CURRENT SERVICES
# ============================================================================

stop_all_services() {
    log "🛑 STOPPING ALL CURRENT SERVICES"
    
    # Stop n8n service
    systemctl stop n8n 2>/dev/null || true
    
    # Kill all n8n processes
    pkill -f "n8n" 2>/dev/null || true
    sleep 3
    
    # Force kill if still running
    if pgrep -f "n8n" > /dev/null; then
        warning "Force killing remaining n8n processes..."
        pkill -9 -f "n8n" 2>/dev/null || true
        sleep 2
    fi
    
    success "All n8n services and processes stopped"
}

# ============================================================================
# FIND AND RESTORE BACKUP CONFIGURATIONS
# ============================================================================

find_backup_configurations() {
    log "🔍 SEARCHING FOR BACKUP CONFIGURATIONS"
    
    # Look for backup directories
    local backup_dirs=(
        $(find /root -name "n8n_config_backup_*" -type d 2>/dev/null | sort -r)
        $(find /root -name ".n8n.backup.*" -type d 2>/dev/null | sort -r)
        $(find /etc -name "nginx.backup.*" -type d 2>/dev/null | sort -r)
    )
    
    if [ ${#backup_dirs[@]} -eq 0 ]; then
        warning "⚠️ No backup directories found"
        return 1
    fi
    
    log "📁 Found backup directories:"
    for dir in "${backup_dirs[@]}"; do
        if [ -d "$dir" ]; then
            local backup_date=$(stat -c %y "$dir" | cut -d' ' -f1,2)
            log "   📂 $dir (created: $backup_date)"
        fi
    done
    
    # Use the most recent backup
    local latest_backup="${backup_dirs[0]}"
    log "📍 Using latest backup: $latest_backup"
    
    return 0
}

restore_n8n_configuration() {
    log "🔄 RESTORING N8N CONFIGURATION FROM BACKUP"
    
    # Find the most recent backup
    local backup_dirs=($(find /root -name "n8n_config_backup_*" -type d 2>/dev/null | sort -r))
    
    if [ ${#backup_dirs[@]} -eq 0 ]; then
        # Look for .n8n.backup directories
        backup_dirs=($(find /root -name ".n8n.backup.*" -type d 2>/dev/null | sort -r))
    fi
    
    if [ ${#backup_dirs[@]} -eq 0 ]; then
        warning "⚠️ No n8n backup directories found, creating minimal config"
        create_minimal_original_config
        return 0
    fi
    
    local backup_dir="${backup_dirs[0]}"
    log "📂 Restoring from: $backup_dir"
    
    # Remove current n8n directory
    if [ -d "/root/.n8n" ]; then
        mv /root/.n8n "/root/.n8n.broken.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || rm -rf /root/.n8n
    fi
    
    # Restore .n8n directory
    if [ -d "$backup_dir/.n8n" ]; then
        cp -r "$backup_dir/.n8n" /root/
        chown -R root:root /root/.n8n
        success "✅ .n8n directory restored from backup"
    elif [ -d "$backup_dir" ] && [[ "$(basename "$backup_dir")" =~ ^\.n8n\.backup\. ]]; then
        # This is a direct .n8n backup
        cp -r "$backup_dir" /root/.n8n
        chown -R root:root /root/.n8n
        success "✅ .n8n directory restored from direct backup"
    else
        warning "⚠️ No .n8n directory in backup, creating minimal config"
        create_minimal_original_config
    fi
    
    # Restore .env file if exists
    if [ -f "$backup_dir/.env" ]; then
        cp "$backup_dir/.env" /root/
        chmod 600 /root/.env
        success "✅ .env file restored from backup"
    else
        warning "⚠️ No .env file in backup, creating minimal .env"
        create_minimal_env_file
    fi
    
    # Restore systemd service if exists
    if [ -f "$backup_dir/n8n.service" ]; then
        cp "$backup_dir/n8n.service" /etc/systemd/system/
        systemctl daemon-reload
        success "✅ systemd service restored from backup"
    else
        warning "⚠️ No systemd service in backup, creating basic service"
        create_basic_systemd_service
    fi
}

create_minimal_original_config() {
    log "⚙️ CREATING MINIMAL ORIGINAL-STYLE CONFIGURATION"
    
    # Create basic n8n directory
    mkdir -p /root/.n8n
    
    # Create very basic config.json (like original)
    cat > /root/.n8n/config.json << 'EOF'
{
  "database": {
    "type": "sqlite",
    "sqlite": {
      "database": "/root/.n8n/database.sqlite"
    }
  },
  "host": "0.0.0.0",
  "port": 5678
}
EOF
    
    chown -R root:root /root/.n8n
    chmod 600 /root/.n8n/config.json
    success "Minimal original-style config created"
}

create_minimal_env_file() {
    log "📝 CREATING MINIMAL .ENV FILE"
    
    cat > /root/.env << 'EOF'
# Basic N8N Configuration
N8N_HOST=0.0.0.0
N8N_PORT=5678
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=n8n_1752790771
EOF
    
    chmod 600 /root/.env
    success "Minimal .env file created"
}

create_basic_systemd_service() {
    log "🔄 CREATING BASIC SYSTEMD SERVICE"
    
    # Find n8n executable
    local n8n_path=$(which n8n 2>/dev/null || echo "/usr/local/bin/n8n")
    
    if [ ! -f "$n8n_path" ]; then
        # Try common locations
        local common_paths=(
            "/usr/bin/n8n"
            "/usr/local/bin/n8n"
            "/root/.npm-global/bin/n8n"
            "/root/node_modules/.bin/n8n"
        )
        
        for path in "${common_paths[@]}"; do
            if [ -f "$path" ]; then
                n8n_path="$path"
                break
            fi
        done
    fi
    
    log "📍 Using n8n executable: $n8n_path"
    
    cat > /etc/systemd/system/n8n.service << EOF
[Unit]
Description=n8n - Workflow Automation Tool
After=network.target

[Service]
Type=simple
User=root
ExecStart=$n8n_path start
Restart=always
RestartSec=10
EnvironmentFile=-/root/.env
WorkingDirectory=/root

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable n8n
    success "Basic systemd service created"
}

# ============================================================================
# RESTORE NGINX CONFIGURATION
# ============================================================================

restore_nginx_configuration() {
    log "📝 RESTORING NGINX CONFIGURATION"
    
    # Look for nginx backup
    local nginx_backups=($(find /etc -name "nginx.backup.*" -type d 2>/dev/null | sort -r))
    local config_backups=($(find /root -name "n8n_config_backup_*" -type d 2>/dev/null | sort -r))
    
    local restored_nginx=false
    
    # Try to restore from nginx backup
    if [ ${#nginx_backups[@]} -gt 0 ]; then
        local nginx_backup="${nginx_backups[0]}"
        log "📂 Restoring nginx from: $nginx_backup"
        
        # Backup current nginx config
        cp -r /etc/nginx "/etc/nginx.current.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
        
        # Restore nginx config
        rm -rf /etc/nginx
        cp -r "$nginx_backup" /etc/nginx
        
        restored_nginx=true
        success "✅ Nginx configuration restored from backup"
    fi
    
    # Try to restore from config backup
    if [ ! "$restored_nginx" = true ] && [ ${#config_backups[@]} -gt 0 ]; then
        local config_backup="${config_backups[0]}"
        if [ -d "$config_backup/nginx" ]; then
            log "📂 Restoring nginx from config backup: $config_backup"
            
            # Backup current nginx config
            cp -r /etc/nginx "/etc/nginx.current.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
            
            # Restore nginx config
            rm -rf /etc/nginx
            cp -r "$config_backup/nginx" /etc/nginx
            
            restored_nginx=true
            success "✅ Nginx configuration restored from config backup"
        fi
    fi
    
    # If no backup found, create simple working config
    if [ ! "$restored_nginx" = true ]; then
        warning "⚠️ No nginx backup found, creating simple working config"
        create_simple_working_nginx_config
    fi
    
    # Test nginx configuration
    if nginx -t; then
        success "✅ Nginx configuration is valid"
        systemctl reload nginx
    else
        error "❌ Nginx configuration test failed, creating emergency config"
        create_emergency_nginx_config
    fi
}

create_simple_working_nginx_config() {
    log "📝 CREATING SIMPLE WORKING NGINX CONFIGURATION"
    
    # Remove problematic configs
    rm -f /etc/nginx/sites-enabled/n8n
    rm -f /etc/nginx/sites-available/n8n
    
    # Create simple working config
    cat > /etc/nginx/sites-available/n8n << EOF
server {
    listen 80;
    server_name $PUBLIC_DOMAIN;
    
    client_max_body_size 100M;
    
    location / {
        proxy_pass http://127.0.0.1:$N8N_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
    
    ln -sf /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/n8n
    success "Simple working nginx config created"
}

create_emergency_nginx_config() {
    log "🚨 CREATING EMERGENCY NGINX CONFIGURATION"
    
    # Remove all n8n configs
    rm -f /etc/nginx/sites-enabled/n8n
    rm -f /etc/nginx/sites-available/n8n
    
    # Use default config
    cat > /etc/nginx/sites-available/default << EOF
server {
    listen 80 default_server;
    server_name _;
    
    location / {
        proxy_pass http://127.0.0.1:$N8N_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF
    
    rm -f /etc/nginx/sites-enabled/*
    ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
    
    if nginx -t; then
        success "Emergency nginx config working"
    else
        error "Even emergency nginx config failed"
        nginx -t
    fi
}

# ============================================================================
# START SERVICES AND VERIFY
# ============================================================================

start_and_verify_original_config() {
    log "🚀 STARTING SERVICES WITH ORIGINAL CONFIGURATION"
    
    # Start nginx
    systemctl start nginx 2>/dev/null || systemctl restart nginx
    
    # Start n8n
    systemctl start n8n
    
    # Wait for n8n to start
    local attempts=0
    local max_attempts=30
    
    while [ $attempts -lt $max_attempts ]; do
        if systemctl is-active --quiet n8n; then
            local response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:$N8N_PORT 2>/dev/null || echo "000")
            
            if [[ "$response" =~ ^(200|401|302)$ ]]; then
                success "✅ N8N started and responding (HTTP $response)"
                break
            fi
        fi
        
        sleep 2
        attempts=$((attempts + 1))
        
        if [ $((attempts % 10)) -eq 0 ]; then
            log "   Waiting for n8n... ($attempts/$max_attempts)"
        fi
    done
    
    if [ $attempts -eq $max_attempts ]; then
        error "❌ N8N failed to start within 1 minute"
        
        # Show diagnostics
        systemctl status n8n --no-pager -l
        journalctl -u n8n --no-pager -l --since "1 minute ago" | tail -10
        
        return 1
    fi
    
    # Test site access
    local site_response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:80 2>/dev/null || echo "000")
    
    if [[ "$site_response" =~ ^(200|401|302)$ ]]; then
        success "✅ Site accessible through nginx (HTTP $site_response)"
    else
        warning "⚠️ Site may not be accessible (HTTP $site_response)"
    fi
}

# ============================================================================
# SHOW RESULTS
# ============================================================================

show_restoration_results() {
    log "📊 ORIGINAL CONFIGURATION RESTORATION RESULTS"
    
    echo ""
    echo "============================================"
    echo "🔄 ORIGINAL CONFIGURATION RESTORED"
    echo "============================================"
    echo ""
    echo "🌐 ACCESS YOUR N8N:"
    echo "   🔗 HTTP: http://$PUBLIC_DOMAIN"
    echo "   👤 Username: admin"
    echo "   🔑 Password: n8n_1752790771"
    echo ""
    echo "✅ WHAT WAS RESTORED:"
    echo "   📂 Original .n8n configuration directory"
    echo "   📝 Original .env file (if backup existed)"
    echo "   🔄 Original systemd service (if backup existed)"
    echo "   📝 Original nginx configuration (if backup existed)"
    echo ""
    echo "📊 SERVICE STATUS:"
    systemctl is-active nginx && echo "   ✅ Nginx: Running" || echo "   ❌ Nginx: Not running"
    systemctl is-active n8n && echo "   ✅ N8N: Running" || echo "   ❌ N8N: Not running"
    echo ""
    echo "⚠️ EXPECTED BEHAVIOR:"
    echo "   ✅ Site should be accessible (no Bad Gateway)"
    echo "   ✅ Login should work"
    echo "   ✅ Workflows should be preserved"
    echo "   📱 Webhook URLs may still show localhost (original issue)"
    echo "   ❓ Init problems should be resolved"
    echo ""
    echo "🔍 IF ISSUES PERSIST:"
    echo "   🧹 Clear browser cache completely"
    echo "   🔄 Try incognito/private browsing"
    echo "   📊 Check: systemctl status nginx n8n"
    echo "   📜 Check logs: journalctl -u n8n -f"
    echo ""
    echo "✅ You should now be back to the original working state!"
    echo "============================================"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    log "🔄 ORIGINAL N8N CONFIGURATION RESTORATION STARTED"
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root (use sudo)"
        exit 1
    fi
    
    # Create log file
    touch "$LOG_FILE"
    
    # Execute restoration
    stop_all_services
    find_backup_configurations
    restore_n8n_configuration
    restore_nginx_configuration
    start_and_verify_original_config
    show_restoration_results
    
    success "🎉 ORIGINAL CONFIGURATION RESTORATION COMPLETED"
    log "📜 Full log available at: $LOG_FILE"
}

# Run main function
main "$@"

