---
name: tool-name                    # Unique tool identifier (kebab-case)
version: "1.0.0"                   # SemVer
description: "Brief description of what this tool does"  # One sentence
type: tool                          # tool | skill | agent (future)

metadata:
  author: Your Name
  created: 2026-04-14
  updated: 2026-04-14
  tags: [tag1, tag2, tag3]
  compatibility:
    toolA: "^1.0"
    toolB: "^2.0"
    
manifest:
  command: ./run.sh                 # Fixed entry point (always ./run.sh)
  interface:                        # Fixed interface - DO NOT ADD MORE
    - run
    - query
    - verify
    - help
  permissions:                      # Allowed permission categories
    - filesystem:read
    - filesystem:write
    - shell:exec
    
dependencies:
  required:                         # Must be available
    - ddev
    - docker
  optional:                         # Used if available
    - git

references:
  - references/setup.md
  - references/commands.md
  - references/examples.md
---

# Tool Name

## Mandate

Single declarative statement of WHY this tool exists.

Example: "To create and configure a complete DDEV-based Drupal 11 development environment with sensible defaults."

## Core Responsibilities

Itemized list of what this tool DOES. Be specific.

1. Initialize DDEV project with Drupal 11
2. Install approved modules via Drush
3. Configure development settings
4. Export configuration for version control

## Interface Contract

### run

What `./run.sh run` does. Include:
- Prerequisites
- Steps executed
- Expected outputs
- Time estimate

### query

What queries are supported:

| Query | Returns | Example |
|-------|---------|---------|
| health | healthy/unhealthy | `./run.sh query health` |
| status | ready\|busy\|error | `./run.sh query status` |
| state | KEY:VALUE dump | `./run.sh query state` |
| version | semver | `./run.sh query version` |

### verify

What `./run.sh verify` checks:
1. Dependencies available
2. Permissions correct
3. Previous runs succeeded

## Input/Output

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| PROJECT_DIR | Yes | . | Project directory |

### Outputs

- Created files
- Modified files
- Log locations

## Dependencies

### Required

- `ddev` >= 1.23
- `docker` >= 24.0

### Optional

- `git` (for version control initialization)

## Guiding Principles

High-level philosophical approach.

1. **Simplicity First** - Default to simplest solution
2. **Idempotency** - Running twice = same result as once
3. **Fail Fast** - Stop on error, don't continue broken

## Examples

### Basic Usage

```bash
# Run the tool
./run.sh run

# Check status
./run.sh query status

# Get help
./run.sh help
```

### Advanced Usage

```bash
# With custom project dir
PROJECT_DIR=/path/to/project ./run.sh run
```

## Troubleshooting

Common issues and solutions.

### Issue: DDEV not found

Solution: Install DDEV from https://ddev.readthedocs.io

### Issue: Docker not running

Solution: Run `docker ps` to verify Docker is running.
