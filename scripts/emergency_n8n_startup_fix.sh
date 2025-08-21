#!/bin/bash

# ============================================================================
# EMERGENCY N8N STARTUP FIX
# ============================================================================
# Purpose: Fix n8n startup failures and get it running immediately
# Issue: n8n fails to start within 60 seconds, PM2 not working
# ============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚨 EMERGENCY N8N STARTUP FIX${NC}"
echo "============================="
echo ""

# Function to display status
log() { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

PUBLIC_DOMAIN="n8n.websolutionsserver.net"

# ============================================================================
# STEP 1: EMERGENCY DIAGNOSIS
# ============================================================================

emergency_diagnosis() {
    log "🔍 EMERGENCY DIAGNOSIS"
    
    echo "📊 System Information:"
    echo "   OS: $(lsb_release -d 2>/dev/null | cut -f2 || echo 'Unknown')"
    echo "   Node.js: $(node --version 2>/dev/null || echo 'Not installed')"
    echo "   npm: $(npm --version 2>/dev/null || echo 'Not installed')"
    echo "   PM2: $(pm2 --version 2>/dev/null || echo 'Not installed')"
    echo ""
    
    echo "🔍 N8N Installation Check:"
    if command -v n8n &> /dev/null; then
        echo "   ✅ n8n command available: $(which n8n)"
        echo "   📦 n8n version: $(n8n --version 2>/dev/null || echo 'Version check failed')"
    else
        echo "   ❌ n8n command not found"
    fi
    echo ""
    
    echo "🔍 Process Check:"
    local n8n_processes=$(ps aux | grep -E '[n]8n|[N]8N' | wc -l)
    echo "   🔄 N8N processes: $n8n_processes"
    
    local port_check=$(netstat -tlnp 2>/dev/null | grep :5678 || echo "Port 5678: Not listening")
    echo "   🌐 $port_check"
    echo ""
    
    echo "🔍 PM2 Status:"
    if command -v pm2 &> /dev/null; then
        pm2 list 2>/dev/null || echo "   ❌ PM2 list failed"
    else
        echo "   ❌ PM2 not installed"
    fi
    
    success "Emergency diagnosis completed"
}

# ============================================================================
# STEP 2: KILL ALL N8N PROCESSES
# ============================================================================

kill_all_n8n() {
    log "🔪 KILLING ALL N8N PROCESSES"
    
    # Stop PM2 processes
    if command -v pm2 &> /dev/null; then
        pm2 stop all 2>/dev/null || true
        pm2 delete all 2>/dev/null || true
        pm2 kill 2>/dev/null || true
    fi
    
    # Kill all n8n processes
    pkill -f "n8n" 2>/dev/null || true
    pkill -f "N8N" 2>/dev/null || true
    
    # Kill processes on port 5678
    local port_pid=$(lsof -ti:5678 2>/dev/null || true)
    if [ ! -z "$port_pid" ]; then
        kill -9 $port_pid 2>/dev/null || true
    fi
    
    success "All n8n processes killed"
}

# ============================================================================
# STEP 3: FIX NODE.JS AND NPM
# ============================================================================

fix_nodejs_npm() {
    log "📦 FIXING NODE.JS AND NPM"
    
    # Check Node.js version
    if ! command -v node &> /dev/null; then
        error "Node.js not installed, installing..."
        curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
        apt-get install -y nodejs
    fi
    
    local node_version=$(node --version 2>/dev/null | sed 's/v//')
    echo "   Node.js version: $node_version"
    
    # Check if Node.js version is compatible (should be 16+ for n8n)
    local major_version=$(echo $node_version | cut -d. -f1)
    if [ "$major_version" -lt 16 ]; then
        warning "Node.js version too old, updating..."
        curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
        apt-get install -y nodejs
    fi
    
    # Fix npm permissions
    npm config set prefix '/usr/local'
    
    success "Node.js and npm fixed"
}

# ============================================================================
# STEP 4: REINSTALL N8N CLEANLY
# ============================================================================

reinstall_n8n() {
    log "🔄 REINSTALLING N8N CLEANLY"
    
    # Uninstall existing n8n
    npm uninstall -g n8n 2>/dev/null || true
    
    # Clear npm cache
    npm cache clean --force
    
    # Install n8n globally
    npm install -g n8n
    
    # Verify installation
    if command -v n8n &> /dev/null; then
        success "✅ N8N installed successfully: $(n8n --version)"
    else
        error "❌ N8N installation failed"
        return 1
    fi
}

# ============================================================================
# STEP 5: CREATE MINIMAL CONFIGURATION
# ============================================================================

create_minimal_config() {
    log "⚙️ CREATING MINIMAL CONFIGURATION"
    
    # Create .n8n directory
    mkdir -p /root/.n8n
    
    # Create minimal config
    cat > /root/.n8n/config.json << EOF
{
  "host": "0.0.0.0",
  "port": 5678,
  "protocol": "https",
  "editorBaseUrl": "https://$PUBLIC_DOMAIN"
}
EOF
    
    # Create environment file
    cat > /root/.env << EOF
NODE_ENV=production
N8N_HOST=0.0.0.0
N8N_PORT=5678
N8N_PROTOCOL=https
N8N_EDITOR_BASE_URL=https://$PUBLIC_DOMAIN
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=n8n_1752790771
EOF
    
    chmod 600 /root/.env
    
    success "Minimal configuration created"
}

# ============================================================================
# STEP 6: TEST MANUAL STARTUP
# ============================================================================

test_manual_startup() {
    log "🧪 TESTING MANUAL N8N STARTUP"
    
    # Set environment variables
    export NODE_ENV=production
    export N8N_HOST=0.0.0.0
    export N8N_PORT=5678
    export N8N_PROTOCOL=https
    export N8N_EDITOR_BASE_URL=https://$PUBLIC_DOMAIN
    export N8N_BASIC_AUTH_ACTIVE=true
    export N8N_BASIC_AUTH_USER=admin
    export N8N_BASIC_AUTH_PASSWORD=n8n_1752790771
    
    # Start n8n in background
    cd /root
    nohup n8n > /var/log/n8n-manual.log 2>&1 &
    local n8n_pid=$!
    
    echo "   Started n8n with PID: $n8n_pid"
    
    # Wait for startup
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        local response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5678 2>/dev/null || echo "000")
        
        if [[ "$response" =~ ^(200|401|302)$ ]]; then
            success "✅ N8N manual startup successful (HTTP $response)"
            echo "   PID: $n8n_pid"
            echo "   Log: /var/log/n8n-manual.log"
            return 0
        fi
        
        echo "   Waiting for n8n... ($attempt/$max_attempts)"
        sleep 2
        ((attempt++))
    done
    
    error "❌ N8N manual startup failed"
    echo "   Check log: tail -f /var/log/n8n-manual.log"
    
    # Kill the failed process
    kill $n8n_pid 2>/dev/null || true
    return 1
}

