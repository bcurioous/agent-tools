# Tool Orchestration Spec (DRAFT)

Multi-tool workflow orchestration.

---

## Overview

Orchestration defines how multiple tools are combined into workflows.
Inspired by:
- A2A protocol patterns
- Unix Make/Systemd
- CI/CD pipeline models
- LangGraph/LangChain workflows

---

## Orchestration Patterns

### 1. Sequential Pipeline

Tools execute in order, output → input:

```yaml
pipeline:
  - tool: drupal-setup
  - tool: content-type
    requires: drupal-setup
  - tool: theme-setup
    requires: content-type
```

### 2. Parallel Fan-Out

Multiple tools execute simultaneously:

```yaml
parallel:
  - tool: drupal-setup
  - tool: redis-setup
  - tool: s3-setup

# All must complete before continuing
```

### 3. Conditional Branch

Execute based on state:

```yaml
if:
  condition: "{{drupal-setup.status}}" == "ready"
  then:
    - tool: content-type
  else:
    - tool: error-reporter
```

### 4. Dynamic Workflow

Tools discover and compose at runtime:

```yaml
dynamic:
  find_by_capability: drupal:*
  for_each: tool
  execute: "{{tool}}"
```

---

## Workflow Definition

### workflow.yaml

```yaml
---
name: drupal-site
version: "1.0.0"

steps:
  - id: setup-drupal
    tool: drupal-setup
    run: ./run.sh run
    
  - id: create-content-types
    tool: content-type
    run: ./run.sh run
    args:
      types:
        - article
        - page
        - event
    requires: setup-drupal
    
  - id: setup-theme
    tool: theme-setup
    run: ./run.sh run
    requires: setup-drupal
    
  - id: import-content
    tool: content-import
    run: ./run.sh run
    requires:
      - create-content-types
      - setup-theme
```

---

## Orchestrator CLI

### tool-orchestrate.sh

```bash
#!/bin/bash
# Orchestrate multi-tool workflows

case "$1" in
    run)
        shift
        orchestrate "$@"
        ;;
    status)
        workflow_status "$2"
        ;;
    list)
        list_workflows
        ;;
    *)
        echo "Usage: tool-orchestrate.sh <run|status|list>"
        ;;
esac
```

### Usage

```bash
# Run workflow
./tool-orchestrate.sh run workflow.yaml

# Check status
./tool-orchestrate.sh status drupal-site

# List available workflows
./tool-orchestrate.sh list
```

---

## Dependency Resolution

### Automatic Resolution

```bash
# Build dependency graph
tool-orchestrate.sh resolve workflow.yaml

# Output:
# 1. drupal-setup (no deps)
# 2. content-type (needs drupal-setup)
# 3. theme-setup (needs drupal-setup)
# 4. content-import (needs content-type, theme-setup)
```

### Topological Sort

Tools execute in dependency order:

```bash
# Execute in correct order
for tool in $(tsort dependency.graph); do
    ./tools/$tool/run.sh run
done
```

---

## State Management

### Workflow State

```yaml
# .workflows/drupal-site/state.yaml
workflow: drupal-site
status: running
current_step: content-import
started: 2026-04-14T10:30:00Z
steps:
  setup-drupal: completed
  create-content-types: completed
  setup-theme: running
  content-import: pending
```

### Step State Machine

```
pending → running → completed
                ↘ failed
                
failed → retry (up to 3)
       → skipped
       → manual_intervention
```

---

## Error Handling

### Automatic Retry

```yaml
steps:
  - id: unstable-tool
    tool: sometimes-fails
    retry:
      max_attempts: 3
      backoff: exponential
      delay: 5s
```

### Fallback

```yaml
steps:
  - id: primary-setup
    tool: drupal-setup
    fallback:
      tool: manual-setup
      on_failure: skip_remaining
```

### Compensation/Rollback

```yaml
steps:
  - id: create-resources
    compensate: delete-resources
    
  - id: delete-resources
    tool: cleanup-tool
```

---

## Execution Modes

### Dry Run

```bash
./tool-orchestrate.sh run workflow.yaml --dry-run
# Shows what would execute, in what order
```

### Step-by-Step

```bash
./tool-orchestrate.sh run workflow.yaml --interactive
# Confirms before each step
```

### Background

```bash
./tool-orchestrate.sh run workflow.yaml --background
# Runs in background, returns immediately
```

### Parallel

```bash
./tool-orchestrate.sh run workflow.yaml --parallel
# Executes independent steps concurrently
```

---

## Integration with Other Specs

### Discovery Spec
- Find tools by capability at runtime

### Registry Spec
- Check tool state before execution
- Update tool state during workflow

### Communicate Spec
- Tools communicate via shared bus
- Events trigger downstream steps

---

## TODO

- [ ] Define workflow.yaml schema
- [ ] Implement tool-orchestrate.sh
- [ ] Add dependency graph builder
- [ ] Implement state machine
- [ ] Add retry/fallback logic
- [ ] Consider distributed orchestration (future)
