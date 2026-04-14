#!/bin/bash

TOOL_NAME="html-to-drupal"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(cd "$TOOL_DIR/../.." && pwd)"
TOOL_SHARED_ROOT="$PROJECT_ROOT/workspace/$TOOL_NAME"
STATE_FILE="$TOOL_SHARED_ROOT/state.json"
DRUPAL_SETUP_TOOL="$PROJECT_ROOT/tools/01-drupal-setup"

load_state() {
    if [ -f "$STATE_FILE" ]; then
        STATUS=$(python3 -c "import json; print(json.load(open('$STATE_FILE')).get('status', 'unknown'))" 2>/dev/null || echo "unknown")
        LAYOUT_JSON=$(python3 -c "import json; print(json.load(open('$STATE_FILE')).get('layout_json_path', ''))" 2>/dev/null || echo "")
        THEME=$(python3 -c "import json; print(json.load(open('$STATE_FILE')).get('theme_name', ''))" 2>/dev/null || echo "")
        CONTENT_TYPE=$(python3 -c "import json; print(json.load(open('$STATE_FILE')).get('content_type_name', ''))" 2>/dev/null || echo "")
        SITE_URL=$(python3 -c "import json; print(json.load(open('$STATE_FILE')).get('site_url', ''))" 2>/dev/null || echo "")
        BLOCKS=$(python3 -c "import json; print(','.join(json.load(open('$STATE_FILE')).get('blocks', [])))" 2>/dev/null || echo "")
        FRONTPAGE_NID=$(python3 -c "import json; print(json.load(open('$STATE_FILE')).get('frontpage_nid', ''))" 2>/dev/null || echo "")
    else
        STATUS="not_ready"
        LAYOUT_JSON=""
        THEME=""
        CONTENT_TYPE=""
        BLOCKS=""
        SITE_URL=""
    fi
}

check_opencode() {
    if command -v opencode &>/dev/null; then
        echo "available"
    else
        echo "not_found"
    fi
}

case "$1" in
    health)
        load_state
        
        OPENCODE_STATUS=$(check_opencode)
        DRUPAL_HEALTH=$("$DRUPAL_SETUP_TOOL/run.sh" query health 2>/dev/null | grep "^STATUS:" | cut -d: -f2-)
        
        echo "TOOL:$TOOL_NAME:QUERY:health"
        echo "STATUS:healthy"
        echo "OPENCODE:$OPENCODE_STATUS"
        echo "DRUPAL:$DRUPAL_HEALTH"
        echo "STATE:$STATUS"
        echo "---"
        ;;
    status)
        load_state
        echo "TOOL:$TOOL_NAME:QUERY:status"
        echo "STATUS:$STATUS"
        if [ -n "$LAYOUT_JSON" ]; then
            echo "LAYOUT_JSON:$LAYOUT_JSON"
        fi
        echo "---"
        ;;
    state)
        load_state
        
        if [ -z "$SITE_URL" ]; then
            SITE_URL=$("$DRUPAL_SETUP_TOOL/run.sh" query site_url 2>/dev/null | grep "^SITE_URL:" | cut -d: -f2-)
        fi
        if [ -z "$DRUPAL_ROOT" ]; then
            DRUPAL_ROOT=$("$DRUPAL_SETUP_TOOL/run.sh" query state 2>/dev/null | grep "^DRUPAL_ROOT:" | cut -d: -f2-)
        fi
        
        echo "TOOL:$TOOL_NAME:QUERY:state"
        echo "STATUS:$STATUS"
        echo "STATIC_HTML_FOLDER:$(python3 -c "import json; print(json.load(open('$STATE_FILE')).get('static_html_folder', ''))" 2>/dev/null || echo '')"
        echo "LAYOUT_JSON:$LAYOUT_JSON"
        echo "THEME_NAME:$THEME"
        echo "CONTENT_TYPE:$CONTENT_TYPE"
        echo "BLOCKS:$BLOCKS"
        echo "SITE_URL:$SITE_URL"
        echo "DRUPAL_ROOT:$DRUPAL_ROOT"
        echo "FRONTPAGE_NID:$FRONTPAGE_NID"
        echo "STEP:$(python3 -c "import json; print(json.load(open('$STATE_FILE')).get('step', ''))" 2>/dev/null || echo '')"
        echo "---"
        ;;
    layout_json)
        load_state
        echo "TOOL:$TOOL_NAME:QUERY:layout_json"
        echo "PATH:$LAYOUT_JSON"
        if [ -n "$LAYOUT_JSON" ] && [ -f "$LAYOUT_JSON" ]; then
            SIZE=$(wc -c < "$LAYOUT_JSON")
            SECTIONS=$(python3 -c "import json; print(len(json.load(open('$LAYOUT_JSON')).get('layout', [])))" 2>/dev/null || echo "0")
            echo "SIZE:$SIZE"
            echo "SECTIONS:$SECTIONS"
        fi
        echo "---"
        ;;
    theme)
        load_state
        echo "TOOL:$TOOL_NAME:QUERY:theme"
        echo "THEME_NAME:$THEME"
        if [ -n "$THEME" ]; then
            echo "STATUS:created"
        else
            echo "STATUS:pending"
        fi
        echo "---"
        ;;
    content_type)
        load_state
        echo "TOOL:$TOOL_NAME:QUERY:content_type"
        echo "CONTENT_TYPE:$CONTENT_TYPE"
        if [ -n "$CONTENT_TYPE" ]; then
            echo "STATUS:created"
        else
            echo "STATUS:pending"
        fi
        echo "---"
        ;;
    blocks)
        load_state
        echo "TOOL:$TOOL_NAME:QUERY:blocks"
        echo "BLOCKS:$BLOCKS"
        if [ -n "$BLOCKS" ]; then
            echo "COUNT:$(echo "$BLOCKS" | tr ',' '\n' | wc -l)"
            echo "STATUS:created"
        else
            echo "STATUS:pending"
        fi
        echo "---"
        ;;
    site_url)
        load_state
        if [ -z "$SITE_URL" ]; then
            SITE_URL=$("$DRUPAL_SETUP_TOOL/run.sh" query site_url 2>/dev/null | grep "^SITE_URL:" | cut -d: -f2-)
        fi
        echo "TOOL:$TOOL_NAME:QUERY:site_url"
        echo "SITE_URL:$SITE_URL"
        echo "---"
        ;;
    dependencies)
        echo "TOOL:$TOOL_NAME:QUERY:dependencies"
        echo "REQUIRED:opencode,node,python3,ddev,docker,drush"
        echo "OPTIONAL:playwright,mmx"
        echo "---"
        ;;
    "")
        echo "TOOL:$TOOL_NAME:QUERY:available"
        echo "QUERY_TYPES:health,status,state,layout_json,theme,content_type,blocks,site_url,dependencies"
        echo "---"
        ;;
    *)
        echo "TOOL:$TOOL_NAME:ERROR:E001"
        echo "MESSAGE:Unknown query type '$1'"
        echo "AVAILABLE:health,status,state,layout_json,theme,content_type,blocks,site_url,dependencies"
        echo "---"
        exit 0
        ;;
esac
