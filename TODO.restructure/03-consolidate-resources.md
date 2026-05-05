# Phase 3: Consolidate Resources Per Standard

Normalize all `resources/` directories to a consistent subcategory structure:

```
{standard}/resources/
  transforms/        # XSL stylesheets
  codelists/         # Codelist dictionary XML files
  schematron/        # Cross-cutting Schematron rules
  bundles/           # ZIP download packages
  namespace-tools/   # Namespace tools (19115 only)
  examples/          # Standard-wide examples (if any)
```

## Specific Moves

### 19115/resources/ (already mostly organized)
- [ ] `Codelist/` → `codelists/` (rename, lowercase)
- [ ] `Schematron/` → `schematron/` (rename, lowercase)
- [ ] `namespaceInformationAndTools/` → `namespace-tools/` (rename)
- [ ] Add `bundles/` directory

### 19157/resources/
- [ ] `Codelists/` → `codelists/` (rename, lowercase)
- [ ] Add `bundles/` directory

### 19139/-/resources/
- [ ] Move to `19139/resources/` (standard-level, not part-level)
- [ ] `codelist/` → `codelists/`
- [ ] `example/` → `examples/`
- [ ] `crs/` stays
- [ ] `uom/` stays

### Root-level resources/
- [ ] `codelists.html`, `codelists.xml`, `codelists1.xml` → move to `19115/resources/codelists/` or delete and regenerate from source

## Notes
- `transforms/` directories already exist in the right place — no changes needed.
- Add redirect entries to `_data/redirects.yml` for each moved file.
