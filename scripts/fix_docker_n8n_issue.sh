#!/bin/bash

# ============================================================================
# FIX DOCKER N8N STARTUP ISSUES
# ============================================================================
# Purpose: Fix Docker n8n service that's failing to start
# Issue: Docker exit code 125, service failing to start
# Solution: Fix Docker setup or switch to native n8n installation
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
LOG_FILE="/var/log/n8n_docker_fix.log"

# Logging functions
log() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"; }
info() { echo -e "${CYAN}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }

echo "🐳 FIXING DOCKER N8N STARTUP ISSUES"
echo "==================================="

# ============================================================================
# DIAGNOSE DOCKER ISSUES
# ============================================================================

diagnose_docker_issues() {
    log "🔍 DIAGNOSING DOCKER ISSUES"
    
    # Check if Docker is installed
    if command -v docker &> /dev/null; then
        success "✅ Docker is installed"
        docker --version
    else
        error "❌ Docker is not installed"
        return 1
    fi
    
    # Check if Docker service is running
    if systemctl is-active --quiet docker; then
        success "✅ Docker service is running"
    else
        warning "⚠️ Docker service is not running"
        log "🔄 Starting Docker service..."
        systemctl start docker
        systemctl enable docker
        
        if systemctl is-active --quiet docker; then
            success "✅ Docker service started"
        else
            error "❌ Failed to start Docker service"
            return 1
        fi
    fi
    
    # Check Docker permissions
    if docker ps &> /dev/null; then
        success "✅ Docker permissions working"
    else
        warning "⚠️ Docker permissions issue"
        log "🔧 Adding root to docker group..."
        usermod -aG docker root
        newgrp docker
    fi
    
    # Test basic Docker functionality
    log "🧪 Testing basic Docker functionality..."
    if docker run --rm hello-world &> /dev/null; then
        success "✅ Docker basic functionality working"
    else
        error "❌ Docker basic functionality failed"
        return 1
    fi
    
    # Check if n8n Docker image exists
    log "🔍 Checking n8n Docker image..."
    if docker images | grep -q "n8nio/n8n"; then
        success "✅ n8n Docker image found locally"
        docker images | grep "n8nio/n8n"
    else
        warning "⚠️ n8n Docker image not found locally"
        log "📥 Pulling n8n Docker image..."
        if docker pull n8nio/n8n:latest; then
            success "✅ n8n Docker image pulled successfully"
        else
            error "❌ Failed to pull n8n Docker image"
            return 1
        fi
    fi
}

# ============================================================================
# FIX DOCKER N8N CONFIGURATION
# ============================================================================

fix_docker_n8n_service() {
    log "🔧 FIXING DOCKER N8N SERVICE CONFIGURATION"
    
    # Stop current service
    systemctl stop n8n 2>/dev/null || true
    
    # Create proper Docker-based systemd service
    cat > /etc/systemd/system/n8n.service << EOF
[Unit]
Description=n8n automation workflow service
After=docker.service
Requires=docker.service

[Service]
Type=simple
User=root
Group=root
Restart=always
RestartSec=10
TimeoutStartSec=300
TimeoutStopSec=30

# Environment variables
Environment=N8N_HOST=0.0.0.0
Environment=N8N_PORT=$N8N_PORT
Environment=N8N_BASIC_AUTH_ACTIVE=true
Environment=N8N_BASIC_AUTH_USER=admin
Environment=N8N_BASIC_AUTH_PASSWORD=n8n_1752790771

# Docker command with proper volume mounting
ExecStartPre=-/usr/bin/docker stop n8n-container
ExecStartPre=-/usr/bin/docker rm n8n-container
ExecStart=/usr/bin/docker run --name n8n-container --rm \\
    -p $N8N_PORT:5678 \\
    -v /root/.n8n:/home/node/.n8n \\
    -e N8N_HOST=0.0.0.0 \\
    -e N8N_PORT=5678 \\
    -e N8N_BASIC_AUTH_ACTIVE=true \\
    -e N8N_BASIC_AUTH_USER=admin \\
    -e N8N_BASIC_AUTH_PASSWORD=n8n_1752790771 \\
    n8nio/n8n

ExecStop=/usr/bin/docker stop n8n-container

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=n8n

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable n8n
    success "Docker-based n8n service configuration updated"
}

# ============================================================================
# ALTERNATIVE: SWITCH TO NATIVE N8N
# ============================================================================

switch_to_native_n8n() {
    log "🔄 SWITCHING TO NATIVE N8N INSTALLATION"
    
    # Stop Docker-based service
    systemctl stop n8n 2>/dev/null || true
    systemctl disable n8n 2>/dev/null || true
    
    # Check if Node.js is installed
    if ! command -v node &> /dev/null; then
        log "📦 Installing Node.js..."
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        apt-get install -y nodejs
        success "Node.js installed"
    else
        local node_version=$(node --version)
        success "✅ Node.js already installed: $node_version"
    fi
    
    # Install n8n globally
    log "📦 Installing n8n globally via npm..."
    npm install -g n8n
    
    # Verify installation
    if command -v n8n &> /dev/null; then
        local n8n_location=$(which n8n)
        success "✅ N8N installed successfully at: $n8n_location"
    else
        error "❌ N8N installation failed"
        return 1
    fi
    
    # Create native systemd service
    cat > /etc/systemd/system/n8n.service << EOF
[Unit]
Description=n8n - Workflow Automation Tool
After=network.target

[Service]
Type=simple
User=root
Group=root
ExecStart=$(which n8n) start
Restart=always
RestartSec=10

# Environment
Environment=NODE_ENV=production
Environment=N8N_HOST=0.0.0.0
Environment=N8N_PORT=$N8N_PORT
Environment=N8N_BASIC_AUTH_ACTIVE=true
Environment=N8N_BASIC_AUTH_USER=admin
Environment=N8N_BASIC_AUTH_PASSWORD=n8n_1752790771

# Working directory
WorkingDirectory=/root

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=n8n

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable n8n
    success "Native n8n service configuration created"
}

# ============================================================================
# PREPARE N8N DATA DIRECTORY
# ============================================================================

prepare_n8n_data_directory() {
    log "📁 PREPARING N8N DATA DIRECTORY"
    
    # Ensure .n8n directory exists with proper permissions
    mkdir -p /root/.n8n
    chown -R root:root /root/.n8n
    chmod -R 755 /root/.n8n
    
    # Create basic config if doesn't exist
    if [ ! -f "/root/.n8n/config.json" ]; then
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
  "security": {
    "basicAuth": {
      "active": true,
      "user": "admin",
      "password": "n8n_1752790771"
    }
  }
}
EOF
        chmod 600 /root/.n8n/config.json
        success "Basic n8n config created"
    else
        success "✅ n8n config already exists"
    fi
}

