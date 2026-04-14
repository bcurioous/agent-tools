#!/bin/bash
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

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_DIR/test-output.log"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$LOG_DIR/test-output.log"
}

cd "$TOOL_DIR"

log "=== Starting Playwright Testing ==="

load_state() {
    if [ -f "$STATE_FILE" ]; then
        SITE_URL=$(python3 -c "import json; print(json.load(open('$STATE_FILE')).get('site_url', ''))" 2>/dev/null)
        STATIC_HTML_FOLDER=$(python3 -c "import json; print(json.load(open('$STATE_FILE')).get('static_html_folder', ''))" 2>/dev/null)
    fi
    
    if [ -z "$SITE_URL" ]; then
        SITE_URL=$("$DRUPAL_SETUP_TOOL/run.sh" query site_url 2>/dev/null | grep "^SITE_URL:" | cut -d: -f2-)
    fi
}

load_state

if [ -z "$SITE_URL" ]; then
    log_error "Site URL not found"
    exit 1
fi

log "Site URL: $SITE_URL"

INDEX_FILE="$STATIC_HTML_FOLDER/index.html"
if [ ! -f "$INDEX_FILE" ]; then
    INDEX_FILE="$STATIC_HTML_FOLDER/index.htm"
fi

log "Reference HTML: $INDEX_FILE"

log "[1/5] Checking Playwright installation..."

if ! command -v playwright &>/dev/null; then
    log "Playwright not found in PATH, checking npm..."
    if command -v npx &>/dev/null; then
        log "Using npx to run playwright"
        PLAYWRIGHT_CMD="npx playwright"
    else
        log_error "Neither playwright nor npx found"
        exit 1
    fi
else
    PLAYWRIGHT_CMD="playwright"
fi

log "[2/5] Launching browser..."

SCREENSHOT_ORIGINAL="$LOG_DIR/original-index.png"
SCREENSHOT_DRUPAL="$LOG_DIR/drupal-frontpage.png"

if [ -f "$INDEX_FILE" ]; then
    log "Taking screenshot of original HTML..."
    
    cat > "$LOG_DIR/test-original.js" << 'EOF'
const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

(async () => {
    const browser = await chromium.launch();
    const page = await browser.newPage();
    
    const indexPath = process.argv[2];
    await page.goto(`file://${indexPath}`);
    await page.screenshot({ path: process.argv[3], fullPage: true });
    
    const title = await page.title();
    console.log(`Title: ${title}`);
    
    const bodyText = await page.locator('body').textContent();
    console.log(`Body text length: ${bodyText.length}`);
    
    await browser.close();
    console.log('Screenshot saved');
})();
EOF

    if [ -f "$LOG_DIR/test-original.js" ]; then
        node "$LOG_DIR/test-original.js" "$INDEX_FILE" "$SCREENSHOT_ORIGINAL" >> "$LOG_DIR/test-output.log" 2>&1 || true
    fi
fi

log "[3/5] Testing Drupal frontpage..."

cat > "$LOG_DIR/test-drupal.js" << 'EOF'
const { chromium } = require('playwright');

(async () => {
    const url = process.argv[2];
    const screenshotPath = process.argv[3];
    
    console.log(`Opening: ${url}`);
    
    const browser = await chromium.launch();
    const page = await browser.newPage();
    
    try {
        await page.goto(url, { timeout: 30000 });
        console.log('Page loaded');
        
        await page.screenshot({ path: screenshotPath, fullPage: true });
        console.log(`Screenshot saved: ${screenshotPath}`);
        
        const title = await page.title();
        console.log(`Title: ${title}`);
        
        const h1 = await page.locator('h1').first().textContent();
        console.log(`H1: ${h1}`);
        
        const bodyText = await page.locator('body').textContent();
        console.log(`Body text length: ${bodyText.length}`);
        
        const navItems = await page.locator('nav ul li').count();
        console.log(`Nav items: ${navItems}`);
        
        const footerColumns = await page.locator('footer h3').count();
        console.log(`Footer columns: ${footerColumns}`);
        
    } catch (err) {
        console.error(`Error: ${err.message}`);
    }
    
    await browser.close();
})();
EOF

if [ -f "$LOG_DIR/test-drupal.js" ]; then
    node "$LOG_DIR/test-drupal.js" "$SITE_URL" "$SCREENSHOT_DRUPAL" >> "$LOG_DIR/test-output.log" 2>&1 || true
fi

log "[4/5] Comparing DOM structure..."

python3 << 'PYEOF'
import re

try:
    with open('$INDEX_FILE', 'r') as f:
        original = f.read()
    
    links = len(re.findall(r'<a ', original))
    images = len(re.findall(r'<img ', original))
    divs = len(re.findall(r'<div', original))
    uls = len(re.findall(r'<ul', original))
    lis = len(re.findall(r'<li', original))
    h1s = len(re.findall(r'<h1', original))
    h2s = len(re.findall(r'<h2', original))
    
    print("Original HTML structure:")
    print(f"  Links: {links}")
    print(f"  Images: {images}")
    print(f"  DIVs: {divs}")
    print(f"  ULs: {uls}")
    print(f"  LIs: {lis}")
    print(f"  H1s: {h1s}")
    print(f"  H2s: {h2s}")
    
except Exception as e:
    print(f"Error: {e}")
PYEOF

log "[5/5] Running DOM comparison tests..."

python3 << 'PYEOF' | tee -a "$LOG_DIR/test-output.log"
import json

with open('$STATE_FILE') as f:
    state = json.load(f)

layout_json = state.get('layout_json_path', '')
if layout_json:
    with open(layout_json) as f:
        layout = json.load(f)
    
    sections = [item.get('id') for item in layout.get('layout', [])]
    
    print("Layout sections found:")
    for s in sections:
        print(f"  - {s}")
    
    print()
    print("Expected DOM elements from layout.json:")
    for item in layout.get('layout', []):
        tag = item.get('tag', 'div')
        print(f"  <{tag}>: {item.get('id')}")
else:
    print("No layout.json found in state")
PYEOF

log "=== Testing Complete ==="

echo ""
echo "Test screenshots:"
echo "  Original: $SCREENSHOT_ORIGINAL"
echo "  Drupal: $SCREENSHOT_DRUPAL"
echo ""
echo "Review screenshots to verify visual match"
echo "Logs: $LOG_DIR/test-output.log"
