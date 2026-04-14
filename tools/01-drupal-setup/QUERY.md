---
name: drupal-setup-query
version: "1.0.0"
description: "Query protocol documentation for drupal-setup tool"
---

# QUERY.md

Query protocol for drupal-setup tool.

## Query Interface

```bash
./run.sh query <type>
```

## Supported Queries

| Query | Returns | Example |
|-------|---------|---------|
| health | healthy/unhealthy | `./run.sh query health` |
| status | ready/busy/error/not_ready | `./run.sh query status` |
| state | KEY:VALUE dump | `./run.sh query state` |
| version | semver string | `./run.sh query version` |
| module | enabled/disabled | `./run.sh query module admin_toolbar` |
| theme | theme name | `./run.sh query theme` |
| site_url | URL | `./run.sh query site_url` |
| dependencies | required/optional list | `./run.sh query dependencies` |

## Response Format

```
TOOL:drupal-setup:QUERY:<type>
KEY1:VALUE1
KEY2:VALUE2
---
```

## Query Details

### health

```
TOOL:drupal-setup:QUERY:health
STATUS:healthy
VERSION:11.0.0
DDEV_VERSION:1.23.0
DOCKER_VERSION:26.0.0
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
DB_STATUS:Connected
---
```

Possible STATUS values:
- ready - DDEV running, Drupal accessible
- busy - Currently executing
- error - Previous command failed
- not_ready - DDEV not running

### state

```
TOOL:drupal-setup:QUERY:state
STATUS:ready
VERSION:11.0.0
PHP_VERSION:8.3
DB_STATUS:Connected
SITE_URL:https://drupal11-dev.ddev.site
DEFAULT_THEME:stable
ADMIN_THEME:stable
INSTALLED_MODULES:admin_toolbar,devel,pathauto,metatag,token,honeypot
---
```

### version

```
TOOL:drupal-setup:QUERY:version
DRUPAL_VERSION:11.0.0
DDEV_VERSION:1.23.0
---
```

### module <name>

```
TOOL:drupal-setup:MODULE:admin_toolbar
STATUS:enabled
---
```

### theme

```
TOOL:drupal-setup:QUERY:theme
DEFAULT_THEME:stable
---
```

### site_url

```
TOOL:drupal-setup:QUERY:site_url
SITE_URL:https://drupal11-dev.ddev.site
---
```

### dependencies

```
TOOL:drupal-setup:QUERY:dependencies
REQUIRED:ddev,docker,composer
OPTIONAL:git
---
```

## Error Responses

```
TOOL:drupal-setup:ERROR:E001
MESSAGE:Unknown query type 'invalid'
AVAILABLE_QUERY_TYPES:health,status,state,version,module,theme,site_url,dependencies
---
```

| Code | Meaning |
|------|---------|
| E001 | Invalid input / unknown query type |
| E002 | Tool not ready |
| E003 | Dependency missing |

## Inter-Tool Querying

Tools can query other tools to check readiness before execution:

```bash
RESULT=$(./tools/01-drupal-setup/run.sh query health)
echo "$RESULT"
```

Parse the STATUS to determine if tool is ready:

```bash
RESULT=$(./tools/01-drupal-setup/run.sh query health)
STATUS=$(echo "$RESULT" | grep "^STATUS:" | cut -d: -f2)

if [[ "$STATUS" == "healthy" ]]; then
    echo "DDEV is healthy, ready to proceed"
elif [[ "$STATUS" == not_ready ]]; then
    echo "DDEV not configured"
else
    echo "DDEV unhealthy: $STATUS"
fi
```

Check specific states:

```bash
# Check if Drupal is installed
VERSION=$(./tools/01-drupal-setup/run.sh query state | grep "^DRUPAL_VERSION:" | cut -d: -f2)
if [[ "$VERSION" == "not installed" ]]; then
    ./tools/01-drupal-setup/run.sh run
fi

# Check if specific module is enabled
MODULE_STATUS=$(./tools/01-drupal-setup/run.sh query module admin_toolbar | grep "^STATUS:" | cut -d: -f2)
if [[ "$MODULE_STATUS" == "disabled" ]]; then
    echo "Need to enable admin_toolbar"
fi
```

## Best Practices

1. Always check health before run
2. Parse STATUS from state dump
3. Handle not_ready state gracefully
4. Log all queries for debugging
5. Return same output for same query (idempotent)
6. Use dependencies query to verify prerequisites before running
