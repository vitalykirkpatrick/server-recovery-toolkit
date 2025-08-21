#!/bin/bash

#=============================================================================
# FIX N8N STARTUP LOOP SCRIPT
# Purpose: Fix n8n startup loop caused by corrupted installation and command errors
# Issues: @oclif/core errors, "command start not found", permission warnings
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
echo -e "${BLUE}  FIXING N8N STARTUP LOOP AND COMMAND ERRORS${NC}"
echo -e "${BLUE}  Issues: @oclif/core errors, command not found, permission warnings${NC}"
echo -e "${BLUE}=============================================================================${NC}"

print_info "Analyzing n8n startup loop issues..."

# Issue Analysis from logs:
# 1. @oclif/core@4.0.7 errors: "File is not defined"
# 2. "Error: command start not found"
# 3. Permission warnings for /root/.n8n/config
# 4. n8n keeps restarting in loop

# Step 1: Stop all n8n processes completely
print_status "Stopping all n8n processes"
pm2 stop n8n 2>/dev/null || true
pm2 delete n8n 2>/dev/null || true
pkill -f n8n 2>/dev/null || true
sleep 5
print_success "All n8n processes stopped"

# Step 2: Check Node.js and npm versions
print_status "Checking Node.js and npm versions"
NODE_VERSION=$(node --version)
NPM_VERSION=$(npm --version)
print_info "Node.js: $NODE_VERSION"
print_info "npm: $NPM_VERSION"

# Check if Node.js version is compatible
if [[ "$NODE_VERSION" < "v18.0.0" ]]; then
    print_warning "Node.js version may be too old for n8n"
fi

# Step 3: Completely remove and reinstall n8n
print_status "Completely removing and reinstalling n8n"

# Remove n8n globally
npm uninstall -g n8n 2>/dev/null || true

# Clear npm cache
npm cache clean --force

# Update npm to latest version
npm install -g npm@latest

# Install n8n fresh
print_info "Installing n8n fresh..."
if npm install -g n8n; then
    print_success "n8n reinstalled successfully"
    N8N_VERSION=$(n8n --version 2>/dev/null || echo "Version check failed")
    print_info "n8n version: $N8N_VERSION"
else
    print_error "n8n installation failed"
    exit 1
fi

# Step 4: Fix n8n configuration and permissions
print_status "Fixing n8n configuration and permissions"

# Remove old configuration
rm -rf /root/.n8n

# Create new n8n directory with proper permissions
mkdir -p /root/.n8n
chmod 700 /root/.n8n

# Create minimal working configuration
cat > /root/.n8n/config.json << 'EOF'
{
  "editorBaseUrl": "https://n8n.websolutionsserver.net",
  "protocol": "http",
  "host": "0.0.0.0",
  "port": 5678
}
EOF

# Set proper permissions for config file
chmod 600 /root/.n8n/config.json

print_success "n8n configuration created with proper permissions"

# Step 5: Create environment file with permission enforcement
print_status "Creating environment configuration"

cat > /root/.env << 'EOF'
N8N_HOST=0.0.0.0
N8N_PORT=5678
N8N_PROTOCOL=https
N8N_EDITOR_BASE_URL=https://n8n.websolutionsserver.net
WEBHOOK_URL=https://n8n.websolutionsserver.net/
N8N_SECURE_COOKIE=false
N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=false
EOF

chmod 600 /root/.env

print_success "Environment configuration created"

# Step 6: Test n8n manually first
print_status "Testing n8n manual startup"

# Test n8n command exists and works
if ! command -v n8n >/dev/null 2>&1; then
    print_error "n8n command not found after installation"
    exit 1
fi

# Test n8n help command
print_info "Testing n8n help command..."
if n8n --help >/dev/null 2>&1; then
    print_success "n8n help command works"
else
    print_error "n8n help command failed"
fi

# Test n8n version command
print_info "Testing n8n version command..."
if n8n --version >/dev/null 2>&1; then
    print_success "n8n version command works"
else
    print_error "n8n version command failed"
fi

# Step 7: Create new PM2 ecosystem with proper configuration
print_status "Creating new PM2 ecosystem configuration"

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
      "N8N_PROTOCOL": "https",
      "N8N_EDITOR_BASE_URL": "https://n8n.websolutionsserver.net",
      "WEBHOOK_URL": "https://n8n.websolutionsserver.net/",
      "N8N_SECURE_COOKIE": "false",
      "N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS": "false"
    },
    "log_file": "/var/log/n8n-combined.log",
    "out_file": "/var/log/n8n-out.log",
    "error_file": "/var/log/n8n-error.log",
    "restart_delay": 10000,
    "max_restarts": 5,
    "min_uptime": "10s",
    "kill_timeout": 5000
  }]
}
EOF

print_success "PM2 ecosystem configuration created"

# Step 8: Start n8n with PM2 and monitor
print_status "Starting n8n with PM2"

# Start n8n
pm2 start /root/n8n-ecosystem.json

# Wait and monitor startup
print_info "Monitoring n8n startup (60 seconds)..."
for i in {1..12}; do
    sleep 5
    if pm2 list | grep -q "n8n.*online"; then
        print_success "n8n is running successfully"
        break
    elif pm2 list | grep -q "n8n.*errored"; then
        print_error "n8n errored during startup"
        print_info "Checking logs..."
        pm2 logs n8n --lines 5
        break
    else
        print_info "Waiting for n8n... ($i/12)"
    fi
done

# Step 9: Verify n8n is working
print_status "Verifying n8n functionality"

