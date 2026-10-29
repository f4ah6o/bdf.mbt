# Font specimen program compatibility

These fixtures record glyph programs and whole and pruned sample programs from
shibukawa/bdf at commit `4f9af52dca60be1eb0daade39f7dc41d6a1fe431`. TrueType,
CFF, TTC, WOFF, color, variable, malformed bitmap-strike and CFF fallback cases are included.
The pruned cases compare the automatically computed GSUB reachability set with
upstream and also test the explicit-glyph API. Program sizes and SHA-256 hashes are
compared with upstream; representative glyph programs are also rendered and
compared with vlmkit. `plan.json.gz` additionally compares sample language,
waterfall and fallback selection across real and synthetic fonts.
`glyphnames.json.gz` covers post, CFF and CID glyph names and malformed data.
`coverage.json.gz` checks Unicode 17 block coverage and assigned counts.
`names.json.gz` compares decoded multilingual names and selection priorities.
`glyphs.json.gz` compares glyph mappings, labels, alternatives, and Unicode scripts.
`variations.json.gz` covers real, truncated and mutated fvar tables.
`info.json.gz` checks language, variation-sequence and color metadata.
`kerning.json.gz` checks GPOS and legacy kerning descriptions.
`overview.json.gz` compares the ordered overview sections and table sizes, including
WOFF, collections, boundary values, and mutated font tables.
`features.json.gz` verifies grouped OpenType features, their lookups, script
users, UI names, characters and displayed descriptions against upstream.
`scroll.json.gz` checks page cuts, row positions, kept headings and anchors.
`paths.json.gz` compares encoded BDF paths for TrueType and CFF glyphs.
`paint.json.gz` compares complete outlined-glyph drawing objects, including
path caching, transforms and alternative text. `glyph-paint.json.gz` checks
embedded glyph runs, non-contiguous positions and outline fallback.
`sample-paint.json.gz` checks sample text shaping, language tags, RTL and
glyph fallback with and without embedded fonts. `programs.json.gz` checks
license-based embedding, sample programs, collection sharing and resource counts.
`document-plan.json.gz` compares document metadata and view names with full
upstream conversions. `texter.json.gz` checks font selection, text runs,
widths, fitting, wrapping and measured-font usage. `ui-fonts.json.gz` checks
font embedding and system-font records, including license restrictions.
`ui-paint.json.gz` verifies text, sample and glyph drawing in the same object.
`page-paint.json.gz` checks complete scroll page objects and anchor links.

After `moon build --target js`, run `npm run test:specimen` and
`npm run test:specimen-plan`, `npm run test:specimen-names`,
`npm run test:specimen-coverage`, `npm run test:specimen-metadata`,
`npm run test:specimen-glyphs`, `npm run test:specimen-variations`,
`npm run test:specimen-info`, `npm run test:specimen-overview`,
`npm run test:specimen-features`, `npm run test:specimen-scroll`,
`npm run test:specimen-path`, `npm run test:specimen-paint`,
`npm run test:specimen-glyph-paint`, `npm run test:specimen-sample-paint`,
`npm run test:specimen-programs`, `npm run test:specimen-document-plan`,
`npm run test:specimen-texter`, `npm run test:specimen-ui-fonts`,
`npm run test:specimen-ui-paint`, `npm run test:specimen-page-paint`, and
`npm run test:specimen-visual`. To regenerate, copy `generate_test.go` without
its first `//go:build ignore` line into the upstream checkout at
`converter/font/codex_specimen_test.go`, then run:

```sh
BDF_FIXTURE_ROOT=/path/to/bdf.mbt go test ./converter/font -run '^TestCodexGlyphPrograms$' -count=1
```

The test writes `compat/specimen/upstream.json.gz` in the target repository.

To regenerate sample-plan cases, also copy `generate-plan_test.go` without its
build tag into the upstream `converter/font` package and run
`go test ./converter/font -run '^TestCodexSamplePlans$'`, with the same
`BDF_FIXTURE_ROOT` environment variable.

To regenerate glyph-name cases, copy `generate-glyphnames_test.go` without its
build tag into the upstream `converter/font` package, then run
`go test ./converter/font -run '^TestCodexGlyphNames$'` with the same fixture root.

To regenerate Unicode data and coverage cases, copy `generate-unicode_test.go`
and `generate-coverage_test.go` without their build tags into upstream
`converter/font`, along with `generate_test.go`, and run the tests
`TestCodexUnicodeTables` and `TestCodexCoverage` with the same fixture root.
Use Go with Unicode 17.0.0; the generator checks the version.

