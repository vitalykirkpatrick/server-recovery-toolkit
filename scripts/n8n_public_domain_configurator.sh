#!/bin/bash

# ============================================================================
# N8N PUBLIC DOMAIN CONFIGURATOR
# ============================================================================
# Purpose: Ensure n8n is properly configured for public domain access
# Domain: n8n.websolutionsserver.net
# Features: nginx reverse proxy, proper webhook URLs, systemd service
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
N8N_USER="admin"
N8N_PASSWORD="n8n_1752790771"
LOG_FILE="/var/log/n8n_public_domain_config.log"

# Logging functions
log() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"; }
info() { echo -e "${CYAN}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }

echo "🌐 N8N PUBLIC DOMAIN CONFIGURATOR"
echo "================================="
echo "🎯 Domain: $PUBLIC_DOMAIN"
echo "🔧 This will ensure n8n is accessible via your public domain"
echo ""

# ============================================================================
# BACKUP CURRENT CONFIGURATION
# ============================================================================

backup_current_config() {
    log "💾 BACKING UP CURRENT CONFIGURATION"
    
    local backup_dir="/root/n8n_config_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Backup n8n configuration
    if [ -d "/root/.n8n" ]; then
        cp -r /root/.n8n "$backup_dir/"
        success "✅ n8n config backed up"
    fi
    
    # Backup environment file
    if [ -f "/root/.env" ]; then
        cp /root/.env "$backup_dir/"
        success "✅ Environment file backed up"
    fi
    
    # Backup nginx configuration
    if [ -d "/etc/nginx" ]; then
        cp -r /etc/nginx "$backup_dir/nginx_backup"
        success "✅ nginx config backed up"
    fi
    
    # Backup systemd service
    if [ -f "/etc/systemd/system/n8n.service" ]; then
        cp /etc/systemd/system/n8n.service "$backup_dir/"
        success "✅ systemd service backed up"
    fi
    
    log "📂 Backup created: $backup_dir"
}

# ============================================================================
# INSTALL AND CONFIGURE N8N
# ============================================================================

install_and_configure_n8n() {
    log "🔧 INSTALLING AND CONFIGURING N8N"
    
    # Install Node.js if not present
    if ! command -v node &> /dev/null; then
        log "📦 Installing Node.js..."
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        apt-get install -y nodejs
        success "Node.js installed"
    else
        log "✅ Node.js already installed: $(node --version)"
    fi
    
    # Install n8n if not present
    if ! command -v n8n &> /dev/null; then
        log "🔧 Installing n8n..."
        npm install -g n8n
        success "n8n installed"
    else
        log "✅ n8n already installed: $(n8n --version 2>/dev/null || echo 'version unknown')"
    fi
    
    # Create n8n configuration directory
    mkdir -p /root/.n8n
    
    # Create comprehensive n8n configuration
    log "⚙️ Creating n8n configuration..."
    cat > /root/.n8n/config.json << EOF
{
  "host": "0.0.0.0",
  "port": $N8N_PORT,
  "protocol": "http",
  "editorBaseUrl": "http://$PUBLIC_DOMAIN",
  "endpoints": {
    "rest": "http://$PUBLIC_DOMAIN/rest",
    "webhook": "http://$PUBLIC_DOMAIN/webhook",
    "webhookWaiting": "http://$PUBLIC_DOMAIN/webhook-waiting",
    "webhookTest": "http://$PUBLIC_DOMAIN/webhook-test"
  },
  "security": {
    "basicAuth": {
      "active": true,
      "user": "$N8N_USER",
      "password": "$N8N_PASSWORD"
    }
  },
  "userManagement": {
    "disabled": true
  },
  "publicApi": {
    "disabled": false
  }
}
EOF
    
    # Create environment file with public domain configuration
    log "📝 Creating environment configuration..."
    cat > /root/.env << EOF
# N8N Public Domain Configuration
N8N_HOST=0.0.0.0
N8N_PORT=$N8N_PORT
N8N_PROTOCOL=http
N8N_EDITOR_BASE_URL=http://$PUBLIC_DOMAIN
WEBHOOK_URL=http://$PUBLIC_DOMAIN

# Authentication
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=$N8N_USER
N8N_BASIC_AUTH_PASSWORD=$N8N_PASSWORD

# Security
N8N_SECURE_COOKIE=false
N8N_USER_MANAGEMENT_DISABLED=true

# Public API
N8N_PUBLIC_API_DISABLED=false

# Endpoints with public domain
N8N_ENDPOINT_REST=http://$PUBLIC_DOMAIN/rest
N8N_ENDPOINT_WEBHOOK=http://$PUBLIC_DOMAIN/webhook
N8N_ENDPOINT_WEBHOOK_WAITING=http://$PUBLIC_DOMAIN/webhook-waiting
N8N_ENDPOINT_WEBHOOK_TEST=http://$PUBLIC_DOMAIN/webhook-test

# Webhook URL override
N8N_WEBHOOK_URL=http://$PUBLIC_DOMAIN
N8N_EDITOR_BASE_URL=http://$PUBLIC_DOMAIN
EOF
    
    chmod 600 /root/.env
    chown -R root:root /root/.n8n
    success "n8n configuration created"
}

# ============================================================================
# CONFIGURE NGINX REVERSE PROXY
# ============================================================================

configure_nginx_reverse_proxy() {
    log "📝 CONFIGURING NGINX REVERSE PROXY"
    
    # Install nginx if not present
    if ! command -v nginx &> /dev/null; then
        log "📦 Installing nginx..."
        apt-get update -y
        apt-get install -y nginx
        success "nginx installed"
    else
        log "✅ nginx already installed"
    fi
    
    # Remove default site
    rm -f /etc/nginx/sites-enabled/default
    
    # Create n8n site configuration with proper proxy settings
    log "🌐 Creating nginx site configuration..."
    cat > /etc/nginx/sites-available/n8n << EOF
server {
    listen 80;
    server_name $PUBLIC_DOMAIN;
    
    # Increase client max body size for file uploads
    client_max_body_size 100M;
    
    # Main location block for n8n
    location / {
        proxy_pass http://127.0.0.1:$N8N_PORT;
        proxy_http_version 1.1;
        
        # WebSocket support
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        
        # Standard proxy headers
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        
        # Disable proxy caching for dynamic content
        proxy_cache_bypass \$http_upgrade;
        proxy_no_cache \$http_upgrade;
        
        # Timeout settings
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
        proxy_connect_timeout 86400;
        
        # Buffer settings
        proxy_buffering off;
        proxy_request_buffering off;
    }
    
    # Specific webhook endpoints
    location /webhook {
        proxy_pass http://127.0.0.1:$N8N_PORT/webhook;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        
        # No timeout for webhooks
        proxy_read_timeout 0;
        proxy_send_timeout 0;
    }
    
    location /webhook-test {
        proxy_pass http://127.0.0.1:$N8N_PORT/webhook-test;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
    }
    
    location /webhook-waiting {
        proxy_pass http://127.0.0.1:$N8N_PORT/webhook-waiting;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
    }
    
    # REST API endpoints
    location /rest {
        proxy_pass http://127.0.0.1:$N8N_PORT/rest;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
    }
    
    # Health check endpoint
    location /health {
        proxy_pass http://127.0.0.1:$N8N_PORT/health;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
    }
}
EOF
    
    # Enable the site
    ln -sf /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/n8n
    
    # Test nginx configuration
    if nginx -t; then
        success "✅ nginx configuration is valid"
    else
        error "❌ nginx configuration test failed"
        nginx -t
        return 1
    fi
    
    success "nginx reverse proxy configured"
}

# ============================================================================
# CREATE SYSTEMD SERVICE
# ============================================================================

create_systemd_service() {
    log "🔄 CREATING SYSTEMD SERVICE"
    
    # Create n8n systemd service
    cat > /etc/systemd/system/n8n.service << EOF
[Unit]
Description=n8n - Workflow Automation Tool
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
Group=root
ExecStart=$(which n8n) start
Restart=always
RestartSec=10
KillMode=process
TimeoutStopSec=60

# Environment
Environment=NODE_ENV=production
EnvironmentFile=/root/.env

# Working directory
WorkingDirectory=/root

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=n8n

# Security
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/root/.n8n /tmp

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd and enable service
    systemctl daemon-reload
    systemctl enable n8n
    success "systemd service created and enabled"
}

# ============================================================================
# START AND VERIFY SERVICES
# ============================================================================

start_and_verify_services() {
    log "🚀 STARTING AND VERIFYING SERVICES"
    
    # Start nginx
    systemctl start nginx
    if systemctl is-active --quiet nginx; then
        success "✅ nginx started successfully"
    else
        error "❌ nginx failed to start"
        systemctl status nginx --no-pager -l
    fi
    
    # Start n8n
    systemctl start n8n
    
    # Wait for n8n to start
    local attempts=0
    local max_attempts=30
    
    log "⏳ Waiting for n8n to start..."
    while [ $attempts -lt $max_attempts ]; do
        if systemctl is-active --quiet n8n; then
            local response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:$N8N_PORT 2>/dev/null || echo "000")
            
            if [[ "$response" =~ ^(200|401|302)$ ]]; then
                success "✅ n8n started and responding (HTTP $response)"
                break
            fi
        fi
        
        sleep 2
        attempts=$((attempts + 1))
        log "   Waiting for n8n... ($attempts/$max_attempts)"
    done
    
    if [ $attempts -eq $max_attempts ]; then
        error "❌ n8n failed to start within $(($max_attempts * 2)) seconds"
        systemctl status n8n --no-pager -l
        return 1
    fi
}

