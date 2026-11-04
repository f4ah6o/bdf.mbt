# PPTX compatibility fixtures

The fixtures compare presentation discovery, slide order and visibility, layout
and master relationships, color mappings, placeholders, and shape transforms
with the upstream Go converter. They use six upstream presentations and a
synthetic package covering strict namespaces, missing relationships, universal
measures, duplicate elements, and markup-compatibility alternatives.

To regenerate `presentation_generated_wbtest.mbt`, overlay
`generate_manifest_test.go` without its build tag in upstream `converter/pptx`
and `drawingml_transform_export.go` without its build tag in upstream
`converter/internal/ooxml/drawingml`. Set `BDF_PPTX_FIXTURES` to the upstream
PPTX testdata directory and `BDF_REFERENCE_OUTPUT` to the output file, then run
`TestCodexPPTXManifest` with `-count=1`.

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
`buAutoNum` numbering) with indentation levels, paragraph and line spacing,
text-box insets, vertical anchors and alignment. Text is wrapped at word and
CJK boundaries with paragraph/line/wrap marks, so the text index reproduces the
upstream reading order; vertical text is rotated.

Other supported DrawingML: solid, image and linear-gradient backgrounds with
theme colors (`bg1`, `tx1`, accents and luminance/tint/shade modifiers),
major/minor theme fonts, rectangles, rounded rectangles and ellipses with solid
or gradient fill, solid-fill alpha and stroke, shape rotation/flips, translated
and rotated groups, embedded pictures with alpha, source-rectangle cropping,
rotation and flips, and EMF/WMF metafiles. Tables render cell text with wrapped
lines, cell fills, text colors/sizes/bold/italic/alignment, vertical anchors,
margins, per-side borders, grid widths/spans, row heights/spans and vertical
merges. Bar (clustered and stacked, horizontal and vertical), line and pie
charts draw their series, legend, category labels, value-axis ticks and pie
percentage labels. Office Math in `a14:m` is linearized to text (fractions,
roots, scripts, n-ary operators, delimiters, matrices, accents and groups); the
`mc:Choice` that holds math is preferred over its `mc:Fallback` picture.

Remaining gaps: only the `rect`, `roundRect` and `ellipse` preset geometries
are drawn (other presets use the rectangle path); SmartArt, ink and 3-D or
non-bar/line/pie charts are not supported; chart titles are used only for
single-series charts without an explicit `c:title`, and chart data tables are
not emitted; table style banding is not applied (only explicit cell properties);
font subsets are not embedded, so text is laid out with approximate metrics and
no font parts are written; autofit scaling, blip bullets, advanced vertical
glyph stacking and placeholder fill/line inheritance are not implemented.
