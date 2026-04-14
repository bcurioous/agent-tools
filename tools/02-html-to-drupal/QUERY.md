---
name: html-to-drupal-query
version: "1.0.0"
description: "Query protocol documentation for html-to-drupal tool"
---

# QUERY.md

Query protocol for html-to-drupal tool.

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
| layout_json | path | `./run.sh query layout_json` |
| theme | theme name | `./run.sh query theme` |
| content_type | content type name | `./run.sh query content_type` |
| blocks | list | `./run.sh query blocks` |
| site_url | URL | `./run.sh query site_url` |
| dependencies | required/optional list | `./run.sh query dependencies` |

## Response Format

```
TOOL:html-to-drupal:QUERY:<type>
KEY1:VALUE1
KEY2:VALUE2
---
```

## Query Details

### health

```
TOOL:html-to-drupal:QUERY:health
STATUS:healthy
OPENCODE_VERSION:0.x.x
DDEV_STATUS:healthy
DRUPAL_STATUS:healthy
---
```

Possible STATUS values:
- `healthy` - All systems operational
- `unhealthy:opencode_not_found` - OpenCode CLI not installed
- `unhealthy:ddev_not_found` - DDEV not installed
- `unhealthy:drupal_not_ready` - Drupal not configured
- `unhealthy:static_html_not_found` - Static HTML folder not found

### status

```
TOOL:html-to-drupal:QUERY:status
STATUS:ready
LAYOUT_JSON:generated
THEME:created
BLOCKS:placed
---
```

Possible STATUS values:
- ready - Tool ready to run or completed
- busy - Currently executing
- error - Previous command failed
- not_ready - Dependencies not met

### state

```
TOOL:html-to-drupal:QUERY:state
STATUS:ready
STATIC_HTML_FOLDER:/path/to/nci
LAYOUT_JSON:/path/to/layout.json
THEME_NAME:nci_theme
CONTENT_TYPE:cancer_content
BLOCKS:government-banner,header,main-navigation,sidebar,main-content,footer
SITE_URL:https://drupal11-dev.ddev.site
FRONTPAGE_NID:1
---
```

### layout_json

```
TOOL:html-to-drupal:QUERY:layout_json
PATH:/path/to/layout.json
SIZE:12345
SECTIONS:8
---
```

### theme

```
TOOL:html-to-drupal:QUERY:theme
THEME_NAME:nci_theme
STATUS:created
---
```

### content_type

```
TOOL:html-to-drupal:QUERY:content_type
CONTENT_TYPE:cancer_content
FIELDS:title,body,featured_image,sidebar_nav
VIEW_MODE:full
---
```

### blocks

```
TOOL:html-to-drupal:QUERY:blocks
BLOCKS:government-banner,header,main-navigation,sidebar,main-content,footer,back-to-top
PLACED:all
---
```

### site_url

```
TOOL:html-to-drupal:QUERY:site_url
SITE_URL:https://drupal11-dev.ddev.site
---
```

### dependencies

```
TOOL:html-to-drupal:QUERY:dependencies
REQUIRED:ddev,docker,drush,opencode
OPTIONAL:playwright,mmx
---
```

## Error Responses

```
TOOL:html-to-drupal:ERROR:E001
MESSAGE:Unknown query type 'invalid'
AVAILABLE_QUERY_TYPES:health,status,state,layout_json,theme,content_type,blocks,site_url,dependencies
---
```

| Code | Meaning |
|------|---------|
| E001 | Invalid input / unknown query type |
| E002 | Tool not ready |
| E003 | Dependency missing |
| E004 | Execution failed |

## Inter-Tool Querying

Tools can query other tools to check readiness before execution:

```bash
# Check if Drupal is ready
RESULT=$(../01-drupal-setup/run.sh query health)
echo "$RESULT"

# Check this tool's state
RESULT=$(./run.sh query state)
echo "$RESULT"
```

## Logging

This tool logs to intermediate files instead of terminal:

| Log Type | Path |
|----------|------|
| OpenCode Analysis | ./logs/opencode-analysis.log |
| Layout Generation | ./logs/layout-generation.log |
| Drupal Creation | ./logs/drupal-creation.log |
| Testing Results | ./logs/testing.log |

## Best Practices

1. Always check health before run
2. Parse STATUS from state dump
3. Handle not_ready state gracefully
4. Log all operations to files
5. Return same output for same query (idempotent)
6. Use dependencies query to verify prerequisites before running
