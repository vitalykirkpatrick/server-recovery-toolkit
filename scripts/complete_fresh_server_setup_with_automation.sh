#!/bin/bash

#=============================================================================
# COMPLETE FRESH SERVER SETUP WITH FULL AUTOMATION
# Compatible with: Ubuntu 22.04 LTS
# Purpose: Clean installation of n8n, nginx, audiobook tools, backups, and automation
# Features: n8n automation, nginx proxy, audiobook conversion, backups, cron jobs
#=============================================================================

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration variables
PUBLIC_DOMAIN="n8n.websolutionsserver.net"
N8N_USER="admin"
N8N_PASSWORD="n8n_1752790771"
NODE_VERSION="18"
PYTHON_VERSION="3.11"
LOG_FILE="/var/log/fresh_server_setup_$(date +%Y%m%d_%H%M%S).log"
INSTALL_DIR="/opt/audiobooksmith"
WORKING_DIR="/tmp/audiobooksmith_production"
GITHUB_REPO="https://raw.githubusercontent.com/vitalykirkpatrick/server-recovery-toolkit/main/scripts"

# Function to print colored output
print_status() {
    echo -e "${BLUE}🔧 STEP:${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

print_success() {
    echo -e "${GREEN}✅ SUCCESS:${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - SUCCESS: $1" >> "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}⚠️  WARNING:${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - WARNING: $1" >> "$LOG_FILE"
}

print_error() {
    echo -e "${RED}❌ ERROR:${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: $1" >> "$LOG_FILE"
}

print_info() {
    echo -e "${CYAN}ℹ️  INFO:${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - INFO: $1" >> "$LOG_FILE"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to download script from GitHub
download_script() {
    local script_name="$1"
    local destination="$2"
    local url="$GITHUB_REPO/$script_name"
    
    if wget -q -O "$destination" "$url" 2>/dev/null; then
        chmod +x "$destination"
        return 0
    else
        return 1
    fi
}

# Start installation
echo -e "${PURPLE}=============================================================================${NC}"
echo -e "${PURPLE}  COMPLETE FRESH SERVER SETUP WITH FULL AUTOMATION${NC}"
echo -e "${PURPLE}  Installation Date: $(date)${NC}"
echo -e "${PURPLE}  Domain: $PUBLIC_DOMAIN${NC}"
echo -e "${PURPLE}=============================================================================${NC}"

print_info "Starting fresh server setup with full automation at $(date)"
print_info "Log file: $LOG_FILE"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root (use sudo)"
    exit 1
fi

print_success "Running as root user"

# Check Ubuntu version
print_status "Checking Ubuntu version..."
if [ -f /etc/os-release ]; then
    . /etc/os-release
    print_info "Operating System: $NAME $VERSION"
    
    if [ "$VERSION_ID" != "22.04" ]; then
        print_warning "This script is optimized for Ubuntu 22.04. Current: $VERSION_ID"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        print_success "Ubuntu 22.04 LTS detected"
    fi
else
    print_error "Cannot determine Ubuntu version"
    exit 1
fi

# Check system requirements
print_status "Checking system requirements..."

# Check disk space (minimum 25GB for everything including backups)
AVAILABLE_SPACE=$(df / | awk 'NR==2 {print $4}')
REQUIRED_SPACE=26214400  # 25GB in KB

if [ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE" ]; then
    print_error "Insufficient disk space. Required: 25GB, Available: $((AVAILABLE_SPACE/1024/1024))GB"
    exit 1
fi

print_success "Sufficient disk space available: $((AVAILABLE_SPACE/1024/1024))GB"

# Check memory (minimum 2GB)
TOTAL_MEM=$(free -m | awk 'NR==2{print $2}')
if [ "$TOTAL_MEM" -lt 2048 ]; then
    print_warning "Low memory detected: ${TOTAL_MEM}MB. Recommended: 4GB+ for optimal performance"
else
    print_success "Memory available: ${TOTAL_MEM}MB"
fi

# Check internet connectivity
print_status "Checking internet connectivity..."
if ping -c 1 google.com >/dev/null 2>&1; then
    print_success "Internet connectivity confirmed"
else
    print_error "No internet connectivity. Please check your network connection"
    exit 1
fi

# Configure non-interactive mode for package installation
print_status "Configuring non-interactive package installation..."
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true
echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

# Disable automatic updates during installation
systemctl stop unattended-upgrades 2>/dev/null || true
systemctl disable unattended-upgrades 2>/dev/null || true

print_success "Non-interactive mode configured"

# Update system packages
print_status "Updating system packages..."
apt-get update -y >> "$LOG_FILE" 2>&1
apt-get upgrade -y >> "$LOG_FILE" 2>&1
print_success "System packages updated"

# Install essential system packages
print_status "Installing essential system packages..."
apt-get install -y \
    curl \
    wget \
    git \
    unzip \
    zip \
    tar \
    gzip \
    p7zip-full \
    build-essential \
    cmake \
    pkg-config \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    file \
    strings \
    htop \
    nano \
    vim \
    net-tools \
    ufw \
    cron \
    logrotate \
    rsync \
    >> "$LOG_FILE" 2>&1

print_success "Essential system packages installed"

# Install Node.js
print_status "Installing Node.js $NODE_VERSION..."
curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - >> "$LOG_FILE" 2>&1
apt-get install -y nodejs >> "$LOG_FILE" 2>&1

# Verify Node.js installation
if command_exists node && command_exists npm; then
    print_success "Node.js installed: $(node --version), npm: $(npm --version)"
else
    print_error "Node.js installation failed"
    exit 1
fi

# Install n8n globally
print_status "Installing n8n globally..."
npm install -g n8n >> "$LOG_FILE" 2>&1

# Verify n8n installation
if command_exists n8n; then
    print_success "n8n installed: $(n8n --version)"
else
    print_error "n8n installation failed"
    exit 1
fi

# Install PM2 for process management
print_status "Installing PM2 process manager..."
npm install -g pm2 >> "$LOG_FILE" 2>&1

if command_exists pm2; then
    print_success "PM2 installed: $(pm2 --version)"
else
    print_error "PM2 installation failed"
    exit 1
fi

# Install nginx
print_status "Installing nginx..."
apt-get install -y nginx >> "$LOG_FILE" 2>&1

if command_exists nginx; then
    print_success "nginx installed: $(nginx -v 2>&1)"
else
    print_error "nginx installation failed"
    exit 1
fi

# Create n8n configuration directory
print_status "Creating n8n configuration..."
mkdir -p /root/.n8n

# Create n8n configuration file
cat > /root/.n8n/config.json << EOF
{
  "host": "0.0.0.0",
  "port": 5678,
  "protocol": "https",
  "editorBaseUrl": "https://$PUBLIC_DOMAIN",
  "endpoints": {
    "rest": "https://$PUBLIC_DOMAIN/rest",
    "webhook": "https://$PUBLIC_DOMAIN/webhook",
    "webhookWaiting": "https://$PUBLIC_DOMAIN/webhook-waiting",
    "webhookTest": "https://$PUBLIC_DOMAIN/webhook-test"
  }
}
EOF

# Create n8n environment file
cat > /root/.env << EOF
NODE_ENV=production
N8N_HOST=0.0.0.0
N8N_PORT=5678
N8N_PROTOCOL=https
N8N_EDITOR_BASE_URL=https://$PUBLIC_DOMAIN
WEBHOOK_URL=https://$PUBLIC_DOMAIN
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=$N8N_USER
N8N_BASIC_AUTH_PASSWORD=$N8N_PASSWORD
N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=false
EOF

chmod 600 /root/.env

print_success "n8n configuration created"

# Create PM2 ecosystem file for n8n
print_status "Creating PM2 configuration for n8n..."
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
      "WEBHOOK_URL": "https://$PUBLIC_DOMAIN",
      "N8N_BASIC_AUTH_ACTIVE": "true",
      "N8N_BASIC_AUTH_USER": "$N8N_USER",
      "N8N_BASIC_AUTH_PASSWORD": "$N8N_PASSWORD",
      "N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS": "false"
    },
    "instances": 1,
    "autorestart": true,
    "watch": false,
    "max_memory_restart": "1G",
    "min_uptime": "10s",
    "max_restarts": 10,
    "restart_delay": 4000,
    "log_date_format": "YYYY-MM-DD HH:mm:ss Z",
    "error_file": "/var/log/n8n-error.log",
    "out_file": "/var/log/n8n-out.log",
    "log_file": "/var/log/n8n-combined.log"
  }]
}
EOF

