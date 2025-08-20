#!/bin/bash

# ============================================================================
# FRESH SERVER COMPLETE SETUP AND BACKUP RESTORATION
# ============================================================================
# Purpose: Complete fresh server setup with all programs and backup restoration
# Use: Run on a clean Ubuntu server to restore full functionality
# Includes: n8n, Node.js, nginx, Docker, PostgreSQL, and all audiobook tools
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
LOG_FILE="/var/log/fresh_server_setup.log"
BACKUP_REPO="https://github.com/vitalykirkpatrick/server-recovery-toolkit.git"

# Logging functions
log() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"; }
info() { echo -e "${CYAN}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }

echo "🚀 FRESH SERVER COMPLETE SETUP AND BACKUP RESTORATION"
echo "====================================================="
echo "🎯 This will install all programs and restore from backup"
echo "📦 Includes: n8n, Node.js, nginx, Docker, PostgreSQL, audiobook tools"
echo ""

# ============================================================================
# SYSTEM UPDATE AND BASIC PACKAGES
# ============================================================================

update_system_and_install_basics() {
    log "📦 UPDATING SYSTEM AND INSTALLING BASIC PACKAGES"
    
    # Update system
    apt-get update -y
    apt-get upgrade -y
    success "System updated"
    
    # Install essential packages
    apt-get install -y \
        curl \
        wget \
        git \
        unzip \
        zip \
        tar \
        gzip \
        htop \
        nano \
        vim \
        net-tools \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        gnupg \
        lsb-release \
        build-essential \
        python3 \
        python3-pip \
        ffmpeg \
        imagemagick \
        ghostscript \
        poppler-utils \
        tesseract-ocr \
        tesseract-ocr-ukr \
        tesseract-ocr-rus \
        ufw \
        fail2ban
    
    success "Basic packages installed"
}

# ============================================================================
# INSTALL NODE.JS AND NPM
# ============================================================================

install_nodejs() {
    log "📦 INSTALLING NODE.JS AND NPM"
    
    # Install Node.js 18.x LTS
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    apt-get install -y nodejs
    
    # Verify installation
    local node_version=$(node --version)
    local npm_version=$(npm --version)
    success "Node.js $node_version and npm $npm_version installed"
    
    # Install global npm packages
    npm install -g pm2 n8n
    success "Global npm packages installed (pm2, n8n)"
}

# ============================================================================
# INSTALL DOCKER
# ============================================================================

install_docker() {
    log "🐳 INSTALLING DOCKER"
    
    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    
    # Add root to docker group
    usermod -aG docker root
    
    # Verify installation
    docker --version
    success "Docker installed and configured"
}

# ============================================================================
# INSTALL NGINX
# ============================================================================

install_nginx() {
    log "📝 INSTALLING NGINX"
    
    # Install nginx
    apt-get install -y nginx
    
    # Start and enable nginx
    systemctl start nginx
    systemctl enable nginx
    
    # Configure firewall
    ufw allow 'Nginx Full'
    ufw allow ssh
    ufw --force enable
    
    success "Nginx installed and configured"
}

# ============================================================================
# INSTALL POSTGRESQL
# ============================================================================

install_postgresql() {
    log "🗄️ INSTALLING POSTGRESQL"
    
    # Install PostgreSQL
    apt-get install -y postgresql postgresql-contrib
    
    # Start and enable PostgreSQL
    systemctl start postgresql
    systemctl enable postgresql
    
    # Create n8n database and user
    sudo -u postgres psql << EOF
CREATE DATABASE n8n;
CREATE USER n8n WITH ENCRYPTED PASSWORD 'n8n_password_secure';
GRANT ALL PRIVILEGES ON DATABASE n8n TO n8n;
\q
EOF
    
    success "PostgreSQL installed with n8n database"
}

# ============================================================================
# INSTALL AUDIOBOOK PROCESSING TOOLS
# ============================================================================

install_audiobook_tools() {
    log "🎧 INSTALLING AUDIOBOOK PROCESSING TOOLS"
    
    # Install Python packages for audiobook processing
    pip3 install \
        pydub \
        mutagen \
        eyed3 \
        pillow \
        requests \
        beautifulsoup4 \
        lxml \
        selenium \
        openai \
        google-cloud-texttospeech \
        azure-cognitiveservices-speech \
        boto3
    
    # Install additional audio tools
    apt-get install -y \
        sox \
        lame \
        flac \
        vorbis-tools \
        mp3gain \
        normalize-audio \
        audacity
    
    success "Audiobook processing tools installed"
}

# ============================================================================
# DOWNLOAD AND RESTORE BACKUP FILES
# ============================================================================

download_and_restore_backup() {
    log "📥 DOWNLOADING AND RESTORING BACKUP FILES"
    
    # Create temporary directory for backup
    mkdir -p /tmp/backup_restore
    cd /tmp/backup_restore
    
    # Clone the backup repository
    git clone $BACKUP_REPO .
    
    # Find the most recent backup files
    local backup_files=($(find . -name "*.tar.gz" -type f | sort -r))
    
    if [ ${#backup_files[@]} -eq 0 ]; then
        warning "⚠️ No backup files found in repository"
        return 1
    fi
    
    log "📂 Found backup files:"
    for file in "${backup_files[@]}"; do
        log "   📄 $file"
    done
    
    # Use the most recent backup
    local latest_backup="${backup_files[0]}"
    log "📍 Using latest backup: $latest_backup"
    
    # Extract backup
    tar -xzf "$latest_backup" -C /tmp/backup_restore/
    
    # Restore n8n configuration
    if [ -d "/tmp/backup_restore/.n8n" ]; then
        cp -r /tmp/backup_restore/.n8n /root/
        chown -R root:root /root/.n8n
        success "✅ n8n configuration restored"
    fi
    
    # Restore environment files
    if [ -f "/tmp/backup_restore/.env" ]; then
        cp /tmp/backup_restore/.env /root/
        chmod 600 /root/.env
        success "✅ Environment file restored"
    fi
    
    # Restore nginx configuration
    if [ -d "/tmp/backup_restore/nginx" ]; then
        cp -r /tmp/backup_restore/nginx/* /etc/nginx/
        success "✅ Nginx configuration restored"
    fi
    
    # Restore workflows and data
    if [ -d "/tmp/backup_restore/workflows" ]; then
        mkdir -p /root/workflows
        cp -r /tmp/backup_restore/workflows/* /root/workflows/
        success "✅ Workflows restored"
    fi
    
    # Restore scripts and tools
    if [ -d "/tmp/backup_restore/scripts" ]; then
        mkdir -p /root/scripts
        cp -r /tmp/backup_restore/scripts/* /root/scripts/
        chmod +x /root/scripts/*.sh
        success "✅ Scripts and tools restored"
    fi
    
    # Clean up
    cd /root
    rm -rf /tmp/backup_restore
    success "Backup restoration completed"
}

# ============================================================================
# CONFIGURE N8N
# ============================================================================

configure_n8n() {
    log "⚙️ CONFIGURING N8N"
    
    # Create n8n configuration directory
    mkdir -p /root/.n8n
    
    # Create comprehensive n8n configuration
    cat > /root/.n8n/config.json << EOF
{
  "database": {
    "type": "postgresdb",
    "postgresdb": {
      "host": "localhost",
      "port": 5432,
      "database": "n8n",
      "user": "n8n",
      "password": "n8n_password_secure"
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
  "userManagement": {
    "disabled": true
  }
}
EOF
    
    # Create environment file
    cat > /root/.env << EOF
# N8N Configuration
N8N_HOST=0.0.0.0
N8N_PORT=$N8N_PORT
N8N_PROTOCOL=http
N8N_EDITOR_BASE_URL=http://$PUBLIC_DOMAIN
WEBHOOK_URL=http://$PUBLIC_DOMAIN

# Database
N8N_DATABASE_TYPE=postgresdb
N8N_DATABASE_POSTGRESDB_HOST=localhost
N8N_DATABASE_POSTGRESDB_PORT=5432
N8N_DATABASE_POSTGRESDB_DATABASE=n8n
N8N_DATABASE_POSTGRESDB_USER=n8n
N8N_DATABASE_POSTGRESDB_PASSWORD=n8n_password_secure

# Authentication
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=n8n_1752790771

# Security
N8N_SECURE_COOKIE=false
N8N_USER_MANAGEMENT_DISABLED=true

# Endpoints
N8N_ENDPOINT_REST=http://$PUBLIC_DOMAIN/rest
N8N_ENDPOINT_WEBHOOK=http://$PUBLIC_DOMAIN/webhook
N8N_ENDPOINT_WEBHOOK_WAITING=http://$PUBLIC_DOMAIN/webhook-waiting
N8N_ENDPOINT_WEBHOOK_TEST=http://$PUBLIC_DOMAIN/webhook-test
EOF
    
    chmod 600 /root/.env
    chown -R root:root /root/.n8n
    success "N8N configuration created"
}

# ============================================================================
# CONFIGURE NGINX
# ============================================================================

configure_nginx() {
    log "📝 CONFIGURING NGINX"
    
    # Remove default site
    rm -f /etc/nginx/sites-enabled/default
    
    # Create n8n site configuration
    cat > /etc/nginx/sites-available/n8n << EOF
server {
    listen 80;
    server_name $PUBLIC_DOMAIN;
    
    client_max_body_size 100M;
    
    location / {
        proxy_pass http://127.0.0.1:$N8N_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_cache_bypass \$http_upgrade;
        
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
        proxy_connect_timeout 86400;
    }
}
EOF
    
    # Enable the site
    ln -sf /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/n8n
    
    # Test and reload nginx
    nginx -t && systemctl reload nginx
    success "Nginx configured for n8n"
}

# ============================================================================
# CREATE SYSTEMD SERVICES
# ============================================================================

create_systemd_services() {
    log "🔄 CREATING SYSTEMD SERVICES"
    
    # Create n8n systemd service
    cat > /etc/systemd/system/n8n.service << EOF
[Unit]
Description=n8n - Workflow Automation Tool
After=network.target postgresql.service
Wants=network.target

[Service]
Type=simple
User=root
Group=root
ExecStart=$(which n8n) start
Restart=always
RestartSec=10
KillMode=process
TimeoutStopSec=60

# Environment
Environment=NODE_ENV=production
EnvironmentFile=/root/.env

# Working directory
WorkingDirectory=/root

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=n8n

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd and enable services
    systemctl daemon-reload
    systemctl enable n8n
    success "Systemd services created and enabled"
}

# ============================================================================
# START ALL SERVICES
# ============================================================================

start_all_services() {
    log "🚀 STARTING ALL SERVICES"
    
    # Start PostgreSQL
    systemctl start postgresql
    
    # Start nginx
    systemctl start nginx
    
    # Start n8n
    systemctl start n8n
    
    # Wait for n8n to start
    local attempts=0
    local max_attempts=30
    
    while [ $attempts -lt $max_attempts ]; do
        if systemctl is-active --quiet n8n; then
            local response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:$N8N_PORT 2>/dev/null || echo "000")
            
            if [[ "$response" =~ ^(200|401|302)$ ]]; then
                success "✅ N8N started and responding (HTTP $response)"
                break
            fi
        fi
        
        sleep 2
        attempts=$((attempts + 1))
    done
    
    if [ $attempts -eq $max_attempts ]; then
        warning "⚠️ N8N may not have started properly"
    fi
    
    success "All services started"
}

# ============================================================================
# SETUP AUTOMATED BACKUPS
# ============================================================================

setup_automated_backups() {
    log "📅 SETTING UP AUTOMATED BACKUPS"
    
    # Create backup script directory
    mkdir -p /root/scripts
    
    # Download the latest backup script
    wget -O /root/scripts/backup_server_fixed.sh https://raw.githubusercontent.com/vitalykirkpatrick/server-recovery-toolkit/main/scripts/backup_server_fixed.sh
    chmod +x /root/scripts/backup_server_fixed.sh
    
    # Download cleanup script
    wget -O /root/scripts/system_cleanup_backup_manager_final.sh https://raw.githubusercontent.com/vitalykirkpatrick/server-recovery-toolkit/main/scripts/system_cleanup_backup_manager_final.sh
    chmod +x /root/scripts/system_cleanup_backup_manager_final.sh
    
    # Setup cron jobs
    (crontab -l 2>/dev/null; echo "0 2 * * * /root/scripts/backup_server_fixed.sh >> /var/log/backup_cron.log 2>&1") | crontab -
    (crontab -l 2>/dev/null; echo "0 3 * * 0 /root/scripts/system_cleanup_backup_manager_final.sh >> /var/log/cleanup_cron.log 2>&1") | crontab -
    
    success "Automated backups configured"
}

# ============================================================================
# VERIFY INSTALLATION
# ============================================================================

verify_installation() {
    log "✅ VERIFYING INSTALLATION"
    
    # Check services
    local services=("nginx" "postgresql" "n8n")
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            success "✅ $service is running"
        else
            error "❌ $service is not running"
        fi
    done
    
    # Test HTTP access
    local http_response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1 2>/dev/null || echo "000")
    if [[ "$http_response" =~ ^(200|401|302)$ ]]; then
        success "✅ HTTP access working (HTTP $http_response)"
    else
        warning "⚠️ HTTP access may have issues (HTTP $http_response)"
    fi
    
    # Test n8n direct access
    local n8n_response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:$N8N_PORT 2>/dev/null || echo "000")
    if [[ "$n8n_response" =~ ^(200|401|302)$ ]]; then
        success "✅ N8N direct access working (HTTP $n8n_response)"
    else
        warning "⚠️ N8N direct access may have issues (HTTP $n8n_response)"
    fi
}

# ============================================================================
# SHOW FINAL RESULTS
# ============================================================================

show_final_results() {
    log "🎉 FRESH SERVER SETUP COMPLETED"
    
    echo ""
    echo "============================================"
    echo "🚀 FRESH SERVER SETUP COMPLETED"
    echo "============================================"
    echo ""
    echo "🌐 ACCESS YOUR N8N:"
    echo "   🔗 URL: http://$PUBLIC_DOMAIN"
    echo "   👤 Username: admin"
    echo "   🔑 Password: n8n_1752790771"
    echo ""
    echo "📦 INSTALLED PROGRAMS:"
    echo "   ✅ Node.js $(node --version)"
    echo "   ✅ n8n (latest version)"
    echo "   ✅ nginx"
    echo "   ✅ Docker $(docker --version | cut -d' ' -f3 | tr -d ',')"
    echo "   ✅ PostgreSQL"
    echo "   ✅ Python3 with audiobook tools"
    echo "   ✅ FFmpeg, ImageMagick, Tesseract OCR"
    echo ""
    echo "🔄 RESTORED FROM BACKUP:"
    echo "   ✅ n8n workflows and configuration"
    echo "   ✅ Environment variables"
    echo "   ✅ Scripts and tools"
    echo "   ✅ Custom configurations"
    echo ""
    echo "📊 SERVICE STATUS:"
    systemctl is-active nginx && echo "   ✅ Nginx: Running" || echo "   ❌ Nginx: Not running"
    systemctl is-active postgresql && echo "   ✅ PostgreSQL: Running" || echo "   ❌ PostgreSQL: Not running"
    systemctl is-active n8n && echo "   ✅ N8N: Running" || echo "   ❌ N8N: Not running"
    systemctl is-active docker && echo "   ✅ Docker: Running" || echo "   ❌ Docker: Not running"
    echo ""
    echo "📅 AUTOMATED BACKUPS:"
    echo "   ✅ Daily backup at 2:00 AM"
    echo "   ✅ Weekly cleanup at 3:00 AM Sunday"
    echo ""
    echo "🔧 TROUBLESHOOTING:"
    echo "   📊 Check services: systemctl status nginx postgresql n8n"
    echo "   📜 Check logs: journalctl -u n8n -f"
    echo "   🧪 Test access: curl http://127.0.0.1"
    echo ""
    echo "🎊 YOUR SERVER IS FULLY RESTORED AND READY!"
    echo "============================================"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    log "🚀 FRESH SERVER COMPLETE SETUP STARTED"
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root (use sudo)"
        exit 1
    fi
    
    # Create log file
    touch "$LOG_FILE"
    
    echo "⚠️  This will install all programs and restore from backup"
    echo "🎯 Continue only on a fresh Ubuntu server"
    echo ""
    read -p "Continue with fresh server setup? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Fresh server setup cancelled."
        exit 0
    fi
    
    # Execute complete setup
    update_system_and_install_basics
    install_nodejs
    install_docker
    install_nginx
    install_postgresql
    install_audiobook_tools
    download_and_restore_backup
    configure_n8n
    configure_nginx
    create_systemd_services
    start_all_services
    setup_automated_backups
    verify_installation
    show_final_results
    
    success "🎉 FRESH SERVER SETUP COMPLETED"
    log "📜 Full log available at: $LOG_FILE"
}

# Run main function
main "$@"

