# TIFF compatibility fixtures

The fixtures are the upstream `converter/tiff/testdata` files and the broader
`converter/internal/tiff/testdata` files at shibukawa/bdf
`4f9af52dca60be1eb0daade39f7dc41d6a1fe431` (MIT license, see
`licenses/Shibukawa-bdf.txt`).

- `scan.tif`: Group 4 bilevel, JPEG YCbCr and LZW RGB pages.
- `fax.tif`: two Group 3 pages with fill bits and two-dimensional coding.
- `orientation.tif`: LZW RGB pages with all eight Orientation values.
- `internal/`: None, LZW, Deflate, PackBits, planar, tile, 16-bit, palette,
  alpha, CMYK and BigTIFF pages used by the upstream decoder tests.

`convert/tiff/fixtures_generated_wbtest.mbt` embeds the three converter
fixtures for the MoonBit unit tests. `compat/converter/phase1-test.mjs`
compares both implementations through `@bdfkit/convert-all`, including decoded
image pixels. JPEG-compressed and YCbCr pages are a documented gap and are left
blank with a warning; the test skips only those pages.