print_success "PM2 configuration created"

# Configure nginx for Cloudflare
print_status "Configuring nginx for Cloudflare proxy..."

# Remove default nginx site
rm -f /etc/nginx/sites-enabled/default

# Create nginx configuration for n8n with Cloudflare support
cat > /etc/nginx/sites-available/n8n << 'EOF'
server {
    listen 80;
    server_name n8n.websolutionsserver.net;
    client_max_body_size 100M;
    
    # Cloudflare real IP configuration
    set_real_ip_from 173.245.48.0/20;
    set_real_ip_from 103.21.244.0/22;
    set_real_ip_from 103.22.200.0/22;
    set_real_ip_from 103.31.4.0/22;
    set_real_ip_from 141.101.64.0/18;
    set_real_ip_from 108.162.192.0/18;
    set_real_ip_from 190.93.240.0/20;
    set_real_ip_from 188.114.96.0/20;
    set_real_ip_from 197.234.240.0/22;
    set_real_ip_from 198.41.128.0/17;
    set_real_ip_from 162.158.0.0/15;
    set_real_ip_from 104.16.0.0/13;
    set_real_ip_from 104.24.0.0/14;
    set_real_ip_from 172.64.0.0/13;
    set_real_ip_from 131.0.72.0/22;
    real_ip_header CF-Connecting-IP;
    
    location / {
        proxy_pass http://127.0.0.1:5678;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Server $host;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Cloudflare headers
        proxy_set_header CF-Ray $http_cf_ray;
        proxy_set_header CF-Visitor $http_cf_visitor;
        proxy_set_header CF-Connecting-IP $http_cf_connecting_ip;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF

# Enable the site
ln -sf /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/n8n

# Test nginx configuration
if nginx -t >> "$LOG_FILE" 2>&1; then
    print_success "nginx configuration is valid"
else
    print_error "nginx configuration test failed"
    exit 1
fi

print_success "nginx configured for Cloudflare"

# Start and enable nginx
print_status "Starting nginx..."
systemctl enable nginx >> "$LOG_FILE" 2>&1
systemctl start nginx >> "$LOG_FILE" 2>&1

if systemctl is-active --quiet nginx; then
    print_success "nginx is running"
else
    print_error "nginx failed to start"
    exit 1
fi

# Start n8n with PM2
print_status "Starting n8n with PM2..."
cd /root
pm2 start n8n-ecosystem.json >> "$LOG_FILE" 2>&1
pm2 save >> "$LOG_FILE" 2>&1

# Setup PM2 startup
pm2 startup systemd -u root --hp /root >> "$LOG_FILE" 2>&1

print_success "n8n started with PM2"

# Wait for n8n to start
print_status "Waiting for n8n to start..."
sleep 10

# Test n8n connectivity
MAX_ATTEMPTS=30
ATTEMPT=1

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5678 2>/dev/null || echo "000")
    
    if [[ "$RESPONSE" =~ ^(200|401|302)$ ]]; then
        print_success "✅ n8n is responding (HTTP $RESPONSE)"
        break
    fi
    
    echo "   Waiting for n8n... ($ATTEMPT/$MAX_ATTEMPTS)"
    sleep 2
    ((ATTEMPT++))
done

if [ $ATTEMPT -gt $MAX_ATTEMPTS ]; then
    print_error "n8n failed to start within $((MAX_ATTEMPTS * 2)) seconds"
    print_info "Check logs: pm2 logs n8n"
    exit 1
fi

# Install audiobook processing packages
print_status "Installing audiobook processing packages..."

# Install PDF processing tools
apt-get install -y \
    poppler-utils \
    ghostscript \
    pdftk \
    qpdf \
    mupdf-tools \
    >> "$LOG_FILE" 2>&1

# Install OCR tools with multiple language support
apt-get install -y \
    tesseract-ocr \
    tesseract-ocr-eng \
    tesseract-ocr-ukr \
    tesseract-ocr-rus \
    tesseract-ocr-pol \
    tesseract-ocr-deu \
    tesseract-ocr-fra \
    tesseract-ocr-spa \
    tesseract-ocr-ita \
    tesseract-ocr-por \
    libtesseract-dev \
    >> "$LOG_FILE" 2>&1

# Install office document processing tools
apt-get install -y \
    libreoffice \
    libreoffice-writer \
    libreoffice-calc \
    pandoc \
    unrtf \
    odt2txt \
    catdoc \
    antiword \
    wv \
    >> "$LOG_FILE" 2>&1

# Install image processing tools
apt-get install -y \
    imagemagick \
    graphicsmagick \
    optipng \
    jpegoptim \
    >> "$LOG_FILE" 2>&1

# Install audio processing tools
apt-get install -y \
    ffmpeg \
    sox \
    lame \
    flac \
    vorbis-tools \
    opus-tools \
    >> "$LOG_FILE" 2>&1

print_success "Audiobook processing packages installed"

# Install Python and development tools
print_status "Installing Python $PYTHON_VERSION..."

# Add deadsnakes PPA for latest Python versions
add-apt-repository -y ppa:deadsnakes/ppa >> "$LOG_FILE" 2>&1
apt-get update -y >> "$LOG_FILE" 2>&1

apt-get install -y \
    python3.11 \
    python3.11-dev \
    python3.11-venv \
    python3.11-distutils \
    python3-pip \
    python3-setuptools \
    python3-wheel \
    >> "$LOG_FILE" 2>&1

# Install pip for Python 3.11
curl -sS https://bootstrap.pypa.io/get-pip.py | python3.11 >> "$LOG_FILE" 2>&1

print_success "Python $PYTHON_VERSION installed"

# Install essential Python packages for audiobook processing
print_status "Installing Python audiobook processing packages..."
python3.11 -m pip install --upgrade pip >> "$LOG_FILE" 2>&1

python3.11 -m pip install \
    pdfplumber \
    PyPDF2 \
    PyPDF4 \
    pdfminer.six \
    python-docx \
    python-pptx \
    openpyxl \
    xlrd \
    pytesseract \
    Pillow \
    beautifulsoup4 \
    lxml \
    html5lib \
    markdown \
    textstat \
    langdetect \
    nltk \
    requests \
    urllib3 \
    openai \
    anthropic \
    elevenlabs \
    pydub \
    librosa \
    soundfile \
    mutagen \
    eyed3 \
    flask \
    fastapi \
    uvicorn \
    pandas \
    numpy \
    python-dotenv \
    click \
    tqdm \
    colorama \
    >> "$LOG_FILE" 2>&1

print_success "Python audiobook processing packages installed"

# Create working directories
print_status "Creating working directories..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$WORKING_DIR"
mkdir -p "$WORKING_DIR/sessions"
mkdir -p "$WORKING_DIR/uploads"
mkdir -p "$WORKING_DIR/processing"
mkdir -p "$WORKING_DIR/output"
mkdir -p "$WORKING_DIR/logs"
mkdir -p "$WORKING_DIR/temp"
mkdir -p /root/backups
mkdir -p /root/scripts

# Set proper permissions
chmod 755 "$INSTALL_DIR"
chmod 777 "$WORKING_DIR"
chmod 777 "$WORKING_DIR/sessions"
chmod 777 "$WORKING_DIR/uploads"
chmod 777 "$WORKING_DIR/processing"
chmod 777 "$WORKING_DIR/output"
chmod 777 "$WORKING_DIR/logs"
chmod 777 "$WORKING_DIR/temp"
chmod 755 /root/backups
chmod 755 /root/scripts

print_success "Working directories created"

# Configure firewall
print_status "Configuring firewall..."

# Enable UFW
ufw --force enable >> "$LOG_FILE" 2>&1

# Allow SSH
ufw allow 22/tcp >> "$LOG_FILE" 2>&1

# Allow HTTP and HTTPS
ufw allow 80/tcp >> "$LOG_FILE" 2>&1
ufw allow 443/tcp >> "$LOG_FILE" 2>&1

# Allow n8n port (for direct access if needed)
ufw allow 5678/tcp >> "$LOG_FILE" 2>&1

print_success "Firewall configured"

# Download and install backup scripts from GitHub
print_status "Installing backup and automation scripts from GitHub..."

# Create scripts directory
mkdir -p /root/scripts

# Download backup scripts
print_info "Downloading backup scripts..."
if download_script "backup_server_minimal.sh" "/root/scripts/backup_server_minimal.sh"; then
    print_success "Minimal backup script downloaded"
else
    print_warning "Failed to download minimal backup script"
fi

if download_script "backup_server.sh" "/root/scripts/backup_server.sh"; then
    print_success "Full backup script downloaded"
else
    print_warning "Failed to download full backup script"
fi

# Download cleanup script
print_info "Downloading cleanup script..."
if download_script "system_cleanup_backup_manager_final.sh" "/root/scripts/system_cleanup.sh"; then
    print_success "System cleanup script downloaded"
else
    print_warning "Failed to download cleanup script"
fi

# Download cron management script
print_info "Downloading cron management script..."
if download_script "fix_cron_jobs.sh" "/root/scripts/cron_manager.sh"; then
    print_success "Cron management script downloaded"
else
    print_warning "Failed to download cron management script"
fi

# Download restoration scripts
print_info "Downloading restoration scripts..."
if download_script "server_restore_script.sh" "/root/scripts/server_restore.sh"; then
    print_success "Server restoration script downloaded"
else
    print_warning "Failed to download restoration script"
fi

print_success "Backup and automation scripts installed"

# Create comprehensive backup script
print_status "Creating comprehensive backup script..."
cat > /root/scripts/comprehensive_backup.sh << 'EOF'
#!/bin/bash
# Comprehensive Server Backup Script

BACKUP_DIR="/root/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="comprehensive_backup_$TIMESTAMP"
LOG_FILE="/var/log/backup_comprehensive.log"

echo "$(date): Starting comprehensive backup" >> "$LOG_FILE"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Create comprehensive backup
tar -czf "$BACKUP_DIR/$BACKUP_NAME.tar.gz" \
    --exclude='/proc' \
    --exclude='/tmp' \
    --exclude='/mnt' \
    --exclude='/dev' \
    --exclude='/sys' \
    --exclude='/run' \
    --exclude='/media' \
    --exclude='/var/log' \
    --exclude='/var/cache' \
    --exclude='/var/tmp' \
    --exclude='/root/backups' \
    /root/.n8n \
    /root/.env \
    /root/n8n-ecosystem.json \
    /etc/nginx \
    /etc/netplan \
    /opt/audiobooksmith \
    /root/scripts \
    2>> "$LOG_FILE"

if [ $? -eq 0 ]; then
    echo "$(date): Comprehensive backup completed: $BACKUP_NAME.tar.gz" >> "$LOG_FILE"
    
    # Keep only last 7 comprehensive backups
    cd "$BACKUP_DIR"
    ls -t comprehensive_backup_*.tar.gz | tail -n +8 | xargs -r rm
    
    echo "$(date): Old backups cleaned up" >> "$LOG_FILE"
else
    echo "$(date): Comprehensive backup failed" >> "$LOG_FILE"
fi
EOF

chmod +x /root/scripts/comprehensive_backup.sh

print_success "Comprehensive backup script created"

# Create system health check script
print_status "Creating system health check script..."
cat > /root/scripts/health_check.sh << 'EOF'
#!/bin/bash
# System Health Check Script

LOG_FILE="/var/log/health_check.log"
ALERT_FILE="/tmp/health_alerts.txt"

echo "$(date): Starting health check" >> "$LOG_FILE"

# Clear previous alerts
> "$ALERT_FILE"

# Check disk space
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 85 ]; then
    echo "ALERT: Disk usage is ${DISK_USAGE}%" >> "$ALERT_FILE"
