# Update codeList URLs in example XML files

- 421 references in example XML files use broken `https://schemas.isotc211.org/Resources/codelists.xml#...`
- Update to `https://schemas.isotc211.org/resources/codelists/codelists.xml#...`
- Also update 56 references using `https://schemas.isotc211.org/19115/resources/Codelist/cat/codelists.xml#...` to the canonical URL
- Leave external URLs (standards.iso.org, iana.org, loc.gov) untouched — those are not ours to change

Repo: ISO-TC211/schemas
