# OOXML package compatibility fixtures

`verify-package.mjs` compares package part lookup, decompression, relationships,
relationship priority and XLSX detection against upstream. The cases include
real XLSX files and synthetic ZIP archives with duplicate, differently cased
and Windows-style part names.

After building the JavaScript target, run `node compat/ooxml/verify-package.mjs`.
To regenerate the fixtures, copy `generate_package_test.go` without its build
tag into upstream `converter/internal/ooxml` and run `TestCodexOOXMLPackage`
with `BDF_FIXTURE_ROOT` set to this repository.

`verify-theme-fonts.mjs` checks major and minor theme fonts, script fallbacks,
and references against upstream for real and generated workbooks. To regenerate
its fixtures, copy `generate_theme_fonts_test.go` without its build tag into
upstream `converter/xlsx` and run `TestCodexThemeFonts` with
`BDF_FIXTURE_ROOT` set to this repository.
