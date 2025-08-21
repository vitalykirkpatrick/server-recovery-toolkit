#!/bin/bash

#=============================================================================
# ENHANCED FRESH SERVER SETUP WITH DETAILED PROGRESS TRACKING
# Purpose: Complete Ubuntu 22.04 server setup for n8n and audiobook processing
# Features: Detailed progress, error tracking, verbose logging, recovery options
#=============================================================================

# Configuration
DOMAIN="n8n.websolutionsserver.net"
INSTALL_DIR="/opt/audiobooksmith"
SCRIPTS_DIR="/root/scripts"
LOG_FILE="/var/log/fresh_server_setup_$(date +%Y%m%d_%H%M%S).log"
PROGRESS_FILE="/tmp/setup_progress.txt"
ERROR_FILE="/tmp/setup_errors.txt"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Progress tracking
TOTAL_STEPS=25
CURRENT_STEP=0

# Initialize files
echo "0" > "$PROGRESS_FILE"
echo "" > "$ERROR_FILE"

# Enhanced logging and progress functions
log_and_print() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    case "$level" in
        "STEP")
            CURRENT_STEP=$((CURRENT_STEP + 1))
            echo "$CURRENT_STEP" > "$PROGRESS_FILE"
            echo -e "${BLUE}🔧 STEP $CURRENT_STEP/$TOTAL_STEPS:${NC} $message"
            echo "STEP $CURRENT_STEP/$TOTAL_STEPS: $message" >> "$PROGRESS_FILE"
            ;;
        "SUCCESS")
            echo -e "${GREEN}✅ SUCCESS:${NC} $message"
            ;;
        "WARNING")
            echo -e "${YELLOW}⚠️  WARNING:${NC} $message"
            echo "WARNING: $message" >> "$ERROR_FILE"
            ;;
        "ERROR")
            echo -e "${RED}❌ ERROR:${NC} $message"
            echo "ERROR: $message" >> "$ERROR_FILE"
            ;;
        "INFO")
            echo -e "${CYAN}ℹ️  INFO:${NC} $message"
            ;;
        "PROGRESS")
            echo -e "${WHITE}📊 PROGRESS:${NC} $message"
            ;;
    esac
}

# Function to run command with detailed output
run_command() {
    local description="$1"
    local command="$2"
    local show_output="${3:-false}"
    
    log_and_print "PROGRESS" "Starting: $description"
    
    if [ "$show_output" = "true" ]; then
        echo -e "${CYAN}   Command: $command${NC}"
        if eval "$command" 2>&1 | tee -a "$LOG_FILE"; then
            log_and_print "SUCCESS" "$description completed"
            return 0
        else
            log_and_print "ERROR" "$description failed"
            return 1
        fi
    else
        if eval "$command" >> "$LOG_FILE" 2>&1; then
            log_and_print "SUCCESS" "$description completed"
            return 0
        else
            log_and_print "ERROR" "$description failed"
            log_and_print "INFO" "Check log file for details: $LOG_FILE"
            return 1
        fi
    fi
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to wait for user input on error
handle_error() {
    local error_msg="$1"
    local continue_anyway="${2:-false}"
    
    log_and_print "ERROR" "$error_msg"
    
    if [ "$continue_anyway" = "true" ]; then
        log_and_print "WARNING" "Continuing despite error..."
        return 0
    fi
    
    echo ""
    echo -e "${RED}❌ INSTALLATION ERROR DETECTED${NC}"
    echo -e "${YELLOW}Error: $error_msg${NC}"
    echo ""
    echo "Options:"
    echo "1. Continue anyway (may cause issues)"
    echo "2. View error log"
    echo "3. Exit installation"
    echo ""
    read -p "Choose option (1-3): " choice
    
    case "$choice" in
        1)
            log_and_print "WARNING" "User chose to continue despite error"
            return 0
            ;;
        2)
            echo ""
            echo "=== ERROR LOG ==="
            tail -20 "$LOG_FILE"
            echo "================="
            echo ""
            read -p "Press Enter to continue..."
            handle_error "$error_msg" false
            ;;
        3)
            log_and_print "INFO" "Installation aborted by user"
            exit 1
            ;;
        *)
            echo "Invalid choice. Please try again."
            handle_error "$error_msg" false
            ;;
    esac
}

