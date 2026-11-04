# EPUB compatibility fixtures

`basic.epub` and `fixed.epub` are the upstream
`converter/epub/testdata` fixtures at
shibukawa/bdf `4f9af52dca60be1eb0daade39f7dc41d6a1fe431`
(MIT license, see `licenses/Shibukawa-bdf.txt`).

`basic.epub` is a reflowable book. `convert/epub/fixtures_generated_wbtest.mbt`
embeds it for the MoonBit tests; this port reads the container, package
manifest and spine, then lays out the XHTML chapters in reader mode.

`fixed.epub` is a pre-paginated picture book: `rendition:layout` is
`pre-paginated`, `rendition:spread` is `landscape`, the spine reads
right to left, and every linear spine item is one picture. It covers the
fixed-layout path:

- an image-only spine entry (`cover.svg`, which wraps `cover.png`),
- three XHTML pages with a 600 x 800 viewport and one `img` each,
- an XHTML page drawn with an inline SVG gradient,
- an XHTML page whose picture is an external SVG file with alternative text,
- one non-linear navigation document outside the reading order.

The upstream expectations are 6 pages and 6 pictures, each page 450 x 600 pt
with the picture fitted and centered, one fixed view with direction `rtl` and
the DC title `固定レイアウトのテスト`, two SVG image parts (the inline one and
the external file), no text index, and exactly one warning that contains
`outside the reading order`.

`convert/epub/fixtures_generated_wbtest.mbt` embeds both fixtures for the
MoonBit tests. `compat/converter/phase3-test.mjs` exercises the native Worker.
Remote images, CSS and embedded fonts remain documented gaps.
