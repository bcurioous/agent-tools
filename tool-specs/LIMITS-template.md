---
name: tool-name-limits             # Must match tool name + -limits
version: "1.0.0"
description: "Prohibited operations and constraints for tool-name"
---

# LIMITS.md

**THIS FILE DEFINES WHAT THIS TOOL CANNOT DO.**

Unlike other specs that only define what tools CAN do, LIMITS.md is our unique
contribution for safety. It explicitly enumerates prohibited operations.

---

## Prohibited Operations

These operations are **NEVER** allowed, regardless of context:

### Filesystem

```yaml
- filesystem:delete        # Cannot delete ANY files
- filesystem:system        # Cannot touch system files (/etc, /usr, etc)
- filesystem:outside-project  # Cannot operate outside PROJECT_DIR
```

### Network

```yaml
- network:external         # Cannot make external API calls
- network:internal         # Cannot probe internal networks
- network:ftp              # Cannot use FTP
- network:ssh               # Cannot initiate SSH connections
```

### Database

```yaml
- database:production      # Cannot touch production databases
- database:drop            # Cannot DROP tables
- database:truncate        # Cannot TRUNCATE tables
```

### Git

```yaml
- git:push                 # Cannot push to remotes
- git:force               # Cannot force push
- git:rebase:interactive  # Cannot do interactive rebase
```

### Shell

```yaml
- shell:privileged        # Cannot sudo/su/root
- shell:background        # Cannot spawn daemons
```

---

## Allowed Operations

Only these operations are permitted (whitelist approach):

### Filesystem

```yaml
- filesystem:read          # Can read files within project
- filesystem:write         # Can create files in designated dirs
- filesystem:mkdir         # Can create directories in project
```

### DDEV/Drush

```yaml
- ddev:start               # Can start DDEV
- ddev:stop                # Can stop DDEV
- ddev:status              # Can check DDEV status
- drush:cr                 # Can clear Drupal cache
- drush:cex                # Can export Drupal config
- drush:cim                # Can import Drupal config
```

### Git (Local Only)

```yaml
- git:init                 # Can git init
- git:add                  # Can stage files
- git:commit               # Can commit locally
- git:log                  # Can view history
- git:status               # Can check status
```

---

## Constraints

### Runtime Constraints

- MUST run within designated `PROJECT_DIR`
- MUST log all operations to `./logs/`
- MUST export config after changes
- MUST clear Drupal cache after config changes

### Input Validation

- All inputs MUST be sanitized
- No user-provided paths outside PROJECT_DIR
- No special characters in filenames

---

## Violation Handling

When LIMITS is violated:

1. **REFUSE** - Tool MUST refuse the operation immediately
2. **LOG** - Log attempt to `./logs/limits_violations.log`
3. **RETURN** - Return exit code E005 (Permission denied)
4. **NOTIFY** - Print warning with violation details

### Violation Log Format

```
TIMESTAMP: 2026-04-14T10:30:00Z
TOOL: tool-name
OPERATION: filesystem:delete
TARGET: /etc/passwd
REQUESTED_BY: user@hostname
REASON: Outside PROJECT_DIR
```

---

## Review Checklist

When creating LIMITS.md for a new tool:

- [ ] Reviewed ALL permission categories
- [ ] Used whitelist (allowed) not blacklist (denied)
- [ ] Documented WHY each prohibition exists
- [ ] Defined violation handling
- [ ] Listed exception cases (if any)

---

## Example: Full LIMITS.md

```yaml
---
name: drupal-setup-limits
version: "1.0.0"
description: "Prohibited operations for Drupal setup tool"
---

# LIMITS.md

## Prohibited Operations

- filesystem:delete - Setup creates, never deletes
- filesystem:system - Never touch system directories
- network:external - No external API calls during setup
- shell:privileged - Never run sudo during setup

## Allowed Operations

- ddev:* - All DDEV commands
- drush:* - All Drush commands  
- filesystem:write - Create project files
- git:local - Local git operations only
```
