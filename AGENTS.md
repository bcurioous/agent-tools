# Drupal Static-to-CMS Migration Agent Instructions

## MANDATORY SKILL USAGE

**THIS FILE MUST BE LOADED ON EVERY SESSION. USE ONLY THE SKILLS LISTED BELOW. ASK USER BEFORE USING ANY OTHER SKILL.**

### Authorized Skills (MUST use these only)
- `drupal-site-builder` - Drupal site building, content types, fields, views, configuration
- `drupal-expert` - Drupal module development, hooks, services, Twig templates, theming
- `ddev-expert` - DDEV local development environment setup and troubleshooting
- `mmx-cli` - Web search, image understanding, visual analysis
- `playwright-cli` - Browser automation, screenshot comparison, pixel-perfect verification
- `uswds` - USWDS design system for Drupal styling
- `drush` - Drupal CLI commands (integrated with ddev-expert)

---

## TOOL SPECS SYSTEM

### What are Tool Specs?

Tool specs define a **constraint-based tool system** where:
- Tools are **discoverable** via tool-registry.yaml
- Tools are **safe** via LIMITS.md prohibitions
- Tools have a **fixed interface**: `./run.sh run|query|verify|help`
- Tools are **self-documenting** via SPEC.md
- Tools are **standalone bash scripts** - they run directly without OpenCode or any agent harness

### Tool Spec Files

| File | Purpose |
|------|---------|
| `tool-specs/tool-guidelines.md` | Full tool specification system (read this first) |
| `tool-specs/SPEC-template.md` | Template for creating new tools |
| `tool-specs/LIMITS-template.md` | Template for tool prohibitions |
| `tool-specs/QUERY-template.md` | Template for query protocol |
| `tool-specs/run-template.sh` | Fixed CLI harness (copy verbatim) |
| `tool-specs/tool-registry-spec.md` | How to register tools |
| `tool-specs/tool-orchestration-spec.md` | Multi-tool workflows |

### When to Use Tool Specs

| Task | How to Use |
|------|------------|
| Create a new tool | skill-creator + tool-guidelines.md |
| Run a tool (stand-alone) | Direct bash: `./tools/<tool>/run.sh run` |
| Run via OpenCode agent | Agent calls bash directly: `bash ./tools/<tool>/run.sh run` |
| Query tool state | `./tools/<tool>/run.sh query health` |
| Update tool permissions | LIMITS-template.md |
| Register new tool | tool-registry-spec.md |
| Orchestrate multiple tools | tool-orchestration-spec.md |

---

## MIGRATION WORKFLOW

### PHASE 1: Analyze Source HTML Project

**Step 1.1: Load Skills**
```
skill(name="drupal-site-builder")
skill(name="drupal-expert")
skill(name="ddev-expert")
skill(name="uswds")
```

**Step 1.2: Explore Source Structure**
- Analyze static HTML structure (index.html, CSS, JS, assets)
- Identify all pages and their layouts
- Map visual components to Drupal concepts

**Step 1.3: Visual Analysis (if screenshots/mockups provided)**
```bash
# Use mmx-cli for image understanding
mmx vision describe --image <mockup-path> --prompt "Detailed description of layout, components, colors, typography"

# Use playwright-cli for browser-based analysis
playwright-cli open <source-url-or-file>
playwright-cli snapshot
```

**Step 1.4: Document Component Map**

| Static HTML Element | Drupal Equivalent |
|---------------------|------------------|
| Header/nav | Block + Menu |
| Hero section | Custom Block or Paragraph |
| Content area | Node + View Mode |
| Sidebar | Block region |
| Footer | Block region |
| Card component | Paragraph or Custom content type |
| Form | Webform or Contact entity |
| Gallery | Media entity + View |
| Testimonial | Custom content type + View |
| Team section | Custom content type + View |

---

### PHASE 2: Setup Drupal Environment

**Step 2.1: Initialize DDEV Project**

Use ONE of these methods:

**Option A: Using Tool (standalone bash)**
```bash
# Run drupal-setup tool directly (no OpenCode required)
./tools/01-drupal-setup/run.sh

# Or with options
SITE_NAME="My Site" ADMIN_PASS="secret" ./tools/01-drupal-setup/run.sh
```

**Option B: Manual Setup with ddev-expert skill**
```bash
skill(name="ddev-expert")
# Follow ddev-expert workflow for Drupal 11 setup
```

**Step 2.2: Verify Installation**
```bash
ddev drush status
ddev drush cr
ddev launch
```

---

### PHASE 3: Analyze & Plan Drupal Architecture

**Step 3.1: Identify Content Types**

For each distinct content type in the static site:

| Static Content | Drupal Content Type | Fields Needed |
|----------------|---------------------|---------------|
| Blog posts | Article/自定义 | title, body, image, date, author |
| Products | Product | title, body, images, price, SKU |
| Services | Service | title, body, icon, link |
| Team members | Team Member | name, photo, role, bio |
| Testimonials | Testimonial | quote, author, photo |
| FAQ items | FAQ | question, answer |
| Contact info | Basic Page + Paragraphs | various |
| Gallery images | Media + View | image, title, description |

