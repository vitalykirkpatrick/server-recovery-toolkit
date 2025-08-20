#!/bin/bash

# ============================================================================
# FIX N8N STARTUP ISSUE
# ============================================================================
# Purpose: Diagnose and fix n8n startup problems (exit code 2)
# Issue: n8n service fails to start after configuration
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
LOG_FILE="/var/log/n8n_startup_fix.log"

# Logging functions
log() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"; }
info() { echo -e "${CYAN}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }

echo "🔧 N8N STARTUP ISSUE DIAGNOSTIC AND FIX"
echo "======================================="
echo "🎯 This will diagnose and fix n8n startup problems"
echo ""

# ============================================================================
# STOP N8N SERVICE
# ============================================================================

stop_n8n_service() {
    log "🛑 STOPPING N8N SERVICE"
    
    # Stop the service
    systemctl stop n8n 2>/dev/null || true
    
    # Kill any remaining n8n processes
    pkill -f "n8n" 2>/dev/null || true
    
    # Wait a moment
    sleep 3
    
    success "n8n service stopped"
}

# ============================================================================
# DIAGNOSE N8N STARTUP ISSUES
# ============================================================================

diagnose_n8n_issues() {
    log "🔍 DIAGNOSING N8N STARTUP ISSUES"
    
    # Check n8n installation
    log "📦 Checking n8n installation..."
    if command -v n8n &> /dev/null; then
        local n8n_version=$(n8n --version 2>/dev/null || echo "unknown")
        log "✅ n8n installed: $n8n_version"
        log "📍 n8n location: $(which n8n)"
    else
        error "❌ n8n not found in PATH"
        return 1
    fi
    
    # Check Node.js
    log "📦 Checking Node.js..."
    if command -v node &> /dev/null; then
        log "✅ Node.js: $(node --version)"
    else
        error "❌ Node.js not found"
        return 1
    fi
    
    # Check npm
    if command -v npm &> /dev/null; then
        log "✅ npm: $(npm --version)"
    else
        error "❌ npm not found"
        return 1
    fi
    
    # Check n8n configuration
    log "⚙️ Checking n8n configuration..."
    if [ -f "/root/.n8n/config.json" ]; then
        log "✅ n8n config file exists"
        log "📄 Config file size: $(stat -c%s /root/.n8n/config.json) bytes"
    else
        warning "⚠️ n8n config file missing"
    fi
    
    # Check environment file
    if [ -f "/root/.env" ]; then
        log "✅ Environment file exists"
        log "📄 Env file size: $(stat -c%s /root/.env) bytes"
    else
        warning "⚠️ Environment file missing"
    fi
    
    # Check permissions
    log "🔐 Checking permissions..."
    log "📁 /root/.n8n permissions: $(stat -c%a /root/.n8n 2>/dev/null || echo 'not found')"
    log "📄 /root/.env permissions: $(stat -c%a /root/.env 2>/dev/null || echo 'not found')"
    
    # Try to run n8n manually to see the error
    log "🧪 Testing n8n startup manually..."
    cd /root
    
    # Set environment variables
    export NODE_ENV=production
    if [ -f "/root/.env" ]; then
        set -a
        source /root/.env
        set +a
    fi
    
    # Try to start n8n and capture output
    log "🔧 Attempting to start n8n manually..."
    timeout 10s n8n start > /tmp/n8n_manual_test.log 2>&1 &
    local n8n_pid=$!
    
    sleep 5
    
    if kill -0 $n8n_pid 2>/dev/null; then
        log "✅ n8n started successfully in manual test"
        kill $n8n_pid 2>/dev/null || true
    else
        log "❌ n8n failed to start manually"
        log "📜 Manual startup output:"
        cat /tmp/n8n_manual_test.log | head -20 | while read line; do
            log "   $line"
        done
    fi
    
    # Clean up
    pkill -f "n8n" 2>/dev/null || true
}

# ============================================================================
# FIX COMMON N8N STARTUP ISSUES
# ============================================================================

fix_n8n_startup_issues() {
    log "🔧 FIXING N8N STARTUP ISSUES"
    
    # Create clean n8n directory
    log "📁 Ensuring clean n8n directory..."
    mkdir -p /root/.n8n
    chown -R root:root /root/.n8n
    chmod 755 /root/.n8n
    
    # Create minimal working configuration
    log "⚙️ Creating minimal working n8n configuration..."
    cat > /root/.n8n/config.json << 'EOF'
{
  "host": "0.0.0.0",
  "port": 5678,
  "protocol": "http",
  "editorBaseUrl": "http://n8n.websolutionsserver.net",
  "endpoints": {
    "rest": "http://n8n.websolutionsserver.net/rest",
    "webhook": "http://n8n.websolutionsserver.net/webhook",
    "webhookWaiting": "http://n8n.websolutionsserver.net/webhook-waiting",
    "webhookTest": "http://n8n.websolutionsserver.net/webhook-test"
  },
  "security": {
    "basicAuth": {
      "active": true,
      "user": "admin",
      "password": "n8n_1752790771"
    }
  },
  "userManagement": {
    "disabled": true
  }
}
EOF
    
    # Create minimal environment file
    log "📝 Creating minimal environment file..."
    cat > /root/.env << 'EOF'
# N8N Minimal Configuration
NODE_ENV=production
N8N_HOST=0.0.0.0
N8N_PORT=5678
N8N_PROTOCOL=http
N8N_EDITOR_BASE_URL=http://n8n.websolutionsserver.net
WEBHOOK_URL=http://n8n.websolutionsserver.net

# Authentication
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=n8n_1752790771

# Security
N8N_SECURE_COOKIE=false
N8N_USER_MANAGEMENT_DISABLED=true

# Disable problematic features that might cause startup issues
N8N_METRICS=false
N8N_DIAGNOSTICS_ENABLED=false
N8N_VERSION_NOTIFICATIONS_ENABLED=false
N8N_TEMPLATES_ENABLED=false
N8N_ONBOARDING_FLOW_DISABLED=true
EOF
    
    chmod 600 /root/.env
    
    # Fix systemd service
    log "🔄 Creating fixed systemd service..."
    cat > /etc/systemd/system/n8n.service << 'EOF'
[Unit]
Description=n8n - Workflow Automation Tool
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
Group=root
ExecStart=/usr/bin/n8n start
Restart=always
RestartSec=10
KillMode=process
TimeoutStopSec=60
TimeoutStartSec=60

# Environment
Environment=NODE_ENV=production
EnvironmentFile=-/root/.env

# Working directory
WorkingDirectory=/root

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=n8n

# Resource limits
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd
    systemctl daemon-reload
    success "Fixed n8n configuration and service"
}

# ============================================================================
# TEST N8N STARTUP
# ============================================================================

test_n8n_startup() {
    log "🧪 TESTING N8N STARTUP"
    
    # Start n8n service
    log "🚀 Starting n8n service..."
    systemctl start n8n
    
    # Wait and check startup
    local attempts=0
    local max_attempts=20
    
    while [ $attempts -lt $max_attempts ]; do
        if systemctl is-active --quiet n8n; then
            local response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5678 2>/dev/null || echo "000")
            
            if [[ "$response" =~ ^(200|401|302)$ ]]; then
                success "✅ n8n started successfully (HTTP $response)"
                return 0
            fi
        fi
        
        sleep 3
        attempts=$((attempts + 1))
        log "   Testing n8n startup... ($attempts/$max_attempts)"
    done
    
    error "❌ n8n failed to start properly"
    
    # Show service status
    log "📊 Service status:"
    systemctl status n8n --no-pager -l
    
    # Show recent logs
    log "📜 Recent n8n logs:"
    journalctl -u n8n --no-pager -l -n 20
    
    return 1
}

