#!/bin/bash
set -euo pipefail

TOOL_NAME="drupal-setup"
TOOL_VERSION="1.1.0"

SITE_NAME="${SITE_NAME:-Drupal 11 Dev}"
ADMIN_PASS="${ADMIN_PASS:-drupal123}"
DDEV_PORT="${DDEV_PORT:-61848}"
DDEV_PROJECT_NAME="${DDEV_PROJECT_NAME:-agent-tools-drupal}"

MACHINE_OUTPUT="${MACHINE_OUTPUT:-false}"
VERBOSE="${VERBOSE:-false}"
SKIP_PROMPTS="${SKIP_PROMPTS:-true}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$TOOL_DIR/../../.." && pwd)}"
DRUPAL_ROOT="${TOOL_SHARED_ROOT:-$PROJECT_ROOT/workspace/$TOOL_NAME}"

STATE_FILE="$DRUPAL_ROOT/.setup_state"

log() {
    local level="$1"
    shift
    local msg="[$(date '+%H:%M:%S')] [$level] $*"
    if [ "$MACHINE_OUTPUT" = "true" ]; then
        echo "{\"time\":\"$(date -Iseconds)\",\"level\":\"$level\",\"message\":\"$*\"}"
    else
        echo "$msg"
    fi
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }
log_success() { log "SUCCESS" "$@"; }
log_debug() { [ "$VERBOSE" = "true" ] && log "DEBUG" "$@" || true; }

section() {
    log_info "========================================"
    log_info "$@"
    log_info "========================================"
}

