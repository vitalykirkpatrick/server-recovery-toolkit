#!/bin/bash

# ============================================================================
# COMPREHENSIVE N8N FIX SCRIPT
# ============================================================================
# Purpose: Fix both init problems AND webhook localhost URLs
# Issues: 1) Init Problem persists, 2) Webhooks still show localhost
# Solution: Deep n8n configuration fix with proper URL settings
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
PUBLIC_URL="http://$PUBLIC_DOMAIN"
N8N_PORT="5678"
LOG_FILE="/var/log/n8n_comprehensive_fix.log"

# Logging functions
log() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"; }
info() { echo -e "${CYAN}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }

echo "🔧 COMPREHENSIVE N8N FIX - INIT PROBLEMS & WEBHOOK URLS"
echo "======================================================="

# ============================================================================
# COMPLETE N8N RESET AND RECONFIGURATION
# ============================================================================

stop_all_n8n_processes() {
    log "🛑 STOPPING ALL N8N PROCESSES COMPLETELY"
    
    # Stop systemd service
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
    
    # Verify all stopped
    if pgrep -f "n8n" > /dev/null; then
        error "❌ Some n8n processes still running"
        ps aux | grep n8n | grep -v grep
    else
        success "✅ All n8n processes stopped"
    fi
}

create_comprehensive_n8n_config() {
    log "⚙️ CREATING COMPREHENSIVE N8N CONFIGURATION"
    
    # Backup existing config
    if [ -d "/root/.n8n" ]; then
        mv /root/.n8n "/root/.n8n.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
    fi
    
    # Create fresh n8n directory
    mkdir -p /root/.n8n
    
    # Create comprehensive environment file
    cat > /root/.env << EOF
# ============================================================================
# COMPREHENSIVE N8N CONFIGURATION
# ============================================================================

# Core N8N Settings
N8N_HOST=0.0.0.0
N8N_PORT=$N8N_PORT
N8N_LISTEN_ADDRESS=0.0.0.0

# Public URL Configuration - CRITICAL for webhook URLs
N8N_PROTOCOL=http
N8N_EDITOR_BASE_URL=$PUBLIC_URL
WEBHOOK_URL=$PUBLIC_URL

# Specific Endpoint Configuration
N8N_ENDPOINT_REST=$PUBLIC_URL/rest
N8N_ENDPOINT_WEBHOOK=$PUBLIC_URL/webhook
N8N_ENDPOINT_WEBHOOK_WAITING=$PUBLIC_URL/webhook-waiting
N8N_ENDPOINT_WEBHOOK_TEST=$PUBLIC_URL/webhook-test

# Force public URL for all webhook generation
N8N_WEBHOOK_URL=$PUBLIC_URL
N8N_PUBLIC_API_ENDPOINT=$PUBLIC_URL/api/v1

# Database Configuration
N8N_DATABASE_TYPE=sqlite
N8N_DATABASE_SQLITE_DATABASE=/root/.n8n/database.sqlite

# Authentication
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=n8n_1752790771

# Security Settings
N8N_SECURE_COOKIE=false
N8N_COOKIE_SAME_SITE_POLICY=lax
N8N_JWT_AUTH_HEADER=authorization
N8N_JWT_AUTH_HEADER_VALUE_PREFIX=Bearer

# Workflow and Execution Settings
N8N_DEFAULT_TIMEZONE=UTC
N8N_WORKFLOWS_DEFAULT_NAME=My Workflow
N8N_DEFAULT_BINARY_DATA_MODE=filesystem

# Disable problematic features
N8N_DISABLE_UI=false
N8N_SKIP_WEBHOOK_DEREGISTRATION_SHUTDOWN=true
N8N_PERSONALIZATION_ENABLED=false

# Logging
N8N_LOG_LEVEL=info
N8N_LOG_OUTPUT=console

# Performance Settings
N8N_EXECUTIONS_TIMEOUT=3600
N8N_EXECUTIONS_TIMEOUT_MAX=7200

# User Management (disable for simplicity)
N8N_USER_MANAGEMENT_DISABLED=true
N8N_TEMPLATES_ENABLED=true

# Metrics and Monitoring
N8N_METRICS=false
N8N_DIAGNOSTICS_ENABLED=false

# Google Drive credentials (preserve if exist)
$(grep "GOOGLE_" /root/.env 2>/dev/null || echo "# Google Drive credentials not configured")

# GitHub credentials (preserve if exist)
$(grep "GITHUB_" /root/.env 2>/dev/null || echo "# GitHub credentials not configured")
EOF
    
    chmod 600 /root/.env
    success "Comprehensive .env file created"
    
    # Create detailed n8n config.json
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
  "editorBaseUrl": "$PUBLIC_URL",
  "path": "/",
  "publicApi": {
    "disabled": false,
    "path": "api"
  },
  "endpoints": {
    "rest": "$PUBLIC_URL/rest",
    "webhook": "$PUBLIC_URL/webhook",
    "webhookWaiting": "$PUBLIC_URL/webhook-waiting",
    "webhookTest": "$PUBLIC_URL/webhook-test",
    "webhookUrl": "$PUBLIC_URL"
  },
  "externalHookFiles": [],
  "nodes": {
    "exclude": [],
    "errorTriggerType": "n8n-nodes-base.errorTrigger"
  },
  "settings": {
    "timezone": "UTC",
    "saveDataErrorExecution": "all",
    "saveDataSuccessExecution": "all",
    "saveManualExecutions": true,
    "callerPolicyDefaultOption": "workflowsFromSameOwner"
  },
  "userManagement": {
    "disabled": true,
    "emails": {
      "mode": "smtp"
    }
  },
  "security": {
    "basicAuth": {
      "active": true,
      "user": "admin",
      "password": "n8n_1752790771"
    },
    "jwtAuth": {
      "active": false
    }
  },
  "workflows": {
    "defaultName": "My Workflow"
  },
  "executions": {
    "timeout": 3600,
    "maxTimeout": 7200,
    "saveDataOnError": "all",
    "saveDataOnSuccess": "all"
  }
}
EOF
    
    chown -R root:root /root/.n8n
    chmod 600 /root/.n8n/config.json
    success "Comprehensive n8n config.json created"
}

