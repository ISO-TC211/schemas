# Add redirect for old /Resources/codelists.xml URL

Add to `_data/redirects.yml`:
```yaml
- from: /Resources/codelists.xml
  to: /resources/codelists/codelists.xml
```

The `redirect_generator.rb` copies the actual XML file to the old path (`.xml` is in `DATA_EXTENSIONS`), so XML parsers dereferencing the old URL get real content — no breakage.

Repo: ISO-TC211/schemas.isotc211.org
