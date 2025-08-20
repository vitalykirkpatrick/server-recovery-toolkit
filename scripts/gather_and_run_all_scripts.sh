#!/bin/bash

# ============================================================================
# GATHER AND RUN ALL SCRIPTS FROM GITHUB REPOSITORY
# ============================================================================
# Purpose: Download all shell scripts from GitHub and run them on server
# Use: Automatically deploy and execute all backup, cleanup, and management scripts
# Repository: https://github.com/vitalykirkpatrick/server-recovery-toolkit
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
GITHUB_REPO="https://github.com/vitalykirkpatrick/server-recovery-toolkit.git"
SCRIPTS_DIR="/root/scripts"
TEMP_DIR="/tmp/github_scripts_deploy"
LOG_FILE="/var/log/github_scripts_deploy.log"

# Logging functions
log() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"; }
info() { echo -e "${CYAN}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }

echo "📥 GATHER AND RUN ALL SCRIPTS FROM GITHUB"
echo "========================================="
echo "🎯 This will download and run all shell scripts from your repository"
echo "📂 Repository: $GITHUB_REPO"
echo ""

# ============================================================================
# CLONE REPOSITORY AND GATHER SCRIPTS
# ============================================================================

clone_and_gather_scripts() {
    log "📥 CLONING REPOSITORY AND GATHERING SCRIPTS"
    
    # Clean up any existing temp directory
    rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR"
    
    # Clone the repository
    cd "$TEMP_DIR"
    git clone "$GITHUB_REPO" .
    success "Repository cloned successfully"
    
    # Find all shell scripts
    local all_scripts=($(find . -name "*.sh" -type f | sort))
    
    if [ ${#all_scripts[@]} -eq 0 ]; then
        error "❌ No shell scripts found in repository"
        return 1
    fi
    
    log "📂 Found ${#all_scripts[@]} shell scripts:"
    for script in "${all_scripts[@]}"; do
        log "   📄 $script"
    done
    
    # Create scripts directory on server
    mkdir -p "$SCRIPTS_DIR"
    
    # Copy all scripts to server
    for script in "${all_scripts[@]}"; do
        local script_name=$(basename "$script")
        cp "$script" "$SCRIPTS_DIR/$script_name"
        chmod +x "$SCRIPTS_DIR/$script_name"
        success "✅ Copied and made executable: $script_name"
    done
    
    success "All scripts gathered and prepared"
}

# ============================================================================
# CATEGORIZE SCRIPTS BY TYPE
# ============================================================================

categorize_scripts() {
    log "📋 CATEGORIZING SCRIPTS BY TYPE"
    
    cd "$SCRIPTS_DIR"
    
    # Define script categories with execution order
    declare -A script_categories
    script_categories[setup]=""
    script_categories[backup]=""
    script_categories[cleanup]=""
    script_categories[cron]=""
    script_categories[fix]=""
    script_categories[emergency]=""
    script_categories[other]=""
    
    # Categorize scripts based on filename patterns
    for script in *.sh; do
        if [[ ! -f "$script" ]]; then
            continue
        fi
        
        case "$script" in
            *setup*|*install*|*fresh*)
                script_categories[setup]+="$script "
                ;;
            *backup*)
                script_categories[backup]+="$script "
                ;;
            *cleanup*|*clean*)
                script_categories[cleanup]+="$script "
                ;;
            *cron*|*schedule*)
                script_categories[cron]+="$script "
                ;;
            *fix*|*repair*)
                script_categories[fix]+="$script "
                ;;
            *emergency*|*vnc*|*recovery*)
                script_categories[emergency]+="$script "
                ;;
            *)
                script_categories[other]+="$script "
                ;;
        esac
    done
    
    # Display categorization
    for category in setup backup cleanup cron fix emergency other; do
        if [[ -n "${script_categories[$category]}" ]]; then
            log "📁 $category scripts: ${script_categories[$category]}"
        fi
    done
}