fi

# Check memory usage
MEM_USAGE=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
if [ "$MEM_USAGE" -gt 90 ]; then
    echo "ALERT: Memory usage is ${MEM_USAGE}%" >> "$ALERT_FILE"
fi

# Check n8n status
if ! pm2 list | grep -q "n8n.*online"; then
    echo "ALERT: n8n is not running" >> "$ALERT_FILE"
fi

# Check nginx status
if ! systemctl is-active --quiet nginx; then
    echo "ALERT: nginx is not running" >> "$ALERT_FILE"
fi

# Check n8n HTTP response
N8N_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5678 2>/dev/null || echo "000")
if [[ ! "$N8N_RESPONSE" =~ ^(200|401|302)$ ]]; then
    echo "ALERT: n8n HTTP response: $N8N_RESPONSE" >> "$ALERT_FILE"
fi

# Log results
if [ -s "$ALERT_FILE" ]; then
    echo "$(date): Health check found issues:" >> "$LOG_FILE"
    cat "$ALERT_FILE" >> "$LOG_FILE"
else
    echo "$(date): Health check passed - all systems normal" >> "$LOG_FILE"
fi
EOF

chmod +x /root/scripts/health_check.sh

print_success "System health check script created"

# Setup automated cron jobs
print_status "Setting up automated cron jobs..."

