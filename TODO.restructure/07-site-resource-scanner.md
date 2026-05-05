# Phase 7: Data-Driven RepoScanner + resources_index.json

Rewrite `generate_configs.rb` with a `RepoScanner` class that auto-discovers everything from the filesystem.

## Core Principle

The filesystem IS the database. With consistent `standard/-part/module/version/` naming, everything is derivable from the path:

```
Given path: 19115/-1/cit/1.3.0/cit.xsd
  → standard=19115, part=1, module=cit, version=1.3.0
  → Main XSD: {module}.xsd (cit.xsd)
  → All XSDs: {version_dir}/*.xsd
  → Schematron: {version_dir}/*.sch
  → Examples: {version_dir}/examples/*.xml
  → Docs: {version_dir}/*.adoc
  → Diagrams: {version_dir}/*.png
  → Standard resources: {standard}/resources/{category}/*
```

## Manifests as Metadata Overlays

`lxr_packages.yml` and `json_packages.yml` provide ONLY human metadata:
- `title` — human-readable title
- `description` — one-line description
- `status` — current/draft/historical
- `files` — which modules to group into a single LXR package

Everything else (file discovery, resource counts, module listing) is auto-discovered.

## Implementation

- [ ] Add `RepoScanner` class to `generate_configs.rb`
  ```ruby
  class RepoScanner
    RESOURCE_CATEGORIES = {
      transforms:    { glob: "**/resources/transforms/**/*.xsl",   label: "XSLT Transforms" },
      schematron:    { glob: "**/*.sch",                          label: "Schematron Rules" },
      examples_xml:  { glob: "**/examples/*.xml",                 label: "XML Examples" },
      examples_json: { glob: "**/examples/*.json",                label: "JSON Examples" },
      codelists:     { glob: "**/resources/codelists/**/*.xml",   label: "Codelist Dictionaries" },
      bundles:       { glob: "**/resources/bundles/**/*.zip",     label: "Download Packages" },
    }
  end
  ```

- [ ] `discover_xsd_packages` — walk `standard/-part/module/version/` dirs, find 3-char .xsd entry points
- [ ] `discover_json_packages` — walk `json/standard/-part/module/version/` dirs
- [ ] `discover_resources` — scan for all resource categories
- [ ] `compute_redirects` — compare current paths against convention, generate redirect map

## Output Files

### schemas_index.json (enhanced)
Now includes resource counts per package:
```json
{
  "name": "ISO 19115-1 — Metadata Fundamentals (v1.3.0)",
  "slug": "19115-1-1.3.0",
  "version": "1.3.0",
  "status": "current",
  "standard": "19115",
  "type": "xsd",
  "has_spa": true,
  "browser_path": "site/19115-1-1.3.0.html",
  "modules": [
    {
      "module": "cit", "version": "1.3.0",
      "xsd_files": ["cit.xsd"],
      "schematron_files": ["cit.sch"],
      "examples": ["examples/cit_valid.xml"],
      "documentation": ["index.adoc"],
      "diagrams": ["cit.png"]
    }
  ],
  "resource_counts": {
    "schematron": 18, "examples_xml": 12, "transforms": 10,
    "codelists": 48, "bundles": 5
  }
}
```

### resources_index.json (new)
```json
{
  "standards": {
    "19115": {
      "transforms": [
        { "path": "19115/resources/transforms/iso19115-to-dc.xsl", "description": "..." }
      ],
      "codelists": [...],
      "schematron": [...],
      "bundles": [...]
    }
  }
}
```

### resource_descriptions.yml (new, optional)
Human descriptions for named resources — scanner uses as lookup, falls back to auto-generated from filename.
