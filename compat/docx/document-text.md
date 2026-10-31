# DOCX paragraph-text fixtures

`generate_document_text_test.go` compares the internal document reader with
upstream `wordproc.walker` on minimal DOCX packages. The fixtures cover Unicode
and XML text, nested content wrappers, tabs, line and page breaks, direct
paragraph properties and section inheritance, along with text extracted from
upstream sample DOCX files. The Go reference uses system font names with
system font lookup disabled; only item kinds, content and
selected paragraph and section properties are compared.

To regenerate, copy the Go file without its build tag into upstream's
`converter/internal/wordproc`, set `BDF_REFERENCE_OUTPUT` to
`convert/docx/document_text_generated_wbtest.mbt`, set `BDF_DOCX_FIXTURES` to
upstream's `converter/docx/testdata`, and run
`TestCodexDOCXDocumentText`. Run the resulting tests on both JavaScript and
wasm-gc.

The reader is private and intentionally narrow. Styles, run formatting,
numbering, fields, tables, drawings, headers, footers, notes and many other
parts are rejected until their semantics are implemented. It is an input
model, not a DOCX-to-BDF converter or a layout engine.
