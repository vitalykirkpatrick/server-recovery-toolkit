#!/bin/bash

# ============================================================================
# FIX NGINX SSL CERTIFICATE ERROR
# ============================================================================
# Purpose: Fix nginx SSL certificate error and configure HTTP-only access
# Issue: nginx trying to load non-existent SSL certificates
# ============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔧 FIXING NGINX SSL CERTIFICATE ERROR${NC}"
echo "====================================="
echo ""

# Function to display status
log() { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

PUBLIC_DOMAIN="n8n.websolutionsserver.net"

# ============================================================================
# STEP 1: BACKUP CURRENT NGINX CONFIGURATION
# ============================================================================

backup_nginx_config() {
    log "💾 BACKING UP NGINX CONFIGURATION"
    
    local backup_dir="/root/nginx_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Backup nginx configurations
    cp -r /etc/nginx/sites-available "$backup_dir/" 2>/dev/null || true
    cp -r /etc/nginx/sites-enabled "$backup_dir/" 2>/dev/null || true
    cp /etc/nginx/nginx.conf "$backup_dir/" 2>/dev/null || true
    
    success "Nginx configuration backed up to: $backup_dir"
}

# ============================================================================
# STEP 2: REMOVE PROBLEMATIC SSL CONFIGURATION
# ============================================================================

remove_ssl_config() {
    log "🗑️ REMOVING PROBLEMATIC SSL CONFIGURATION"
    
    # Remove any sites that might have SSL configuration
    rm -f /etc/nginx/sites-enabled/n8n 2>/dev/null || true
    rm -f /etc/nginx/sites-available/n8n 2>/dev/null || true
    rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true
    
    success "Problematic SSL configurations removed"
}

# ============================================================================
# STEP 3: CREATE HTTP-ONLY NGINX CONFIGURATION
# ============================================================================

create_http_config() {
    log "📝 CREATING HTTP-ONLY NGINX CONFIGURATION"
    
    # Create simple HTTP-only configuration
    cat > /etc/nginx/sites-available/n8n << EOF
server {
    listen 80;
    server_name $PUBLIC_DOMAIN;
    
    # Increase client max body size for file uploads
    client_max_body_size 100M;
    
    # Main location block
    location / {
        proxy_pass http://127.0.0.1:5678;
        proxy_http_version 1.1;
        
        # WebSocket support
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_cache_bypass \$http_upgrade;
        
        # Standard proxy headers
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        
        # Timeouts
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
        proxy_connect_timeout 86400;
        
        # Disable buffering for real-time updates
        proxy_buffering off;
        proxy_request_buffering off;
    }
    
    # Webhook endpoints
    location /webhook {
        proxy_pass http://127.0.0.1:5678/webhook;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_read_timeout 0;
        proxy_send_timeout 0;
    }
    
    location /webhook-test {
        proxy_pass http://127.0.0.1:5678/webhook-test;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
    }
    
    location /webhook-waiting {
        proxy_pass http://127.0.0.1:5678/webhook-waiting;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
    }
    
    # REST API endpoints
    location /rest {
        proxy_pass http://127.0.0.1:5678/rest;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
    }
}
EOF
    
    success "HTTP-only nginx configuration created"
}

# ============================================================================
# STEP 4: ENABLE THE SITE
# ============================================================================

enable_site() {
    log "🔗 ENABLING N8N SITE"
    
    # Enable the site
    ln -sf /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/n8n
    
    success "N8N site enabled"
}

# ============================================================================
# STEP 5: UPDATE N8N CONFIGURATION FOR HTTP
# ============================================================================

update_n8n_config() {
    log "⚙️ UPDATING N8N CONFIGURATION FOR HTTP"
    
    # Create n8n directory if it doesn't exist
    mkdir -p /root/.n8n
    
    # Create HTTP-only n8n configuration
    cat > /root/.n8n/config.json << EOF
{
  "host": "0.0.0.0",
  "port": 5678,
  "protocol": "http",
  "editorBaseUrl": "http://$PUBLIC_DOMAIN",
  "endpoints": {
    "rest": "http://$PUBLIC_DOMAIN/rest",
    "webhook": "http://$PUBLIC_DOMAIN/webhook",
    "webhookWaiting": "http://$PUBLIC_DOMAIN/webhook-waiting",
    "webhookTest": "http://$PUBLIC_DOMAIN/webhook-test"
  }
}
EOF
    
    # Update environment file
    cat > /root/.env << EOF
NODE_ENV=production
N8N_HOST=0.0.0.0
N8N_PORT=5678
N8N_PROTOCOL=http
N8N_EDITOR_BASE_URL=http://$PUBLIC_DOMAIN
WEBHOOK_URL=http://$PUBLIC_DOMAIN
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=n8n_1752790771
EOF
    
    chmod 600 /root/.env
    
    success "N8N configuration updated for HTTP"
}

# ============================================================================
# STEP 6: TEST NGINX CONFIGURATION
# ============================================================================

test_nginx_config() {
    log "🧪 TESTING NGINX CONFIGURATION"
    
    if nginx -t; then
        success "✅ Nginx configuration test passed"
        return 0
    else
        error "❌ Nginx configuration test failed"
        return 1
    fi
}

# ============================================================================
# STEP 7: RESTART SERVICES
# ============================================================================

restart_services() {
    log "🔄 RESTARTING SERVICES"
    
    # Restart nginx
    systemctl restart nginx
    if systemctl is-active --quiet nginx; then
        success "✅ Nginx restarted successfully"
    else
        error "❌ Nginx failed to restart"
        return 1
    fi
    
    # Restart n8n if it's running
    if systemctl is-active --quiet n8n; then
        systemctl restart n8n
        success "✅ N8N restarted successfully"
    elif command -v pm2 &> /dev/null && pm2 list | grep -q "n8n.*online"; then
        pm2 restart n8n
        success "✅ N8N PM2 process restarted"
    else
        warning "⚠️ N8N service not found - may need manual start"
    fi
}

# ============================================================================
# STEP 8: VERIFY ACCESS
# ============================================================================

verify_access() {
    log "✅ VERIFYING ACCESS"
    
    # Wait for services to start
    sleep 5
    
    # Test local access
    local response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1 2>/dev/null || echo "000")
    
    if [[ "$response" =~ ^(200|401|302)$ ]]; then
        success "✅ HTTP access working (response: $response)"
        return 0
    else
        error "❌ HTTP access not working (response: $response)"
        return 1
    fi
}

