# draw.io compatibility fixtures

The fixtures are the upstream `converter/drawio/testdata` files at
shibukawa/bdf `4f9af52dca60be1eb0daade39f7dc41d6a1fe431` (MIT license, see
`licenses/Shibukawa-bdf.txt`).

`convert/drawio` reads uncompressed and compressed XML, SVG `content` exports
and PNG `tEXt`/`zTXt` exports. Every diagram becomes a fixed view with its own
title and text index; content bounds plus a 10 px border size the page, and
draw.io layers become BDF layers. `UserObject`/`object` wrappers, parent
offsets, a practical mxGraph/flowchart/UML/BPMN shape registry, perimeters for
edge attachment, waypoints and arrowheads, edge-label anchors, label rotation
and wrapping, per-run HTML bold/italic/underline/colour/size, and best-effort
LaTeX→Unicode conversion. Remaining gaps: the large AWS/Azure/GCP/Cisco
stencil tables and their full XML geometry, a real formula/typesetting engine
(stacked fractions, MathJax metrics), images, gradients/shadows/sketch
styles, line jumps and obstacle-aware routing; straight/curved edges,
orthogonal/elbow routes and start/end marker variants are supported. Unknown
stencils are drawn
as labelled rectangles with a once-per-name warning.
