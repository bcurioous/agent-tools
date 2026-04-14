#!/bin/bash
#
# DOM Comparison Harness for HTML-to-Drupal
# Compares source HTML against Drupal output to detect:
# 1. MISSING elements (in Drupal but not source)
# 2. EXTRA elements (in Drupal but not source) <- THIS WAS MISSING!
# 3. CSS class mismatches
# 4. CSS framework validation
#

set -e

TOOL_NAME="html-to-drupal"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$TOOL_DIR/../../.." && pwd)}"
TOOL_SHARED_ROOT="${TOOL_SHARED_ROOT:-$PROJECT_ROOT/workspace/$TOOL_NAME}"
LOG_DIR="$TOOL_SHARED_ROOT/logs"
STATE_FILE="$TOOL_SHARED_ROOT/state.json"
DRUPAL_SETUP_TOOL="${DRUPAL_SETUP_TOOL:-$PROJECT_ROOT/tools/01-drupal-setup}"

mkdir -p "$LOG_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_DIR/dom-comparison.log"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" | tee -a "$LOG_DIR/dom-comparison.log"
}

log_warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARN: $1${NC}" | tee -a "$LOG_DIR/dom-comparison.log"
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] OK: $1${NC}" | tee -a "$LOG_DIR/dom-comparison.log"
}

load_state() {
    if [ -f "$STATE_FILE" ]; then
        SITE_URL=$(python3 -c "import json; print(json.load(open('$STATE_FILE')).get('site_url', ''))" 2>/dev/null)
        STATIC_HTML_FOLDER=$(python3 -c "import json; print(json.load(open('$STATE_FILE')).get('static_html_folder', ''))" 2>/dev/null)
        CSS_FRAMEWORK=$(python3 -c "import json; print(json.load(open('$STATE_FILE')).get('css_framework', 'unknown'))" 2>/dev/null)
    fi
    
    if [ -z "$SITE_URL" ]; then
        SITE_URL=$("$DRUPAL_SETUP_TOOL/run.sh" query site_url 2>/dev/null | grep "^SITE_URL:" | cut -d: -f2-)
    fi
    
    if [ -z "$CSS_FRAMEWORK" ] || [ "$CSS_FRAMEWORK" = "unknown" ]; then
        CSS_FRAMEWORK="tailwind"  # Default to Tailwind
    fi
}

load_state

INDEX_FILE="$STATIC_HTML_FOLDER/index.html"
if [ ! -f "$INDEX_FILE" ]; then
    INDEX_FILE="$STATIC_HTML_FOLDER/index.htm"
fi

log "=== DOM Comparison Harness ==="
log "Reference HTML: $INDEX_FILE"
log "Drupal URL: $SITE_URL"
log "CSS Framework: $CSS_FRAMEWORK"

# =====================================================================
# STEP 1: Detect CSS Framework from source HTML
# =====================================================================
log "[1/6] Detecting CSS framework from source HTML..."

detect_css_framework() {
    if [ ! -f "$INDEX_FILE" ]; then
        echo "unknown"
        return
    fi
    
    # Check for Tailwind
    if grep -q "tailwindcss" "$INDEX_FILE" 2>/dev/null; then
        echo "tailwind"
        return
    fi
    
    # Check for Bootstrap
    if grep -q "bootstrap" "$INDEX_FILE" 2>/dev/null; then
        echo "bootstrap"
        return
    fi
    
    # Check for custom CSS
    if grep -q "<link.*\.css" "$INDEX_FILE" 2>/dev/null; then
        echo "custom"
        return
    fi
    
    echo "unknown"
}

DETECTED_CSS=$(detect_css_framework)
log "Detected CSS framework: $DETECTED_CSS"

# =====================================================================
# STEP 2: Capture Drupal DOM via Playwright
# =====================================================================
log "[2/6] Capturing Drupal DOM via Playwright..."

DRUPAL_DOM_FILE="$LOG_DIR/drupal-dom.json"

cat > "$LOG_DIR/capture-drupal-dom.js" << 'EOF'
const { chromium } = require('playwright');

