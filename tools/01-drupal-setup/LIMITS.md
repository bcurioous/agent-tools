---
name: drupal-setup-limits
version: "1.0.0"
description: "Prohibited operations for Drupal setup tool"
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
- network:external         # Cannot make external API calls
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
- shell:background        # Cannot spawn daemons
```

## Allowed Operations

### Filesystem

```yaml
- filesystem:read          # Read project files
- filesystem:write         # Create files in project
- filesystem:mkdir         # Create directories in project
```

### DDEV/Drush

```yaml
- ddev:start              # Start DDEV
- ddev:stop              # Stop DDEV
- ddev:status            # Check DDEV status
- ddev:describe          # Get project info
- drush:*                # All Drush commands
```

### Composer

```yaml
- composer:require        # Install packages
- composer:remove          # Remove packages
```

### Git (Local Only)

```yaml
- git:init               # Initialize repo
- git:add                # Stage files
- git:commit            # Local commits only
```

## Constraints

- MUST run within designated PROJECT_DIR
- MUST export Drupal config after changes
- MUST clear cache after config changes
- All inputs MUST be validated

## Violation Handling

1. REFUSE - Tool refuses operation immediately
2. LOG - Log to ./logs/limits_violations.log
3. RETURN - Exit code E005

## Review Checklist

- [x] Reviewed ALL permission categories
- [x] Used whitelist approach
- [x] Documented why prohibitions exist
- [x] Defined violation handling
