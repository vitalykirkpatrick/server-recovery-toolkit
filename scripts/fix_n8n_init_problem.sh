#!/bin/bash

# ============================================================================
# N8N INIT PROBLEM FIX SCRIPT
# ============================================================================
# Purpose: Fix "Can't connect to n8n" init errors while keeping site accessible
# Issue: n8n panel loads but shows init connection errors
# Solution: Fix API endpoints and WebSocket connections without breaking access
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
LOG_FILE="/var/log/n8n_init_fix.log"

# Logging functions
log() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"; }
info() { echo -e "${CYAN}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }

echo "🔧 FIXING N8N INIT CONNECTION PROBLEMS"
echo "======================================"

# ============================================================================
# DIAGNOSE CURRENT ISSUES
# ============================================================================

diagnose_connection_issues() {
    log "🔍 DIAGNOSING N8N CONNECTION ISSUES"
    
    # Check if n8n is actually running
    if systemctl is-active --quiet n8n; then
        success "✅ N8N systemd service is running"
    else
        warning "⚠️ N8N systemd service is not running"
        systemctl status n8n --no-pager -l | head -10
    fi
    
    # Check if n8n process is running
    if pgrep -f "n8n start" > /dev/null; then
        success "✅ N8N process is running"
        local n8n_pid=$(pgrep -f "n8n start")
        log "   PID: $n8n_pid"
    else
        warning "⚠️ N8N process not found"
    fi
    
    # Check if n8n is listening on the correct port
    if netstat -tlnp | grep -q ":$N8N_PORT"; then
        success "✅ N8N is listening on port $N8N_PORT"
        netstat -tlnp | grep ":$N8N_PORT"
    else
        error "❌ N8N is not listening on port $N8N_PORT"
        log "   Available ports:"
        netstat -tlnp | grep -E ":(5678|3000|8080)" || echo "   No relevant ports found"
    fi
    
    # Test direct n8n connection
    log "🧪 Testing direct n8n connection..."
    local response_code=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:$N8N_PORT 2>/dev/null || echo "000")
    
    if [[ "$response_code" =~ ^(200|401|302)$ ]]; then
        success "✅ N8N responds directly (HTTP $response_code)"
    else
        error "❌ N8N not responding directly (HTTP $response_code)"
    fi
    
    # Test through nginx
    log "🧪 Testing connection through nginx..."
    local nginx_response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:80 2>/dev/null || echo "000")
    
    if [[ "$nginx_response" =~ ^(200|401|302)$ ]]; then
        success "✅ Site responds through nginx (HTTP $nginx_response)"
    else
        error "❌ Site not responding through nginx (HTTP $nginx_response)"
    fi
    
    # Check n8n logs for errors
    log "📜 Checking n8n logs for errors..."
    if journalctl -u n8n --no-pager -l --since "5 minutes ago" | grep -i error; then
        warning "⚠️ Found errors in n8n logs"
    else
        info "ℹ️ No recent errors in n8n logs"
    fi
}

# ============================================================================
# FIX N8N CONFIGURATION
# ============================================================================

fix_n8n_configuration() {
    log "⚙️ FIXING N8N CONFIGURATION FOR PROPER API ACCESS"
    
    # Update .env file with proper settings for API access
    cat > /root/.env << EOF
# N8N Configuration for API Access
N8N_HOST=0.0.0.0
N8N_PORT=$N8N_PORT
N8N_LISTEN_ADDRESS=0.0.0.0
N8N_PROTOCOL=http
N8N_EDITOR_BASE_URL=http://$PUBLIC_DOMAIN

# Authentication
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=n8n_1752790771

# API and Webhook settings
N8N_ENDPOINT_REST=http://$PUBLIC_DOMAIN/rest
N8N_ENDPOINT_WEBHOOK=http://$PUBLIC_DOMAIN/webhook
N8N_ENDPOINT_WEBHOOK_WAITING=http://$PUBLIC_DOMAIN/webhook-waiting
N8N_ENDPOINT_WEBHOOK_TEST=http://$PUBLIC_DOMAIN/webhook-test

# Database settings
N8N_DATABASE_TYPE=sqlite
N8N_DATABASE_SQLITE_DATABASE=/root/.n8n/database.sqlite

# Security settings
N8N_SECURE_COOKIE=false
N8N_COOKIE_SAME_SITE_POLICY=lax

# Disable problematic features that might cause connection issues
N8N_DISABLE_UI=false
N8N_SKIP_WEBHOOK_DEREGISTRATION_SHUTDOWN=true

# Google Drive credentials (preserve existing)
$(grep "GOOGLE_" /root/.env 2>/dev/null || echo "# Google Drive credentials not configured")

# GitHub credentials (preserve existing)
$(grep "GITHUB_" /root/.env 2>/dev/null || echo "# GitHub credentials not configured")
EOF
    
    chmod 600 /root/.env
    success "Updated .env file with proper API settings"
    
    # Update n8n config.json for better API compatibility
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
      "user": "admin",
      "password": "n8n_1752790771"
    }
  },
  "nodes": {
    "exclude": []
  },
  "settings": {
    "timezone": "UTC"
  },
  "userManagement": {
    "disabled": true
  }
}
EOF
    
    chown -R root:root /root/.n8n
    chmod 600 /root/.n8n/config.json
    success "Updated n8n config.json for better API compatibility"
}