(async () => {
    const url = process.argv[2];
    const outputPath = process.argv[3];
    
    const browser = await chromium.launch();
    const page = await browser.newPage();
    
    await page.goto(url, { timeout: 30000 });
    
    // Get full DOM as JSON
    const body = await page.evaluate(() => {
        const body = document.body;
        return getDomTree(body);
    });
    
    // Get visible text content
    const visibleText = await page.evaluate(() => {
        const el = document.body;
        const style = window.getComputedStyle(el);
        return el.innerText || el.textContent || '';
    });
    
    // Get all elements count
    const elementCount = await page.evaluate(() => document.body.querySelectorAll('*').length);
    
    // Get all classes used
    const allClasses = await page.evaluate(() => {
        const classes = new Set();
        document.body.querySelectorAll('[class]').forEach(el => {
            el.classList.forEach(c => classes.add(c));
        });
        return Array.from(classes);
    });
    
    const result = {
        url: url,
        timestamp: new Date().toISOString(),
        elementCount: elementCount,
        visibleTextLength: visibleText.length,
        classes: allClasses,
        body: body
    };
    
    const fs = require('fs');
    fs.writeFileSync(outputPath, JSON.stringify(result, null, 2));
    
    console.log(`DOM captured: ${elementCount} elements, ${allClasses.length} unique classes`);
    
    await browser.close();
})();

function getDomTree(element, depth = 0) {
    if (depth > 20) return null; // Limit depth
    
    const node = {
        tag: element.tagName ? element.tagName.toLowerCase() : null,
        id: element.id || null,
        classes: element.className && typeof element.className === 'string' ? element.className.split(' ').filter(c => c) : [],
        attrs: {},
        text: null,
        children: []
    };
    
    // Get important attributes
    for (const attr of element.attributes || []) {
        if (['href', 'src', 'alt', 'title', 'placeholder'].includes(attr.name)) {
            node.attrs[attr.name] = attr.value;
        }
    }
    
    // Get text content (only direct text, not children's text)
    if (element.childNodes.length === 1 && element.childNodes[0].nodeType === Node.TEXT_NODE) {
        node.text = element.childNodes[0].textContent.trim();
    }
    
    // Process children
    for (const child of element.childNodes) {
        if (child.nodeType === Node.ELEMENT_NODE) {
            const childNode = getDomTree(child, depth + 1);
            if (childNode) {
                node.children.push(childNode);
            }
        }
    }
    
    return node;
}
EOF

if [ -f "$LOG_DIR/capture-drupal-dom.js" ]; then
    node "$LOG_DIR/capture-drupal-dom.js" "$SITE_URL" "$DRUPAL_DOM_FILE" >> "$LOG_DIR/dom-comparison.log" 2>&1 || {
        log_error "Failed to capture Drupal DOM"
        exit 1
    }
fi

# =====================================================================
# STEP 3: Parse source HTML
# =====================================================================
log "[3/6] Parsing source HTML..."

SOURCE_ELEMENTS_FILE="$LOG_DIR/source-elements.json"

python3 << PYEOF > "$SOURCE_ELEMENTS_FILE"
import re
import json
from html.parser import HTMLParser

class Element:
    def __init__(self, tag, classes=None, attrs=None, text=None):
        self.tag = tag.lower() if tag else None
        self.classes = classes or []
        self.attrs = attrs or {}
        self.text = text
        self.children = []
        self.id = None
        
    def to_dict(self):
        return {
            'tag': self.tag,
            'id': self.id,
            'classes': self.classes,
            'attrs': self.attrs,
            'text': self.text[:50] if self.text else None,  # Truncate text
            'children': [c.to_dict() if isinstance(c, Element) else c for c in self.children]
        }

class DOMParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.root = Element('root')
        self.stack = [self.root]
        
    def handle_starttag(self, tag, attrs):
        attrs_dict = dict(attrs)
        classes = attrs_dict.get('class', '').split() if 'class' in attrs_dict else []
        elem = Element(tag, classes=classes, attrs=attrs_dict)
        
        if 'id' in attrs_dict:
            elem.id = attrs_dict['id']
            
        self.stack[-1].children.append(elem)
        self.stack.append(elem)
        
    def handle_endtag(self, tag):
        if self.stack[-1].tag == tag:
            self.stack.pop()
            
    def handle_data(self, data):
        text = data.strip()
        if text and len(self.stack) > 1:
            current = self.stack[-1]
            if current.text is None:
                current.text = text
            else:
                current.text += ' ' + text

with open('$INDEX_FILE', 'r') as f:
    html = f.read()

