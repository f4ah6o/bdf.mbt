# DOCX paragraph-text fixtures

`generate_document_text_test.go` compares the internal document reader with
upstream `wordproc.walker` on minimal DOCX packages. The fixtures cover Unicode
and XML text, nested content wrappers, tabs, line and page breaks, direct and
inherited paragraph and run properties, and section inheritance. Additional
fixtures use text extracted from upstream sample DOCX files. The reference
uses system font names with system font lookup disabled. Styled fixtures
compare paragraph-mark and individual item properties as well as text.

To regenerate, copy the Go file without its build tag into upstream's
`converter/internal/wordproc`, set `BDF_REFERENCE_OUTPUT` to
`convert/docx/document_text_generated_wbtest.mbt`, set `BDF_DOCX_FIXTURES` to
upstream's `converter/docx/testdata`, and run `TestCodexDOCXDocumentText`.
Run the resulting tests on both JavaScript and wasm-gc.

The reader is private and intentionally narrow. It retains supported styles
and run properties but rejects unsupported colors and shading, case conversion,
hidden and combined vertical text, numbering, settings, fields, tables,
drawings, headers, footers, notes and other unimplemented features. It is an
input model, not a DOCX-to-BDF converter or a layout engine.
