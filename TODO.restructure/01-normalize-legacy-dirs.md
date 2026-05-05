# Phase 1: Normalize Legacy Directory Naming

Move legacy-named directories to the `standard/-part/module/version/` pattern.

## Moves Required

| Current Path | Target Path |
|---|---|
| `19155/gpi/1.0/` | `19155/-/gpi/1.0/` |
| `19165/gpm/1.0/` | `19165/-/gpm/1.0/` |
| `19110/fcc/1.0/` | `19110/-/fcc/1.0/` |
| `19110/gfc/1.1/` | `19110/-/gfc/1.1/` |
| `19111/rbc/1.0/` | `19111/-/rbc/1.0/` |
| `19111/rce/1.0/` | `19111/-/rce/1.0/` |
| `19119/srv/` | `19119/-/srv/1.0/` |

## Steps

- [ ] `git mv 19155/gpi 19155/-/gpi` (includes 1.0/ subdirectory)
- [ ] `git mv 19165/gpm 19165/-/gpm`
- [ ] `git mv 19110/fcc 19110/-/fcc` (includes 1.0/)
- [ ] `git mv 19110/gfc 19110/-/gfc` (includes 1.1/ and 2.2.0/)
- [ ] `git mv 19111/rbc 19111/-/rbc`
- [ ] `git mv 19111/rce 19111/-/rce`
- [ ] `git mv 19119/srv 19119/-/srv` then `git mv 19119/-/srv/srv 19119/-/srv/1.0` if needed
- [ ] Update `lxr_packages.yml` paths for all moved packages
- [ ] Update `json_packages.yml` if any paths affected
- [ ] Verify all XSD files still referenced by `lxr_packages.yml` exist at new paths
- [ ] Add redirect entries to site's `_data/redirects.yml` for each moved file
