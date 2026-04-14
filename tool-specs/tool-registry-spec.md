# Tool Registry Spec (DRAFT)

Central registry format for tool metadata and discovery.

---

## Overview

Tool Registry is the canonical source of truth for all available tools.
Inspired by:
- npm package.json
- Docker registry
- MCP server manifests

---

## Registry File

### Location

Default: `./tool-registry.yaml`
Alternative: `$TOOL_REGISTRY_PATH`

### Format

```yaml
---
registry:
  version: "1.0.0"
  name: my-project-tools
  updated: 2026-04-14T10:30:00Z
  
tools:
  - name: drupal-setup
    version: "1.0.0"
    path: tools/01-drupal-setup
    description: Creates DDEV-based Drupal 11 environment
    tags: [drupal, ddev, setup]
    
  - name: content-type
    version: "1.0.0"
    path: tools/02-content-type
    description: Creates Drupal content types
    tags: [drupal, content-type]
    
dependencies:
  graph:
    content-type:
      requires: [drupal-setup]
    drupal-setup:
      requires: []
```

---

## Tool Entry Schema

Each tool entry:

```yaml
name: string (required)
  # Unique identifier, kebab-case
  # Example: drupal-setup, content-type

version: semver (required)
  # Must be valid semver
  # Example: 1.0.0, 2.1.0-beta.1

path: string (required)
  # Relative path from registry
  # Example: tools/01-drupal-setup

description: string (optional)
  # Human-readable description
  # One sentence maximum

tags: array (optional)
  # For capability search
  # Example: [drupal, setup, ddev]

provides: array (optional)
  # Capabilities this tool provides
  # Example: [drupal:setup, ddev:init]

requires: array (optional)
  # Tool dependencies with version constraints
  # Example: [drupal-setup@^1.0.0]

state: enum (auto-managed)
  # ready|busy|error|not_installed
  # Auto-updated by tool-registry.sh

author: string (optional)
  # Tool author

created: date (optional)
  # ISO 8601 date

updated: date (optional)
  # ISO 8601 date
```

---

## Operations

### Register Tool

```bash
tool-registry.sh register tools/01-drupal-setup
```

### Unregister Tool

```bash
tool-registry.sh unregister drupal-setup
```

### Update State

```bash
tool-registry.sh state drupal-setup ready
tool-registry.sh state drupal-setup busy
tool-registry.sh state drupal-setup error
```

### List Tools

```bash
# All tools
tool-registry.sh list

# By tag
tool-registry.sh list --tag drupal

# By state
tool-registry.sh list --state ready
```

### Dependency Graph

```bash
tool-registry.sh deps

# Output:
# content-type
#   └── drupal-setup
# drupal-setup
#   └── (none)
```

---

## Validation

Registry must be valid YAML and pass schema validation:

```bash
tool-registry.sh validate
# Returns: valid|invalid:error_message
```

---

## Integration with Other Specs

### Discovery Spec
- Registry provides capability-based search

### Communicate Spec
- Tools query registry for peer tool paths

### Orchestration Spec
- Orchestrator reads registry for dependency graph

---

## TODO

- [ ] Define JSON Schema for validation
- [ ] Implement tool-registry.sh
- [ ] Add version constraint resolver
- [ ] Add circular dependency detection
- [ ] Consider distributed registry (future)
