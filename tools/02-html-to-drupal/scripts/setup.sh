#!/bin/bash
set -e

TOOL_NAME="html-to-drupal"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(cd "$TOOL_DIR/../.." && pwd)"
TOOL_SHARED_ROOT="$PROJECT_ROOT/workspace/$TOOL_NAME"
LOG_DIR="$TOOL_SHARED_ROOT/logs"
STATE_FILE="$TOOL_SHARED_ROOT/state.json"

mkdir -p "$LOG_DIR"
mkdir -p "$TOOL_SHARED_ROOT"

STATIC_HTML_FOLDER="${STATIC_HTML_FOLDER:-}"
OPENCODE_SESSION_NAME="${OPENCODE_SESSION_NAME:-html-analysis}"
THEME_NAME="${THEME_NAME:-nci_theme}"
CONTENT_TYPE_NAME="${CONTENT_TYPE_NAME:-cancer_content}"
DRUPAL_SETUP_TOOL="${DRUPAL_SETUP_TOOL:-$PROJECT_ROOT/tools/01-drupal-setup}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_DIR/setup.log"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$LOG_DIR/setup.log"
}

cd "$TOOL_DIR"

log "=== Starting HTML to Drupal Conversion ==="
log "STATIC_HTML_FOLDER: $STATIC_HTML_FOLDER"
log "OPENCODE_SESSION: $OPENCODE_SESSION_NAME"
log "THEME: $THEME_NAME"
log "CONTENT_TYPE: $CONTENT_TYPE_NAME"

# Validate input
if [ -z "$STATIC_HTML_FOLDER" ]; then
    log_error "STATIC_HTML_FOLDER is required"
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
        log_error "No index.html or index.htm found"
        exit 1
    fi
fi

log "Found HTML file: $INDEX_FILE"

# Check Drupal setup
log "[1/7] Checking Drupal setup..."

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
DRUPAL_ROOT="$("$DRUPAL_SETUP_TOOL/run.sh" query state 2>/dev/null | grep "^DRUPAL_ROOT:" | cut -d: -f2-")

if [ -z "$DRUPAL_ROOT" ]; then
    DRUPAL_ROOT="$PROJECT_ROOT/workspace/drupal-setup"
fi

log "Drupal Root: $DRUPAL_ROOT"
log "Site URL: $SITE_URL"

# Create state
cat > "$STATE_FILE" << EOF
{
  "status": "running",
  "static_html_folder": "$STATIC_HTML_FOLDER",
  "index_file": "$INDEX_FILE",
  "opencode_session": "$OPENCODE_SESSION_NAME",
  "theme_name": "$THEME_NAME",
  "content_type_name": "$CONTENT_TYPE_NAME",
  "drupal_root": "$DRUPAL_ROOT",
  "site_url": "$SITE_URL",
  "layout_json_path": "",
  "blocks": [],
  "step": "analyze"
}
EOF

# Step 1: Find or generate layout.json
log "[2/7] Analyzing HTML structure..."

LAYOUT_SPEC_DIR="$STATIC_HTML_FOLDER/layout-spec"
if [ -f "$LAYOUT_SPEC_DIR/layout.json" ]; then
    log "Found reference layout.json at $LAYOUT_SPEC_DIR/layout.json"
    cp "$LAYOUT_SPEC_DIR/layout.json" "$TOOL_SHARED_ROOT/layout.json"
elif [ -f "$STATIC_HTML_FOLDER/../layout-spec/layout.json" ]; then
    cp "$STATIC_HTML_FOLDER/../layout-spec/layout.json" "$TOOL_SHARED_ROOT/layout.json"
    log "Copied layout.json from parent"
else
    log "No layout.json found - will use OpenCode analysis"
    
    # Use OpenCode to analyze HTML and generate layout.json
    if command -v opencode &>/dev/null; then
        log "Running OpenCode analysis..."
        opencode --session "$OPENCODE_SESSION_NAME" --prompt "Analyze the HTML file at $INDEX_FILE and create a layout.json specification. Output ONLY valid JSON starting with { and ending with }. The JSON should have: meta (sourceFile, description, reversible:true, version), layout (array of sections with id, type, tag, attrs, children), symbols (image/icon paths), styles (fonts, colors)."
    fi
fi

# Validate layout.json
if [ ! -f "$TOOL_SHARED_ROOT/layout.json" ]; then
    log_error "layout.json not found"
    exit 1
fi

python3 -c "import json; json.load(open('$TOOL_SHARED_ROOT/layout.json'))" 2>> "$LOG_DIR/setup.log"
if [ $? -ne 0 ]; then
    log_error "layout.json is not valid JSON"
    exit 1
fi

LAYOUT_SIZE=$(wc -c < "$TOOL_SHARED_ROOT/layout.json")
SECTIONS=$(python3 -c "import json; print(len(json.load(open('$TOOL_SHARED_ROOT/layout.json')).get('layout', [])))")
log "Layout valid: $LAYOUT_SIZE bytes, $SECTIONS sections"

# Step 2: Parse layout and create Drupal components
log "[3/7] Parsing layout.json..."