# ============================================================================
# STEP 7: SETUP PM2 PROPERLY
# ============================================================================

setup_pm2_properly() {
    log "📦 SETTING UP PM2 PROPERLY"
    
    # Install PM2 if not installed
    if ! command -v pm2 &> /dev/null; then
        npm install -g pm2
    fi
    
    # Kill any existing PM2 daemon
    pm2 kill 2>/dev/null || true
    
    # Create PM2 ecosystem file with absolute paths
    cat > /root/n8n-ecosystem.json << EOF
{
  "apps": [{
    "name": "n8n",
    "script": "$(which n8n)",
    "cwd": "/root",
    "env": {
      "NODE_ENV": "production",
      "N8N_HOST": "0.0.0.0",
      "N8N_PORT": "5678",
      "N8N_PROTOCOL": "https",
      "N8N_EDITOR_BASE_URL": "https://$PUBLIC_DOMAIN",
      "N8N_BASIC_AUTH_ACTIVE": "true",
      "N8N_BASIC_AUTH_USER": "admin",
      "N8N_BASIC_AUTH_PASSWORD": "n8n_1752790771"
    },
    "instances": 1,
    "autorestart": true,
    "watch": false,
    "max_memory_restart": "1G",
    "min_uptime": "10s",
    "max_restarts": 5,
    "restart_delay": 4000,
    "log_date_format": "YYYY-MM-DD HH:mm:ss Z",
    "error_file": "/var/log/n8n-error.log",
    "out_file": "/var/log/n8n-out.log",
    "log_file": "/var/log/n8n-combined.log"
  }]
}
EOF
    
    # Start with PM2
    pm2 start /root/n8n-ecosystem.json
    pm2 save
    
    # Setup PM2 startup
    pm2 startup systemd -u root --hp /root
    
    success "PM2 setup completed"
}

# ============================================================================
# STEP 8: VERIFY FINAL SETUP
# ============================================================================