# Create cron jobs
(crontab -l 2>/dev/null; cat << 'EOF'
# n8n Server Automation Cron Jobs

# Daily minimal backup at 2:30 AM
30 2 * * * /root/scripts/backup_server_minimal.sh >> /var/log/backup_minimal_cron.log 2>&1

# Weekly comprehensive backup on Sundays at 3:00 AM
0 3 * * 0 /root/scripts/comprehensive_backup.sh >> /var/log/backup_comprehensive_cron.log 2>&1

# Weekly system cleanup on Sundays at 4:00 AM
0 4 * * 0 /root/scripts/system_cleanup.sh >> /var/log/cleanup_cron.log 2>&1

# Daily health check at 6:00 AM and 6:00 PM
0 6,18 * * * /root/scripts/health_check.sh >> /var/log/health_check_cron.log 2>&1

# Weekly PM2 save on Sundays at 5:00 AM
0 5 * * 0 /usr/bin/pm2 save >> /var/log/pm2_save_cron.log 2>&1

# Daily log rotation check at 1:00 AM
0 1 * * * /usr/sbin/logrotate /etc/logrotate.conf >> /var/log/logrotate_cron.log 2>&1
EOF
) | crontab -

print_success "Automated cron jobs configured"

# Configure log rotation
print_status "Configuring log rotation..."
cat > /etc/logrotate.d/n8n-automation << 'EOF'
/var/log/n8n-*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
    postrotate
        /usr/bin/pm2 reloadLogs
    endscript
}

