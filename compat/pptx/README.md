# PPTX compatibility fixtures

The fixtures compare presentation discovery, slide order and visibility, layout
and master relationships, color mappings, placeholders, and shape transforms
with the upstream Go converter. They use six upstream presentations and a
synthetic package covering strict namespaces, missing relationships, universal
measures, duplicate elements, and markup-compatibility alternatives.

The preset geometry table is generated from the upstream DrawingML preset
definitions: `generate_presets.py` reads
`converter/internal/ooxml/drawingml/presets.xml.gz` and writes
`convert/pptx/presets_generated.mbt`. Run `python3
compat/pptx/generate_presets.py` from the repository root after the upstream
table changes.

To regenerate `presentation_generated_wbtest.mbt`, overlay
`generate_manifest_test.go` without its build tag in upstream `converter/pptx`
and `drawingml_transform_export.go` without its build tag in upstream
`converter/internal/ooxml/drawingml`. Set `BDF_PPTX_FIXTURES` to the upstream
PPTX testdata directory and `BDF_REFERENCE_OUTPUT` to the output file, then run
`TestCodexPPTXManifest` with `-count=1`.

The phase 15 converter test also builds a synthetic deck in the browser with
triangle, diamond, right-arrow, star, hexagon, wedge-rectangle-callout and
flowchart-decision presets, a themed `p:style` fill/line reference, a
layout-inherited placeholder and an unknown preset. It converts it with both
the upstream converter and this package, applies the draw transforms, and
compares every fill, outline, color and path command; the unknown preset must
draw as a rectangle with the upstream warning. A second synthetic deck covers
custom geometry (`a:custGeom`): guides and adjust values, line, quadratic,
cubic and arc paths, multiple sub-paths, fill modes, per-path strokes, an
`a:rect` text rectangle and a themed `p:style` fill/line reference. Upstream
keeps `arcTo` as a Canvas ellipse verb, so the comparison flattens both
encodings to cubic Béziers; the malformed-geometry fallback is covered by the
MoonBit tests.

To regenerate the other fixtures, overlay `generate_placeholders_test.go` in
`converter/pptx` or `generate_transforms_test.go` in
`converter/internal/ooxml/drawingml`, set `BDF_REFERENCE_OUTPUT`, and run the
corresponding `TestCodexPPTXPlaceholders` or `TestCodexPPTXTransforms` with
`-count=1`. Strip the build tag from each overlay. Run `moon fmt convert/pptx`
afterward; JavaScript and wasm-gc execute the same expectations.

## Limited converter

`convert/pptx` exposes `detect` and `convert` for PresentationML. The
generated document has one fixed `slides` view; every visible slide becomes a
page of the presentation size, with layers in upstream order:

- a `background` layer drawn once per background source (a slide, layout or
  master `p:bg`, falling back to the color scheme's `bg1`);
- up to two `master` layers: the slide layout's non-placeholder shapes and the
  slide master's non-placeholder shapes, each stored once and reused by every
  slide that uses it (empty layers are omitted, as upstream does);
- a `body` layer for the slide's own shapes.

Text follows the placeholder chain by index, then by type: a slide placeholder
takes its transform and text properties from the layout placeholder and then
the master placeholder. Paragraph and run properties are resolved through the
paragraph's `pPr`, the shape's `lstStyle`, the layout/master placeholder list
styles and paragraph defaults, and the master's `titleStyle`/`bodyStyle`/
`otherStyle` (or the presentation's `defaultTextStyle` for ordinary shapes).
This covers font family/size/bold/italic/color, bullets (`buChar` and
`buAutoNum` numbering, including `buClr` colours and `buSzPct`/`buSzPts`
sizes) with indentation levels, paragraph and line spacing,
text-box insets, vertical anchors and alignment. Text is wrapped at word and
CJK boundaries with paragraph/line/wrap marks, so the text index reproduces the
upstream reading order; vertical text is rotated.

Other supported DrawingML: solid, image and linear-gradient backgrounds with
theme colors (`bg1`, `tx1`, accents and luminance/tint/shade modifiers),
major/minor theme fonts, the DrawingML preset geometries (the complete upstream
preset table: triangles, diamonds, pentagons, stars, arrows, callouts, flowchart
shapes, braces, scrolls and the rest), filled and outlined per path with the
`lighten`/`darken` path fill modes. Arc segments are evaluated with the upstream
guide formulas and flattened to cubic Béziers, so they draw the same outline in
every renderer. Unknown presets fall back to a rectangle with the upstream
warning. Custom geometry (`a:custGeom`) evaluates its `avLst`/`gdLst` guides,
`a:rect` text rectangle and every `a:path` of the `a:pathLst`: `moveTo`,
`lnTo`, `quadBezTo`, `cubicBezTo`, `arcTo` (with `wR`/`hR`/`stAng`/`swAng`
guide tokens) and `close`, along with each path's own `w`/`h` coordinate
space, `fill`/`stroke` attributes and multiple sub-paths. Custom paths use
the same fill, outline, text-rectangle and group-transform pipeline as presets,
including theme fills and line styles. Malformed custom geometry (a missing or
empty `a:pathLst`, an unknown path command or a wrong point count) falls back
to the rectangle with a precise warning. Shape fill and outline resolve through
the shape's `spPr`, its layout
and master placeholders (including an explicit `noFill`), and then its
`p:style` `fillRef`/`lnRef` theme entries with `phClr` substitution. Shape
rotation/flips, translated and rotated groups, embedded pictures with alpha,
source-rectangle cropping, rotation and flips, and EMF/WMF metafiles are drawn.
Tables render cell text with wrapped lines, cell fills, text
colors/sizes/bold/italic/alignment, vertical anchors, margins, per-side borders,
grid widths/spans, row heights/spans and vertical merges. Bar (clustered and
stacked, horizontal and vertical, with `gapWidth`/`overlap`), line, area,
scatter, radar, pie and doughnut charts (with `firstSliceAng`, per-point `explosion` and
data-point fills, series line widths, dash patterns and markers) draw their series, axis titles with `txPr` sizes/colours,
bar/line/radar/scatter value labels with optional category/series names
and bar/line/scatter/radar `dLblPos` placement, point colours from
`c:varyColors`,
stacked segment labels and pie/doughnut combined value+percentage labels (`numFmt` decimals) with
`dLblPos` (leader lines for
outside labels, with optional
category/series names, `c:numFmt`, `c:txPr` sizes/colours/bold/italic, `c:separator` and per-point `c:dLbl`
text/delete)
from `dLbls`, legends with colour swatches and `txPr` text styles, deleted entries and
overlay mode, category labels and value-axis ticks with `txPr` text
styles, explicit `c:majorUnit`/`c:minorUnit`, `c:scaling/c:min`/`c:max` (automatically extending below zero for negative
values), reversed category axes (`c:orientation=maxMin`), negative bars and mixed-sign stacks drawn from a visible zero line, value-axis
`c:numFmt`, chart/plot-area `c:spPr` fills and borders, major/minor gridlines, and
sparse point caches keep their `idx` positions, blank points draw no bars or
scatter/radar markers,
and line/area gaps honour `dispBlanksAs=gap|span|zero`. Office
Math in `a14:m` is linearized to text (fractions, roots, scripts, n-ary
operators, delimiters, matrices, accents and groups); the `mc:Choice` that
holds math is preferred over its `mc:Fallback` picture.

Fonts are host supplied, like the other converters: `convert` takes an optional
`@fontdb.Database` (the contents of a PowerPoint font directory) and measures
every run with the resolved face's advances and vertical metrics, falling back
per glyph the way upstream `fontset` does. The faces used are subset and
embedded as WOFF2 parts; the summary reports the embedded font count and a
character no available font has is reported in the upstream warning. With no
database the converter keeps upstream's estimated metrics, writes no font parts,
and reports the `no fonts found` warning. A host that receives a font directory
URL (the native converter worker's `fonts` option) must pass the resulting
database to `convert(db=...)`.

Line `a:headEnd`/`a:tailEnd` arrowheads are drawn for triangle, stealth,
diamond, oval and open-arrow ends with the upstream width/length sizes; the
oval end is an eight-sided approximation. Shape `flipH`/`flipV` mirroring is
applied through the DrawingML transform.

Remaining gaps: upstream keeps `arcTo` as a Canvas ellipse verb while this
converter flattens it to cubic Béziers (the same outline, and the phase 15
comparison flattens both encodings before comparing); malformed custom
geometry falls back to the shape rectangle where upstream silently draws
nothing; SmartArt is reduced to its data-model text (the diagram layout is not
drawn), and ink, 3-D or other non-bar/line/pie/doughnut/area/scatter/radar charts are not
supported; chart titles use an explicit `c:title` (with its `txPr` size/colour and
`overlay`) or the single-series name unless `autoTitleDeleted` is set,
and bar/line/pie/radar/scatter charts with `c:dTable` draw a category/series/value table with series names,
honouring the show and border flags; the built-in
The 74 predefined table-style IDs resolve their whole-table, header, band and
last-row/edge-column fills, their header/body text colours and their family
borders (with dash styles), cell diagonals, gradient fills and explicit
noFill (the grid/rule sides are approximated per family);
`normAutofit` font scale and
line-spacing reduction are applied, while advanced vertical
glyph stacking is not implemented; chart label
text keeps the estimated advance even when fonts are supplied, and the subsets
are always embedded as WOFF2 without the `no_subset`/`no_woff2` options.