verify_final_setup() {
    log "✅ VERIFYING FINAL SETUP"
    
    # Wait for startup
    sleep 10
    
    # Check PM2 status
    echo "📦 PM2 Status:"
    pm2 list
    echo ""
    
    # Check if n8n is responding
    local response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5678 2>/dev/null || echo "000")
    
    if [[ "$response" =~ ^(200|401|302)$ ]]; then
        success "✅ N8N is responding (HTTP $response)"
        
        # Check nginx proxy
        local nginx_response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1 2>/dev/null || echo "000")
        echo "🌐 Nginx proxy: HTTP $nginx_response"
        
        return 0
    else
        error "❌ N8N not responding (HTTP $response)"
        
        echo "🔍 Troubleshooting information:"
        echo "   PM2 logs: pm2 logs n8n"
        echo "   Manual log: tail -f /var/log/n8n-manual.log"
        echo "   Process check: ps aux | grep n8n"
        echo "   Port check: netstat -tlnp | grep 5678"
        
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
    echo "🚨 EMERGENCY N8N STARTUP FIX COMPLETED"
    echo "============================================"
    echo ""
    
    local response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5678 2>/dev/null || echo "000")
    local nginx_response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1 2>/dev/null || echo "000")
    
    if [[ "$response" =~ ^(200|401|302)$ ]]; then
        echo "✅ N8N STATUS: RUNNING"
        echo "🌐 Direct access: http://127.0.0.1:5678 (HTTP $response)"
        echo "🌐 Public access: https://$PUBLIC_DOMAIN (HTTP $nginx_response)"
        echo "🔐 Login: admin / n8n_1752790771"
        echo ""
        echo "🔗 WEBHOOK URLS:"
        echo "   📝 Form Trigger: https://$PUBLIC_DOMAIN/webhook-test/..."
        echo "   🔗 Webhooks: https://$PUBLIC_DOMAIN/webhook/..."
        echo "   🔄 REST API: https://$PUBLIC_DOMAIN/rest/..."
        echo ""
        echo "🎯 MANAGEMENT COMMANDS:"
        echo "   📦 PM2 status: pm2 status"
        echo "   📦 PM2 logs: pm2 logs n8n"
        echo "   📦 PM2 restart: pm2 restart n8n"
        echo "   📦 PM2 stop: pm2 stop n8n"
        echo ""
        echo "📜 LOG FILES:"
        echo "   📄 Combined: /var/log/n8n-combined.log"
        echo "   ❌ Errors: /var/log/n8n-error.log"
        echo "   📝 Output: /var/log/n8n-out.log"
    else
        echo "❌ N8N STATUS: NOT RUNNING"
        echo "📊 Direct access: HTTP $response"
        echo "📊 Nginx proxy: HTTP $nginx_response"
        echo ""
        echo "🔧 MANUAL TROUBLESHOOTING:"
        echo "   1. Check PM2: pm2 status"
        echo "   2. Check logs: pm2 logs n8n"
        echo "   3. Manual start: cd /root && n8n"
        echo "   4. Check port: netstat -tlnp | grep 5678"
        echo "   5. Check processes: ps aux | grep n8n"
        echo ""
        echo "🆘 EMERGENCY COMMANDS:"
        echo "   🔄 Restart PM2: pm2 restart n8n"
        echo "   🔪 Kill all: pkill -f n8n && pm2 kill"
        echo "   🧪 Manual test: cd /root && n8n"
    fi
    
    echo ""
    echo "============================================"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    log "🚨 Starting emergency n8n startup fix..."
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root (use sudo)"
        exit 1
    fi
    
    echo -e "${YELLOW}🚨 This is an emergency fix for n8n startup failures${NC}"
    echo -e "${BLUE}🔧 Will completely reinstall and reconfigure n8n${NC}"
    echo ""
    read -p "Continue with emergency fix? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Emergency fix cancelled."
        exit 0
    fi
    
    # Execute emergency fix steps
    emergency_diagnosis
    kill_all_n8n
    fix_nodejs_npm
    
    if reinstall_n8n; then
        create_minimal_config
        
        if test_manual_startup; then
            # Manual startup worked, now setup PM2
            kill_all_n8n  # Kill manual process
            setup_pm2_properly
            verify_final_setup
        else
            error "Manual startup failed - check Node.js and n8n installation"
        fi
    else
        error "N8N installation failed"
    fi
    
    show_final_status
    
    success "🎉 EMERGENCY N8N STARTUP FIX COMPLETED"
}

# Run main function
main "$@"

