# Generate HTML codelist browse pages

- Generate a codelist landing page at `/resources/codelists/` listing all codelists parsed from `resources/codelists/codelists.xml`
- Generate per-codelist HTML pages (e.g. `/resources/codelists/CI_RoleCode/`) rendering name, description, and values as a readable table
- Source: parse the cat-encoded codelists.xml, or use the GML per-codelist files in `19115/resources/codelists-gml/gml/`
- This gives human users browseable HTML (addresses w3c/dxwg#975)

Repo: ISO-TC211/schemas.isotc211.org