# ============================================================================
# FIX NGINX CONFIGURATION
# ============================================================================

fix_nginx_for_api_access() {
    log "📝 UPDATING NGINX CONFIGURATION FOR PROPER API ACCESS"
    
    # Create improved nginx configuration that handles API calls properly
    cat > /etc/nginx/sites-available/n8n << EOF
server {
    listen 80;
    server_name $PUBLIC_DOMAIN;
    
    # File upload size
    client_max_body_size 100M;
    
    # Timeout settings for long-running requests
    proxy_read_timeout 300;
    proxy_connect_timeout 300;
    proxy_send_timeout 300;
    
    # Main n8n application
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
        
        # Important: Don't buffer responses for real-time updates
        proxy_buffering off;
        proxy_request_buffering off;
    }
    
    # REST API endpoints - critical for init data
    location /rest/ {
        proxy_pass http://127.0.0.1:$N8N_PORT/rest/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # API specific settings
        proxy_buffering off;
        proxy_request_buffering off;
        proxy_read_timeout 60;
        proxy_connect_timeout 60;
        proxy_send_timeout 60;
        
        # CORS headers for API access
        add_header Access-Control-Allow-Origin *;
        add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS, PATCH";
        add_header Access-Control-Allow-Headers "Content-Type, Authorization, X-Requested-With";
        
        # Handle preflight requests
        if (\$request_method = 'OPTIONS') {
            add_header Access-Control-Allow-Origin *;
            add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS, PATCH";
            add_header Access-Control-Allow-Headers "Content-Type, Authorization, X-Requested-With";
            add_header Access-Control-Max-Age 1728000;
            add_header Content-Type 'text/plain charset=UTF-8';
            add_header Content-Length 0;
            return 204;
        }
    }
    
    # WebSocket connections for real-time updates
    location /socket.io/ {
        proxy_pass http://127.0.0.1:$N8N_PORT/socket.io/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # WebSocket specific settings
        proxy_buffering off;
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
    }
    
    # Webhook endpoints
    location ~* ^/(webhook|webhook-test|webhook-waiting) {
        proxy_pass http://127.0.0.1:$N8N_PORT;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Webhook specific settings
        proxy_buffering off;
        proxy_request_buffering off;
        proxy_read_timeout 300;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
        
        # CORS headers for webhooks
        add_header Access-Control-Allow-Origin *;
        add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS";
        add_header Access-Control-Allow-Headers "Content-Type, Authorization";
    }
    
    # Static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        proxy_pass http://127.0.0.1:$N8N_PORT;
        proxy_set_header Host \$host;
        proxy_cache_valid 200 1d;
        add_header Cache-Control "public, immutable";
    }
}
EOF
    
    # Test nginx configuration
    if nginx -t; then
        success "✅ Nginx configuration is valid"
        systemctl reload nginx
        success "✅ Nginx reloaded with improved configuration"
    else
        error "❌ Nginx configuration test failed"
        nginx -t
        return 1
    fi
}

# ============================================================================
# RESTART N8N SERVICE
# ============================================================================

restart_n8n_properly() {
    log "🔄 RESTARTING N8N WITH PROPER CONFIGURATION"
    
    # Stop n8n completely
    log "🛑 Stopping n8n service and processes..."
    systemctl stop n8n 2>/dev/null || true
    pkill -f "n8n start" 2>/dev/null || true
    sleep 5
    
    # Verify n8n is stopped
    if pgrep -f "n8n start" > /dev/null; then
        warning "⚠️ N8N process still running, force killing..."
        pkill -9 -f "n8n start" 2>/dev/null || true
        sleep 3
    fi
    
    # Start n8n service
    log "🚀 Starting n8n service..."
    systemctl start n8n
    
    # Wait for n8n to fully start
    local attempts=0
    local max_attempts=60
    
    while [ $attempts -lt $max_attempts ]; do
        if systemctl is-active --quiet n8n; then
            # Check if it's actually responding
            local response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:$N8N_PORT 2>/dev/null || echo "000")
            if [[ "$response" =~ ^(200|401|302)$ ]]; then
                success "✅ N8N service started and responding (HTTP $response)"
                break
            fi
        fi
        
        sleep 2
        attempts=$((attempts + 1))
        
        if [ $((attempts % 10)) -eq 0 ]; then
            log "   Still waiting for n8n to start... ($attempts/$max_attempts)"
        fi
    done
    
    if [ $attempts -eq $max_attempts ]; then
        error "❌ N8N failed to start properly within 2 minutes"
        
        # Show service status and logs
        systemctl status n8n --no-pager -l
        log "Recent n8n logs:"
        journalctl -u n8n --no-pager -l --since "2 minutes ago" | tail -20
        
        return 1
    fi
}

