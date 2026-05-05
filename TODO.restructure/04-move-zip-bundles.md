# Phase 4: Move ZIP Bundles to resources/bundles/

Move all ZIP files from version dirs to `{standard}/resources/bundles/`.

## Specific Moves

### 19115
- [ ] `19115/-3/*/\*.zip` → `19115/resources/bundles/{module}-{version}.zip`
- [ ] `19115/-2/gmi/1.0/gmi.zip` → `19115/resources/bundles/gmi-1.0.zip`

### 19155 (after Phase 1 normalization)
- [ ] `19155/-/gpi/1.0/gpi.zip` → `19155/resources/bundles/gpi-1.0.zip`
- [ ] `19155/19155.zip` → `19155/resources/bundles/19155.zip`

### 19157
- [ ] `19157/-2/*/\*.zip` → `19157/resources/bundles/{module}-1.0.zip`
- [ ] `19157/19157.zip` → `19157/resources/bundles/19157.zip`

### 19110
- [ ] `19110/19110.zip` → `19110/resources/bundles/19110.zip`

### Standard-level bundles
- [ ] `19115/resources/resources.zip` → `19115/resources/bundles/resources.zip`
- [ ] `19115/resources/19115-3-2016-2022.zip` → `19115/resources/bundles/19115-3-2016-2022.zip`

## Notes
- Naming convention: `{module}-{version}.zip` for module-level bundles, `{standard}.zip` for standard-level bundles.
- Add redirect entries to `_data/redirects.yml` for each moved ZIP.
