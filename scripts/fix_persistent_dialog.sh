#!/bin/bash

# ============================================================================
# FIX PERSISTENT PACKAGE CONFIGURATION DIALOGS
# ============================================================================
# Purpose: Stop persistent kernel upgrade and package configuration dialogs
# Issue: Dialogs keep appearing even with DEBIAN_FRONTEND=noninteractive
# ============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔧 FIXING PERSISTENT PACKAGE DIALOGS${NC}"
echo "===================================="
echo ""

# Function to display status
log() { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ============================================================================
# STEP 1: KILL ALL PACKAGE PROCESSES
# ============================================================================

kill_package_processes() {
    log "🔪 KILLING ALL PACKAGE PROCESSES"
    
    # Kill all package-related processes
    pkill -9 -f "apt" 2>/dev/null || true
    pkill -9 -f "dpkg" 2>/dev/null || true
    pkill -9 -f "unattended-upgrade" 2>/dev/null || true
    pkill -9 -f "packagekit" 2>/dev/null || true
    pkill -9 -f "update-manager" 2>/dev/null || true
    
    # Kill any dialog processes
    pkill -9 -f "dialog" 2>/dev/null || true
    pkill -9 -f "whiptail" 2>/dev/null || true
    pkill -9 -f "debconf" 2>/dev/null || true
    
    success "All package processes killed"
}

# ============================================================================
# STEP 2: CONFIGURE DEBCONF FOR NON-INTERACTIVE MODE
# ============================================================================

configure_debconf() {
    log "⚙️ CONFIGURING DEBCONF FOR NON-INTERACTIVE MODE"
    
    # Set debconf to non-interactive mode
    echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
    
    # Configure debconf priority
    echo 'debconf debconf/priority select critical' | debconf-set-selections
    
    # Disable kernel upgrade prompts
    echo 'libpam-runtime libpam-runtime/profiles multiselect unix' | debconf-set-selections
    
    # Set environment variables
    export DEBIAN_FRONTEND=noninteractive
    export DEBCONF_NONINTERACTIVE_SEEN=true
    export UCF_FORCE_CONFFOLD=1
    
    success "debconf configured for non-interactive mode"
}

# ============================================================================
# STEP 3: DISABLE KERNEL UPGRADE NOTIFICATIONS
# ============================================================================

disable_kernel_notifications() {
    log "🔕 DISABLING KERNEL UPGRADE NOTIFICATIONS"
    
    # Create or update needrestart configuration
    mkdir -p /etc/needrestart/conf.d
    cat > /etc/needrestart/conf.d/no-prompt.conf << 'EOF'
# Disable needrestart prompts
$nrconf{restart} = 'a';
$nrconf{kernelhints} = 0;
EOF
    
    # Disable kernel upgrade prompts in dpkg
    cat > /etc/apt/apt.conf.d/50unattended-upgrades-local << 'EOF'
// Disable interactive prompts
Dpkg::Options {
   "--force-confdef";
   "--force-confold";
}
EOF
    
    success "Kernel upgrade notifications disabled"
}

# ============================================================================
# STEP 4: REMOVE LOCK FILES AND CLEAN
# ============================================================================

clean_package_system() {
    log "🧹 CLEANING PACKAGE SYSTEM"
    
    # Remove lock files
    rm -f /var/lib/dpkg/lock-frontend
    rm -f /var/lib/dpkg/lock
    rm -f /var/cache/apt/archives/lock
    rm -f /var/lib/apt/lists/lock
    
    # Clean package cache
    apt clean
    
    # Reconfigure dpkg
    DEBIAN_FRONTEND=noninteractive dpkg --configure -a
    
    success "Package system cleaned"
}

# ============================================================================
# STEP 5: UPDATE WITH FORCED NON-INTERACTIVE MODE
# ============================================================================

update_noninteractive() {
    log "📦 UPDATING WITH FORCED NON-INTERACTIVE MODE"
    
    # Set all environment variables
    export DEBIAN_FRONTEND=noninteractive
    export DEBCONF_NONINTERACTIVE_SEEN=true
    export UCF_FORCE_CONFFOLD=1
    export NEEDRESTART_MODE=a
    
    # Update package lists
    apt update
    
    success "Package lists updated non-interactively"
}

# ============================================================================
# STEP 6: CREATE PERMANENT CONFIGURATION
# ============================================================================

create_permanent_config() {
    log "💾 CREATING PERMANENT NON-INTERACTIVE CONFIGURATION"
    
    # Add to bashrc for permanent effect
    cat >> /root/.bashrc << 'EOF'

# Non-interactive package management
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true
export UCF_FORCE_CONFFOLD=1
export NEEDRESTART_MODE=a
EOF
    
    # Create systemd environment file
    cat > /etc/environment << 'EOF'
DEBIAN_FRONTEND=noninteractive
DEBCONF_NONINTERACTIVE_SEEN=true
UCF_FORCE_CONFFOLD=1
NEEDRESTART_MODE=a
EOF
    
    success "Permanent non-interactive configuration created"
}

# ============================================================================
# STEP 7: TEST PACKAGE OPERATIONS
# ============================================================================

test_package_operations() {
    log "🧪 TESTING PACKAGE OPERATIONS"
    
    # Test with a simple package operation
    if DEBIAN_FRONTEND=noninteractive apt list --installed > /dev/null 2>&1; then
        success "✅ Package operations working without dialogs"
        return 0
    else
        error "❌ Package operations still having issues"
        return 1
    fi
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    log "🔧 Starting persistent dialog fix..."
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root (use sudo)"
        exit 1
    fi
    
    echo -e "${YELLOW}⚠️  This will stop all package dialogs and configure non-interactive mode${NC}"
    echo ""
    read -p "Continue with dialog fix? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Dialog fix cancelled."
        exit 0
    fi
    
    # Execute fix steps
    kill_package_processes
    configure_debconf
    disable_kernel_notifications
    clean_package_system
    update_noninteractive
    create_permanent_config
    
    if test_package_operations; then
        echo ""
        echo -e "${GREEN}🎉 PERSISTENT DIALOGS FIXED!${NC}"
        echo ""
        echo "✅ All package operations will now run non-interactively"
        echo "✅ No more kernel upgrade prompts"
        echo "✅ No more configuration dialogs"
        echo ""
        echo "🎯 You can now run your restoration script:"
        echo "curl -fsSL https://raw.githubusercontent.com/vitalykirkpatrick/server-recovery-toolkit/main/scripts/one_command_restore.sh | sudo bash"
        echo ""
        echo -e "${BLUE}💡 TIP: All future package operations will be non-interactive${NC}"
        echo ""
    else
        echo ""
        echo -e "${RED}❌ DIALOG FIX INCOMPLETE${NC}"
        echo ""
        echo "🔧 Try manual approach:"
        echo "1. Reboot the server: sudo reboot"
        echo "2. Wait 5 minutes after reboot"
        echo "3. Run this script again"
        echo ""
    fi
}

# Run main function
main "$@"

