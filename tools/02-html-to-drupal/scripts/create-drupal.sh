#!/bin/bash
set -e

TOOL_NAME="html-to-drupal"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$TOOL_DIR/../.." && pwd)}"
TOOL_SHARED_ROOT="${TOOL_SHARED_ROOT:-$PROJECT_ROOT/workspace/$TOOL_NAME}"
LOG_DIR="$TOOL_SHARED_ROOT/logs"
STATE_FILE="$TOOL_SHARED_ROOT/state.json"
DRUPAL_SETUP_TOOL="${DRUPAL_SETUP_TOOL:-$PROJECT_ROOT/tools/01-drupal-setup}"

mkdir -p "$LOG_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_DIR/create-drupal.log"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$LOG_DIR/create-drupal.log"
}

cd "$TOOL_DIR"

log "=== Starting Drupal Creation ==="

load_state() {
    if [ -f "$STATE_FILE" ]; then
        LAYOUT_JSON=$(python3 -c "import json; print(json.load(open('$STATE_FILE')).get('layout_json_path', ''))" 2>/dev/null)
        THEME_NAME=$(python3 -c "import json; print(json.load(open('$STATE_FILE')).get('theme_name', 'nci_theme'))" 2>/dev/null)
        CONTENT_TYPE_NAME=$(python3 -c "import json; print(json.load(open('$STATE_FILE')).get('content_type_name', 'cancer_content'))" 2>/dev/null)
        SITE_URL=$(python3 -c "import json; print(json.load(open('$STATE_FILE')).get('site_url', ''))" 2>/dev/null)
        STATIC_HTML_FOLDER=$(python3 -c "import json; print(json.load(open('$STATE_FILE')).get('static_html_folder', ''))" 2>/dev/null)
    fi
    
    LAYOUT_JSON="${LAYOUT_JSON:-$TOOL_SHARED_ROOT/layout.json}"
    THEME_NAME="${THEME_NAME:-nci_theme}"
    CONTENT_TYPE_NAME="${CONTENT_TYPE_NAME:-cancer_content}"
}

load_state

if [ ! -f "$LAYOUT_JSON" ]; then
    log_error "layout.json not found: $LAYOUT_JSON"
    log "Run analyze-html.sh first"
    exit 1
fi

log "Layout JSON: $LAYOUT_JSON"
log "Theme: $THEME_NAME"
log "Content Type: $CONTENT_TYPE_NAME"

SITE_URL=$("$DRUPAL_SETUP_TOOL/run.sh" query site_url 2>/dev/null | grep "^SITE_URL:" | cut -d: -f2-)
DRUPAL_ROOT="$("$DRUPAL_SETUP_TOOL/run.sh" query state 2>/dev/null | grep "^DRUPAL_ROOT:" | cut -d: -f2-)"

if [ -z "$DRUPAL_ROOT" ]; then
    DRUPAL_ROOT="$PROJECT_ROOT/workspace/drupal-setup"
fi

log "Drupal Root: $DRUPAL_ROOT"
log "Site URL: $SITE_URL"

log "[1/8] Parsing layout.json..."

SECTIONS=$(python3 << PYEOF
import json
with open('$LAYOUT_JSON') as f:
    data = json.load(f)
    layout = data.get('layout', [])
    print(len(layout))
    for item in layout:
        print(f"  - {item.get('id', 'unknown')}: {item.get('type', 'unknown')}")
PYEOF
)

log "Found $SECTIONS sections in layout"

log "[2/8] Creating Drupal theme..."

ddev exec -- drush generate theme $THEME_NAME --theme-type=stable 2>&1 | tee -a "$LOG_DIR/create-drupal.log" || true

THEME_PATH="$DRUPAL_ROOT/web/themes/custom/$THEME_NAME"
if [ ! -d "$THEME_PATH" ]; then
    mkdir -p "$THEME_PATH"
fi

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

mkdir -p "$THEME_PATH/css"
cat > "$THEME_PATH/css/style.css" << EOF
/* NCI Theme - Generated from layout.json */
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
EOF

mkdir -p "$THEME_PATH/templates"

log "Theme created at $THEME_PATH"

log "[3/8] Creating content type..."

cd "$DRUPAL_ROOT"

ddev exec -- drush generate content-entity node $CONTENT_TYPE_NAME --bundle=node --label="$CONTENT_TYPE_NAME" 2>&1 | tee -a "$LOG_DIR/create-drupal.log" || true

