#!/bin/bash
set -e

TOOL_NAME="html-to-drupal"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_DIR="$(dirname "$SCRIPT_DIR")"
TOOLS_DIR="$(dirname "$TOOL_DIR")"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$TOOLS_DIR/.." && pwd)}"
TOOL_SHARED_ROOT="${TOOL_SHARED_ROOT:-$PROJECT_ROOT/workspace/$TOOL_NAME}"
LOG_DIR="$TOOL_SHARED_ROOT/logs"

mkdir -p "$LOG_DIR"

STATIC_HTML_FOLDER="${STATIC_HTML_FOLDER:-}"
OPENCODE_SESSION_NAME="${OPENCODE_SESSION_NAME:-html-analysis}"
THEME_NAME="${THEME_NAME:-nci_theme}"
CONTENT_TYPE_NAME="${CONTENT_TYPE_NAME:-cancer_content}"
DRUPAL_SETUP_TOOL="${DRUPAL_SETUP_TOOL:-$PROJECT_ROOT/tools/01-drupal-setup}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_DIR/analyze-html.log"
}

log "DEBUG: SCRIPT_DIR=$SCRIPT_DIR"
log "DEBUG: TOOL_DIR=$TOOL_DIR"
log "DEBUG: TOOLS_DIR=$TOOLS_DIR"
log "DEBUG: PROJECT_ROOT=$PROJECT_ROOT"

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$LOG_DIR/analyze-html.log"
}

cd "$TOOL_DIR"

log "=== Starting HTML Analysis ==="
log "STATIC_HTML_FOLDER: $STATIC_HTML_FOLDER"
log "OPENCODE_SESSION_NAME: $OPENCODE_SESSION_NAME"

if [ -z "$STATIC_HTML_FOLDER" ]; then
    log_error "STATIC_HTML_FOLDER is required"
    echo "Usage: ./run.sh run /path/to/static/html"
    exit 1
fi

if [ ! -d "$STATIC_HTML_FOLDER" ]; then
    log_error "Directory not found: $STATIC_HTML_FOLDER"
    exit 1
fi

INDEX_FILE="$STATIC_HTML_FOLDER/index.html"
if [ ! -f "$INDEX_FILE" ]; then
    INDEX_FILE="$STATIC_HTML_FOLDER/index.htm"
    if [ ! -f "$INDEX_FILE" ]; then
        log_error "No index.html or index.htm found in $STATIC_HTML_FOLDER"
        ls -la "$STATIC_HTML_FOLDER" | head -20 >> "$LOG_DIR/analyze-html.log"
        exit 1
    fi
fi

log "Found HTML file: $INDEX_FILE"

log "[1/6] Checking dependencies..."

if ! command -v opencode &>/dev/null; then
    log_error "OpenCode CLI is not installed"
    log "Install from: https://opencode.ai or via npm"
    exit 3
fi

if ! command -v node &>/dev/null; then
    log_error "Node.js is not installed"
    exit 3
fi

log "Dependencies OK"

log "[2/6] Checking Drupal setup..."

if [ ! -f "$DRUPAL_SETUP_TOOL/run.sh" ]; then
    log_error "Drupal setup tool not found: $DRUPAL_SETUP_TOOL"
    exit 3
fi

DRUPAL_HEALTH=$("$DRUPAL_SETUP_TOOL/run.sh" query health 2>/dev/null | grep "^STATUS:" | cut -d: -f2-)
if [ "$DRUPAL_HEALTH" != "healthy" ]; then
    log_error "Drupal is not healthy: $DRUPAL_HEALTH"
    log "Run drupal-setup first: $DRUPAL_SETUP_TOOL/run.sh run"
    exit 2
fi

SITE_URL=$("$DRUPAL_SETUP_TOOL/run.sh" query site_url 2>/dev/null | grep "^SITE_URL:" | cut -d: -f2-)
log "Drupal site URL: $SITE_URL"

log "[3/6] Creating state file..."
cat > "$TOOL_SHARED_ROOT/state.json" << EOF
{
  "status": "analyzing",
  "static_html_folder": "$STATIC_HTML_FOLDER",
  "index_file": "$INDEX_FILE",
  "opencode_session": "$OPENCODE_SESSION_NAME",
  "theme_name": "$THEME_NAME",
  "content_type_name": "$CONTENT_TYPE_NAME",
  "site_url": "$SITE_URL",
  "layout_json_path": "",
  "blocks": [],
  "step": "analyze-html"
}
EOF
log "State file created"