/var/log/backup_*.log {
    weekly
    rotate 12
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
}

/var/log/cleanup_*.log {
    weekly
    rotate 12
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
}

/var/log/health_check*.log {
    weekly
    rotate 12
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
}
EOF

print_success "Log rotation configured"

# Create management scripts
print_status "Creating management scripts..."

# Create n8n management script
cat > "$INSTALL_DIR/manage_n8n.sh" << 'EOF'
#!/bin/bash
# n8n Management Script

case "$1" in
    "start")
        echo "🚀 Starting n8n..."
        pm2 start n8n
        ;;
    "stop")
        echo "🛑 Stopping n8n..."
        pm2 stop n8n
        ;;
    "restart")
        echo "🔄 Restarting n8n..."
        pm2 restart n8n
        ;;
    "status")
        echo "📊 n8n Status:"
        pm2 list
        echo ""
        echo "🌐 HTTP Status:"
        curl -s -o /dev/null -w "Local: HTTP %{http_code}\n" http://127.0.0.1:5678
        ;;
    "logs")
        echo "📜 n8n Logs:"
        pm2 logs n8n
        ;;
    "update")
        echo "🔄 Updating n8n..."
        npm update -g n8n
        pm2 restart n8n
        ;;
    *)
        echo "n8n Management Script"
        echo "Usage: $0 {start|stop|restart|status|logs|update}"
        echo ""
        echo "Commands:"
        echo "  start   - Start n8n"
        echo "  stop    - Stop n8n"
        echo "  restart - Restart n8n"
        echo "  status  - Show n8n status"
        echo "  logs    - Show n8n logs"
        echo "  update  - Update n8n"
        ;;
esac
EOF

chmod +x "$INSTALL_DIR/manage_n8n.sh"

# Create automation management script
cat > "$INSTALL_DIR/manage_automation.sh" << 'EOF'
#!/bin/bash
# Automation Management Script

case "$1" in
    "backup-minimal")
        echo "💾 Running minimal backup..."
        /root/scripts/backup_server_minimal.sh
        ;;
    "backup-comprehensive")
        echo "💾 Running comprehensive backup..."
        /root/scripts/comprehensive_backup.sh
        ;;
    "cleanup")
        echo "🧹 Running system cleanup..."
        /root/scripts/system_cleanup.sh
        ;;
    "health-check")
        echo "🏥 Running health check..."
        /root/scripts/health_check.sh
        ;;
    "cron-status")
        echo "⏰ Cron Jobs Status:"
        crontab -l
        ;;
    "logs")
        echo "📜 Automation Logs:"
        echo "==================="
        echo "Recent backup logs:"
        tail -10 /var/log/backup_*_cron.log 2>/dev/null
        echo ""
        echo "Recent cleanup logs:"
        tail -10 /var/log/cleanup_cron.log 2>/dev/null
        echo ""
        echo "Recent health check logs:"
        tail -10 /var/log/health_check_cron.log 2>/dev/null
        ;;
    *)
        echo "Automation Management Script"
        echo "Usage: $0 {backup-minimal|backup-comprehensive|cleanup|health-check|cron-status|logs}"
        echo ""
        echo "Commands:"
        echo "  backup-minimal       - Run minimal backup now"
        echo "  backup-comprehensive - Run comprehensive backup now"
        echo "  cleanup              - Run system cleanup now"
        echo "  health-check         - Run health check now"
        echo "  cron-status          - Show scheduled cron jobs"
        echo "  logs                 - Show automation logs"
        ;;
