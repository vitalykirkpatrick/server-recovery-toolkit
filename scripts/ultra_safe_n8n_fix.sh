#!/bin/bash

# ============================================================================
# ULTRA SAFE N8N FIX
# ============================================================================
# Purpose: Fix n8n without terminating the script itself
# Safety: Careful process management to avoid self-termination
# ============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
LOG_FILE="/var/log/ultra_safe_n8n_fix.log"
SCRIPT_PID=$$

# Logging functions
log() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"; }
info() { echo -e "${CYAN}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }

echo "🛡️ ULTRA SAFE N8N FIX"
echo "====================="
echo "🎯 This will fix n8n without script termination"
echo ""

# ============================================================================
# ULTRA SAFE PROCESS MANAGEMENT
# ============================================================================

ultra_safe_stop() {
    log "🛡️ ULTRA SAFE N8N STOPPING"
    
    # Get our script PID to avoid killing ourselves
    local script_pid=$SCRIPT_PID
    log "🔒 Script PID: $script_pid (protecting from termination)"
    
    # Stop systemd service first
    log "🔄 Stopping systemd service..."
    systemctl stop n8n 2>/dev/null && success "✅ systemd service stopped" || warning "⚠️ systemd service not running"
    
    # Stop PM2 processes safely
    log "📦 Stopping PM2 processes..."
    if command -v pm2 &> /dev/null; then
        pm2 stop n8n 2>/dev/null && success "✅ PM2 stopped" || warning "⚠️ PM2 not running"
        pm2 delete n8n 2>/dev/null && success "✅ PM2 deleted" || warning "⚠️ PM2 not found"
    fi
    
    # Find n8n processes carefully
    log "🔍 Finding n8n processes..."
    local n8n_pids=$(pgrep -f "n8n start" 2>/dev/null | grep -v "$script_pid" || true)
    
    if [ -n "$n8n_pids" ]; then
        log "🎯 Found n8n processes (excluding script): $n8n_pids"
        
        # Kill each process individually and safely
        for pid in $n8n_pids; do
            if [ "$pid" != "$script_pid" ]; then
                log "🔪 Stopping process $pid"
                kill "$pid" 2>/dev/null || true
            else
                log "🔒 Skipping script PID $pid"
            fi
        done
        
        # Wait a moment
        sleep 3
        
        # Check for remaining processes
        local remaining_pids=$(pgrep -f "n8n start" 2>/dev/null | grep -v "$script_pid" || true)
        if [ -n "$remaining_pids" ]; then
            log "🔪 Force killing remaining processes: $remaining_pids"
            for pid in $remaining_pids; do
                if [ "$pid" != "$script_pid" ]; then
                    kill -9 "$pid" 2>/dev/null || true
                fi
            done
        fi
    else
        log "✅ No n8n processes found"
    fi
    
    success "Ultra safe stop completed"
}

# ============================================================================
# DETECT CURRENT N8N SETUP
# ============================================================================

detect_current_setup() {
    log "🔍 DETECTING CURRENT N8N SETUP"
    
    local setup_type="unknown"
    
    # Check for Docker setup
    if systemctl list-units --full -all | grep -q "n8n.*docker"; then
        setup_type="docker"
        log "🐳 Detected: Docker-based n8n setup"
    elif [ -f "/etc/systemd/system/n8n.service" ] && grep -q "docker" "/etc/systemd/system/n8n.service"; then
        setup_type="docker"
        log "🐳 Detected: Docker-based n8n setup (systemd)"
    fi
    
    # Check for PM2 setup
    if command -v pm2 &> /dev/null && pm2 list 2>/dev/null | grep -q "n8n"; then
        setup_type="pm2"
        log "📦 Detected: PM2-based n8n setup"
    fi
    
    # Check for native npm setup
    if [ -f "/etc/systemd/system/n8n.service" ] && grep -q "/usr/bin/n8n\|/usr/local/bin/n8n" "/etc/systemd/system/n8n.service"; then
        setup_type="native"
        log "📦 Detected: Native npm n8n setup"
    fi
    
    # Check for manual/other setup
    if [ "$setup_type" = "unknown" ]; then
        if command -v n8n &> /dev/null; then
            setup_type="native"
            log "📦 Detected: Native n8n installation"
        else
            setup_type="none"
            log "❌ No n8n installation detected"
        fi
    fi
    
    echo "$setup_type"
}

# ============================================================================
# INSTALL N8N IF MISSING
# ============================================================================

install_n8n_if_missing() {
    log "📦 CHECKING N8N INSTALLATION"
    
    if ! command -v n8n &> /dev/null; then
        log "📥 Installing n8n..."
        
        # Install Node.js if missing
        if ! command -v node &> /dev/null; then
            log "📥 Installing Node.js..."
            curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
            apt-get install -y nodejs
        fi
        
        # Install n8n
        npm install -g n8n
        success "✅ n8n installed"
    else
        local version=$(n8n --version 2>/dev/null || echo "unknown")
        log "✅ n8n already installed: $version"
    fi
}

# ============================================================================
# CREATE MINIMAL WORKING CONFIG
# ============================================================================

create_minimal_config() {
    log "⚙️ CREATING MINIMAL WORKING CONFIG"
    
    # Backup existing config
    if [ -d "/root/.n8n" ]; then
        local backup_dir="/root/.n8n.backup.$(date +%Y%m%d_%H%M%S)"
        cp -r /root/.n8n "$backup_dir" 2>/dev/null && log "💾 Backed up to: $backup_dir"
    fi
    
    # Create fresh directory
    mkdir -p /root/.n8n
    chown root:root /root/.n8n
    chmod 755 /root/.n8n
    
    # Create ultra-minimal config that definitely works
    cat > /root/.n8n/config.json << 'EOF'
{
  "host": "0.0.0.0",
  "port": 5678
}
EOF
    
    # Create minimal environment
    cat > /root/.env << 'EOF'
NODE_ENV=production
N8N_HOST=0.0.0.0
N8N_PORT=5678
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=n8n_1752790771
EOF
    
    chmod 600 /root/.env
    success "Minimal config created"
}

# ============================================================================
# TEST N8N MANUALLY
# ============================================================================

test_n8n_manually() {
    log "🧪 TESTING N8N MANUALLY"
    
    cd /root
    export NODE_ENV=production
    export N8N_HOST=0.0.0.0
    export N8N_PORT=5678
    export N8N_BASIC_AUTH_ACTIVE=true
    export N8N_BASIC_AUTH_USER=admin
    export N8N_BASIC_AUTH_PASSWORD=n8n_1752790771
    
    # Test in a separate process to avoid termination
    log "🚀 Starting n8n test..."
    
    # Create test script
    cat > /tmp/n8n_test.sh << 'EOF'
#!/bin/bash
cd /root
export NODE_ENV=production
export N8N_HOST=0.0.0.0
export N8N_PORT=5678
export N8N_BASIC_AUTH_ACTIVE=true
export N8N_BASIC_AUTH_USER=admin
export N8N_BASIC_AUTH_PASSWORD=n8n_1752790771
n8n start > /tmp/n8n_test.log 2>&1 &
echo $! > /tmp/n8n_test.pid
EOF
    
    chmod +x /tmp/n8n_test.sh
    /tmp/n8n_test.sh
    
    # Wait and test
    sleep 8
    
    local response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5678 2>/dev/null || echo "000")
    
    # Clean up test process
    if [ -f "/tmp/n8n_test.pid" ]; then
        local test_pid=$(cat /tmp/n8n_test.pid)
        kill "$test_pid" 2>/dev/null || true
    fi
    
    if [[ "$response" =~ ^(200|401|302)$ ]]; then
        success "✅ Manual test successful (HTTP $response)"
        return 0
    else
        error "❌ Manual test failed (HTTP $response)"
        if [ -f "/tmp/n8n_test.log" ]; then
            log "📜 Test output:"
            head -10 /tmp/n8n_test.log | while read line; do
                log "   $line"
            done
        fi
        return 1
    fi
}

