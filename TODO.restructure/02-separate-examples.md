# Phase 2: Separate Examples from Schemas

Move loose XML example files from version dirs into `examples/` subdirs within the same version dir. Move codelist XML files to `resources/codelists/`.

## Example Moves

### 19115/-1/mdb/1.3.1/
- [ ] `D.1Minimal.xml` → `examples/D.1Minimal.xml`
- [ ] `D.2VectorSmartMap.xml` → `examples/D.2VectorSmartMap.xml`
- [ ] `FullishV0.0.4.xml` → `examples/FullishV0.0.4.xml`

### 19115/-1/mdb/1.3.0/
- [ ] Move example XMLs to `examples/`

### 19115/-1/{mcc,mco,mex,mmi,mrc,mrd,mri,mrs}/*/
- [ ] Move `codelists.xml` to `resources/codelists/` (renamed appropriately)
- [ ] Move other XML examples to `examples/`

### 19115/-3/*/
- [ ] Move example XMLs to `examples/` subdirs

### 19157/-2/mdq/1.0/
- [ ] `mdq_invalid.xml` → `examples/mdq_invalid.xml`
- [ ] `mdq_valid.xml` → `examples/mdq_valid.xml`
- [ ] `codelists.xml` → `resources/codelists/` (renamed `mdq-1.0-codelists.xml`)

### 19155/-/gpi/1.0/ (after Phase 1 move)
- [ ] `point.xml` → `examples/point.xml`
- [ ] `referenceSystem.xml` → `examples/referenceSystem.xml`

## Notes
- `19123/-2/cis/1.2/examples/` and `19165/-/gpm/1.0/examples/` already have this structure — no change needed.
- JSON examples in `json/*/examples/` are already organized — no change needed.
- `codelists.xml` files are NOT examples — they're codelist dictionaries that should move to `resources/codelists/`.