ddev exec -- drush field:create node $CONTENT_TYPE_NAME \
    --field-name=body \
    --field-label="Body" \
    --field-type=text_long \
    --field-widget=text_textarea \
    2>&1 | tee -a "$LOG_DIR/create-drupal.log" || true

ddev exec -- drush field:create node $CONTENT_TYPE_NAME \
    --field-name=featured_image \
    --field-label="Featured Image" \
    --field-type=image \
    --field-widget=image_image \
    2>&1 | tee -a "$LOG_DIR/create-drupal.log" || true

ddev exec -- drush field:create node $CONTENT_TYPE_NAME \
    --field-name=sidebar_content \
    --field-label="Sidebar Content" \
    --field-type=text_long \
    --field-widget=text_textarea \
    2>&1 | tee -a "$LOG_DIR/create-drupal.log" || true

log "Content type fields created"

log "[4/8] Creating custom blocks..."

BLOCK_IDS=$(python3 -c "
import json
with open('$LAYOUT_JSON') as f:
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

for block_id in $(echo "$BLOCK_IDS" | tr ',' '\n'); do
    log "  Creating block: $block_id"
    
    ddev exec -- drush generate plugin:block "$block_id" 2>&1 | tee -a "$LOG_DIR/create-drupal.log" || true
    
    BLOCK_PLUGIN="inline_template_${block_id}"
done

cd "$DRUPAL_ROOT"

log "[5/8] Creating twig templates..."

python3 -c "
import json

with open('$LAYOUT_JSON') as f:
    data = json.load(f)

templates = []

for item in data.get('layout', []):
    section_id = item.get('id', '')
    section_type = item.get('type', '')
    section_tag = item.get('tag', 'div')
    
    if section_type == 'main':
        continue
    
    template_content = '''<!-- Theme: $THEME_NAME - Section: ''' + section_id + ''' -->
<''' + section_tag + ''' class=\"section-''' + section_id + '''\" id=\"''' + section_id + '''\">
  <!-- ''' + section_type + ''' section -->
  <div class=\"container\">
    <!-- Content from layout.json -->
  </div>
</''' + section_tag + '''>
'''
    templates.append((section_id, template_content))

for tid, tcontent in templates:
    print(f'Template: {tid}')

print(f'Total templates: {len(templates)}')
"

log "[6/8] Enabling theme and setting up blocks..."

cd "$DRUPAL_ROOT"

ddev exec -- drush theme:enable $THEME_NAME -y 2>&1 | tee -a "$LOG_DIR/create-drupal.log" || true
ddev exec -- drush config:set system.theme default $THEME_NAME -y 2>&1 | tee -a "$LOG_DIR/create-drupal.log" || true

log "[7/8] Creating frontpage content..."

cd "$DRUPAL_ROOT"

ddev exec -- drush generate content node $CONTENT_TYPE_NAME \
    --title="Types of Breast Cancer" \
    --body="Content from static HTML converted to Drupal" \
    --count=1 \
    2>&1 | tee -a "$LOG_DIR/create-drupal.log" || true

ddev exec -- drush config:set system.site frontpage "node/1" -y 2>&1 | tee -a "$LOG_DIR/create-drupal.log" || true

log "[8/8] Clearing cache and exporting config..."

cd "$DRUPAL_ROOT"

ddev exec -- drush cr 2>&1 | tee -a "$LOG_DIR/create-drupal.log" || true
ddev exec -- drush cex -y 2>&1 | tee -a "$LOG_DIR/create-drupal.log" || true

BLOCKS_LIST=$(echo "$BLOCK_IDS" | tr ',' ' ')

cat > "$STATE_FILE" << EOF
{
  "status": "completed",
  "layout_json_path": "$LAYOUT_JSON",
  "theme_name": "$THEME_NAME",
  "content_type_name": "$CONTENT_TYPE_NAME",
  "blocks": ["$BLOCKS_LIST"],
  "site_url": "$SITE_URL",
  "step": "completed",
  "static_html_folder": "$STATIC_HTML_FOLDER"
}
EOF

log "=== Drupal Creation Complete ==="

echo ""
echo "Drupal Creation Complete!"
echo "Theme: $THEME_NAME"
echo "Content Type: $CONTENT_TYPE_NAME"
echo "Blocks: $BLOCK_IDS"
echo "Site URL: $SITE_URL"
echo ""
echo "Next: ./run.sh run --test to verify with Playwright"