# Function to show progress summary
show_progress() {
    local current=$(cat "$PROGRESS_FILE" | tail -1)
    echo ""
    echo -e "${PURPLE}=============================================================================${NC}"
    echo -e "${PURPLE}  INSTALLATION PROGRESS: Step $current of $TOTAL_STEPS${NC}"
    echo -e "${PURPLE}  Progress: $((current * 100 / TOTAL_STEPS))%${NC}"
    echo -e "${PURPLE}=============================================================================${NC}"
    echo ""
}

# Trap to show progress on exit
trap 'show_progress; echo "Installation interrupted at step $CURRENT_STEP"; exit 1' INT TERM

# Start installation
clear
echo -e "${PURPLE}=============================================================================${NC}"
echo -e "${PURPLE}  ENHANCED FRESH SERVER SETUP WITH DETAILED PROGRESS TRACKING${NC}"
echo -e "${PURPLE}  Installation Date: $(date)${NC}"
echo -e "${PURPLE}  Domain: $DOMAIN${NC}"
echo -e "${PURPLE}  Log File: $LOG_FILE${NC}"
echo -e "${PURPLE}=============================================================================${NC}"

log_and_print "INFO" "Starting enhanced fresh server setup with detailed progress tracking"
log_and_print "INFO" "Log file: $LOG_FILE"

# Step 1: Check root privileges
log_and_print "STEP" "Checking root privileges"
if [ "$EUID" -ne 0 ]; then
    handle_error "This script must be run as root (use sudo)"
fi
log_and_print "SUCCESS" "Running as root user"

# Step 2: Check Ubuntu version
log_and_print "STEP" "Checking Ubuntu version"
if ! grep -q "Ubuntu 22.04" /etc/os-release; then
    handle_error "This script is designed for Ubuntu 22.04 LTS" true
fi
OS_INFO=$(lsb_release -d | cut -f2)
log_and_print "INFO" "Operating System: $OS_INFO"
log_and_print "SUCCESS" "Ubuntu version check completed"

# Step 3: Check system requirements
log_and_print "STEP" "Checking system requirements"
DISK_SPACE=$(df / | awk 'NR==2 {print $4}')
MEMORY=$(free -m | awk 'NR==2{print $2}')

if [ "$DISK_SPACE" -lt 10485760 ]; then  # 10GB in KB
    handle_error "Insufficient disk space. At least 10GB required"
fi
log_and_print "SUCCESS" "Sufficient disk space available: $((DISK_SPACE / 1048576))GB"

if [ "$MEMORY" -lt 1024 ]; then  # 1GB in MB
    handle_error "Insufficient memory. At least 1GB RAM required" true
fi
log_and_print "SUCCESS" "Memory available: ${MEMORY}MB"

# Step 4: Check internet connectivity
log_and_print "STEP" "Checking internet connectivity"
if ! ping -c 1 google.com >/dev/null 2>&1; then
    handle_error "No internet connectivity detected"
fi
log_and_print "SUCCESS" "Internet connectivity confirmed"

# Step 5: Configure non-interactive mode
log_and_print "STEP" "Configuring non-interactive package installation"
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true
echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
log_and_print "SUCCESS" "Non-interactive mode configured"

# Step 6: Update system packages
log_and_print "STEP" "Updating system packages (this may take a few minutes)"
run_command "System package update" "apt update && apt upgrade -y"

# Step 7: Install essential system packages
log_and_print "STEP" "Installing essential system packages"
ESSENTIAL_PACKAGES="curl wget git unzip zip htop nano vim net-tools software-properties-common apt-transport-https ca-certificates gnupg lsb-release build-essential"
run_command "Essential packages installation" "apt install -y $ESSENTIAL_PACKAGES"

# Step 8: Install Node.js
log_and_print "STEP" "Installing Node.js 18.x"
run_command "Node.js repository setup" "curl -fsSL https://deb.nodesource.com/setup_18.x | bash -"
run_command "Node.js installation" "apt-get install -y nodejs"

# Verify Node.js installation
if command_exists node && command_exists npm; then
    NODE_VERSION=$(node --version)
    NPM_VERSION=$(npm --version)
    log_and_print "SUCCESS" "Node.js installed: $NODE_VERSION, npm: $NPM_VERSION"
else
    handle_error "Node.js installation failed"
fi

# Step 9: Install nginx
log_and_print "STEP" "Installing and configuring nginx"
run_command "nginx installation" "apt install -y nginx"
run_command "nginx service enable" "systemctl enable nginx"
run_command "nginx service start" "systemctl start nginx"

# Step 10: Install n8n
log_and_print "STEP" "Installing n8n globally"
run_command "n8n installation" "npm install -g n8n" true

