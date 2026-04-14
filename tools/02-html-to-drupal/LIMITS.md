---
name: html-to-drupal-limits
version: "1.0.0"
description: "Prohibited operations for HTML to Drupal conversion tool"
---

# LIMITS.md

**THIS FILE DEFINES WHAT THIS TOOL CANNOT DO.**

## Prohibited Operations

### Filesystem

```yaml
- filesystem:delete        # Cannot delete any files
- filesystem:system        # Cannot touch system directories (/etc, /usr, etc)
- filesystem:outside-project  # Cannot operate outside PROJECT_DIR
```

### Network

```yaml
- network:external         # Cannot make external API calls (except OpenCode CLI)
- network:ssh              # Cannot initiate SSH connections
```

### Database

```yaml
- database:production      # Cannot touch production databases
- database:drop            # Cannot DROP tables
```

### Git

```yaml
- git:push                 # Cannot push to remotes
- git:force               # Cannot force push
```

### Shell

```yaml
- shell:privileged        # Cannot run sudo/root
- shell:background        # Cannot spawn long-running daemons
```

## Allowed Operations

### Filesystem

```yaml
- filesystem:read          # Read project files and static HTML
- filesystem:write         # Create files in project (layout.json, logs, Drupal config)
- filesystem:mkdir         # Create directories in project
```

### DDEV/Drush

```yaml
- ddev:start              # Start DDEV
- ddev:stop              # Stop DDEV
- ddev:status            # Check DDEV status
- ddev:describe          # Get project info
- ddev:exec             # Execute commands in DDEV
- drush:*                # All Drush commands
```

### OpenCode CLI

```yaml
- opencode:session:create  # Create analysis session
- opencode:session:run     # Run commands in session
- opencode:session:read    # Read session output
```

### Composer

```yaml
- composer:require        # Install packages in DDEV
- composer:remove          # Remove packages in DDEV
```

## Constraints

- MUST run within designated PROJECT_DIR
- MUST log to files (not terminal stdout) for intermediate steps
- MUST validate layout.json by reverse engineering
- MUST test final output with Playwright
- All inputs MUST be validated
- OpenCode session output MUST be captured to log files

## Violation Handling

1. REFUSE - Tool refuses operation immediately
2. LOG - Log to ./logs/limits_violations.log
3. RETURN - Exit code E005

## Review Checklist

- [x] Reviewed ALL permission categories
- [x] Used whitelist approach
- [x] Documented why prohibitions exist
- [x] Defined violation handling