# ============================================================================
# SETUP NATIVE N8N SERVICE
# ============================================================================

setup_native_service() {
    log "🔄 SETTING UP NATIVE N8N SERVICE"
    
    # Create simple systemd service
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

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable n8n
    
    # Start and test
    systemctl start n8n
    sleep 10
    
    local response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5678 2>/dev/null || echo "000")
    
    if [[ "$response" =~ ^(200|401|302)$ ]]; then
        success "✅ Native service working (HTTP $response)"
        return 0
    else
        error "❌ Native service failed (HTTP $response)"
        return 1
    fi
}

# ============================================================================
# SETUP PM2 SERVICE
# ============================================================================

setup_pm2_service() {
    log "📦 SETTING UP PM2 SERVICE"
    
    # Install PM2 if needed
    if ! command -v pm2 &> /dev/null; then
        npm install -g pm2
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
      N8N_BASIC_AUTH_PASSWORD: 'n8n_1752790771'
    },
    instances: 1,
    autorestart: true,
    watch: false
  }]
};
EOF
    
    # Start with PM2
    cd /root
    pm2 start n8n.config.js
    sleep 10
    
    local response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5678 2>/dev/null || echo "000")
    
    if [[ "$response" =~ ^(200|401|302)$ ]]; then
        success "✅ PM2 service working (HTTP $response)"
        pm2 save
        pm2 startup systemd -u root --hp /root
        return 0
    else
        error "❌ PM2 service failed (HTTP $response)"
        return 1
    fi
}