# ============================================================================
# ALTERNATIVE STARTUP METHOD
# ============================================================================

try_alternative_startup() {
    log "🔄 TRYING ALTERNATIVE STARTUP METHOD"
    
    # Stop systemd service
    systemctl stop n8n 2>/dev/null || true
    systemctl disable n8n 2>/dev/null || true
    
    # Create PM2 startup instead
    log "📦 Installing PM2 for alternative startup..."
    npm install -g pm2 2>/dev/null || true
    
    # Create PM2 ecosystem file
    cat > /root/n8n-ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'n8n',
    script: 'n8n',
    args: 'start',
    cwd: '/root',
    env: {
      NODE_ENV: 'production',
      N8N_HOST: '0.0.0.0',
      N8N_PORT: '5678',
      N8N_PROTOCOL: 'http',
      N8N_EDITOR_BASE_URL: 'http://n8n.websolutionsserver.net',
      WEBHOOK_URL: 'http://n8n.websolutionsserver.net',
      N8N_BASIC_AUTH_ACTIVE: 'true',
      N8N_BASIC_AUTH_USER: 'admin',
      N8N_BASIC_AUTH_PASSWORD: 'n8n_1752790771',
      N8N_SECURE_COOKIE: 'false',
      N8N_USER_MANAGEMENT_DISABLED: 'true'
    },
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    log_file: '/var/log/n8n.log',
    out_file: '/var/log/n8n-out.log',
    error_file: '/var/log/n8n-error.log'
  }]
};
EOF
    
    # Start with PM2
    log "🚀 Starting n8n with PM2..."
    cd /root
    pm2 start n8n-ecosystem.config.js
    pm2 save
    pm2 startup systemd -u root --hp /root
    
    # Test PM2 startup
    sleep 10
    local response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5678 2>/dev/null || echo "000")
    
    if [[ "$response" =~ ^(200|401|302)$ ]]; then
        success "✅ n8n started successfully with PM2 (HTTP $response)"
        return 0
    else
        error "❌ PM2 startup also failed"
        pm2 logs n8n --lines 20
        return 1
    fi
}

