# Tool Specification Guidelines

A constraint-based specification system for creating **predictable**, **safe**, **tool-to-tool communicable** tools. Inspired by SKILL.md pattern, AI Agent Specification Template, and MCP Protocol.

---

## Core Philosophy

| Principle | Description |
|-----------|-------------|
| **Singleness** | One tool = One purpose (like MCP tools) |
| **Limited Scope** | Tools can ONLY do what's specified + LIMITS.md (unique safety layer) |
| **Fixed Interface** | Same input → Same output every time |
| **Queryable** | Other tools can ask about state (like MCP resources) |
| **Safe** | LIMITS.md defines explicit prohibitions (our unique contribution) |
| **Progressive Disclosure** | Main spec + references for deeper detail (like SKILL.md) |

---

## Three-Layer Model Compatibility

This spec bridges three layers:

| Layer | Our Tool Role | Similar To |
|-------|---------------|------------|
| **Agent** | Orchestration decisions | Agent_Handle, Mandate, Core_Responsibilities |
| **Skills** | Domain knowledge/guidelines | SKILL.md, best practices, workflow |
| **MCP** | External connectivity/tools | Tools, Resources, fixed interface |

---

## Tool Folder Structure

Every tool MUST follow this structure:

```
tools/<tool-name>/
├── SPEC.md              # Main specification (YAML frontmatter + markdown)
├── LIMITS.md            # What this tool CANNOT do (our unique safety layer)
├── QUERY.md             # Query protocol documentation
├── run.sh               # Fixed harness - PURE BASH (executable CLI, no OpenCode required)
├── references/          # Progressive disclosure (like SKILL.md references/)
│   ├── setup.md        # Detailed setup reference
│   ├── commands.md     # Command reference
│   └── examples.md     # Usage examples
├── scripts/            # Implementation scripts
│   ├── setup.sh        # Main setup execution
│   ├── verify.sh       # Self-verification
│   └── query.sh        # Query handlers
└── workspace/          # Tool's OWN isolated workspace (100% context)
    ├── cache/          #   Permanent-ish cache
    ├── temp/          #   Tool temp (auto-clean)
    └── output/        #   Tool artifacts
```

## Two-Layer Workspace Model

This project uses a **two-layer workspace architecture**:

### Layer 1: Tool Isolated Workspace
**Path**: `tools/<tool-name>/workspace/`
- Tool's **own** isolated sandbox
- Only the owning tool writes here
- Other tools cannot depend on files here
- Use for: tool's internal state, cache, temp files

### Layer 2: Shared Common Workspace  
**Path**: `workspace/<tool-name>/`
- **Common** working area ALL tools access
- Tool writes its shared output here
- Other tools can read/use these files
- Use for: Drupal files, config exports, content exports

### Standard Shared Directories

| Path | Purpose |
|------|---------|
| `workspace/<tool-name>/config/` | Drush config exports |
| `workspace/<tool-name>/content/` | Content exports |
| `workspace/<tool-name>/data/` | Data dumps, SQL exports |
| `workspace/assets/` | Shared media/uploads |
| `workspace/exports/` | Cross-tool exports |
| `workspace/temp/` | Shared temp (cleanable) |
| `workspace/logs/` | Shared logs |

### Environment Variables

Every tool session automatically has:

```bash
TOOL_WORKSPACE_ROOT   # = tools/<tool-name>/workspace
TOOL_SHARED_ROOT      # = workspace/<tool-name>
TOOL_REGISTRY         # = tool-registry.yaml
PROJECT_ROOT          # = project root (nic-drupal/)
```

---

## SPEC.md Format (SKILL.md inspired with YAML frontmatter)

Every tool's SPEC.md MUST have YAML frontmatter:

```yaml
---
name: drupal-setup                    # Unique tool identifier
version: "1.0.0"                     # SemVer
description: "Creates DDEV-based Drupal 11 development environment"
type: tool                            # tool | skill | agent (future)

metadata:
  author: Your Name
  created: 2026-04-14
  tags: [drupal, ddev, setup, development]
  compatibility:
    - drupal: "^11.0"
    - ddev: "^1.23"
    
manifest:
  command: ./run.sh                   # Fixed entry point
  interface: [run, query, verify, help]  # Fixed interface (like MCP tools)
  permissions: [filesystem:read, filesystem:write, shell:exec]
  
references:
  - references/setup.md
  - references/commands.md
---
```

### SPEC.md Sections (Agent Spec inspired)

After frontmatter, the SPEC.md contains:

```markdown
# Tool Name

## Mandate
Single declarative statement of purpose (why this tool exists).

## Core Responsibilities
- Itemized list of what this tool DOES
- Scoped to single purpose

## Interface Contract
### run
What happens when `./run.sh run` is executed.

### query
What queries are supported and their response format.

### verify
What self-verification checks are performed.

## Input/Output
Expected inputs and outputs for each command.

## Dependencies
What this tool depends on (other tools, external services).

## Guiding Principles
High-level philosophical approach (like KISS, YAGNI, DRY).
```

