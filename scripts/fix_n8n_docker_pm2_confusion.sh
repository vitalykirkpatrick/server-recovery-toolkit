#!/bin/bash

# ============================================================================
# FIX N8N DOCKER/PM2 CONFUSION
# ============================================================================
# Purpose: Fix the mixed Docker/PM2 n8n setup causing 502 errors
# Issue: n8n detected as Docker but no containers found, PM2 crashing
# ============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔧 FIXING N8N DOCKER/PM2 CONFUSION${NC}"
echo "=================================="
echo ""

# Function to display status
log() { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

PUBLIC_DOMAIN="n8n.websolutionsserver.net"

# ============================================================================
# STEP 1: ANALYZE CURRENT SITUATION
# ============================================================================

analyze_current_state() {
    log "🔍 ANALYZING CURRENT N8N STATE"
    
    echo "📊 Current situation analysis:"
    
    # Check Docker
    if command -v docker &> /dev/null; then
        local containers=$(docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" | grep -i n8n || echo "No n8n containers")
        echo "🐳 Docker containers: $containers"
    else
        echo "🐳 Docker: Not installed"
    fi
    
    # Check PM2
    if command -v pm2 &> /dev/null; then
        local pm2_status=$(pm2 list | grep n8n || echo "No n8n in PM2")
        echo "📦 PM2 status: $pm2_status"
    else
        echo "📦 PM2: Not installed"
    fi
    
    # Check systemd
    local systemd_status=$(systemctl is-active n8n 2>/dev/null || echo "inactive")
    echo "⚙️ Systemd service: $systemd_status"
    
    # Check processes
    local processes=$(ps aux | grep -E '[n]8n|[N]8N' | wc -l)
    echo "🔄 N8N processes running: $processes"
    
    # Check ports
    local port_5678=$(netstat -tlnp 2>/dev/null | grep :5678 || echo "Port 5678: Not listening")
    echo "🌐 $port_5678"
    
    success "Current state analyzed"
}

# ============================================================================
# STEP 2: STOP ALL N8N PROCESSES
# ============================================================================

stop_all_n8n() {
    log "🛑 STOPPING ALL N8N PROCESSES"
    
    # Stop PM2 processes
    if command -v pm2 &> /dev/null; then
        pm2 stop n8n 2>/dev/null || true
        pm2 delete n8n 2>/dev/null || true
        success "PM2 n8n processes stopped"
    fi
    
    # Stop systemd service
    systemctl stop n8n 2>/dev/null || true
    systemctl disable n8n 2>/dev/null || true
    success "Systemd n8n service stopped"
    
    # Stop Docker containers
    if command -v docker &> /dev/null; then
        docker stop $(docker ps -q --filter "ancestor=n8nio/n8n") 2>/dev/null || true
        docker rm $(docker ps -aq --filter "ancestor=n8nio/n8n") 2>/dev/null || true
        success "Docker n8n containers stopped"
    fi
    
    # Kill any remaining processes
    pkill -f "n8n" 2>/dev/null || true
    
    success "All n8n processes stopped"
}

# ============================================================================
# STEP 3: CLEAN UP CONFLICTING INSTALLATIONS
# ============================================================================

cleanup_installations() {
    log "🧹 CLEANING UP CONFLICTING INSTALLATIONS"
    
    # Remove systemd service file
    rm -f /etc/systemd/system/n8n.service
    systemctl daemon-reload
    
    # Clean PM2 configuration
    if command -v pm2 &> /dev/null; then
        pm2 flush
        pm2 save --force
    fi
    
    success "Conflicting installations cleaned"
}

# ============================================================================
# STEP 4: CHOOSE INSTALLATION METHOD
# ============================================================================

choose_installation_method() {
    log "🎯 CHOOSING BEST INSTALLATION METHOD"
    
    echo ""
    echo "🔧 Available installation methods:"
    echo "1. PM2 (Process Manager) - Recommended"
    echo "2. Docker (Container)"
    echo "3. Systemd (System Service)"
    echo ""
    
    read -p "Choose installation method (1-3) [1]: " -n 1 -r
    echo
    
    case $REPLY in
        2)
            install_method="docker"
            ;;
        3)
            install_method="systemd"
            ;;
        *)
            install_method="pm2"
            ;;
    esac
    
    success "Selected installation method: $install_method"
}

