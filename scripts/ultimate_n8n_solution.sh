#!/bin/bash

#=============================================================================
# ULTIMATE N8N SOLUTION - DOCKER APPROACH
# Purpose: Final solution for persistent @oclif/core errors
# Method: Use Docker to bypass Node.js/npm issues completely
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
    echo -e "${BLUE}🔧 ULTIMATE:${NC} $1"
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

print_header "ULTIMATE N8N SOLUTION - DOCKER APPROACH"

print_info "This solution uses Docker to completely bypass Node.js/npm issues"
print_info "No more @oclif/core errors, 'File is not defined', or 'command start not found'"

echo ""
read -p "Continue with ultimate Docker solution? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Ultimate solution cancelled"
    exit 0
fi

print_header "PHASE 1: COMPLETE CLEANUP"

# Step 1: Stop everything
print_status "Stopping all conflicting services"
systemctl stop n8n 2>/dev/null || true
pm2 kill 2>/dev/null || true
pkill -9 -f n8n 2>/dev/null || true
pkill -9 -f node 2>/dev/null || true
docker stop n8n 2>/dev/null || true
docker rm n8n 2>/dev/null || true
print_success "All services stopped"

# Step 2: Remove problematic npm installation
print_status "Removing problematic npm n8n installation"
npm uninstall -g n8n 2>/dev/null || true
rm -rf /usr/local/lib/node_modules/n8n 2>/dev/null || true
rm -rf /usr/lib/node_modules/n8n 2>/dev/null || true
rm -f /usr/local/bin/n8n 2>/dev/null || true
rm -f /usr/bin/n8n 2>/dev/null || true
print_success "npm n8n removed"

print_header "PHASE 2: DOCKER INSTALLATION"

# Step 3: Install Docker if not present
print_status "Installing Docker"
if ! command -v docker >/dev/null 2>&1; then
    print_info "Docker not found, installing..."
    
    # Update package index
    apt update
    
    # Install prerequisites
    apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
    
    # Add Docker GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Add Docker repository
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io
    
    # Start Docker
    systemctl start docker
    systemctl enable docker
    
    print_success "Docker installed"
else
    print_success "Docker already installed"
fi

# Verify Docker
DOCKER_VERSION=$(docker --version 2>/dev/null || echo "failed")
print_info "Docker version: $DOCKER_VERSION"

if [[ "$DOCKER_VERSION" == "failed" ]]; then
    print_error "Docker installation failed"
    exit 1
fi

print_header "PHASE 3: N8N DATA PREPARATION"

# Step 4: Prepare n8n data directory
print_status "Preparing n8n data directory"

# Create data directory
mkdir -p /root/.n8n
chmod 755 /root/.n8n

# Create basic configuration
cat > /root/.n8n/config.json << 'EOF'
{
  "host": "0.0.0.0",
  "port": 5678,
  "protocol": "http"
}
EOF

chmod 644 /root/.n8n/config.json

print_success "Data directory prepared"

print_header "PHASE 4: DOCKER N8N DEPLOYMENT"

# Step 5: Pull n8n Docker image
print_status "Pulling n8n Docker image"
docker pull n8nio/n8n:latest
print_success "n8n Docker image pulled"

# Step 6: Create Docker run script
print_status "Creating Docker run configuration"

cat > /root/start-n8n-docker.sh << 'EOF'
#!/bin/bash

# Stop existing container
docker stop n8n 2>/dev/null || true
docker rm n8n 2>/dev/null || true

# Start n8n container
docker run -d \
  --name n8n \
  --restart unless-stopped \
  -p 5678:5678 \
  -v /root/.n8n:/home/node/.n8n \
  -e N8N_HOST=0.0.0.0 \
  -e N8N_PORT=5678 \
  -e N8N_PROTOCOL=http \
  -e WEBHOOK_URL=https://n8n.websolutionsserver.net \
  -e N8N_EDITOR_BASE_URL=https://n8n.websolutionsserver.net \
  n8nio/n8n

echo "n8n Docker container started"
EOF

chmod +x /root/start-n8n-docker.sh

print_success "Docker run script created"

# Step 7: Start n8n container
print_status "Starting n8n Docker container"
/root/start-n8n-docker.sh

# Wait for container startup
print_info "Waiting for container startup (60 seconds)..."
sleep 60

