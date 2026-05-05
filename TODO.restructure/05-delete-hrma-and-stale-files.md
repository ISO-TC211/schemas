# Phase 5: Delete hrma Gem and Stale Infrastructure

The hrma gem is fully obsolete:
- `build documentation` command — already deleted in restructure branch
- `schemas manifest update/list/validate` — manages old `schemas.yml` format, superseded by `lxr_packages.yml`/`json_packages.yml`
- `config get/set` — only used by deleted build pipeline
- CI workflow already broken (calls removed commands)

## Files to Delete

### hrma gem
- [ ] `lib/hrma/` directory (cli.rb, config.rb, hrma.rb, version.rb, commands/)
- [ ] `bin/` directory (hrma binary)
- [ ] `spec/` directory
- [ ] `hrma.gemspec`
- [ ] `Gemfile` (hrma's Gemfile, NOT the site's)
- [ ] `Gemfile.lock` (hrma's lock file)

### Old manifests
- [ ] `schemas.yml`
- [ ] `schemas.minimal.yml`
- [ ] `schemas.test4.yml`

### Stale files
- [ ] `.archive/` directory (xs3p.tar.gz, xsdvi-1.0.jar)
- [ ] `xsdvi.log` (if exists)
- [ ] `.github/workflows/build.yml` (broken CI referencing hrma build)

### .gitignore cleanup
- [ ] Remove stale entries: `xsdvi/`, `transforms/`, `.archive/`, `.vscode/`
- [ ] Keep: `_site/`, `.DS_Store`, `*.log`

## Notes
- Verify `.github/workflows/deploy.yml` doesn't depend on hrma before deleting build.yml.
- The site repo's `Gemfile` and `Gemfile.lock` are NOT affected — only the schemas repo's.
