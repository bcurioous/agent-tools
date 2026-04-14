---
name: tool-name-query
version: "1.0.0"
description: "Query protocol documentation for tool-name"
---

# QUERY.md

Query protocol defines how other tools can ask this tool about its state.
Inspired by MCP Resources and Agent Status patterns.

---

## Query Interface

All queries go through the fixed `run.sh` interface:

```bash
./run.sh query <type>
```

---

## Supported Queries

| Query | Returns | Description |
|-------|---------|-------------|
| `health` | `healthy` or `unhealthy:<reason>` | Is tool functional? |
| `status` | `ready\|busy\|error\|not_ready` | Current operational state |
| `state` | KEY:VALUE dump | Full state as parseable format |
| `version` | semver string | Tool version |
| `dependencies` | comma-separated list | Required dependencies |
| `<key>` | value | Specific state value lookup |

---

## Response Format

All responses follow this format:

```
TOOL:<tool-name>:QUERY:<query-type>
KEY1:VALUE1
KEY2:VALUE2
KEY3:VALUE3
---
```

### Response Header

Always starts with: `TOOL:<name>:QUERY:<type>`

### Response Body

KEY:VALUE pairs, one per line.

### Response Footer

Always ends with: `---` (three dashes)

---

## Query Details

### health

```
TOOL:drupal-setup:QUERY:health
STATUS:healthy
VERSION:1.0.0
DDEV_VERSION:1.23.0
---
```

Possible STATUS values:
- `healthy` - All systems operational
- `unhealthy:ddev_not_found` - DDEV not installed
- `unhealthy:docker_not_running` - Docker not running
- `unhealthy:project_not_initialized` - Project not set up

### status

```
TOOL:drupal-setup:QUERY:status
STATUS:ready
LAST_RUN:2026-04-14T10:30:00Z
LAST_COMMAND:run
EXIT_CODE:0
---
```

Possible STATUS values:
- `ready` - Idle, can accept commands
- `busy` - Currently executing a command
- `error` - Previous command failed
- `not_ready` - Prerequisites not met

### state

Returns all known state as KEY:VALUE:

```
TOOL:drupal-setup:QUERY:state
VERSION:1.0.0
STATUS:ready
PROJECT_DIR:/Users/me/project
DDEV_VERSION:1.23.0
DRUPAL_VERSION:11.0
INSTALLED_MODULES:admin_toolbar,devel,pathauto
CONFIG_EXPORTED:true
LAST_RUN:2026-04-14T10:30:00Z
---
```

### version

```
TOOL:drupal-setup:QUERY:version
VERSION:1.0.0
SPEC_VERSION:1.0.0
---
```

### dependencies

```
TOOL:drupal-setup:QUERY:dependencies
REQUIRED:ddev,docker,git
OPTIONAL:composer,drupal-cli
---
```

### Custom Keys

Any state value can be queried directly:

```bash
./run.sh query INSTALLED_MODULES
```

Returns:
```
TOOL:drupal-setup:QUERY:INSTALLED_MODULES
INSTALLED_MODULES:admin_toolbar,devel,pathauto
---
```

---

## Error Responses

When a query fails:

```
TOOL:drupal-setup:QUERY:invalid
ERROR:E001
MESSAGE:Invalid query type 'invalid'
---
```

| Code | Meaning |
|------|---------|
| E001 | Invalid input / unknown query type |
| E002 | Tool not ready |
| E003 | Dependency missing |

---

## Query Script Implementation

The `scripts/query.sh` handles all queries:

```bash
#!/bin/bash
case "$1" in
    health) echo_health ;;
    status) echo_status ;;
    state) echo_state ;;
    version) echo_version ;;
    dependencies) echo_dependencies ;;
    *) echo_custom "$1" ;;
esac
```

---

## Inter-Tool Querying

Tools can query other tools:

```bash
# Tool A queries Tool B
RESULT=$(./tools/02-content-type/run.sh query status)
echo "$RESULT"
```

Parse response:
```bash
STATUS=$(echo "$RESULT" | grep "^STATUS:" | cut -d: -f2)
if [ "$STATUS" = "ready" ]; then
    ./tools/02-content-type/run.sh run
fi
```

---

## Best Practices

1. **Always check health before run**
2. **Parse STATUS from state dump**
3. **Handle E002 (not ready) gracefully**
4. **Log all queries for debugging**
5. **Return same output for same query (idempotent)**
