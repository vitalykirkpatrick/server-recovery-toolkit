#!/bin/bash

#=============================================================================
# ENHANCED AUTOMATION SETUP WITH N8N WORKFLOW BACKUP
# Purpose: Add n8n workflow backup to existing automation setup
# Features: Complete n8n backup, workflow preservation, automated scheduling
#=============================================================================

# Configuration
INSTALL_DIR="/opt/audiobooksmith"
SCRIPTS_DIR="/root/scripts"
GITHUB_REPO="https://raw.githubusercontent.com/vitalykirkpatrick/server-recovery-toolkit/main/scripts"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}🔧 STEP:${NC} $1"
}

print_success() {
    echo -e "${GREEN}✅ SUCCESS:${NC} $1"
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

echo -e "${PURPLE}=============================================================================${NC}"
echo -e "${PURPLE}  ENHANCED AUTOMATION SETUP WITH N8N WORKFLOW BACKUP${NC}"
echo -e "${PURPLE}  Setup Date: $(date)${NC}"
echo -e "${PURPLE}=============================================================================${NC}"

print_info "Adding n8n workflow backup to automation setup"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root (use sudo)"
    exit 1
fi

# Create directories if they don't exist
print_status "Creating directories..."
mkdir -p "$SCRIPTS_DIR"
mkdir -p "$INSTALL_DIR"
mkdir -p "/root/n8n_backups"

print_success "Directories created"

# Install n8n complete backup script
print_status "Installing n8n complete backup script..."

cat > "$SCRIPTS_DIR/n8n_complete_backup.sh" << 'EOF'
#!/bin/bash

#=============================================================================
# N8N COMPLETE BACKUP SCRIPT
# Purpose: Backup all n8n workflows, configurations, credentials, and user data
# Features: Database backup, workflow export, configuration backup, GitHub upload
#=============================================================================

# Configuration
BACKUP_DIR="/root/n8n_backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="n8n_complete_backup_$TIMESTAMP"
LOG_FILE="/var/log/n8n_backup.log"
N8N_DIR="/root/.n8n"
GITHUB_REPO="vitalykirkpatrick/server-recovery-toolkit"

# GitHub token from environment or config file
if [ -f "/root/.github_token" ]; then
    GITHUB_TOKEN=$(cat /root/.github_token)
elif [ -n "$GITHUB_TOKEN" ]; then
    # Use environment variable
    GITHUB_TOKEN="$GITHUB_TOKEN"
else
    GITHUB_TOKEN=""
fi

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging function
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

log_success() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - SUCCESS: $1" >> "$LOG_FILE"
    echo -e "${GREEN}✅ SUCCESS:${NC} $1"
}

log_warning() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - WARNING: $1" >> "$LOG_FILE"
    echo -e "${YELLOW}⚠️  WARNING:${NC} $1"
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: $1" >> "$LOG_FILE"
    echo -e "${RED}❌ ERROR:${NC} $1"
}

# Function to check if n8n is running
check_n8n_status() {
    if pm2 list | grep -q "n8n.*online"; then
        return 0
    else
        return 1
    fi
}

# Function to export workflows via n8n CLI
export_workflows() {
    local export_dir="$1"
    
    log_message "Exporting n8n workflows..."
    
    # Create workflows export directory
    mkdir -p "$export_dir/workflows"
    mkdir -p "$export_dir/credentials"
    
    # Export all workflows
    if command -v n8n >/dev/null 2>&1; then
        cd /root
        
        # Export workflows to JSON
        n8n export:workflow --all --output="$export_dir/workflows/" 2>/dev/null || {
            log_warning "n8n CLI export failed, using database backup instead"
            return 1
        }
        
        # Export credentials (encrypted)
        n8n export:credentials --all --output="$export_dir/credentials/" 2>/dev/null || {
            log_warning "Credentials export failed"
        }
        
        log_success "Workflows exported via n8n CLI"
        return 0
    else
        log_warning "n8n CLI not available"
        return 1
    fi
}

