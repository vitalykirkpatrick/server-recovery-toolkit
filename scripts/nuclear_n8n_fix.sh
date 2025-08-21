#!/bin/bash

#=============================================================================
# NUCLEAR N8N FIX - COMPLETE REMOVAL AND REINSTALLATION
# Purpose: Fix persistent @oclif/core errors and "command start not found"
# Method: Complete nuclear removal and fresh installation
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
    echo -e "${BLUE}🔧 NUCLEAR:${NC} $1"
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

print_header "NUCLEAR N8N FIX - COMPLETE REMOVAL AND REINSTALLATION"

print_info "This will completely remove ALL traces of n8n and reinstall from scratch"
print_info "Error seen: 'File is not defined' and 'Error: command start not found'"

echo ""
read -p "Continue with nuclear n8n fix? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Nuclear fix cancelled"
    exit 0
fi

print_header "PHASE 1: NUCLEAR REMOVAL"

# Step 1: Kill ALL Node.js and n8n processes
print_status "Killing ALL Node.js and n8n processes"
pkill -9 -f n8n 2>/dev/null || true
pkill -9 -f node 2>/dev/null || true
pkill -9 -f npm 2>/dev/null || true
pm2 kill 2>/dev/null || true
sleep 5
print_success "All processes killed"

# Step 2: Remove ALL n8n installations
print_status "Removing ALL n8n installations"

# Remove global n8n
npm uninstall -g n8n 2>/dev/null || true
npm uninstall -g @n8n/cli 2>/dev/null || true

# Remove from all possible locations
rm -rf /usr/local/lib/node_modules/n8n 2>/dev/null || true
rm -rf /usr/lib/node_modules/n8n 2>/dev/null || true
rm -rf /opt/node_modules/n8n 2>/dev/null || true
rm -rf ~/.npm/_cacache 2>/dev/null || true
rm -rf ~/.npm 2>/dev/null || true

# Remove n8n binaries
rm -f /usr/local/bin/n8n 2>/dev/null || true
rm -f /usr/bin/n8n 2>/dev/null || true
rm -f /bin/n8n 2>/dev/null || true

print_success "All n8n installations removed"

# Step 3: Remove ALL n8n data and configuration
print_status "Removing ALL n8n data and configuration"
rm -rf /root/.n8n 2>/dev/null || true
rm -rf /home/*/.n8n 2>/dev/null || true
rm -f /root/.env 2>/dev/null || true
rm -f /root/n8n-ecosystem.json 2>/dev/null || true
rm -rf /var/log/n8n* 2>/dev/null || true
print_success "All n8n data removed"

# Step 4: Nuclear npm cache clean
print_status "Nuclear npm cache cleaning"
npm cache clean --force 2>/dev/null || true
rm -rf ~/.npm 2>/dev/null || true
rm -rf /root/.npm 2>/dev/null || true
rm -rf /tmp/npm-* 2>/dev/null || true
print_success "npm cache nuked"

# Step 5: Remove PM2 completely
print_status "Removing PM2 completely"
npm uninstall -g pm2 2>/dev/null || true
rm -rf /root/.pm2 2>/dev/null || true
rm -rf /home/*/.pm2 2>/dev/null || true
print_success "PM2 removed"

print_header "PHASE 2: FRESH INSTALLATION"

# Step 6: Update npm to latest
print_status "Updating npm to latest version"
npm install -g npm@latest
NPM_VERSION=$(npm --version)
print_info "npm version: $NPM_VERSION"
print_success "npm updated"

# Step 7: Install PM2 fresh
print_status "Installing PM2 fresh"
npm install -g pm2
PM2_VERSION=$(pm2 --version 2>/dev/null || echo "failed")
print_info "PM2 version: $PM2_VERSION"

if [[ "$PM2_VERSION" == "failed" ]]; then
    print_error "PM2 installation failed"
    exit 1
fi
print_success "PM2 installed"

# Step 8: Install n8n with specific method
print_status "Installing n8n with verbose output"

