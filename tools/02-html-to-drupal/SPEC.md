---
name: html-to-drupal
version: "1.0.0"
description: "Analyzes static HTML and generates Drupal 11 site with content types, blocks, twig templates, and views from layout.json"
type: tool

metadata:
  author: dev-team
  created: 2026-04-14
  tags: [drupal, html, layout, blocks, twig, content-type, static-analysis]
  compatibility:
    drupal: "^11.0"
    ddev: "^1.23"
    opencode: ">=0.1.0"

manifest:
  command: ./run.sh
  interface:
    - run
    - query
    - verify
    - help
  permissions:
    - filesystem:read
    - filesystem:write
    - ddev:all
    - drush:all
    - opencode:all

dependencies:
  required:
    - ddev
    - docker
    - drush
    - opencode
  optional:
    - playwright
    - mmx

references:
  - references/opencode-analysis.md
  - references/drupal-creation.md
  - references/testing.md
---

# HTML to Drupal Tool

## Mandate

Analyze static HTML files, generate a layout.json specification, create Drupal 11 content types, blocks, block layouts, twig templates, and views based on the layout. Test the output against the original HTML for 100% match.

## Core Responsibilities

1. **HTML Analysis** - Use OpenCode CLI to dynamically analyze HTML structure
2. **Layout JSON Generation** - Create layout.json from HTML analysis
3. **Reverse Engineering Validation** - Verify layout.json can reproduce original HTML
4. **Drupal Content Types** - Create content types based on layout structure
5. **Drupal Blocks** - Create custom blocks for each layout section
6. **Block Layout** - Configure block placements
7. **Twig Templates** - Create templates matching the original HTML/CSS
8. **Views** - Create views for list/grid displays
9. **Visual Testing** - Use Playwright to verify 100% match with original

## Interface Contract

### run

Executes the full HTML to Drupal conversion:

**Parameters:**
- `STATIC_HTML_FOLDER` - Path to folder containing index.html (required)
- `OPENCODE_SESSION_NAME` - Name for OpenCode analysis session (optional)
- `THEME_NAME` - Name for the Drupal theme to create (default: nci_theme)
- `CONTENT_TYPE_NAME` - Name for the main content type (default: cancer_content)

**Steps:**
1. Validate static HTML folder and find index.html
2. Log to intermediate file (not terminal stdout)
3. Launch OpenCode CLI to analyze HTML structure
4. Generate layout.json from analysis
5. Validate layout.json by reverse-engineering to HTML
6. Create Drupal theme
7. Create content types
8. Create blocks from layout sections
9. Configure block layout
10. Create twig templates
11. Create views
12. Create frontpage node
13. Test with Playwright

**Time Estimate:** 15-30 minutes depending on HTML complexity

### query

| Query | Returns | Description |
|-------|---------|-------------|
| health | healthy/unhealthy | All dependencies status |
| status | ready/busy/error/not_ready | Current state |
| state | KEY:VALUE dump | Full state |
| layout_json | path | Path to generated layout.json |
| theme | theme name | Created theme |
| content_type | content type name | Created content type |
| blocks | list | Created blocks |
| site_url | URL | Drupal site URL |

### verify

Self-verification checks:
1. Static HTML folder exists
2. OpenCode CLI is available
3. DDEV is running
4. Drupal is accessible
5. All scripts are present

## Inputs

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| STATIC_HTML_FOLDER | Yes | - | Path to HTML folder |
| OPENCODE_SESSION_NAME | No | "html-analysis" | OpenCode session name |
| THEME_NAME | No | "nci_theme" | Drupal theme name |
| CONTENT_TYPE_NAME | No | "cancer_content" | Main content type |
| DRUPAL_SETUP_TOOL | No | "../01-drupal-setup" | Path to drupal-setup tool |

## Outputs

