# Phase 9: Update Existing Site Pages + Documentation

## _config.yml Updates
- [ ] Update nav: "Transforms" → "Resources", `/transforms/` → `/resources/`
  ```yaml
  nav:
    - title: Schemas
      url: /
    - title: Documentation
      url: /docs/
    - title: Resources
      url: /resources/
  ```
- [ ] Clean up excludes list:
  ```yaml
  exclude:
    - Gemfile
    - Gemfile.lock
    - Makefile
    - README.adoc
    - CLAUDE.md
    - generate_configs.rb
    - lxr_packages.yml
    - json_packages.yml
    - resource_descriptions.yml
    - resources_index.json
    - node_modules
    - vendor
    - build
    - configs
    - _frontend
    - config
    - vite.config.ts
    - package.json
    - package-lock.json
  ```
- [ ] Add `jekyll-redirect-from` to plugins

## _pages/docs.html Updates
- [ ] Add resource summary sections with links to `/resources/`:
  - Schematron validation rules (count per standard)
  - XML/JSON example instances
  - Codelist dictionaries
  - Download packages

## _frontend/js/schemas.js Updates
- [ ] Add resource count links to schema cards:
  - "3 Schematron rules" → link to `/resources/?standard=19115&type=schematron`
  - "12 examples" → link to `/resources/?standard=19115&type=examples_xml`

## CLAUDE.md Updates
- [ ] Update for new architecture:
  - RepoScanner auto-discovery
  - Resources page
  - Redirect infrastructure
  - Updated directory structure conventions

## README.adoc Updates
- [ ] Update `schemas/README.adoc` with:
  - New directory structure and naming conventions
  - How to add new content (XSD, JSON, resources, codelists)
  - MECE organization principles