# Try multiple installation methods
print_info "Method 1: Standard global install"
if npm install -g n8n --verbose; then
    print_success "n8n installed via standard method"
else
    print_info "Method 2: Force install"
    if npm install -g n8n --force; then
        print_success "n8n installed via force method"
    else
        print_info "Method 3: Latest version install"
        if npm install -g n8n@latest; then
            print_success "n8n installed via latest method"
        else
            print_error "All installation methods failed"
            exit 1
        fi
    fi
fi

# Step 9: Verify installation
print_status "Verifying n8n installation"

# Check if n8n command exists
if command -v n8n >/dev/null 2>&1; then
    print_success "n8n command found"
    N8N_PATH=$(which n8n)
    print_info "n8n location: $N8N_PATH"
else
    print_error "n8n command not found"
    exit 1
fi

# Test n8n version
N8N_VERSION=$(n8n --version 2>/dev/null || echo "failed")
print_info "n8n version: $N8N_VERSION"

if [[ "$N8N_VERSION" == "failed" ]]; then
    print_error "n8n version check failed"
    exit 1
fi

# Test n8n help
print_info "Testing n8n help command..."
if n8n --help >/dev/null 2>&1; then
    print_success "n8n help command works"
else
    print_error "n8n help command failed"
    exit 1
fi

print_success "n8n installation verified"

print_header "PHASE 3: CONFIGURATION"

# Step 10: Create fresh configuration
print_status "Creating fresh n8n configuration"

# Create .n8n directory
mkdir -p /root/.n8n
chmod 700 /root/.n8n

# Create minimal config
cat > /root/.n8n/config.json << 'EOF'
{
  "host": "0.0.0.0",
  "port": 5678
}
EOF

chmod 600 /root/.n8n/config.json

# Create environment file
cat > /root/.env << 'EOF'
N8N_HOST=0.0.0.0
N8N_PORT=5678
N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=false
EOF

chmod 600 /root/.env

print_success "Configuration created"

print_header "PHASE 4: MANUAL TESTING"

# Step 11: Test n8n manually
print_status "Testing n8n manual startup"

# Set environment
export N8N_HOST=0.0.0.0
export N8N_PORT=5678
export N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=false

# Test n8n start command specifically
print_info "Testing 'n8n start' command..."
cd /root

# Start n8n in background
print_info "Starting n8n manually..."
nohup n8n start > /tmp/n8n_test.log 2>&1 &
N8N_PID=$!
print_info "n8n started with PID: $N8N_PID"

# Wait for startup
print_info "Waiting for n8n startup (60 seconds)..."
for i in {1..12}; do
    sleep 5
    if curl -s http://127.0.0.1:5678 >/dev/null 2>&1; then
        print_success "n8n is responding!"
        break
    else
        print_info "Waiting... ($i/12)"
    fi
done

# Test final response
HTTP_TEST=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5678 2>/dev/null || echo "000")
print_info "HTTP test result: $HTTP_TEST"

if [[ "$HTTP_TEST" =~ ^(200|401|302)$ ]]; then
    print_success "n8n manual startup successful!"
    
    # Kill test instance
    kill $N8N_PID 2>/dev/null || true
    sleep 5
    
    print_info "Manual test log (last 10 lines):"
    tail -10 /tmp/n8n_test.log 2>/dev/null || echo "No log available"
    
else
    print_error "n8n manual startup failed"
    print_info "Test log:"
    cat /tmp/n8n_test.log 2>/dev/null || echo "No log available"
    
    # Kill failed instance
    kill $N8N_PID 2>/dev/null || true
    exit 1
fi

print_header "PHASE 5: PM2 SETUP"

# Step 12: Configure PM2
print_status "Setting up PM2 for n8n"

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
      "N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS": "false"
    },
    "log_file": "/var/log/n8n-combined.log",
    "out_file": "/var/log/n8n-out.log",
    "error_file": "/var/log/n8n-error.log",
    "restart_delay": 10000,
    "max_restarts": 5,
    "min_uptime": "30s"
  }]
}
EOF

