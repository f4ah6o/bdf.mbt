# CGM compatibility fixtures

The fixtures are the upstream `converter/cgm/testdata` files at shibukawa/bdf
`4f9af52dca60be1eb0daade39f7dc41d6a1fe431` (MIT license, see
`licenses/Shibukawa-bdf.txt`).

The fixtures `shapes.cgm`, `illustration.cgm` and `sjis.cgm` are
exercised by `compat/converter/phase5-test.mjs`. `shapes-text.cgm` is
clear-text CGM, which is an explicit error. The second picture of
`illustration.cgm` has no metric scaling; this port sizes it from the VDC
extent, so that page's geometry differs from upstream.

`convert/cgm` ports the binary encoding and the clear-text encoding:
pictures, VDC extents, metric scaling, background colours, the colour
precision, mode and table, line and fill attributes, edge and fill
visibility, polylines, disjoint polylines, markers, polygons, rectangles,
circles, arcs, ellipses, elliptical arcs and text with its character height,
expansion, spacing, path and alignment (APPEND TEXT continues the previous
text). `shapes.cgm` and `shapes-text.cgm` are the same drawing in the two
encodings. gzip (`.cgz`), cell arrays, tiles, hatches, pattern tables and the
specialised attribute elements are documented gaps; `shapes.cgm` draws its
background through a cell array, so it still renders blank.