# Function to backup n8n database
backup_database() {
    local backup_dir="$1"
    
    log_message "Backing up n8n database..."
    
    if [ -f "$N8N_DIR/database.sqlite" ]; then
        # Stop n8n temporarily for consistent backup
        local n8n_was_running=false
        if check_n8n_status; then
            n8n_was_running=true
            log_message "Stopping n8n for database backup..."
            pm2 stop n8n >/dev/null 2>&1
            sleep 2
        fi
        
        # Copy database
        cp "$N8N_DIR/database.sqlite" "$backup_dir/database.sqlite"
        
        # Create database dump for readability
        if command -v sqlite3 >/dev/null 2>&1; then
            sqlite3 "$N8N_DIR/database.sqlite" .dump > "$backup_dir/database_dump.sql"
            log_success "Database dump created"
        fi
        
        # Restart n8n if it was running
        if [ "$n8n_was_running" = true ]; then
            log_message "Restarting n8n..."
            pm2 start n8n >/dev/null 2>&1
            sleep 3
        fi
        
        log_success "Database backup completed"
        return 0
    else
        log_error "n8n database not found at $N8N_DIR/database.sqlite"
        return 1
    fi
}

# Function to backup configuration files
backup_configurations() {
    local backup_dir="$1"
    
    log_message "Backing up n8n configurations..."
    
    # Create config backup directory
    mkdir -p "$backup_dir/config"
    
    # Backup n8n directory structure
    if [ -d "$N8N_DIR" ]; then
        # Copy entire .n8n directory
        cp -r "$N8N_DIR" "$backup_dir/n8n_directory"
        
        # Copy specific config files
        [ -f "$N8N_DIR/config.json" ] && cp "$N8N_DIR/config.json" "$backup_dir/config/"
        [ -f "$N8N_DIR/config" ] && cp "$N8N_DIR/config" "$backup_dir/config/"
        
        log_success "n8n directory backed up"
    else
        log_error "n8n directory not found at $N8N_DIR"
        return 1
    fi
    
    # Backup environment file
    if [ -f "/root/.env" ]; then
        cp "/root/.env" "$backup_dir/config/n8n.env"
        log_success "Environment file backed up"
    fi
    
    # Backup PM2 ecosystem file
    if [ -f "/root/n8n-ecosystem.json" ]; then
        cp "/root/n8n-ecosystem.json" "$backup_dir/config/"
        log_success "PM2 ecosystem file backed up"
    fi
    
    # Backup nginx configuration
    if [ -f "/etc/nginx/sites-available/n8n" ]; then
        cp "/etc/nginx/sites-available/n8n" "$backup_dir/config/nginx_n8n.conf"
        log_success "nginx configuration backed up"
    fi
    
    return 0
}

