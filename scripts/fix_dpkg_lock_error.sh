#!/bin/bash

# ============================================================================
# FIX DPKG LOCK ERROR
# ============================================================================
# Purpose: Fix "dpkg frontend lock" and "apt lock" errors
# Common issue: Multiple package management processes running
# ============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔧 FIXING DPKG LOCK ERROR${NC}"
echo "=========================="
echo ""

# Function to display status
log() { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ============================================================================
# STEP 1: CHECK RUNNING PROCESSES
# ============================================================================

check_running_processes() {
    log "🔍 Checking for running package management processes..."
    
    # Check for apt processes
    local apt_processes=$(ps aux | grep -E "(apt|dpkg|unattended-upgrade)" | grep -v grep)
    
    if [ -n "$apt_processes" ]; then
        warning "Found running package management processes:"
        echo "$apt_processes"
        echo ""
    else
        success "No running package management processes found"
    fi
}

# ============================================================================
# STEP 2: WAIT FOR AUTOMATIC UPDATES TO FINISH
# ============================================================================

wait_for_automatic_updates() {
    log "⏳ Waiting for automatic updates to finish..."
    
    # Wait for unattended-upgrades to finish
    local attempts=0
    local max_attempts=30
    
    while [ $attempts -lt $max_attempts ]; do
        if ! pgrep -f "unattended-upgrade" > /dev/null; then
            success "Automatic updates finished"
            return 0
        fi
        
        log "   Waiting for automatic updates... ($((attempts + 1))/$max_attempts)"
        sleep 10
        attempts=$((attempts + 1))
    done
    
    warning "Automatic updates still running after 5 minutes, proceeding with force cleanup"
}

# ============================================================================
# STEP 3: KILL HANGING PROCESSES
# ============================================================================

kill_hanging_processes() {
    log "🔪 Killing hanging package management processes..."
    
    # Kill apt processes
    pkill -f "apt" 2>/dev/null || true
    pkill -f "dpkg" 2>/dev/null || true
    pkill -f "unattended-upgrade" 2>/dev/null || true
    
    # Wait a moment
    sleep 3
    
    # Force kill if still running
    pkill -9 -f "apt" 2>/dev/null || true
    pkill -9 -f "dpkg" 2>/dev/null || true
    pkill -9 -f "unattended-upgrade" 2>/dev/null || true
    
    success "Package management processes killed"
}

# ============================================================================
# STEP 4: REMOVE LOCK FILES
# ============================================================================

remove_lock_files() {
    log "🔓 Removing lock files..."
    
    # Remove dpkg lock files
    rm -f /var/lib/dpkg/lock-frontend
    rm -f /var/lib/dpkg/lock
    rm -f /var/cache/apt/archives/lock
    rm -f /var/lib/apt/lists/lock
    
    success "Lock files removed"
}

# ============================================================================
# STEP 5: RECONFIGURE DPKG
# ============================================================================

reconfigure_dpkg() {
    log "🔧 Reconfiguring dpkg..."
    
    # Reconfigure dpkg
    dpkg --configure -a
    
    success "dpkg reconfigured"
}

# ============================================================================
# STEP 6: UPDATE PACKAGE LISTS
# ============================================================================

update_package_lists() {
    log "📦 Updating package lists..."
    
    # Update package lists
    apt update
    
    success "Package lists updated"
}

# ============================================================================
# STEP 7: TEST APT FUNCTIONALITY
# ============================================================================

test_apt_functionality() {
    log "🧪 Testing apt functionality..."
    
    # Test apt with a simple command
    if apt list --installed > /dev/null 2>&1; then
        success "apt is working correctly"
        return 0
    else
        error "apt is still not working"
        return 1
    fi
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    log "🔧 Starting dpkg lock fix..."
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root (use sudo)"
        exit 1
    fi
    
    # Execute fix steps
    check_running_processes
    wait_for_automatic_updates
    kill_hanging_processes
    remove_lock_files
    reconfigure_dpkg
    update_package_lists
    
    if test_apt_functionality; then
        echo ""
        echo -e "${GREEN}✅ DPKG LOCK ERROR FIXED!${NC}"
        echo ""
        echo "🎯 You can now run your restoration script:"
        echo "curl -fsSL https://raw.githubusercontent.com/vitalykirkpatrick/server-recovery-toolkit/main/scripts/one_command_restore.sh | sudo bash"
        echo ""
    else
        echo ""
        echo -e "${RED}❌ DPKG LOCK ERROR PERSISTS${NC}"
        echo ""
        echo "🔧 Try these manual steps:"
        echo "1. Reboot the server: sudo reboot"
        echo "2. Wait 5 minutes after reboot"
        echo "3. Run the restoration script again"
        echo ""
    fi
}

# Run main function
main "$@"

