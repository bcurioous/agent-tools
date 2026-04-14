#!/bin/bash

TOOL_NAME="drupal-setup"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_DIR="$(dirname "$SCRIPT_DIR")"

check_dependencies() {
    if ! command -v ddev &>/dev/null; then
        echo "TOOL:$TOOL_NAME:QUERY:health"
        echo "STATUS:unhealthy:ddev_not_found"
        echo "---"
        return 1
    fi

    if ! docker info &>/dev/null 2>&1; then
        echo "TOOL:$TOOL_NAME:QUERY:health"
        echo "STATUS:unhealthy:docker_not_running"
        echo "---"
        return 1
    fi

    if ! ddev describe &>/dev/null 2>&1; then
        echo "TOOL:$TOOL_NAME:QUERY:health"
        echo "STATUS:unhealthy:project_not_initialized"
        echo "---"
        return 1
    fi

    return 0
}

case "$1" in
    health)
        check_dependencies || exit 0
        echo "TOOL:$TOOL_NAME:QUERY:health"
        echo "STATUS:healthy"
        echo "VERSION:$(ddev --version 2>/dev/null | head -1)"
        echo "DOCKER_VERSION:$(docker --version 2>/dev/null)"
        echo "---"
        ;;
    status)
        check_dependencies || exit 0
        if ddev describe &>/dev/null 2>&1; then
            DB_STATUS=$(ddev drush status --field=db-status 2>/dev/null || echo "unknown")
            echo "TOOL:$TOOL_NAME:QUERY:status"
            echo "STATUS:ready"
            echo "DB_STATUS:$DB_STATUS"
        else
            echo "TOOL:$TOOL_NAME:QUERY:status"
            echo "STATUS:not_ready"
        fi
        echo "---"
        ;;
    state)
        check_dependencies || exit 0
        echo "TOOL:$TOOL_NAME:QUERY:state"
        echo "STATUS:ready"
        echo "DRUPAL_VERSION:$(ddev drush status --field=drupal-version 2>/dev/null || echo 'not installed')"
        echo "PHP_VERSION:$(ddev drush status --field=php-version 2>/dev/null || echo 'not installed')"
        echo "DB_STATUS:$(ddev drush status --field=db-status 2>/dev/null || echo 'unknown')"
        echo "DEFAULT_THEME:$(ddev drush config:get system.theme default 2>/dev/null | awk '{print $2}' || echo 'unknown')"
        echo "ADMIN_THEME:$(ddev drush config:get system.theme admin 2>/dev/null | awk '{print $2}' || echo 'unknown')"
        echo "SITE_URL:$(ddev describe 2>/dev/null | grep -o 'https://[^ ]*' | head -1 || echo 'unknown')"
        echo "---"
        ;;
    version)
        check_dependencies || exit 0
        echo "TOOL:$TOOL_NAME:QUERY:version"
        echo "DRUPAL_VERSION:$(ddev drush status --field=drupal-version 2>/dev/null || echo 'not installed')"
        echo "DDEV_VERSION:$(ddev --version 2>/dev/null | head -1)"
        echo "---"
        ;;
    module)
        check_dependencies || exit 0
        if [ -z "$2" ]; then
            echo "TOOL:$TOOL_NAME:ERROR:E001"
            echo "MESSAGE:Module name required"
            echo "USAGE:query module <name>"
            echo "---"
            exit 0
        fi
        if ddev drush pm:list --status=enabled 2>/dev/null | grep -q "^$2 "; then
            echo "TOOL:$TOOL_NAME:MODULE:$2"
            echo "STATUS:enabled"
        else
            echo "TOOL:$TOOL_NAME:MODULE:$2"
            echo "STATUS:disabled"
        fi
        echo "---"
        ;;
    theme)
        check_dependencies || exit 0
        echo "TOOL:$TOOL_NAME:QUERY:theme"
        echo "DEFAULT_THEME:$(ddev drush config:get system.theme default 2>/dev/null | awk '{print $2}' || echo 'unknown')"
        echo "---"
        ;;
    site_url)
        check_dependencies || exit 0
        echo "TOOL:$TOOL_NAME:QUERY:site_url"
        echo "SITE_URL:$(ddev describe 2>/dev/null | grep -o 'https://[^ ]*' | head -1 || echo 'unknown')"
        echo "---"
        ;;
    dependencies)
        echo "TOOL:$TOOL_NAME:QUERY:dependencies"
        echo "REQUIRED:ddev,docker,composer"
        echo "OPTIONAL:git"
        echo "---"
        ;;
    "")
        echo "TOOL:$TOOL_NAME:QUERY:available"
        echo "QUERY_TYPES:health,status,state,version,module,theme,site_url,dependencies"
        echo "---"
        ;;
    *)
        echo "TOOL:$TOOL_NAME:ERROR:E001"
        echo "MESSAGE:Unknown query type '$1'"
        echo "AVAILABLE_QUERY_TYPES:health,status,state,version,module,theme,site_url,dependencies"
        echo "---"
        exit 0
        ;;
esac