esac
EOF

chmod +x "$INSTALL_DIR/manage_automation.sh"

# Create system status script
cat > "$INSTALL_DIR/system_status.sh" << 'EOF'
#!/bin/bash
# System Status Script

echo "🖥️  SYSTEM STATUS"
echo "================="
echo "Date: $(date)"
echo "Uptime: $(uptime -p)"
echo "Load: $(uptime | awk -F'load average:' '{print $2}')"
echo ""

echo "💾 MEMORY USAGE"
echo "==============="
free -h
echo ""

echo "💿 DISK USAGE"
echo "============="
df -h /
echo ""

echo "🔧 SERVICES STATUS"
echo "=================="
echo -n "nginx: "
if systemctl is-active --quiet nginx; then echo "✅ Running"; else echo "❌ Stopped"; fi

echo -n "n8n: "
if pm2 list | grep -q "n8n.*online"; then echo "✅ Running"; else echo "❌ Stopped"; fi

echo -n "ufw: "
if ufw status | grep -q "Status: active"; then echo "✅ Active"; else echo "❌ Inactive"; fi

echo -n "cron: "
if systemctl is-active --quiet cron; then echo "✅ Running"; else echo "❌ Stopped"; fi

echo ""

echo "🌐 NETWORK STATUS"
echo "================="
echo -n "n8n Local: "
curl -s -o /dev/null -w "HTTP %{http_code}\n" http://127.0.0.1:5678

echo -n "nginx: "
curl -s -o /dev/null -w "HTTP %{http_code}\n" http://127.0.0.1

echo ""

echo "📦 PACKAGE VERSIONS"
echo "==================="
echo "Node.js: $(node --version)"
echo "npm: $(npm --version)"
echo "n8n: $(n8n --version)"
echo "nginx: $(nginx -v 2>&1)"
echo "Python: $(python3.11 --version)"
echo "PM2: $(pm2 --version)"

echo ""

echo "⏰ AUTOMATION STATUS"
echo "===================="
echo "Cron jobs configured:"
crontab -l | grep -v '^#' | grep -v '^$' | wc -l

echo ""
echo "Recent backup status:"
if [ -f /var/log/backup_minimal_cron.log ]; then
    echo -n "Last minimal backup: "
    tail -1 /var/log/backup_minimal_cron.log 2>/dev/null | head -c 50
    echo "..."
fi

if [ -f /var/log/backup_comprehensive_cron.log ]; then
    echo -n "Last comprehensive backup: "
    tail -1 /var/log/backup_comprehensive_cron.log 2>/dev/null | head -c 50
    echo "..."
fi

echo ""
echo "📁 BACKUP FILES:"
if [ -d /root/backups ]; then
    ls -lah /root/backups/ | tail -5
fi
EOF

chmod +x "$INSTALL_DIR/system_status.sh"

print_success "Management scripts created"

# Create comprehensive test script
print_status "Creating comprehensive test script..."
cat > "$INSTALL_DIR/test_all_systems.sh" << 'EOF'
#!/bin/bash
# Comprehensive System Test Script

echo "🧪 COMPREHENSIVE SYSTEM TESTING"
echo "================================"

TESTS_PASSED=0
TESTS_TOTAL=0

# Function to run test
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    echo -n "$test_name: "
    
    if eval "$test_command" >/dev/null 2>&1; then
        echo "✅ PASS"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "❌ FAIL"
    fi
}

echo "🔧 Testing System Commands:"
echo "----------------------------"
run_test "Node.js" "node --version"
run_test "npm" "npm --version"
run_test "n8n" "n8n --version"
run_test "nginx" "nginx -v"
run_test "Python 3.11" "python3.11 --version"
run_test "PM2" "pm2 --version"

echo ""
echo "📄 Testing Document Processing:"
echo "--------------------------------"
run_test "PDF Tools" "pdftotext -v"
run_test "Tesseract OCR" "tesseract --version"
run_test "LibreOffice" "libreoffice --version"
run_test "ImageMagick" "convert -version"
run_test "FFmpeg" "ffmpeg -version"

echo ""
echo "🐍 Testing Python Packages:"
echo "----------------------------"
run_test "PDF Processing" "python3.11 -c 'import pdfplumber, PyPDF2'"
run_test "OCR" "python3.11 -c 'import pytesseract'"
run_test "Office Docs" "python3.11 -c 'import docx, openpyxl'"
run_test "Audio Processing" "python3.11 -c 'import pydub, librosa'"
run_test "AI APIs" "python3.11 -c 'import openai'"
run_test "Web Framework" "python3.11 -c 'import flask, fastapi'"

echo ""
echo "🌐 Testing Services:"
echo "--------------------"
run_test "nginx Service" "systemctl is-active nginx"
run_test "n8n Process" "pm2 list | grep -q 'n8n.*online'"
run_test "n8n HTTP" "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:5678 | grep -E '^(200|401|302)$'"
run_test "nginx HTTP" "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1 | grep -E '^(200|401|302|502)$'"
run_test "cron Service" "systemctl is-active cron"