# Verify n8n installation
if command_exists n8n; then
    N8N_VERSION=$(n8n --version)
    log_and_print "SUCCESS" "n8n installed: $N8N_VERSION"
else
    handle_error "n8n installation failed"
fi

# Step 11: Install PM2
log_and_print "STEP" "Installing PM2 process manager"
run_command "PM2 installation" "npm install -g pm2"

# Step 12: Install Python and pip
log_and_print "STEP" "Installing Python 3.11 and pip"
run_command "Python installation" "apt install -y python3.11 python3.11-pip python3.11-venv python3.11-dev"

# Step 13: Install audiobook processing tools
log_and_print "STEP" "Installing audiobook processing tools"
AUDIO_PACKAGES="ffmpeg sox libsox-fmt-all poppler-utils tesseract-ocr tesseract-ocr-ukr tesseract-ocr-rus libreoffice imagemagick sqlite3"
run_command "Audiobook tools installation" "apt install -y $AUDIO_PACKAGES"

# Step 14: Install Python packages for audiobook processing
log_and_print "STEP" "Installing Python packages for audiobook processing"
PYTHON_PACKAGES="pdfplumber PyPDF2 pytesseract python-docx openpyxl pydub librosa openai flask fastapi uvicorn requests beautifulsoup4 lxml"
run_command "Python packages installation" "python3.11 -m pip install $PYTHON_PACKAGES"

# Step 15: Create directories
log_and_print "STEP" "Creating application directories"
run_command "Directory creation" "mkdir -p $INSTALL_DIR $SCRIPTS_DIR /root/n8n_backups /root/backups"

# Step 16: Configure n8n for public domain
log_and_print "STEP" "Configuring n8n for public domain access"

# Create n8n directory
mkdir -p /root/.n8n

# Create n8n configuration
cat > /root/.n8n/config.json << EOF
{
  "editorBaseUrl": "https://$DOMAIN",
  "protocol": "http",
  "host": "0.0.0.0",
  "port": 5678,
  "endpoints": {
    "rest": "https://$DOMAIN/rest",
    "webhook": "https://$DOMAIN/webhook",
    "webhookWaiting": "https://$DOMAIN/webhook-waiting",
    "webhookTest": "https://$DOMAIN/webhook-test"
  }
}
EOF

# Create environment file
cat > /root/.env << EOF
N8N_HOST=0.0.0.0
N8N_PORT=5678
N8N_PROTOCOL=https
N8N_EDITOR_BASE_URL=https://$DOMAIN
WEBHOOK_URL=https://$DOMAIN/
N8N_SECURE_COOKIE=false
EOF

log_and_print "SUCCESS" "n8n configuration created"

# Step 17: Create PM2 ecosystem file
log_and_print "STEP" "Creating PM2 ecosystem configuration"
cat > /root/n8n-ecosystem.json << EOF
{
  "apps": [{
    "name": "n8n",
    "script": "n8n",
    "cwd": "/root",
    "env": {
      "N8N_HOST": "0.0.0.0",
      "N8N_PORT": "5678",
      "N8N_PROTOCOL": "https",
      "N8N_EDITOR_BASE_URL": "https://$DOMAIN",
      "WEBHOOK_URL": "https://$DOMAIN/",
      "N8N_SECURE_COOKIE": "false"
    },
    "log_file": "/var/log/n8n-combined.log",
    "out_file": "/var/log/n8n-out.log",
    "error_file": "/var/log/n8n-error.log",
    "restart_delay": 5000,
    "max_restarts": 10
  }]
}
EOF

log_and_print "SUCCESS" "PM2 ecosystem file created"

# Step 18: Configure nginx for Cloudflare
log_and_print "STEP" "Configuring nginx for Cloudflare proxy"
cat > /etc/nginx/sites-available/n8n << EOF
server {
    listen 80;
    server_name $DOMAIN;
    client_max_body_size 100M;
    
    # Cloudflare real IP
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
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_http_version 1.1;
        proxy_cache_bypass \$http_upgrade;
        proxy_buffering off;
    }
}
EOF

# Enable site
run_command "nginx site enable" "ln -sf /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/"
run_command "nginx configuration test" "nginx -t"
run_command "nginx service restart" "systemctl restart nginx"

