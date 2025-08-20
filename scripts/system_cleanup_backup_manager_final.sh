#!/bin/bash

# ============================================================================
# SYSTEM CLEANUP & BACKUP MANAGER (FINAL CORRECTED VERSION)
# ============================================================================
# Purpose: Manage backups, clean unnecessary files, optimize system resources
# Features: Keep 3 latest + 2 full backups, remove unused packages, optimize disk
# Fixed: Properly handles n8n_minimal_backup_YYYYMMDD_HHMMSS.tar.gz files
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
BACKUP_DIR="/var/backups"
LOG_FILE="/var/log/system_cleanup.log"
MAX_INCREMENTAL_BACKUPS=3
MAX_FULL_BACKUPS=2
MIN_FREE_SPACE_GB=5

# Logging functions
log() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"; }
info() { echo -e "${CYAN}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }

# ============================================================================
# BACKUP MANAGEMENT FUNCTIONS (CORRECTED)
# ============================================================================

manage_n8n_backups() {
    log "🔄 Managing n8n backup files..."
    
    # Specific directories where n8n backups are stored
    local n8n_backup_dirs=(
        "/root"
        "/home/*/backups"
        "/var/backups"
        "/opt/backups"
    )
    
    # n8n backup patterns (based on your backup script)
    local n8n_patterns=(
        "n8n_minimal_backup_*.tar.gz"
        "n8n_backup_*.tar.gz"
        "n8n_*_backup_*.tar.gz"
    )
    
    for dir in "${n8n_backup_dirs[@]}"; do
        # Handle wildcard expansion for /home/*/backups
        for expanded_dir in $dir; do
            if [ -d "$expanded_dir" ]; then
                log "🔍 Checking n8n backup directory: $expanded_dir"
                
                for pattern in "${n8n_patterns[@]}"; do
                    # Create temporary file to store backup list
                    local temp_file=$(mktemp)
                    
                    # Find n8n backup files, sort by modification time (newest first)
                    find "$expanded_dir" -maxdepth 1 -name "$pattern" -type f -printf '%T@ %p\n' 2>/dev/null | sort -nr > "$temp_file"
                    
                    if [ -s "$temp_file" ]; then
                        local count=0
                        local total_files=$(wc -l < "$temp_file")
                        log "📊 Found $total_files n8n backup files matching pattern: $pattern"
                        
                        # Read the sorted file list
                        while IFS=' ' read -r timestamp filepath; do
                            count=$((count + 1))
                            local file_size=$(du -h "$filepath" 2>/dev/null | cut -f1 || echo "unknown")
                            local file_date=$(date -d "@${timestamp%.*}" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "unknown")
                            
                            if [ "$count" -gt "$MAX_INCREMENTAL_BACKUPS" ]; then
                                log "🗑️ Removing old n8n backup #$count: $(basename "$filepath") ($file_size, $file_date)"
                                rm -f "$filepath"
                                
                                # Also remove associated manifest files
                                local manifest_file="${filepath%.*}_MANIFEST.txt"
                                if [ -f "$manifest_file" ]; then
                                    log "🗑️ Removing associated manifest: $(basename "$manifest_file")"
                                    rm -f "$manifest_file"
                                fi
                                
                                # Remove backup_MANIFEST.txt if it exists in same directory
                                local backup_manifest="$(dirname "$filepath")/backup_MANIFEST.txt"
                                if [ -f "$backup_manifest" ]; then
                                    # Check if this manifest is older than the newest 3 backups
                                    local manifest_time=$(stat -c %Y "$backup_manifest" 2>/dev/null || echo 0)
                                    if [ "$manifest_time" -lt "${timestamp%.*}" ]; then
                                        log "🗑️ Removing old backup manifest: $(basename "$backup_manifest")"
                                        rm -f "$backup_manifest"
                                    fi
                                fi
                            else
                                log "✅ Keeping n8n backup #$count: $(basename "$filepath") ($file_size, $file_date)"
                            fi
                        done < "$temp_file"
                    fi
                    
                    # Clean up temporary file
                    rm -f "$temp_file"
                done
            fi
        done
    done
}

manage_incremental_backups() {
    log "🔄 Managing other incremental backups..."
    
    # Find incremental backup files (common patterns, excluding n8n)
    local backup_patterns=(
        "*.tar.gz" "*.tar.bz2" "*.tar.xz" "*.zip"
        "*backup*.tar.gz" "*dump*.sql.gz" "*snapshot*.tar.gz"
        "*.sql" "*.sql.gz"
    )
    
    local backup_dirs=(
        "$BACKUP_DIR"
        "/var/backups"
        "/home/*/backups"
        "/opt/backups"
        "/tmp"
        "/var/tmp"
    )
    
    for dir in "${backup_dirs[@]}"; do
        for expanded_dir in $dir; do
            if [ -d "$expanded_dir" ]; then
                log "🔍 Checking backup directory: $expanded_dir"
                
                for pattern in "${backup_patterns[@]}"; do
                    # Create temporary file to store backup list
                    local temp_file=$(mktemp)
                    
                    # Skip n8n backup files (handled separately)
                    find "$expanded_dir" -maxdepth 1 -name "$pattern" -type f ! -name "n8n_*backup*" -printf '%T@ %p\n' 2>/dev/null | sort -nr > "$temp_file"
                    
                    if [ -s "$temp_file" ]; then
                        local count=0
                        while IFS=' ' read -r timestamp filepath; do
                            count=$((count + 1))
                            if [ "$count" -gt "$MAX_INCREMENTAL_BACKUPS" ]; then
                                local file_size=$(du -h "$filepath" 2>/dev/null | cut -f1 || echo "unknown")
                                log "🗑️ Removing old backup: $(basename "$filepath") ($file_size)"
                                rm -f "$filepath"
                            fi
                        done < "$temp_file"
                    fi
                    
                    # Clean up temporary file
                    rm -f "$temp_file"
                done
            fi
        done
    done
}

manage_full_backups() {
    log "💽 Managing full system backups..."
    
    # Common full backup patterns
    local full_backup_patterns=(
        "*full*backup*" "*system*backup*" "*complete*backup*"
        "*.img" "*.iso" "*clone*" "*image*"
    )
    
    for dir in "/var/backups" "/opt/backups" "/home/*/backups" "/root"; do
        for expanded_dir in $dir; do
            if [ -d "$expanded_dir" ]; then
                for pattern in "${full_backup_patterns[@]}"; do
                    # Create temporary file to store backup list
                    local temp_file=$(mktemp)
                    
                    find "$expanded_dir" -maxdepth 1 -name "$pattern" -type f -printf '%T@ %p\n' 2>/dev/null | sort -nr > "$temp_file"
                    
                    if [ -s "$temp_file" ]; then
                        local count=0
                        while IFS=' ' read -r timestamp filepath; do
                            count=$((count + 1))
                            if [ "$count" -gt "$MAX_FULL_BACKUPS" ]; then
                                local file_size=$(du -h "$filepath" 2>/dev/null | cut -f1 || echo "unknown")
                                log "🗑️ Removing old full backup: $(basename "$filepath") ($file_size)"
                                rm -f "$filepath"
                            fi
                        done < "$temp_file"
                    fi
                    
                    # Clean up temporary file
                    rm -f "$temp_file"
                done
            fi
        done
    done
}

# ============================================================================
# SYSTEM ANALYSIS FUNCTIONS
# ============================================================================

analyze_disk_usage() {
    log "📊 ANALYZING DISK USAGE"
    
    echo "=== DISK USAGE ANALYSIS ===" >> "$LOG_FILE"
    df -h >> "$LOG_FILE"
    
    log "🔍 Top 10 largest directories:"
    du -h --max-depth=2 / 2>/dev/null | sort -hr | head -10 | tee -a "$LOG_FILE"
    
    log "🔍 Large files (>100MB):"
    find / -type f -size +100M -exec ls -lh {} \; 2>/dev/null | head -20 | tee -a "$LOG_FILE"
}

analyze_packages() {
    log "📦 ANALYZING PACKAGES"
    
    # Find orphaned packages
    local orphaned=$(deborphan 2>/dev/null || apt list --installed | grep -v "automatic" | wc -l)
    log "🔍 Orphaned packages found: $orphaned"
    
    # Find old kernels
    local current_kernel=$(uname -r)
    local old_kernels=$(dpkg -l | grep linux-image | grep -v "$current_kernel" | wc -l)
    log "🔍 Old kernel versions: $old_kernels"
    
    # Package cache size
    local cache_size=$(du -sh /var/cache/apt/archives 2>/dev/null | cut -f1)
    log "🔍 Package cache size: $cache_size"
}

analyze_services() {
    log "🔧 ANALYZING SERVICES"
    
    # Find failed services
    local failed_services=$(systemctl list-units --failed --no-legend | wc -l)
    log "🔍 Failed services: $failed_services"
    
    # Find high memory usage services
    log "🔍 Top 5 memory-consuming services:"
    systemctl status --no-pager -l | grep -E "Memory:|Active:" | head -10 | tee -a "$LOG_FILE"
}

# ============================================================================
# CLEANUP FUNCTIONS
# ============================================================================

cleanup_package_cache() {
    log "🧹 Cleaning package cache..."
    
    # Clean apt cache
    apt-get clean
    apt-get autoclean
    
    # Remove orphaned packages
    if command -v deborphan >/dev/null 2>&1; then
        local orphaned=$(deborphan)
        if [ -n "$orphaned" ]; then
            log "🗑️ Removing orphaned packages..."
            echo "$orphaned" | xargs apt-get -y remove --purge
        fi
    fi
    
    # Remove old kernels (keep current + 1 previous)
    local current_kernel=$(uname -r | sed 's/-generic//')
    local old_kernels=$(dpkg -l | grep linux-image | grep -v "$current_kernel" | awk '{print $2}' | grep -v "$(dpkg -l | grep linux-image | grep -v "$current_kernel" | awk '{print $2}' | sort -V | tail -1)")
    
    if [ -n "$old_kernels" ]; then
        log "🗑️ Removing old kernels..."
        echo "$old_kernels" | xargs apt-get -y remove --purge
    fi
    
    # Autoremove unused packages
    apt-get -y autoremove --purge
    
    success "Package cache cleanup completed"
}

cleanup_temporary_files() {
    log "🧹 Cleaning temporary files..."
    
    # Clean /tmp (files older than 7 days)
    find /tmp -type f -atime +7 -delete 2>/dev/null || true
    find /tmp -type d -empty -delete 2>/dev/null || true
    
    # Clean /var/tmp (files older than 30 days)
    find /var/tmp -type f -atime +30 -delete 2>/dev/null || true
    
    # Clean user cache directories
    find /home -name ".cache" -type d -exec rm -rf {}/chromium {}/google-chrome {}/mozilla {}/thumbnails \; 2>/dev/null || true
    
    # Clean system cache
    rm -rf /var/cache/fontconfig/* 2>/dev/null || true
    rm -rf /var/cache/man/* 2>/dev/null || true
    
    success "Temporary files cleanup completed"
}

cleanup_log_files() {
    log "🧹 Managing log files..."
    
    # Compress large log files
    find /var/log -name "*.log" -size +50M -exec gzip {} \; 2>/dev/null || true
    
    # Remove old compressed logs (older than 30 days)
    find /var/log -name "*.gz" -mtime +30 -delete 2>/dev/null || true
    
    # Clean journal logs (keep last 7 days)
    journalctl --vacuum-time=7d 2>/dev/null || true
    
    # Clean old syslog files
    find /var/log -name "syslog.*" -mtime +7 -delete 2>/dev/null || true
    find /var/log -name "kern.log.*" -mtime +7 -delete 2>/dev/null || true
    find /var/log -name "auth.log.*" -mtime +7 -delete 2>/dev/null || true
    
    success "Log files cleanup completed"
}

cleanup_development_files() {
    log "🧹 Cleaning development files..."
    
    # Clean node_modules (in non-active projects)
    find /home -name "node_modules" -type d -mtime +30 -exec rm -rf {} \; 2>/dev/null || true
    find /root -name "node_modules" -type d -mtime +30 -exec rm -rf {} \; 2>/dev/null || true
    
    # Clean Python cache
    find / -name "__pycache__" -type d -exec rm -rf {} \; 2>/dev/null || true
    find / -name "*.pyc" -delete 2>/dev/null || true
    
    # Clean build directories
    find /home -name "build" -type d -mtime +30 -exec rm -rf {} \; 2>/dev/null || true
    find /home -name "dist" -type d -mtime +30 -exec rm -rf {} \; 2>/dev/null || true
    
    success "Development files cleanup completed"
}

cleanup_docker() {
    log "🧹 Cleaning Docker resources..."
    
    if command -v docker >/dev/null 2>&1; then
        # Remove unused containers
        docker container prune -f 2>/dev/null || true
        
        # Remove unused images
        docker image prune -f 2>/dev/null || true
        
        # Remove unused volumes
        docker volume prune -f 2>/dev/null || true
        
        # Remove unused networks
        docker network prune -f 2>/dev/null || true
        
        success "Docker cleanup completed"
    else
        info "Docker not installed, skipping Docker cleanup"
    fi
}

cleanup_snap_packages() {
    log "🧹 Cleaning Snap packages..."
    
    if command -v snap >/dev/null 2>&1; then
        # Remove old snap revisions (keep only 2 most recent)
        snap list --all | awk '/disabled/{print $1, $3}' | while read snapname revision; do
            snap remove "$snapname" --revision="$revision" 2>/dev/null || true
        done
        
        success "Snap packages cleanup completed"
    else
        info "Snap not installed, skipping Snap cleanup"
    fi
}

# ============================================================================
# OPTIMIZATION FUNCTIONS
# ============================================================================

optimize_memory() {
    log "⚡ Optimizing memory usage..."
    
    # Clear page cache, dentries and inodes
    sync
    echo 3 > /proc/sys/vm/drop_caches
    
    # Optimize swappiness (reduce swap usage)
    echo 10 > /proc/sys/vm/swappiness
    
    success "Memory optimization completed"
}

optimize_disk() {
    log "⚡ Optimizing disk I/O..."
    
    # Run fstrim on all mounted filesystems
    fstrim -av 2>/dev/null || true
    
    # Update locate database
    updatedb 2>/dev/null || true
    
    success "Disk optimization completed"
}

# ============================================================================
# REPORTING FUNCTIONS
# ============================================================================

generate_report() {
    log "📊 Generating cleanup report..."
    
    local report_file="/var/log/cleanup_report_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=== SYSTEM CLEANUP REPORT ==="
        echo "Date: $(date)"
        echo "Script: $0"
        echo ""
        
        echo "=== DISK USAGE BEFORE/AFTER ==="
        df -h
        echo ""
        
        echo "=== BACKUP SUMMARY ==="
        echo "n8n backups in /root:"
        ls -la /root/n8n_*backup*.tar.gz 2>/dev/null || echo "No n8n backups found"
        echo ""
        
        echo "=== SERVICES STATUS ==="
        systemctl list-units --failed --no-legend
        echo ""
        
        echo "=== MEMORY USAGE ==="
        free -h
        echo ""
        
        echo "=== LARGEST DIRECTORIES ==="
        du -h --max-depth=1 / 2>/dev/null | sort -hr | head -10
        
    } > "$report_file"
    
    success "Report generated: $report_file"
}

# ============================================================================
# MAIN EXECUTION FUNCTIONS
# ============================================================================

run_backup_management() {
    log "🎯 STARTING BACKUP MANAGEMENT"
    
    manage_n8n_backups
    manage_incremental_backups
    manage_full_backups
    
    success "Backup management completed"
}

run_system_analysis() {
    log "🎯 STARTING SYSTEM ANALYSIS"
    
    analyze_disk_usage
    analyze_packages
    analyze_services
    
    success "System analysis completed"
}

run_system_cleanup() {
    log "🎯 STARTING SYSTEM CLEANUP"
    
    cleanup_package_cache
    cleanup_temporary_files
    cleanup_log_files
    cleanup_development_files
    cleanup_docker
    cleanup_snap_packages
    
    success "System cleanup completed"
}

run_system_optimization() {
    log "🎯 STARTING SYSTEM OPTIMIZATION"
    
    optimize_memory
    optimize_disk
    
    success "System optimization completed"
}

setup_cron_job() {
    log "⏰ Setting up automated cleanup cron job..."
    
    local cron_entry="0 2 * * 0 /bin/bash $0 --auto"
    
    # Add cron job if it doesn't exist
    if ! crontab -l 2>/dev/null | grep -q "$0"; then
        (crontab -l 2>/dev/null; echo "$cron_entry") | crontab -
        success "Cron job added: Weekly cleanup every Sunday at 2 AM"
    else
        info "Cron job already exists"
    fi
}

# ============================================================================
# MAIN SCRIPT LOGIC
# ============================================================================

main() {
    log "🚀 SYSTEM CLEANUP & BACKUP MANAGER STARTED"
    log "📝 Log file: $LOG_FILE"
    
    case "${1:-}" in
        --analyze-only)
            log "🔍 Running analysis only mode"
            run_system_analysis
            ;;
        --backup-only)
            log "💾 Running backup management only"
            run_backup_management
            ;;
        --cleanup-only)
            log "🧹 Running cleanup only mode"
            run_system_cleanup
            ;;
        --setup-cron)
            log "⏰ Setting up cron job"
            setup_cron_job
            ;;
        --auto)
            log "🤖 Running automated mode (for cron)"
            run_backup_management
            run_system_cleanup
            run_system_optimization
            generate_report
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "OPTIONS:"
            echo "  --analyze-only    Run system analysis only"
            echo "  --backup-only     Run backup management only"
            echo "  --cleanup-only    Run system cleanup only"
            echo "  --setup-cron      Setup automated weekly cleanup"
            echo "  --auto            Automated mode (for cron jobs)"
            echo "  --help, -h        Show this help message"
            echo ""
            echo "Default: Run full cleanup (analysis + backup + cleanup + optimization)"
            ;;
        *)
            log "🎯 Running full system cleanup"
            run_system_analysis
            run_backup_management
            run_system_cleanup
            run_system_optimization
            generate_report
            ;;
    esac
    
    success "🎉 SYSTEM CLEANUP & BACKUP MANAGER COMPLETED"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error "This script must be run as root (use sudo)"
    exit 1
fi

# Create log file if it doesn't exist
touch "$LOG_FILE"

# Run main function with all arguments
main "$@"

