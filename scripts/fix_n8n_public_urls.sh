#!/bin/bash

# ============================================================================
# N8N PUBLIC URL CONFIGURATION FIX
# ============================================================================
# Purpose: Fix n8n localhost URLs to use public domain
# Issue: Form triggers and webhooks showing localhost instead of public URL
# Solution: Configure n8n with proper public URL settings
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
PUBLIC_PROTOCOL="https"
N8N_PORT="5678"
LOG_FILE="/var/log/n8n_url_fix.log"

# Logging functions
log() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"; }
info() { echo -e "${CYAN}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }

echo "🔧 FIXING N8N PUBLIC URL CONFIGURATION"
echo "======================================="

# ============================================================================
# BACKUP CURRENT CONFIGURATION
# ============================================================================

backup_current_config() {
    log "💾 Backing up current n8n configuration..."
    
    local backup_dir="/root/n8n_config_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Backup n8n directory
    if [ -d "/root/.n8n" ]; then
        cp -r /root/.n8n "$backup_dir/"
        success "n8n directory backed up to: $backup_dir/.n8n"
    fi
    
    # Backup environment files
    if [ -f "/root/.env" ]; then
        cp /root/.env "$backup_dir/"
        success ".env file backed up"
    fi
    
    # Backup systemd service file
    if [ -f "/etc/systemd/system/n8n.service" ]; then
        cp /etc/systemd/system/n8n.service "$backup_dir/"
        success "n8n service file backed up"
    fi
    
    # Backup nginx configuration
    if [ -d "/etc/nginx" ]; then
        cp -r /etc/nginx "$backup_dir/"
        success "nginx configuration backed up"
    fi
    
    log "📁 Backup completed: $backup_dir"
}

# ============================================================================
# N8N CONFIGURATION FUNCTIONS
# ============================================================================

configure_n8n_environment() {
    log "🌐 Setting up N8N environment variables..."
    
    # Create or update .env file
    cat > /root/.env << EOF
# N8N Public URL Configuration
N8N_HOST=0.0.0.0
N8N_PORT=$N8N_PORT
N8N_PROTOCOL=$PUBLIC_PROTOCOL
N8N_EDITOR_BASE_URL=$PUBLIC_PROTOCOL://$PUBLIC_DOMAIN
WEBHOOK_URL=$PUBLIC_PROTOCOL://$PUBLIC_DOMAIN

# N8N Endpoints Configuration
N8N_ENDPOINT_REST=$PUBLIC_PROTOCOL://$PUBLIC_DOMAIN/rest
N8N_ENDPOINT_WEBHOOK=$PUBLIC_PROTOCOL://$PUBLIC_DOMAIN/webhook
N8N_ENDPOINT_WEBHOOK_WAITING=$PUBLIC_PROTOCOL://$PUBLIC_DOMAIN/webhook-waiting
N8N_ENDPOINT_WEBHOOK_TEST=$PUBLIC_PROTOCOL://$PUBLIC_DOMAIN/webhook-test

# N8N Authentication
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=n8n_1752790771

# Additional N8N Settings
N8N_SECURE_COOKIE=true
N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true

# Google Drive credentials (if they exist)
$(grep "GOOGLE_" /root/.env 2>/dev/null || echo "# Google Drive credentials not found")

# GitHub credentials (if they exist)
$(grep "GITHUB_" /root/.env 2>/dev/null || echo "# GitHub credentials not found")
EOF
    
    chmod 600 /root/.env
    success "Environment variables configured"
}

create_n8n_config_file() {
    log "⚙️ Creating N8N configuration file..."
    
    # Create n8n config directory
    mkdir -p /root/.n8n
    
    # Create config.json with proper public URLs
    cat > /root/.n8n/config.json << EOF
{
  "database": {
    "type": "sqlite",
    "sqlite": {
      "database": "/root/.n8n/database.sqlite"
    }
  },
  "editorBaseUrl": "$PUBLIC_PROTOCOL://$PUBLIC_DOMAIN",
  "protocol": "$PUBLIC_PROTOCOL",
  "host": "0.0.0.0",
  "port": $N8N_PORT,
  "endpoints": {
    "rest": "$PUBLIC_PROTOCOL://$PUBLIC_DOMAIN/rest",
    "webhook": "$PUBLIC_PROTOCOL://$PUBLIC_DOMAIN/webhook",
    "webhookWaiting": "$PUBLIC_PROTOCOL://$PUBLIC_DOMAIN/webhook-waiting",
    "webhookTest": "$PUBLIC_PROTOCOL://$PUBLIC_DOMAIN/webhook-test"
  },
  "security": {
    "basicAuth": {
      "active": true,
      "user": "admin",
      "password": "n8n_1752790771"
    }
  },
  "nodes": {
    "exclude": []
  },
  "settings": {
    "timezone": "UTC"
  }
}
EOF
    
    chown -R root:root /root/.n8n
    chmod 600 /root/.n8n/config.json
    success "N8N configuration file created"
}

# ============================================================================
# SYSTEMD SERVICE CONFIGURATION
# ============================================================================

update_n8n_service() {
    log "🔄 Updating N8N systemd service..."
    
    # Create or update n8n systemd service
    cat > /etc/systemd/system/n8n.service << EOF
[Unit]
Description=n8n - Workflow Automation Tool
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
Group=root
ExecStart=/usr/local/bin/n8n start
Restart=always
RestartSec=10
Environment=NODE_ENV=production
EnvironmentFile=/root/.env
WorkingDirectory=/root
StandardOutput=journal
StandardError=journal

# Security settings
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=false
ReadWritePaths=/root

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd and enable service
    systemctl daemon-reload
    systemctl enable n8n
    success "N8N systemd service updated"
}

# ============================================================================
# NGINX CONFIGURATION
# ============================================================================

update_nginx_config() {
    log "📝 Updating Nginx configuration for proper proxying..."
    
    # Create nginx site configuration
    cat > /etc/nginx/sites-available/n8n << EOF
server {
    listen 80;
    server_name $PUBLIC_DOMAIN;
    
    # Redirect HTTP to HTTPS
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $PUBLIC_DOMAIN;
    
    # SSL Configuration (assuming certificates exist)
    ssl_certificate /etc/letsencrypt/live/$PUBLIC_DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$PUBLIC_DOMAIN/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # File upload size
    client_max_body_size 100M;
    
    # Proxy settings for n8n
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
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
        proxy_connect_timeout 86400;
    }
    
    # Webhook endpoints with special handling
    location ~* ^/(webhook|webhook-test|webhook-waiting) {
        proxy_pass http://127.0.0.1:$N8N_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_read_timeout 300;
        proxy_send_timeout 300;
        proxy_connect_timeout 300;
        
        # CORS headers for webhooks
        add_header Access-Control-Allow-Origin *;
        add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS";
        add_header Access-Control-Allow-Headers "Content-Type, Authorization";
    }
}
EOF
    
    # Enable the site
    ln -sf /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/n8n
    success "Nginx configuration updated"
}