# Remove script and style tags content
html = re.sub(r'<script[^>]*>.*?</script>', '', html, flags=re.DOTALL)
html = re.sub(r'<style[^>]*>.*?</style>', '', html, flags=re.DOTALL)

parser = DOMParser()
parser.feed(html)

result = parser.root.to_dict()
result['element_count'] = sum(1 for _ in re.findall(r'<(?!/)(script|style)[^>]*>', html))
result['classes'] = list(set(re.findall(r'class=["\']([^"\']+)["\']', html)))

print(json.dumps(result, indent=2))
PYEOF

log "Source HTML parsed"

# =====================================================================
# STEP 4: Extract and compare elements
# =====================================================================
log "[4/6] Extracting and comparing elements..."

COMPARISON_REPORT="$LOG_DIR/comparison-report.txt"

python3 << 'PYEOF' > "$COMPARISON_REPORT"
import json

# Load source and Drupal DOM
with open('$SOURCE_ELEMENTS_FILE') as f:
    source = json.load(f)

with open('$DRUPAL_DOM_FILE') as f:
    drupal = json.load(f)

report = []
report.append("=" * 60)
report.append("DOM COMPARISON REPORT")
report.append("=" * 60)
report.append("")

# Helper to flatten tree to list of elements
def flatten_tree(node, elements=None):
    if elements is None:
        elements = []
    if node.get('tag') and node.get('tag') != 'root':
        elements.append({
            'tag': node.get('tag'),
            'id': node.get('id'),
            'classes': node.get('classes', []),
            'attrs': {k: v for k, v in node.get('attrs', {}).items() if k in ['href', 'src', 'alt']},
            'text': node.get('text')
        })
    for child in node.get('children', []):
        flatten_tree(child, elements)
    return elements

# Helper to find element by tag in list
def find_by_tag(tag, elements):
    return [e for e in elements if e['tag'] == tag]

# Get all elements
source_elements = flatten_tree(source)
drupal_elements = flatten_tree(drupal)

# Count by tag
source_tags = {}
drupal_tags = {}

for e in source_elements:
    tag = e['tag']
    source_tags[tag] = source_tags.get(tag, 0) + 1

for e in drupal_elements:
    tag = e['tag']
    drupal_tags[tag] = drupal_tags.get(tag, 0) + 1

report.append("ELEMENT COUNT COMPARISON:")
report.append("-" * 40)

all_tags = set(source_tags.keys()) | set(drupal_tags.keys())
for tag in sorted(all_tags):
    src_count = source_tags.get(tag, 0)
    drup_count = drupal_tags.get(tag, 0)
    status = "OK" if src_count == drup_count else "DIFF"
    if src_count != drup_count:
        status = f"MISSING" if drup_count < src_count else "EXTRA"
    report.append(f"  <{tag}>: Source={src_count}, Drupal={drup_count} [{status}]")

report.append("")

# Check for EXTRA elements in Drupal (NOT in source)
report.append("EXTRA ELEMENTS IN DRUPAL (not in source):")
report.append("-" * 40)

# Known Drupal extras that are OK
KNOWN_DRUPAL_EXTRAS = [
    'skip-link',  # Drupal's accessibility skip link
]

source_tags_texts = set()
for e in source_elements:
    key = f"{e['tag']}:{e.get('text', '')[:30] if e.get('text') else ''}"
    source_tags_texts.add(key)

drupal_extras = []
for e in drupal_elements:
    text_key = f"{e['tag']}:{e.get('text', '')[:30] if e.get('text') else ''}"
    # Check if this exact element exists in source
    if text_key not in source_tags_texts:
        # Check if it's a known Drupal extra
        if e['tag'] == 'a' and 'skip' in str(e.get('text', '')).lower():
            if 'skip-link' not in [ex.get('id', '') for ex in drupal_extras]:
                drupal_extras.append({'tag': e['tag'], 'text': e.get('text'), 'issue': 'Drupal accessibility skip link - should use sr-only class'})

if drupal_extras:
    for extra in drupal_extras:
        report.append(f"  <{extra['tag']}>: '{extra['text']}'")
        report.append(f"    -> {extra['issue']}")
else:
    report.append("  None found")

report.append("")

# Check for MISSING elements
report.append("MISSING ELEMENTS IN DRUPAL (in source but not rendered):")
report.append("-" * 40)