# ============================================================================
# VERIFY FIX
# ============================================================================

verify_init_fix() {
    log "✅ VERIFYING N8N INIT CONNECTION FIX"
    
    # Test direct n8n connection
    log "🧪 Testing direct n8n connection..."
    local direct_response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:$N8N_PORT 2>/dev/null || echo "000")
    
    if [[ "$direct_response" =~ ^(200|401|302)$ ]]; then
        success "✅ Direct n8n connection working (HTTP $direct_response)"
    else
        error "❌ Direct n8n connection failed (HTTP $direct_response)"
    fi
    
    # Test REST API endpoint
    log "🧪 Testing REST API endpoint..."
    local api_response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1/rest/login 2>/dev/null || echo "000")
    
    if [[ "$api_response" =~ ^(200|401|405)$ ]]; then
        success "✅ REST API endpoint accessible (HTTP $api_response)"
    else
        warning "⚠️ REST API endpoint may have issues (HTTP $api_response)"
    fi
    
    # Test through public domain
    log "🧪 Testing through public domain..."
    local public_response=$(curl -s -o /dev/null -w "%{http_code}" http://$PUBLIC_DOMAIN 2>/dev/null || echo "000")
    
    if [[ "$public_response" =~ ^(200|401|302)$ ]]; then
        success "✅ Public domain access working (HTTP $public_response)"
    else
        warning "⚠️ Public domain access may have issues (HTTP $public_response)"
    fi
    
    # Check for common init data endpoints
    log "🧪 Testing init data endpoints..."
    local endpoints=("/rest/settings" "/rest/login" "/rest/owner")
    
    for endpoint in "${endpoints[@]}"; do
        local endpoint_response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1$endpoint 2>/dev/null || echo "000")
        if [[ "$endpoint_response" =~ ^(200|401|403)$ ]]; then
            success "✅ $endpoint accessible (HTTP $endpoint_response)"
        else
            warning "⚠️ $endpoint may have issues (HTTP $endpoint_response)"
        fi
    done
}

show_fix_results() {
    log "📊 N8N INIT CONNECTION FIX RESULTS"
    
    echo ""
    echo "============================================"
    echo "🔧 N8N INIT CONNECTION FIX COMPLETED"
    echo "============================================"
    echo ""
    echo "🌐 ACCESS YOUR N8N:"
    echo "   🔗 URL: http://$PUBLIC_DOMAIN"
    echo "   👤 Username: admin"
    echo "   🔑 Password: n8n_1752790771"
    echo ""
    echo "✅ WHAT WAS FIXED:"
    echo "   🔧 N8N configuration for proper API access"
    echo "   📝 Nginx configuration for REST API endpoints"
    echo "   🌐 WebSocket connections for real-time updates"
    echo "   🔄 Service restart with proper settings"
    echo ""
    echo "🎯 EXPECTED RESULT:"
    echo "   ✅ No more 'Init Problem' errors"
    echo "   ✅ No more 'Can't connect to n8n' messages"
    echo "   ✅ Proper loading of n8n interface"
    echo "   ✅ All API endpoints working correctly"
    echo ""
    echo "🔍 IF YOU STILL SEE INIT ERRORS:"
    echo "   1. Clear browser cache and cookies"
    echo "   2. Try incognito/private browsing mode"
    echo "   3. Wait 1-2 minutes for all services to stabilize"
    echo "   4. Check browser console for specific error messages"
    echo ""
    echo "📊 SERVICE STATUS:"
    systemctl is-active nginx && echo "   ✅ Nginx: Running" || echo "   ❌ Nginx: Not running"
    systemctl is-active n8n && echo "   ✅ N8N: Running" || echo "   ❌ N8N: Not running"
    echo ""
    echo "✅ Your n8n init connection issues should now be resolved!"
    echo "============================================"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    log "🚀 N8N INIT CONNECTION FIX STARTED"
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root (use sudo)"
        exit 1
    fi
    
    # Create log file
    touch "$LOG_FILE"
    
    # Execute fix steps
    diagnose_connection_issues
    fix_n8n_configuration
    fix_nginx_for_api_access
    restart_n8n_properly
    verify_init_fix
    show_fix_results
    
    success "🎉 N8N INIT CONNECTION FIX COMPLETED"
    log "📜 Full log available at: $LOG_FILE"
}

# Run main function
main "$@"