# ============================================================================
# SHOW FINAL STATUS
# ============================================================================

show_final_status() {
    log "📊 FINAL STATUS"
    
    echo ""
    echo "============================================"
    echo "🔧 NGINX SSL ERROR FIX COMPLETED"
    echo "============================================"
    echo ""
    
    local response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1 2>/dev/null || echo "000")
    
    if [[ "$response" =~ ^(200|401|302)$ ]]; then
        echo "✅ N8N STATUS: ACCESSIBLE"
        echo "🌐 Access: http://$PUBLIC_DOMAIN"
        echo "🔐 Login: admin / n8n_1752790771"
        echo "📊 HTTP Response: $response"
        echo ""
        echo "🔗 WEBHOOK URLS NOW USE:"
        echo "   📝 Form Trigger: http://$PUBLIC_DOMAIN/webhook-test/..."
        echo "   🔗 Webhooks: http://$PUBLIC_DOMAIN/webhook/..."
        echo "   ⏳ Webhook Waiting: http://$PUBLIC_DOMAIN/webhook-waiting/..."
        echo "   🔄 REST API: http://$PUBLIC_DOMAIN/rest/..."
    else
        echo "❌ N8N STATUS: NOT ACCESSIBLE"
        echo "📊 HTTP Response: $response"
        echo ""
        echo "🔧 TROUBLESHOOTING:"
        echo "   1. Check if n8n is running: systemctl status n8n"
        echo "   2. Check nginx status: systemctl status nginx"
        echo "   3. Check n8n logs: journalctl -u n8n -f"
    fi
    
    echo ""
    echo "📝 NOTE: SSL/HTTPS has been disabled to fix the certificate error"
    echo "🔒 To enable HTTPS later, you'll need to install SSL certificates"
    echo ""
    echo "============================================"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    log "🔧 Starting nginx SSL error fix..."
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root (use sudo)"
        exit 1
    fi
    
    echo -e "${YELLOW}⚠️  This will remove SSL configuration and set up HTTP-only access${NC}"
    echo ""
    read -p "Continue with SSL error fix? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "SSL error fix cancelled."
        exit 0
    fi
    
    # Execute fix steps
    backup_nginx_config
    remove_ssl_config
    create_http_config
    enable_site
    update_n8n_config
    
    if test_nginx_config; then
        restart_services
        verify_access
    else
        error "Nginx configuration test failed - check the configuration"
    fi
    
    show_final_status
    
    success "🎉 NGINX SSL ERROR FIX COMPLETED"
}

# Run main function
main "$@"