# ============================================================================
# TEST PUBLIC DOMAIN ACCESS
# ============================================================================

test_public_domain_access() {
    log "🌐 TESTING PUBLIC DOMAIN ACCESS"
    
    # Test local access first
    local local_response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1 2>/dev/null || echo "000")
    if [[ "$local_response" =~ ^(200|401|302)$ ]]; then
        success "✅ Local nginx proxy working (HTTP $local_response)"
    else
        warning "⚠️ Local nginx proxy may have issues (HTTP $local_response)"
    fi
    
    # Test direct n8n access
    local n8n_response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:$N8N_PORT 2>/dev/null || echo "000")
    if [[ "$n8n_response" =~ ^(200|401|302)$ ]]; then
        success "✅ Direct n8n access working (HTTP $n8n_response)"
    else
        warning "⚠️ Direct n8n access may have issues (HTTP $n8n_response)"
    fi
    
    # Test webhook endpoints
    local webhook_response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1/webhook-test/test 2>/dev/null || echo "000")
    if [[ "$webhook_response" =~ ^(404|405)$ ]]; then
        success "✅ Webhook endpoint accessible (HTTP $webhook_response - expected for test URL)"
    else
        info "ℹ️ Webhook endpoint response: HTTP $webhook_response"
    fi
    
    success "Public domain access tests completed"
}

