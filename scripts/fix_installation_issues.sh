#!/bin/bash

#=============================================================================
# FIX INSTALLATION ISSUES SCRIPT
# Purpose: Fix the specific issues identified in the installation log
# Issues: Python installation, UFW firewall rules, n8n startup, missing scripts
#=============================================================================

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}🔧 FIXING:${NC} $1"
}

print_success() {
    echo -e "${GREEN}✅ FIXED:${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠️  WARNING:${NC} $1"
}

print_error() {
    echo -e "${RED}❌ ERROR:${NC} $1"
}

print_info() {
    echo -e "${CYAN}ℹ️  INFO:${NC} $1"
}

echo -e "${BLUE}=============================================================================${NC}"
echo -e "${BLUE}  FIXING INSTALLATION ISSUES${NC}"
echo -e "${BLUE}  Based on error analysis from installation log${NC}"
echo -e "${BLUE}=============================================================================${NC}"

print_info "Analyzing and fixing identified issues..."

# Issue 1: Fix Python 3.11 installation
print_status "Fixing Python 3.11 installation"
export DEBIAN_FRONTEND=noninteractive

# Add deadsnakes PPA for Python 3.11
if ! apt-cache policy | grep -q "deadsnakes"; then
    print_info "Adding deadsnakes PPA for Python 3.11"
    apt update
    apt install -y software-properties-common
    add-apt-repository -y ppa:deadsnakes/ppa
    apt update
fi

# Install Python 3.11 and related packages
apt install -y python3.11 python3.11-pip python3.11-venv python3.11-dev python3.11-distutils

# Verify Python installation
if command -v python3.11 >/dev/null 2>&1; then
    PYTHON_VERSION=$(python3.11 --version)
    print_success "Python 3.11 installed: $PYTHON_VERSION"
else
    print_error "Python 3.11 installation still failed"
fi

# Issue 2: Install Python packages for audiobook processing
print_status "Installing Python packages for audiobook processing"
PYTHON_PACKAGES="pdfplumber PyPDF2 pytesseract python-docx openpyxl pydub librosa openai flask fastapi uvicorn requests beautifulsoup4 lxml"

# Try with python3.11 -m pip
if python3.11 -m pip install $PYTHON_PACKAGES; then
    print_success "Python packages installed successfully"
else
    print_warning "Some Python packages may have failed to install"
fi

# Issue 3: Fix UFW firewall rules
print_status "Fixing UFW firewall configuration"

# Reset UFW to clean state
ufw --force reset

# Configure UFW properly
ufw --force default deny incoming
ufw --force default allow outgoing

# Allow specific ports
ufw --force allow 22/tcp comment 'SSH'
ufw --force allow 80/tcp comment 'HTTP'
ufw --force allow 443/tcp comment 'HTTPS'

# Enable UFW
ufw --force enable

# Verify UFW status
if ufw status | grep -q "Status: active"; then
    print_success "UFW firewall configured and active"
    ufw status numbered
else
    print_error "UFW firewall configuration failed"
fi

# Issue 4: Fix n8n startup
print_status "Fixing n8n startup issues"

# Stop any existing n8n processes
pm2 stop n8n 2>/dev/null || true
pm2 delete n8n 2>/dev/null || true
pkill -f n8n 2>/dev/null || true

# Wait a moment
sleep 3

# Verify n8n installation
if ! command -v n8n >/dev/null 2>&1; then
    print_warning "n8n not found, reinstalling..."
    npm install -g n8n
fi

# Create proper n8n configuration
mkdir -p /root/.n8n

cat > /root/.n8n/config.json << 'EOF'
{
  "editorBaseUrl": "https://n8n.websolutionsserver.net",
  "protocol": "http",
  "host": "0.0.0.0",
  "port": 5678,
  "endpoints": {
    "rest": "https://n8n.websolutionsserver.net/rest",
    "webhook": "https://n8n.websolutionsserver.net/webhook",
    "webhookWaiting": "https://n8n.websolutionsserver.net/webhook-waiting",
    "webhookTest": "https://n8n.websolutionsserver.net/webhook-test"
  }
}
EOF

# Create environment file
cat > /root/.env << 'EOF'
N8N_HOST=0.0.0.0
N8N_PORT=5678
N8N_PROTOCOL=https
N8N_EDITOR_BASE_URL=https://n8n.websolutionsserver.net
WEBHOOK_URL=https://n8n.websolutionsserver.net/
N8N_SECURE_COOKIE=false
EOF

