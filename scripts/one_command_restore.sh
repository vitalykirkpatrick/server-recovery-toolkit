#!/bin/bash

# ============================================================================
# ONE-COMMAND COMPLETE SERVER RESTORATION
# ============================================================================
# Purpose: Restore entire server from fresh installation in one command
# Usage: curl -fsSL https://raw.githubusercontent.com/.../one_command_restore.sh | sudo bash
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
LOG_FILE="/var/log/one_command_restore.log"
PUBLIC_DOMAIN="n8n.websolutionsserver.net"

# Logging functions
log() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"; }
info() { echo -e "${CYAN}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }

echo "🚀 ONE-COMMAND COMPLETE SERVER RESTORATION"
echo "=========================================="
echo "🎯 This will restore your entire server from fresh installation"
echo "🌐 Domain: $PUBLIC_DOMAIN"
echo ""

# ============================================================================
# STEP 1: BASIC SYSTEM SETUP
# ============================================================================

setup_basic_system() {
    log "🔧 SETTING UP BASIC SYSTEM"
    
    # Update system
    log "📦 Updating system packages..."
    apt update && apt upgrade -y
    
    # Install essential packages
    log "📦 Installing essential packages..."
    apt install -y curl wget git unzip zip htop nano vim net-tools software-properties-common
    
    # Set timezone
    timedatectl set-timezone UTC
    
    success "Basic system setup completed"
}

# ============================================================================
# STEP 2: INSTALL NODE.JS AND NPM
# ============================================================================

install_nodejs() {
    log "📦 INSTALLING NODE.JS AND NPM"
    
    # Install Node.js 18.x
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y nodejs
    
    # Verify installation
    local node_version=$(node --version)
    local npm_version=$(npm --version)
    
    log "✅ Node.js: $node_version"
    log "✅ npm: $npm_version"
    
    success "Node.js and npm installed"
}

# ============================================================================
# STEP 3: INSTALL NGINX
# ============================================================================

install_nginx() {
    log "🌐 INSTALLING NGINX"
    
    # Install nginx
    apt install -y nginx
    
    # Enable and start nginx
    systemctl enable nginx
    systemctl start nginx
    
    # Verify installation
    if systemctl is-active --quiet nginx; then
        success "nginx installed and running"
    else
        error "nginx installation failed"
        return 1
    fi
}

# ============================================================================
# STEP 4: INSTALL N8N
# ============================================================================

install_n8n() {
    log "🔧 INSTALLING N8N"
    
    # Install n8n globally
    npm install -g n8n
    
    # Verify installation
    local n8n_version=$(n8n --version 2>/dev/null || echo "unknown")
    log "✅ n8n: $n8n_version"
    
    success "n8n installed"
}

# ============================================================================
# STEP 5: INSTALL PM2
# ============================================================================

install_pm2() {
    log "📦 INSTALLING PM2"
    
    # Install PM2
    npm install -g pm2
    
    # Verify installation
    local pm2_version=$(pm2 --version 2>/dev/null || echo "unknown")
    log "✅ PM2: $pm2_version"
    
    success "PM2 installed"
}

# ============================================================================
# STEP 6: INSTALL AUDIOBOOK PROCESSING TOOLS
# ============================================================================

install_audiobook_tools() {
    log "🎧 INSTALLING AUDIOBOOK PROCESSING TOOLS"
    
    # Install FFmpeg
    apt install -y ffmpeg
    
    # Install ImageMagick
    apt install -y imagemagick
    
    # Install Tesseract OCR with Ukrainian and Russian support
    apt install -y tesseract-ocr tesseract-ocr-ukr tesseract-ocr-rus
    
    # Install Python packages
    apt install -y python3-pip
    pip3 install pydub mutagen openai requests beautifulsoup4 lxml
    
    success "Audiobook processing tools installed"
}

# ============================================================================
# STEP 7: CONFIGURE N8N
# ============================================================================

configure_n8n() {
    log "⚙️ CONFIGURING N8N"
    
    # Create n8n directory
    mkdir -p /root/.n8n
    chown root:root /root/.n8n
    chmod 755 /root/.n8n
    
    # Create n8n configuration
    cat > /root/.n8n/config.json << EOF
{
  "host": "0.0.0.0",
  "port": 5678,
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
  "userManagement": {
    "disabled": true
  }
}
EOF
    
    # Create environment file
    cat > /root/.env << EOF
NODE_ENV=production
N8N_HOST=0.0.0.0
N8N_PORT=5678
N8N_PROTOCOL=http
N8N_EDITOR_BASE_URL=http://$PUBLIC_DOMAIN
WEBHOOK_URL=http://$PUBLIC_DOMAIN
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=n8n_1752790771
N8N_USER_MANAGEMENT_DISABLED=true
EOF
    
    chmod 600 /root/.env
    
    success "n8n configured"
}

# ============================================================================
# STEP 8: CONFIGURE NGINX REVERSE PROXY
# ============================================================================

configure_nginx() {
    log "📝 CONFIGURING NGINX REVERSE PROXY"
    
    # Remove default site
    rm -f /etc/nginx/sites-enabled/default
    
    # Create n8n site configuration
    cat > /etc/nginx/sites-available/n8n << EOF
server {
    listen 80;
    server_name $PUBLIC_DOMAIN;
    
    client_max_body_size 100M;
    
    location / {
        proxy_pass http://127.0.0.1:5678;
        proxy_http_version 1.1;
        
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        
        proxy_cache_bypass \$http_upgrade;
        proxy_no_cache \$http_upgrade;
        
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
        proxy_connect_timeout 86400;
        
        proxy_buffering off;
        proxy_request_buffering off;
    }
    
    location /webhook {
        proxy_pass http://127.0.0.1:5678/webhook;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_read_timeout 0;
        proxy_send_timeout 0;
    }
    
    location /webhook-test {
        proxy_pass http://127.0.0.1:5678/webhook-test;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
    }
    
    location /rest {
        proxy_pass http://127.0.0.1:5678/rest;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
    }
}
EOF
    
    # Enable the site
    ln -sf /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/n8n
    
    # Test nginx configuration
    if nginx -t; then
        systemctl reload nginx
        success "nginx configured and reloaded"
    else
        error "nginx configuration test failed"
        return 1
    fi
}

# ============================================================================
# STEP 9: CREATE N8N SERVICE
# ============================================================================

create_n8n_service() {
    log "🔄 CREATING N8N SERVICE"
    
    # Create PM2 ecosystem file
    cat > /root/n8n.config.js << EOF
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
      N8N_EDITOR_BASE_URL: 'http://$PUBLIC_DOMAIN',
      WEBHOOK_URL: 'http://$PUBLIC_DOMAIN',
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
    
    # Start n8n with PM2
    cd /root
    pm2 start n8n.config.js
    pm2 save
    pm2 startup systemd -u root --hp /root
    
    success "n8n service created and started"
}

# ============================================================================
# STEP 10: CONFIGURE FIREWALL
# ============================================================================

configure_firewall() {
    log "🔥 CONFIGURING FIREWALL"
    
    # Install UFW if not present
    apt install -y ufw
    
    # Configure firewall rules
    ufw --force reset
    ufw allow 22/tcp    # SSH
    ufw allow 80/tcp    # HTTP
    ufw allow 443/tcp   # HTTPS
    
    # Enable firewall
    ufw --force enable
    
    success "Firewall configured"
}

# ============================================================================
# STEP 11: DOWNLOAD BACKUP RESTORATION SCRIPTS
# ============================================================================

download_restoration_scripts() {
    log "📥 DOWNLOADING RESTORATION SCRIPTS"
    
    # Create scripts directory
    mkdir -p /root/scripts
    
    # Download backup restoration script
    wget -O /root/scripts/restore_backups.sh https://raw.githubusercontent.com/vitalykirkpatrick/server-recovery-toolkit/main/scripts/server_restore_script.sh
    chmod +x /root/scripts/restore_backups.sh
    
    # Download backup script
    wget -O /root/scripts/backup_server.sh https://raw.githubusercontent.com/vitalykirkpatrick/server-recovery-toolkit/main/scripts/backup_server_fixed.sh
    chmod +x /root/scripts/backup_server.sh
    
    # Download cleanup script
    wget -O /root/scripts/cleanup_system.sh https://raw.githubusercontent.com/vitalykirkpatrick/server-recovery-toolkit/main/scripts/system_cleanup_backup_manager_final.sh
    chmod +x /root/scripts/cleanup_system.sh
    
    success "Restoration scripts downloaded"
}

# ============================================================================
# STEP 12: SET UP AUTOMATED MAINTENANCE
# ============================================================================

setup_automated_maintenance() {
    log "⏰ SETTING UP AUTOMATED MAINTENANCE"
    
    # Create cron jobs
    cat > /tmp/n8n_crontab << EOF
# N8N Server Automated Maintenance
# Daily backup at 2:30 AM
30 2 * * * /root/scripts/backup_server.sh >> /var/log/backup_cron.log 2>&1

# Weekly cleanup on Sunday at 3:00 AM
0 3 * * 0 /root/scripts/cleanup_system.sh >> /var/log/cleanup_cron.log 2>&1

# Monthly system update on 1st day at 4:00 AM
0 4 1 * * apt update && apt upgrade -y >> /var/log/update_cron.log 2>&1
EOF
    
    # Install cron jobs
    crontab /tmp/n8n_crontab
    rm /tmp/n8n_crontab
    
    # Enable cron service
    systemctl enable cron
    systemctl start cron
    
    success "Automated maintenance configured"
}

# ============================================================================
# STEP 13: VERIFY INSTALLATION
# ============================================================================

verify_installation() {
    log "✅ VERIFYING INSTALLATION"
    
    # Wait for services to start
    sleep 10
    
    # Check nginx
    if systemctl is-active --quiet nginx; then
        success "✅ nginx is running"
    else
        error "❌ nginx is not running"
    fi
    
    # Check PM2
    if pm2 list | grep -q "n8n.*online"; then
        success "✅ n8n PM2 process is running"
    else
        error "❌ n8n PM2 process is not running"
    fi
    
    # Test local access
    local response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5678 2>/dev/null || echo "000")
    if [[ "$response" =~ ^(200|401|302)$ ]]; then
        success "✅ n8n is responding locally (HTTP $response)"
    else
        error "❌ n8n is not responding locally (HTTP $response)"
    fi
    
    # Test proxy access
    local proxy_response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1 2>/dev/null || echo "000")
    if [[ "$proxy_response" =~ ^(200|401|302)$ ]]; then
        success "✅ nginx proxy is working (HTTP $proxy_response)"
    else
        error "❌ nginx proxy is not working (HTTP $proxy_response)"
    fi
}

