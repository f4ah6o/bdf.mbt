# Visio VSDX compatibility fixtures

The fixtures are the upstream `converter/visio/testdata` files at
shibukawa/bdf `4f9af52dca60be1eb0daade39f7dc41d6a1fe431`
(MIT license, see `licenses/Shibukawa-bdf.txt`).

- `shapes.vsdx`: two foreground pages, a shared background page, masters,
  geometry, text, hidden layers, links and an embedded picture.
- `flow.vsdx`: a flowchart with background page and master shapes.

`convert/visio/fixtures_generated_wbtest.mbt` embeds them for the MoonBit unit
tests. `compat/converter/phase2-test.mjs` compares page count, page geometry
and layer roles with upstream through `@bdfkit/convert-all`.

This port reads Visio 2013+ packages, page sheets, pages and backgrounds,
masters, layers, ShapeSheet cells, geometry rows, solid fills/strokes, text and
text indexes. Theme quick-style resolution, shadows, hyperlinks, embedded
pictures and DrawingML text layout are documented gaps.
