# Tool Discovery Spec (DRAFT)

How tools find and identify each other dynamically.

---

## Overview

Tool Discovery answers: "How do I find tools that can do X?"

Inspired by:
- MCP server discovery
- DNS service discovery
- Skill activation in AGENTS.md

---

## Discovery Methods

### 1. Registry-Based Discovery

Tools are registered in `tool-registry.yaml`:

```yaml
registry:
  version: "1.0.0"
  tools:
    - name: drupal-setup
      version: "1.0.0"
      path: tools/01-drupal-setup
      tags: [drupal, setup, ddev]
      provides: [drupal:setup, ddev:init]
      
    - name: content-type
      version: "1.0.0"
      path: tools/02-content-type
      tags: [drupal, content-type]
      provides: [drupal:content-type:create]
      requires: [drupal-setup]
```

### 2. Capability-Based Discovery

Query registry for tools by capability:

```bash
# Find tools that can "setup drupal"
./tool-registry.sh find --capability drupal:setup

# Find tools by tag
./tool-registry.sh find --tag drupal

# Find tools by dependency
./tool-registry.sh find --requires drupal-setup
```

### 3. Auto-Discovery

Tools auto-discover sibling tools via directory scan:

```bash
# Scans tools/*/run.sh and extracts SPEC.md metadata
./tool-registry.sh scan
```

### 4. Network Discovery (Future)

```yaml
# Service announcement
announce:
  service: drupal-setup
  port: 9090
  capabilities:
    - drupal:setup
    - ddev:init
```

---

## Discovery Protocol

### Query Flow

```
User/Agent wants to: create a content type in Drupal

1. Query registry: "drupal:content-type:create"
2. Registry returns: content-type tool
3. Check dependency: content-type requires drupal-setup
4. Query registry: "drupal:setup"
5. Registry returns: drupal-setup tool
6. Execute: drupal-setup → content-type
```

---

## Registry File Format

`tool-registry.yaml` is the source of truth:

```yaml
---
version: "1.0.0"
updated: 2026-04-14

tools:
  - name: string (required)
    version: semver (required)
    path: relative/path (required)
    description: string (optional)
    tags: [tag1, tag2] (optional)
    provides: [capability1, capability2] (optional)
    requires: [tool-name@version] (optional)
    state: ready|busy|error|not_installed

discovery:
  auto_scan: true
  scan_paths: [tools/, ~/.local/tools/]
```

---

## Implementation

### tool-registry.sh

```bash
#!/bin/bash
# Tool Registry CLI

case "$1" in
    scan)      scan_directory ;;
    find)     find_by_capability "$2" ;;
    list)     list_all ;;
    register)  register_tool "$2" ;;
    *)         echo "Usage: tool-registry.sh <scan|find|list|register>" ;;
esac
```

### Discovery Query

```bash
# Find tool by capability
tool-registry.sh find --capability drupal:setup

# Output:
# drupal-setup (1.0.0) - tools/01-drupal-setup
# Provides: drupal:setup, ddev:init
```

---

## Status Codes

| Status | Meaning |
|--------|---------|
| ready | Tool installed and functional |
| busy | Tool currently executing |
| error | Tool previously failed |
| not_installed | Tool referenced but not present |

---

## Workspace Discovery

### How Tools Find Each Other's Workspaces

Tools discover workspaces via registry lookup:

```bash
# Get workspace path for a tool
./tool-registry.sh workspace <tool-name>

# Example:
./tool-registry.sh workspace drupal-setup
# Returns: workspace/drupal-setup
```

### Workspace Registry Format

The registry maps tool names to workspace paths:

```yaml
workspaces:
  root: workspace
  drupal-setup: workspace/drupal-setup
  content-type: workspace/content-type
  assets: workspace/assets
  exports: workspace/exports
  temp: workspace/temp
  logs: workspace/logs

tools:
  - name: drupal-setup
    workspace: tools/01-drupal-setup/workspace    # Tool's isolated workspace
    shared-workspace: workspace/drupal-setup      # Tool's shared output
```

### Querying Workspaces

```bash
# List all workspaces
./tool-registry.sh workspaces

# Output:
# drupal-setup: workspace/drupal-setup
# content-type: workspace/content-type
# assets: workspace/assets
# ...

# Get tool's shared workspace (where other tools should look)
./tool-registry.sh shared-workspace drupal-setup
# Returns: workspace/drupal-setup

# Get tool's isolated workspace (tool's own sandbox)
./tool-registry.sh isolated-workspace drupal-setup
# Returns: tools/01-drupal-setup/workspace
```

### Environment Variable Injection

Every tool session automatically has these env vars:

```bash
TOOL_WORKSPACE_ROOT   # Tool's isolated workspace
TOOL_SHARED_ROOT      # Tool's shared workspace  
DRUPAL_ROOT           # Drupal project (same as drupal-setup's shared-workspace)
TOOL_REGISTRY         # Path to registry
PROJECT_ROOT          # Project root
```

---

## TODO

- [ ] Define capability namespace (e.g., `drupal:content-type:create`)
- [ ] Implement tool-registry.sh CLI
- [ ] Add dependency resolution
- [ ] Add version constraints
- [ ] Consider network discovery for distributed tools
- [x] Add workspace discovery (registry-based lookup)
