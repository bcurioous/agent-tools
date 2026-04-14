# Testing Reference

## Overview

Testing ensures the Drupal output matches the original static HTML 100%.

## Test Types

### 1. Layout JSON Validation
Verify layout.json can reproduce the original HTML.

```bash
./scripts/reverse-validate.sh
```

### 2. Playwright Visual Testing
Take screenshots and compare DOM structure.

```bash
./scripts/test-output.sh
```

### 3. DOM Comparison
Compare element counts and structure.

## Playwright Setup

### Installation

```bash
npm init -y
npm install playwright
npx playwright install chromium
```

### Basic Test Script

```javascript
const { chromium } = require('playwright');

(async () => {
    const browser = await chromium.launch();
    const page = await browser.newPage();
    
    await page.goto('http://example.com');
    await page.screenshot({ path: 'screenshot.png', fullPage: true });
    
    const title = await page.title();
    console.log(`Title: ${title}`);
    
    await browser.close();
})();
```

## DOM Comparison

### What to Compare

| Element | Expected |
|---------|----------|
| h1 | "Types of Breast Cancer" |
| nav li | 6 items |
| sidebar li | 19 items |
| footer h3 | 4 columns |
| images | All referenced |

### Python Comparison Script

```python
import re

def count_elements(html_content):
    return {
        'links': len(re.findall(r'<a ', html_content)),
        'images': len(re.findall(r'<img ', html_content)),
        'divs': len(re.findall(r'<div', html_content)),
        'uls': len(re.findall(r'<ul', html_content)),
        'lis': len(re.findall(r'<li', html_content)),
    }

original = open('index.html').read()
generated = open('generated.html').read()

orig_counts = count_elements(original)
gen_counts = count_elements(generated)

print("Original:", orig_counts)
print("Generated:", gen_counts)

if orig_counts == gen_counts:
    print("MATCH!")
else:
    print("DIFFERENCES:", {k: v for k, v in orig_counts.items() if orig_counts[k] != gen_counts[k]})
```

## Visual Comparison

### Screenshot Comparison

1. Take screenshot of original HTML (file:// URL)
2. Take screenshot of Drupal site
3. Compare visually

### CLI Comparison

```bash
# Install screenshot comparison tool
npm install -g pixelmatch

pixelmatch screenshot1.png screenshot2.png diff.png
```

## Test Run

### Full Test Workflow

```bash
# 1. Run the tool
./run.sh run /path/to/static/html

# 2. Reverse validate
./scripts/reverse-validate.sh

# 3. Test Drupal output
./scripts/test-output.sh

# 4. Compare results
diff original.html generated.html
```

### Test Results Format

```
=== Test Results ===
Date: 2026-04-14

[1/3] Layout JSON Validation
  Status: PASS
  Sections: 8
  Reversible: true

[2/3] DOM Structure Comparison
  Links: PASS (orig: 45, gen: 45)
  Images: PASS (orig: 8, gen: 8)
  DIVs: PASS (orig: 120, gen: 120)

[3/3] Playwright Test
  Status: PASS
  Screenshots: saved to logs/
  Errors: None
```

## Iteration Process

If tests fail:

1. Review test output in `logs/`
2. Check which section doesn't match
3. Fix layout.json or twig template
4. Re-run tests
5. Repeat until 100% match

## Log Files

| Test | Log File |
|------|----------|
| HTML Analysis | `logs/analyze-html.log` |
| Drupal Creation | `logs/create-drupal.log` |
| Reverse Validation | `logs/reverse-validate.log` |
| Playwright Test | `logs/test-output.log` |
| OpenCode Analysis | `logs/opencode-analysis.log` |
| Tool Overall | `logs/tool.log` |

## Validation Criteria

### 100% Match Requirements

- [ ] All body DOM elements present
- [ ] All CSS classes match exactly
- [ ] All images loaded
- [ ] All links correct
- [ ] Navigation items correct
- [ ] Sidebar items correct
- [ ] Footer columns correct
- [ ] Typography matches
- [ ] Colors match

### Visual Checkpoints

1. **Header**: Government banner + Logo + Search
2. **Navigation**: 6 nav items with icons
3. **Sidebar**: 19 items with proper indentation
4. **Main Content**: H1, breadcrumb, featured image, paragraphs
5. **Footer**: 4 columns + sign up form
6. **Back to Top**: Button in bottom-right

## Debugging Failed Tests

### Common Issues

1. **Missing images**: Check asset paths in layout.json
2. **Wrong CSS**: Verify Tailwind classes match
3. **Missing elements**: Check template rendering
4. **Encoding issues**: Ensure UTF-8 throughout

### Debug Steps

```bash
# 1. Check logs
cat logs/test-output.log

# 2. Compare HTML manually
diff index.html generated.html

# 3. Check browser console
# Open DevTools in browser

# 4. Verify Drupal render
ddev exec -- drush wind bug
```
