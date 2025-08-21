#!/bin/bash

# ============================================================================
# FORCE FIX DPKG LOCK ERROR
# ============================================================================
# Purpose: Aggressively fix dpkg lock without waiting for automatic updates
# Approach: Immediately kill processes and remove locks
# ============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${RED}🔥 FORCE FIXING DPKG LOCK ERROR${NC}"
echo "================================"
echo -e "${YELLOW}⚠️  This will aggressively kill all package management processes${NC}"
echo ""

# Function to display status
log() { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ============================================================================
# STEP 1: IMMEDIATELY KILL ALL PACKAGE PROCESSES
# ============================================================================

force_kill_processes() {
    log "🔥 FORCE KILLING ALL PACKAGE MANAGEMENT PROCESSES"
    
    # Show what we're killing
    log "📋 Current package processes:"
    ps aux | grep -E "(apt|dpkg|unattended-upgrade)" | grep -v grep || echo "   No processes found"
    echo ""
    
    # Kill all apt-related processes immediately
    log "🔪 Killing apt processes..."
    pkill -9 -f "apt-get" 2>/dev/null || true
    pkill -9 -f "apt " 2>/dev/null || true
    pkill -9 -f "aptd" 2>/dev/null || true
    pkill -9 -f "apt.systemd.daily" 2>/dev/null || true
    
    # Kill dpkg processes
    log "🔪 Killing dpkg processes..."
    pkill -9 -f "dpkg" 2>/dev/null || true
    
    # Kill unattended upgrade processes
    log "🔪 Killing unattended-upgrade processes..."
    pkill -9 -f "unattended-upgrade" 2>/dev/null || true
    pkill -9 -f "unattended-upgrades" 2>/dev/null || true
    
    # Kill any remaining package manager processes
    log "🔪 Killing any remaining package processes..."
    pkill -9 -f "packagekit" 2>/dev/null || true
    pkill -9 -f "update-manager" 2>/dev/null || true
    
    # Wait a moment
    sleep 2
    
    success "All package management processes killed"
}

# ============================================================================
# STEP 2: REMOVE ALL LOCK FILES
# ============================================================================

remove_all_locks() {
    log "🔓 REMOVING ALL LOCK FILES"
    
    # Remove dpkg locks
    log "🗑️ Removing dpkg locks..."
    rm -f /var/lib/dpkg/lock-frontend
    rm -f /var/lib/dpkg/lock
    rm -f /var/lib/dpkg/lock-updates
    
    # Remove apt locks
    log "🗑️ Removing apt locks..."
    rm -f /var/cache/apt/archives/lock
    rm -f /var/lib/apt/lists/lock
    
    # Remove any other package manager locks
    log "🗑️ Removing other package locks..."
    rm -f /var/lib/apt/daily_lock
    rm -f /var/lib/apt/periodic/update-success-stamp
    
    success "All lock files removed"
}

# ============================================================================
# STEP 3: DISABLE AUTOMATIC UPDATES TEMPORARILY
# ============================================================================

disable_automatic_updates() {
    log "⏸️ TEMPORARILY DISABLING AUTOMATIC UPDATES"
    
    # Stop automatic update services
    systemctl stop apt-daily.timer 2>/dev/null || true
    systemctl stop apt-daily-upgrade.timer 2>/dev/null || true
    systemctl stop unattended-upgrades 2>/dev/null || true
    
    # Disable them temporarily
    systemctl disable apt-daily.timer 2>/dev/null || true
    systemctl disable apt-daily-upgrade.timer 2>/dev/null || true
    
    success "Automatic updates temporarily disabled"
}

# ============================================================================
# STEP 4: RECONFIGURE DPKG
# ============================================================================

reconfigure_dpkg() {
    log "🔧 RECONFIGURING DPKG"
    
    # Reconfigure dpkg
    DEBIAN_FRONTEND=noninteractive dpkg --configure -a
    
    success "dpkg reconfigured"
}

# ============================================================================
# STEP 5: CLEAN AND UPDATE
# ============================================================================

clean_and_update() {
    log "🧹 CLEANING AND UPDATING PACKAGE SYSTEM"
    
    # Clean apt cache
    apt clean
    
    # Update package lists
    DEBIAN_FRONTEND=noninteractive apt update
    
    success "Package system cleaned and updated"
}

# ============================================================================
# STEP 6: RE-ENABLE AUTOMATIC UPDATES
# ============================================================================

reenable_automatic_updates() {
    log "🔄 RE-ENABLING AUTOMATIC UPDATES"
    
    # Re-enable automatic update services
    systemctl enable apt-daily.timer 2>/dev/null || true
    systemctl enable apt-daily-upgrade.timer 2>/dev/null || true
    
    # Start them
    systemctl start apt-daily.timer 2>/dev/null || true
    systemctl start apt-daily-upgrade.timer 2>/dev/null || true
    
    success "Automatic updates re-enabled"
}

# ============================================================================
# STEP 7: TEST APT FUNCTIONALITY
# ============================================================================

test_apt() {
    log "🧪 TESTING APT FUNCTIONALITY"
    
    # Test apt with a simple command
    if DEBIAN_FRONTEND=noninteractive apt list --installed > /dev/null 2>&1; then
        success "✅ apt is working correctly"
        return 0
    else
        error "❌ apt is still not working"
        return 1
    fi
}

# ============================================================================
# STEP 8: SHOW PROCESS STATUS
# ============================================================================

show_process_status() {
    log "📊 CURRENT PROCESS STATUS"
    
    echo ""
    echo "📋 Package management processes:"
    ps aux | grep -E "(apt|dpkg|unattended-upgrade)" | grep -v grep || echo "   ✅ No package processes running"
    
    echo ""
    echo "🔓 Lock file status:"
    ls -la /var/lib/dpkg/lock* 2>/dev/null || echo "   ✅ No dpkg lock files"
    ls -la /var/cache/apt/archives/lock 2>/dev/null || echo "   ✅ No apt cache lock"
    ls -la /var/lib/apt/lists/lock 2>/dev/null || echo "   ✅ No apt lists lock"
    
    echo ""
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    log "🔥 Starting force dpkg lock fix..."
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root (use sudo)"
        exit 1
    fi
    
    echo -e "${YELLOW}⚠️  This will forcefully kill all package management processes${NC}"
    echo -e "${YELLOW}⚠️  and remove all lock files without waiting${NC}"
    echo ""
    read -p "Continue with force fix? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Force fix cancelled."
        exit 0
    fi
    
    # Execute aggressive fix
    force_kill_processes
    remove_all_locks
    disable_automatic_updates
    reconfigure_dpkg
    clean_and_update
    reenable_automatic_updates
    
    show_process_status
    
    if test_apt; then
        echo ""
        echo -e "${GREEN}🎉 DPKG LOCK ERROR FORCE FIXED!${NC}"
        echo ""
        echo "🎯 You can now run your restoration script:"
        echo "curl -fsSL https://raw.githubusercontent.com/vitalykirkpatrick/server-recovery-toolkit/main/scripts/one_command_restore.sh | sudo bash"
        echo ""
        echo -e "${BLUE}💡 TIP: The restoration script will now run without lock conflicts${NC}"
        echo ""
    else
        echo ""
        echo -e "${RED}❌ FORCE FIX FAILED${NC}"
        echo ""
        echo "🔧 Last resort options:"
        echo "1. Reboot the server: sudo reboot"
        echo "2. Wait 10 minutes after reboot"
        echo "3. Try the restoration script again"
        echo ""
        echo "🆘 Or try manual package installation:"
        echo "apt install -y curl wget git"
        echo ""
    fi
}

# Run main function
main "$@"