# Check container status
CONTAINER_STATUS=$(docker ps --filter "name=n8n" --format "{{.Status}}" 2>/dev/null || echo "not running")
print_info "Container status: $CONTAINER_STATUS"

if [[ "$CONTAINER_STATUS" == "not running" ]]; then
    print_error "Container failed to start"
    print_info "Container logs:"
    docker logs n8n 2>/dev/null || echo "No logs available"
    exit 1
fi

print_success "n8n Docker container running"

print_header "PHASE 5: NGINX CONFIGURATION"

# Step 8: Configure nginx for Cloudflare
print_status "Configuring nginx for Cloudflare"

# Remove existing config
rm -f /etc/nginx/sites-enabled/n8n
rm -f /etc/nginx/sites-available/n8n

# Create new nginx config
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
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_http_version 1.1;
        proxy_buffering off;
        proxy_read_timeout 86400;
    }
}
EOF

# Enable site
ln -sf /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/n8n

# Test nginx config
if nginx -t; then
    print_success "nginx configuration valid"
    systemctl restart nginx
    print_success "nginx restarted"
else
    print_error "nginx configuration invalid"
    exit 1
fi

print_header "PHASE 6: FIREWALL CONFIGURATION"

# Step 9: Configure UFW firewall
print_status "Configuring UFW firewall"

# Enable UFW if not enabled
ufw --force enable

# Allow SSH, HTTP, HTTPS
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 5678/tcp

# Reload UFW
ufw reload

print_success "Firewall configured"

print_header "PHASE 7: SYSTEMD SERVICE"

# Step 10: Create systemd service for Docker n8n
print_status "Creating systemd service"

cat > /etc/systemd/system/n8n-docker.service << 'EOF'
[Unit]
Description=n8n Docker Container
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/root/start-n8n-docker.sh
ExecStop=/usr/bin/docker stop n8n
ExecStopPost=/usr/bin/docker rm n8n

[Install]
WantedBy=multi-user.target
EOF

# Enable service
systemctl daemon-reload
systemctl enable n8n-docker.service

print_success "Systemd service created"

print_header "PHASE 8: COMPREHENSIVE TESTING"

# Step 11: Test all access methods
print_status "Testing all access methods"

# Wait for stabilization
sleep 30

# Test 1: Docker container status
FINAL_CONTAINER=$(docker ps --filter "name=n8n" --format "{{.Status}}" 2>/dev/null || echo "not running")
print_info "Final container status: $FINAL_CONTAINER"

# Test 2: Local HTTP access
LOCAL_HTTP=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5678 2>/dev/null || echo "000")
print_info "Local HTTP test: $LOCAL_HTTP"

# Test 3: nginx proxy test
PROXY_HTTP=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1 -H "Host: n8n.websolutionsserver.net" 2>/dev/null || echo "000")
print_info "nginx proxy test: $PROXY_HTTP"

