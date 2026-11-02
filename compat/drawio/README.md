# draw.io compatibility fixtures

The fixtures are the upstream `converter/drawio/testdata` files at
shibukawa/bdf `4f9af52dca60be1eb0daade39f7dc41d6a1fe431` (MIT license, see
`licenses/Shibukawa-bdf.txt`).

`convert/drawio` reads uncompressed and compressed XML, SVG `content` exports
and PNG `tEXt`/`zTXt` exports. Every diagram becomes a fixed view with its own
title and text index; content bounds plus a 10 px border size the page, and
draw.io layers become BDF layers. `UserObject`/`object` wrappers, parent
offsets, basic shapes, edges with waypoints and arrowheads, label positions,
wrapping and common HTML tags are flattened into text; per-run bold/italic/colour styling is still a gap.

Remaining gaps: full stencil libraries (AWS/BPMN/UML), LaTeX math typesetting,
images, sketch styles, line jumps and complex mxGraph edge routing. Unsupported
stencils are drawn as their bounding rectangle with the label.
