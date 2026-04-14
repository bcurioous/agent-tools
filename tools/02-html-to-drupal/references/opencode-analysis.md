# OpenCode Analysis Reference

## Using OpenCode CLI for HTML Analysis

### Installation

```bash
npm install -g opencode-cli
# or
brew install opencode
```

### Basic Usage

```bash
opencode --session <session-name> --prompt "analyze this HTML"
opencode --session <session-name> --read
opencode --session <session-name> --continue
```

### HTML Analysis Prompt

When analyzing static HTML, use this prompt structure:

```
Analyze the HTML file at <path> and create a layout.json specification.

For each section:
1. Identify the section ID and type
2. Note the HTML tag and attributes
3. Document children elements
4. Note if it's repeatable (navigation, sidebar items)
5. Extract CSS classes (especially Tailwind)
6. Find image/icon references

Output a complete layout.json following the standard format.
```

### Session Management

```bash
opencode --session list
opencode --session html-analysis --read
opencode --session html-analysis --clear
```

### Capturing Output

The tool captures OpenCode output to log files:

```bash
./run.sh run /path/to/html --opencode-session=my-session
```

Logs are written to:
- `workspace/html-to-drupal/logs/opencode-analysis.log`
- `workspace/html-to-drupal/logs/tool.log`

## Layout JSON Format

See the main SPEC.md for the complete layout.json specification.

## Integration with Tool

The `analyze-html.sh` script:

1. Validates the static HTML folder
2. Launches OpenCode with the analysis prompt
3. Captures output to log files
4. Validates the generated layout.json
5. Updates state.json with results

## Troubleshooting

### OpenCode not found

If `opencode` command is not found:
1. Check if Node.js is installed: `node --version`
2. Try using npx: `npx opencode-cli`
3. Install via npm: `npm install -g opencode-cli`

### Session timeout

OpenCode sessions may time out for large HTML files. Break analysis into smaller parts:

```bash
opencode --session html-part1 --prompt "Analyze header and nav sections..."
opencode --session html-part2 --prompt "Analyze main content..."
```