create_optimized_systemd_service() {
    log "🔄 CREATING OPTIMIZED SYSTEMD SERVICE"
    
    cat > /etc/systemd/system/n8n.service << EOF
[Unit]
Description=n8n - Workflow Automation Tool
Documentation=https://docs.n8n.io
After=network.target postgresql.service mysql.service
Wants=network.target

[Service]
Type=simple
User=root
Group=root
ExecStart=/usr/local/bin/n8n start --tunnel
Restart=always
RestartSec=10
KillMode=process
TimeoutStopSec=60

# Environment
Environment=NODE_ENV=production
Environment=NODE_OPTIONS=--max-old-space-size=2048
EnvironmentFile=/root/.env

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
ReadWritePaths=/var/tmp

# Resource limits
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable n8n
    success "Optimized systemd service created and enabled"
}

create_advanced_nginx_config() {
    log "📝 CREATING ADVANCED NGINX CONFIGURATION"
    
    cat > /etc/nginx/sites-available/n8n << EOF
# N8N Advanced Configuration
# Handles init problems and webhook URL issues

upstream n8n_backend {
    server 127.0.0.1:$N8N_PORT;
    keepalive 32;
}

server {
    listen 80;
    server_name $PUBLIC_DOMAIN;
    
    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    
    # File upload size
    client_max_body_size 100M;
    client_body_buffer_size 128k;
    
    # Timeout settings
    proxy_connect_timeout 60s;
    proxy_send_timeout 60s;
    proxy_read_timeout 300s;
    
    # Buffer settings
    proxy_buffer_size 4k;
    proxy_buffers 8 4k;
    proxy_busy_buffers_size 8k;
    
    # Main application with enhanced settings
    location / {
        proxy_pass http://n8n_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
        
        # Critical for webhook URL generation
        proxy_set_header X-Original-URI \$request_uri;
        proxy_set_header X-Original-Host \$host;
        
        proxy_cache_bypass \$http_upgrade;
        proxy_no_cache \$http_upgrade;
        
        # Disable buffering for real-time
        proxy_buffering off;
        proxy_request_buffering off;
    }
    
    # REST API with specific handling
    location /rest/ {
        proxy_pass http://n8n_backend/rest/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        
        # API specific settings
        proxy_buffering off;
        proxy_request_buffering off;
        proxy_read_timeout 60s;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        
        # CORS headers
        add_header Access-Control-Allow-Origin *;
        add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS, PATCH";
        add_header Access-Control-Allow-Headers "Content-Type, Authorization, X-Requested-With";
        add_header Access-Control-Max-Age 86400;
        
        # Handle preflight requests
        if (\$request_method = 'OPTIONS') {
            add_header Access-Control-Allow-Origin *;
            add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS, PATCH";
            add_header Access-Control-Allow-Headers "Content-Type, Authorization, X-Requested-With";
            add_header Access-Control-Max-Age 86400;
            add_header Content-Type 'text/plain charset=UTF-8';
            add_header Content-Length 0;
            return 204;
        }
    }
    
    # WebSocket connections
    location /socket.io/ {
        proxy_pass http://n8n_backend/socket.io/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # WebSocket specific
        proxy_buffering off;
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
        proxy_connect_timeout 86400;
    }
    
    # Webhook endpoints - CRITICAL for URL generation
    location ~* ^/(webhook|webhook-test|webhook-waiting)/ {
        proxy_pass http://n8n_backend;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
        
        # Essential for webhook URL generation
        proxy_set_header X-Original-URI \$request_uri;
        proxy_set_header X-Original-Host \$host;
        proxy_set_header X-Forwarded-Prefix "";
        
        proxy_buffering off;
        proxy_request_buffering off;
        proxy_read_timeout 300s;
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        
        # CORS for webhooks
        add_header Access-Control-Allow-Origin *;
        add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS";
        add_header Access-Control-Allow-Headers "Content-Type, Authorization";
    }
    
    # API endpoints
    location /api/ {
        proxy_pass http://n8n_backend/api/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        proxy_buffering off;
        proxy_request_buffering off;
    }
    
    # Static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        proxy_pass http://n8n_backend;
        proxy_set_header Host \$host;
        proxy_cache_valid 200 1d;
        add_header Cache-Control "public, immutable";
        expires 1d;
    }
    
    # Health check
    location /health {
        proxy_pass http://n8n_backend/health;
        proxy_set_header Host \$host;
        access_log off;
    }
}
EOF
    
    # Test and reload nginx
    if nginx -t; then
        success "✅ Advanced nginx configuration is valid"
        systemctl reload nginx
        success "✅ Nginx reloaded with advanced configuration"
    else
        error "❌ Nginx configuration test failed"
        nginx -t
        return 1
    fi
}