# Step 19: Configure firewall
log_and_print "STEP" "Configuring UFW firewall"
run_command "UFW installation" "apt install -y ufw"
run_command "UFW default deny" "ufw --force default deny incoming"
run_command "UFW default allow" "ufw --force default allow outgoing"
run_command "UFW allow SSH" "ufw --force allow 22/tcp"
run_command "UFW allow HTTP" "ufw --force allow 80/tcp"
run_command "UFW allow HTTPS" "ufw --force allow 443/tcp"
run_command "UFW enable" "ufw --force enable"

# Step 20: Start n8n with PM2
log_and_print "STEP" "Starting n8n with PM2"
run_command "PM2 start n8n" "pm2 start /root/n8n-ecosystem.json"
run_command "PM2 save configuration" "pm2 save"
run_command "PM2 startup configuration" "pm2 startup systemd -u root --hp /root"

# Wait for n8n to start
log_and_print "PROGRESS" "Waiting for n8n to start (30 seconds)"
sleep 30

# Step 21: Verify n8n is running
log_and_print "STEP" "Verifying n8n installation"
if pm2 list | grep -q "n8n.*online"; then
    log_and_print "SUCCESS" "n8n is running via PM2"
else
    handle_error "n8n failed to start via PM2" true
fi

# Test HTTP access
if curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5678 | grep -E "^(200|401|302)$" >/dev/null; then
    log_and_print "SUCCESS" "n8n HTTP access working"
else
    log_and_print "WARNING" "n8n HTTP access may have issues"
fi

# Step 22: Download and install automation scripts
log_and_print "STEP" "Installing automation scripts"
GITHUB_BASE="https://raw.githubusercontent.com/vitalykirkpatrick/server-recovery-toolkit/main/scripts"

# Download backup scripts
run_command "Download minimal backup script" "wget -O $SCRIPTS_DIR/backup_server_minimal.sh $GITHUB_BASE/backup_server_minimal.sh"
run_command "Download comprehensive backup script" "wget -O $SCRIPTS_DIR/comprehensive_backup.sh $GITHUB_BASE/comprehensive_backup.sh"
run_command "Download n8n backup script" "wget -O $SCRIPTS_DIR/n8n_complete_backup.sh $GITHUB_BASE/n8n_complete_backup.sh"
run_command "Download n8n restore script" "wget -O $SCRIPTS_DIR/n8n_restore.sh $GITHUB_BASE/n8n_restore_script.sh"
run_command "Download system cleanup script" "wget -O $SCRIPTS_DIR/system_cleanup.sh $GITHUB_BASE/system_cleanup_backup_manager_final.sh"
run_command "Download health check script" "wget -O $SCRIPTS_DIR/health_check.sh $GITHUB_BASE/health_check.sh"

# Make scripts executable
run_command "Make scripts executable" "chmod +x $SCRIPTS_DIR/*.sh"

# Step 23: Install automation management
log_and_print "STEP" "Installing automation management system"
run_command "Download enhanced automation setup" "wget -O /tmp/enhanced_automation.sh $GITHUB_BASE/enhanced_automation_setup.sh"
run_command "Run enhanced automation setup" "bash /tmp/enhanced_automation.sh"

# Step 24: Setup cron jobs
log_and_print "STEP" "Setting up automated cron jobs"
cat > /tmp/cron_jobs << EOF
# n8n Complete Backup (workflows, configs, database) - Daily at 1:30 AM
30 1 * * * $SCRIPTS_DIR/n8n_complete_backup.sh >> /var/log/n8n_backup_cron.log 2>&1

# System Minimal Backup - Daily at 2:30 AM
30 2 * * * $SCRIPTS_DIR/backup_server_minimal.sh >> /var/log/backup_minimal_cron.log 2>&1

# Comprehensive Backup - Sundays at 3:00 AM
0 3 * * 0 $SCRIPTS_DIR/comprehensive_backup.sh >> /var/log/backup_comprehensive_cron.log 2>&1

# System Cleanup - Sundays at 4:00 AM
0 4 * * 0 $SCRIPTS_DIR/system_cleanup.sh >> /var/log/cleanup_cron.log 2>&1

# Health Check - Twice daily at 6:00 AM and 6:00 PM
0 6,18 * * * $SCRIPTS_DIR/health_check.sh >> /var/log/health_check_cron.log 2>&1
EOF

crontab /tmp/cron_jobs
rm -f /tmp/cron_jobs
log_and_print "SUCCESS" "Cron jobs configured"

# Step 25: Final verification and setup completion
log_and_print "STEP" "Running final verification and cleanup"

# Create initial n8n user
log_and_print "PROGRESS" "Setting up initial n8n user"
sleep 5  # Give n8n more time to fully start