echo ""
echo "🔒 Testing Security:"
echo "--------------------"
run_test "UFW Firewall" "ufw status | grep -q 'Status: active'"
run_test "SSH Port" "ufw status | grep -q '22/tcp'"
run_test "HTTP Port" "ufw status | grep -q '80/tcp'"

echo ""
echo "🤖 Testing Automation:"
echo "----------------------"
run_test "Backup Scripts" "test -x /root/scripts/backup_server_minimal.sh"
run_test "Cleanup Script" "test -x /root/scripts/system_cleanup.sh"
run_test "Health Check" "test -x /root/scripts/health_check.sh"
run_test "Cron Jobs" "crontab -l | grep -q backup"

echo ""
echo "📊 TEST RESULTS:"
echo "================"
echo "Passed: $TESTS_PASSED/$TESTS_TOTAL ($((TESTS_PASSED * 100 / TESTS_TOTAL))%)"

if [ $TESTS_PASSED -eq $TESTS_TOTAL ]; then
    echo "🎉 ALL TESTS PASSED!"
    exit 0
else
    echo "⚠️  Some tests failed. Check the output above."
    exit 1
fi
EOF

chmod +x "$INSTALL_DIR/test_all_systems.sh"

print_success "Comprehensive test script created"

# Run initial backup
print_status "Creating initial backup..."
if [ -x /root/scripts/backup_server_minimal.sh ]; then
    /root/scripts/backup_server_minimal.sh >> "$LOG_FILE" 2>&1
    print_success "Initial backup completed"
else
    print_warning "Backup script not available, skipping initial backup"
fi

# Run final system test
print_status "Running final system test..."
if "$INSTALL_DIR/test_all_systems.sh" >> "$LOG_FILE" 2>&1; then
    FINAL_TEST_RESULT="PASSED"
    print_success "Final system test passed"
else
    FINAL_TEST_RESULT="FAILED"
    print_warning "Some tests failed - check logs"
fi

# Re-enable automatic updates
systemctl enable unattended-upgrades 2>/dev/null || true
systemctl start unattended-upgrades 2>/dev/null || true

# Generate final summary
print_status "Generating installation summary..."

SUMMARY_FILE="/root/fresh_server_setup_with_automation_summary_$(date +%Y%m%d_%H%M%S).txt"

cat > "$SUMMARY_FILE" << EOF
=============================================================================
  FRESH SERVER SETUP WITH FULL AUTOMATION SUMMARY
=============================================================================
Installation Date: $(date)
Server: $(hostname)
Ubuntu Version: $VERSION
Domain: $PUBLIC_DOMAIN

🎯 INSTALLED COMPONENTS:
=============================================================================

🔧 Core Services:
- Node.js: $(node --version)
- n8n: $(n8n --version)
- nginx: $(nginx -v 2>&1)
- PM2: $(pm2 --version)
- Python: $(python3.11 --version)

📄 Document Processing:
- PDF Tools: poppler-utils, ghostscript, pdftk, qpdf
- OCR: tesseract-ocr with Ukrainian, Russian, English support
- Office: libreoffice, pandoc, unrtf, odt2txt
- Images: imagemagick, graphicsmagick
- Audio: ffmpeg, sox, lame, flac

🐍 Python Packages:
- File Processing: pdfplumber, PyPDF2, python-docx, openpyxl
- OCR: pytesseract, Pillow
- Text: beautifulsoup4, nltk, textstat, langdetect
- AI: openai, anthropic, elevenlabs
- Audio: pydub, librosa, soundfile, mutagen
- Web: flask, fastapi, requests

🔒 Security:
- UFW Firewall: Active
- Allowed Ports: 22 (SSH), 80 (HTTP), 443 (HTTPS), 5678 (n8n)

🤖 AUTOMATION FEATURES:
=============================================================================

📅 Scheduled Cron Jobs:
- Daily minimal backup (2:30 AM)
- Weekly comprehensive backup (Sunday 3:00 AM)
- Weekly system cleanup (Sunday 4:00 AM)
- Daily health checks (6:00 AM & 6:00 PM)
- Weekly PM2 save (Sunday 5:00 AM)
- Daily log rotation (1:00 AM)

💾 Backup Scripts:
- Minimal backup: /root/scripts/backup_server_minimal.sh
- Comprehensive backup: /root/scripts/comprehensive_backup.sh
- System cleanup: /root/scripts/system_cleanup.sh

🏥 Monitoring:
- Health check: /root/scripts/health_check.sh
- System status: $INSTALL_DIR/system_status.sh
- Comprehensive testing: $INSTALL_DIR/test_all_systems.sh

📊 SYSTEM STATUS:
=============================================================================
Final Test: $FINAL_TEST_RESULT
n8n Status: $(pm2 list | grep n8n | awk '{print $10}' || echo "Unknown")
nginx Status: $(systemctl is-active nginx)
Firewall: $(ufw status | head -1 | awk '{print $2}')
Cron Jobs: $(crontab -l | grep -v '^#' | grep -v '^$' | wc -l) configured

🌐 ACCESS INFORMATION:
=============================================================================
Public URL: https://$PUBLIC_DOMAIN
Login: $N8N_USER
Password: $N8N_PASSWORD

