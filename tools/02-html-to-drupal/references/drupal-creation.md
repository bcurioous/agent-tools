# Drupal Creation Reference

## Overview

The `create-drupal.sh` script creates Drupal components based on the layout.json specification.

## Component Mapping

### Layout Sections to Drupal Components

| Layout Section | Drupal Component | Creation Method |
|----------------|------------------|-----------------|
| government-banner | Custom Block | `drush generate plugin:block` |
| header | Custom Block | `drush generate plugin:block` |
| main-navigation | Menu Block | Block placement |
| sidebar | Menu Block + Block region | Block placement |
| main-content | Node content type | Content type + View mode |
| footer | Custom Block | `drush generate plugin:block` |
| back-to-top | Custom Block | `drush generate plugin:block` |

## Content Type Fields

Based on the layout, the main content type should have:

| Field | Type | Widget |
|-------|------|--------|
| title | string | text_field |
| body | text_long | text_textarea |
| featured_image | image | image_image |
| sidebar_content | text_long | text_textarea |

## Block Creation

### Using Drush

```bash
ddev exec -- drush generate plugin:block <block-id>
```

This creates:
- `src/Plugin/Block/<BlockId>.php`
- Registers the block plugin

### Manual Block Creation

```php
// src/Plugin/Block/GovernmentBanner.php
<?php

namespace Drupal\<theme>\Plugin\Block;

use Drupal\Core\Block\BlockBase;

#[Block(id: "government_banner", admin_label: "Government Banner")]
class GovernmentBanner extends BlockBase {
    public function build() {
        return [
            '#markup' => '<div class="government-banner">...</div>',
        ];
    }
}
```

## Twig Templates

### Template Naming

| Component | Template File |
|-----------|---------------|
| Page | `page.html.twig` |
| Node | `node--<content-type>.html.twig` |
| Block | `block--<block-id>.html.twig` |
| Field | `field.html.twig` |

### Example: Section Template

```twig
{# templates/block--government-banner.html.twig #}
<div class="bg-[#f0f0f0]">
  <div class="mx-auto flex max-w-[1200px] items-center gap-2 px-4 py-1 text-[13px]">
    <img src="{{ base_path ~ directory }}/assets/us_flag_small.png" alt="U.S. flag" class="h-[11px] w-4" />
    <span>An official website of the United States government</span>
    <a href="#" class="ml-1 text-[#005ea2] underline">Here's how you know</a>
  </div>
</div>
```

## Block Placement

### Using Drush

```bash
ddev exec -- drush block:place <region> <plugin_id>
```

### Example Placements

```bash
ddev exec -- drush block:place header government_banner
ddev exec -- drush block:place content main_navigation
ddev exec -- drush block:place sidebar_left navigation
ddev exec -- drush block:place footer footer_block
```

## Theme Setup

### Create Theme

```bash
ddev exec -- drush generate theme nci_theme --theme-type=stable
```

### Theme Files

```
web/themes/custom/nci_theme/
├── nci_theme.info.yml
├── nci_theme.libraries.yml
├── nci_theme.theme
├── css/
│   └── style.css
└── templates/
    ├── page.html.twig
    └── block/
        └── block--government-banner.html.twig
```

### Libraries

```yaml
# nci_theme.libraries.yml
global-styling:
  css:
    theme:
      css/style.css: {}
```

## View Creation

### Create View

```bash
ddev exec -- drush generate views:content <view-name>
```

### Example View for Cancer Content

```yaml
# config/install/views.view.cancer_content.yml
langcode: en
status: true
dependencies:
  module:
    - node
id: cancer_content
label: 'Cancer Content'
module: views
tag: ''
base_table: node_field_data
core: 8.x
display:
  default:
    display_plugin: default
    id: default
    display_title: Master
    plugin_type: page
    display_options:
      fields:
        title:
          id: title
          table: node_field_data
          field: title
      filters:
        status:
          value: '1'
      path: cancer-content
```

## Frontpage Setup

```bash
ddev exec -- drush config:set system.site frontpage 'node/1' -y
```

## Cache Clear

Always after changes:

```bash
ddev exec -- drush cr
ddev exec -- drush cex -y
```