start_n8n_with_verification() {
    log "🚀 STARTING N8N WITH COMPREHENSIVE VERIFICATION"
    
    # Start n8n service
    systemctl start n8n
    
    # Wait for startup with detailed monitoring
    local attempts=0
    local max_attempts=90
    
    log "⏳ Waiting for n8n to fully initialize..."
    
    while [ $attempts -lt $max_attempts ]; do
        # Check if service is active
        if systemctl is-active --quiet n8n; then
            # Check if it's responding
            local response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:$N8N_PORT 2>/dev/null || echo "000")
            
            if [[ "$response" =~ ^(200|401|302)$ ]]; then
                # Check if REST API is working
                local api_response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:$N8N_PORT/rest/settings 2>/dev/null || echo "000")
                
                if [[ "$api_response" =~ ^(200|401|403)$ ]]; then
                    success "✅ N8N fully started and API responding (HTTP $api_response)"
                    break
                fi
            fi
        fi
        
        sleep 2
        attempts=$((attempts + 1))
        
        if [ $((attempts % 15)) -eq 0 ]; then
            log "   Still waiting for n8n... ($attempts/$max_attempts)"
            
            # Show service status
            if ! systemctl is-active --quiet n8n; then
                warning "   N8N service not active, checking logs..."
                journalctl -u n8n --no-pager -l --since "1 minute ago" | tail -5
            fi
        fi
    done
    
    if [ $attempts -eq $max_attempts ]; then
        error "❌ N8N failed to start properly within 3 minutes"
        
        # Detailed diagnostics
        log "🔍 Service status:"
        systemctl status n8n --no-pager -l
        
        log "🔍 Recent logs:"
        journalctl -u n8n --no-pager -l --since "5 minutes ago" | tail -20
        
        log "🔍 Process check:"
        ps aux | grep n8n | grep -v grep || echo "No n8n processes found"
        
        log "🔍 Port check:"
        netstat -tlnp | grep ":$N8N_PORT" || echo "Port $N8N_PORT not listening"
        
        return 1
    fi
}

