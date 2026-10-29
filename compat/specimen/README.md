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
path caching, transforms and alternative text.

After `moon build --target js`, run `npm run test:specimen` and
`npm run test:specimen-plan`, `npm run test:specimen-names`,
`npm run test:specimen-coverage`, `npm run test:specimen-metadata`,
`npm run test:specimen-glyphs`, `npm run test:specimen-variations`,
`npm run test:specimen-info`, `npm run test:specimen-overview`,
`npm run test:specimen-features`, `npm run test:specimen-scroll`,
`npm run test:specimen-path`, `npm run test:specimen-paint`, and
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