**Step 3.2: Identify Block Regions**

Map static layout sections to Drupal block regions:

```
┌─────────────────────────────────────────────┐
│ HEADER (Logo + Navigation Menu)             │
│   → Block region: Header                   │
│   → Menu: Main navigation                  │
├─────────────────────────────────────────────┤
│ HERO SECTION                                │
│   → Custom Block or Paragraph type          │
├──────────────────────┬──────────────────────┤
│ MAIN CONTENT         │ SIDEBAR              │
│   → Node content     │   → Block region     │
│   → View display    │   → Custom blocks    │
├──────────────────────┴──────────────────────┤
│ FOOTER                                      │
│   → Block region: Footer                   │
│   → Multiple blocks for columns            │
└─────────────────────────────────────────────┘
```

---

### PHASE 4: Build Drupal Components

**Step 4.1: Create Content Types**

Use `drupal-site-builder` skill:

```bash
skill(name="drupal-site-builder")

# Then use drush to create content type
ddev drush generate content-entity
```

**Step 4.2: Create Fields**

```bash
# Use drush field:create for each field
ddev drush field:create node team_member \
  --field-name=field_photo \
  --field-label="Photo" \
  --field-type=image \
  --field-widget=image_image \
  --is-required=1 \
  --cardinality=1
```

**Step 4.3: Export Configuration**
```bash
ddev drush cex -y
```

---

### PHASE 5: Create Block Layout & Regions

**Step 5.1: Define Block Regions (in theme .info.yml)**
```yaml
# themes/custom/mytheme/mytheme.info.yml
regions:
  header: Header
  hero: Hero Section
  content: Main Content
  sidebar: Sidebar
  footer: Footer
```

**Step 5.2: Create Custom Blocks**
```bash
ddev drush generate plugin:block
```

---

### PHASE 6: Build Twig Templates (Theming)

Use `drupal-expert` skill for templates:

```bash
skill(name="drupal-expert")

# Generate theme scaffold
ddev drush generate module
```

Template structure:
```
web/themes/custom/mytheme/
├── templates/
│   ├── page.html.twig
│   ├── node.html.twig
│   └── block/*.html.twig
└── css/components/
```

---

### PHASE 7: Styling with USWDS

Use `uswds` skill for styling:

```bash
skill(name="uswds")
```

Apply USWDS classes and tokens - never hardcode colors/spacing.

---

### PHASE 8: Pixel-Perfect Verification

Use `playwright-cli` and `mmx-cli`:

```bash
# Screenshot comparison
playwright-cli open <drupal-site-url>
playwright-cli screenshot

# Visual analysis
mmx vision --image screenshot.png --prompt "Compare with reference design"
```

---

## SKILL REFERENCE COMMANDS

### drupal-site-builder
```bash
ddev drush generate content-entity
ddev drush field:create node <bundle> --field-name=<name> --field-type=<type>
ddev drush cex -y
ddev drush cim -y
```

### drupal-expert
```bash
ddev drush generate <type>
ddev drush cr
ddev drush updb
ddev drush ws --severity=error
```

### ddev-expert
```bash
ddev start
ddev describe
ddev ssh
ddev mysql
```

### mmx-cli (Web Search & Image Understanding)
```bash
mmx websearch --query "<search query>"
mmx vision --image <path> --prompt "Detailed description"
mmx image generate --prompt "<description>"
```

### playwright-cli (Browser Automation)
```bash
playwright-cli open <url>
playwright-cli snapshot
playwright-cli screenshot
```

### uswds
```scss
@use "uswds-core" with (
  $theme-image-path: '~@uswds/uswds/dist/img',
);
.usa-button {
  @include u-bg('primary');
  @include u-padding-y(2);
}
```

---

## MANDATORY RULES

### ALWAYS DO:
1. **Load skills at session start**: `skill(name="drupal-site-builder")` etc.
2. **Export config after changes**: `ddev drush cex -y`
3. **Clear cache after config import**: `ddev drush cr`
4. **Use USWDS design tokens**: Never hardcode colors/spacing
5. **Follow Drupal naming conventions**: field.storage.node.field_name
6. **Test pixel-perfect**: Use playwright-cli screenshots

### NEVER DO:
1. **Never use skills not listed above** - ask user first
2. **Never manually edit core files** - use configuration
3. **Never skip cache clear** - always `ddev drush cr`
4. **Never hardcode USWDS values** - use tokens
5. **Never ignore mobile-first** - use USWDS responsive prefixes
6. **Never skip accessibility** - use ARIA, semantic HTML

---

## WORKFLOW SUMMARY