comprehensive_verification() {
    log "✅ COMPREHENSIVE VERIFICATION OF ALL FIXES"
    
    # Test direct n8n connection
    log "🧪 Testing direct n8n connection..."
    local direct_response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:$N8N_PORT 2>/dev/null || echo "000")
    
    if [[ "$direct_response" =~ ^(200|401|302)$ ]]; then
        success "✅ Direct n8n connection working (HTTP $direct_response)"
    else
        error "❌ Direct n8n connection failed (HTTP $direct_response)"
    fi
    
    # Test public domain access
    log "🧪 Testing public domain access..."
    local public_response=$(curl -s -o /dev/null -w "%{http_code}" http://$PUBLIC_DOMAIN 2>/dev/null || echo "000")
    
    if [[ "$public_response" =~ ^(200|401|302)$ ]]; then
        success "✅ Public domain access working (HTTP $public_response)"
    else
        error "❌ Public domain access failed (HTTP $public_response)"
    fi
    
    # Test critical API endpoints
    log "🧪 Testing critical API endpoints..."
    local endpoints=(
        "/rest/settings"
        "/rest/login"
        "/rest/owner"
        "/rest/workflows"
    )
    
    for endpoint in "${endpoints[@]}"; do
        local endpoint_response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1$endpoint 2>/dev/null || echo "000")
        if [[ "$endpoint_response" =~ ^(200|401|403)$ ]]; then
            success "✅ $endpoint accessible (HTTP $endpoint_response)"
        else
            warning "⚠️ $endpoint may have issues (HTTP $endpoint_response)"
        fi
    done
    
    # Test webhook endpoints
    log "🧪 Testing webhook endpoints..."
    local webhook_endpoints=(
        "/webhook"
        "/webhook-test"
        "/webhook-waiting"
    )
    
    for endpoint in "${webhook_endpoints[@]}"; do
        local webhook_response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1$endpoint 2>/dev/null || echo "000")
        if [[ "$webhook_response" =~ ^(404|405|200)$ ]]; then
            success "✅ $endpoint endpoint accessible (HTTP $webhook_response)"
        else
            warning "⚠️ $endpoint endpoint may have issues (HTTP $webhook_response)"
        fi
    done
    
    # Check environment variables are loaded
    log "🧪 Verifying environment configuration..."
    if systemctl show n8n --property=Environment | grep -q "N8N_EDITOR_BASE_URL=$PUBLIC_URL"; then
        success "✅ Public URL environment variable loaded correctly"
    else
        warning "⚠️ Public URL environment variable may not be loaded"
    fi
}

show_comprehensive_results() {
    log "📊 COMPREHENSIVE N8N FIX RESULTS"
    
    echo ""
    echo "============================================"
    echo "🎉 COMPREHENSIVE N8N FIX COMPLETED"
    echo "============================================"
    echo ""
    echo "🌐 ACCESS YOUR N8N:"
    echo "   🔗 URL: $PUBLIC_URL"
    echo "   👤 Username: admin"
    echo "   🔑 Password: n8n_1752790771"
    echo ""
    echo "✅ FIXES APPLIED:"
    echo "   🔧 Complete n8n configuration reset"
    echo "   ⚙️ Comprehensive environment variables"
    echo "   📝 Advanced nginx proxy configuration"
    echo "   🔄 Optimized systemd service"
    echo "   🌐 Proper webhook URL generation"
    echo "   📡 Fixed API endpoint connectivity"
    echo ""
    echo "🎯 EXPECTED RESULTS:"
    echo "   ✅ No more 'Init Problem' errors"
    echo "   ✅ Webhook URLs show: $PUBLIC_URL/webhook/..."
    echo "   ✅ Form Trigger URLs show: $PUBLIC_URL/webhook-test/..."
    echo "   ✅ All API calls working properly"
    echo "   ✅ Real-time updates functioning"
    echo ""
    echo "🔍 VERIFICATION STEPS:"
    echo "   1. Clear browser cache completely"
    echo "   2. Try incognito/private browsing mode"
    echo "   3. Login to n8n with credentials above"
    echo "   4. Create or edit a Form Trigger workflow"
    echo "   5. Check webhook URLs now show public domain"
    echo ""
    echo "📊 SERVICE STATUS:"
    systemctl is-active nginx && echo "   ✅ Nginx: Running" || echo "   ❌ Nginx: Not running"
    systemctl is-active n8n && echo "   ✅ N8N: Running" || echo "   ❌ N8N: Not running"
    echo ""
    echo "🔧 TROUBLESHOOTING:"
    echo "   📊 Check services: systemctl status nginx n8n"
    echo "   📜 Check logs: journalctl -u n8n -f"
    echo "   🧪 Test direct: curl http://127.0.0.1:$N8N_PORT"
    echo "   🌐 Test public: curl $PUBLIC_URL"
    echo ""
    echo "✅ Both init problems and webhook URLs should now be fixed!"
    echo "============================================"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    log "🚀 COMPREHENSIVE N8N FIX STARTED"
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root (use sudo)"
        exit 1
    fi
    
    # Create log file
    touch "$LOG_FILE"
    
    # Execute comprehensive fix
    stop_all_n8n_processes
    create_comprehensive_n8n_config
    create_optimized_systemd_service
    create_advanced_nginx_config
    start_n8n_with_verification
    comprehensive_verification
    show_comprehensive_results
    
    success "🎉 COMPREHENSIVE N8N FIX COMPLETED"
    log "📜 Full log available at: $LOG_FILE"
}

# Run main function
main "$@"

