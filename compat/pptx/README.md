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

`convert/pptx` exposes `detect` and `convert` for a shape/text subset of
PresentationML. It renders visible slides, solid slide backgrounds, embedded pictures, rectangle, rounded-rectangle and ellipse fill/stroke, theme colour schemes with luminance/tint/shade modifiers, theme major/minor
fonts, paragraph default run properties, placeholder transform and default run-format inheritance, table text
flattening, layout/master backgrounds and non-placeholder decorations, translated
group shapes, solid shape fills and paragraph/run text with approximate
metrics. Charts and group rotation/scaling are not rendered yet; layout/master placeholder shapes are skipped after their
transforms are used for inheritance. The native
converter Worker advertises the `pptx` format.
