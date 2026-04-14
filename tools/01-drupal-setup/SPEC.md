---
name: drupal-setup
version: "1.0.0"
description: "Creates DDEV-based Drupal 11 development environment with essential modules"
type: tool

metadata:
  author: dev-team
  created: 2026-04-14
  tags: [drupal, ddev, setup, development]
  compatibility:
    drupal: "^11.0"
    ddev: "^1.23"
    docker: "^24.0"
    
manifest:
  command: ./run.sh
  interface:
    - run
    - query
    - verify
    - help
  permissions:
    - filesystem:read
    - filesystem:write
    - ddev:all
    - drush:all
    
dependencies:
  required:
    - ddev
    - docker
    - composer
  optional: []

references:
  - references/setup.md
  - references/commands.md
  - references/troubleshooting.md
---

# Drupal Setup Tool

## Mandate

Create and configure a complete DDEV-based Drupal 11 development environment with essential modules, themes, and sensible defaults for rapid development.

## Core Responsibilities

1. Initialize DDEV project with Drupal 11
2. Install and configure Drush
3. Install essential modules (admin_toolbar, devel, pathauto, etc.)
4. Install Stable and Classy themes
5. Configure Drupal site settings
6. Export configuration for version control

## Interface Contract

### run

Executes the full Drupal development environment setup:

**Prerequisites:**
- DDEV installed and working
- Docker running
- Composer available

**Steps:**
1. Check prerequisites (DDEV, Docker, Composer)
2. Create .ddev/config.yaml if not exists
3. Start DDEV containers
4. Install Drupal 11 (site:install)
5. Install Drush
6. Enable essential modules
7. Install Stable themes
8. Configure honeypot spam protection
9. Clear Drupal cache
10. Export configuration

**Time Estimate:** 5-10 minutes

### query

| Query | Returns | Description |
|-------|---------|-------------|
| health | healthy/unhealthy | DDEV and Drupal status |
| status | ready/busy/error/not_ready | Current state |
| state | KEY:VALUE dump | Full state |
| version | Drupal version | Drupal version |
| module | enabled/disabled | Check specific module |
| theme | theme name | Default theme |
| site_url | URL | HTTPS site URL |

### verify

Self-verification checks:
1. DDEV is installed
2. Docker is running
3. DDEV project exists
4. Drupal is accessible
5. Scripts are present

## Inputs

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| PROJECT_DIR | No | . | Target directory |
| SITE_NAME | No | "Drupal 11 Dev" | Site name |
| ADMIN_PASS | No | "drupal123" | Admin password |

## Outputs

| Output | Example |
|--------|---------|
| site_url | https://drupal11-dev.ddev.site |
| admin_user | admin |
| installed_modules | admin_toolbar,devel,pathauto,metatag |
| default_theme | stable |

## Guiding Principles

1. **Idempotency** - Running twice = same result as once
2. **Fail Fast** - Stop on error, don't continue broken
3. **Configuration as Code** - Always export config after changes
