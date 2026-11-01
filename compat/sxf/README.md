# SXF compatibility fixtures

The fixture is the upstream `converter/sxf/testdata/shapes.sfc` at
shibukawa/bdf `4f9af52dca60be1eb0daade39f7dc41d6a1fe431` (MIT license, see
`licenses/Shibukawa-bdf.txt`).

`convert/sxf` currently ports the SFC text feature format: sheets, layers,
predefined and user colours, line types and widths, lines, polylines, circles,
arcs, ellipses, elliptic arcs, text, point markers, splines, clothoids and
compound figures. P21/P2Z input, dimensions, labels and hatches are documented
gaps: they are reported with warnings or an explicit error.
