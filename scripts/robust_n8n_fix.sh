#!/bin/bash

# ============================================================================
# ROBUST N8N STARTUP FIX
# ============================================================================
# Purpose: Fix n8n startup issues without script termination
# Approach: Handle all errors gracefully, no early exits
# ============================================================================

# Remove set -e to prevent script termination on errors
# set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
LOG_FILE="/var/log/robust_n8n_fix.log"

# Logging functions
log() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"; }
info() { echo -e "${CYAN}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }

echo "🔧 ROBUST N8N STARTUP FIX"
echo "========================="
echo "🎯 This will fix n8n startup issues without script termination"
echo ""

# ============================================================================
# SAFE STOP N8N SERVICE
# ============================================================================

safe_stop_n8n() {
    log "🛑 SAFELY STOPPING N8N SERVICE"
    
    # Try to stop systemd service
    if systemctl stop n8n 2>/dev/null; then
        success "✅ systemd service stopped"
    else
        warning "⚠️ systemd service stop failed or not running"
    fi
    
    # Try to stop PM2 processes
    if command -v pm2 &> /dev/null; then
        if pm2 stop n8n 2>/dev/null; then
            success "✅ PM2 process stopped"
        else
            warning "⚠️ PM2 stop failed or not running"
        fi
    fi
    
    # Kill any remaining n8n processes
    local n8n_pids=$(pgrep -f "n8n" 2>/dev/null || true)
    if [ -n "$n8n_pids" ]; then
        log "🔪 Killing remaining n8n processes: $n8n_pids"
        pkill -f "n8n" 2>/dev/null || true
        sleep 2
        
        # Force kill if still running
        local remaining_pids=$(pgrep -f "n8n" 2>/dev/null || true)
        if [ -n "$remaining_pids" ]; then
            log "🔪 Force killing stubborn processes: $remaining_pids"
            pkill -9 -f "n8n" 2>/dev/null || true
        fi
    fi
    
    success "n8n processes stopped"
}

# ============================================================================
# DIAGNOSE SYSTEM STATE
# ============================================================================

diagnose_system() {
    log "🔍 DIAGNOSING SYSTEM STATE"
    
    # Check basic requirements
    log "📦 Checking basic requirements..."
    
    if command -v node &> /dev/null; then
        log "✅ Node.js: $(node --version)"
    else
        error "❌ Node.js not found"
    fi
    
    if command -v npm &> /dev/null; then
        log "✅ npm: $(npm --version)"
    else
        error "❌ npm not found"
    fi
    
    if command -v n8n &> /dev/null; then
        local n8n_version=$(n8n --version 2>/dev/null || echo "unknown")
        log "✅ n8n: $n8n_version"
        log "📍 n8n location: $(which n8n)"
    else
        error "❌ n8n not found"
    fi
    
    # Check directories
    log "📁 Checking directories..."
    if [ -d "/root/.n8n" ]; then
        log "✅ /root/.n8n exists"
        log "📊 Contents: $(ls -la /root/.n8n/ 2>/dev/null | wc -l) items"
    else
        warning "⚠️ /root/.n8n missing"
    fi
    
    # Check files
    log "📄 Checking configuration files..."
    if [ -f "/root/.n8n/config.json" ]; then
        log "✅ config.json exists ($(stat -c%s /root/.n8n/config.json) bytes)"
    else
        warning "⚠️ config.json missing"
    fi
    
    if [ -f "/root/.env" ]; then
        log "✅ .env exists ($(stat -c%s /root/.env) bytes)"
    else
        warning "⚠️ .env missing"
    fi
    
    # Check ports
    log "🔌 Checking port usage..."
    local port_check=$(netstat -tlnp 2>/dev/null | grep ":5678 " || true)
    if [ -n "$port_check" ]; then
        log "⚠️ Port 5678 in use: $port_check"
    else
        log "✅ Port 5678 available"
    fi
}

# ============================================================================
# CREATE CLEAN CONFIGURATION
# ============================================================================

create_clean_config() {
    log "🧹 CREATING CLEAN CONFIGURATION"
    
    # Backup existing config
    if [ -d "/root/.n8n" ]; then
        local backup_dir="/root/.n8n.backup.$(date +%Y%m%d_%H%M%S)"
        if cp -r /root/.n8n "$backup_dir" 2>/dev/null; then
            log "💾 Backed up existing config to: $backup_dir"
        else
            warning "⚠️ Failed to backup existing config"
        fi
    fi
    
    # Create fresh directory
    log "📁 Creating fresh .n8n directory..."
    rm -rf /root/.n8n 2>/dev/null || true
    mkdir -p /root/.n8n
    chown root:root /root/.n8n
    chmod 755 /root/.n8n
    
    # Create ultra-minimal config
    log "⚙️ Creating minimal configuration..."
    cat > /root/.n8n/config.json << 'EOF'
{
  "host": "0.0.0.0",
  "port": 5678
}
EOF
    
    # Create minimal environment
    log "📝 Creating minimal environment..."
    cat > /root/.env << 'EOF'
NODE_ENV=production
N8N_HOST=0.0.0.0
N8N_PORT=5678
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=n8n_1752790771
N8N_USER_MANAGEMENT_DISABLED=true
EOF
    
    chmod 600 /root/.env
    success "Clean configuration created"
}

# ============================================================================
# TEST MANUAL STARTUP
# ============================================================================

test_manual_startup() {
    log "🧪 TESTING MANUAL N8N STARTUP"
    
    # Change to root directory
    cd /root
    
    # Set environment
    export NODE_ENV=production
    export N8N_HOST=0.0.0.0
    export N8N_PORT=5678
    export N8N_BASIC_AUTH_ACTIVE=true
    export N8N_BASIC_AUTH_USER=admin
    export N8N_BASIC_AUTH_PASSWORD=n8n_1752790771
    export N8N_USER_MANAGEMENT_DISABLED=true
    
    # Try manual startup
    log "🚀 Starting n8n manually..."
    
    # Create a test script to capture output
    cat > /tmp/test_n8n.sh << 'EOF'
#!/bin/bash
cd /root
export NODE_ENV=production
export N8N_HOST=0.0.0.0
export N8N_PORT=5678
export N8N_BASIC_AUTH_ACTIVE=true
export N8N_BASIC_AUTH_USER=admin
export N8N_BASIC_AUTH_PASSWORD=n8n_1752790771
export N8N_USER_MANAGEMENT_DISABLED=true

echo "Starting n8n manually..."
n8n start
EOF
    
    chmod +x /tmp/test_n8n.sh
    
    # Run test in background and capture output
    timeout 15s /tmp/test_n8n.sh > /tmp/n8n_test_output.log 2>&1 &
    local test_pid=$!
    
    # Wait and check
    sleep 10
    
    if kill -0 $test_pid 2>/dev/null; then
        log "✅ n8n started manually"
        kill $test_pid 2>/dev/null || true
        
        # Test HTTP response
        local response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5678 2>/dev/null || echo "000")
        if [[ "$response" =~ ^(200|401|302)$ ]]; then
            success "✅ n8n responding (HTTP $response)"
            return 0
        else
            warning "⚠️ n8n not responding properly (HTTP $response)"
        fi
    else
        error "❌ n8n failed to start manually"
        log "📜 Manual startup output:"
        if [ -f "/tmp/n8n_test_output.log" ]; then
            head -20 /tmp/n8n_test_output.log | while read line; do
                log "   $line"
            done
        fi
    fi
    
    # Clean up any remaining processes
    pkill -f "n8n" 2>/dev/null || true
    
    return 1
}

