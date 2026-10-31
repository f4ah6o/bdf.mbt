# DOCX paragraph-property fixtures

`generate_paragraph_props_test.go` compares the internal paragraph-property
parser against upstream `wordproc.defaultPProps` and `applyPPr`. It exercises
layered paragraph properties, tab stops, indentation, spacing, numbering,
booleans, and properties found in the upstream sample DOCX documents.

To regenerate, copy the Go source without its build tag into the upstream
`converter/internal/wordproc` package, set `BDF_DOCX_FIXTURES` to upstream's
`converter/docx/testdata` directory and `BDF_REFERENCE_OUTPUT` to
`convert/docx/paragraph_props_generated_wbtest.mbt`, then run
`TestCodexDOCXParagraphProps`. The generated tests run on JavaScript and
wasm-gc.

The parser is internal and does not implement DOCX conversion or style
resolution. Paragraph borders and shading require theme-color handling and
are rejected rather than silently omitted.
