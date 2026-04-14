# Tool Communicate Spec (DRAFT)

Inter-tool communication protocol.

---

## Overview

Tool Communication defines how tools exchange state, results, and signals.
Inspired by:
- MCP protocol (JSON-RPC 2.0)
- A2A (Agent-to-Agent) protocol
- Unix pipes and signals

---

## Communication Patterns

### 1. Query/Response (Synchronous)

Tool A queries Tool B and waits for response:

```bash
# Tool A wants to know if Tool B is ready
RESULT=$(./tools/02-content-type/run.sh query status)

# Parse result
STATUS=$(echo "$RESULT" | grep "^STATUS:" | cut -d: -f2)
if [ "$STATUS" = "ready" ]; then
    # Execute
fi
```

### 2. Pipe/Stream (Streaming)

Tool A pipes data to Tool B:

```bash
# Tool A generates data, Tool B processes
./tools/01-drupal-setup/run.sh run | ./tools/02-content-type/run.sh run
```

### 3. Event/Notification (Async)

Tool A notifies Tool B of state change:

```bash
# Write to shared state file
echo "STATE:completed" > ./tools/02-content-type/state.d/event

# Or use named pipe
echo "event:complete" > /tmp/tool-bus
```

### 4. Request/Response (RPC-style)

Tool A calls Tool B's specific function:

```bash
# Call specific operation
./tools/02-content-type/run.sh run --content-type=article --fields=title,body,image
```

---

## Message Format

### Query Response Format

```
TOOL:<name>:QUERY:<type>
KEY1:VALUE1
KEY2:VALUE2
---
```

### Event Format

```yaml
event:
  type: state_change
  source: drupal-setup
  target: content-type
  data:
    state: ready
    timestamp: 2026-04-14T10:30:00Z
```

### Shared State Format

```yaml
# ./tools/shared/state/<tool-name>.yaml
tool: content-type
status: ready
version: "1.0.0"
last_update: 2026-04-14T10:30:00Z
data:
  content_types:
    - article
    - page
```

---

## Communication Bus

### Two-Layer Workspace Model

Tools communicate via **shared workspaces** and **tool isolated workspaces**:

```
nic-drupal/
├── workspace/                        # COMMON working area (ALL tools access this)
│   ├── drupal-setup/               # Tool's shared output
│   │   ├── config/                 #   Drush config exports
│   │   ├── content/                #   Content exports
│   │   └── data/                   #   Data dumps
│   ├── content-type/               # Another tool's shared space
│   ├── assets/                     # Shared assets
│   ├── exports/                    # Cross-tool exports
│   ├── temp/                      # Shared temp
│   └── logs/                      # Shared logs
│
└── tools/
    ├── 01-drupal-setup/
    │   ├── run.sh
    │   └── workspace/              # Tool's isolated workspace
    │       ├── cache/
    │       ├── temp/
    │       └── output/
    └── 02-content-type/
        └── workspace/
```

### Shared Workspace Paths

Tools access shared workspaces via registry:

```bash
# Get workspace path
TOOL_SHARED_ROOT=$(./tool-registry.sh workspace drupal-setup)
# Returns: workspace/drupal-setup

# Read/write shared data
cat $TOOL_SHARED_ROOT/config/drupal-config.tar.gz
echo "STATE:ready" > $TOOL_SHARED_ROOT/status
```

### Message Types

| Type | Format | Use Case |
|------|--------|----------|
| query | TOOL:... | Synchronous state query |
| event | YAML | Async notifications |
| data | JSON/YAML | Shared data exchange |
| signal | filename | Simple triggers |

### File-Based Communication

```
# Shared state via workspace
workspace/<tool-name>/state/status     # Tool status
workspace/<tool-name>/state/last_run  # Last execution time
workspace/<tool-name>/config/         # Exported config

# Shared events via workspace
workspace/<tool-name>/events/         # Event notifications
workspace/temp/                      # Temporary shared files
``` |

---

## Protocol Flow

### Example: Content-Type Creation Pipeline

```
User: "Create article content type"

Orchestrator:
  1. Query drupal-setup status
     → drupal-setup:QUERY:status
     ← STATUS:ready
  
  2. Query content-type status  
     → content-type:QUERY:status
     ← STATUS:ready
  
  3. Execute drupal-setup (if needed)
     → ./tools/01-drupal-setup/run.sh run
     ← (completes)
  
  4. Execute content-type
     → ./tools/02-content-type/run.sh run --content-type=article
     ← (completes)
  
  5. Notify drupal-setup of change
     → echo "event:content-type-created" > shared/bus/
```

---

## Error Handling

### Timeout

```bash
# Wait up to 30 seconds for tool
timeout 30 ./tools/02-content-type/run.sh query health
if [ $? -eq 124 ]; then
    echo "Tool timeout"
fi
```

### Retry

```bash
# Retry up to 3 times
for i in 1 2 3; do
    if ./tools/02-content-type/run.sh query health | grep -q "healthy"; then
        break
    fi
    sleep 5
done
```

---

## Security Considerations

- Tools should only communicate via defined interfaces
- No arbitrary code execution between tools
- Shared state should have access controls
- Limit what can be written to shared bus

---

## TODO

- [ ] Define event type vocabulary
- [ ] Implement shared bus mechanism
- [ ] Add message signing for trust
- [ ] Consider network-based communication (future)
- [ ] Add correlation IDs for tracing
- [x] Document two-layer workspace model for communication