# ============================================================================
# CREATE SIMPLE SYSTEMD SERVICE
# ============================================================================

create_simple_service() {
    log "🔄 CREATING SIMPLE SYSTEMD SERVICE"
    
    # Create ultra-simple service
    cat > /etc/systemd/system/n8n.service << 'EOF'
[Unit]
Description=n8n
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root
ExecStart=/usr/bin/n8n start
Restart=always
RestartSec=5
Environment=NODE_ENV=production
Environment=N8N_HOST=0.0.0.0
Environment=N8N_PORT=5678
Environment=N8N_BASIC_AUTH_ACTIVE=true
Environment=N8N_BASIC_AUTH_USER=admin
Environment=N8N_BASIC_AUTH_PASSWORD=n8n_1752790771
Environment=N8N_USER_MANAGEMENT_DISABLED=true

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload and enable
    systemctl daemon-reload
    systemctl enable n8n
    success "Simple systemd service created"
}

# ============================================================================
# TEST SYSTEMD STARTUP
# ============================================================================

test_systemd_startup() {
    log "🧪 TESTING SYSTEMD STARTUP"
    
    # Start service
    log "🚀 Starting n8n systemd service..."
    if systemctl start n8n; then
        log "✅ Service start command succeeded"
    else
        error "❌ Service start command failed"
        return 1
    fi
    
    # Wait and test
    local attempts=0
    local max_attempts=15
    
    while [ $attempts -lt $max_attempts ]; do
        if systemctl is-active --quiet n8n; then
            local response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5678 2>/dev/null || echo "000")
            
            if [[ "$response" =~ ^(200|401|302)$ ]]; then
                success "✅ n8n systemd service working (HTTP $response)"
                return 0
            fi
        fi
        
        sleep 2
        attempts=$((attempts + 1))
        log "   Testing systemd startup... ($attempts/$max_attempts)"
    done
    
    error "❌ systemd service failed to start properly"
    
    # Show status
    log "📊 Service status:"
    systemctl status n8n --no-pager -l || true
    
    # Show logs
    log "📜 Recent logs:"
    journalctl -u n8n --no-pager -l -n 10 || true
    
    return 1
}

# ============================================================================
# SETUP PM2 ALTERNATIVE
# ============================================================================