# ============================================================================
# SERVICE MANAGEMENT
# ============================================================================

restart_services() {
    log "🔄 Restarting services..."
    
    # Test nginx configuration
    if nginx -t; then
        success "Nginx configuration is valid"
        systemctl reload nginx
        success "Nginx reloaded"
    else
        error "Nginx configuration test failed"
        nginx -t
        return 1
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
            success "N8N service started successfully"
            break
        fi
        sleep 2
        attempts=$((attempts + 1))
    done
    
    if [ $attempts -eq 30 ]; then
        error "N8N service failed to start within 60 seconds"
        systemctl status n8n --no-pager -l
        return 1
    fi
}

# ============================================================================
# VERIFICATION FUNCTIONS
# ============================================================================

verify_configuration() {
    log "✅ Verifying N8N configuration..."
    
    # Check service status
    log "📊 Service status:"
    systemctl status n8n --no-pager -l | head -10
    systemctl status nginx --no-pager -l | head -5
    
    # Check if n8n is listening on correct port
    if netstat -tlnp | grep -q ":$N8N_PORT.*n8n"; then
        success "✅ N8N is listening on port $N8N_PORT"
    else
        warning "⚠️ N8N may not be listening on port $N8N_PORT"
        netstat -tlnp | grep ":$N8N_PORT" || true
    fi
    
    # Check nginx is proxying correctly
    if netstat -tlnp | grep -q ":443.*nginx"; then
        success "✅ Nginx is listening on HTTPS port 443"
    else
        warning "⚠️ Nginx may not be listening on HTTPS port 443"
    fi
    
    # Test internal connectivity
    log "🔍 Testing internal connectivity..."
    if curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:$N8N_PORT | grep -q "200\|401"; then
        success "✅ N8N is responding on internal port"
    else
        warning "⚠️ N8N may not be responding on internal port"
    fi
    
    # Show configuration summary
    log "📋 Configuration Summary:"
    log "   🌐 Public URL: $PUBLIC_PROTOCOL://$PUBLIC_DOMAIN"
    log "   🔌 Internal Port: $N8N_PORT"
    log "   📝 Config File: /root/.n8n/config.json"
    log "   🔧 Service File: /etc/systemd/system/n8n.service"
    log "   🌍 Nginx Config: /etc/nginx/sites-enabled/n8n"
}

