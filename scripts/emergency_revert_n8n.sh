#!/bin/bash

# ============================================================================
# EMERGENCY N8N CONFIGURATION REVERT SCRIPT
# ============================================================================
# Purpose: Revert n8n configuration changes and fix redirect loops
# Issue: Too many redirects preventing site access
# Solution: Restore previous config and create working nginx configuration
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
LOG_FILE="/var/log/n8n_revert.log"

# Logging functions
log() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"; }
info() { echo -e "${CYAN}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }

echo "🚨 EMERGENCY N8N CONFIGURATION REVERT"
echo "====================================="

# ============================================================================
# IMMEDIATE FIXES FOR REDIRECT LOOPS
# ============================================================================

fix_nginx_redirects() {
    log "🔧 FIXING NGINX REDIRECT LOOPS"
    
    # Stop nginx to prevent further issues
    systemctl stop nginx 2>/dev/null || true
    
    # Remove the problematic n8n nginx config
    if [ -f "/etc/nginx/sites-enabled/n8n" ]; then
        log "🗑️ Removing problematic nginx config..."
        rm -f /etc/nginx/sites-enabled/n8n
        success "Removed /etc/nginx/sites-enabled/n8n"
    fi
    
    if [ -f "/etc/nginx/sites-available/n8n" ]; then
        log "🗑️ Removing nginx config from sites-available..."
        rm -f /etc/nginx/sites-available/n8n
        success "Removed /etc/nginx/sites-available/n8n"
    fi
    
    # Create a simple working nginx configuration
    log "📝 Creating simple working nginx configuration..."
    
    cat > /etc/nginx/sites-available/n8n << 'EOF'
server {
    listen 80;
    server_name n8n.websolutionsserver.net;
    
    # File upload size
    client_max_body_size 100M;
    
    # Simple proxy to n8n without SSL redirects
    location / {
        proxy_pass http://127.0.0.1:5678;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
        proxy_connect_timeout 86400;
    }
}
EOF
    
    # Enable the simple config
    ln -sf /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/n8n
    success "Created simple nginx configuration"
}

restore_from_backup() {
    log "💾 LOOKING FOR CONFIGURATION BACKUPS"
    
    # Find the most recent backup directory
    local backup_dir=$(find /root -name "n8n_config_backup_*" -type d 2>/dev/null | sort -r | head -1)
    
    if [ -n "$backup_dir" ] && [ -d "$backup_dir" ]; then
        log "📁 Found backup directory: $backup_dir"
        
        # Restore .n8n directory if backup exists
        if [ -d "$backup_dir/.n8n" ]; then
            log "🔄 Restoring .n8n directory from backup..."
            rm -rf /root/.n8n
            cp -r "$backup_dir/.n8n" /root/
            chown -R root:root /root/.n8n
            success ".n8n directory restored from backup"
        fi
        
        # Restore .env file if backup exists
        if [ -f "$backup_dir/.env" ]; then
            log "🔄 Restoring .env file from backup..."
            cp "$backup_dir/.env" /root/
            chmod 600 /root/.env
            success ".env file restored from backup"
        fi
        
        # Restore systemd service if backup exists
        if [ -f "$backup_dir/n8n.service" ]; then
            log "🔄 Restoring n8n systemd service from backup..."
            cp "$backup_dir/n8n.service" /etc/systemd/system/
            systemctl daemon-reload
            success "n8n systemd service restored from backup"
        fi
        
    else
        warning "No backup directory found, creating minimal configuration..."
        create_minimal_config
    fi
}

create_minimal_config() {
    log "⚙️ CREATING MINIMAL N8N CONFIGURATION"
    
    # Create minimal .env file
    cat > /root/.env << 'EOF'
# Minimal N8N Configuration
N8N_HOST=0.0.0.0
N8N_PORT=5678
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=n8n_1752790771
EOF
    
    chmod 600 /root/.env
    success "Minimal .env file created"
    
    # Create minimal n8n config
    mkdir -p /root/.n8n
    
    cat > /root/.n8n/config.json << 'EOF'
{
  "database": {
    "type": "sqlite",
    "sqlite": {
      "database": "/root/.n8n/database.sqlite"
    }
  },
  "host": "0.0.0.0",
  "port": 5678,
  "security": {
    "basicAuth": {
      "active": true,
      "user": "admin",
      "password": "n8n_1752790771"
    }
  }
}
EOF
    
    chown -R root:root /root/.n8n
    chmod 600 /root/.n8n/config.json
    success "Minimal n8n config created"
    
    # Create minimal systemd service
    cat > /etc/systemd/system/n8n.service << 'EOF'
[Unit]
Description=n8n - Workflow Automation Tool
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/n8n start
Restart=always
RestartSec=10
EnvironmentFile=/root/.env
WorkingDirectory=/root

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    success "Minimal n8n systemd service created"
}

# ============================================================================
# SERVICE RESTART AND VERIFICATION
# ============================================================================

restart_services_safely() {
    log "🔄 RESTARTING SERVICES SAFELY"
    
    # Test nginx configuration first
    log "🧪 Testing nginx configuration..."
    if nginx -t; then
        success "✅ Nginx configuration is valid"
        
        # Start nginx
        systemctl start nginx
        success "✅ Nginx started successfully"
    else
        error "❌ Nginx configuration still has errors"
        
        # Create emergency nginx config
        log "🚨 Creating emergency nginx configuration..."
        
        cat > /etc/nginx/sites-available/default << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    server_name _;
    
    location / {
        proxy_pass http://127.0.0.1:5678;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
EOF
        
        # Remove all other sites
        rm -f /etc/nginx/sites-enabled/*
        ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
        
        if nginx -t; then
            systemctl start nginx
            success "✅ Emergency nginx configuration working"
        else
            error "❌ Even emergency nginx config failed"
            nginx -t
        fi
    fi
    
    # Restart n8n service
    log "🔄 Restarting n8n service..."
    systemctl stop n8n 2>/dev/null || true
    sleep 3
    
    systemctl start n8n
    
    # Wait for n8n to start
    local attempts=0
    while [ $attempts -lt 30 ]; do
        if systemctl is-active --quiet n8n; then
            success "✅ N8N service started successfully"
            break
        fi
        sleep 2
        attempts=$((attempts + 1))
    done
    
    if [ $attempts -eq 30 ]; then
        error "❌ N8N service failed to start"
        systemctl status n8n --no-pager -l
        
        # Try manual start
        log "🔧 Attempting manual n8n start..."
        pkill -f n8n 2>/dev/null || true
        sleep 2
        cd /root && nohup n8n start > /var/log/n8n_manual.log 2>&1 &
        sleep 5
        
        if pgrep -f "n8n start" > /dev/null; then
            success "✅ N8N started manually"
        else
            error "❌ Manual n8n start also failed"
        fi
    fi
}

verify_site_access() {
    log "✅ VERIFYING SITE ACCESS"
    
    # Check if services are running
    log "📊 Service status:"
    if systemctl is-active --quiet nginx; then
        success "✅ Nginx is running"
    else
        error "❌ Nginx is not running"
    fi
    
    if systemctl is-active --quiet n8n || pgrep -f "n8n start" > /dev/null; then
        success "✅ N8N is running"
    else
        error "❌ N8N is not running"
    fi
    
    # Check ports
    log "🔌 Port status:"
    if netstat -tlnp | grep -q ":80.*nginx"; then
        success "✅ Nginx listening on port 80"
    else
        warning "⚠️ Nginx may not be listening on port 80"
    fi
    
    if netstat -tlnp | grep -q ":$N8N_PORT"; then
        success "✅ N8N listening on port $N8N_PORT"
    else
        warning "⚠️ N8N may not be listening on port $N8N_PORT"
    fi
    
    # Test internal connectivity
    log "🔍 Testing connectivity..."
    
    # Test n8n directly
    if curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:$N8N_PORT | grep -q "200\|401"; then
        success "✅ N8N responding on internal port"
    else
        warning "⚠️ N8N may not be responding on internal port"
    fi
    
    # Test through nginx
    if curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:80 | grep -q "200\|401"; then
        success "✅ Site accessible through nginx"
    else
        warning "⚠️ Site may not be accessible through nginx"
    fi
}

show_access_info() {
    log "🌐 SITE ACCESS INFORMATION"
    
    echo ""
    echo "============================================"
    echo "🚨 EMERGENCY REVERT COMPLETED"
    echo "============================================"
    echo ""
    echo "🌐 ACCESS YOUR SITE:"
    echo "   🔗 HTTP: http://$PUBLIC_DOMAIN"
    echo "   🔗 Direct IP: http://$(hostname -I | awk '{print $1}')"
    echo "   🔗 Local: http://127.0.0.1:$N8N_PORT"
    echo ""
    echo "🔐 LOGIN CREDENTIALS:"
    echo "   👤 Username: admin"
    echo "   🔑 Password: n8n_1752790771"
    echo ""
    echo "⚠️ CURRENT STATUS:"
    echo "   📡 Protocol: HTTP only (no HTTPS redirects)"
    echo "   🔧 Configuration: Minimal/Basic"
    echo "   🌐 URLs: May show localhost in webhooks (but site accessible)"
    echo ""
    echo "🔍 TROUBLESHOOTING:"
    echo "   📊 Check services: systemctl status nginx n8n"
    echo "   📜 Check logs: journalctl -u n8n -f"
    echo "   🧪 Test direct: curl http://127.0.0.1:$N8N_PORT"
    echo ""
    echo "✅ Your site should now be accessible without redirect loops!"
    echo "============================================"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    log "🚨 EMERGENCY N8N REVERT STARTED"
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root (use sudo)"
        exit 1
    fi
    
    # Create log file
    touch "$LOG_FILE"
    
    # Execute revert steps
    fix_nginx_redirects
    restore_from_backup
    restart_services_safely
    verify_site_access
    show_access_info
    
    success "🎉 EMERGENCY REVERT COMPLETED"
    log "📜 Full log available at: $LOG_FILE"
}

# Run main function
main "$@"