# ============================================================================
# SHOW FINAL RESULTS
# ============================================================================

show_final_results() {
    log "📊 N8N STARTUP FIX COMPLETED"
    
    echo ""
    echo "============================================"
    echo "🔧 N8N STARTUP FIX COMPLETED"
    echo "============================================"
    echo ""
    
    # Check final status
    local n8n_running=false
    local response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5678 2>/dev/null || echo "000")
    
    if [[ "$response" =~ ^(200|401|302)$ ]]; then
        n8n_running=true
        echo "✅ N8N STATUS: RUNNING"
        echo "🌐 Access: http://n8n.websolutionsserver.net"
        echo "🔐 Login: admin / n8n_1752790771"
    else
        echo "❌ N8N STATUS: NOT RUNNING"
        echo "🔧 Manual troubleshooting needed"
    fi
    
    echo ""
    echo "📊 SERVICE STATUS:"
    if systemctl is-active --quiet n8n; then
        echo "   🔄 systemd service: Running"
    else
        echo "   ⏸️ systemd service: Not running"
    fi
    
    if command -v pm2 &> /dev/null && pm2 list | grep -q "n8n"; then
        echo "   🔄 PM2 process: Running"
    else
        echo "   ⏸️ PM2 process: Not running"
    fi
    
    echo ""
    echo "🔧 TROUBLESHOOTING:"
    echo "   📜 Check logs: journalctl -u n8n -f"
    echo "   📊 Service status: systemctl status n8n"
    echo "   🧪 Test access: curl -I http://127.0.0.1:5678"
    echo "   🔄 Restart: systemctl restart n8n"
    echo ""
    
    if [ "$n8n_running" = true ]; then
        echo "🎉 N8N IS NOW RUNNING!"
    else
        echo "⚠️ N8N STARTUP ISSUES PERSIST"
        echo "📞 Manual intervention may be required"
    fi
    
    echo "============================================"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    log "🔧 N8N STARTUP ISSUE FIX STARTED"
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root (use sudo)"
        exit 1
    fi
    
    # Create log file
    touch "$LOG_FILE"
    
    echo "⚠️  This will diagnose and fix n8n startup issues"
    echo "🔧 Detected: n8n service failing with exit code 2"
    echo ""
    read -p "Continue with n8n startup fix? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "n8n startup fix cancelled."
        exit 0
    fi
    
    # Execute fix
    stop_n8n_service
    diagnose_n8n_issues
    fix_n8n_startup_issues
    
    if test_n8n_startup; then
        show_final_results
    else
        log "🔄 Trying alternative startup method..."
        if try_alternative_startup; then
            show_final_results
        else
            show_final_results
        fi
    fi
    
    success "🎉 N8N STARTUP FIX COMPLETED"
    log "📜 Full log available at: $LOG_FILE"
}

# Run main function
main "$@"

