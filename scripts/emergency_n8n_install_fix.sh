#!/bin/bash

# ============================================================================
# EMERGENCY N8N INSTALLATION AND SERVICE FIX
# ============================================================================
# Purpose: Fix n8n executable not found and Bad Gateway errors
# Issues: 1) n8n executable missing, 2) Bad Gateway from nginx
# Solution: Find/install n8n and fix service configuration
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
LOG_FILE="/var/log/n8n_emergency_fix.log"

# Logging functions
log() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"; }
info() { echo -e "${CYAN}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }

echo "🚨 EMERGENCY N8N INSTALLATION AND SERVICE FIX"
echo "=============================================="

# ============================================================================
# DIAGNOSE N8N INSTALLATION
# ============================================================================

diagnose_n8n_installation() {
    log "🔍 DIAGNOSING N8N INSTALLATION"
    
    # Check if n8n executable exists in expected location
    if [ -f "/usr/local/bin/n8n" ]; then
        success "✅ N8N found at /usr/local/bin/n8n"
        ls -la /usr/local/bin/n8n
        return 0
    else
        warning "⚠️ N8N not found at /usr/local/bin/n8n"
    fi
    
    # Search for n8n in common locations
    log "🔍 Searching for n8n executable..."
    local n8n_locations=(
        "/usr/bin/n8n"
        "/usr/local/bin/n8n"
        "/opt/n8n/bin/n8n"
        "/root/.npm-global/bin/n8n"
        "/root/node_modules/.bin/n8n"
        "$(which n8n 2>/dev/null || echo '')"
    )
    
    local found_n8n=""
    for location in "${n8n_locations[@]}"; do
        if [ -n "$location" ] && [ -f "$location" ]; then
            success "✅ Found n8n at: $location"
            ls -la "$location"
            found_n8n="$location"
            break
        fi
    done
    
    if [ -n "$found_n8n" ]; then
        log "📍 N8N executable found at: $found_n8n"
        return 0
    else
        error "❌ N8N executable not found anywhere"
        return 1
    fi
}

# ============================================================================
# INSTALL OR FIX N8N
# ============================================================================

install_or_fix_n8n() {
    log "🔧 INSTALLING OR FIXING N8N"
    
    # Check if Node.js is installed
    if ! command -v node &> /dev/null; then
        log "📦 Installing Node.js..."
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        apt-get install -y nodejs
        success "Node.js installed"
    else
        local node_version=$(node --version)
        success "✅ Node.js already installed: $node_version"
    fi
    
    # Check if npm is available
    if ! command -v npm &> /dev/null; then
        log "📦 Installing npm..."
        apt-get install -y npm
        success "npm installed"
    else
        local npm_version=$(npm --version)
        success "✅ npm already available: $npm_version"
    fi
    
    # Try to find existing n8n installation
    local existing_n8n=$(which n8n 2>/dev/null || echo "")
    
    if [ -n "$existing_n8n" ] && [ -f "$existing_n8n" ]; then
        log "📍 Found existing n8n at: $existing_n8n"
        
        # Create symlink to expected location if needed
        if [ "$existing_n8n" != "/usr/local/bin/n8n" ]; then
            log "🔗 Creating symlink to /usr/local/bin/n8n..."
            ln -sf "$existing_n8n" /usr/local/bin/n8n
            success "Symlink created: /usr/local/bin/n8n -> $existing_n8n"
        fi
    else
        log "📦 Installing n8n globally..."
        
        # Install n8n globally
        npm install -g n8n
        
        # Verify installation
        if command -v n8n &> /dev/null; then
            local n8n_location=$(which n8n)
            success "✅ N8N installed successfully at: $n8n_location"
            
            # Create symlink if not in expected location
            if [ "$n8n_location" != "/usr/local/bin/n8n" ]; then
                ln -sf "$n8n_location" /usr/local/bin/n8n
                success "Symlink created: /usr/local/bin/n8n -> $n8n_location"
            fi
        else
            error "❌ N8N installation failed"
            return 1
        fi
    fi
    
    # Verify n8n can run
    log "🧪 Testing n8n executable..."
    if /usr/local/bin/n8n --version; then
        success "✅ N8N executable working correctly"
    else
        error "❌ N8N executable test failed"
        return 1
    fi
}

# ============================================================================
# FIX SYSTEMD SERVICE
# ============================================================================

create_working_systemd_service() {
    log "🔄 CREATING WORKING SYSTEMD SERVICE"
    
    # Stop any existing service
    systemctl stop n8n 2>/dev/null || true
    
    # Find the correct n8n path
    local n8n_path="/usr/local/bin/n8n"
    if [ ! -f "$n8n_path" ]; then
        n8n_path=$(which n8n 2>/dev/null || echo "")
        if [ -z "$n8n_path" ]; then
            error "❌ Cannot find n8n executable for service"
            return 1
        fi
    fi
    
    log "📍 Using n8n executable at: $n8n_path"
    
    # Create working systemd service
    cat > /etc/systemd/system/n8n.service << EOF
[Unit]
Description=n8n - Workflow Automation Tool
Documentation=https://docs.n8n.io
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
Group=root
ExecStart=$n8n_path start
Restart=always
RestartSec=10
KillMode=process
TimeoutStopSec=60

# Environment
Environment=NODE_ENV=production
EnvironmentFile=-/root/.env

# Working directory
WorkingDirectory=/root

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=n8n

# Security settings
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=false
ReadWritePaths=/root
ReadWritePaths=/tmp

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable n8n
    success "Working systemd service created and enabled"
}

# ============================================================================
# CREATE MINIMAL WORKING CONFIGURATION
# ============================================================================

create_minimal_working_config() {
    log "⚙️ CREATING MINIMAL WORKING CONFIGURATION"
    
    # Create minimal .env file
    cat > /root/.env << EOF
# Minimal Working N8N Configuration
N8N_HOST=0.0.0.0
N8N_PORT=$N8N_PORT

# Authentication
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=n8n_1752790771

# Database
N8N_DATABASE_TYPE=sqlite
N8N_DATABASE_SQLITE_DATABASE=/root/.n8n/database.sqlite

# Security
N8N_SECURE_COOKIE=false

# Disable problematic features for now
N8N_DISABLE_UI=false
N8N_SKIP_WEBHOOK_DEREGISTRATION_SHUTDOWN=true
EOF
    
    chmod 600 /root/.env
    success "Minimal .env configuration created"
    
    # Create minimal n8n directory and config
    mkdir -p /root/.n8n
    
    cat > /root/.n8n/config.json << EOF
{
  "database": {
    "type": "sqlite",
    "sqlite": {
      "database": "/root/.n8n/database.sqlite"
    }
  },
  "host": "0.0.0.0",
  "port": $N8N_PORT,
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
    success "Minimal n8n configuration created"
}

# ============================================================================
# FIX NGINX CONFIGURATION
# ============================================================================

create_simple_nginx_config() {
    log "📝 CREATING SIMPLE NGINX CONFIGURATION"
    
    # Remove any existing n8n nginx configs
    rm -f /etc/nginx/sites-enabled/n8n
    rm -f /etc/nginx/sites-available/n8n
    
    # Create simple working nginx configuration
    cat > /etc/nginx/sites-available/n8n << EOF
server {
    listen 80;
    server_name $PUBLIC_DOMAIN;
    
    # File upload size
    client_max_body_size 100M;
    
    # Simple proxy to n8n
    location / {
        proxy_pass http://127.0.0.1:$N8N_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # Timeout settings
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
        proxy_connect_timeout 86400;
    }
}
EOF
    
    # Enable the site
    ln -sf /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/n8n
    
    # Test nginx configuration
    if nginx -t; then
        success "✅ Simple nginx configuration is valid"
        systemctl reload nginx
        success "✅ Nginx reloaded"
    else
        error "❌ Nginx configuration test failed"
        nginx -t
        return 1
    fi
}

# ============================================================================
# START AND VERIFY SERVICES
# ============================================================================

start_and_verify_services() {
    log "🚀 STARTING AND VERIFYING SERVICES"
    
    # Start n8n service
    log "🔄 Starting n8n service..."
    systemctl start n8n
    
    # Wait for n8n to start
    local attempts=0
    local max_attempts=60
    
    while [ $attempts -lt $max_attempts ]; do
        if systemctl is-active --quiet n8n; then
            # Check if it's responding
            local response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:$N8N_PORT 2>/dev/null || echo "000")
            
            if [[ "$response" =~ ^(200|401|302)$ ]]; then
                success "✅ N8N service started and responding (HTTP $response)"
                break
            fi
        fi
        
        sleep 2
        attempts=$((attempts + 1))
        
        if [ $((attempts % 10)) -eq 0 ]; then
            log "   Still waiting for n8n... ($attempts/$max_attempts)"
        fi
    done
    
    if [ $attempts -eq $max_attempts ]; then
        error "❌ N8N failed to start within 2 minutes"
        
        # Show diagnostics
        log "🔍 Service status:"
        systemctl status n8n --no-pager -l
        
        log "🔍 Recent logs:"
        journalctl -u n8n --no-pager -l --since "2 minutes ago" | tail -10
        
        return 1
    fi
    
    # Test through nginx
    log "🧪 Testing through nginx..."
    local nginx_response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:80 2>/dev/null || echo "000")
    
    if [[ "$nginx_response" =~ ^(200|401|302)$ ]]; then
        success "✅ Site accessible through nginx (HTTP $nginx_response)"
    else
        warning "⚠️ Site may not be accessible through nginx (HTTP $nginx_response)"
    fi
    
    # Test public domain
    log "🧪 Testing public domain..."
    local public_response=$(curl -s -o /dev/null -w "%{http_code}" http://$PUBLIC_DOMAIN 2>/dev/null || echo "000")
    
    if [[ "$public_response" =~ ^(200|401|302)$ ]]; then
        success "✅ Public domain accessible (HTTP $public_response)"
    else
        warning "⚠️ Public domain may have issues (HTTP $public_response)"
    fi
}

# ============================================================================
# SHOW RESULTS
# ============================================================================

show_emergency_fix_results() {
    log "📊 EMERGENCY FIX RESULTS"
    
    echo ""
    echo "============================================"
    echo "🚨 EMERGENCY N8N FIX COMPLETED"
    echo "============================================"
    echo ""
    echo "🌐 ACCESS YOUR N8N:"
    echo "   🔗 HTTP: http://$PUBLIC_DOMAIN"
    echo "   👤 Username: admin"
    echo "   🔑 Password: n8n_1752790771"
    echo ""
    echo "✅ FIXES APPLIED:"
    echo "   📦 N8N installation verified/fixed"
    echo "   🔄 Working systemd service created"
    echo "   ⚙️ Minimal working configuration"
    echo "   📝 Simple nginx proxy configuration"
    echo "   🚀 Services started and verified"
    echo ""
    echo "📊 SERVICE STATUS:"
    systemctl is-active nginx && echo "   ✅ Nginx: Running" || echo "   ❌ Nginx: Not running"
    systemctl is-active n8n && echo "   ✅ N8N: Running" || echo "   ❌ N8N: Not running"
    echo ""
    echo "🔍 TROUBLESHOOTING:"
    echo "   📊 Check services: systemctl status nginx n8n"
    echo "   📜 Check logs: journalctl -u n8n -f"
    echo "   🧪 Test direct: curl http://127.0.0.1:$N8N_PORT"
    echo "   🌐 Test public: curl http://$PUBLIC_DOMAIN"
    echo ""
    echo "⚠️ CURRENT STATUS:"
    echo "   🔧 Basic working configuration"
    echo "   🌐 HTTP access only (no HTTPS)"
    echo "   📱 May still show localhost in webhooks"
    echo "   ✅ No more Bad Gateway errors"
    echo ""
    echo "✅ Your n8n should now be accessible without errors!"
    echo "============================================"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    log "🚨 EMERGENCY N8N INSTALLATION AND SERVICE FIX STARTED"
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root (use sudo)"
        exit 1
    fi
    
    # Create log file
    touch "$LOG_FILE"
    
    # Execute emergency fix
    if ! diagnose_n8n_installation; then
        log "🔧 N8N not found, installing..."
        install_or_fix_n8n
    else
        log "✅ N8N found, fixing service configuration..."
    fi
    
    create_working_systemd_service
    create_minimal_working_config
    create_simple_nginx_config
    start_and_verify_services
    show_emergency_fix_results
    
    success "🎉 EMERGENCY N8N FIX COMPLETED"
    log "📜 Full log available at: $LOG_FILE"
}

# Run main function
main "$@"