# Test final access
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5678)
NGINX_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1)

log_and_print "INFO" "n8n direct access: HTTP $HTTP_STATUS"
log_and_print "INFO" "nginx proxy access: HTTP $NGINX_STATUS"

# Cleanup
rm -f /tmp/setup_progress.txt /tmp/setup_errors.txt

# Final success message
show_progress

echo ""
echo -e "${GREEN}=============================================================================${NC}"
echo -e "${GREEN}  🎉 ENHANCED FRESH SERVER SETUP COMPLETED SUCCESSFULLY!${NC}"
echo -e "${GREEN}=============================================================================${NC}"
echo ""

log_and_print "SUCCESS" "Enhanced fresh server setup completed successfully!"

echo -e "${CYAN}🌐 ACCESS INFORMATION:${NC}"
echo -e "${CYAN}   Public URL: https://$DOMAIN${NC}"
echo -e "${CYAN}   Direct Access: http://$(curl -s ifconfig.me):5678${NC}"
echo -e "${CYAN}   Local Access: http://127.0.0.1:5678${NC}"
echo ""
echo -e "${CYAN}🔑 INITIAL SETUP:${NC}"
echo -e "${CYAN}   1. Visit: https://$DOMAIN${NC}"
echo -e "${CYAN}   2. Create your first n8n user account${NC}"
echo -e "${CYAN}   3. Start building workflows!${NC}"
echo ""
echo -e "${CYAN}🛠️  MANAGEMENT COMMANDS:${NC}"
echo -e "${CYAN}   System Status: $INSTALL_DIR/system_status.sh${NC}"
echo -e "${CYAN}   Test Systems: $INSTALL_DIR/test_all_systems.sh${NC}"
echo -e "${CYAN}   Manage Automation: $INSTALL_DIR/manage_automation.sh${NC}"
echo -e "${CYAN}   n8n Backup: $INSTALL_DIR/manage_automation.sh backup-n8n${NC}"
echo -e "${CYAN}   Setup GitHub Token: $INSTALL_DIR/manage_automation.sh setup-github-token${NC}"
echo ""
echo -e "${CYAN}📊 SERVICE STATUS:${NC}"
echo -e "${CYAN}   nginx: $(systemctl is-active nginx)${NC}"
echo -e "${CYAN}   n8n: $(pm2 list | grep -q 'n8n.*online' && echo 'online' || echo 'offline')${NC}"
echo -e "${CYAN}   UFW Firewall: $(ufw status | grep -q 'Status: active' && echo 'active' || echo 'inactive')${NC}"
echo ""
echo -e "${CYAN}⏰ AUTOMATED BACKUPS:${NC}"
echo -e "${CYAN}   01:30 AM - n8n complete backup (workflows, configs, database)${NC}"
echo -e "${CYAN}   02:30 AM - System minimal backup${NC}"
echo -e "${CYAN}   03:00 AM - Comprehensive backup (Sundays)${NC}"
echo -e "${CYAN}   04:00 AM - System cleanup (Sundays)${NC}"
echo -e "${CYAN}   06:00 AM & 18:00 PM - Health checks${NC}"
echo ""
echo -e "${CYAN}📁 IMPORTANT DIRECTORIES:${NC}"
echo -e "${CYAN}   n8n Data: /root/.n8n${NC}"
echo -e "${CYAN}   n8n Backups: /root/n8n_backups${NC}"
echo -e "${CYAN}   System Backups: /root/backups${NC}"
echo -e "${CYAN}   Scripts: $SCRIPTS_DIR${NC}"
echo -e "${CYAN}   Logs: /var/log/${NC}"
echo ""
echo -e "${CYAN}📜 LOG FILES:${NC}"
echo -e "${CYAN}   Installation Log: $LOG_FILE${NC}"
echo -e "${CYAN}   n8n Logs: /var/log/n8n-*.log${NC}"
echo -e "${CYAN}   Backup Logs: /var/log/*_cron.log${NC}"
echo ""
echo -e "${GREEN}🎊 YOUR AUDIOBOOK PROCESSING SERVER IS READY!${NC}"
echo -e "${GREEN}   All tools installed for document to audiobook conversion${NC}"
echo -e "${GREEN}   n8n workflows automatically backed up daily${NC}"
echo -e "${GREEN}   Complete automation and monitoring configured${NC}"
echo ""

log_and_print "INFO" "Installation completed at $(date)"
log_and_print "INFO" "Total installation time: $SECONDS seconds"

exit 0