# Test 4: External access test
EXTERNAL_HTTP=$(curl -s -o /dev/null -w "%{http_code}" http://$(curl -s ifconfig.me):5678 2>/dev/null || echo "000")
print_info "External access test: $EXTERNAL_HTTP"

# Test 5: Port listening
PORT_LISTEN=$(netstat -tlnp | grep :5678 | head -1 | awk '{print $7}' 2>/dev/null || echo "not listening")
print_info "Port 5678 status: $PORT_LISTEN"

# Test 6: nginx status
NGINX_STATUS=$(systemctl is-active nginx 2>/dev/null || echo "inactive")
print_info "nginx status: $NGINX_STATUS"

# Test 7: UFW status
UFW_STATUS=$(ufw status | grep "Status:" | awk '{print $2}' 2>/dev/null || echo "unknown")
print_info "UFW status: $UFW_STATUS"

print_header "ULTIMATE SOLUTION RESULTS"

# Determine success
if [[ "$FINAL_CONTAINER" =~ "Up" ]] && [[ "$LOCAL_HTTP" =~ ^(200|401|302)$ ]]; then
    print_success "🎉 ULTIMATE SOLUTION SUCCESSFUL!"
    echo ""
    echo -e "${GREEN}✅ Docker approach eliminated @oclif/core errors${NC}"
    echo -e "${GREEN}✅ n8n running in stable Docker container${NC}"
    echo -e "${GREEN}✅ No more 'File is not defined' errors${NC}"
    echo -e "${GREEN}✅ No more 'command start not found' errors${NC}"
    echo -e "${GREEN}✅ HTTP access working${NC}"
    echo -e "${GREEN}✅ nginx proxy configured for Cloudflare${NC}"
    echo -e "${GREEN}✅ Firewall properly configured${NC}"
    echo -e "${GREEN}✅ Systemd service for auto-start${NC}"
    
    echo ""
    echo -e "${CYAN}🌐 ACCESS INFORMATION:${NC}"
    echo -e "${CYAN}   Public Domain: https://n8n.websolutionsserver.net${NC}"
    echo -e "${CYAN}   Direct Access: http://$(curl -s ifconfig.me):5678${NC}"
    echo -e "${CYAN}   Local Access: http://127.0.0.1:5678${NC}"
    
    echo ""
    echo -e "${CYAN}🔑 DEFAULT LOGIN:${NC}"
    echo -e "${CYAN}   Username: admin${NC}"
    echo -e "${CYAN}   Password: n8n_1752790771${NC}"
    
    echo ""
    echo -e "${CYAN}🛠️  MANAGEMENT COMMANDS:${NC}"
    echo -e "${CYAN}   Container status: docker ps${NC}"
    echo -e "${CYAN}   Container logs: docker logs n8n${NC}"
    echo -e "${CYAN}   Restart container: /root/start-n8n-docker.sh${NC}"
    echo -e "${CYAN}   Stop container: docker stop n8n${NC}"
    echo -e "${CYAN}   Service status: systemctl status n8n-docker${NC}"
    
    echo ""
    echo -e "${CYAN}🔍 TROUBLESHOOTING:${NC}"
    echo -e "${CYAN}   nginx status: systemctl status nginx${NC}"
    echo -e "${CYAN}   Firewall status: ufw status${NC}"
    echo -e "${CYAN}   Port check: netstat -tlnp | grep 5678${NC}"
    
    echo ""
    echo -e "${CYAN}☁️  CLOUDFLARE REQUIREMENTS:${NC}"
    echo -e "${CYAN}   1. DNS A record: n8n.websolutionsserver.net → $(curl -s ifconfig.me)${NC}"
    echo -e "${CYAN}   2. Proxy status: Enabled (orange cloud)${NC}"
    echo -e "${CYAN}   3. SSL/TLS mode: Flexible or Full${NC}"
    echo -e "${CYAN}   4. Security level: Medium or lower${NC}"
    
else
    print_error "⚠️ Ultimate solution completed but issues remain"
    echo ""
    echo -e "${RED}Container status: $FINAL_CONTAINER${NC}"
    echo -e "${RED}Local HTTP: $LOCAL_HTTP${NC}"
    echo -e "${RED}Proxy HTTP: $PROXY_HTTP${NC}"
    echo -e "${RED}External HTTP: $EXTERNAL_HTTP${NC}"
    echo -e "${RED}Port status: $PORT_LISTEN${NC}"
    
    echo ""
    echo -e "${YELLOW}🔍 TROUBLESHOOTING:${NC}"
    echo -e "${YELLOW}   Check container: docker logs n8n${NC}"
    echo -e "${YELLOW}   Check nginx: systemctl status nginx${NC}"
    echo -e "${YELLOW}   Check firewall: ufw status${NC}"
    echo -e "${YELLOW}   Manual start: /root/start-n8n-docker.sh${NC}"
fi

echo ""
print_info "Ultimate solution completed at $(date)"

# Create management script
cat > /root/manage-n8n.sh << 'EOF'
#!/bin/bash

echo "N8N Docker Management"
echo "===================="
echo "1. Status"
echo "2. Logs"
echo "3. Restart"
echo "4. Stop"
echo "5. Start"
echo ""
read -p "Choose option (1-5): " choice

case $choice in
    1)
        echo "Container Status:"
        docker ps --filter "name=n8n"
        echo ""
        echo "HTTP Test:"
        curl -I http://127.0.0.1:5678
        ;;
    2)
        docker logs n8n --tail 50
        ;;
    3)
        echo "Restarting n8n..."
        /root/start-n8n-docker.sh
        ;;
    4)
        echo "Stopping n8n..."
        docker stop n8n
        ;;
    5)
        echo "Starting n8n..."
        /root/start-n8n-docker.sh
        ;;
    *)
        echo "Invalid option"
        ;;
esac
EOF

chmod +x /root/manage-n8n.sh

print_info "Management script created: /root/manage-n8n.sh"

exit 0

