#!/bin/bash
set -e

TOOL_NAME="html-to-drupal"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$TOOL_DIR/../../.." && pwd)}"
TOOL_SHARED_ROOT="${TOOL_SHARED_ROOT:-$PROJECT_ROOT/workspace/$TOOL_NAME}"
LOG_DIR="$TOOL_SHARED_ROOT/logs"
STATE_FILE="$TOOL_SHARED_ROOT/state.json"

mkdir -p "$LOG_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_DIR/reverse-validate.log"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$LOG_DIR/reverse-validate.log"
}

cd "$TOOL_DIR"

log "=== Starting Reverse Validation ==="

load_state() {
    if [ -f "$STATE_FILE" ]; then
        LAYOUT_JSON=$(python3 -c "import json; print(json.load(open('$STATE_FILE')).get('layout_json_path', ''))" 2>/dev/null)
        STATIC_HTML_FOLDER=$(python3 -c "import json; print(json.load(open('$STATE_FILE')).get('static_html_folder', ''))" 2>/dev/null)
    fi
    LAYOUT_JSON="${LAYOUT_JSON:-$TOOL_SHARED_ROOT/layout.json}"
}

load_state

if [ ! -f "$LAYOUT_JSON" ]; then
    log_error "layout.json not found"
    exit 1
fi

INDEX_FILE="$STATIC_HTML_FOLDER/index.html"
if [ ! -f "$INDEX_FILE" ]; then
    INDEX_FILE="$STATIC_HTML_FOLDER/index.htm"
fi

if [ ! -f "$INDEX_FILE" ]; then
    log_error "index.html not found in $STATIC_HTML_FOLDER"
    exit 1
fi

log "Layout JSON: $LAYOUT_JSON"
log "Index HTML: $INDEX_FILE"

log "[1/4] Parsing layout.json..."

python3 << 'PYEOF' | tee -a /tmp/reverse-validate-output.txt
import json
import sys

with open('$LAYOUT_JSON') as f:
    data = json.load(f)

layout = data.get('layout', [])
meta = data.get('meta', {})
symbols = data.get('symbols', {})
styles = data.get('styles', {})

print(f"Sections: {len(layout)}")
print(f"Reversible: {meta.get('reversible', False)}")
print(f"Source: {meta.get('sourceFile', 'unknown')}")
print()

for i, item in enumerate(layout):
    print(f"{i+1}. {item.get('id', 'unknown')}")
    print(f"   Type: {item.get('type', 'unknown')}")
    print(f"   Tag: {item.get('tag', 'div')}")
    if 'children' in item:
        print(f"   Children: {len(item['children'])}")
    if 'container' in item:
        print(f"   Has container")
    if 'repeatable' in item:
        print(f"   Repeatable: {item['repeatable']}")
    print()

print("Symbols (assets):")
for k, v in symbols.items():
    print(f"  {k}: {v}")

print()
print("Styles:")
print(f"  Fonts: {styles.get('fonts', {})}")
print(f"  Colors: {styles.get('colors', {})}")
PYEOF

log "[2/4] Reading original index.html..."

BODY_CONTENT=$(python3 << 'PYEOF'
from html.parser import HTMLParser
import re

class BodyExtractor(HTMLParser):
    def __init__(self):
        super().__init__()
        self.in_body = False
        self.body_content = []
        self.skip_tags = {'meta', 'link', 'script', 'style', 'noscript'}
        
    def handle_starttag(self, tag, attrs):
        if tag == 'body':
            self.in_body = True
        if self.in_body and tag not in self.skip_tags:
            attrs_str = ''.join(f' {k}="{v}"' for k, v in attrs)
            self.body_content.append(f'<{tag}{attrs_str}>')
            
    def handle_endtag(self, tag):
        if tag == 'body':
            self.in_body = False
        if self.in_body and tag not in self.skip_tags:
            self.body_content.append(f'</{tag}>')
            
    def handle_data(self, data):
        if self.in_body:
            data = data.strip()
            if data:
                self.body_content.append(data)

with open('$INDEX_FILE', 'r') as f:
    content = f.read()

parser = BodyExtractor()
parser.feed(content)

body = parser.body_content
print(f"Body elements count: {len(body)}")

links_count = content.count('<a ')
images_count = content.count('<img ')
divs_count = content.count('<div')
uls_count = content.count('<ul')
lis_count = content.count('<li')

print(f"Links: {links_count}")
print(f"Images: {images_count}")
print(f"DIVs: {divs_count}")
print(f"ULs: {uls_count}")
print(f"LIs: {lis_count}")
PYEOF
)

