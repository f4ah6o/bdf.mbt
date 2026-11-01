# Jw_cad compatibility fixtures

The fixtures are the upstream `converter/jww/testdata` files at shibukawa/bdf
`4f9af52dca60be1eb0daade39f7dc41d6a1fe431` (MIT license, see
`licenses/Shibukawa-bdf.txt`).

- `shapes.jww`: lines, arcs, circles, ellipses, points, text, dimensions,
  solids and blocks in layer groups, from a current Jw_cad version.
- `old.jww`: a version 2 file.

`convert/jww/jww_wbtest.mbt` converts the fixtures in the MoonBit tests.
`compat/converter/phase5-test.mjs` compares page geometry, layers and text
with the upstream converter.
