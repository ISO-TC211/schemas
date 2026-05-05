# Phase 6: Implement Redirect Infrastructure in Site

Two-tier redirect strategy for handling URL changes from Phases 1-4.

## Tier 1: HTML Page Redirects (jekyll-redirect-from gem)

- [ ] Add `jekyll-redirect-from` to site's `Gemfile`
- [ ] Add to `_config.yml` plugins list
- [ ] Add `redirect_from: ["/transforms/"]` to `_pages/resources.html` front matter

## Tier 2: File-Level Redirects (custom Jekyll generator)

- [ ] Create `_plugins/redirect_generator.rb` — Jekyll generator that reads `_data/redirects.yml` and creates HTML redirect pages
- [ ] Create `_layouts/redirect.html` — minimal layout with meta refresh:
  ```html
  <!DOCTYPE html>
  <html><head>
    <meta http-equiv="refresh" content="0; url={{ page.redirect_to }}">
    <link rel="canonical" href="{{ page.redirect_to }}">
  </head><body>
    <p>This file has moved to <a href="{{ page.redirect_to }}">{{ page.redirect_to }}</a></p>
  </body></html>
  ```

## Redirect Data File

- [ ] Create `_data/redirects.yml` with all mappings from Phases 1-4:
  ```yaml
  # Phase 1: Legacy directory normalization
  - from: "/schemas/19155/gpi/1.0/gpi.xsd"
    to: "/schemas/19155/-/gpi/1.0/gpi.xsd"
  # Phase 2: Examples moved to subdirs
  - from: "/schemas/19115/-1/mdb/1.3.1/D.1Minimal.xml"
    to: "/schemas/19115/-1/mdb/1.3.1/examples/D.1Minimal.xml"
  # Phase 3: Resources consolidated
  - from: "/schemas/19115/resources/Codelist/CI_RoleType.xml"
    to: "/schemas/19115/resources/codelists/CI_RoleType.xml"
  # Phase 4: ZIP bundles moved
  - from: "/schemas/19115/-3/cat/1.0/cat.zip"
    to: "/schemas/19115/resources/bundles/cat-1.0.zip"
  ```

## Limitations
- GitHub Pages doesn't support HTTP 301/302 — meta refresh only
- XSD `schemaLocation` resolution uses `schema_location_mappings` regex rewrites, not redirects
- Redirects are for human/browsable URLs only