show_next_steps() {
    log "🎯 NEXT STEPS"
    
    echo ""
    echo "============================================"
    echo "🎉 N8N PUBLIC URL CONFIGURATION COMPLETE!"
    echo "============================================"
    echo ""
    echo "📋 WHAT WAS CONFIGURED:"
    echo "   ✅ N8N environment variables"
    echo "   ✅ N8N configuration file with public URLs"
    echo "   ✅ Systemd service with proper settings"
    echo "   ✅ Nginx proxy configuration"
    echo ""
    echo "🌐 YOUR N8N URLS:"
    echo "   📱 Editor: $PUBLIC_PROTOCOL://$PUBLIC_DOMAIN"
    echo "   🔗 Webhooks: $PUBLIC_PROTOCOL://$PUBLIC_DOMAIN/webhook"
    echo "   🧪 Test Webhooks: $PUBLIC_PROTOCOL://$PUBLIC_DOMAIN/webhook-test"
    echo "   ⏳ Waiting Webhooks: $PUBLIC_PROTOCOL://$PUBLIC_DOMAIN/webhook-waiting"
    echo "   🔧 REST API: $PUBLIC_PROTOCOL://$PUBLIC_DOMAIN/rest"
    echo ""
    echo "🔐 LOGIN CREDENTIALS:"
    echo "   👤 Username: admin"
    echo "   🔑 Password: n8n_1752790771"
    echo ""
    echo "🎯 TO TEST THE FIX:"
    echo "   1. Go to: $PUBLIC_PROTOCOL://$PUBLIC_DOMAIN"
    echo "   2. Login with credentials above"
    echo "   3. Create or edit a Form Trigger workflow"
    echo "   4. Check that URLs now show: $PUBLIC_PROTOCOL://$PUBLIC_DOMAIN/webhook-test/..."
    echo ""
    echo "🔧 TROUBLESHOOTING:"
    echo "   📊 Check services: systemctl status n8n nginx"
    echo "   📜 Check logs: journalctl -u n8n -f"
    echo "   🌐 Test internal: curl http://127.0.0.1:$N8N_PORT"
    echo "   🔍 Check config: cat /root/.n8n/config.json"
    echo ""
    echo "✅ Form Trigger URLs should now show your public domain!"
    echo "============================================"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    log "🚀 N8N PUBLIC URL CONFIGURATION FIX STARTED"
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root (use sudo)"
        exit 1
    fi
    
    # Create log file
    touch "$LOG_FILE"
    
    # Execute configuration steps
    backup_current_config
    configure_n8n_environment
    create_n8n_config_file
    update_n8n_service
    update_nginx_config
    restart_services
    verify_configuration
    show_next_steps
    
    success "🎉 N8N PUBLIC URL CONFIGURATION COMPLETED"
    log "📜 Full log available at: $LOG_FILE"
}

# Run main function
main "$@"

