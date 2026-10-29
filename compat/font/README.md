# SFNT compatibility fixtures

The font fixtures are copied from `converter/font/testdata` in
[shibukawa/bdf](https://github.com/shibukawa/bdf), pinned at commit
`4f9af52dca60be1eb0daade39f7dc41d6a1fe431`. They include STIX Two Text,
licensed under the [SIL Open Font License](fixtures/OFL.txt). The separate
`compat/visual/synthetic.ttf` fixture is generated in this repository.

`upstream.json` records face metadata, metrics, and hashes of every Unicode
mapping and horizontal advance. `synthetic.json` covers constructed and
malformed cmap subtables. `rebuild.json` records rebuilt cmap hashes for the synthetic fonts;
`defaults.json` checks fonts with missing and truncated tables. `subset.json`
checks real TrueType subsets, and `subset-edge.json` checks composite cycles,
missing metrics, malformed and long `loca` offsets.
`geometry.json` and `drawing.json` record grid dimensions and drawing objects for each
font and language scenario. `csv.json` covers full CSV documents with whole-font
embedding, TrueType and CFF subsetting and individually selected TTC faces, and includes upstream BDFs for the visual comparison. `npm run test:font-compat` checks them against the
MoonBit implementation after `moon build --target js`.

To regenerate the JSON files, copy each Go generator into a directory under
an upstream checkout (its imports use upstream internal packages) and run it
with the absolute path to this repository as its argument. Redirect the output
to the corresponding JSON file. Use the pinned upstream revision above.

`node compat/font/visual-compare.mjs` renders nine upstream and MoonBit CSV
documents with actual embedded TTF/OTF and TTC faces and compares the screenshots
using vlmkit at three viewport sizes.

`outlines.json.gz` compares TrueType outline commands and glyph bounds with upstream, including
real fonts and collections, composite transforms, recursive components and
mutated or truncated glyph data. Run `npm run test:font-outline` and
`npm run test:font-outline-visual` after a JS build. The latter renders 72
outlines and compares them with vlmkit. To regenerate, copy
`generate-outline_test.go` without its build tag into upstream `internal/sfnt`
and run `BDF_FIXTURE_ROOT=/path/to/bdf.mbt go test ./internal/sfnt -run '^TestCodexOutlines$'`.
