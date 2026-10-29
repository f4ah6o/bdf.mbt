# Sheet viewport fixture

The fixture was generated with shibukawa/bdf v0.2.1. It contains six tiles,
nonuniform grid runs with hidden entries, text, an embedded font, an image and shapes crossing
tile boundaries. The comparison renders the same view with upstream
`PageRenderer.renderSheet` and the MoonBit single and split viewport APIs.
It also compares scrolling sheet mounts, including HiDPI, resizing, tile
fetching, cancellation, overlapping mounts and resource cleanup.
Interactive mounts also exercise text selection across visible tiles,
clipboard output, pointer targeting and retention while scrolling, in single,
split and password-encrypted files. Sheet search and rectangular cell selection
are tested against upstream search, clipboard serialization and display.
The search comparison puts both inputs on their own compositing layers to avoid
Chromium blending their glyphs with the colored canvas in Linux screenshots.
The zoom fixtures compare the upstream `Viewer` against the MoonBit live
sheet at several zooms and device pixel ratios, including scrolling before a
zoom change. They also check selectable text, search, clipped tile extents and
superseded asynchronous drawing and search requests.

From an upstream checkout, regenerate it with:

```sh
go run /absolute/path/to/bdf.mbt/compat/sheet/generate.go /absolute/path/to/bdf.mbt/compat/sheet/fixture.bdf /absolute/path/to/bdf.mbt/compat/sheet/split /absolute/path/to/bdf.mbt/compat/visual/synthetic.ttf /absolute/path/to/bdf.mbt/compat/sheet/encrypted.bdf /absolute/path/to/bdf.mbt/compat/sheet/encrypted-split
go run /absolute/path/to/bdf.mbt/compat/sheet/cells-generate.go /absolute/path/to/bdf.mbt/compat/sheet/cells.bdf /absolute/path/to/bdf.mbt/compat/sheet/cells-split /absolute/path/to/bdf.mbt/compat/sheet/cells-encrypted.bdf /absolute/path/to/bdf.mbt/compat/sheet/cells-encrypted-split
```

Column width fixtures use the upstream sheet and CSV converters at commit
`4f9af52dca60be1eb0daade39f7dc41d6a1fe431` with system fonts disabled. They
cover headers, numeric alignment, long values, East Asian characters, line
breaks and table filter buttons. From that upstream checkout, regenerate them
and compare the result with:

```sh
go run /path/to/bdf.mbt/compat/sheet/generate-grid.go > /path/to/bdf.mbt/compat/sheet/upstream.json
go run /path/to/bdf.mbt/compat/sheet/generate-heights.go > /path/to/bdf.mbt/compat/sheet/heights.json
go run /path/to/bdf.mbt/compat/sheet/generate-geometry.go > /path/to/bdf.mbt/compat/sheet/geometry.json
go run /path/to/bdf.mbt/compat/sheet/generate-draw.go > /path/to/bdf.mbt/compat/sheet/drawing.json
cp /path/to/bdf.mbt/compat/sheet/generate-styles_test.go converter/xlsx/
BDF_SHEET_STYLES=/path/to/bdf.mbt/compat/sheet/table-styles.json BDF_SHEET_STYLE_CELLS=/path/to/bdf.mbt/compat/sheet/style-cells.json go test ./converter/xlsx -run '^TestGenerateGridStyle' -count=1
go run /path/to/bdf.mbt/compat/sheet/generate-styled.go /path/to/bdf.mbt/compat/sheet/table-styles.json > /path/to/bdf.mbt/compat/sheet/styled.json
node /path/to/bdf.mbt/compat/sheet/generate-style-source.mjs
node /path/to/bdf.mbt/compat/sheet/generate-style-test.mjs
moon build --target js
npm run test:sheet-compat
```

The style fixtures cover all 60 built-in table styles, including header and
stripe precedence, borders, filter buttons, empty rows and tile boundaries.
The upstream style data is derived from the ECMA-376 SpreadsheetML
`presetTableStyles.xml`; see its `tools/gen-tablestyles.py` for provenance.

For line wrapping, copy `generate-wrap_test.go` into the upstream
`converter/xlsx` directory and regenerate the 510-case fixture and the
exhaustive Unicode break digests with:

```sh
BDF_SHEET_WRAP_FIXTURE=/path/to/bdf.mbt/compat/sheet/wrap.json BDF_SHEET_BREAK_FIXTURE=/path/to/bdf.mbt/compat/sheet/break-sha256.txt go test ./converter/xlsx -run '^TestCodexGenerateWrap$' -count=1
```
