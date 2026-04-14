#!/bin/bash
set -e

TOOL_NAME="drupal-setup"
SITE_NAME="${SITE_NAME:-Drupal 11 Dev}"
ADMIN_PASS="${ADMIN_PASS:-drupal123}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$TOOL_DIR/../../.." && pwd)}"
ASSETS_DIR="$SCRIPT_DIR/assets"

# Use shared workspace for Drupal files (Layer 2 of workspace architecture)
# TOOL_SHARED_ROOT = workspace/drupal-setup/
DRUPAL_ROOT="${TOOL_SHARED_ROOT:-$PROJECT_ROOT/workspace/$TOOL_NAME}"

mkdir -p "$DRUPAL_ROOT/.ddev"
mkdir -p "$DRUPAL_ROOT/web"

cd "$DRUPAL_ROOT"

echo "[drupal-setup] Starting Drupal development environment setup..."
echo "[INFO] Drupal files location: $DRUPAL_ROOT"

echo "[1/10] Checking prerequisites..."
if ! command -v ddev &>/dev/null; then
    echo "ERROR: DDEV is not installed"
    echo "Install from: https://ddev.readthedocs.io"
    exit E003
fi

if ! docker info &>/dev/null; then
    echo "ERROR: Docker is not running"
    echo "Start Docker and try again"
    exit E002
fi

echo "[2/10] Creating DDEV config if needed..."
DDEV_PORT="${DDEV_PORT:-61838}"
if [ ! -f .ddev/config.yaml ]; then
    ddev config --project-name=drupal11-dev --project-type=drupal11 --docroot=web --host-webserver-port="$DDEV_PORT"
fi

echo "[3/10] Starting DDEV containers..."
ddev start -y

echo "[4/10] Scaffolding Drupal 11..."
if [ ! -f web/core/install.php ]; then
    ddev composer create-project drupal/recommended-project:^11 . --no-install --no-interaction
fi

echo "[5/10] Installing dependencies..."
ddev composer install
ddev composer require drush/drush --dev

echo "[6/10] Installing Drupal 11..."
# Check if Drupal is actually installed and database is connected
if ddev drush status 2>/dev/null | grep -q "Database connected"; then
    echo "Drupal database is already installed"
elif [ -f web/core/install.php ]; then
    ddev drush site:install standard \
        --account-name=admin \
        --account-pass="$ADMIN_PASS" \
        --site-name="$SITE_NAME" \
        -y
else
    echo "ERROR: Drupal core not found"
    exit E004
fi

echo "[7/10] Installing and enabling modules..."
ddev composer require drupal/admin_toolbar drupal/admin_toolbar_tools drupal/devel drupal/pathauto drupal/metatag drupal/token drupal/honeypot --no-interaction
ddev drush pm:enable admin_toolbar admin_toolbar_tools devel pathauto metatag token honeypot -y

echo "[8/10] Installing themes..."
ddev composer require drupal/stable drupal/classy --dev --no-interaction
ddev drush theme:enable stable classy -y

echo "[9/10] Configuring honeypot..."
ddev drush config:set honeypot.settings enabled true -y
ddev drush config:set honeypot.settings element_name 'url' -y

echo "[10/10] Clearing cache and exporting config..."
ddev drush cr
ddev drush cex -y

echo ""
echo "[drupal-setup] Setup complete!"
echo "Drupal files: $DRUPAL_ROOT"
echo "Site URL: http://127.0.0.1:${DDEV_PORT:-61838}"
echo "Admin user: admin"
echo "Admin pass: $ADMIN_PASS"