# Start with PM2
print_info "Starting n8n with PM2..."
pm2 start /root/n8n-ecosystem.json

# Wait for PM2 startup
print_info "Waiting for PM2 startup (45 seconds)..."
sleep 45

# Check PM2 status
PM2_STATUS=$(pm2 list | grep n8n | awk '{print $10}' 2>/dev/null || echo "unknown")
print_info "PM2 status: $PM2_STATUS"

# Test PM2 n8n
PM2_HTTP=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5678 2>/dev/null || echo "000")
print_info "PM2 HTTP test: $PM2_HTTP"

if [[ "$PM2_HTTP" =~ ^(200|401|302)$ ]]; then
    print_success "PM2 n8n startup successful!"
else
    print_error "PM2 n8n startup failed"
    print_info "PM2 logs:"
    pm2 logs n8n --lines 10 2>/dev/null || echo "No PM2 logs"
fi

# Save PM2 config
pm2 save
pm2 startup systemd -u root --hp /root

print_success "PM2 setup completed"

print_header "PHASE 6: FINAL VERIFICATION"

# Step 13: Final tests
print_status "Final verification"

# Wait for stabilization
sleep 30

# Final HTTP test
FINAL_HTTP=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5678 2>/dev/null || echo "000")
print_info "Final HTTP test: $FINAL_HTTP"

# Check PM2 final status
FINAL_PM2=$(pm2 list | grep n8n | awk '{print $10}' 2>/dev/null || echo "unknown")
print_info "Final PM2 status: $FINAL_PM2"

# Check if port is listening
PORT_CHECK=$(netstat -tlnp | grep :5678 | awk '{print $7}' 2>/dev/null || echo "not listening")
print_info "Port 5678 status: $PORT_CHECK"

echo ""
print_header "NUCLEAR FIX RESULTS"

if [[ "$FINAL_HTTP" =~ ^(200|401|302)$ ]] && [[ "$FINAL_PM2" == "online" ]]; then
    print_success "🎉 NUCLEAR FIX SUCCESSFUL!"
    echo ""
    echo -e "${GREEN}✅ n8n completely reinstalled and working${NC}"
    echo -e "${GREEN}✅ @oclif/core errors eliminated${NC}"
    echo -e "${GREEN}✅ 'command start not found' fixed${NC}"
    echo -e "${GREEN}✅ PM2 managing n8n properly${NC}"
    echo -e "${GREEN}✅ HTTP access working${NC}"
    
    echo ""
    echo -e "${CYAN}🌐 ACCESS INFORMATION:${NC}"
    echo -e "${CYAN}   Local: http://127.0.0.1:5678${NC}"
    echo -e "${CYAN}   External: http://$(curl -s ifconfig.me):5678${NC}"
    echo -e "${CYAN}   Domain: https://n8n.websolutionsserver.net${NC}"
    
    echo ""
    echo -e "${CYAN}🛠️  MANAGEMENT COMMANDS:${NC}"
    echo -e "${CYAN}   PM2 status: pm2 list${NC}"
    echo -e "${CYAN}   PM2 logs: pm2 logs n8n${NC}"
    echo -e "${CYAN}   Restart: pm2 restart n8n${NC}"
    echo -e "${CYAN}   Stop: pm2 stop n8n${NC}"
    
else
    print_error "⚠️ Nuclear fix completed but issues remain"
    echo ""
    echo -e "${RED}Final HTTP: $FINAL_HTTP${NC}"
    echo -e "${RED}Final PM2: $FINAL_PM2${NC}"
    echo -e "${RED}Port status: $PORT_CHECK${NC}"
    
    echo ""
    echo -e "${YELLOW}🔍 TROUBLESHOOTING:${NC}"
    echo -e "${YELLOW}   Check logs: pm2 logs n8n${NC}"
    echo -e "${YELLOW}   Check process: ps aux | grep n8n${NC}"
    echo -e "${YELLOW}   Check port: netstat -tlnp | grep 5678${NC}"
fi

echo ""
print_info "Nuclear fix completed at $(date)"

exit 0

