# Phase 10: Contributor Documentation

## README.adoc — schemas/ Repository Guide

Update `schemas/README.adoc` with complete contributor documentation.

### Directory Naming Conventions

- **Standard number**: 5 digits (e.g., `19115`)
- **Part**: `-1`, `-2`, `-3`, etc. Use `-` for "no part" (standalone standard)
- **Module**: 3 lowercase letters (e.g., `cit`, `mdb`, `gml`). Must match the main XSD filename.
- **Version**: Semantic version (e.g., `1.0`, `1.3.0`, `2.2.0`)

### Directory Structure

```
schemas/
  {standard}/{-part}/{module}/{version}/
    *.xsd              # Schema definitions
    *.sch              # Schematron validation rules
    index.adoc         # Schema documentation
    *.png              # UML/diagram images
    examples/          # Example instances
      *.xml

  {standard}/resources/
    transforms/        # XSL transform stylesheets
    codelists/         # Codelist dictionary XML files
    schematron/        # Cross-cutting Schematron rules
    bundles/           # ZIP download packages
    namespace-tools/   # Namespace tools

  json/{standard}/{-part}/{module}/{version}/
    *.json             # JSON Schema definitions
    examples/          # JSON example instances
```

### How to Add a New XSD Schema Package

1. Create directory: `{standard}/{-part}/{module}/{version}/`
2. Place main XSD: `{module}.xsd` (3-char name)
3. Place Schematron alongside: `{module}.sch` (optional)
4. Place examples: `examples/{name}.xml`
5. Place docs: `index.adoc`
6. Place diagrams: `{module}.png`
7. Register in `lxr_packages.yml`:
   ```yaml
   - name: "{standard}-{module}-{version}"
     title: "ISO {standard} — {Description} ({module} v{version})"
     standard: "{standard}"
     status: "current"
     description: "One-line description."
     files:
       - "{standard}/{-part}/{module}/{version}/{module}.xsd"
   ```

### How to Add a New JSON Schema Package

1. Create directory: `json/{standard}/{-part}/{module}/{version}/`
2. Place schema: `{name}.json`
3. Place examples: `examples/{name}.json`
4. Register in `json_packages.yml`

### How to Add Codelist Dictionaries

1. Place in: `{standard}/resources/codelists/{CategoryCode}.xml`
2. Follow GML CodelistDictionary XML format

### How to Add XSL Transform Stylesheets

1. Place in: `{standard}/resources/transforms/{category}/{name}.xsl`
2. Optionally add description to `resource_descriptions.yml`

### How to Add Schematron Validation Rules

1. Schema-specific: `{standard}/{-part}/{module}/{version}/{module}.sch`
2. Cross-cutting: `{standard}/resources/schematron/{name}.sch`

### Rules

- Examples: Always in `examples/` subdir, never loose in version dir
- Bundles: Always in `resources/bundles/`, never in version dirs
- Codelists: Always in `resources/codelists/`, never in version dirs
- XSD URLs are immutable — never move a published XSD file