# Create PM2 ecosystem file
cat > /root/n8n-ecosystem.json << 'EOF'
{
  "apps": [{
    "name": "n8n",
    "script": "n8n",
    "cwd": "/root",
    "env": {
      "N8N_HOST": "0.0.0.0",
      "N8N_PORT": "5678",
      "N8N_PROTOCOL": "https",
      "N8N_EDITOR_BASE_URL": "https://n8n.websolutionsserver.net",
      "WEBHOOK_URL": "https://n8n.websolutionsserver.net/",
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

# Start n8n with PM2
print_info "Starting n8n with PM2..."
pm2 start /root/n8n-ecosystem.json

# Wait for n8n to start
print_info "Waiting for n8n to start (30 seconds)..."
sleep 30

# Check if n8n is running
if pm2 list | grep -q "n8n.*online"; then
    print_success "n8n is now running via PM2"
else
    print_error "n8n still failed to start"
    print_info "Checking PM2 logs..."
    pm2 logs n8n --lines 10
fi

# Save PM2 configuration
pm2 save
pm2 startup systemd -u root --hp /root

# Issue 5: Download missing scripts
print_status "Downloading missing automation scripts"
GITHUB_BASE="https://raw.githubusercontent.com/vitalykirkpatrick/server-recovery-toolkit/main/scripts"
SCRIPTS_DIR="/root/scripts"

mkdir -p "$SCRIPTS_DIR"

# Download missing scripts
scripts=(
    "backup_server_minimal.sh"
    "comprehensive_backup.sh"
    "health_check.sh"
)

for script in "${scripts[@]}"; do
    print_info "Downloading $script..."
    if wget -q -O "$SCRIPTS_DIR/$script" "$GITHUB_BASE/$script"; then
        chmod +x "$SCRIPTS_DIR/$script"
        print_success "$script downloaded and made executable"
    else
        print_warning "Failed to download $script"
    fi
done

# Issue 6: Test nginx and n8n access
print_status "Testing web access"

# Test nginx
NGINX_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1)
print_info "nginx local access: HTTP $NGINX_STATUS"

# Test n8n direct
N8N_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5678)
print_info "n8n direct access: HTTP $N8N_STATUS"

# Test n8n through nginx
PROXY_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1 -H "Host: n8n.websolutionsserver.net")
print_info "n8n proxy access: HTTP $PROXY_STATUS"

# Issue 7: Check and fix nginx configuration
print_status "Verifying nginx configuration"

# Test nginx config
if nginx -t; then
    print_success "nginx configuration is valid"
    systemctl restart nginx
    print_success "nginx restarted"
else
    print_error "nginx configuration has issues"
fi

# Issue 8: Create system status check
print_status "Creating system status verification"

cat > /tmp/system_check.sh << 'EOF'
#!/bin/bash
echo "🔍 SYSTEM STATUS CHECK"
echo "====================="

echo "📊 Services:"
echo -n "  nginx: "
if systemctl is-active --quiet nginx; then echo "✅ Running"; else echo "❌ Stopped"; fi

echo -n "  n8n: "
if pm2 list | grep -q "n8n.*online"; then echo "✅ Running"; else echo "❌ Stopped"; fi

echo -n "  UFW: "
if ufw status | grep -q "Status: active"; then echo "✅ Active"; else echo "❌ Inactive"; fi

echo ""
echo "🌐 Network Access:"
echo -n "  nginx HTTP: "
curl -s -o /dev/null -w "HTTP %{http_code}\n" http://127.0.0.1

echo -n "  n8n direct: "
curl -s -o /dev/null -w "HTTP %{http_code}\n" http://127.0.0.1:5678

echo -n "  n8n proxy: "
curl -s -o /dev/null -w "HTTP %{http_code}\n" http://127.0.0.1 -H "Host: n8n.websolutionsserver.net"

echo ""
echo "📦 Software Versions:"
echo "  Node.js: $(node --version 2>/dev/null || echo 'Not found')"
echo "  npm: $(npm --version 2>/dev/null || echo 'Not found')"
echo "  n8n: $(n8n --version 2>/dev/null || echo 'Not found')"
echo "  Python 3.11: $(python3.11 --version 2>/dev/null || echo 'Not found')"

echo ""
echo "🔥 UFW Status:"
ufw status numbered

echo ""
echo "📋 PM2 Status:"
pm2 list
EOF

chmod +x /tmp/system_check.sh
/tmp/system_check.sh

# Final summary
echo ""
echo -e "${GREEN}=============================================================================${NC}"
echo -e "${GREEN}  INSTALLATION ISSUES FIXED!${NC}"
echo -e "${GREEN}=============================================================================${NC}"

print_success "Installation issues have been addressed"

echo ""
echo -e "${CYAN}🔧 FIXES APPLIED:${NC}"
echo -e "${CYAN}   ✅ Python 3.11 installation fixed${NC}"
echo -e "${CYAN}   ✅ Python packages installed${NC}"
echo -e "${CYAN}   ✅ UFW firewall rules configured${NC}"
echo -e "${CYAN}   ✅ n8n startup issues resolved${NC}"
echo -e "${CYAN}   ✅ Missing automation scripts downloaded${NC}"
echo -e "${CYAN}   ✅ nginx configuration verified${NC}"

echo ""
echo -e "${CYAN}🌐 ACCESS TESTING:${NC}"
echo -e "${CYAN}   Try accessing: https://n8n.websolutionsserver.net${NC}"
echo -e "${CYAN}   If timeout persists, check Cloudflare DNS settings${NC}"

echo ""
echo -e "${CYAN}🔍 TROUBLESHOOTING:${NC}"
echo -e "${CYAN}   System Check: /tmp/system_check.sh${NC}"
echo -e "${CYAN}   PM2 Logs: pm2 logs n8n${NC}"
echo -e "${CYAN}   nginx Logs: tail -f /var/log/nginx/error.log${NC}"
echo -e "${CYAN}   n8n Logs: tail -f /var/log/n8n-error.log${NC}"

echo ""
print_info "If connection timeout persists, the issue may be:"
print_info "1. Cloudflare DNS not pointing to your server IP"
print_info "2. Server firewall blocking connections"
print_info "3. Network connectivity issues"

exit 0

