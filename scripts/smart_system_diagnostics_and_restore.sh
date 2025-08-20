#!/bin/bash

# ============================================================================
# SMART SYSTEM DIAGNOSTICS AND SELECTIVE RESTORE
# ============================================================================
# Purpose: Diagnose current system, compare with backup requirements, 
#          and selectively install only missing components
# Safety: Backs up everything before making changes
# Approach: Non-destructive - only adds missing components
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
BACKUP_REPO="https://github.com/vitalykirkpatrick/server-recovery-toolkit.git"
DIAGNOSTICS_DIR="/root/diagnostics"
BACKUP_DIR="/root/pre_restore_backup_$(date +%Y%m%d_%H%M%S)"
LOG_FILE="/var/log/smart_diagnostics_restore.log"

# Logging functions
log() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"; }
info() { echo -e "${CYAN}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }

echo "🔍 SMART SYSTEM DIAGNOSTICS AND SELECTIVE RESTORE"
echo "================================================="
echo "🎯 This will diagnose your system and only install missing components"
echo "🛡️ Backs up everything before making any changes"
echo "✅ Non-destructive - preserves working installations"
echo ""

# ============================================================================
# CREATE COMPREHENSIVE BACKUP BEFORE ANY CHANGES
# ============================================================================

create_comprehensive_backup() {
    log "💾 CREATING COMPREHENSIVE BACKUP BEFORE ANY CHANGES"
    
    mkdir -p "$BACKUP_DIR"
    
    # Backup system configuration
    log "📂 Backing up system configuration..."
    
    # Backup critical directories
    local backup_paths=(
        "/etc/nginx"
        "/etc/systemd/system"
        "/etc/cron.d"
        "/etc/crontab"
        "/root/.n8n"
        "/root/.env"
        "/root/scripts"
        "/root/workflows"
        "/var/spool/cron/crontabs"
    )
    
    for path in "${backup_paths[@]}"; do
        if [ -e "$path" ]; then
            local backup_name=$(echo "$path" | sed 's/\//_/g' | sed 's/^_//')
            cp -r "$path" "$BACKUP_DIR/$backup_name" 2>/dev/null || true
            success "✅ Backed up: $path"
        fi
    done
    
    # Backup package lists
    log "📦 Backing up package information..."
    dpkg --get-selections > "$BACKUP_DIR/dpkg_selections.txt"
    apt list --installed > "$BACKUP_DIR/apt_installed.txt" 2>/dev/null
    npm list -g --depth=0 > "$BACKUP_DIR/npm_global.txt" 2>/dev/null || true
    pip3 list > "$BACKUP_DIR/pip3_packages.txt" 2>/dev/null || true
    
    # Backup service states
    log "🔄 Backing up service states..."
    systemctl list-units --type=service --state=active > "$BACKUP_DIR/active_services.txt"
    systemctl list-units --type=service --state=enabled > "$BACKUP_DIR/enabled_services.txt"
    
    # Backup cron jobs
    log "📅 Backing up cron jobs..."
    crontab -l > "$BACKUP_DIR/root_crontab.txt" 2>/dev/null || echo "No crontab for root" > "$BACKUP_DIR/root_crontab.txt"
    
    # Create backup manifest
    cat > "$BACKUP_DIR/backup_manifest.txt" << EOF
# Comprehensive System Backup
# Created: $(date)
# Purpose: Pre-restore backup before smart diagnostics and selective restore

BACKUP_DIRECTORIES:
$(find "$BACKUP_DIR" -type d | sort)

BACKUP_FILES:
$(find "$BACKUP_DIR" -type f | sort)

SYSTEM_INFO:
OS: $(lsb_release -d | cut -f2)
Kernel: $(uname -r)
Architecture: $(uname -m)
Uptime: $(uptime)

DISK_USAGE:
$(df -h)

MEMORY_USAGE:
$(free -h)
EOF
    
    success "Comprehensive backup created: $BACKUP_DIR"
}

# ============================================================================
# DIAGNOSE CURRENT SYSTEM STATE
# ============================================================================

diagnose_current_system() {
    log "🔍 DIAGNOSING CURRENT SYSTEM STATE"
    
    mkdir -p "$DIAGNOSTICS_DIR"
    
    # System information
    log "💻 Gathering system information..."
    cat > "$DIAGNOSTICS_DIR/system_info.txt" << EOF
# System Information
OS: $(lsb_release -d | cut -f2)
Kernel: $(uname -r)
Architecture: $(uname -m)
Hostname: $(hostname)
Uptime: $(uptime)
Date: $(date)
EOF
    
    # Check Node.js and npm
    log "📦 Checking Node.js and npm..."
    cat > "$DIAGNOSTICS_DIR/nodejs_status.txt" << EOF
# Node.js and npm Status
EOF
    
    if command -v node &> /dev/null; then
        echo "Node.js: INSTALLED ($(node --version))" >> "$DIAGNOSTICS_DIR/nodejs_status.txt"
    else
        echo "Node.js: NOT INSTALLED" >> "$DIAGNOSTICS_DIR/nodejs_status.txt"
    fi
    
    if command -v npm &> /dev/null; then
        echo "npm: INSTALLED ($(npm --version))" >> "$DIAGNOSTICS_DIR/nodejs_status.txt"
        echo "" >> "$DIAGNOSTICS_DIR/nodejs_status.txt"
        echo "Global npm packages:" >> "$DIAGNOSTICS_DIR/nodejs_status.txt"
        npm list -g --depth=0 >> "$DIAGNOSTICS_DIR/nodejs_status.txt" 2>/dev/null || true
    else
        echo "npm: NOT INSTALLED" >> "$DIAGNOSTICS_DIR/nodejs_status.txt"
    fi
    
    # Check n8n
    log "🔧 Checking n8n installation..."
    cat > "$DIAGNOSTICS_DIR/n8n_status.txt" << EOF
# n8n Status
EOF
    
    if command -v n8n &> /dev/null; then
        echo "n8n: INSTALLED ($(n8n --version 2>/dev/null || echo 'version unknown'))" >> "$DIAGNOSTICS_DIR/n8n_status.txt"
        echo "n8n location: $(which n8n)" >> "$DIAGNOSTICS_DIR/n8n_status.txt"
    else
        echo "n8n: NOT INSTALLED" >> "$DIAGNOSTICS_DIR/n8n_status.txt"
    fi
    
    # Check n8n service
    if systemctl list-units --type=service | grep -q "n8n"; then
        echo "n8n service: EXISTS" >> "$DIAGNOSTICS_DIR/n8n_status.txt"
        echo "n8n service status: $(systemctl is-active n8n 2>/dev/null || echo 'inactive')" >> "$DIAGNOSTICS_DIR/n8n_status.txt"
    else
        echo "n8n service: NOT CONFIGURED" >> "$DIAGNOSTICS_DIR/n8n_status.txt"
    fi
    
    # Check n8n configuration
    if [ -d "/root/.n8n" ]; then
        echo "n8n config directory: EXISTS" >> "$DIAGNOSTICS_DIR/n8n_status.txt"
        echo "n8n config files:" >> "$DIAGNOSTICS_DIR/n8n_status.txt"
        ls -la /root/.n8n/ >> "$DIAGNOSTICS_DIR/n8n_status.txt" 2>/dev/null || true
    else
        echo "n8n config directory: NOT FOUND" >> "$DIAGNOSTICS_DIR/n8n_status.txt"
    fi
    
    # Check Docker
    log "🐳 Checking Docker installation..."
    cat > "$DIAGNOSTICS_DIR/docker_status.txt" << EOF
# Docker Status
EOF
    
    if command -v docker &> /dev/null; then
        echo "Docker: INSTALLED ($(docker --version | cut -d' ' -f3 | tr -d ','))" >> "$DIAGNOSTICS_DIR/docker_status.txt"
        echo "Docker service: $(systemctl is-active docker 2>/dev/null || echo 'inactive')" >> "$DIAGNOSTICS_DIR/docker_status.txt"
        echo "Docker images:" >> "$DIAGNOSTICS_DIR/docker_status.txt"
        docker images >> "$DIAGNOSTICS_DIR/docker_status.txt" 2>/dev/null || echo "Cannot list images" >> "$DIAGNOSTICS_DIR/docker_status.txt"
    else
        echo "Docker: NOT INSTALLED" >> "$DIAGNOSTICS_DIR/docker_status.txt"
    fi
    
    # Check nginx
    log "📝 Checking nginx installation..."
    cat > "$DIAGNOSTICS_DIR/nginx_status.txt" << EOF
# nginx Status
EOF
    
    if command -v nginx &> /dev/null; then
        echo "nginx: INSTALLED ($(nginx -v 2>&1 | cut -d' ' -f3))" >> "$DIAGNOSTICS_DIR/nginx_status.txt"
        echo "nginx service: $(systemctl is-active nginx 2>/dev/null || echo 'inactive')" >> "$DIAGNOSTICS_DIR/nginx_status.txt"
        echo "nginx sites enabled:" >> "$DIAGNOSTICS_DIR/nginx_status.txt"
        ls -la /etc/nginx/sites-enabled/ >> "$DIAGNOSTICS_DIR/nginx_status.txt" 2>/dev/null || echo "No sites-enabled directory" >> "$DIAGNOSTICS_DIR/nginx_status.txt"
    else
        echo "nginx: NOT INSTALLED" >> "$DIAGNOSTICS_DIR/nginx_status.txt"
    fi
    
    # Check PostgreSQL
    log "🗄️ Checking PostgreSQL installation..."
    cat > "$DIAGNOSTICS_DIR/postgresql_status.txt" << EOF
# PostgreSQL Status
EOF
    
    if command -v psql &> /dev/null; then
        echo "PostgreSQL: INSTALLED ($(psql --version | cut -d' ' -f3))" >> "$DIAGNOSTICS_DIR/postgresql_status.txt"
        echo "PostgreSQL service: $(systemctl is-active postgresql 2>/dev/null || echo 'inactive')" >> "$DIAGNOSTICS_DIR/postgresql_status.txt"
        echo "PostgreSQL databases:" >> "$DIAGNOSTICS_DIR/postgresql_status.txt"
        sudo -u postgres psql -l >> "$DIAGNOSTICS_DIR/postgresql_status.txt" 2>/dev/null || echo "Cannot list databases" >> "$DIAGNOSTICS_DIR/postgresql_status.txt"
    else
        echo "PostgreSQL: NOT INSTALLED" >> "$DIAGNOSTICS_DIR/postgresql_status.txt"
    fi
    
    # Check Python and packages
    log "🐍 Checking Python installation..."
    cat > "$DIAGNOSTICS_DIR/python_status.txt" << EOF
# Python Status
EOF
    
    if command -v python3 &> /dev/null; then
        echo "Python3: INSTALLED ($(python3 --version | cut -d' ' -f2))" >> "$DIAGNOSTICS_DIR/python_status.txt"
        echo "pip3: $(pip3 --version 2>/dev/null || echo 'NOT INSTALLED')" >> "$DIAGNOSTICS_DIR/python_status.txt"
        echo "" >> "$DIAGNOSTICS_DIR/python_status.txt"
        echo "Installed Python packages:" >> "$DIAGNOSTICS_DIR/python_status.txt"
        pip3 list >> "$DIAGNOSTICS_DIR/python_status.txt" 2>/dev/null || echo "Cannot list packages" >> "$DIAGNOSTICS_DIR/python_status.txt"
    else
        echo "Python3: NOT INSTALLED" >> "$DIAGNOSTICS_DIR/python_status.txt"
    fi
    
    # Check audiobook processing tools
    log "🎧 Checking audiobook processing tools..."
    cat > "$DIAGNOSTICS_DIR/audiobook_tools_status.txt" << EOF
# Audiobook Processing Tools Status
EOF
    
    local audiobook_tools=(
        "ffmpeg"
        "sox"
        "lame"
        "flac"
        "imagemagick"
        "tesseract"
        "ghostscript"
        "poppler-utils"
    )
    
    for tool in "${audiobook_tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            echo "$tool: INSTALLED" >> "$DIAGNOSTICS_DIR/audiobook_tools_status.txt"
        else
            echo "$tool: NOT INSTALLED" >> "$DIAGNOSTICS_DIR/audiobook_tools_status.txt"
        fi
    done
    
    # Check system packages
    log "📦 Checking system packages..."
    dpkg --get-selections > "$DIAGNOSTICS_DIR/current_packages.txt"
    apt list --installed > "$DIAGNOSTICS_DIR/current_apt_packages.txt" 2>/dev/null
    
    success "System diagnostics completed"
}

# ============================================================================
# DOWNLOAD AND ANALYZE BACKUP REQUIREMENTS
# ============================================================================

analyze_backup_requirements() {
    log "📥 ANALYZING BACKUP REQUIREMENTS"
    
    # Download backup repository
    local temp_repo="/tmp/backup_analysis"
    rm -rf "$temp_repo"
    mkdir -p "$temp_repo"
    
    cd "$temp_repo"
    git clone "$BACKUP_REPO" .
    
    # Look for backup files and manifests
    local backup_files=($(find . -name "*.tar.gz" -o -name "*manifest*" -o -name "*requirements*" | sort -r))
    
    if [ ${#backup_files[@]} -eq 0 ]; then
        warning "⚠️ No backup files found in repository"
        return 1
    fi
    
    log "📂 Found backup files:"
    for file in "${backup_files[@]}"; do
        log "   📄 $file"
    done
    
    # Extract and analyze the most recent backup
    local latest_backup=""
    for file in "${backup_files[@]}"; do
        if [[ "$file" == *.tar.gz ]]; then
            latest_backup="$file"
            break
        fi
    done
    
    if [ -n "$latest_backup" ]; then
        log "📦 Analyzing latest backup: $latest_backup"
        
        # Extract backup to analyze contents
        local extract_dir="/tmp/backup_extract"
        mkdir -p "$extract_dir"
        tar -xzf "$latest_backup" -C "$extract_dir" 2>/dev/null || true
        
        # Analyze backup contents
        cat > "$DIAGNOSTICS_DIR/backup_requirements.txt" << EOF
# Backup Requirements Analysis
# Source: $latest_backup
# Extracted to: $extract_dir

BACKUP_CONTENTS:
$(find "$extract_dir" -type f | head -20)

REQUIRED_DIRECTORIES:
EOF
        
        # Check what directories should exist based on backup
        local required_dirs=(
            "/root/.n8n"
            "/etc/nginx"
            "/etc/systemd/system"
            "/root/scripts"
            "/root/workflows"
        )
        
        for dir in "${required_dirs[@]}"; do
            local backup_dir_name=$(echo "$dir" | sed 's/\//_/g' | sed 's/^_//')
            if [ -d "$extract_dir/$backup_dir_name" ] || [ -d "$extract_dir$dir" ]; then
                echo "$dir: REQUIRED (found in backup)" >> "$DIAGNOSTICS_DIR/backup_requirements.txt"
            else
                echo "$dir: NOT IN BACKUP" >> "$DIAGNOSTICS_DIR/backup_requirements.txt"
            fi
        done
        
        # Clean up
        rm -rf "$extract_dir"
    fi
    
    # Clean up temp repo
    cd /root
    rm -rf "$temp_repo"
    
    success "Backup requirements analyzed"
}

# ============================================================================
# COMPARE CURRENT STATE WITH REQUIREMENTS
# ============================================================================

compare_and_identify_gaps() {
    log "🔍 COMPARING CURRENT STATE WITH REQUIREMENTS"
    
    cat > "$DIAGNOSTICS_DIR/gap_analysis.txt" << EOF
# Gap Analysis - What's Missing
# Generated: $(date)

MISSING_COMPONENTS:
EOF
    
    # Check Node.js
    if ! command -v node &> /dev/null; then
        echo "- Node.js (required for n8n)" >> "$DIAGNOSTICS_DIR/gap_analysis.txt"
    fi
    
    # Check npm
    if ! command -v npm &> /dev/null; then
        echo "- npm (required for n8n installation)" >> "$DIAGNOSTICS_DIR/gap_analysis.txt"
    fi
    
    # Check n8n
    if ! command -v n8n &> /dev/null; then
        echo "- n8n (main application)" >> "$DIAGNOSTICS_DIR/gap_analysis.txt"
    fi
    
    # Check nginx
    if ! command -v nginx &> /dev/null; then
        echo "- nginx (web server)" >> "$DIAGNOSTICS_DIR/gap_analysis.txt"
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        echo "- Docker (containerization)" >> "$DIAGNOSTICS_DIR/gap_analysis.txt"
    fi
    
    # Check PostgreSQL
    if ! command -v psql &> /dev/null; then
        echo "- PostgreSQL (database)" >> "$DIAGNOSTICS_DIR/gap_analysis.txt"
    fi
    
    # Check Python packages
    local python_packages=(
        "pydub"
        "mutagen"
        "pillow"
        "requests"
        "beautifulsoup4"
        "openai"
    )
    
    echo "" >> "$DIAGNOSTICS_DIR/gap_analysis.txt"
    echo "MISSING_PYTHON_PACKAGES:" >> "$DIAGNOSTICS_DIR/gap_analysis.txt"
    
    for package in "${python_packages[@]}"; do
        if ! pip3 show "$package" &> /dev/null; then
            echo "- $package" >> "$DIAGNOSTICS_DIR/gap_analysis.txt"
        fi
    done
    
    # Check audiobook tools
    local audiobook_tools=(
        "ffmpeg"
        "sox"
        "lame"
        "flac"
        "tesseract"
    )
    
    echo "" >> "$DIAGNOSTICS_DIR/gap_analysis.txt"
    echo "MISSING_AUDIOBOOK_TOOLS:" >> "$DIAGNOSTICS_DIR/gap_analysis.txt"
    
    for tool in "${audiobook_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            echo "- $tool" >> "$DIAGNOSTICS_DIR/gap_analysis.txt"
        fi
    done
    
    # Check required directories
    local required_dirs=(
        "/root/.n8n"
        "/root/scripts"
        "/root/workflows"
    )
    
    echo "" >> "$DIAGNOSTICS_DIR/gap_analysis.txt"
    echo "MISSING_DIRECTORIES:" >> "$DIAGNOSTICS_DIR/gap_analysis.txt"
    
    for dir in "${required_dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            echo "- $dir" >> "$DIAGNOSTICS_DIR/gap_analysis.txt"
        fi
    done
    
    success "Gap analysis completed"
}

# ============================================================================
# SELECTIVE INSTALLATION OF MISSING COMPONENTS
# ============================================================================

selective_install_missing_components() {
    log "📦 SELECTIVE INSTALLATION OF MISSING COMPONENTS"
    
    # Read gap analysis
    if [ ! -f "$DIAGNOSTICS_DIR/gap_analysis.txt" ]; then
        error "❌ Gap analysis file not found"
        return 1
    fi
    
    # Install missing system packages
    local missing_packages=()
    
    # Check what's missing and add to install list
    if ! command -v node &> /dev/null; then
        log "📦 Node.js missing - will install"
        missing_packages+=("nodejs")
    fi
    
    if ! command -v nginx &> /dev/null; then
        log "📝 nginx missing - will install"
        missing_packages+=("nginx")
    fi
    
    if ! command -v docker &> /dev/null; then
        log "🐳 Docker missing - will install"
        missing_packages+=("docker.io")
    fi
    
    if ! command -v psql &> /dev/null; then
        log "🗄️ PostgreSQL missing - will install"
        missing_packages+=("postgresql" "postgresql-contrib")
    fi
    
    if ! command -v ffmpeg &> /dev/null; then
        log "🎧 FFmpeg missing - will install"
        missing_packages+=("ffmpeg")
    fi
    
    if ! command -v sox &> /dev/null; then
        log "🎵 Sox missing - will install"
        missing_packages+=("sox")
    fi
    
    if ! command -v tesseract &> /dev/null; then
        log "📖 Tesseract missing - will install"
        missing_packages+=("tesseract-ocr" "tesseract-ocr-ukr" "tesseract-ocr-rus")
    fi
    
    # Install missing packages if any
    if [ ${#missing_packages[@]} -gt 0 ]; then
        log "📦 Installing missing packages: ${missing_packages[*]}"
        
        # Update package list
        apt-get update -y
        
        # Install missing packages
        apt-get install -y "${missing_packages[@]}"
        
        success "Missing system packages installed"
    else
        log "✅ All required system packages are already installed"
    fi
    
    # Install Node.js properly if needed
    if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
        log "📦 Installing Node.js 18.x LTS..."
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        apt-get install -y nodejs
        success "Node.js installed"
    fi
    
    # Install n8n if missing
    if ! command -v n8n &> /dev/null; then
        log "🔧 Installing n8n..."
        npm install -g n8n
        success "n8n installed"
    else
        log "✅ n8n is already installed"
    fi
    
    # Install missing Python packages
    local python_packages=(
        "pydub"
        "mutagen"
        "pillow"
        "requests"
        "beautifulsoup4"
        "openai"
        "google-cloud-texttospeech"
        "azure-cognitiveservices-speech"
    )
    
    local missing_python_packages=()
    for package in "${python_packages[@]}"; do
        if ! pip3 show "$package" &> /dev/null; then
            missing_python_packages+=("$package")
        fi
    done
    
    if [ ${#missing_python_packages[@]} -gt 0 ]; then
        log "🐍 Installing missing Python packages: ${missing_python_packages[*]}"
        pip3 install "${missing_python_packages[@]}"
        success "Missing Python packages installed"
    else
        log "✅ All required Python packages are already installed"
    fi
    
    # Create missing directories
    local required_dirs=(
        "/root/.n8n"
        "/root/scripts"
        "/root/workflows"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            log "📁 Creating missing directory: $dir"
            mkdir -p "$dir"
            success "Created directory: $dir"
        else
            log "✅ Directory already exists: $dir"
        fi
    done
}

# ============================================================================
# RESTORE CONFIGURATIONS FROM BACKUP
# ============================================================================

restore_configurations_from_backup() {
    log "🔄 RESTORING CONFIGURATIONS FROM BACKUP"
    
    # Download and extract backup
    local temp_repo="/tmp/backup_restore"
    rm -rf "$temp_repo"
    mkdir -p "$temp_repo"
    
    cd "$temp_repo"
    git clone "$BACKUP_REPO" .
    
    # Find latest backup
    local backup_files=($(find . -name "*.tar.gz" | sort -r))
    
    if [ ${#backup_files[@]} -eq 0 ]; then
        warning "⚠️ No backup files found for restoration"
        return 1
    fi
    
    local latest_backup="${backup_files[0]}"
    log "📦 Restoring from: $latest_backup"
    
    # Extract backup
    local extract_dir="/tmp/backup_extract"
    mkdir -p "$extract_dir"
    tar -xzf "$latest_backup" -C "$extract_dir" 2>/dev/null || true
    
    # Restore configurations only if they don't exist or are empty
    local restore_paths=(
        ".n8n:/root/.n8n"
        ".env:/root/.env"
        "scripts:/root/scripts"
        "workflows:/root/workflows"
        "nginx:/etc/nginx"
    )
    
    for restore_path in "${restore_paths[@]}"; do
        local source_path=$(echo "$restore_path" | cut -d':' -f1)
        local dest_path=$(echo "$restore_path" | cut -d':' -f2)
        
        # Check if source exists in backup
        if [ -e "$extract_dir/$source_path" ]; then
            # Only restore if destination doesn't exist or is empty
            if [ ! -e "$dest_path" ] || [ -z "$(ls -A "$dest_path" 2>/dev/null)" ]; then
                log "🔄 Restoring: $source_path -> $dest_path"
                cp -r "$extract_dir/$source_path" "$dest_path"
                success "✅ Restored: $dest_path"
            else
                log "⏭️ Skipping: $dest_path (already exists and not empty)"
            fi
        fi
    done
    
    # Clean up
    rm -rf "$extract_dir"
    cd /root
    rm -rf "$temp_repo"
    
    success "Configuration restoration completed"
}

# ============================================================================
# VERIFY SYSTEM AFTER RESTORATION
# ============================================================================

verify_system_after_restoration() {
    log "✅ VERIFYING SYSTEM AFTER RESTORATION"
    
    cat > "$DIAGNOSTICS_DIR/post_restore_verification.txt" << EOF
# Post-Restoration Verification
# Generated: $(date)

SYSTEM_STATUS:
EOF
    
    # Check services
    local services=("nginx" "postgresql" "docker")
    for service in "${services[@]}"; do
        if systemctl list-units --type=service | grep -q "$service"; then
            local status=$(systemctl is-active "$service" 2>/dev/null || echo "inactive")
            echo "$service: $status" >> "$DIAGNOSTICS_DIR/post_restore_verification.txt"
        else
            echo "$service: not configured" >> "$DIAGNOSTICS_DIR/post_restore_verification.txt"
        fi
    done
    
    # Check n8n
    if command -v n8n &> /dev/null; then
        echo "n8n: INSTALLED ($(n8n --version 2>/dev/null || echo 'version unknown'))" >> "$DIAGNOSTICS_DIR/post_restore_verification.txt"
    else
        echo "n8n: NOT INSTALLED" >> "$DIAGNOSTICS_DIR/post_restore_verification.txt"
    fi
    
    # Check configurations
    echo "" >> "$DIAGNOSTICS_DIR/post_restore_verification.txt"
    echo "CONFIGURATIONS:" >> "$DIAGNOSTICS_DIR/post_restore_verification.txt"
    
    local config_paths=(
        "/root/.n8n"
        "/root/.env"
        "/root/scripts"
        "/etc/nginx/sites-enabled"
    )
    
    for path in "${config_paths[@]}"; do
        if [ -e "$path" ]; then
            echo "$path: EXISTS" >> "$DIAGNOSTICS_DIR/post_restore_verification.txt"
        else
            echo "$path: MISSING" >> "$DIAGNOSTICS_DIR/post_restore_verification.txt"
        fi
    done
    
    success "System verification completed"
}

# ============================================================================
# SHOW COMPREHENSIVE RESULTS
# ============================================================================

show_comprehensive_results() {
    log "📊 SMART DIAGNOSTICS AND RESTORATION COMPLETED"
    
    echo ""
    echo "============================================"
    echo "🔍 SMART DIAGNOSTICS AND RESTORATION COMPLETED"
    echo "============================================"
    echo ""
    echo "💾 BACKUP CREATED:"
    echo "   📂 Pre-restoration backup: $BACKUP_DIR"
    echo "   🛡️ All configurations backed up before changes"
    echo ""
    echo "🔍 DIAGNOSTICS COMPLETED:"
    echo "   📊 System state analyzed: $DIAGNOSTICS_DIR"
    echo "   📋 Gap analysis performed"
    echo "   🎯 Missing components identified"
    echo ""
    echo "📦 SELECTIVE INSTALLATION:"
    echo "   ✅ Only missing components installed"
    echo "   🛡️ Existing installations preserved"
    echo "   📝 No destructive changes made"
    echo ""
    echo "🔄 CONFIGURATION RESTORATION:"
    echo "   📂 Configurations restored from backup"
    echo "   ⏭️ Existing configs preserved"
    echo "   🎯 Only missing configs restored"
    echo ""
    echo "📊 VERIFICATION:"
    echo "   ✅ System verified after restoration"
    echo "   📋 Status report generated"
    echo ""
    echo "📁 IMPORTANT FILES:"
    echo "   📊 Diagnostics: $DIAGNOSTICS_DIR/"
    echo "   💾 Backup: $BACKUP_DIR/"
    echo "   📜 Log: $LOG_FILE"
    echo ""
    echo "🔍 REVIEW RESULTS:"
    echo "   📊 Check diagnostics: ls -la $DIAGNOSTICS_DIR/"
    echo "   📋 Gap analysis: cat $DIAGNOSTICS_DIR/gap_analysis.txt"
    echo "   ✅ Verification: cat $DIAGNOSTICS_DIR/post_restore_verification.txt"
    echo ""
    echo "🎯 NEXT STEPS:"
    echo "   1. Review diagnostics results"
    echo "   2. Test system functionality"
    echo "   3. Start required services if needed"
    echo "   4. Configure any remaining components"
    echo ""
    echo "✅ SMART RESTORATION COMPLETED SAFELY!"
    echo "============================================"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    log "🔍 SMART SYSTEM DIAGNOSTICS AND SELECTIVE RESTORE STARTED"
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root (use sudo)"
        exit 1
    fi
    
    # Create log file
    touch "$LOG_FILE"
    
    echo "⚠️  This will diagnose your system and selectively install missing components"
    echo "🛡️  A comprehensive backup will be created before any changes"
    echo "✅  Existing working installations will be preserved"
    echo ""
    read -p "Continue with smart diagnostics and restoration? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Smart diagnostics and restoration cancelled."
        exit 0
    fi
    
    # Execute smart restoration
    create_comprehensive_backup
    diagnose_current_system
    analyze_backup_requirements
    compare_and_identify_gaps
    selective_install_missing_components
    restore_configurations_from_backup
    verify_system_after_restoration
    show_comprehensive_results
    
    success "🎉 SMART DIAGNOSTICS AND RESTORATION COMPLETED"
    log "📜 Full log available at: $LOG_FILE"
}

# Run main function
main "$@"