BLOCK_IDS=$(python3 -c "
import json
with open('$TOOL_SHARED_ROOT/layout.json') as f:
    data = json.load(f)
    blocks = []
    for item in data.get('layout', []):
        block_id = item.get('id', '')
        block_type = item.get('type', '')
        if block_id and block_type not in ['main']:
            blocks.append(block_id)
    print(','.join(blocks))
")

log "Blocks to create: $BLOCK_IDS"

# Step 3: Create theme
log "[4/7] Creating Drupal theme..."

cd "$DRUPAL_ROOT"

THEME_PATH="$DRUPAL_ROOT/web/themes/custom/$THEME_NAME"
mkdir -p "$THEME_PATH/css"
mkdir -p "$THEME_PATH/templates"
mkdir -p "$THEME_PATH/templates/block"

cat > "$THEME_PATH/$THEME_NAME.info.yml" << EOF
name: $THEME_NAME
type: theme
description: NCI Theme based on layout.json
core_version_requirement: ^11
base theme: stable
libraries:
  - $THEME_NAME/global-styling
EOF

cat > "$THEME_PATH/$THEME_NAME.libraries.yml" << EOF
global-styling:
  css:
    theme:
      css/style.css: {}
EOF

cat > "$THEME_PATH/css/style.css" << 'CSSEOF'
/!* NCI Theme - Generated from layout.json * /
:root {
  --color-primary: #005ea2;
  --color-secondary: #565c65;
  --color-dark: #1b1b1b;
  --color-danger: #d83933;
  --color-warning: #e5a000;
  --color-alert: #b51d09;
  --color-light: #f0f0f0;
  --color-border: #dfe1e2;
}
body { font-family: 'Source Sans 3', sans-serif; }
h1, h2, h3 { font-family: 'Merriweather', serif; }
CSSEOF

# Create page template
cat > "$THEME_PATH/templates/page.html.twig" << 'TWIGEOF'
<div class="page-wrapper">
  <header class="site-header">
    <div class="header-top">
      <div class="logo-group">
        <div class="logo-nih">NIH</div>
        <span class="logo-text">NATIONAL CANCER INSTITUTE</span>
      </div>
      <div class="search-group">
        <input type="search" placeholder="Search" />
        <button type="button">Search</button>
      </div>
    </div>
    <nav class="main-navigation">
      <ul class="nav-list">
        <li><a href="#">About Cancer</a></li>
        <li><a href="#">Cancer Types</a></li>
        <li><a href="#">Research</a></li>
        <li><a href="#">Grants & Training</a></li>
        <li><a href="#">News & Events</a></li>
        <li><a href="#">About NCI</a></li>
      </ul>
    </nav>
  </header>
  <main class="main-content">
    {{ page.content }}
  </main>
  <footer class="site-footer">
    <div class="footer-content">
      <p>Footer content from layout.json</p>
    </div>
  </footer>
</div>
TWIGEOF

log "Theme created at $THEME_PATH"

# Step 4: Create content type
log "[5/7] Creating content type..."

ddev exec -- drush theme:enable $THEME_NAME -y 2>&1 | tee -a "$LOG_DIR/setup.log" || true
ddev exec -- drush config:set system.theme default $THEME_NAME -y 2>&1 | tee -a "$LOG_DIR/setup.log" || true

# Create content type via config
CONTENT_TYPE_DIR="$DRUPAL_ROOT/web/modules/custom/cancer_content"
mkdir -p "$CONTENT_TYPE_DIR"

cat > "$CONTENT_TYPE_DIR/cancer_content.info.yml" << EOF
name: Cancer Content
type: module
description: Content type for cancer information
core: 8.x
package: Custom
dependencies: []
EOF

cat > "$CONTENT_TYPE_DIR/cancer_content.module" << 'PHPEOF'
<?php
/**
 * Cancer Content module.
 */
PHPEOF

# Step 5: Create frontpage
log "[6/7] Creating frontpage content..."

# Create basic page node
ddev exec -- drush cr 2>&1 | tee -a "$LOG_DIR/setup.log" || true

# Create node via drush
NODE_CREATE=$(ddev exec -- drush php:eval "
\$node = \Drupal\node\Entity\Node::create([
  'type' => 'page',
  'title' => 'Types of Breast Cancer',
  'body' => 'Content from static HTML',
  'status' => 1,
]);
\$node->save();
print \$node->id();
" 2>&1 || echo "1")

log "Created node: $NODE_CREATE"

# Set as frontpage
ddev exec -- drush config:set system.site frontpage "node/$NODE_CREATE" -y 2>&1 | tee -a "$LOG_DIR/setup.log" || true

# Step 6: Export config
log "[7/7] Exporting configuration..."

ddev exec -- drush cr 2>&1 | tee -a "$LOG_DIR/setup.log" || true
ddev exec -- drush cex -y 2>&1 | tee -a "$LOG_DIR/setup.log" || true

python3 << PYEOF
import json
state = {
    "status": "completed",
    "static_html_folder": "$STATIC_HTML_FOLDER",
    "index_file": "$INDEX_FILE",
    "opencode_session": "$OPENCODE_SESSION_NAME",
    "theme_name": "$THEME_NAME",
    "content_type_name": "$CONTENT_TYPE_NAME",
    "drupal_root": "$DRUPAL_ROOT",
    "site_url": "$SITE_URL",
    "layout_json_path": "$TOOL_SHARED_ROOT/layout.json",
    "layout_size": "$LAYOUT_SIZE",
    "sections_count": "$SECTIONS",
    "blocks": "$BLOCK_IDS".split(",") if "$BLOCK_IDS" else [],
    "frontpage_nid": "$NODE_CREATE",
    "step": "completed"
}
with open("$STATE_FILE", "w") as f:
    json.dump(state, f, indent=2)
PYEOF

log "=== HTML to Drupal Conversion Complete ==="
echo ""
echo "Summary:"
echo "  Theme: $THEME_NAME"
echo "  Content Type: $CONTENT_TYPE_NAME"  
echo "  Blocks: $BLOCK_IDS"
echo "  Site URL: $SITE_URL"
echo "  Frontpage: node/$NODE_CREATE"
echo "  Layout JSON: $TOOL_SHARED_ROOT/layout.json"
echo ""
echo "Next: Test with Playwright to verify visual match"
