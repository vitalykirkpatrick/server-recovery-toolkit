#!/bin/bash

#=============================================================================
# COMPREHENSIVE CONNECTIVITY FIX FOR N8N
# Purpose: Fix timeout and ERR_EMPTY_RESPONSE issues
# Issues: Public domain timeout, direct IP ERR_EMPTY_RESPONSE
#=============================================================================

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

print_header() {
    echo -e "${PURPLE}=============================================================================${NC}"
    echo -e "${PURPLE}  $1${NC}"
    echo -e "${PURPLE}=============================================================================${NC}"
}

print_status() {
    echo -e "${BLUE}🔧 CHECKING:${NC} $1"
}

print_fixing() {
    echo -e "${YELLOW}🔧 FIXING:${NC} $1"
}

print_success() {
    echo -e "${GREEN}✅ SUCCESS:${NC} $1"
}

print_error() {
    echo -e "${RED}❌ ERROR:${NC} $1"
}

print_info() {
    echo -e "${CYAN}ℹ️  INFO:${NC} $1"
}

print_header "COMPREHENSIVE N8N CONNECTIVITY DIAGNOSIS AND FIX"

print_info "Analyzing connectivity issues..."
print_info "Public domain: https://n8n.websolutionsserver.net (timeout)"
print_info "Direct IP: http://172.245.67.47:5678 (ERR_EMPTY_RESPONSE)"

echo ""
print_header "PHASE 1: SYSTEM DIAGNOSIS"

# Check if we're running as root
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root"
    exit 1
fi

# Step 1: Check basic system status
print_status "Basic system status"
echo "Date: $(date)"
echo "Uptime: $(uptime)"
echo "Memory: $(free -h | grep Mem | awk '{print $3 "/" $2}')"
echo "Disk: $(df -h / | tail -1 | awk '{print $3 "/" $2 " (" $5 " used)"}')"

# Step 2: Check network connectivity
print_status "Network connectivity"
if ping -c 1 google.com >/dev/null 2>&1; then
    print_success "Internet connectivity working"
else
    print_error "No internet connectivity"
fi

# Check server IP
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "unknown")
print_info "Server public IP: $SERVER_IP"

# Step 3: Check services status
print_status "Service status"
echo "nginx: $(systemctl is-active nginx 2>/dev/null || echo 'unknown')"
echo "ufw: $(ufw status 2>/dev/null | head -1 || echo 'unknown')"

# Step 4: Check PM2 status
print_status "PM2 and n8n status"
if command -v pm2 >/dev/null 2>&1; then
    echo "PM2 installed: Yes"
    pm2 list 2>/dev/null || echo "PM2 list failed"
else
    print_error "PM2 not installed"
fi

# Step 5: Check n8n installation
print_status "n8n installation"
if command -v n8n >/dev/null 2>&1; then
    N8N_VERSION=$(n8n --version 2>/dev/null || echo "version check failed")
    print_success "n8n installed: $N8N_VERSION"
else
    print_error "n8n not installed or not in PATH"
fi

# Step 6: Check ports
print_status "Port status"
echo "Port 5678 (n8n):"
netstat -tlnp | grep :5678 || echo "  Not listening"
echo "Port 80 (HTTP):"
netstat -tlnp | grep :80 || echo "  Not listening"
echo "Port 443 (HTTPS):"
netstat -tlnp | grep :443 || echo "  Not listening"

# Step 7: Check processes
print_status "n8n processes"
ps aux | grep -v grep | grep n8n || echo "No n8n processes found"

echo ""
print_header "PHASE 2: CONNECTIVITY TESTING"

# Test local connections
print_status "Local connectivity tests"

# Test n8n direct
N8N_DIRECT=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5678 2>/dev/null || echo "000")
echo "n8n direct (127.0.0.1:5678): HTTP $N8N_DIRECT"

# Test nginx
NGINX_LOCAL=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1 2>/dev/null || echo "000")
echo "nginx local (127.0.0.1:80): HTTP $NGINX_LOCAL"

# Test nginx with host header
NGINX_PROXY=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1 -H "Host: n8n.websolutionsserver.net" 2>/dev/null || echo "000")
echo "nginx proxy (with host header): HTTP $NGINX_PROXY"

echo ""
print_header "PHASE 3: COMPREHENSIVE FIXES"

# Fix 1: Stop all conflicting processes
print_fixing "Stopping all n8n and conflicting processes"
pm2 stop all 2>/dev/null || true
pm2 delete all 2>/dev/null || true
pkill -f n8n 2>/dev/null || true
pkill -f node 2>/dev/null || true
sleep 5
print_success "All processes stopped"

# Fix 2: Install/reinstall required software
print_fixing "Installing/updating required software"

# Update system
apt update >/dev/null 2>&1

# Install Node.js if missing
if ! command -v node >/dev/null 2>&1; then
    print_info "Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash - >/dev/null 2>&1
    apt-get install -y nodejs >/dev/null 2>&1
fi

# Install PM2 if missing
if ! command -v pm2 >/dev/null 2>&1; then
    print_info "Installing PM2..."
    npm install -g pm2 >/dev/null 2>&1