To regenerate name-record cases, copy `generate-names_test.go` without its
build tag into upstream `converter/font`, along with `generate_test.go`, and run
`TestCodexNameRecords` with the same fixture root.

To regenerate glyph and script-count cases, copy `generate-glyphs_test.go`
without its build tag into upstream `converter/font`, along with `generate_test.go`,
and run `TestCodexGlyphs` with the same fixture root and Unicode 17 Go toolchain.

To regenerate variation cases, copy `generate-variations_test.go` without its
build tag into upstream `converter/font`, along with `generate_test.go`, and run
`TestCodexVariations` with the same fixture root.

To regenerate the table-information cases, copy `generate-info_test.go` without
its build tag into upstream `converter/font`, along with `generate_test.go`, and
run `TestCodexInfoTables` with the same fixture root.

To regenerate kerning cases, first generate `compat/gsub/gpos.json.gz`, then copy
`generate-kerning_test.go` without its build tag into upstream `converter/font`
with `generate_test.go` and run `TestCodexKerning`.

To regenerate overview cases, first generate `compat/specimen/upstream.json.gz`,
then copy `generate-overview_test.go` without its build tag into upstream
`converter/font` alongside `generate_test.go` and run `TestCodexOverview`.

To regenerate feature-group cases, first generate `compat/gsub/layout.json.gz`,
then copy `generate-features_test.go` without its build tag into upstream
`converter/font` alongside `generate_test.go` and run `TestCodexFeatureGroups`.

To regenerate scroll-layout cases, copy `generate-scroll_test.go` without its
build tag into upstream `converter/font` alongside `generate_test.go` and run
`TestCodexScroll` with the same fixture root.

To regenerate specimen paths, first generate `compat/font/outlines.json.gz`
and `compat/font/cff-outlines.json.gz`, then copy `generate-path_test.go`
without its build tag into upstream `converter/font` alongside `generate_test.go`
and run `TestCodexSpecimenPaths` with the same fixture root.

To regenerate outline-painting cases, copy `generate-paint_test.go` without
its build tag into upstream `converter/font` alongside `generate_test.go` and
run `TestCodexOutlinePainting` with the same fixture root.

To regenerate embedded-glyph painting cases, copy `generate-glyph-paint_test.go`
without its build tag into upstream `converter/font` alongside
`generate_test.go` and `generate-paint_test.go`, then run
`TestCodexGlyphPainting` with the same fixture root.

To regenerate sample-paint cases, copy `generate-sample-paint_test.go` without
its build tag into upstream `converter/font` alongside `generate_test.go` and
run `TestCodexSamplePainting` with the same fixture root. Generate Unicode 17
simple-fold mappings by copying `generate-fold_test.go` into the same package
and running `TestCodexSimpleFold` with Go Unicode 17, then format with `moon fmt`.

To regenerate embedding cases, copy `generate-programs_test.go` without its
build tag into upstream `converter/font` alongside `generate_test.go` and run
`TestCodexSpecimenPrograms` with the same fixture root.

To regenerate document-plan cases, copy `generate-document-plan_test.go`
without its build tag into upstream `converter/font` alongside `generate_test.go`
and run `TestCodexDocumentPlan` with the same fixture root.

To regenerate text-layout cases, copy `generate-texter_test.go` and
`generate_test.go` without their build tags into upstream `converter/font`,
and copy `generate-fontset-helper.go` without its build tag into upstream
`converter/internal/fontset` as a temporary Go source. Run
`TestCodexSpecimenTexter` with the same fixture root, then remove the helper
from the upstream checkout.

To regenerate UI font cases, copy `generate-ui-fonts_test.go` without its
build tag into upstream `converter/font` alongside `generate_test.go`, then
run `TestCodexSpecimenUIFonts` with the same fixture root.

To regenerate UI painting cases, copy `generate-ui-paint_test.go` without its
build tag into upstream `converter/font` alongside `generate_test.go` and run
`TestCodexSpecimenUIPaint` with the same fixture root.

To regenerate page painting cases, copy `generate-page-paint_test.go` without
its build tag into upstream `converter/font` alongside `generate_test.go` and
run `TestCodexSpecimenPagePaint` with the same fixture root.

To regenerate glyph-grid page cases, copy `generate-glyph-view_test.go` without
its build tag into upstream `converter/font` alongside `generate_test.go` and
run `TestCodexGlyphView` with the same fixture root.

To regenerate character-chart glyph-cell cases, copy `generate-chart-cell_test.go`
without its build tag into upstream `converter/font` alongside `generate_test.go`
and run `TestCodexChartCells` with the same fixture root.
