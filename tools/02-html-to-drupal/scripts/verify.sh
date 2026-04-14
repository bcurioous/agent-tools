#!/bin/bash

TOOL_NAME="html-to-drupal"
ERRORS=0
WARNINGS=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_DIR="$(dirname "$SCRIPT_DIR")"

cd "$TOOL_DIR"

echo "Running self-verification for $TOOL_NAME..."

echo "[1/8] Checking OpenCode CLI..."
if command -v opencode &>/dev/null; then
    echo "  OK: OpenCode CLI is installed"
else
    echo "  WARN: OpenCode CLI is not installed (needed for HTML analysis)"
    WARNINGS=$((WARNINGS + 1))
fi

echo "[2/8] Checking Node.js..."
if command -v node &>/dev/null; then
    echo "  OK: Node.js is installed"
else
    echo "  FAIL: Node.js is not installed"
    ERRORS=$((ERRORS + 1))
fi

echo "[3/8] Checking Python3..."
if command -v python3 &>/dev/null; then
    echo "  OK: Python3 is installed"
else
    echo "  FAIL: Python3 is not installed"
    ERRORS=$((ERRORS + 1))
fi

echo "[4/8] Checking DDEV..."
if command -v ddev &>/dev/null; then
    echo "  OK: DDEV is installed"
else
    echo "  FAIL: DDEV is not installed"
    ERRORS=$((ERRORS + 1))
fi

echo "[5/8] Checking Docker..."
if docker info &>/dev/null 2>&1; then
    echo "  OK: Docker is running"
else
    echo "  FAIL: Docker is not running"
    ERRORS=$((ERRORS + 1))
fi

echo "[6/8] Checking project structure..."
if [ -f "SPEC.md" ] && [ -f "LIMITS.md" ] && [ -f "QUERY.md" ] && [ -f "run.sh" ]; then
    echo "  OK: All required files present"
else
    echo "  FAIL: Missing required files"
    ERRORS=$((ERRORS + 1))
fi

echo "[7/8] Checking scripts..."
REQUIRED_SCRIPTS="analyze-html.sh create-drupal.sh test-output.sh reverse-validate.sh query.sh verify.sh"
MISSING_SCRIPTS=""
for script in $REQUIRED_SCRIPTS; do
    if [ ! -f "scripts/$script" ]; then
        MISSING_SCRIPTS="$MISSING_SCRIPTS $script"
    fi
done
if [ -z "$MISSING_SCRIPTS" ]; then
    echo "  OK: All scripts present"
else
    echo "  FAIL: Missing scripts:$MISSING_SCRIPTS"
    ERRORS=$((ERRORS + 1))
fi

echo "[8/8] Checking Drupal setup tool..."
DRUPAL_SETUP_TOOL="$(cd '../01-drupal-setup' 2>/dev/null && pwd)/run.sh"
if [ -f "$DRUPAL_SETUP_TOOL" ]; then
    echo "  OK: Drupal setup tool found"
else
    echo "  WARN: Drupal setup tool not found at ../01-drupal-setup"
    WARNINGS=$((WARNINGS + 1))
fi

echo ""
if [ $ERRORS -eq 0 ]; then
    echo "Verification passed!"
    if [ $WARNINGS -gt 0 ]; then
        echo "Note: $WARNINGS warning(s) - some features may not work"
    fi
    exit 0
else
    echo "Verification failed with $ERRORS error(s)"
    exit 4
fi