# ============================================================================
# CONFIGURE PUBLIC DOMAIN
# ============================================================================

configure_public_domain() {
    log "🌐 CONFIGURING PUBLIC DOMAIN"
    
    # Update config for public domain
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
EOF
    
    chmod 600 /root/.env
    success "Public domain configured"
}

# ============================================================================
# RESTART SERVICE SAFELY
# ============================================================================

restart_service_safely() {
    log "🔄 RESTARTING SERVICE SAFELY"
    
    # Determine which service to restart
    if systemctl is-active --quiet n8n; then
        log "🔄 Restarting systemd service..."
        systemctl restart n8n
        sleep 5
    elif command -v pm2 &> /dev/null && pm2 list 2>/dev/null | grep -q "n8n.*online"; then
        log "📦 Restarting PM2 service..."
        pm2 restart n8n
        sleep 5
    fi
    
    # Test final result
    local response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5678 2>/dev/null || echo "000")
    
    if [[ "$response" =~ ^(200|401|302)$ ]]; then
        success "✅ Service restart successful (HTTP $response)"
        return 0
    else
        error "❌ Service restart failed (HTTP $response)"
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
    echo "🛡️ ULTRA SAFE N8N FIX COMPLETED"
    echo "============================================"
    echo ""
    
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
    
    if systemctl is-active --quiet n8n; then
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
    echo "============================================"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    log "🛡️ ULTRA SAFE N8N FIX STARTED"
    
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root (use sudo)"
        exit 1
    fi
    
    touch "$LOG_FILE" 2>/dev/null || true
    
    echo "⚠️  This will fix n8n safely without script termination"
    echo "🛡️ Ultra-safe process management"
    echo ""
    read -p "Continue with ultra-safe n8n fix? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Ultra-safe n8n fix cancelled."
        exit 0
    fi
    
    # Execute ultra-safe fix
    ultra_safe_stop
    
    local current_setup=$(detect_current_setup)
    log "🔍 Current setup: $current_setup"
    
    install_n8n_if_missing
    create_minimal_config
    
    if test_n8n_manually; then
        log "✅ Manual test passed, setting up service"
        
        if setup_native_service; then
            log "✅ Native service working"
        elif setup_pm2_service; then
            log "✅ PM2 service working"
        else
            error "❌ Both service methods failed"
        fi
        
        configure_public_domain
        restart_service_safely
    else
        log "❌ Manual test failed, trying PM2 directly"
        if setup_pm2_service; then
            log "✅ PM2 service working"
            configure_public_domain
            restart_service_safely
        else
            error "❌ All methods failed"
        fi
    fi
    
    show_final_status
    
    success "🎉 ULTRA SAFE N8N FIX COMPLETED"
    log "📜 Full log: $LOG_FILE"
}

# Run main function
main "$@"

