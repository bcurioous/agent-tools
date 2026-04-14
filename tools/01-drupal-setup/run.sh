#!/bin/bash
#===============================================================================
# Tool run.sh - Fixed Interface Harness
#
# DO NOT MODIFY THIS FILE - This is the fixed interface for ALL tools.
# Each tool's specific logic goes in scripts/*.sh
#
# Interface (MUST match exactly):
#   ./run.sh run      - Execute the tool
#   ./run.sh query    - Query tool state
#   ./run.sh verify   - Self-verification
#   ./run.sh help     - Show help
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
# 0 = Success
# E001 = 1 = Invalid input
# E002 = 2 = Tool not ready
# E003 = 3 = Dependency missing
# E004 = 4 = Execution failed
# E005 = 5 = Permission denied
E001=1
E002=2
E003=3
E004=4
E005=5

# Tool metadata
TOOL_NAME="${TOOL_NAME:-drupal-setup}"
TOOL_VERSION="${TOOL_VERSION:-1.0.0}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Standard environment variables (from tool-spec)
export TOOL_WORKSPACE_ROOT="${TOOL_WORKSPACE_ROOT:-$SCRIPT_DIR/workspace}"
export PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
export TOOL_SHARED_ROOT="${TOOL_SHARED_ROOT:-$PROJECT_ROOT/workspace/$TOOL_NAME}"
export TOOL_REGISTRY="${TOOL_REGISTRY:-$PROJECT_ROOT/tool-registry.yaml}"

# Colors for output (disabled if not terminal)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

#-------------------------------------------------------------------------------
# Logging functions
#-------------------------------------------------------------------------------
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

#-------------------------------------------------------------------------------
# Load LIMITS (permission boundaries)
#-------------------------------------------------------------------------------
load_limits() {
    if [ -f "$SCRIPT_DIR/LIMITS.md" ]; then
        LIMITS_FILE="$SCRIPT_DIR/LIMITS.md"
    fi
}

#-------------------------------------------------------------------------------
# Check if operation is allowed (LIMITS enforcement)
#-------------------------------------------------------------------------------
check_limit() {
    local operation="$1"
    local target="$2"

    if [ -n "$DEBUG" ]; then
        log_info "LIMITS check: $operation on $target"
    fi

    # TODO: Implement actual LIMITS enforcement by parsing LIMITS.md
    # For now, this is a stub that allows all operations
    return 0
}

#-------------------------------------------------------------------------------
# Verify tool prerequisites
#-------------------------------------------------------------------------------
verify_prerequisites() {
    local missing=()

    # Check dependencies from SPEC.md
    if [ -f "$SCRIPT_DIR/SPEC.md" ]; then
        # Extract required dependencies (stub - implement properly)
        :
    fi

    # Always check for scripts/
    if [ ! -d "$SCRIPT_DIR/scripts" ]; then
        log_error "Missing scripts/ directory"
        exit $E004
    fi

    # Check required scripts
    for script in setup.sh verify.sh query.sh; do
        if [ ! -f "$SCRIPT_DIR/scripts/$script" ]; then
            log_error "Missing scripts/$script"
            missing+=("$script")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing required scripts: ${missing[*]}"
        exit $E004
    fi

    log_success "Prerequisites verified"
}

#-------------------------------------------------------------------------------
# Show help
#-------------------------------------------------------------------------------
show_help() {
    cat << EOF
${BLUE}Tool: $TOOL_NAME${NC}
${BLUE}Version: $TOOL_VERSION${NC}

A constraint-based tool following the tool-spec specification.

${GREEN}Usage:${NC}
    ./run.sh <command> [options]

${GREEN}Commands:${NC}
    run         Execute the tool
    query       Query tool state (health|status|state|version|<key>)
    verify      Self-verification
    help        Show this help

${GREEN}Query Options:${NC}
    health      Health check
    status      Current status (ready|busy|error|not_ready)
    state       Full state dump
    version     Tool version
    <key>       Specific value lookup

${GREEN}Examples:${NC}
    ./run.sh run              # Execute the tool
    ./run.sh query health     # Health check
    ./run.sh query status     # Current status
    ./run.sh query state      # Full state
    ./run.sh verify          # Self-check

${GREEN}Files:${NC}
    SPEC.md   - Tool specification
    LIMITS.md - Prohibited operations
    QUERY.md  - Query protocol docs

EOF
}

#-------------------------------------------------------------------------------
# Main command dispatcher
#-------------------------------------------------------------------------------
main() {
    # Load LIMITS
    load_limits

    # Ensure scripts exist before any operation
    if [ "$1" != "help" ] && [ "$1" != "--help" ] && [ "$1" != "-h" ]; then
        verify_prerequisites
    fi

    case "$1" in
        run|"")
            log_info "Executing $TOOL_NAME..."
            check_limit "run" "tool"
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
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: $1"
            echo "Run './run.sh help' for usage"
            exit $E001
            ;;
    esac
}

# Run
main "$@"
