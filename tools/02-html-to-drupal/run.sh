#!/bin/bash
#===============================================================================
# Tool run.sh - Fixed Interface Harness for html-to-drupal tool
#
# DO NOT MODIFY THIS FILE - This is the fixed interface for ALL tools.
# Each tool's specific logic goes in scripts/*.sh
#
# Interface (MUST match exactly):
#   ./run.sh run [STATIC_HTML_FOLDER]   - Execute the tool
#   ./run.sh query [type]                - Query tool state
#   ./run.sh verify                      - Self-verification
#   ./run.sh help                        - Show help
#
# Exit Codes:
#   0       - Success
#   E001    - Invalid input
#   E002    - Tool not ready
#   E003    - Dependency missing
#   E004    - Execution failed
#   E005    - Permission denied (LIMITS violation)
#===============================================================================

set -e

# Exit code mappings (per tool-spec)
E001=1
E002=2
E003=3
E004=4
E005=5

# Tool metadata
TOOL_NAME="html-to-drupal"
TOOL_VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Standard environment variables (from tool-spec)
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TOOL_SHARED_ROOT="$PROJECT_ROOT/workspace/$TOOL_NAME"
LOG_DIR="$TOOL_SHARED_ROOT/logs"

# Colors for output (disabled if not terminal)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

show_help() {
    cat << EOF
${BLUE}Tool: html-to-drupal${NC}
${BLUE}Version: ${TOOL_VERSION}${NC}

Analyzes static HTML and creates Drupal 11 site with content types, blocks, and templates.

${GREEN}Usage:${NC}
    ./run.sh <command> [options]

${GREEN}Commands:${NC}
    run         Execute HTML analysis and Drupal creation
    query       Query tool state (health|status|state|...)
    verify      Self-verification
    help        Show this help

${GREEN}Run Options:${NC}
    STATIC_HTML_FOLDER   Path to folder containing index.html (required)
                          If not provided, will prompt interactively
    --opencode-session   OpenCode session name (default: html-analysis)
    --theme-name         Drupal theme name (default: nci_theme)
    --content-type       Content type name (default: cancer_content)
    --drupal-setup      Path to drupal-setup tool (default: ../01-drupal-setup)

${GREEN}Query Options:${NC}
    health              Health check
    status              Current status (ready|busy|error|not_ready)
    state               Full state dump
    layout_json         Path to generated layout.json
    theme               Theme name
    content_type        Content type name
    blocks              List of created blocks
    site_url            Drupal site URL
    dependencies        Required/optional dependencies

${GREEN}Examples:${NC}
    ./run.sh run /path/to/nci
    ./run.sh run /path/to/nci --theme-name=my_theme
    ./run.sh run --opencode-session=my-session
    ./run.sh query health
    ./run.sh query state
    ./run.sh verify

${GREEN}Interactive Mode:${NC}
    If STATIC_HTML_FOLDER is not provided, tool will prompt:
    - Enter path to static HTML folder

${GREEN}Files:${NC}
    SPEC.md   - Tool specification
    LIMITS.md - Prohibited operations
    QUERY.md  - Query protocol docs

EOF
}

verify_prerequisites() {
    if [ ! -d "$SCRIPT_DIR/scripts" ]; then
        log_error "Missing scripts/ directory"
        exit $E004
    fi
    for script in setup.sh verify.sh query.sh; do
        if [ ! -f "$SCRIPT_DIR/scripts/$script" ]; then
            log_error "Missing scripts/$script"
            exit $E004
        fi
    done
    log_success "Prerequisites verified"
}

prompt_static_html_folder() {
    echo ""
    echo "Enter the path to your static HTML folder (containing index.html):"
    echo -n "  Path: "
    read -r STATIC_HTML_FOLDER
    
    if [ -z "$STATIC_HTML_FOLDER" ]; then
        log_error "Static HTML folder is required"
        exit $E001
    fi
    
    if [ ! -d "$STATIC_HTML_FOLDER" ]; then
        log_error "Directory not found: $STATIC_HTML_FOLDER"
        exit $E001
    fi
    
    INDEX_FILE="$STATIC_HTML_FOLDER/index.html"
    if [ ! -f "$INDEX_FILE" ]; then
        INDEX_FILE="$STATIC_HTML_FOLDER/index.htm"
        if [ ! -f "$INDEX_FILE" ]; then
            log_error "No index.html or index.htm found"
            exit $E001
        fi
    fi
    
    export STATIC_HTML_FOLDER
}

main() {
    mkdir -p "$LOG_DIR"
    mkdir -p "$TOOL_SHARED_ROOT"

    case "$1" in
        run)
            shift
            while [ -n "$1" ]; do
                case "$1" in
                    --opencode-session) export OPENCODE_SESSION_NAME="$2"; shift 2 ;;
                    --theme-name) export THEME_NAME="$2"; shift 2 ;;
                    --content-type) export CONTENT_TYPE_NAME="$2"; shift 2 ;;
                    --drupal-setup) export DRUPAL_SETUP_TOOL="$2"; shift 2 ;;
                    --help|-h) show_help; exit 0 ;;
                    -*) log_error "Unknown option: $1"; exit $E001 ;;
                    *) export STATIC_HTML_FOLDER="$1"; shift ;;
                esac
            done
            
            export OPENCODE_SESSION_NAME="${OPENCODE_SESSION_NAME:-html-analysis}"
            export THEME_NAME="${THEME_NAME:-nci_theme}"
            export CONTENT_TYPE_NAME="${CONTENT_TYPE_NAME:-cancer_content}"
            export DRUPAL_SETUP_TOOL="${DRUPAL_SETUP_TOOL:-$PROJECT_ROOT/tools/01-drupal-setup}"
            
            if [ -z "$STATIC_HTML_FOLDER" ]; then
                prompt_static_html_folder
            fi
            
            log_info "Executing $TOOL_NAME..."
            bash "$SCRIPT_DIR/scripts/setup.sh"
            ;;
        query)
            shift
            bash "$SCRIPT_DIR/scripts/query.sh" "$@"
            ;;
        verify)
            log_info "Running self-verification..."
            bash "$SCRIPT_DIR/scripts/verify.sh"
            ;;
        help|--help|-h|"")
            show_help
            ;;
        *)
            log_error "Unknown command: $1"
            exit $E001
            ;;
    esac
}

main "$@"
