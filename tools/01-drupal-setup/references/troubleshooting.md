# Drupal Setup - Troubleshooting

## Common Issues

### Issue: "DDEV not found"

**Cause:** DDEV not installed or not in PATH

**Solution:**
```bash
# Install DDEV
curl -fsSL https://ddev.install.sh | bash

# Verify installation
ddev --version
```

### Issue: "Docker not running"

**Cause:** Docker Desktop not started

**Solution:**
```bash
# macOS
open -a Docker

# Linux
sudo systemctl start docker
sudo systemctl enable docker
```

### Issue: "Port already in use"

**Cause:** Another service using DDEV's default ports (ports 8080, 8025, etc.)

**Solution:**
```bash
# Check what's using the port
lsof -i :8080

# Or change DDEV ports
ddev config --http-port=8081
ddev start
```

### Issue: "Database connection failed"

**Cause:** Database container not running

**Solution:**
```bash
ddev stop
ddev start -y
```

### Issue: "Composer memory limit"

**Cause:** PHP memory limit too low

**Solution:**
```bash
# Set higher memory limit
ddev exec php -d memory_limit=512M /usr/bin/composer require VENDOR/PACKAGE

# Or edit composer.json and run
ddev composer update --no-interaction
```

## Diagnostic Commands

```bash
# Full DDEV status
ddev describe

# Docker status
docker ps
docker logs ddev-router

# Drupal status
ddev drush status

# PHP info
ddev php -i | grep memory_limit

# Check logs
ddev logs
```

## Reset Environment

To completely reset the environment:

```bash
# Stop and remove
ddev poweroff
ddev delete -y

# Remove config
rm -rf .ddev

# Start fresh
./run.sh run
```
