# Drupal Setup - Detailed Setup Reference

## Prerequisites

### Required Software

| Software | Version | Install |
|----------|---------|---------|
| DDEV | >= 1.23 | https://ddev.readthedocs.io |
| Docker | >= 24.0 | https://docker.com |
| Composer | >= 2.0 | https://getcomposer.org |

### Verify Prerequisites

```bash
# Check DDEV
ddev --version

# Check Docker
docker --version
docker ps

# Check Composer
composer --version
```

## Installation Steps

### Step 1: DDEV Configuration

DDEV config is created at `.ddev/config.yaml`:

```yaml
name: drupal11-dev
type: drupal11
docroot: web
php_version: "8.3"
```

### Step 2: Drupal Installation

Uses Drush site:install:

```bash
ddev drush site:install standard \
  --account-name=admin \
  --account-pass=YOUR_PASSWORD \
  --site-name="Your Site Name" \
  -y
```

### Step 3: Module Installation

Essential modules installed via Composer + Drush:

| Module | Purpose |
|--------|---------|
| admin_toolbar | Admin navigation |
| admin_toolbar_tools | Admin toolbar extras |
| devel | Development utilities |
| pathauto | Automatic URL aliases |
| metatag | Meta tags |
| token | Token API |
| honeypot | Spam protection |

### Step 4: Theme Installation

Stable and Classy themes installed for base theme development.

## Troubleshooting

### DDEV Not Found

```bash
# Install DDEV
curl -fsSL https://ddev.install.sh | bash
```

### Docker Not Running

```bash
# Start Docker Desktop (macOS)
open -a Docker

# Or restart Docker service (Linux)
sudo systemctl restart docker
```

### Port Conflicts

```bash
# Check if ports are in use
ddev describe

# Use different ports
ddev config --http-port=8081
```
