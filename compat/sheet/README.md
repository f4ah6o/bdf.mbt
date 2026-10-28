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