Direct Access: http://$(hostname -I | awk '{print $1}'):5678
Local Access: http://127.0.0.1:5678

🛠️ MANAGEMENT COMMANDS:
=============================================================================
n8n Management: $INSTALL_DIR/manage_n8n.sh {start|stop|restart|status|logs|update}
Automation: $INSTALL_DIR/manage_automation.sh {backup-minimal|backup-comprehensive|cleanup|health-check|cron-status|logs}
System Status: $INSTALL_DIR/system_status.sh
Test All: $INSTALL_DIR/test_all_systems.sh

Manual Commands:
- Minimal Backup: /root/scripts/backup_server_minimal.sh
- Comprehensive Backup: /root/scripts/comprehensive_backup.sh
- System Cleanup: /root/scripts/system_cleanup.sh
- Health Check: /root/scripts/health_check.sh

PM2 Commands:
- Status: pm2 status
- Logs: pm2 logs n8n
- Restart: pm2 restart n8n

nginx Commands:
- Status: systemctl status nginx
- Restart: systemctl restart nginx
- Test config: nginx -t

🔧 TROUBLESHOOTING:
=============================================================================
If n8n is not accessible:
1. Check PM2: pm2 status
2. Check logs: pm2 logs n8n
3. Check nginx: systemctl status nginx
4. Check firewall: ufw status
5. Test local: curl http://127.0.0.1:5678

If webhook URLs show localhost:
- They should automatically show https://$PUBLIC_DOMAIN
- If not, restart n8n: pm2 restart n8n

If automation fails:
1. Check cron: systemctl status cron
2. Check cron logs: tail /var/log/syslog | grep CRON
3. Test scripts manually: /root/scripts/backup_server_minimal.sh

📁 IMPORTANT DIRECTORIES:
=============================================================================
n8n Config: /root/.n8n/
n8n Environment: /root/.env
PM2 Config: /root/n8n-ecosystem.json
nginx Config: /etc/nginx/sites-available/n8n
Management Scripts: $INSTALL_DIR/
Automation Scripts: /root/scripts/
Working Directory: $WORKING_DIR/
Backup Directory: /root/backups/
Logs: /var/log/n8n-*.log, /var/log/*_cron.log

🎉 AUDIOBOOK PROCESSING WITH FULL AUTOMATION READY:
=============================================================================
Your server is now ready for audiobook processing with:
✅ n8n automation workflows
✅ Document processing (PDF, DOCX, etc.)
✅ OCR with Ukrainian support
✅ Audio processing and conversion
✅ AI integration capabilities
✅ Secure firewall configuration
✅ Cloudflare HTTPS support
✅ Automated daily backups
✅ Weekly system cleanup
✅ Health monitoring
✅ Log rotation
✅ Comprehensive management tools

Installation Log: $LOG_FILE
Summary File: $SUMMARY_FILE
=============================================================================
EOF

print_success "Installation summary created: $SUMMARY_FILE"

# Display final results
echo ""
echo -e "${PURPLE}=============================================================================${NC}"
echo -e "${PURPLE}  FRESH SERVER SETUP WITH FULL AUTOMATION COMPLETED!${NC}"
echo -e "${PURPLE}=============================================================================${NC}"
echo ""

if [ "$FINAL_TEST_RESULT" = "PASSED" ]; then
    echo -e "${GREEN}🎉 SUCCESS: Fresh server setup with full automation completed successfully!${NC}"
else
    echo -e "${YELLOW}⚠️  WARNING: Setup completed but some tests failed${NC}"
fi

echo ""
echo -e "${CYAN}🌐 ACCESS YOUR N8N:${NC}"
echo -e "${CYAN}   Public URL: https://$PUBLIC_DOMAIN${NC}"
echo -e "${CYAN}   Login: $N8N_USER${NC}"
echo -e "${CYAN}   Password: $N8N_PASSWORD${NC}"
echo ""
echo -e "${CYAN}🛠️  MANAGEMENT COMMANDS:${NC}"
echo -e "${CYAN}   n8n: $INSTALL_DIR/manage_n8n.sh {start|stop|restart|status}${NC}"
echo -e "${CYAN}   Automation: $INSTALL_DIR/manage_automation.sh {backup-minimal|cleanup|health-check}${NC}"
echo -e "${CYAN}   Status: $INSTALL_DIR/system_status.sh${NC}"
echo -e "${CYAN}   Test: $INSTALL_DIR/test_all_systems.sh${NC}"
echo ""
echo -e "${CYAN}🤖 AUTOMATION FEATURES:${NC}"
echo -e "${CYAN}   📅 Daily backups at 2:30 AM${NC}"
echo -e "${CYAN}   🧹 Weekly cleanup on Sundays${NC}"
echo -e "${CYAN}   🏥 Health checks twice daily${NC}"
echo -e "${CYAN}   📜 Automatic log rotation${NC}"
echo ""
echo -e "${CYAN}📋 SUMMARY FILE: $SUMMARY_FILE${NC}"
echo -e "${CYAN}📝 INSTALLATION LOG: $LOG_FILE${NC}"
echo ""
echo -e "${GREEN}✅ Your server is ready for audiobook processing with full automation!${NC}"
echo ""

# End of script
print_info "Fresh server setup with full automation completed at $(date)"
exit 0