# ============================================================================
# STEP 5: INSTALL N8N WITH CHOSEN METHOD
# ============================================================================

install_n8n_pm2() {
    log "📦 INSTALLING N8N WITH PM2"
    
    # Ensure n8n is installed globally
    if ! command -v n8n &> /dev/null; then
        npm install -g n8n
    fi
    
    # Create PM2 ecosystem file
    cat > /root/n8n-pm2.json << EOF
{
  "apps": [{
    "name": "n8n",
    "script": "n8n",
    "cwd": "/root",
    "env": {
      "NODE_ENV": "production",
      "N8N_HOST": "0.0.0.0",
      "N8N_PORT": "5678",
      "N8N_PROTOCOL": "https",
      "N8N_EDITOR_BASE_URL": "https://$PUBLIC_DOMAIN",
      "WEBHOOK_URL": "https://$PUBLIC_DOMAIN",
      "N8N_BASIC_AUTH_ACTIVE": "true",
      "N8N_BASIC_AUTH_USER": "admin",
      "N8N_BASIC_AUTH_PASSWORD": "n8n_1752790771"
    },
    "instances": 1,
    "autorestart": true,
    "watch": false,
    "max_memory_restart": "1G",
    "log_date_format": "YYYY-MM-DD HH:mm Z",
    "error_file": "/var/log/n8n-error.log",
    "out_file": "/var/log/n8n-out.log",
    "log_file": "/var/log/n8n-combined.log"
  }]
}
EOF
    
    # Start with PM2
    pm2 start /root/n8n-pm2.json
    pm2 save
    pm2 startup
    
    success "N8N installed with PM2"
}

install_n8n_docker() {
    log "🐳 INSTALLING N8N WITH DOCKER"
    
    # Create docker-compose file
    cat > /root/docker-compose.yml << EOF
version: '3.8'
services:
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    ports:
      - "5678:5678"
    environment:
      - N8N_HOST=0.0.0.0
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - N8N_EDITOR_BASE_URL=https://$PUBLIC_DOMAIN
      - WEBHOOK_URL=https://$PUBLIC_DOMAIN
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=n8n_1752790771
    volumes:
      - /root/.n8n:/home/node/.n8n
    user: "0:0"
EOF
    
    # Start with docker-compose
    cd /root
    docker-compose up -d
    
    success "N8N installed with Docker"
}

install_n8n_systemd() {
    log "⚙️ INSTALLING N8N WITH SYSTEMD"
    
    # Ensure n8n is installed globally
    if ! command -v n8n &> /dev/null; then
        npm install -g n8n
    fi
    
    # Create systemd service
    cat > /etc/systemd/system/n8n.service << EOF
[Unit]
Description=n8n automation workflow service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root
Environment=NODE_ENV=production
Environment=N8N_HOST=0.0.0.0
Environment=N8N_PORT=5678
Environment=N8N_PROTOCOL=https
Environment=N8N_EDITOR_BASE_URL=https://$PUBLIC_DOMAIN
Environment=WEBHOOK_URL=https://$PUBLIC_DOMAIN
Environment=N8N_BASIC_AUTH_ACTIVE=true
Environment=N8N_BASIC_AUTH_USER=admin
Environment=N8N_BASIC_AUTH_PASSWORD=n8n_1752790771
ExecStart=/usr/bin/n8n
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable and start service
    systemctl daemon-reload
    systemctl enable n8n
    systemctl start n8n
    
    success "N8N installed with systemd"
}

# ============================================================================
# STEP 6: WAIT FOR N8N TO START
# ============================================================================

