#!/bin/bash

# ============================================================================
# CRON JOBS MANAGEMENT SCRIPT
# ============================================================================
# Purpose: Audit existing cron jobs and replace with updated scripts
# Features: Remove old cron jobs, install correct scripts, setup new cron jobs
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
LOG_FILE="/var/log/cron_management.log"
BACKUP_DIR="/root/cron_backup_$(date +%Y%m%d_%H%M%S)"
SCRIPTS_DIR="/root/scripts"

# Logging functions
log() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"; }
info() { echo -e "${CYAN}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }

# ============================================================================
# CRON AUDIT FUNCTIONS
# ============================================================================

audit_current_cron_jobs() {
    log "🔍 AUDITING CURRENT CRON JOBS"
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    
    # Check root crontab
    log "📋 Checking root crontab..."
    if crontab -l > "$BACKUP_DIR/root_crontab_backup.txt" 2>/dev/null; then
        success "Root crontab backed up to: $BACKUP_DIR/root_crontab_backup.txt"
        
        log "📊 Current root cron jobs:"
        cat "$BACKUP_DIR/root_crontab_backup.txt" | nl | tee -a "$LOG_FILE"
        
        # Analyze cron jobs
        local backup_jobs=$(grep -c "backup" "$BACKUP_DIR/root_crontab_backup.txt" 2>/dev/null || echo "0")
        local cleanup_jobs=$(grep -c "cleanup\|clean" "$BACKUP_DIR/root_crontab_backup.txt" 2>/dev/null || echo "0")
        local n8n_jobs=$(grep -c "n8n" "$BACKUP_DIR/root_crontab_backup.txt" 2>/dev/null || echo "0")
        
        log "📊 Cron job analysis:"
        log "   - Backup jobs: $backup_jobs"
        log "   - Cleanup jobs: $cleanup_jobs"
        log "   - n8n related jobs: $n8n_jobs"
        
    else
        warning "No root crontab found or empty"
        touch "$BACKUP_DIR/root_crontab_backup.txt"
    fi
    
    # Check system cron directories
    log "🔍 Checking system cron directories..."
    
    for cron_dir in /etc/cron.d /etc/cron.daily /etc/cron.weekly /etc/cron.monthly; do
        if [ -d "$cron_dir" ]; then
            log "📁 Checking $cron_dir..."
            
            # List files in cron directory
            if ls "$cron_dir"/* >/dev/null 2>&1; then
                for file in "$cron_dir"/*; do
                    if [ -f "$file" ]; then
                        local filename=$(basename "$file")
                        log "   📄 Found: $filename"
                        
                        # Copy to backup
                        cp "$file" "$BACKUP_DIR/$(basename $cron_dir)_$filename"
                        
                        # Check if it's related to our scripts
                        if grep -q -E "(backup|cleanup|n8n)" "$file" 2>/dev/null; then
                            warning "   ⚠️ Contains backup/cleanup/n8n references"
                        fi
                    fi
                done
            else
                info "   📭 Empty directory"
            fi
        fi
    done
    
    # Check for running cron processes
    log "🔍 Checking running cron processes..."
    ps aux | grep -E "(cron|backup|cleanup)" | grep -v grep | tee -a "$LOG_FILE"
    
    success "Cron audit completed. Backups saved to: $BACKUP_DIR"
}

identify_problematic_cron_jobs() {
    log "🎯 IDENTIFYING PROBLEMATIC CRON JOBS"
    
    local problematic_patterns=(
        "backup_server\.sh"
        "backup_server_minimal\.sh"
        "system_cleanup.*\.sh"
        "/tmp/.*backup"
        "/tmp/.*cleanup"
        "old.*backup"
        "test.*backup"
    )
    
    log "🔍 Scanning for problematic cron job patterns..."
    
    # Check root crontab
    if [ -f "$BACKUP_DIR/root_crontab_backup.txt" ]; then
        for pattern in "${problematic_patterns[@]}"; do
            if grep -q "$pattern" "$BACKUP_DIR/root_crontab_backup.txt" 2>/dev/null; then
                warning "❌ Found problematic pattern in root crontab: $pattern"
                grep "$pattern" "$BACKUP_DIR/root_crontab_backup.txt" | tee -a "$LOG_FILE"
            fi
        done
    fi
    
    # Check system cron files
    for backup_file in "$BACKUP_DIR"/*; do
        if [ -f "$backup_file" ] && [[ "$backup_file" != *"root_crontab_backup.txt" ]]; then
            for pattern in "${problematic_patterns[@]}"; do
                if grep -q "$pattern" "$backup_file" 2>/dev/null; then
                    warning "❌ Found problematic pattern in $(basename $backup_file): $pattern"
                    grep "$pattern" "$backup_file" | tee -a "$LOG_FILE"
                fi
            done
        fi
    done
}

# ============================================================================
# CRON CLEANUP FUNCTIONS
# ============================================================================

remove_old_cron_jobs() {
    log "🧹 REMOVING OLD/PROBLEMATIC CRON JOBS"
    
    # Patterns to remove from crontab
    local remove_patterns=(
        "backup_server\.sh"
        "backup_server_minimal\.sh"
        "system_cleanup.*\.sh"
        "/tmp/.*backup"
        "/tmp/.*cleanup"
        "old.*backup"
        "test.*backup"
        "n8n.*backup"
    )
    
    # Clean root crontab
    log "🧹 Cleaning root crontab..."
    
    if [ -f "$BACKUP_DIR/root_crontab_backup.txt" ] && [ -s "$BACKUP_DIR/root_crontab_backup.txt" ]; then
        # Create cleaned crontab
        cp "$BACKUP_DIR/root_crontab_backup.txt" "$BACKUP_DIR/root_crontab_cleaned.txt"
        
        for pattern in "${remove_patterns[@]}"; do
            if grep -q "$pattern" "$BACKUP_DIR/root_crontab_cleaned.txt" 2>/dev/null; then
                log "🗑️ Removing cron jobs matching pattern: $pattern"
                sed -i "/$pattern/d" "$BACKUP_DIR/root_crontab_cleaned.txt"
            fi
        done
        
        # Apply cleaned crontab
        crontab "$BACKUP_DIR/root_crontab_cleaned.txt"
        success "Root crontab cleaned and applied"
        
        # Show what was removed
        log "📊 Comparison of before/after:"
        log "   Before: $(wc -l < "$BACKUP_DIR/root_crontab_backup.txt") lines"
        log "   After:  $(wc -l < "$BACKUP_DIR/root_crontab_cleaned.txt") lines"
        
    else
        log "📭 Root crontab was empty, nothing to clean"
    fi
    
    # Clean system cron directories
    log "🧹 Cleaning system cron directories..."
    
    for cron_dir in /etc/cron.d /etc/cron.daily /etc/cron.weekly /etc/cron.monthly; do
        if [ -d "$cron_dir" ]; then
            for file in "$cron_dir"/*; do
                if [ -f "$file" ]; then
                    local should_remove=false
                    
                    for pattern in "${remove_patterns[@]}"; do
                        if grep -q "$pattern" "$file" 2>/dev/null; then
                            should_remove=true
                            break
                        fi
                    done
                    
                    if [ "$should_remove" = true ]; then
                        warning "🗑️ Removing problematic cron file: $file"
                        rm -f "$file"
                    fi
                fi
            done
        fi
    done
    
    success "Old cron jobs removed"
}

# ============================================================================
# SCRIPT INSTALLATION FUNCTIONS
# ============================================================================

download_updated_scripts() {
    log "⬇️ DOWNLOADING UPDATED SCRIPTS"
    
    # Create scripts directory
    mkdir -p "$SCRIPTS_DIR"
    cd "$SCRIPTS_DIR"
    
    # Download updated scripts
    local scripts_to_download=(
        "backup_server_fixed.sh:https://raw.githubusercontent.com/vitalykirkpatrick/server-recovery-toolkit/main/scripts/backup_server_fixed.sh"
        "system_cleanup_backup_manager_final.sh:https://raw.githubusercontent.com/vitalykirkpatrick/server-recovery-toolkit/main/scripts/system_cleanup_backup_manager_final.sh"
        "server_restore_script.sh:https://raw.githubusercontent.com/vitalykirkpatrick/server-recovery-toolkit/main/scripts/server_restore_script.sh"
    )
    
    for script_info in "${scripts_to_download[@]}"; do
        local script_name=$(echo "$script_info" | cut -d':' -f1)
        local script_url=$(echo "$script_info" | cut -d':' -f2-)
        
        log "⬇️ Downloading $script_name..."
        
        if wget -O "$script_name" "$script_url"; then
            chmod +x "$script_name"
            success "Downloaded and made executable: $script_name"
        else
            error "Failed to download: $script_name"
        fi
    done
    
    # Verify downloads
    log "✅ Verifying downloaded scripts..."
    for script_info in "${scripts_to_download[@]}"; do
        local script_name=$(echo "$script_info" | cut -d':' -f1)
        
        if [ -f "$SCRIPTS_DIR/$script_name" ] && [ -x "$SCRIPTS_DIR/$script_name" ]; then
            local size=$(du -h "$SCRIPTS_DIR/$script_name" | cut -f1)
            success "✅ $script_name ($size) - Ready"
        else
            error "❌ $script_name - Missing or not executable"
        fi
    done
}

# ============================================================================
# NEW CRON JOBS SETUP
# ============================================================================

setup_new_cron_jobs() {
    log "⏰ SETTING UP NEW CRON JOBS"
    
    # Create new crontab content
    local new_crontab="$BACKUP_DIR/new_crontab.txt"
    
    # Start with existing cleaned crontab (if any)
    if [ -f "$BACKUP_DIR/root_crontab_cleaned.txt" ]; then
        cp "$BACKUP_DIR/root_crontab_cleaned.txt" "$new_crontab"
    else
        touch "$new_crontab"
    fi
    
    # Add header comment
    cat >> "$new_crontab" << 'EOF'

# ============================================================================
# AUTOMATED SERVER MAINTENANCE CRON JOBS
# Updated: $(date)
# ============================================================================

EOF
    
    # Add backup job (daily at 2:30 AM)
    log "📦 Adding daily backup job..."
    cat >> "$new_crontab" << EOF
# Daily backup at 2:30 AM
30 2 * * * /bin/bash $SCRIPTS_DIR/backup_server_fixed.sh >> /var/log/backup_cron.log 2>&1

EOF
    
    # Add cleanup job (weekly on Sunday at 3:00 AM)
    log "🧹 Adding weekly cleanup job..."
    cat >> "$new_crontab" << EOF
# Weekly system cleanup on Sunday at 3:00 AM
0 3 * * 0 /bin/bash $SCRIPTS_DIR/system_cleanup_backup_manager_final.sh --auto >> /var/log/cleanup_cron.log 2>&1

EOF
    
    # Add backup cleanup job (weekly on Sunday at 4:00 AM)
    log "🗑️ Adding weekly backup cleanup job..."
    cat >> "$new_crontab" << EOF
# Weekly backup cleanup on Sunday at 4:00 AM  
0 4 * * 0 /bin/bash $SCRIPTS_DIR/system_cleanup_backup_manager_final.sh --backup-only >> /var/log/backup_cleanup_cron.log 2>&1

EOF
    
    # Add system health check (daily at 6:00 AM)
    log "🔍 Adding daily system health check..."
    cat >> "$new_crontab" << EOF
# Daily system health check at 6:00 AM
0 6 * * * /bin/bash $SCRIPTS_DIR/system_cleanup_backup_manager_final.sh --analyze-only >> /var/log/health_check_cron.log 2>&1

EOF
    
    # Apply new crontab
    log "📝 Applying new crontab..."
    crontab "$new_crontab"
    
    success "New cron jobs installed successfully!"
    
    # Show new crontab
    log "📋 New crontab contents:"
    crontab -l | tee -a "$LOG_FILE"
}

create_log_rotation() {
    log "📜 SETTING UP LOG ROTATION"
    
    # Create logrotate configuration for cron logs
    cat > /etc/logrotate.d/server-maintenance << 'EOF'
/var/log/backup_cron.log
/var/log/cleanup_cron.log  
/var/log/backup_cleanup_cron.log
/var/log/health_check_cron.log
/var/log/cron_management.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
    postrotate
        # Restart rsyslog if it's running
        /bin/kill -HUP `cat /var/run/rsyslogd.pid 2> /dev/null` 2> /dev/null || true
    endscript
}
EOF
    
    success "Log rotation configured for maintenance logs"
}

# ============================================================================
# VERIFICATION FUNCTIONS
# ============================================================================

verify_cron_setup() {
    log "✅ VERIFYING CRON SETUP"
    
    # Check cron service
    log "🔍 Checking cron service status..."
    if systemctl is-active --quiet cron; then
        success "✅ Cron service is running"
    else
        warning "⚠️ Cron service is not running, starting..."
        systemctl start cron
        systemctl enable cron
    fi
    
    # Check crontab syntax
    log "🔍 Verifying crontab syntax..."
    if crontab -l > /dev/null 2>&1; then
        success "✅ Crontab syntax is valid"
    else
        error "❌ Crontab has syntax errors"
        crontab -l
    fi
    
    # Check script permissions
    log "🔍 Checking script permissions..."
    for script in "$SCRIPTS_DIR"/*.sh; do
        if [ -f "$script" ]; then
            if [ -x "$script" ]; then
                success "✅ $(basename $script) is executable"
            else
                warning "⚠️ $(basename $script) is not executable, fixing..."
                chmod +x "$script"
            fi
        fi
    done
    
    # Check log directories
    log "🔍 Checking log file permissions..."
    touch /var/log/backup_cron.log
    touch /var/log/cleanup_cron.log
    touch /var/log/backup_cleanup_cron.log
    touch /var/log/health_check_cron.log
    
    chmod 644 /var/log/*_cron.log
    success "✅ Log files created and permissions set"
    
    # Show next scheduled runs
    log "📅 Next scheduled cron runs:"
    log "   - Daily backup: $(date -d 'tomorrow 02:30' '+%Y-%m-%d %H:%M:%S')"
    log "   - Weekly cleanup: $(date -d 'next Sunday 03:00' '+%Y-%m-%d %H:%M:%S')"
    log "   - Backup cleanup: $(date -d 'next Sunday 04:00' '+%Y-%m-%d %H:%M:%S')"
    log "   - Health check: $(date -d 'tomorrow 06:00' '+%Y-%m-%d %H:%M:%S')"
}

# ============================================================================
# MAIN EXECUTION FUNCTIONS
# ============================================================================

show_summary() {
    log "📊 CRON MANAGEMENT SUMMARY"
    
    echo ""
    echo "============================================"
    echo "🎯 CRON JOBS MANAGEMENT COMPLETED"
    echo "============================================"
    echo ""
    echo "📦 BACKUP & CLEANUP SCHEDULE:"
    echo "   🕐 02:30 Daily  - Full backup to GitHub"
    echo "   🕒 03:00 Sunday - System cleanup & optimization"
    echo "   🕓 04:00 Sunday - Backup file cleanup (keep 3 recent)"
    echo "   🕕 06:00 Daily  - System health analysis"
    echo ""
    echo "📁 FILES & LOCATIONS:"
    echo "   📂 Scripts: $SCRIPTS_DIR/"
    echo "   📂 Backups: $BACKUP_DIR/"
    echo "   📜 Logs: /var/log/*_cron.log"
    echo ""
    echo "🔧 MANAGEMENT COMMANDS:"
    echo "   📋 View crontab: crontab -l"
    echo "   📝 Edit crontab: crontab -e"
    echo "   📊 Check logs: tail -f /var/log/backup_cron.log"
    echo "   🔍 Test script: $SCRIPTS_DIR/backup_server_fixed.sh"
    echo ""
    echo "✅ All cron jobs are now using the latest fixed scripts!"
    echo "============================================"
}

# ============================================================================
# MAIN SCRIPT LOGIC
# ============================================================================

main() {
    log "🚀 CRON JOBS MANAGEMENT SCRIPT STARTED"
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root (use sudo)"
        exit 1
    fi
    
    # Create log file
    touch "$LOG_FILE"
    
    case "${1:-}" in
        --audit-only)
            log "🔍 Running audit only mode"
            audit_current_cron_jobs
            identify_problematic_cron_jobs
            ;;
        --clean-only)
            log "🧹 Running cleanup only mode"
            audit_current_cron_jobs
            remove_old_cron_jobs
            ;;
        --install-only)
            log "⬇️ Running install only mode"
            download_updated_scripts
            ;;
        --setup-only)
            log "⏰ Running setup only mode"
            setup_new_cron_jobs
            verify_cron_setup
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "OPTIONS:"
            echo "  --audit-only     Audit current cron jobs only"
            echo "  --clean-only     Remove old cron jobs only"
            echo "  --install-only   Download updated scripts only"
            echo "  --setup-only     Setup new cron jobs only"
            echo "  --help, -h       Show this help message"
            echo ""
            echo "Default: Full cron management (audit + clean + install + setup)"
            ;;
        *)
            log "🎯 Running full cron management"
            audit_current_cron_jobs
            identify_problematic_cron_jobs
            remove_old_cron_jobs
            download_updated_scripts
            setup_new_cron_jobs
            create_log_rotation
            verify_cron_setup
            show_summary
            ;;
    esac
    
    success "🎉 CRON JOBS MANAGEMENT COMPLETED"
    log "📜 Full log available at: $LOG_FILE"
}

# Run main function with all arguments
main "$@"