```
┌─────────────────────────────────────────────────────────────────────┐
│  1. ANALYZE                                                          │
│     • Explore static HTML structure                                  │
│     • Use mmx-cli vision for mockup analysis                         │
│     • Map components to Drupal concepts                              │
├─────────────────────────────────────────────────────────────────────┤
│  2. SETUP                                                            │
│     • Initialize DDEV project (ddev-expert)                          │
│     • Install Drupal with required modules                           │
│     • Configure environment                                          │
├─────────────────────────────────────────────────────────────────────┤
│  3. BUILD                                                            │
│     • Create content types (drupal-site-builder)                      │
│     • Create fields and configure displays                           │
│     • Build block layout and regions                                 │
│     • Create Twig templates (drupal-expert)                          │
│     • Apply USWDS styling (uswds)                                    │
├─────────────────────────────────────────────────────────────────────┤
│  4. VERIFY                                                           │
│     • Use playwright-cli for screenshots                             │
│     • Compare with mmx-cli vision analysis                           │
│     • Test all functionality                                         │
│     • Check accessibility                                            │
├─────────────────────────────────────────────────────────────────────┤
│  5. DEPLOY                                                           │
│     • Export final configuration                                     │
│     • Document component map                                         │
│     • Provide deployment instructions                                │
└─────────────────────────────────────────────────────────────────────┘
```

---

## WORKSPACE ARCHITECTURE

### Two-Layer Workspace Model

This project uses a **two-layer workspace architecture** for isolation, discoverability, and safe inter-tool communication.

```
nic-drupal/
│
├── workspace/                        # COMMON working area (ALL tools access this)
│   ├── drupal-setup/               # Tool's shared output (tool-name prefix)
│   │   ├── config/                #   Config exports (Drush cex output)
│   │   ├── content/               #   Content exports
│   │   └── data/                  #   Data dumps, SQL exports
│   ├── content-type/               # Another tool's shared space
│   ├── assets/                     # Shared media/uploads
│   ├── exports/                    # Cross-tool exports
│   ├── temp/                       # Shared temp (cleanable)
│   └── logs/                       # Shared logs
│
├── tools/                          # Tool definitions (immutable specs)
│   ├── 01-drupal-setup/
│   │   ├── SPEC.md
│   │   ├── LIMITS.md
│   │   ├── run.sh
│   │   └── workspace/              # Tool's OWN isolated workspace
│   │       ├── cache/             #   Permanent cache
│   │       ├── temp/              #   Tool temp (auto-clean)
│   │       └── output/            #   Tool artifacts
│   └── 02-content-type/
│       └── workspace/
│
└── tool-registry.yaml              # Maps: tool-name → workspace paths
```

### Workspace Path Convention

| Path Pattern | Purpose | Access |
|--------------|---------|--------|
| `workspace/<tool-name>/` | Tool's shared output | All tools (read), Owning tool (write) |
| `tools/<tool-name>/workspace/` | Tool's isolated workspace | Owning tool only |
| `workspace/temp/` | Shared temp files | All tools (cleanable) |
| `workspace/exports/` | Cross-tool exports | All tools |

### Environment Variables (100% Context)

Every session automatically has:

```bash
TOOL_WORKSPACE_ROOT   # Tool's isolated workspace (e.g., tools/01-drupal-setup/workspace)
TOOL_SHARED_ROOT      # Tool's shared output (e.g., workspace/drupal-setup)
DRUPAL_ROOT           # Drupal project (workspace/drupal-setup - the Drupal files)
TOOL_REGISTRY         # Registry path (tool-registry.yaml)
PROJECT_ROOT          # Project root (nic-drupal/)
```

### How Tools Find Each Other's Workspaces

Tools query the registry for workspace paths:

```bash
# Get workspace path for a tool
TOOL_SHARED_ROOT=$(./tool-registry.sh workspace drupal-setup)
# Returns: workspace/drupal-setup

# Get all registered workspaces
./tool-registry.sh workspaces
# Returns: YAML with all workspace mappings
```

### File Naming Conventions

To ensure discoverability:

- **Tool shared output**: `workspace/<tool-name>/<artifact-type>/`
  - Example: `workspace/drupal-setup/config/` for Drupal config exports
  - Example: `workspace/drupal-setup/content/` for content exports

- **Temporary files**: Always use `workspace/temp/` or `tools/<tool>/workspace/temp/`
  - Temp files should be prefixed with tool name: `workspace/temp/drupal-setup-001.tmp`

- **Logs**: `workspace/logs/<tool-name>.log` or `tools/<tool>/workspace/logs/`

### Workflow Example

```
1. drupal-setup tool runs
   → Writes Drupal files to: workspace/drupal-setup/
   → Writes logs to: workspace/logs/drupal-setup.log
   → Writes exports to: workspace/drupal-setup/config/

2. content-type tool runs (depends on drupal-setup)
   → Reads Drupal from: workspace/drupal-setup/
   → Queries Drupal via: drush (in DDEV context)
   → Writes content type config to: workspace/content-type/

3. Both tools can write exports to: workspace/exports/
```

---

**END OF AGENTS.MD - LOAD ON EVERY SESSION**