drupal_texts = set()
for e in drupal_elements:
    key = f"{e['tag']}:{e.get('text', '')[:30] if e.get('text') else ''}"
    drupal_texts.add(key)

missing = []
for e in source_elements:
    text_key = f"{e['tag']}:{e.get('text', '')[:30] if e.get('text') else ''}"
    if text_key not in drupal_texts:
        missing.append(e)

if missing:
    for m in missing[:10]:  # Limit to first 10
        report.append(f"  <{m['tag']}>: '{m.get('text', '')[:50]}'")
else:
    report.append("  None found")

report.append("")

# CSS Class validation
report.append("CSS CLASS VALIDATION:")
report.append("-" * 40)

source_classes = set(source.get('classes', []))
drupal_classes = set(drupal.get('classes', []))

# Tailwind-specific validation
tailwind_indicator_classes = ['flex', 'grid', 'block', 'inline', 'hidden', 'visible', 'relative', 'absolute', 'fixed']

valid_tailwind_classes = set()
invalid_classes = []

for cls in drupal_classes:
    # Skip Drupal internal classes
    if cls.startswith('js-') or cls.startswith('is-') or cls.startswith('has-'):
        continue
    if cls in ['visually-hidden', 'focusable']:  # These are Drupal classes, not Tailwind
        invalid_classes.append((cls, 'Drupal class not compatible with Tailwind - use sr-only'))
        continue
    # Check if it looks like a Tailwind class but might not exist
    if any(cls.startswith(prefix) for prefix in ['flex-', 'grid-', 'text-', 'bg-', 'p-', 'm-', 'w-', 'h-', 'border', 'font-', 'item-', 'justify-', 'self-', 'absolute', 'fixed', 'relative']):
        valid_tailwind_classes.add(cls)

if invalid_classes:
    report.append("INVALID CLASSES FOUND:")
    for cls, reason in invalid_classes:
        report.append(f"  '{cls}': {reason}")

if valid_tailwind_classes:
    report.append(f"Valid Tailwind-like classes found: {len(valid_tailwind_classes)}")

report.append("")

# Summary
report.append("=" * 60)
report.append("SUMMARY")
report.append("=" * 60)

tag_diffs = sum(1 for tag in all_tags if source_tags.get(tag, 0) != drupal_tags.get(tag, 0))
extra_count = len(drupal_extras)
missing_count = len(missing)

report.append(f"Tag count differences: {tag_diffs}")
report.append(f"Extra elements: {extra_count}")
report.append(f"Missing elements: {missing_count}")

if extra_count == 0 and missing_count == 0 and tag_diffs == 0:
    report.append("")
    report.append("RESULT: PASS - DOM structures match!")
else:
    report.append("")
    report.append("RESULT: FAIL - Differences detected")

print('\n'.join(report))
PYEOF

cat "$COMPARISON_REPORT"

# =====================================================================
# STEP 5: Validate CSS Framework
# =====================================================================
log "[5/6] Validating CSS framework..."

if [ "$DETECTED_CSS" = "tailwind" ]; then
    log "Detected Tailwind CSS - checking for Tailwind CDN in html.html.twig..."
    
    HTML_TWIG="$PROJECT_ROOT/workspace/drupal-setup/web/themes/custom/nci_theme/templates/html.html.twig"
    
    if [ -f "$HTML_TWIG" ]; then
        if grep -q "tailwindcss/browser" "$HTML_TWIG" 2>/dev/null; then
            log_success "Tailwind CDN found in html.html.twig"
        else
            log_error "Tailwind CDN NOT found in html.html.twig"
            log "  Source HTML uses Tailwind but Drupal theme doesn't include it!"
        fi
        
        if grep -q "sr-only" "$HTML_TWIG" 2>/dev/null; then
            log_success "sr-only class found (Tailwind-compatible)"
        elif grep -q "visually-hidden" "$HTML_TWIG" 2>/dev/null; then
            log_warn "visually-hidden class found - NOT a Tailwind class, use sr-only instead"
        fi
    fi
fi

# =====================================================================
# STEP 6: Final verdict
# =====================================================================
log "[6/6] Final verdict..."

if grep -q "RESULT: PASS" "$COMPARISON_REPORT"; then
    log_success "DOM comparison PASSED"
    exit 0
else
    log_error "DOM comparison FAILED - see report above"
    log "Review $COMPARISON_REPORT for details"
    exit 1
fi