check_prerequisites() {
    section "[1/10] Prerequisites"

    if ! command -v ddev &>/dev/null; then
        log_error "DDEV is not installed"
        log_error "Install from: https://ddev.readthedocs.io/en/stable/#installation"
        log_error "Or run: brew install ddev/ddev/ddev (macOS)"
        return 1
    fi
    log_success "DDEV installed: $(ddev --version 2>/dev/null | head -1)"

    if ! docker info &>/dev/null 2>&1; then
        log_error "Docker is not running"
        log_error "Start Docker Desktop or Docker daemon and try again"
        return 1
    fi
    log_success "Docker running"

    local ddev_version=$(ddev --version 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+' | head -1 | tr -d 'v')
    if [ -n "$ddev_version" ]; then
        local major=$(echo "$ddev_version" | cut -d. -f1)
        local minor=$(echo "$ddev_version" | cut -d. -f2)
        if [ "$major" -lt 1 ] || { [ "$major" -eq 1 ] && [ "$minor" -lt 23 ]; }; then
            log_warn "DDEV version $ddev_version detected. Consider upgrading to v1.23+ for best compatibility"
        fi
    fi

    return 0
}

handle_ddev_config() {
    section "[2/10] DDEV Configuration"

    mkdir -p "$DRUPAL_ROOT/.ddev"
    mkdir -p "$DRUPAL_ROOT/web"

    cd "$DRUPAL_ROOT"

    if [ -f .ddev/config.yaml ]; then
        local config_project_root=$(grep -o 'project_root:.*' .ddev/config.yaml 2>/dev/null | sed 's/project_root: *//' || true)
        local config_project_name=$(grep -o '^name:.*' .ddev/config.yaml 2>/dev/null | sed 's/name: *//' || true)
        
        if [ -n "$config_project_root" ] && [ "$config_project_root" != "$DRUPAL_ROOT" ]; then
            log_warn "Found stale config.yaml with mismatched project_root"
            log_warn "Expected: $DRUPAL_ROOT"
            log_warn "Found: $config_project_root"
            log_info "Removing stale config..."
            rm -f .ddev/config.yaml
        elif [ -n "$config_project_name" ] && [ "$config_project_name" != "$DDEV_PROJECT_NAME" ]; then
            log_warn "Found stale config.yaml with mismatched project_name"
            log_warn "Expected: $DDEV_PROJECT_NAME"
            log_warn "Found: $config_project_name"
            log_info "Removing stale config..."
            rm -f .ddev/config.yaml
        else
            log_info "Using existing DDEV config"
        fi
    fi

    if [ ! -f .ddev/config.yaml ]; then
        log_info "Creating DDEV config..."
        local config_output
        local config_exit=0
        config_output=$(ddev config \
            --project-name="$DDEV_PROJECT_NAME" \
            --project-type=drupal11 \
            --docroot=web \
            --host-webserver-port="$DDEV_PORT" 2>&1) || config_exit=$?
        
        if [ "$config_exit" -ne 0 ]; then
            if echo "$config_output" | grep -q "project root is already set to"; then
                local conflict_path=$(echo "$config_output" | grep "project root is already set to" | sed 's/.*project root is already set to \([^,]*\),.*/\1/')
                log_warn "Project '$DDEV_PROJECT_NAME' already registered at: $conflict_path"
                log_info "Unlisting old project..."
                ddev stop --unlist "$DDEV_PROJECT_NAME" 2>/dev/null || true
                
                config_exit=0
                config_output=$(ddev config \
                    --project-name="$DDEV_PROJECT_NAME" \
                    --project-type=drupal11 \
                    --docroot=web \
                    --host-webserver-port="$DDEV_PORT" 2>&1) || config_exit=$?
                
                if [ "$config_exit" -ne 0 ]; then
                    log_error "Failed to create DDEV config after cleanup"
                    log_error "$config_output"
                    return 1
                fi
            else
                log_error "Failed to create DDEV config"
                log_error "$config_output"
                return 1
            fi
        fi
        log_success "DDEV config created"
    fi

    return 0
}

start_ddev_containers() {
    section "[3/10] Starting DDEV Containers"
    
    if ddev describe "$DDEV_PROJECT_NAME" &>/dev/null; then
        local status=$(ddev describe "$DDEV_PROJECT_NAME" 2>/dev/null | grep -E "web.*OK" | head -1 | grep -oE 'OK|stopped|running' || echo "unknown")
        if [ "$status" = "OK" ]; then
            log_info "DDEV project already running"
            return 0
        fi
    fi
    
    log_info "This may take a few minutes on first run..."
    
    if ! ddev start -y 2>&1; then
        log_warn "DDEV start had issues - checking if project is usable..."
        if ddev describe "$DDEV_PROJECT_NAME" &>/dev/null; then
            log_info "Project appears to be running despite warnings"
            return 0
        fi
        log_error "Failed to start DDEV containers"
        log_error "Try running 'ddev restart' manually to see detailed errors"
        return 1
    fi
    
    log_success "DDEV containers started"
    return 0
}

scaffold_drupal() {
    section "[4/10] Scaffolding Drupal 11"
    
    if [ -f web/core/install.php ]; then
        log_info "Drupal core already scaffolded"
    else
        log_info "Creating Drupal project (this may take a while)..."
        if ! ddev composer create-project "drupal/recommended-project:^11" . --no-install --no-interaction 2>&1; then
            log_error "Failed to scaffold Drupal"
            log_error "Check internet connection and Docker resources"
            return 1
        fi
        log_success "Drupal scaffolded"
    fi
    
    return 0
}

install_dependencies() {
    section "[5/10] Installing Dependencies"
    
    log_info "Installing Composer dependencies..."
    if ! ddev composer install --no-interaction 2>&1; then
        log_error "Failed to install Composer dependencies"
        return 1
    fi
    log_success "Base dependencies installed"
    
    log_info "Installing Drush..."
    if ! ddev composer require --dev drush/drush --no-interaction 2>&1; then
        log_error "Failed to install Drush"
        return 1
    fi
    log_success "Drush installed"
    
    return 0
}

install_drupal() {
    section "[6/10] Installing Drupal"
    
    local db_status
    db_status=$(ddev drush status 2>/dev/null | grep 'Database.*Connected' || true)
    if [ -n "$db_status" ]; then
        log_info "Drupal already installed and database connected"
        return 0
    fi
    
    if [ ! -f web/core/install.php ]; then
        log_error "Drupal core not found at web/core/install.php"
        return 1
    fi
    
    log_info "Running Drupal installation..."
    if ! ddev drush site:install standard \
        --account-name=admin \
        --account-pass="$ADMIN_PASS" \
        --site-name="$SITE_NAME" \
        -y 2>&1; then
        log_error "Failed to install Drupal"
        log_error "Check database credentials and configuration"
        return 1
    fi
    log_success "Drupal installed"
    
    return 0
}

install_modules() {
    section "[7/10] Installing Modules"
    
    local modules="drupal/admin_toolbar drupal/admin_toolbar_tools drupal/devel drupal/pathauto drupal/metatag drupal/token drupal/honeypot"
    
    log_info "Installing modules..."
    if ! ddev composer require $modules --no-interaction 2>&1; then
        log_warn "Some modules may already be installed or have issues"
    fi
    
    log_info "Enabling modules..."
    if ! ddev drush pm:enable admin_toolbar admin_toolbar_tools devel pathauto metatag token honeypot -y 2>&1; then
        log_warn "Some modules may already be enabled"
    fi
    log_success "Modules processed"
    
    return 0
}

install_themes() {
    section "[8/10] Installing Themes"
    
    log_info "Installing themes..."
    if ! ddev composer require --dev drupal/stable drupal/classy --no-interaction 2>&1; then
        log_warn "Themes may already be installed"
    fi
    
    log_info "Enabling themes..."
    if ! ddev drush theme:enable stable classy -y 2>&1; then
        log_warn "Themes may already be enabled"
    fi
    log_success "Themes processed"
    
    return 0
}

configure_honeypot() {
    section "[9/10] Configuring Honeypot"
    
    log_info "Configuring honeypot anti-spam..."
    
    local honeypot_status
    honeypot_status=$(ddev drush pm:list --status=enabled 2>/dev/null | grep -i "honeypot" || echo "")
    if [ -n "$honeypot_status" ]; then
        ddev drush config:set honeypot.settings enabled true -y 2>&1 || log_warn "Could not enable honeypot"
        ddev drush config:set honeypot.settings element_name 'url' -y 2>&1 || log_warn "Could not set honeypot element name"
        log_success "Honeypot configured"
    else
        log_warn "Honeypot module not enabled - skipping configuration"
    fi
    
    return 0
}

finalize() {
    section "[10/10] Finalizing"
    
    log_info "Clearing cache..."
    ddev drush cr 2>&1 || log_warn "Cache clear had issues"
    
    log_info "Exporting configuration..."
    ddev exec -- mkdir -p /var/www/html/web/sites/default/files/sync 2>/dev/null || true
    ddev drush cex -y 2>&1 || log_warn "Config export had issues"
    
    local site_url="http://127.0.0.1:$DDEV_PORT"
    local admin_url
    admin_url=$(ddev drush uli 2>/dev/null | tail -1) || admin_url="(run 'ddev drush uli' to generate)"
    
    echo ""
    log_success "=========================================="
    log_success "SETUP COMPLETE!"
    log_success "=========================================="
    echo ""
    log_info "Drupal files: $DRUPAL_ROOT"
    log_info "Site URL: $site_url"
    log_info "Admin user: admin"
    log_info "Admin pass: $ADMIN_PASS"
    log_info "Admin login: $admin_url"
    echo ""
    
    return 0
}

main() {
    echo ""
    log_info "=========================================="
    log_info "Drupal Setup Tool v$TOOL_VERSION"
    log_info "=========================================="
    log_info "Machine output: $MACHINE_OUTPUT"
    log_info "Verbose: $VERBOSE"
    log_info "Drupal root: $DRUPAL_ROOT"
    echo ""
    
    if ! check_prerequisites; then
        log_error "Prerequisites check failed"
        log_error "Fix the issues above and run again"
        exit 1
    fi
    
    if ! handle_ddev_config; then
        log_error "DDEV configuration failed"
        exit 1
    fi
    
    if ! start_ddev_containers; then
        log_error "Failed to start DDEV containers"
        exit 1
    fi
    
    if ! scaffold_drupal; then
        log_error "Drupal scaffolding failed"
        exit 1
    fi
    
    if ! install_dependencies; then
        log_error "Dependency installation failed"
        exit 1
    fi
    
    if ! install_drupal; then
        log_error "Drupal installation failed"
        exit 1
    fi
    
    if ! install_modules; then
        log_error "Module installation failed"
        exit 1
    fi
    
    if ! install_themes; then
        log_error "Theme installation failed"
        exit 1
    fi
    
    if ! configure_honeypot; then
        log_warn "Honeypot configuration had warnings"
    fi
    
    if ! finalize; then
        log_error "Finalization had warnings"
    fi
    
    log_success "All steps completed"
    exit 0
}

main "$@"
