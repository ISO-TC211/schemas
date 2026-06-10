# Update resource scanner for top-level resources/

- Add glob pattern `resources/**/*.xml` to `RESOURCE_CATEGORIES` in `generate_configs.rb` (currently only scans `*/resources/codelists/**/*.xml` under per-standard dirs)
- Ensure the general codelists.xml appears in `resources_index.json` as a cross-cutting resource

Repo: ISO-TC211/schemas.isotc211.org