# ============================================================================
# CONFIGURE FIREWALL
# ============================================================================

configure_firewall() {
    log "🔥 CONFIGURING FIREWALL"
    
    # Configure UFW if available
    if command -v ufw &> /dev/null; then
        # Allow HTTP
        ufw allow 80/tcp 2>/dev/null || true
        ufw allow http 2>/dev/null || true
        
        # Allow SSH
        ufw allow 22/tcp 2>/dev/null || true
        ufw allow ssh 2>/dev/null || true
        
        # Don't allow direct n8n port from outside
        ufw deny $N8N_PORT/tcp 2>/dev/null || true
        
        success "UFW firewall configured"
    fi
    
    # Configure iptables if available
    if command -v iptables &> /dev/null; then
        # Allow HTTP
        iptables -I INPUT -p tcp --dport 80 -j ACCEPT 2>/dev/null || true
        
        # Allow SSH
        iptables -I INPUT -p tcp --dport 22 -j ACCEPT 2>/dev/null || true
        
        success "iptables configured"
    fi
}

# ============================================================================
# SHOW CONFIGURATION RESULTS
# ============================================================================

show_configuration_results() {
    log "📊 N8N PUBLIC DOMAIN CONFIGURATION COMPLETED"
    
    echo ""
    echo "============================================"
    echo "🌐 N8N PUBLIC DOMAIN CONFIGURATION COMPLETED"
    echo "============================================"
    echo ""
    echo "🎯 ACCESS YOUR N8N:"
    echo "   🔗 URL: http://$PUBLIC_DOMAIN"
    echo "   👤 Username: $N8N_USER"
    echo "   🔑 Password: $N8N_PASSWORD"
    echo ""
    echo "🔗 WEBHOOK ENDPOINTS:"
    echo "   📡 Webhook: http://$PUBLIC_DOMAIN/webhook/[webhook-id]"
    echo "   🧪 Test: http://$PUBLIC_DOMAIN/webhook-test/[webhook-id]"
    echo "   ⏳ Waiting: http://$PUBLIC_DOMAIN/webhook-waiting/[webhook-id]"
    echo "   📊 REST API: http://$PUBLIC_DOMAIN/rest"
    echo ""
    echo "📊 SERVICE STATUS:"
    systemctl is-active nginx && echo "   ✅ nginx: Running" || echo "   ❌ nginx: Not running"
    systemctl is-active n8n && echo "   ✅ n8n: Running" || echo "   ❌ n8n: Not running"
    echo ""
    echo "🔧 CONFIGURATION FILES:"
    echo "   ⚙️ n8n config: /root/.n8n/config.json"
    echo "   📝 Environment: /root/.env"
    echo "   🌐 nginx site: /etc/nginx/sites-available/n8n"
    echo "   🔄 systemd service: /etc/systemd/system/n8n.service"
    echo ""
    echo "🧪 TESTING:"
    echo "   🌐 Test public access: curl -I http://$PUBLIC_DOMAIN"
    echo "   🔧 Test local access: curl -I http://127.0.0.1"
    echo "   📊 Check n8n logs: journalctl -u n8n -f"
    echo "   📝 Check nginx logs: tail -f /var/log/nginx/access.log"
    echo ""
    echo "🔧 TROUBLESHOOTING:"
    echo "   📊 Service status: systemctl status nginx n8n"
    echo "   📜 n8n logs: journalctl -u n8n -f"
    echo "   📝 nginx test: nginx -t"
    echo "   🔄 Restart services: systemctl restart nginx n8n"
    echo ""
    echo "✅ N8N IS NOW CONFIGURED FOR PUBLIC DOMAIN ACCESS!"
    echo "============================================"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    log "🌐 N8N PUBLIC DOMAIN CONFIGURATION STARTED"
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root (use sudo)"
        exit 1
    fi
    
    # Create log file
    touch "$LOG_FILE"
    
    echo "⚠️  This will configure n8n for public domain access"
    echo "🌐 Domain: $PUBLIC_DOMAIN"
    echo "🔧 This includes nginx reverse proxy and proper webhook URLs"
    echo ""
    read -p "Continue with n8n public domain configuration? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "n8n public domain configuration cancelled."
        exit 0
    fi
    
    # Execute configuration
    backup_current_config
    install_and_configure_n8n
    configure_nginx_reverse_proxy
    create_systemd_service
    configure_firewall
    start_and_verify_services
    test_public_domain_access
    show_configuration_results
    
    success "🎉 N8N PUBLIC DOMAIN CONFIGURATION COMPLETED"
    log "📜 Full log available at: $LOG_FILE"
}

# Run main function
main "$@"