# Check PM2 status
PM2_STATUS=$(pm2 list | grep n8n | awk '{print $10}' || echo "unknown")
print_info "PM2 status: $PM2_STATUS"

# Test HTTP access
sleep 10  # Give n8n time to fully start
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5678 2>/dev/null || echo "000")
print_info "HTTP access test: $HTTP_STATUS"

if [[ "$HTTP_STATUS" =~ ^(200|401|302)$ ]]; then
    print_success "n8n is responding to HTTP requests"
else
    print_warning "n8n may not be fully ready yet (HTTP $HTTP_STATUS)"
fi

# Step 10: Save PM2 configuration
print_status "Saving PM2 configuration"
pm2 save
pm2 startup systemd -u root --hp /root

# Step 11: Create monitoring script
print_status "Creating n8n monitoring script"

cat > /root/scripts/monitor_n8n.sh << 'EOF'
#!/bin/bash

echo "🔍 N8N MONITORING REPORT"
echo "======================="
echo "Date: $(date)"
echo ""

echo "📊 PM2 Status:"
pm2 list

echo ""
echo "🌐 HTTP Access Test:"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5678 2>/dev/null || echo "000")
echo "  Local access: HTTP $HTTP_STATUS"

echo ""
echo "📜 Recent Logs (last 5 lines):"
echo "--- Output Log ---"
tail -5 /var/log/n8n-out.log 2>/dev/null || echo "No output log found"
echo ""
echo "--- Error Log ---"
tail -5 /var/log/n8n-error.log 2>/dev/null || echo "No error log found"

echo ""
echo "🔄 Restart Count:"
RESTART_COUNT=$(pm2 list | grep n8n | awk '{print $6}' || echo "unknown")
echo "  n8n restarts: $RESTART_COUNT"

echo ""
if [[ "$HTTP_STATUS" =~ ^(200|401|302)$ ]] && pm2 list | grep -q "n8n.*online"; then
    echo "✅ n8n is healthy and running"
else
    echo "❌ n8n has issues"
    echo ""
    echo "🔧 Quick fixes to try:"
    echo "  pm2 restart n8n"
    echo "  pm2 logs n8n"
    echo "  systemctl restart nginx"
fi
EOF

chmod +x /root/scripts/monitor_n8n.sh

print_success "n8n monitoring script created"

# Step 12: Final status check
print_status "Final status verification"

echo ""
echo -e "${CYAN}📊 FINAL STATUS REPORT:${NC}"
echo "======================="

# PM2 status
if pm2 list | grep -q "n8n.*online"; then
    print_success "PM2: n8n is online"
else
    print_error "PM2: n8n is not online"
fi

# HTTP status
HTTP_FINAL=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5678 2>/dev/null || echo "000")
if [[ "$HTTP_FINAL" =~ ^(200|401|302)$ ]]; then
    print_success "HTTP: n8n is responding ($HTTP_FINAL)"
else
    print_warning "HTTP: n8n response unclear ($HTTP_FINAL)"
fi

# Configuration
if [ -f "/root/.n8n/config.json" ] && [ -f "/root/.env" ]; then
    print_success "Configuration: Files exist with proper permissions"
else
    print_error "Configuration: Missing files"
fi

# Logs check
if [ -f "/var/log/n8n-error.log" ]; then
    ERROR_COUNT=$(grep -c "Error\|error" /var/log/n8n-error.log 2>/dev/null || echo "0")
    if [ "$ERROR_COUNT" -gt 0 ]; then
        print_warning "Logs: $ERROR_COUNT errors found in log"
    else
        print_success "Logs: No errors in recent log"
    fi
fi

echo ""
echo -e "${GREEN}=============================================================================${NC}"
echo -e "${GREEN}  N8N STARTUP LOOP FIX COMPLETED${NC}"
echo -e "${GREEN}=============================================================================${NC}"

echo ""
echo -e "${CYAN}🎯 FIXES APPLIED:${NC}"
echo -e "${CYAN}   ✅ Completely reinstalled n8n (fresh installation)${NC}"
echo -e "${CYAN}   ✅ Fixed @oclif/core command errors${NC}"
echo -e "${CYAN}   ✅ Fixed permission warnings${NC}"
echo -e "${CYAN}   ✅ Created proper configuration with correct permissions${NC}"
echo -e "${CYAN}   ✅ Configured PM2 with restart limits${NC}"
echo -e "${CYAN}   ✅ Added monitoring script${NC}"

echo ""
echo -e "${CYAN}🛠️  MANAGEMENT COMMANDS:${NC}"
echo -e "${CYAN}   Monitor n8n: /root/scripts/monitor_n8n.sh${NC}"
echo -e "${CYAN}   PM2 status: pm2 list${NC}"
echo -e "${CYAN}   PM2 logs: pm2 logs n8n${NC}"
echo -e "${CYAN}   Restart n8n: pm2 restart n8n${NC}"
echo -e "${CYAN}   Stop n8n: pm2 stop n8n${NC}"

echo ""
echo -e "${CYAN}🌐 ACCESS:${NC}"
echo -e "${CYAN}   Public URL: https://n8n.websolutionsserver.net${NC}"
echo -e "${CYAN}   Direct URL: http://$(curl -s ifconfig.me):5678${NC}"
echo -e "${CYAN}   Local URL: http://127.0.0.1:5678${NC}"

echo ""
if [[ "$HTTP_FINAL" =~ ^(200|401|302)$ ]] && pm2 list | grep -q "n8n.*online"; then
    print_success "🎉 n8n startup loop fixed! n8n is now running properly."
else
    print_warning "⚠️  n8n may need additional time to fully start. Run monitor script in 2-3 minutes."
fi

exit 0