# Function to create backup manifest
create_backup_manifest() {
    local backup_dir="$1"
    local manifest_file="$backup_dir/BACKUP_MANIFEST.txt"
    
    log_message "Creating backup manifest..."
    
    cat > "$manifest_file" << MANIFEST_EOF
N8N COMPLETE BACKUP MANIFEST
============================
Backup Date: $(date)
Backup Name: $BACKUP_NAME
Server: $(hostname)
n8n Version: $(n8n --version 2>/dev/null || echo "Unknown")
Node.js Version: $(node --version 2>/dev/null || echo "Unknown")

BACKUP CONTENTS:
===============

📁 Database:
- database.sqlite: Complete n8n database
- database_dump.sql: Human-readable database dump

📁 Workflows:
- workflows/: Exported workflow JSON files
- credentials/: Exported credentials (encrypted)

📁 Configuration:
- n8n_directory/: Complete .n8n directory copy
- config/: Individual configuration files
  - config.json: n8n configuration
  - n8n.env: Environment variables
  - n8n-ecosystem.json: PM2 configuration
  - nginx_n8n.conf: nginx configuration

📁 System Info:
- system_info.txt: System information at backup time

RESTORATION INSTRUCTIONS:
========================

1. Install fresh n8n server using setup script
2. Stop n8n: pm2 stop n8n
3. Restore database: cp database.sqlite /root/.n8n/
4. Restore config: cp config/* to appropriate locations
5. Set permissions: chown -R root:root /root/.n8n
6. Start n8n: pm2 start n8n

BACKUP STATISTICS:
=================
Total Files: $(find "$backup_dir" -type f | wc -l)
Total Size: $(du -sh "$backup_dir" | cut -f1)
Workflows Count: $(find "$backup_dir/workflows" -name "*.json" 2>/dev/null | wc -l)
Database Size: $(du -sh "$backup_dir/database.sqlite" 2>/dev/null | cut -f1 || echo "N/A")

MANIFEST_EOF

    # Add system information
    cat >> "$manifest_file" << MANIFEST_EOF

SYSTEM INFORMATION:
==================
$(uname -a)
$(free -h)
$(df -h /)
$(pm2 list 2>/dev/null || echo "PM2 not available")

MANIFEST_EOF

    log_success "Backup manifest created"
}

# Function to upload to GitHub
upload_to_github() {
    local backup_file="$1"
    
    if [ -z "$GITHUB_TOKEN" ]; then
        log_warning "GitHub token not configured, skipping upload"
        log_warning "To enable GitHub upload, set GITHUB_TOKEN environment variable or create /root/.github_token file"
        return 1
    fi
    
    log_message "Uploading backup to GitHub..."
    
    # Create a simple upload script
    cat > /tmp/github_upload.py << 'PYEOF'
import requests
import base64
import json
import sys
import os

def upload_to_github(file_path, github_path, token, repo):
    with open(file_path, 'rb') as f:
        content = f.read()
    
    encoded_content = base64.b64encode(content).decode('utf-8')
    
    url = f"https://api.github.com/repos/{repo}/contents/{github_path}"
    headers = {
        "Authorization": f"token {token}",
        "Accept": "application/vnd.github.v3+json"
    }
    
    # Check if file exists
    response = requests.get(url, headers=headers)
    sha = None
    if response.status_code == 200:
        sha = response.json()["sha"]
    
    data = {
        "message": f"n8n backup {os.path.basename(file_path)}",
        "content": encoded_content,
        "branch": "main"
    }
    
    if sha:
        data["sha"] = sha
    
    response = requests.put(url, headers=headers, data=json.dumps(data))
    return response.status_code in [200, 201]

if __name__ == "__main__":
    file_path = sys.argv[1]
    github_path = sys.argv[2]
    token = sys.argv[3]
    repo = sys.argv[4]
    
    if upload_to_github(file_path, github_path, token, repo):
        print("Upload successful")
        sys.exit(0)
    else:
        print("Upload failed")
        sys.exit(1)
PYEOF

    # Try to upload
    if python3 /tmp/github_upload.py "$backup_file" "backups/n8n/$(basename "$backup_file")" "$GITHUB_TOKEN" "$GITHUB_REPO" 2>/dev/null; then
        log_success "Backup uploaded to GitHub"
        rm -f /tmp/github_upload.py
        return 0
    else
        log_warning "GitHub upload failed"
        rm -f /tmp/github_upload.py
        return 1
    fi
}

# Main backup function
main() {
    echo "💾 N8N COMPLETE BACKUP SCRIPT"
    echo "============================="
    echo "Backup Name: $BACKUP_NAME"
    echo "Timestamp: $(date)"
    echo ""
    
    log_message "Starting n8n complete backup"
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    local current_backup_dir="$BACKUP_DIR/$BACKUP_NAME"
    mkdir -p "$current_backup_dir"
    
    # Check if n8n directory exists
    if [ ! -d "$N8N_DIR" ]; then
        log_error "n8n directory not found at $N8N_DIR"
        exit 1
    fi
    
    # Perform backups
    local backup_success=true
    
    # Backup database
    if ! backup_database "$current_backup_dir"; then
        backup_success=false
    fi
    
    # Export workflows
    export_workflows "$current_backup_dir" || log_warning "Workflow export had issues"
    
    # Backup configurations
    if ! backup_configurations "$current_backup_dir"; then
        backup_success=false
    fi
    
    # Create manifest
    create_backup_manifest "$current_backup_dir"
    
    # Create compressed archive
    log_message "Creating compressed backup archive..."
    cd "$BACKUP_DIR"
    tar -czf "${BACKUP_NAME}.tar.gz" "$BACKUP_NAME"
    
    if [ $? -eq 0 ]; then
        log_success "Backup archive created: ${BACKUP_NAME}.tar.gz"
        
        # Remove uncompressed directory
        rm -rf "$current_backup_dir"
        
        # Upload to GitHub
        upload_to_github "$BACKUP_DIR/${BACKUP_NAME}.tar.gz"
        
    else
        log_error "Failed to create backup archive"
        backup_success=false
    fi
    
    # Cleanup old backups (keep last 10)
    log_message "Cleaning up old backups..."
    cd "$BACKUP_DIR"
    ls -t n8n_complete_backup_*.tar.gz | tail -n +11 | xargs -r rm
    log_success "Old backups cleaned up"
    
    # Final status
    if [ "$backup_success" = true ]; then
        log_success "n8n complete backup completed successfully"
        echo ""
        echo "✅ Backup Location: $BACKUP_DIR/${BACKUP_NAME}.tar.gz"
        echo "📋 Manifest: Check BACKUP_MANIFEST.txt in archive"
        echo "📊 Size: $(du -sh "$BACKUP_DIR/${BACKUP_NAME}.tar.gz" | cut -f1)"
        
        # Show GitHub token setup info if not configured
        if [ -z "$GITHUB_TOKEN" ]; then
            echo ""
            echo "ℹ️  To enable GitHub backup upload:"
            echo "   echo 'your_github_token' > /root/.github_token"
            echo "   or export GITHUB_TOKEN='your_github_token'"
        fi
        
        exit 0
    else
        log_error "n8n backup completed with errors"
        exit 1
    fi
}

# Run main function
main "$@"
EOF

chmod +x "$SCRIPTS_DIR/n8n_complete_backup.sh"
print_success "n8n complete backup script installed"

# Install n8n restoration script
print_status "Installing n8n restoration script..."

# Download from GitHub or create basic version
if ! download_script "n8n_restore_script.sh" "$SCRIPTS_DIR/n8n_restore.sh"; then
    cat > "$SCRIPTS_DIR/n8n_restore.sh" << 'EOF'
#!/bin/bash
echo "🔄 N8N RESTORATION SCRIPT"
echo "========================"
echo "This script helps restore n8n backups."
echo "Usage: $0 [backup_file.tar.gz]"
echo ""
echo "For detailed restoration, download the complete restoration script from GitHub."
EOF
fi

chmod +x "$SCRIPTS_DIR/n8n_restore.sh"
print_success "n8n restoration script installed"

# Update automation management script
print_status "Updating automation management script..."

cat > "$INSTALL_DIR/manage_automation.sh" << 'EOF'
#!/bin/bash
# Enhanced Automation Management Script with n8n Workflow Backup

case "$1" in
    "backup-minimal")
        echo "💾 Running minimal backup..."
        /root/scripts/backup_server_minimal.sh
        ;;
    "backup-comprehensive")
        echo "💾 Running comprehensive backup..."
        /root/scripts/comprehensive_backup.sh
        ;;
    "backup-n8n")
        echo "💾 Running n8n complete backup..."
        /root/scripts/n8n_complete_backup.sh
        ;;
    "restore-n8n")
        echo "🔄 Running n8n restoration..."
        /root/scripts/n8n_restore.sh "$2"
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
        echo "Recent n8n backup logs:"
        tail -10 /var/log/n8n_backup.log 2>/dev/null
        echo ""
        echo "Recent cleanup logs:"
        tail -10 /var/log/cleanup_cron.log 2>/dev/null
        echo ""
        echo "Recent health check logs:"
        tail -10 /var/log/health_check_cron.log 2>/dev/null
        ;;
    "list-n8n-backups")
        echo "📋 Available n8n Backups:"
        echo "========================="
        if [ -d "/root/n8n_backups" ]; then
            ls -lah /root/n8n_backups/n8n_complete_backup_*.tar.gz 2>/dev/null | tail -10
        else
            echo "No n8n backups found"
        fi
        ;;
    "setup-github-token")
        echo "🔑 GitHub Token Setup:"
        echo "====================="
        echo "To enable GitHub backup upload, you need to set up a GitHub token."
        echo ""
        read -p "Enter your GitHub token: " -s token
        echo ""
        if [ -n "$token" ]; then
            echo "$token" > /root/.github_token
            chmod 600 /root/.github_token
            echo "✅ GitHub token saved to /root/.github_token"
        else
            echo "❌ No token provided"
        fi
        ;;
    *)
        echo "Enhanced Automation Management Script"
        echo "Usage: $0 {backup-minimal|backup-comprehensive|backup-n8n|restore-n8n|cleanup|health-check|cron-status|logs|list-n8n-backups|setup-github-token}"
        echo ""
        echo "Commands:"
        echo "  backup-minimal       - Run minimal backup now"
        echo "  backup-comprehensive - Run comprehensive backup now"
        echo "  backup-n8n          - Run n8n complete backup now"
        echo "  restore-n8n [file]  - Restore n8n from backup"
        echo "  cleanup              - Run system cleanup now"
        echo "  health-check         - Run health check now"
        echo "  cron-status          - Show scheduled cron jobs"
        echo "  logs                 - Show automation logs"
        echo "  list-n8n-backups    - List available n8n backups"
        echo "  setup-github-token   - Configure GitHub token for backup upload"
        echo ""
        echo "Examples:"
        echo "  $0 backup-n8n"
        echo "  $0 restore-n8n /root/n8n_backups/n8n_complete_backup_20250821_120000.tar.gz"
        echo "  $0 list-n8n-backups"
        echo "  $0 setup-github-token"
        ;;
esac
EOF

chmod +x "$INSTALL_DIR/manage_automation.sh"
print_success "Automation management script updated"

# Update cron jobs to include n8n backup
print_status "Updating cron jobs to include n8n workflow backup..."

# Get current crontab
crontab -l > /tmp/current_cron 2>/dev/null || touch /tmp/current_cron

# Remove existing n8n backup entries
grep -v "n8n_complete_backup" /tmp/current_cron > /tmp/new_cron

# Add n8n backup cron job
cat >> /tmp/new_cron << 'EOF'

# n8n Complete Backup (workflows, configs, database) - Daily at 1:30 AM
30 1 * * * /root/scripts/n8n_complete_backup.sh >> /var/log/n8n_backup_cron.log 2>&1
EOF

# Install new crontab
crontab /tmp/new_cron
rm -f /tmp/current_cron /tmp/new_cron

print_success "Cron jobs updated with n8n workflow backup"

# Update log rotation configuration
print_status "Updating log rotation for n8n backup logs..."

cat >> /etc/logrotate.d/n8n-automation << 'EOF'

/var/log/n8n_backup*.log {
    weekly
    rotate 12
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
}
EOF

print_success "Log rotation updated"

# Update system status script
print_status "Updating system status script..."

cat > "$INSTALL_DIR/system_status.sh" << 'EOF'
#!/bin/bash
# Enhanced System Status Script with n8n Backup Info

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

if [ -f /var/log/n8n_backup_cron.log ]; then
    echo -n "Last n8n backup: "
    tail -1 /var/log/n8n_backup_cron.log 2>/dev/null | head -c 50
    echo "..."
fi

echo ""
echo "📁 BACKUP FILES:"
echo "System Backups:"
if [ -d /root/backups ]; then
    ls -lah /root/backups/ | tail -3
fi

echo ""
echo "n8n Backups:"
if [ -d /root/n8n_backups ]; then
    ls -lah /root/n8n_backups/ | tail -5
else
    echo "No n8n backups directory found"
fi

echo ""
echo "💾 n8n DATA STATUS"
echo "=================="
if [ -f /root/.n8n/database.sqlite ]; then
    echo "Database: $(du -sh /root/.n8n/database.sqlite | cut -f1)"
    echo "Workflows: $(sqlite3 /root/.n8n/database.sqlite "SELECT COUNT(*) FROM workflow_entity;" 2>/dev/null || echo "Unknown")"
    echo "Credentials: $(sqlite3 /root/.n8n/database.sqlite "SELECT COUNT(*) FROM credentials_entity;" 2>/dev/null || echo "Unknown")"
else
    echo "❌ n8n database not found"
fi

echo ""
echo "🔑 GITHUB BACKUP STATUS"
echo "======================="
if [ -f /root/.github_token ]; then
    echo "✅ GitHub token configured"
else
    echo "❌ GitHub token not configured"
    echo "   Run: /opt/audiobooksmith/manage_automation.sh setup-github-token"
fi
EOF

chmod +x "$INSTALL_DIR/system_status.sh"
print_success "System status script updated"

# Update test script
print_status "Updating comprehensive test script..."

cat > "$INSTALL_DIR/test_all_systems.sh" << 'EOF'
#!/bin/bash
# Enhanced Comprehensive System Test Script with n8n Backup Testing

echo "🧪 COMPREHENSIVE SYSTEM TESTING WITH N8N BACKUP"
echo "================================================"

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
run_test "SQLite3" "sqlite3 --version"

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
run_test "n8n Backup Script" "test -x /root/scripts/n8n_complete_backup.sh"
run_test "n8n Restore Script" "test -x /root/scripts/n8n_restore.sh"
run_test "Cron Jobs" "crontab -l | grep -q backup"

echo ""
echo "💾 Testing n8n Data:"
echo "--------------------"
run_test "n8n Directory" "test -d /root/.n8n"
run_test "n8n Database" "test -f /root/.n8n/database.sqlite"
run_test "n8n Config" "test -f /root/.n8n/config.json || test -f /root/.n8n/config"
run_test "Environment File" "test -f /root/.env"
run_test "PM2 Ecosystem" "test -f /root/n8n-ecosystem.json"
run_test "Backup Directory" "test -d /root/n8n_backups"

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
print_success "Comprehensive test script updated"

# Run initial n8n backup if n8n is available
print_status "Running initial n8n backup..."
if [ -d "/root/.n8n" ] && pm2 list | grep -q "n8n"; then
    /root/scripts/n8n_complete_backup.sh >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        print_success "Initial n8n backup completed"
    else
        print_warning "Initial n8n backup had issues"
    fi
else
    print_warning "n8n not available for initial backup"
fi

# Display final summary
echo ""
echo -e "${PURPLE}=============================================================================${NC}"
echo -e "${PURPLE}  ENHANCED AUTOMATION SETUP WITH N8N WORKFLOW BACKUP COMPLETED!${NC}"
echo -e "${PURPLE}=============================================================================${NC}"
echo ""

print_success "Enhanced automation setup completed successfully!"

echo ""
echo -e "${CYAN}🤖 NEW AUTOMATION FEATURES:${NC}"
echo -e "${CYAN}   📅 Daily n8n backup at 1:30 AM${NC}"
echo -e "${CYAN}   💾 Complete workflow preservation${NC}"
echo -e "${CYAN}   🔄 Easy restoration capabilities${NC}"
echo -e "${CYAN}   📊 Enhanced monitoring and status${NC}"
echo ""
echo -e "${CYAN}🛠️  ENHANCED MANAGEMENT COMMANDS:${NC}"
echo -e "${CYAN}   n8n Backup: $INSTALL_DIR/manage_automation.sh backup-n8n${NC}"
echo -e "${CYAN}   n8n Restore: $INSTALL_DIR/manage_automation.sh restore-n8n [file]${NC}"
echo -e "${CYAN}   List Backups: $INSTALL_DIR/manage_automation.sh list-n8n-backups${NC}"
echo -e "${CYAN}   Setup GitHub: $INSTALL_DIR/manage_automation.sh setup-github-token${NC}"
echo -e "${CYAN}   Status: $INSTALL_DIR/system_status.sh${NC}"
echo -e "${CYAN}   Test: $INSTALL_DIR/test_all_systems.sh${NC}"
echo ""
echo -e "${CYAN}📁 BACKUP LOCATIONS:${NC}"
echo -e "${CYAN}   System Backups: /root/backups/${NC}"
echo -e "${CYAN}   n8n Backups: /root/n8n_backups/${NC}"
echo -e "${CYAN}   Scripts: /root/scripts/${NC}"
echo ""
echo -e "${CYAN}⏰ AUTOMATED SCHEDULE:${NC}"
echo -e "${CYAN}   01:30 AM - n8n complete backup (workflows, configs, database)${NC}"
echo -e "${CYAN}   02:30 AM - System minimal backup${NC}"
echo -e "${CYAN}   03:00 AM - Comprehensive backup (Sundays)${NC}"
echo -e "${CYAN}   04:00 AM - System cleanup (Sundays)${NC}"
echo -e "${CYAN}   06:00 AM & 18:00 PM - Health checks${NC}"
echo ""
echo -e "${CYAN}🔑 GITHUB SETUP:${NC}"
echo -e "${CYAN}   To enable GitHub backup upload:${NC}"
echo -e "${CYAN}   $INSTALL_DIR/manage_automation.sh setup-github-token${NC}"
echo ""
echo -e "${GREEN}✅ Your n8n workflows and configurations are now fully protected!${NC}"
echo ""

exit 0

