# Contributing to ISO/TC 211 Schemas

Thank you for contributing! Before adding or updating schemas, please read these
guidelines carefully. The CI pipeline validates every push — failing validation
blocks all downstream builds and site deployment.

## Before you push

Always run this command locally:

```sh
ruby tools/validate_manifests.rb
```

If this fails, **do not push** — fix the errors first. CI runs the same check
and will block the build on failure.

## Directory structure

Schemas follow a strict directory layout that mirrors how they are served at
https://schemas.isotc211.org/.

### XML (XSD) schemas

```
{standard}/{-part}/{module}/{version}/
  {module}.xsd              # Main entry point (3-letter lowercase)
  *.xsd                     # Additional schemas
  *.sch                     # Schematron rules
  index.adoc                # Documentation
  examples/*.xml            # Example instances
```

### JSON schemas

```
json/{standard}/{-part}/{module}/{version}/
  *.json                    # JSON Schema definitions
  examples/*.json           # Example instances
```

**Important:** Do not flatten or rearrange these directories. The path
components (`standard`, `part`, `module`, `version`) are meaningful — they
determine the schema's URL and how `$ref` references resolve.

Example: ISO 19115-4 metadata JSON schemas go in:

```
json/19115/-4/mdj/1.0.0/
  19115-4.json    # Entry point
  mdj.json        # Metadata definitions
  Feature.json    # GeoJSON Feature
```

## Adding an XML (XSD) schema

1. Create the directory: `mkdir -p {standard}/{-part}/{module}/{version}/`
2. Place the `.xsd` files there (entry point named after the module).
3. Optionally add `.sch`, `index.adoc`, `examples/*.xml`.
4. Add an entry to `lxr_packages.yml` (see README for fields).
5. Run `ruby tools/validate_manifests.rb` — must pass.
6. Commit and push.

## Adding a JSON schema

1. Create the directory: `mkdir -p json/{standard}/{-part}/{module}/{version}/`
2. Place the `.json` files there.
3. Add an entry to `ljr_packages.yml` (see README for fields).
4. Run `ruby tools/validate_manifests.rb` — must pass.
5. Commit and push.

## JSON Schema URI conventions

### `$id` — every JSON schema MUST have one

The `$id` identifies the schema and sets the base URI for resolving `$ref`.
It must match the URL where the schema is served:

```
"$id": "https://schemas.isotc211.org/json/{standard}/{-part}/{module}/{version}/{filename}.json"
```

Example for `json/19115/-4/mdj/1.0.0/mdj.json`:

```json
"$id": "https://schemas.isotc211.org/json/19115/-4/mdj/1.0.0/mdj.json"
```

**Do not use** `https://schemas.isotc211.org/schemas/json/...` (note the extra
`/schemas/` segment) — the correct URL path starts with `/json/` directly.

### `$ref` — referencing other schemas

- **ISO/TC 211 schemas** — use the absolute URL matching the target's `$id`:

  ```json
  "$ref": "https://schemas.isotc211.org/json/19157/-1/dqc/1.0.0/dqc.json#DataQuality"
  ```

- **External schemas** (e.g., GeoJSON) — use the canonical external URL:

  ```json
  "$ref": "https://geojson.org/schema/Feature.json"
  ```

- **Internal references** within the same file — use `#` anchors:

  ```json
  "$ref": "#MetadataRecords"
  ```

## Common mistakes to avoid

- **Moving files without updating manifests.** The manifests (`lxr_packages.yml`,
  `ljr_packages.yml`) list every file by its repo-relative path. If you move,
  rename, or delete a schema file, you must update the corresponding manifest.
  Otherwise `validate_manifests.rb` will fail.

- **Placing schemas in the wrong directory.** Each schema belongs under its
  standard's directory tree, not in a flat location. A data quality schema
  (`dqc.json`) for ISO 19157-1 belongs at `json/19157/-1/dqc/1.0.0/dqc.json`,
  not under `json/19115/-4/`.

- **Missing `$id` in JSON schemas.** Without `$id`, `$ref` resolution has no
  base URI and may produce incorrect results.

- **Using old URL patterns.** The correct prefix is
  `https://schemas.isotc211.org/json/...`, not
  `https://schemas.isotc211.org/schemas/json/...`.

## Branch protection

The `main` branch requires CI to pass before merging. Please submit changes via
pull request and wait for the CI pipeline to complete successfully.