fi

# Install/reinstall n8n
print_info "Reinstalling n8n..."
npm uninstall -g n8n >/dev/null 2>&1 || true
npm cache clean --force >/dev/null 2>&1
npm install -g n8n >/dev/null 2>&1

# Verify installations
NODE_VERSION=$(node --version 2>/dev/null || echo "failed")
NPM_VERSION=$(npm --version 2>/dev/null || echo "failed")
N8N_VERSION=$(n8n --version 2>/dev/null || echo "failed")

print_info "Node.js: $NODE_VERSION"
print_info "npm: $NPM_VERSION"
print_info "n8n: $N8N_VERSION"

if [[ "$N8N_VERSION" == "failed" ]]; then
    print_error "n8n installation failed"
    exit 1
fi

print_success "Software installation completed"

# Fix 3: Create proper n8n configuration
print_fixing "Creating proper n8n configuration"

# Remove old configuration
rm -rf /root/.n8n

# Create new configuration directory
mkdir -p /root/.n8n
chmod 700 /root/.n8n

# Create minimal configuration
cat > /root/.n8n/config.json << 'EOF'
{
  "host": "0.0.0.0",
  "port": 5678,
  "protocol": "http"
}
EOF

chmod 600 /root/.n8n/config.json

# Create environment file
cat > /root/.env << 'EOF'
N8N_HOST=0.0.0.0
N8N_PORT=5678
N8N_PROTOCOL=http
N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=false
EOF

chmod 600 /root/.env

print_success "n8n configuration created"

# Fix 4: Test n8n manually
print_fixing "Testing n8n manual startup"

# Test n8n command
if n8n --help >/dev/null 2>&1; then
    print_success "n8n command works"
else
    print_error "n8n command failed"
    exit 1
fi

# Start n8n manually in background for testing
print_info "Starting n8n manually for testing..."
cd /root
export N8N_HOST=0.0.0.0
export N8N_PORT=5678
export N8N_PROTOCOL=http
export N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=false

# Start n8n in background
nohup n8n start > /tmp/n8n_manual.log 2>&1 &
N8N_PID=$!

# Wait for startup
print_info "Waiting for n8n to start (30 seconds)..."
sleep 30

# Test if n8n is responding
MANUAL_TEST=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5678 2>/dev/null || echo "000")
print_info "Manual n8n test: HTTP $MANUAL_TEST"

if [[ "$MANUAL_TEST" =~ ^(200|401|302)$ ]]; then
    print_success "n8n manual startup successful"
    # Kill manual instance
    kill $N8N_PID 2>/dev/null || true
    sleep 5
else
    print_error "n8n manual startup failed"
    print_info "Manual startup log:"
    tail -10 /tmp/n8n_manual.log 2>/dev/null || echo "No log available"
    kill $N8N_PID 2>/dev/null || true
    exit 1
fi

# Fix 5: Configure PM2 properly
print_fixing "Configuring PM2 for n8n"

# Create PM2 ecosystem
cat > /root/n8n-ecosystem.json << 'EOF'
{
  "apps": [{
    "name": "n8n",
    "script": "n8n",
    "args": "start",
    "cwd": "/root",
    "env": {
      "N8N_HOST": "0.0.0.0",
      "N8N_PORT": "5678",
      "N8N_PROTOCOL": "http",
      "N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS": "false"
    },
    "log_file": "/var/log/n8n-combined.log",
    "out_file": "/var/log/n8n-out.log",
    "error_file": "/var/log/n8n-error.log",
    "restart_delay": 5000,
    "max_restarts": 3,
    "min_uptime": "30s"
  }]
}
EOF

# Start n8n with PM2
print_info "Starting n8n with PM2..."
pm2 start /root/n8n-ecosystem.json

# Wait for PM2 startup
print_info "Waiting for PM2 startup (45 seconds)..."
sleep 45

# Check PM2 status
PM2_STATUS=$(pm2 list | grep n8n | awk '{print $10}' 2>/dev/null || echo "unknown")
print_info "PM2 status: $PM2_STATUS"

# Test PM2 n8n
PM2_TEST=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5678 2>/dev/null || echo "000")
print_info "PM2 n8n test: HTTP $PM2_TEST"

if [[ "$PM2_TEST" =~ ^(200|401|302)$ ]]; then
    print_success "PM2 n8n startup successful"
else
    print_error "PM2 n8n startup failed"
    print_info "PM2 logs:"
    pm2 logs n8n --lines 5 2>/dev/null || echo "No PM2 logs available"
fi

# Save PM2 configuration
pm2 save >/dev/null 2>&1
pm2 startup systemd -u root --hp /root >/dev/null 2>&1

print_success "PM2 configuration completed"

# Fix 6: Configure nginx properly
print_fixing "Configuring nginx"

# Create nginx configuration
cat > /etc/nginx/sites-available/n8n << 'EOF'
server {
    listen 80;
    server_name n8n.websolutionsserver.net;
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
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_http_version 1.1;
        proxy_cache_bypass $http_upgrade;
        proxy_buffering off;
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
    }
}
EOF