wait_for_n8n() {
    log "⏳ WAITING FOR N8N TO START"
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        local response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5678 2>/dev/null || echo "000")
        
        if [[ "$response" =~ ^(200|401|302)$ ]]; then
            success "✅ N8N is responding (HTTP $response)"
            return 0
        fi
        
        echo "   Waiting for n8n... ($attempt/$max_attempts)"
        sleep 2
        ((attempt++))
    done
    
    error "❌ N8N failed to start within $((max_attempts * 2)) seconds"
    return 1
}

# ============================================================================
# STEP 7: VERIFY INSTALLATION
# ============================================================================

verify_installation() {
    log "✅ VERIFYING INSTALLATION"
    
    # Check if n8n is responding
    local response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5678 2>/dev/null || echo "000")
    
    if [[ "$response" =~ ^(200|401|302)$ ]]; then
        success "✅ N8N is accessible (HTTP $response)"
        
        # Check nginx proxy
        local nginx_response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1 2>/dev/null || echo "000")
        if [[ "$nginx_response" =~ ^(200|401|302)$ ]]; then
            success "✅ Nginx proxy working (HTTP $nginx_response)"
        else
            warning "⚠️ Nginx proxy not working (HTTP $nginx_response)"
        fi
        
        return 0
    else
        error "❌ N8N not accessible (HTTP $response)"
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
    echo "🔧 N8N DOCKER/PM2 CONFUSION FIX COMPLETED"
    echo "============================================"
    echo ""
    
    local response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5678 2>/dev/null || echo "000")
    local nginx_response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1 2>/dev/null || echo "000")
    
    if [[ "$response" =~ ^(200|401|302)$ ]]; then
        echo "✅ N8N STATUS: RUNNING"
        echo "🔧 Installation method: $install_method"
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
        case $install_method in
            "pm2")
                echo "   📦 PM2 status: pm2 status"
                echo "   📦 PM2 logs: pm2 logs n8n"
                echo "   📦 PM2 restart: pm2 restart n8n"
                ;;
            "docker")
                echo "   🐳 Docker status: docker ps"
                echo "   🐳 Docker logs: docker logs n8n"
                echo "   🐳 Docker restart: docker restart n8n"
                ;;
            "systemd")
                echo "   ⚙️ Service status: systemctl status n8n"
                echo "   ⚙️ Service logs: journalctl -u n8n -f"
                echo "   ⚙️ Service restart: systemctl restart n8n"
                ;;
        esac
    else
        echo "❌ N8N STATUS: NOT RUNNING"
        echo "📊 Direct access: HTTP $response"
        echo "📊 Nginx proxy: HTTP $nginx_response"
        echo ""
        echo "🔧 TROUBLESHOOTING:"
        echo "   1. Check installation method: $install_method"
        case $install_method in
            "pm2")
                echo "   2. Check PM2: pm2 status"
                echo "   3. Check PM2 logs: pm2 logs n8n"
                ;;
            "docker")
                echo "   2. Check Docker: docker ps"
                echo "   3. Check Docker logs: docker logs n8n"
                ;;
            "systemd")
                echo "   2. Check service: systemctl status n8n"
                echo "   3. Check logs: journalctl -u n8n -f"
                ;;
        esac
    fi
    
    echo ""
    echo "============================================"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    log "🔧 Starting n8n Docker/PM2 confusion fix..."
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root (use sudo)"
        exit 1
    fi
    
    echo -e "${YELLOW}⚠️  This will stop all n8n processes and reinstall with a single method${NC}"
    echo ""
    read -p "Continue with n8n confusion fix? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "N8N confusion fix cancelled."
        exit 0
    fi
    
    # Execute fix steps
    analyze_current_state
    stop_all_n8n
    cleanup_installations
    choose_installation_method
    
    case $install_method in
        "pm2")
            install_n8n_pm2
            ;;
        "docker")
            install_n8n_docker
            ;;
        "systemd")
            install_n8n_systemd
            ;;
    esac
    
    if wait_for_n8n && verify_installation; then
        success "🎉 N8N CONFUSION FIX COMPLETED SUCCESSFULLY"
    else
        error "❌ N8N confusion fix completed but n8n is not responding"
    fi
    
    show_final_status
}

# Run main function
main "$@"

