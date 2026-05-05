# Phase 8: Site — Dynamic Resources Page + resources.js

Create the dynamic Resources page that replaces the current Transforms page.

## Files to Create/Modify

### _pages/resources.html (rename from transforms.html)
- [ ] Rename `_pages/transforms.html` → `_pages/resources.html`
- [ ] Replace hardcoded content with dynamic container + filter bar
- [ ] Add `redirect_from: ["/transforms/"]` to front matter
- [ ] Filter bar: text search + type dropdown (All, XSLT, Schematron, Examples, Codelists, Bundles)
- [ ] Dynamic rendering grouped by standard → category

### _frontend/js/resources.js (new)
- [ ] Fetches `resources_index.json`
- [ ] Groups resources by standard
- [ ] Renders filterable sections with type-specific icons and badges
- [ ] Type icons: ⚡ XSLT, ✓ Schematron, 📄 Examples, 📋 Codelists, 📦 Bundles
- [ ] Download links for each file
- [ ] Import from `_frontend/entrypoints/application.js`

### _frontend/css/schemas.css (update)
- [ ] Add resource-type badge styles:
  ```css
  .badge--xslt { /* orange */ }
  .badge--schematron { /* purple */ }
  .badge--examples { /* blue */ }
  .badge--codelists { /* green */ }
  .badge--bundles { /* gray */ }
  ```
- [ ] Reuse existing: `page-section`, `transform-group`, `transform-card`, `filter-bar`

### _frontend/entrypoints/application.js (update)
- [ ] Add `import '../js/resources.js'`

## Notes
- Page URL changes from `/transforms/` to `/resources/`
- Old URL redirects via `jekyll-redirect-from`
- Nav updated in Phase 9