---

## LIMITS.md (Our Unique Safety Contribution)

LIMITS.md defines what the tool **CANNOT** do. This is our unique contribution that fills the gap between Skill specs (what to do) and Agent specs (what not to do).

```yaml
---
name: drupal-setup-limits
version: "1.0.0"
description: "Prohibited operations for drupal-setup tool"
---

# LIMITS.md

## Prohibited Operations

These operations are **NEVER** allowed:

1. **filesystem:delete** - Cannot delete any files
2. **network:external** - Cannot make external API calls
3. **database:production** - Cannot touch production databases
4. **git:push** - Cannot push to remote repositories
5. **shell:privileged** - Cannot run sudo/root commands

## Allowed Operations

Only these operations are permitted:

- `ddev start/stop/status`
- `ddev drush *`
- `mkdir` within project directory
- `git:local` - Local git operations only

## Constraints

- Must run within designated project directory
- Must export config after changes
- Must clear cache after Drupal operations

## Error Behavior

When LIMITS is violated:
- Tool MUST refuse operation
- Return E005 (Permission denied)
- Log attempt to limits_violations.log
```

---

## run.sh Interface (Fixed for ALL tools)

Every tool's run.sh MUST implement this exact interface (MCP-inspired):

```bash
./run.sh run          # Execute the tool's main function
./run.sh query <type> # Query tool state (health|status|state|version|<key>)
./run.sh verify       # Self-verification
./run.sh help         # Show help
```

### Response Format

```
TOOL:<name>:QUERY:<type>
KEY:VALUE
---
```

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| E001 | Invalid input |
| E002 | Tool not ready |
| E003 | Dependency missing |
| E004 | Execution failed |
| E005 | Permission denied (LIMITS violation) |

---

## Query Protocol

Standardized query interface (MCP Resources inspired):

```bash
./run.sh query health     # Health check - returns "healthy" or "unhealthy:<reason>"
./run.sh query status     # Status: ready|busy|error|not_ready
./run.sh query state      # Full state dump as KEY:VALUE pairs
./run.sh query version    # Tool version
./run.sh query <key>     # Specific value lookup
```

### Query Response Format

```
TOOL:drupal-setup:QUERY:health
STATUS:healthy
VERSION:1.0.0
UPTIME:3600
---
```

---

## Development Cycle

Tools are **standalone bash scripts** - they run directly via `./run.sh` and do NOT require OpenCode or any agent harness.

### Phase 1: Develop and Test
1. Write/test commands directly in terminal
2. Verify commands work deterministically
3. Record what works in scripts/setup.sh

### Phase 2: Create Tool Files
1. Create SPEC.md with YAML frontmatter
2. Create LIMITS.md with prohibitions
3. Create QUERY.md for query protocol
4. Create run.sh harness (pure bash - no OpenCode dependency)
5. Create references/ for progressive disclosure

### Phase 3: Verify & Publish
1. Run ./run.sh verify to self-check
2. Add to tool-registry.yaml
3. Document in tool-docs/

---

## Tool Registry Format

Tools are registered in `tool-registry.yaml`:

```yaml
tools:
  - name: drupal-setup
    version: "1.0.0"
    path: tools/01-drupal-setup
    tags: [drupal, ddev, setup]
    dependencies: [ddev, docker]
    
  - name: content-type
    version: "1.0.0" 
    path: tools/02-content-type
    tags: [drupal, content-type]
    dependencies: [drupal-setup]
```

---

## Progressive Disclosure Pattern

Like SKILL.md, tools support progressive disclosure:

1. **Router** - AGENTS.md or tool-registry.yaml maps task → tool
2. **Main Spec** - SPEC.md provides domain-specific instructions (<500 lines)
3. **References** - references/*.md provides deep-dive when needed

---

## Comparison: Our Tool Spec vs Others

| Aspect | SKILL.md | AI Agent Spec | MCP | **Our Tool Spec** |
|--------|----------|---------------|-----|-------------------|
| Format | Markdown + YAML | YAML-heavy | JSON-RPC | Markdown + YAML |
| Execution | None (reference) | Full agent | Tool execution | Shell scripts |
| Safety | Implicit | Explicit | Trust-based | **LIMITS.md explicit** |
| Queryable | No | Yes | Resources | Yes |
| Interface | N/A | Multi-method | Fixed | **Fixed (run/query/verify)** |
| Discovery | AGENTS.md router | Manifest | Registry | **tool-registry.yaml** |

---

## Future Specs (Planned)

- **tool-discovery-spec.md** - How tools find each other
- **tool-registry-spec.md** - Central registry format
- **tool-communicate-spec.md** - Inter-tool communication
- **tool-orchestration-spec.md** - Multi-tool workflows

---

**Last Updated**: April 2026
