#!/bin/bash

TOOL_NAME="drupal-setup"
ERRORS=0
WARNINGS=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_DIR="$(dirname "$SCRIPT_DIR")"

cd "$TOOL_DIR"

echo "Running self-verification for $TOOL_NAME..."

echo "[1/5] Checking DDEV..."
if command -v ddev &>/dev/null; then
    echo "  OK: DDEV is installed"
else
    echo "  FAIL: DDEV is not installed"
    ERRORS=$((ERRORS + 1))
fi

echo "[2/5] Checking Docker..."
if docker info &>/dev/null 2>&1; then
    echo "  OK: Docker is running"
else
    echo "  FAIL: Docker is not running"
    ERRORS=$((ERRORS + 1))
fi

echo "[3/5] Checking project structure..."
if [ -f "SPEC.md" ] && [ -f "LIMITS.md" ] && [ -f "QUERY.md" ] && [ -f "run.sh" ]; then
    echo "  OK: All required files present"
else
    echo "  FAIL: Missing required files"
    ERRORS=$((ERRORS + 1))
fi

echo "[4/5] Checking scripts..."
if [ -f "scripts/setup.sh" ] && [ -f "scripts/query.sh" ] && [ -f "scripts/verify.sh" ]; then
    echo "  OK: All scripts present"
else
    echo "  FAIL: Missing scripts"
    ERRORS=$((ERRORS + 1))
fi

echo "[5/5] Checking DDEV project..."
if ddev describe &>/dev/null 2>&1; then
    echo "  OK: DDEV project is configured"
    DDEV_STATUS="configured"
else
    echo "  WARN: DDEV project not configured (run './run.sh run' to set up)"
    WARNINGS=$((WARNINGS + 1))
    DDEV_STATUS="not_configured"
fi

echo ""
if [ $ERRORS -eq 0 ]; then
    echo "Verification passed!"
    if [ $WARNINGS -gt 0 ]; then
        echo "Note: $WARNINGS warning(s) - tool may not be fully operational"
    fi
    exit 0
else
    echo "Verification failed with $ERRORS error(s)"
    exit E004
fi
