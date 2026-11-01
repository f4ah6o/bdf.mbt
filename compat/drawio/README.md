# draw.io compatibility fixtures

The fixtures are the upstream `converter/drawio/testdata` files at
shibukawa/bdf `4f9af52dca60be1eb0daade39f7dc41d6a1fe431` (MIT license, see
`licenses/Shibukawa-bdf.txt`).

`convert/drawio` currently ports uncompressed XML: the first diagram, vertices
(rectangles/ellipses/text, fill/stroke/font colours, rotation ignored), simple
edges, labels and a text index. Compressed diagrams, stencils, HTML/math
formatting, automatic wrapping, edge routing and page auto-fit are documented
gaps.