| Output | Example |
|--------|---------|
| layout_json_path | /path/to/layout.json |
| theme_name | nci_theme |
| content_type | cancer_content |
| blocks | government-banner, header, main-content, footer |
| site_url | https://drupal11-dev.ddev.site |
| frontpage_nid | 1 |

## Layout JSON Specification

The generated layout.json follows this structure:

```json
{
  "meta": {
    "sourceFile": "index.html",
    "description": "...",
    "reversible": true,
    "version": "1.0"
  },
  "layout": [
    {
      "id": "section-id",
      "type": "section-type",
      "tag": "html-tag",
      "attrs": { "class": "..." },
      "container": { ... },
      "children": [ ... ],
      "repeatable": false,
      "items": [ ... ],
      "itemTemplate": { ... }
    }
  ],
  "symbols": {
    "iconName": "./public/assets/icon.svg"
  },
  "styles": {
    "fonts": { "heading": "Merriweather", "body": "Source Sans 3" },
    "colors": { "primary": "#005ea2", ... }
  }
}
```

## Drupal Component Mapping

| Layout Section | Drupal Component |
|----------------|-----------------|
| government-banner | Custom block + block placement |
| header | Custom block or theme header region |
| main-navigation | Menu block |
| sidebar | Block region + menu block |
| main-content | Node content type + view mode |
| footer | Custom block + block placement |
| back-to-top | Custom block |

## Inter-Tool Communication

This tool depends on `01-drupal-setup` for the Drupal environment:

```bash
# Check if Drupal is ready
../01-drupal-setup/run.sh query health

# Get site URL
../01-drupal-setup/run.sh query site_url
```

## Validation Criteria

### Layout JSON Validation
- All layout sections present
- All HTML tags match original
- All CSS classes preserved
- All images/assets referenced
- Reverse engineer produces identical body DOM

### CSS Framework Detection (MANDATORY)
The tool MUST detect the CSS framework from source HTML:
- Check `<script>` tags for Tailwind CDN (`tailwindcss`, `@tailwindcss/browser`)
- Check `<link>` tags for Bootstrap CDN
- Check for custom CSS files
- Store detected CSS framework in state.json

### Template Strategy (MANDATORY)
1. **DO NOT** put content directly in `page.html.twig` - this breaks all non-front pages
2. **Create** `page--front.html.twig` for frontpage with full static content
3. **Create** `page.html.twig` with header/footer ONLY, delegate to `{{ page.content }}`
4. **Test** `/user/login` returns 200 with login form (not access denied)

### Drupal Output Validation (MANDATORY)
Run these tests after theme creation - FAIL if any fails:

```bash
# 1. Critical pages must return 200
curl -s -o /dev/null -w "%{http_code}" http://SITE_URL/user/login
# Expected: 200

# 2. Login form must be present (not access denied)
curl -s http://SITE_URL/user/login | grep -q "username"
# Expected: 0 (success)

# 3. Frontpage must show NCI content (not Drupal default)
curl -s http://SITE_URL | grep -q "NATIONAL CANCER INSTITUTE"
# Expected: 0 (success)

# 4. CSS framework must be included
grep -q "tailwindcss" themes/custom/THEME/templates/html.html.twig
# Expected: 0 (success)
```

### DOM Comparison Test
The `dom-compare.sh` script validates:
- **EXTRA elements** in Drupal (not in source) - FAIL if found
- **MISSING elements** from Drupal (in source but not rendered) - FAIL if found
- **CSS class compatibility** with detected framework - FAIL if incompatible classes found

### Playwright Visual Test
- Capture screenshot of frontpage
- Capture screenshot of /user/login
- Compare against reference if available

## Guiding Principles

1. **Reversibility** - layout.json must be able to reproduce original HTML
2. **Idempotency** - Running twice = same result as once
3. **Fail Fast** - Stop on error, don't continue broken
4. **Human-Readable Logs** - Log to files, not stdout
5. **100% Match** - Visual testing must confirm perfect reproduction
