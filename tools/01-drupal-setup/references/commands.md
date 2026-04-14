# Drupal Setup - Command Reference

## DDEV Commands

```bash
# Start DDEV
ddev start

# Stop DDEV
ddev stop

# Check status
ddev status

# Describe project
ddev describe

# Get site URL
ddev describe --json | grep -o 'https://[^"]*'
```

## Drush Commands

```bash
# Clear cache
ddev drush cr
ddev drush cache:rebuild

# Enable modules
ddev drush pm:enable MODULE_NAME -y

# Disable modules
ddev drush pm:uninstall MODULE_NAME -y

# List modules
ddev drush pm:list

# Config export
ddev drush cex

# Config import
ddev drush cim

# Get config value
ddev drush config:get system.site

# Set config value
ddev drush config:set system.site name "My Site"
```

## Composer Commands

```bash
# Install package
ddev composer require VENDOR/PACKAGE

# Remove package
ddev composer remove VENDOR/PACKAGE

# Update all
ddev composer update

# Show installed
ddev composer show
```

## Project Commands

```bash
# Run tests
ddev exec phpunit

# Open browser
ddev launch

# SSH into container
ddev ssh

# Import database
ddev import-db --file=dump.sql

# Export database
ddev export-db --file=dump.sql
```