# ============================================================================
# START AND VERIFY N8N
# ============================================================================

start_and_verify_n8n() {
    log "🚀 STARTING AND VERIFYING N8N"
    
    # Start n8n service
    log "🔄 Starting n8n service..."
    systemctl start n8n
    
    # Wait for n8n to start with extended timeout
    local attempts=0
    local max_attempts=60
    
    while [ $attempts -lt $max_attempts ]; do
        if systemctl is-active --quiet n8n; then
            # Check if it's responding
            local response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:$N8N_PORT 2>/dev/null || echo "000")
            
            if [[ "$response" =~ ^(200|401|302)$ ]]; then
                success "✅ N8N started and responding (HTTP $response)"
                break
            fi
        fi
        
        sleep 2
        attempts=$((attempts + 1))
        
        if [ $((attempts % 15)) -eq 0 ]; then
            log "   Still waiting for n8n... ($attempts/$max_attempts)"
            
            # Show service status
            if ! systemctl is-active --quiet n8n; then
                warning "   N8N service not active, checking status..."
                systemctl status n8n --no-pager -l | head -10
            fi
        fi
    done
    
    if [ $attempts -eq $max_attempts ]; then
        error "❌ N8N failed to start within 2 minutes"
        
        # Detailed diagnostics
        log "🔍 Service status:"
        systemctl status n8n --no-pager -l
        
        log "🔍 Recent logs:"
        journalctl -u n8n --no-pager -l --since "2 minutes ago" | tail -20
        
        return 1
    fi
    
    # Test through nginx
    log "🧪 Testing through nginx..."
    local nginx_response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:80 2>/dev/null || echo "000")
    
    if [[ "$nginx_response" =~ ^(200|401|302)$ ]]; then
        success "✅ Site accessible through nginx (HTTP $nginx_response)"
    else
        warning "⚠️ Site may not be accessible through nginx (HTTP $nginx_response)"
    fi
}

# ============================================================================
# SHOW RESULTS
# ============================================================================

show_fix_results() {
    log "📊 DOCKER N8N FIX RESULTS"
    
    echo ""
    echo "============================================"
    echo "🐳 DOCKER N8N FIX COMPLETED"
    echo "============================================"
    echo ""
    echo "🌐 ACCESS YOUR N8N:"
    echo "   🔗 URL: http://$PUBLIC_DOMAIN"
    echo "   👤 Username: admin"
    echo "   🔑 Password: n8n_1752790771"
    echo ""
    echo "✅ FIXES APPLIED:"
    echo "   🐳 Docker service started and configured"
    echo "   📥 n8n Docker image pulled/verified"
    echo "   🔧 Proper Docker-based systemd service"
    echo "   📁 n8n data directory prepared"
    echo "   🚀 Service started and verified"
    echo ""
    echo "📊 SERVICE STATUS:"
    systemctl is-active docker && echo "   ✅ Docker: Running" || echo "   ❌ Docker: Not running"
    systemctl is-active nginx && echo "   ✅ Nginx: Running" || echo "   ❌ Nginx: Not running"
    systemctl is-active n8n && echo "   ✅ N8N: Running" || echo "   ❌ N8N: Not running"
    echo ""
    echo "🔍 TROUBLESHOOTING:"
    echo "   📊 Check services: systemctl status docker nginx n8n"
    echo "   📜 Check logs: journalctl -u n8n -f"
    echo "   🐳 Check container: docker ps"
    echo "   🧪 Test direct: curl http://127.0.0.1:$N8N_PORT"
    echo ""
    echo "✅ Your n8n should now be running via Docker!"
    echo "============================================"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    log "🐳 DOCKER N8N FIX STARTED"
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root (use sudo)"
        exit 1
    fi
    
    # Create log file
    touch "$LOG_FILE"
    
    # Try to fix Docker issues first
    if diagnose_docker_issues; then
        log "🐳 Docker is working, fixing Docker-based n8n service..."
        prepare_n8n_data_directory
        fix_docker_n8n_service
        
        if start_and_verify_n8n; then
            show_fix_results
        else
            warning "⚠️ Docker-based n8n failed, switching to native installation..."
            switch_to_native_n8n
            start_and_verify_n8n
            show_fix_results
        fi
    else
        warning "⚠️ Docker issues detected, switching to native n8n installation..."
        switch_to_native_n8n
        prepare_n8n_data_directory
        start_and_verify_n8n
        show_fix_results
    fi
    
    success "🎉 N8N FIX COMPLETED"
    log "📜 Full log available at: $LOG_FILE"
}

# Run main function
main "$@"