log "$BODY_CONTENT"

log "[3/4] Comparing structure..."

python3 << 'PYEOF'
import json

with open('$LAYOUT_JSON') as f:
    data = json.load(f)

layout = data.get('layout', [])

required_sections = [
    'government-banner',
    'header',
    'main-content',
    'footer'
]

missing = []
for section in required_sections:
    found = any(item.get('id') == section for item in layout)
    if not found:
        missing.append(section)

if missing:
    print(f"MISSING sections: {missing}")
else:
    print("All required sections found")

print()
print("Layout section IDs:")
for item in layout:
    print(f"  - {item.get('id')}: {item.get('type')}")
PYEOF

log "[4/4] Generating HTML from layout.json..."

GENERATED_HTML="$TOOL_SHARED_ROOT/index-generated.html"

python3 << PYEOF > "$GENERATED_HTML"
import json
import sys

def render_layout_item(item, indent=0):
    tag = item.get('tag', 'div')
    attrs = item.get('attrs', {})
    children = item.get('children', [])
    container = item.get('container')
    text = item.get('text', '')
    repeatable = item.get('repeatable', False)
    items = item.get('items', [])
    item_template = item.get('itemTemplate', {})
    child = item.get('child')
    
    classes = attrs.get('class', '')
    other_attrs = {k: v for k, v in attrs.items() if k != 'class'}
    
    attr_str = f' class="{classes}"' if classes else ''
    for k, v in other_attrs.items():
        attr_str += f' {k}="{v}"'
    
    lines = []
    lines.append(' ' * indent + f'<{tag}{attr_str}>')
    
    if text:
        lines.append(' ' * (indent + 2) + text)
    
    if container:
        cont_tag = container.get('tag', 'div')
        cont_attrs = container.get('attrs', {})
        cont_classes = cont_attrs.get('class', '')
        cont_attr_str = f' class="{cont_classes}"' if cont_classes else ''
        lines.append(' ' * (indent + 2) + f'<{cont_tag}{cont_attr_str}>')
        
        if 'children' in container:
            for c in container['children']:
                lines.append(render_layout_item(c, indent + 4))
        if 'child' in container:
            lines.append(render_layout_item(container['child'], indent + 4))
        
        lines.append(' ' * (indent + 2) + f'</{cont_tag}>')
    
    if children:
        for c in children:
            lines.append(render_layout_item(c, indent + 2))
    
    if child:
        lines.append(render_layout_item(child, indent + 2))
    
    lines.append(' ' * indent + f'</{tag}>')
    
    return '\n'.join(lines)

with open('$LAYOUT_JSON') as f:
    data = json.load(f)

html_parts = []
html_parts.append('<!DOCTYPE html>')
html_parts.append('<html lang="en">')
html_parts.append('<head>')
html_parts.append('  <meta charset="UTF-8" />')
html_parts.append('  <meta name="viewport" content="width=device-width, initial-scale=1.0" />')
html_parts.append('  <title>Generated from layout.json</title>')
html_parts.append('  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Merriweather:wght@700&family=Source+Sans+3:ital,wght@0,400;0,700;1,400&display=swap" />')
html_parts.append('  <script src="https://cdn.jsdelivr.net/npm/@tailwindcss/browser@4"></script>')
html_parts.append('</head>')
html_parts.append('<body class="min-h-screen bg-white font-[Source_Sans_3] text-[#1b1b1b]">')

for item in data.get('layout', []):
    html_parts.append(render_layout_item(item))

html_parts.append('</body>')
html_parts.append('</html>')

print('\n'.join(html_parts))
PYEOF

log "Generated HTML written to: $GENERATED_HTML"

log "[Compare] Running diff..."

if command -v diff &>/dev/null; then
    DIFF_OUTPUT=$(diff -u "$INDEX_FILE" "$GENERATED_HTML" 2>&1 | head -100 || true)
    if [ -n "$DIFF_OUTPUT" ]; then
        log "Differences found (first 100 lines):"
        echo "$DIFF_OUTPUT" | head -100 >> "$LOG_DIR/reverse-validate.log"
        log "Full diff saved to $LOG_DIR/reverse-validate.log"
    else
        log "No differences found - HTML matches!"
    fi
fi

log "=== Reverse Validation Complete ==="
log "Generated HTML: $GENERATED_HTML"
log "Compare manually: diff $INDEX_FILE $GENERATED_HTML"
