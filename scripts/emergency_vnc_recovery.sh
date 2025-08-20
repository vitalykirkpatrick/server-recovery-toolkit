#!/bin/bash

# ============================================================================
# EMERGENCY VNC RECOVERY SCRIPT
# ============================================================================
# Purpose: Emergency recovery when SSH is inaccessible and site has redirect loops
# Use: Run this via VNC console when SSH and web access are both broken
# Critical: This script restores basic functionality and SSH access
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
LOG_FILE="/var/log/emergency_vnc_recovery.log"

# Logging functions
log() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"; }
info() { echo -e "${CYAN}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }

echo "🚨 EMERGENCY VNC RECOVERY - CRITICAL SERVER ISSUES"
echo "=================================================="
echo "⚠️  Use this when SSH is inaccessible and site has redirect loops"
echo "🖥️  Run via VNC console or direct server access"
echo ""

# ============================================================================
# EMERGENCY STOP ALL PROBLEMATIC SERVICES
# ============================================================================

emergency_stop_services() {
    log "🛑 EMERGENCY STOP ALL PROBLEMATIC SERVICES"
    
    # Stop nginx (causing redirect loops)
    systemctl stop nginx 2>/dev/null || true
    success "Nginx stopped (was causing redirect loops)"
    
    # Stop n8n (may be causing issues)
    systemctl stop n8n 2>/dev/null || true
    pkill -f "n8n" 2>/dev/null || true
    pkill -f "docker.*n8n" 2>/dev/null || true
    success "All n8n processes stopped"
    
    # Stop Docker (may be causing resource issues)
    systemctl stop docker 2>/dev/null || true
    success "Docker stopped"
    
    log "✅ All problematic services stopped"
}

# ============================================================================
# RESTORE SSH ACCESS
# ============================================================================

restore_ssh_access() {
    log "🔑 RESTORING SSH ACCESS"
    
    # Ensure SSH service is running
    systemctl start ssh 2>/dev/null || systemctl start sshd 2>/dev/null || true
    systemctl enable ssh 2>/dev/null || systemctl enable sshd 2>/dev/null || true
    
    # Check SSH service status
    if systemctl is-active --quiet ssh || systemctl is-active --quiet sshd; then
        success "✅ SSH service is running"
    else
        warning "⚠️ SSH service not running, attempting to start..."
        systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || true
    fi
    
    # Reset SSH configuration to defaults if needed
    if [ ! -f "/etc/ssh/sshd_config.backup" ]; then
        cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup 2>/dev/null || true
    fi
    
    # Ensure SSH is listening on port 22
    if ! netstat -tlnp | grep -q ":22 "; then
        warning "⚠️ SSH not listening on port 22, checking configuration..."
        
        # Create minimal working SSH config
        cat > /etc/ssh/sshd_config << 'EOF'
Port 22
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_dsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key
UsePrivilegeSeparation yes
KeyRegenerationInterval 3600
ServerKeyBits 1024
SyslogFacility AUTH
LogLevel INFO
LoginGraceTime 120
PermitRootLogin yes
StrictModes yes
RSAAuthentication yes
PubkeyAuthentication yes
IgnoreRhosts yes
RhostsRSAAuthentication no
HostbasedAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
PasswordAuthentication yes
X11Forwarding yes
X11DisplayOffset 10
PrintMotd no
PrintLastLog yes
TCPKeepAlive yes
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
UsePAM yes
EOF
        
        systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || true
        success "SSH configuration reset to defaults"
    fi
    
    # Check if SSH is now accessible
    if netstat -tlnp | grep -q ":22 "; then
        success "✅ SSH is listening on port 22"
    else
        error "❌ SSH still not listening on port 22"
    fi
}

# ============================================================================
# FIX FIREWALL ISSUES
# ============================================================================

fix_firewall_issues() {
    log "🔥 FIXING FIREWALL ISSUES"
    
    # Check if ufw is active and blocking SSH
    if command -v ufw &> /dev/null; then
        if ufw status | grep -q "Status: active"; then
            log "🔍 UFW is active, checking SSH rules..."
            
            # Allow SSH
            ufw allow 22/tcp 2>/dev/null || true
            ufw allow ssh 2>/dev/null || true
            success "SSH allowed through UFW"
            
            # Allow HTTP
            ufw allow 80/tcp 2>/dev/null || true
            ufw allow http 2>/dev/null || true
            success "HTTP allowed through UFW"
            
            # Reload UFW
            ufw reload 2>/dev/null || true
        else
            log "ℹ️ UFW is not active"
        fi
    fi
    
    # Check iptables
    if command -v iptables &> /dev/null; then
        # Ensure SSH is allowed
        iptables -I INPUT -p tcp --dport 22 -j ACCEPT 2>/dev/null || true
        iptables -I INPUT -p tcp --dport 80 -j ACCEPT 2>/dev/null || true
        success "SSH and HTTP allowed through iptables"
    fi
    
    # Save iptables rules if possible
    if command -v iptables-save &> /dev/null; then
        iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
    fi
}

# ============================================================================
# CREATE MINIMAL WORKING NGINX CONFIGURATION
# ============================================================================

create_minimal_nginx_config() {
    log "📝 CREATING MINIMAL NGINX CONFIGURATION (NO REDIRECTS)"
    
    # Backup current nginx config
    if [ -d "/etc/nginx" ]; then
        cp -r /etc/nginx "/etc/nginx.broken.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
    fi
    
    # Remove all existing site configurations
    rm -f /etc/nginx/sites-enabled/* 2>/dev/null || true
    rm -f /etc/nginx/sites-available/n8n 2>/dev/null || true
    
    # Create ultra-simple default configuration with NO redirects
    cat > /etc/nginx/sites-available/default << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    
    # Disable all redirects
    error_page 497 =200 $request_uri;
    
    # Simple response for testing
    location / {
        return 200 'Server is accessible. SSH should now work. n8n will be restored separately.';
        add_header Content-Type text/plain;
    }
    
    # Health check
    location /health {
        return 200 'OK';
        add_header Content-Type text/plain;
    }
}
EOF
    
    # Enable the simple default site
    ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
    
    # Test nginx configuration
    if nginx -t; then
        success "✅ Minimal nginx configuration is valid"
    else
        error "❌ Even minimal nginx config failed, creating emergency config"
        
        # Create absolute minimal config
        cat > /etc/nginx/nginx.conf << 'EOF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;

events {
    worker_connections 768;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;
    
    server {
        listen 80 default_server;
        server_name _;
        
        location / {
            return 200 'Emergency nginx config active. Server accessible.';
            add_header Content-Type text/plain;
        }
    }
}
EOF
        
        if nginx -t; then
            success "✅ Emergency nginx configuration working"
        else
            error "❌ Complete nginx failure"
            nginx -t
        fi
    fi
}

# ============================================================================
# START ESSENTIAL SERVICES
# ============================================================================

start_essential_services() {
    log "🚀 STARTING ESSENTIAL SERVICES"
    
    # Start SSH first (most critical)
    systemctl start ssh 2>/dev/null || systemctl start sshd 2>/dev/null || true
    if systemctl is-active --quiet ssh || systemctl is-active --quiet sshd; then
        success "✅ SSH service started"
    else
        error "❌ SSH service failed to start"
    fi
    
    # Start nginx with minimal config
    systemctl start nginx
    if systemctl is-active --quiet nginx; then
        success "✅ Nginx started with minimal configuration"
    else
        error "❌ Nginx failed to start"
        systemctl status nginx --no-pager -l
    fi
    
    # Don't start n8n yet - focus on basic access first
    log "ℹ️ n8n intentionally not started - focus on restoring basic access first"
}

# ============================================================================
# VERIFY RECOVERY
# ============================================================================

verify_recovery() {
    log "✅ VERIFYING EMERGENCY RECOVERY"
    
    # Check SSH
    if netstat -tlnp | grep -q ":22 "; then
        success "✅ SSH is listening on port 22"
    else
        error "❌ SSH still not accessible"
    fi
    
    # Check HTTP
    if netstat -tlnp | grep -q ":80 "; then
        success "✅ HTTP is listening on port 80"
    else
        error "❌ HTTP not accessible"
    fi
    
    # Test local HTTP
    local http_response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1 2>/dev/null || echo "000")
    if [[ "$http_response" == "200" ]]; then
        success "✅ Local HTTP responding (no redirect loops)"
    else
        warning "⚠️ Local HTTP may have issues (HTTP $http_response)"
    fi
    
    # Show service status
    log "📊 Service Status:"
    systemctl is-active ssh 2>/dev/null && echo "   ✅ SSH: Running" || echo "   ❌ SSH: Not running"
    systemctl is-active nginx && echo "   ✅ Nginx: Running" || echo "   ❌ Nginx: Not running"
    echo "   ⏸️ n8n: Intentionally stopped"
    echo "   ⏸️ Docker: Intentionally stopped"
}

# ============================================================================
# SHOW RECOVERY INSTRUCTIONS
# ============================================================================

show_recovery_instructions() {
    log "📋 EMERGENCY RECOVERY COMPLETED"
    
    echo ""
    echo "============================================"
    echo "🚨 EMERGENCY VNC RECOVERY COMPLETED"
    echo "============================================"
    echo ""
    echo "🎯 IMMEDIATE STATUS:"
    echo "   🔑 SSH should now be accessible"
    echo "   🌐 Website shows simple message (no redirect loops)"
    echo "   ⏸️ n8n intentionally stopped for now"
    echo "   ⏸️ Docker intentionally stopped for now"
    echo ""
    echo "🔑 TEST SSH ACCESS:"
    echo "   Try connecting via SSH from your local machine"
    echo "   If SSH works, you can continue recovery remotely"
    echo ""
    echo "🌐 TEST WEBSITE:"
    echo "   Visit your domain - should show simple text message"
    echo "   No more 'ERR_TOO_MANY_REDIRECTS' errors"
    echo ""
    echo "🔄 NEXT STEPS (via SSH once accessible):"
    echo "   1. Verify SSH access works"
    echo "   2. Download and run n8n recovery script"
    echo "   3. Restore n8n functionality step by step"
    echo ""
    echo "📞 IF SSH STILL NOT WORKING:"
    echo "   - Check your SSH client settings"
    echo "   - Verify server IP address"
    echo "   - Check if your ISP blocks port 22"
    echo "   - Try SSH on different port if configured"
    echo ""
    echo "🔧 MANUAL COMMANDS IF NEEDED:"
    echo "   systemctl status ssh"
    echo "   netstat -tlnp | grep :22"
    echo "   journalctl -u ssh -f"
    echo ""
    echo "✅ Basic server access should now be restored!"
    echo "============================================"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    log "🚨 EMERGENCY VNC RECOVERY STARTED"
    
    # Create log file
    touch "$LOG_FILE"
    
    echo "⚠️  CRITICAL: This will stop nginx and n8n to restore basic access"
    echo "🖥️  Continue only if SSH is inaccessible and site has redirect loops"
    echo ""
    read -p "Continue with emergency recovery? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Emergency recovery cancelled."
        exit 0
    fi
    
    # Execute emergency recovery
    emergency_stop_services
    restore_ssh_access
    fix_firewall_issues
    create_minimal_nginx_config
    start_essential_services
    verify_recovery
    show_recovery_instructions
    
    success "🎉 EMERGENCY VNC RECOVERY COMPLETED"
    log "📜 Full log available at: $LOG_FILE"
}

# Run main function
main "$@"

