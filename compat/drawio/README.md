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
LaTeX→Unicode conversion. The embedded AWS4 stencil library and the
aws/aws2/aws3d legacy→AWS4 substitution tables are implemented (the Pages
`aws.drawio` fixture converts with no stencil fallback; see
`convert/drawio/aws_sample_wbtest.mbt`); the Azure, GCP and Cisco stencil
tables remain unported. Remaining gaps: a real formula/typesetting engine
(stacked fractions, MathJax metrics), images, gradients/shadows/sketch
styles, Azure/GCP/Cisco stencil parity, line jumps and obstacle-aware routing; straight/curved edges,
orthogonal/elbow routes and start/end marker variants are supported. Unknown
stencils are drawn
as labelled rectangles with a once-per-name warning.

## Same-renderer AWS parity oracle (2026-11-12)

Upstream provenance: `shibukawa/bdf` commit
`a5e4d7a6b202cfe73de44b0be51f6fb86cd8ee22`, `converter/drawio`
(`label.go` readTextProps/getSpacing drive this port's directional label
spacing in `convert/drawio/text.mbt`). The Pages sample content is the
same input on both sides: `site/samples/aws.drawio` ==
`compat/drawio/fixtures/aws.drawio` ==
upstream `converter/drawio/testdata/aws.drawio`
(sha256 `18b91cb3554f47f6963650f2b058737bfb85cb726d363a3e7f1d9013b531e203`).

Reproduce (real commands; executed 2026-11-12 on this worktree):

```sh
UPSTREAM=/path/to/shibukawa-bdf OUT=/tmp/aws-oracle \
  sh compat/drawio/oracle-aws.sh
```

The script drives the MoonBit converter worker through node:worker_threads
(`oracle-worker.mjs` + `oracle-worker-shim.mjs`) with no npm dependency, and
the upstream Go CLI is the single renderer for both sides. Measured evidence
(same input, same renderer): group labels "AWS Cloud"/"Region" draw at
TRANSLATE x=104/119 (pre-fix 81.5/96.5, inside the 30-unit corner icon);
go.png renders 436x211 vs moon.png 435x210 (the one-unit page-size
difference is separate from the label work), pixel-difference fraction 0.178 (0.179
pre-fix, from `PIL.ImageChops.difference`, pixels with channel sum > 30,
after resizing to the common size). The remaining page-bbox off-by-one
(436x211 vs 435x210) and the missing font embedding parts (upstream embeds
2) are NOT addressed here: font embedding is an uncontrolled configuration
difference between the upstream CLI and the no-font MoonBit worker, and
edge route paths are a separate slice.

## Open-arrow regression

`moon test convert/drawio --target js` (also wasm-gc/native) exercises open
marker geometry, reversed/start arrows, vertical paths, strokeWidth2 and zero
length. After `npm ci` and `moon build --target js native_converter_worker`,
run `node compat/drawio/open-arrow-test.mjs` for the real AWS XML-to-BDF path:
the independent upstream decoder checks Current e2's shortened line, three-point
V and marker pen width2. Formula provenance is upstream
`converter/drawio/shapes_core.go` `createOpenArrow(2)` at the commit above.

A separate official draw.io v32.7.1 browser capture at zoom100%/DPR1 confirmed
Current e2's source-unit open tip318.882 and shortened line endpoint317.764
for endSize10/strokeWidth1. The AWS fixture contains4 Current open arrows and11
Legacy block arrows. This change fixes open-marker geometry only: orthogonal
waypoints, rounded joins, block/classic markers and complete15-edge visual
parity remain separate work. The original routing points still drive labels;
only the rendered line's endpoint copy is shortened.