log "[4/6] Running OpenCode analysis..."

OPENCODE_LOG="$LOG_DIR/opencode-analysis.log"
cat > "$OPENCODE_LOG" << 'OPENCODESTART'
=== OpenCode HTML Analysis Session ===
Started: $(date)

OPENCODESTART

ANALYSIS_PROMPT="You are analyzing a static HTML file to create a layout.json specification.

Read the file at: $INDEX_FILE

Your task is to:
1. Analyze the HTML structure (header, nav, main content, sidebar, footer, etc.)
2. Identify all CSS classes used (especially Tailwind)
3. Find all image and asset references
4. Note the fonts being used
5. Identify color schemes
6. Map the DOM hierarchy

Output a JSON structure called layout.json with:
- meta: sourceFile, description, reversible: true, version
- layout: array of section objects with id, type, tag, attrs, children
- symbols: image/icon paths
- styles: fonts, colors

IMPORTANT: The layout.json MUST be reversible - you should be able to regenerate the exact HTML from it.

Output ONLY the JSON, no explanation. Start with { and end with }"

log "OpenCode analysis prompt prepared"
log "Note: In a full implementation, OpenCode CLI would be invoked here"
log "For now, we will use a reference layout.json if available"

log "[5/6] Looking for reference layout.json..."

LAYOUT_SPEC_DIR="$STATIC_HTML_FOLDER/layout-spec"
if [ -f "$LAYOUT_SPEC_DIR/layout.json" ]; then
    log "Found reference layout.json at $LAYOUT_SPEC_DIR/layout.json"
    cp "$LAYOUT_SPEC_DIR/layout.json" "$TOOL_SHARED_ROOT/layout.json"
    log "Copied to $TOOL_SHARED_ROOT/layout.json"
elif [ -f "$STATIC_HTML_FOLDER/../layout-spec/layout.json" ]; then
    REF_LAYOUT="$STATIC_HTML_FOLDER/../layout-spec/layout.json"
    log "Found reference layout.json at $REF_LAYOUT"
    cp "$REF_LAYOUT" "$TOOL_SHARED_ROOT/layout.json"
    log "Copied to $TOOL_SHARED_ROOT/layout.json"
else
    log_error "No layout.json found!"
    log "Please provide layout.json in layout-spec/ subfolder or parent directory"
    exit 1
fi

log "[6/6] Validating layout.json..."

if [ ! -f "$TOOL_SHARED_ROOT/layout.json" ]; then
    log_error "layout.json not found at $TOOL_SHARED_ROOT/layout.json"
    exit 1
fi

python3 -c "import json; json.load(open('$TOOL_SHARED_ROOT/layout.json'))" 2>> "$LOG_DIR/analyze-html.log"
if [ $? -ne 0 ]; then
    log_error "layout.json is not valid JSON"
    exit 1
fi

log "layout.json is valid JSON"

LAYOUT_SIZE=$(wc -c < "$TOOL_SHARED_ROOT/layout.json")
SECTIONS=$(python3 -c "import json; print(len(json.load(open('$TOOL_SHARED_ROOT/layout.json')).get('layout', [])))")
log "Layout size: $LAYOUT_SIZE bytes, Sections: $SECTIONS"

log "=== HTML Analysis Complete ==="

cat > "$TOOL_SHARED_ROOT/state.json" << EOF
{
  "status": "analyzed",
  "static_html_folder": "$STATIC_HTML_FOLDER",
  "index_file": "$INDEX_FILE",
  "opencode_session": "$OPENCODE_SESSION_NAME",
  "theme_name": "$THEME_NAME",
  "content_type_name": "$CONTENT_TYPE_NAME",
  "site_url": "$SITE_URL",
  "layout_json_path": "$TOOL_SHARED_ROOT/layout.json",
  "layout_size": "$LAYOUT_SIZE",
  "sections_count": "$SECTIONS",
  "blocks": [],
  "step": "analyzed"
}
EOF

log "Next step: Run create-drupal.sh to create Drupal components"

echo ""
echo "HTML Analysis Complete!"
echo "Layout JSON: $TOOL_SHARED_ROOT/layout.json"
echo "Next: ./run.sh run --continue or manually run create-drupal.sh"