# ============================================================================
# RUN SETUP SCRIPTS
# ============================================================================

run_setup_scripts() {
    log "🚀 RUNNING SETUP SCRIPTS"
    
    cd "$SCRIPTS_DIR"
    local setup_scripts=($(ls *setup*.sh *install*.sh *fresh*.sh 2>/dev/null || true))
    
    if [ ${#setup_scripts[@]} -eq 0 ]; then
        log "ℹ️ No setup scripts found"
        return 0
    fi
    
    for script in "${setup_scripts[@]}"; do
        log "🔧 Running setup script: $script"
        
        # Ask for confirmation for setup scripts (they might be destructive)
        echo ""
        warning "⚠️ About to run setup script: $script"
        warning "⚠️ Setup scripts may make significant system changes"
        read -p "Run this setup script? (y/N): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if ./"$script"; then
                success "✅ Setup script completed: $script"
            else
                error "❌ Setup script failed: $script"
            fi
        else
            warning "⏭️ Skipped setup script: $script"
        fi
    done
}

# ============================================================================
# RUN BACKUP SCRIPTS
# ============================================================================

run_backup_scripts() {
    log "💾 RUNNING BACKUP SCRIPTS"
    
    cd "$SCRIPTS_DIR"
    local backup_scripts=($(ls *backup*.sh 2>/dev/null || true))
    
    if [ ${#backup_scripts[@]} -eq 0 ]; then
        log "ℹ️ No backup scripts found"
        return 0
    fi
    
    for script in "${backup_scripts[@]}"; do
        log "💾 Running backup script: $script"
        
        if ./"$script"; then
            success "✅ Backup script completed: $script"
        else
            error "❌ Backup script failed: $script"
        fi
    done
}

# ============================================================================
# RUN CLEANUP SCRIPTS
# ============================================================================

run_cleanup_scripts() {
    log "🧹 RUNNING CLEANUP SCRIPTS"
    
    cd "$SCRIPTS_DIR"
    local cleanup_scripts=($(ls *cleanup*.sh *clean*.sh 2>/dev/null || true))
    
    if [ ${#cleanup_scripts[@]} -eq 0 ]; then
        log "ℹ️ No cleanup scripts found"
        return 0
    fi
    
    for script in "${cleanup_scripts[@]}"; do
        log "🧹 Running cleanup script: $script"
        
        if ./"$script"; then
            success "✅ Cleanup script completed: $script"
        else
            error "❌ Cleanup script failed: $script"
        fi
    done
}

# ============================================================================
# RUN CRON MANAGEMENT SCRIPTS
# ============================================================================

run_cron_scripts() {
    log "📅 RUNNING CRON MANAGEMENT SCRIPTS"
    
    cd "$SCRIPTS_DIR"
    local cron_scripts=($(ls *cron*.sh *schedule*.sh 2>/dev/null || true))
    
    if [ ${#cron_scripts[@]} -eq 0 ]; then
        log "ℹ️ No cron management scripts found"
        return 0
    fi
    
    for script in "${cron_scripts[@]}"; do
        log "📅 Running cron script: $script"
        
        if ./"$script"; then
            success "✅ Cron script completed: $script"
        else
            error "❌ Cron script failed: $script"
        fi
    done
}

# ============================================================================
# RUN FIX SCRIPTS (OPTIONAL)
# ============================================================================

run_fix_scripts() {
    log "🔧 RUNNING FIX SCRIPTS (OPTIONAL)"
    
    cd "$SCRIPTS_DIR"
    local fix_scripts=($(ls *fix*.sh *repair*.sh 2>/dev/null || true))
    
    if [ ${#fix_scripts[@]} -eq 0 ]; then
        log "ℹ️ No fix scripts found"
        return 0
    fi
    
    echo ""
    warning "⚠️ Fix scripts are available but not run automatically"
    warning "⚠️ These should only be run if you have specific issues"
    log "🔧 Available fix scripts:"
    
    for script in "${fix_scripts[@]}"; do
        log "   📄 $script"
    done
    
    echo ""
    read -p "Do you want to run fix scripts? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        for script in "${fix_scripts[@]}"; do
            echo ""
            warning "⚠️ About to run fix script: $script"
            read -p "Run this fix script? (y/N): " -n 1 -r
            echo
            
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                log "🔧 Running fix script: $script"
                if ./"$script"; then
                    success "✅ Fix script completed: $script"
                else
                    error "❌ Fix script failed: $script"
                fi
            else
                warning "⏭️ Skipped fix script: $script"
            fi
        done
    else
        log "ℹ️ Fix scripts skipped"
    fi
}

# ============================================================================
# CREATE SCRIPT MANAGEMENT MENU
# ============================================================================

create_script_menu() {
    log "📋 CREATING SCRIPT MANAGEMENT MENU"
    
    cat > "$SCRIPTS_DIR/run_script_menu.sh" << 'EOF'
#!/bin/bash

# Script Management Menu
SCRIPTS_DIR="/root/scripts"

echo "📋 SCRIPT MANAGEMENT MENU"
echo "========================="
echo ""

cd "$SCRIPTS_DIR"

# List all available scripts
echo "📂 Available scripts:"
ls -la *.sh | awk '{print "   " $9 " (" $5 " bytes, " $6 " " $7 " " $8 ")"}'
echo ""

# Interactive menu
while true; do
    echo "🎯 What would you like to do?"
    echo "1) Run backup scripts"
    echo "2) Run cleanup scripts"
    echo "3) Run cron management scripts"
    echo "4) Run fix scripts"
    echo "5) Run specific script"
    echo "6) List all scripts"
    echo "7) Exit"
    echo ""
    read -p "Choose option (1-7): " choice
    
    case $choice in
        1)
            echo "💾 Running backup scripts..."
            for script in *backup*.sh; do
                if [[ -f "$script" ]]; then
                    echo "Running: $script"
                    ./"$script"
                fi
            done
            ;;
        2)
            echo "🧹 Running cleanup scripts..."
            for script in *cleanup*.sh *clean*.sh; do
                if [[ -f "$script" ]]; then
                    echo "Running: $script"
                    ./"$script"
                fi
            done
            ;;
        3)
            echo "📅 Running cron management scripts..."
            for script in *cron*.sh *schedule*.sh; do
                if [[ -f "$script" ]]; then
                    echo "Running: $script"
                    ./"$script"
                fi
            done
            ;;
        4)
            echo "🔧 Available fix scripts:"
            ls *fix*.sh *repair*.sh 2>/dev/null || echo "No fix scripts found"
            echo ""
            read -p "Enter script name to run (or press Enter to skip): " script_name
            if [[ -n "$script_name" && -f "$script_name" ]]; then
                ./"$script_name"
            fi
            ;;
        5)
            echo "📄 Available scripts:"
            ls *.sh
            echo ""
            read -p "Enter script name to run: " script_name
            if [[ -f "$script_name" ]]; then
                ./"$script_name"
            else
                echo "Script not found: $script_name"
            fi
            ;;
        6)
            echo "📂 All scripts:"
            ls -la *.sh
            ;;
        7)
            echo "👋 Goodbye!"
            exit 0
            ;;
        *)
            echo "❌ Invalid option. Please choose 1-7."
            ;;
    esac
    echo ""
done
EOF
    
    chmod +x "$SCRIPTS_DIR/run_script_menu.sh"
    success "Script management menu created: $SCRIPTS_DIR/run_script_menu.sh"
}

# ============================================================================
# SHOW DEPLOYMENT SUMMARY
# ============================================================================

show_deployment_summary() {
    log "📊 DEPLOYMENT SUMMARY"
    
    cd "$SCRIPTS_DIR"
    local total_scripts=$(ls *.sh 2>/dev/null | wc -l)
    
    echo ""
    echo "============================================"
    echo "📥 GITHUB SCRIPTS DEPLOYMENT COMPLETED"
    echo "============================================"
    echo ""
    echo "📊 DEPLOYMENT STATISTICS:"
    echo "   📂 Total scripts downloaded: $total_scripts"
    echo "   📁 Scripts directory: $SCRIPTS_DIR"
    echo "   📜 Log file: $LOG_FILE"
    echo ""
    echo "📋 SCRIPT CATEGORIES:"
    
    # Count scripts by category
    local setup_count=$(ls *setup*.sh *install*.sh *fresh*.sh 2>/dev/null | wc -l)
    local backup_count=$(ls *backup*.sh 2>/dev/null | wc -l)
    local cleanup_count=$(ls *cleanup*.sh *clean*.sh 2>/dev/null | wc -l)
    local cron_count=$(ls *cron*.sh *schedule*.sh 2>/dev/null | wc -l)
    local fix_count=$(ls *fix*.sh *repair*.sh 2>/dev/null | wc -l)
    local emergency_count=$(ls *emergency*.sh *vnc*.sh *recovery*.sh 2>/dev/null | wc -l)
    
    echo "   🚀 Setup scripts: $setup_count"
    echo "   💾 Backup scripts: $backup_count"
    echo "   🧹 Cleanup scripts: $cleanup_count"
    echo "   📅 Cron scripts: $cron_count"
    echo "   🔧 Fix scripts: $fix_count"
    echo "   🚨 Emergency scripts: $emergency_count"
    echo ""
    echo "🎯 WHAT WAS EXECUTED:"
    echo "   ✅ Setup scripts (if confirmed)"
    echo "   ✅ Backup scripts"
    echo "   ✅ Cleanup scripts"
    echo "   ✅ Cron management scripts"
    echo "   ⏭️ Fix scripts (skipped unless requested)"
    echo ""
    echo "📋 SCRIPT MANAGEMENT:"
    echo "   🎮 Interactive menu: $SCRIPTS_DIR/run_script_menu.sh"
    echo "   📂 All scripts in: $SCRIPTS_DIR/"
    echo "   🔧 Run individual scripts: cd $SCRIPTS_DIR && ./script_name.sh"
    echo ""
    echo "🔄 FUTURE UPDATES:"
    echo "   📥 Re-run this script to get latest versions"
    echo "   🔄 Scripts are automatically updated from GitHub"
    echo ""
    echo "✅ ALL SCRIPTS DEPLOYED AND EXECUTED!"
    echo "============================================"
}

# ============================================================================
# CLEANUP TEMPORARY FILES
# ============================================================================

cleanup_temp_files() {
    log "🧹 CLEANING UP TEMPORARY FILES"
    
    # Remove temporary directory
    rm -rf "$TEMP_DIR"
    success "Temporary files cleaned up"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    log "📥 GITHUB SCRIPTS DEPLOYMENT STARTED"
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root (use sudo)"
        exit 1
    fi
    
    # Create log file
    touch "$LOG_FILE"
    
    echo "⚠️  This will download and run scripts from GitHub repository"
    echo "🎯 Repository: $GITHUB_REPO"
    echo ""
    read -p "Continue with script deployment? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Script deployment cancelled."
        exit 0
    fi
    
    # Execute deployment
    clone_and_gather_scripts
    categorize_scripts
    run_setup_scripts
    run_backup_scripts
    run_cleanup_scripts
    run_cron_scripts
    run_fix_scripts
    create_script_menu
    show_deployment_summary
    cleanup_temp_files
    
    success "🎉 GITHUB SCRIPTS DEPLOYMENT COMPLETED"
    log "📜 Full log available at: $LOG_FILE"
    
    echo ""
    echo "🎮 To manage scripts interactively:"
    echo "   cd $SCRIPTS_DIR && ./run_script_menu.sh"
}

# Run main function
main "$@"

