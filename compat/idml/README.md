# InDesign IDML compatibility fixtures

The fixtures are the upstream `converter/idml/testdata` files at
shibukawa/bdf `4f9af52dca60be1eb0daade39f7dc41d6a1fe431`
(MIT license, see `licenses/Shibukawa-bdf.txt`).

- `basic.idml`: three pages, a two-page master spread, threaded stories,
  gradients, an embedded PNG and a linked image.
- `vertical.idml`: vertical writing and a table.

`convert/idml/fixtures_generated_wbtest.mbt` embeds the files for the MoonBit
unit tests. `compat/converter/phase2-test.mjs` compares page count, page
geometry and layer roles with upstream through `@bdfkit/convert-all`.

This port currently reads spreads, master spreads, layers, paths, colours,
gradients (first stop), embedded images, stories and text indexes. Text is
drawn on the frame that first uses a story; the upstream DrawingML flow
engine that continues a story through threaded frames is not ported yet and
is reported as a warning. Linked images, PDF/EPS placements, page-number
markers and table stories are documented gaps.