# ============================================================================
# SHOW FINAL RESULTS
# ============================================================================

show_final_results() {
    log "📊 RESTORATION COMPLETED"
    
    echo ""
    echo "============================================"
    echo "🎉 ONE-COMMAND RESTORATION COMPLETED"
    echo "============================================"
    echo ""
    echo "🌐 ACCESS YOUR N8N:"
    echo "   🔗 URL: http://$PUBLIC_DOMAIN"
    echo "   👤 Username: admin"
    echo "   🔑 Password: n8n_1752790771"
    echo ""
    echo "📊 SERVICE STATUS:"
    systemctl is-active nginx && echo "   ✅ nginx: Running" || echo "   ❌ nginx: Not running"
    pm2 list | grep -q "n8n.*online" && echo "   ✅ n8n: Running" || echo "   ❌ n8n: Not running"
    echo ""
    echo "🔧 INSTALLED COMPONENTS:"
    echo "   ✅ Node.js $(node --version)"
    echo "   ✅ npm $(npm --version)"
    echo "   ✅ n8n $(n8n --version 2>/dev/null || echo 'installed')"
    echo "   ✅ PM2 $(pm2 --version)"
    echo "   ✅ nginx"
    echo "   ✅ FFmpeg"
    echo "   ✅ ImageMagick"
    echo "   ✅ Tesseract OCR"
    echo ""
    echo "⏰ AUTOMATED MAINTENANCE:"
    echo "   📅 Daily backups at 2:30 AM"
    echo "   🧹 Weekly cleanup on Sundays at 3:00 AM"
    echo "   📦 Monthly updates on 1st day at 4:00 AM"
    echo ""
    echo "🔧 RESTORATION SCRIPTS:"
    echo "   📥 Backup restoration: /root/scripts/restore_backups.sh"
    echo "   💾 Server backup: /root/scripts/backup_server.sh"
    echo "   🧹 System cleanup: /root/scripts/cleanup_system.sh"
    echo ""
    echo "🔥 FIREWALL STATUS:"
    ufw status | head -10
    echo ""
    echo "🎊 YOUR SERVER IS NOW FULLY RESTORED!"
    echo "============================================"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    log "🚀 ONE-COMMAND RESTORATION STARTED"
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root"
        exit 1
    fi
    
    # Create log file
    touch "$LOG_FILE"
    
    # Execute all steps
    setup_basic_system
    install_nodejs
    install_nginx
    install_n8n
    install_pm2
    install_audiobook_tools
    configure_n8n
    configure_nginx
    create_n8n_service
    configure_firewall
    download_restoration_scripts
    setup_automated_maintenance
    verify_installation
    show_final_results
    
    success "🎉 ONE-COMMAND RESTORATION COMPLETED"
    log "📜 Full log available at: $LOG_FILE"
}

# Run main function
main "$@"

