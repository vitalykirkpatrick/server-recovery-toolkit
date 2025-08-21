#!/bin/bash

# ============================================================================
# FIX NGINX FOR CLOUDFLARE PROXY
# ============================================================================
# Purpose: Configure nginx for Cloudflare proxy with automatic SSL
# Setup: Cloudflare handles SSL, origin server uses HTTP
# ============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}☁️ CONFIGURING NGINX FOR CLOUDFLARE PROXY${NC}"
echo "=========================================="
echo ""

# Function to display status
log() { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

PUBLIC_DOMAIN="n8n.websolutionsserver.net"

# ============================================================================
# STEP 1: BACKUP CURRENT CONFIGURATION
# ============================================================================

backup_config() {
    log "💾 BACKING UP CURRENT CONFIGURATION"
    
    local backup_dir="/root/cloudflare_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Backup nginx configurations
    cp -r /etc/nginx/sites-available "$backup_dir/" 2>/dev/null || true
    cp -r /etc/nginx/sites-enabled "$backup_dir/" 2>/dev/null || true
    cp /etc/nginx/nginx.conf "$backup_dir/" 2>/dev/null || true
    
    # Backup n8n configuration
    cp -r /root/.n8n "$backup_dir/" 2>/dev/null || true
    cp /root/.env "$backup_dir/" 2>/dev/null || true
    
    success "Configuration backed up to: $backup_dir"
}

# ============================================================================
# STEP 2: REMOVE EXISTING CONFIGURATION
# ============================================================================

remove_existing_config() {
    log "🗑️ REMOVING EXISTING CONFIGURATION"
    
    # Remove any existing n8n sites
    rm -f /etc/nginx/sites-enabled/n8n 2>/dev/null || true
    rm -f /etc/nginx/sites-available/n8n 2>/dev/null || true
    rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true
    
    success "Existing configuration removed"
}

# ============================================================================
# STEP 3: CREATE CLOUDFLARE-OPTIMIZED NGINX CONFIGURATION
# ============================================================================

create_cloudflare_config() {
    log "☁️ CREATING CLOUDFLARE-OPTIMIZED NGINX CONFIGURATION"
    
    # Create nginx configuration optimized for Cloudflare
    cat > /etc/nginx/sites-available/n8n << EOF
server {
    listen 80;
    server_name $PUBLIC_DOMAIN;
    
    # Increase client max body size for file uploads
    client_max_body_size 100M;
    
    # Trust Cloudflare IPs for real IP detection
    set_real_ip_from 173.245.48.0/20;
    set_real_ip_from 103.21.244.0/22;
    set_real_ip_from 103.22.200.0/22;
    set_real_ip_from 103.31.4.0/22;
    set_real_ip_from 141.101.64.0/18;
    set_real_ip_from 108.162.192.0/18;
    set_real_ip_from 190.93.240.0/20;
    set_real_ip_from 188.114.96.0/20;
    set_real_ip_from 197.234.240.0/22;
    set_real_ip_from 198.41.128.0/17;
    set_real_ip_from 162.158.0.0/15;
    set_real_ip_from 104.16.0.0/13;
    set_real_ip_from 104.24.0.0/14;
    set_real_ip_from 172.64.0.0/13;
    set_real_ip_from 131.0.72.0/22;
    real_ip_header CF-Connecting-IP;
    
    # Main location block
    location / {
        proxy_pass http://127.0.0.1:5678;
        proxy_http_version 1.1;
        
        # WebSocket support
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_cache_bypass \$http_upgrade;
        
        # Cloudflare-aware headers
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;  # Always HTTPS from user perspective
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header CF-Connecting-IP \$http_cf_connecting_ip;
        proxy_set_header CF-Ray \$http_cf_ray;
        proxy_set_header CF-Visitor \$http_cf_visitor;
        
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
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header CF-Connecting-IP \$http_cf_connecting_ip;
        proxy_read_timeout 0;
        proxy_send_timeout 0;
    }
    
    location /webhook-test {
        proxy_pass http://127.0.0.1:5678/webhook-test;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header CF-Connecting-IP \$http_cf_connecting_ip;
    }
    
    location /webhook-waiting {
        proxy_pass http://127.0.0.1:5678/webhook-waiting;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header CF-Connecting-IP \$http_cf_connecting_ip;
    }
    
    # REST API endpoints
    location /rest {
        proxy_pass http://127.0.0.1:5678/rest;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header CF-Connecting-IP \$http_cf_connecting_ip;
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF
    
    success "Cloudflare-optimized nginx configuration created"
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
# STEP 5: UPDATE N8N CONFIGURATION FOR CLOUDFLARE
# ============================================================================

update_n8n_config() {
    log "⚙️ UPDATING N8N CONFIGURATION FOR CLOUDFLARE"
    
    # Create n8n directory if it doesn't exist
    mkdir -p /root/.n8n
    
    # Create n8n configuration for Cloudflare (HTTPS URLs)
    cat > /root/.n8n/config.json << EOF
{
  "host": "0.0.0.0",
  "port": 5678,
  "protocol": "https",
  "editorBaseUrl": "https://$PUBLIC_DOMAIN",
  "endpoints": {
    "rest": "https://$PUBLIC_DOMAIN/rest",
    "webhook": "https://$PUBLIC_DOMAIN/webhook",
    "webhookWaiting": "https://$PUBLIC_DOMAIN/webhook-waiting",
    "webhookTest": "https://$PUBLIC_DOMAIN/webhook-test"
  }
}
EOF
    
    # Update environment file for Cloudflare
    cat > /root/.env << EOF
NODE_ENV=production
N8N_HOST=0.0.0.0
N8N_PORT=5678
N8N_PROTOCOL=https
N8N_EDITOR_BASE_URL=https://$PUBLIC_DOMAIN
WEBHOOK_URL=https://$PUBLIC_DOMAIN
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=n8n_1752790771
EOF
    
    chmod 600 /root/.env
    
    success "N8N configuration updated for Cloudflare HTTPS"
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
        success "✅ Local HTTP access working (response: $response)"
        return 0
    else
        error "❌ Local HTTP access not working (response: $response)"
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
    echo "☁️ CLOUDFLARE NGINX CONFIGURATION COMPLETED"
    echo "============================================"
    echo ""
    
    local response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1 2>/dev/null || echo "000")
    
    if [[ "$response" =~ ^(200|401|302)$ ]]; then
        echo "✅ N8N STATUS: ACCESSIBLE"
        echo "🌐 Public Access: https://$PUBLIC_DOMAIN"
        echo "🔐 Login: admin / n8n_1752790771"
        echo "📊 Local HTTP Response: $response"
        echo ""
        echo "☁️ CLOUDFLARE SETUP:"
        echo "   🔒 Users connect via HTTPS (Cloudflare SSL)"
        echo "   🌐 Cloudflare proxies to your server via HTTP"
        echo "   🔗 Webhook URLs use HTTPS"
        echo ""
        echo "🔗 WEBHOOK URLS NOW USE:"
        echo "   📝 Form Trigger: https://$PUBLIC_DOMAIN/webhook-test/..."
        echo "   🔗 Webhooks: https://$PUBLIC_DOMAIN/webhook/..."
        echo "   ⏳ Webhook Waiting: https://$PUBLIC_DOMAIN/webhook-waiting/..."
        echo "   🔄 REST API: https://$PUBLIC_DOMAIN/rest/..."
        echo ""
        echo "☁️ CLOUDFLARE FEATURES ENABLED:"
        echo "   🛡️ Real IP detection from Cloudflare"
        echo "   📊 CF-Ray header forwarding"
        echo "   🔍 CF-Connecting-IP header support"
        echo "   🚀 Optimized for Cloudflare proxy"
    else
        echo "❌ N8N STATUS: NOT ACCESSIBLE"
        echo "📊 Local HTTP Response: $response"
        echo ""
        echo "🔧 TROUBLESHOOTING:"
        echo "   1. Check if n8n is running: systemctl status n8n"
        echo "   2. Check nginx status: systemctl status nginx"
        echo "   3. Check n8n logs: journalctl -u n8n -f"
        echo "   4. Verify Cloudflare DNS settings"
    fi
    
    echo ""
    echo "☁️ CLOUDFLARE REQUIREMENTS:"
    echo "   🌐 Domain DNS pointed to Cloudflare"
    echo "   🔒 SSL/TLS mode: Flexible or Full"
    echo "   ☁️ Proxy status: Proxied (orange cloud)"
    echo ""
    echo "============================================"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    log "☁️ Starting Cloudflare nginx configuration..."
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root (use sudo)"
        exit 1
    fi
    
    echo -e "${YELLOW}☁️ This will configure nginx for Cloudflare proxy with automatic SSL${NC}"
    echo -e "${BLUE}🔒 Cloudflare handles SSL, origin server uses HTTP${NC}"
    echo -e "${GREEN}🌐 Webhook URLs will use HTTPS${NC}"
    echo ""
    read -p "Continue with Cloudflare configuration? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cloudflare configuration cancelled."
        exit 0
    fi
    
    # Execute configuration steps
    backup_config
    remove_existing_config
    create_cloudflare_config
    enable_site
    update_n8n_config
    
    if test_nginx_config; then
        restart_services
        verify_access
    else
        error "Nginx configuration test failed - check the configuration"
    fi
    
    show_final_status
    
    success "🎉 CLOUDFLARE NGINX CONFIGURATION COMPLETED"
}

# Run main function
main "$@"