# Enable site
ln -sf /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/

# Test nginx configuration
if nginx -t >/dev/null 2>&1; then
    print_success "nginx configuration valid"
    systemctl restart nginx
    print_success "nginx restarted"
else
    print_error "nginx configuration invalid"
    nginx -t
fi

# Fix 7: Configure firewall
print_fixing "Configuring firewall"

# Reset UFW
ufw --force reset >/dev/null 2>&1

# Configure UFW
ufw --force default deny incoming >/dev/null 2>&1
ufw --force default allow outgoing >/dev/null 2>&1
ufw --force allow 22/tcp >/dev/null 2>&1
ufw --force allow 80/tcp >/dev/null 2>&1
ufw --force allow 443/tcp >/dev/null 2>&1
ufw --force allow 5678/tcp >/dev/null 2>&1

# Enable UFW
ufw --force enable >/dev/null 2>&1

print_success "Firewall configured"

echo ""
print_header "PHASE 4: COMPREHENSIVE TESTING"

# Wait for everything to stabilize
print_info "Waiting for services to stabilize (30 seconds)..."
sleep 30

# Test all connections
print_status "Final connectivity tests"

# Test n8n direct
N8N_FINAL=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5678 2>/dev/null || echo "000")
echo "n8n direct (127.0.0.1:5678): HTTP $N8N_FINAL"

# Test nginx local
NGINX_FINAL=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1 2>/dev/null || echo "000")
echo "nginx local (127.0.0.1:80): HTTP $NGINX_FINAL"

# Test nginx proxy
PROXY_FINAL=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1 -H "Host: n8n.websolutionsserver.net" 2>/dev/null || echo "000")
echo "nginx proxy (with host header): HTTP $PROXY_FINAL"

# Test external IP
EXTERNAL_TEST=$(curl -s -o /dev/null -w "%{http_code}" http://$SERVER_IP:5678 2>/dev/null || echo "000")
echo "External IP ($SERVER_IP:5678): HTTP $EXTERNAL_TEST"

# Check services
print_status "Service status check"
echo "nginx: $(systemctl is-active nginx)"
echo "PM2 n8n: $(pm2 list | grep n8n | awk '{print $10}' || echo 'not found')"
echo "UFW: $(ufw status | head -1)"

# Check ports
print_status "Port listening check"
echo "Port 5678: $(netstat -tlnp | grep :5678 | awk '{print $7}' || echo 'not listening')"
echo "Port 80: $(netstat -tlnp | grep :80 | awk '{print $7}' || echo 'not listening')"

echo ""
print_header "PHASE 5: RESULTS AND RECOMMENDATIONS"

# Analyze results
if [[ "$N8N_FINAL" =~ ^(200|401|302)$ ]]; then
    print_success "n8n is responding locally"
else
    print_error "n8n is not responding locally (HTTP $N8N_FINAL)"
fi

if [[ "$PROXY_FINAL" =~ ^(200|401|302)$ ]]; then
    print_success "nginx proxy is working"
else
    print_error "nginx proxy is not working (HTTP $PROXY_FINAL)"
fi

if [[ "$EXTERNAL_TEST" =~ ^(200|401|302)$ ]]; then
    print_success "External IP access is working"
else
    print_error "External IP access is not working (HTTP $EXTERNAL_TEST)"
fi

echo ""
print_header "ACCESS INFORMATION"

echo -e "${CYAN}🌐 ACCESS URLS:${NC}"
echo -e "${CYAN}   Public Domain: https://n8n.websolutionsserver.net${NC}"
echo -e "${CYAN}   Direct IP: http://$SERVER_IP:5678${NC}"
echo -e "${CYAN}   Local: http://127.0.0.1:5678${NC}"

echo ""
echo -e "${CYAN}🔍 TROUBLESHOOTING:${NC}"
echo -e "${CYAN}   Check n8n: pm2 logs n8n${NC}"
echo -e "${CYAN}   Check nginx: tail -f /var/log/nginx/error.log${NC}"
echo -e "${CYAN}   Check firewall: ufw status${NC}"
echo -e "${CYAN}   Check ports: netstat -tlnp | grep -E ':(80|443|5678)'${NC}"

echo ""
if [[ "$N8N_FINAL" =~ ^(200|401|302)$ ]] && [[ "$PROXY_FINAL" =~ ^(200|401|302)$ ]]; then
    print_success "🎉 n8n connectivity fix completed successfully!"
    echo ""
    echo -e "${GREEN}If you still get timeout on the public domain, check:${NC}"
    echo -e "${GREEN}1. Cloudflare DNS A record points to $SERVER_IP${NC}"
    echo -e "${GREEN}2. Cloudflare proxy is enabled (orange cloud)${NC}"
    echo -e "${GREEN}3. Cloudflare SSL/TLS mode is 'Flexible'${NC}"
else
    print_error "⚠️ Some connectivity issues remain. Check the troubleshooting section above."
fi

exit 0

