# DOCX run-property fixtures

`generate_run_props_test.go` compares the private run-property model with
upstream `wordproc.defaultRProps` and `applyRPr`. Its synthetic and upstream
DOCX-derived property layers cover toggles and their specified masks, fonts and
theme-font references, sizes, spacing, scaling, language, vertical alignment,
underline, emphasis, and vertical text settings.

To regenerate, copy the Go file without its build tag into upstream's
`converter/internal/wordproc`, set `BDF_REFERENCE_OUTPUT` to
`convert/docx/run_props_generated_wbtest.mbt` and `BDF_DOCX_FIXTURES` to
upstream's `converter/docx/testdata`, then run `TestCodexDOCXRunProps`. Run
the resulting MoonBit tests on JavaScript and wasm-gc.

The standalone parser rejects colors, shading, underline colors, style
references, two-lines-in-one layout and other unsupported properties. The
style resolver handles style references, and the document-text reader retains
supported resolved properties. Numbering, settings, case conversion, hidden
text and vertical combined text remain unsupported. No BDF output is produced.