setup_pm2_alternative() {
    log "🔄 SETTING UP PM2 ALTERNATIVE"
    
    # Install PM2 if not present
    if ! command -v pm2 &> /dev/null; then
        log "📦 Installing PM2..."
        if npm install -g pm2; then
            success "✅ PM2 installed"
        else
            error "❌ PM2 installation failed"
            return 1
        fi
    else
        log "✅ PM2 already installed"
    fi
    
    # Stop any existing PM2 processes
    pm2 stop all 2>/dev/null || true
    pm2 delete all 2>/dev/null || true
    
    # Create PM2 config
    cat > /root/n8n.config.js << 'EOF'
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
      N8N_BASIC_AUTH_ACTIVE: 'true',
      N8N_BASIC_AUTH_USER: 'admin',
      N8N_BASIC_AUTH_PASSWORD: 'n8n_1752790771',
      N8N_USER_MANAGEMENT_DISABLED: 'true'
    },
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G'
  }]
};
EOF
    
    # Start with PM2
    log "🚀 Starting n8n with PM2..."
    cd /root
    if pm2 start n8n.config.js; then
        log "✅ PM2 start command succeeded"
    else
        error "❌ PM2 start command failed"
        return 1
    fi
    
    # Test PM2 startup
    sleep 10
    local response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5678 2>/dev/null || echo "000")
    
    if [[ "$response" =~ ^(200|401|302)$ ]]; then
        success "✅ n8n PM2 service working (HTTP $response)"
        
        # Save PM2 config and setup startup
        pm2 save
        pm2 startup systemd -u root --hp /root
        
        return 0
    else
        error "❌ PM2 service not responding properly"
        pm2 logs n8n --lines 10 || true
        return 1
    fi
}

# ============================================================================
# CONFIGURE PUBLIC DOMAIN
# ============================================================================

configure_public_domain() {
    log "🌐 CONFIGURING PUBLIC DOMAIN ACCESS"
    
    # Update n8n config for public domain
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
  }
}
EOF
    
    # Update environment
    cat > /root/.env << 'EOF'
NODE_ENV=production
N8N_HOST=0.0.0.0
N8N_PORT=5678
N8N_PROTOCOL=http
N8N_EDITOR_BASE_URL=http://n8n.websolutionsserver.net
WEBHOOK_URL=http://n8n.websolutionsserver.net
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=n8n_1752790771
N8N_USER_MANAGEMENT_DISABLED=true
EOF
    
    chmod 600 /root/.env
    success "Public domain configuration updated"
}

# ============================================================================
# SHOW FINAL STATUS
# ============================================================================

show_final_status() {
    log "📊 FINAL STATUS CHECK"
    
    echo ""
    echo "============================================"
    echo "🔧 ROBUST N8N FIX COMPLETED"
    echo "============================================"
    echo ""
    
    # Test final status
    local response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5678 2>/dev/null || echo "000")
    
    if [[ "$response" =~ ^(200|401|302)$ ]]; then
        echo "✅ N8N STATUS: RUNNING"
        echo "🌐 Access: http://n8n.websolutionsserver.net"
        echo "🔐 Login: admin / n8n_1752790771"
        echo "📊 HTTP Response: $response"
    else
        echo "❌ N8N STATUS: NOT RUNNING"
        echo "📊 HTTP Response: $response"
    fi
    
    echo ""
    echo "📊 SERVICE STATUS:"
    
    if systemctl is-active --quiet n8n 2>/dev/null; then
        echo "   ✅ systemd: Running"
    else
        echo "   ❌ systemd: Not running"
    fi
    
    if command -v pm2 &> /dev/null && pm2 list 2>/dev/null | grep -q "n8n.*online"; then
        echo "   ✅ PM2: Running"
    else
        echo "   ❌ PM2: Not running"
    fi
    
    echo ""
    echo "🔧 TROUBLESHOOTING:"
    echo "   📜 Check logs: journalctl -u n8n -f"
    echo "   📊 PM2 status: pm2 status"
    echo "   🧪 Test local: curl -I http://127.0.0.1:5678"
    echo ""
    echo "============================================"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    log "🔧 ROBUST N8N STARTUP FIX STARTED"
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root (use sudo)"
        exit 1
    fi
    
    # Create log file
    touch "$LOG_FILE" 2>/dev/null || true
    
    echo "⚠️  This will fix n8n startup issues robustly"
    echo "🔧 No early script termination on errors"
    echo ""
    read -p "Continue with robust n8n fix? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Robust n8n fix cancelled."
        exit 0
    fi
    
    # Execute fix steps
    safe_stop_n8n
    diagnose_system
    create_clean_config
    
    # Try manual startup first
    if test_manual_startup; then
        log "✅ Manual startup successful, proceeding with service setup"
        create_simple_service
        
        if test_systemd_startup; then
            log "✅ systemd service working"
            configure_public_domain
        else
            log "⚠️ systemd failed, trying PM2"
            if setup_pm2_alternative; then
                log "✅ PM2 service working"
                configure_public_domain
            else
                error "❌ Both systemd and PM2 failed"
            fi
        fi
    else
        log "❌ Manual startup failed, trying PM2 directly"
        if setup_pm2_alternative; then
            log "✅ PM2 service working"
            configure_public_domain
        else
            error "❌ All startup methods failed"
        fi
    fi
    
    show_final_status
    
    success "🎉 ROBUST N8N FIX COMPLETED"
    log "📜 Full log available at: $LOG_FILE"
}

# Run main function
main "$@"

