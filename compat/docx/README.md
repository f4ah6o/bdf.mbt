# DOCX compatibility fixtures

These fixtures compare basic page size and margin attributes in direct body
and paragraph sections with upstream `wordproc.parseSection`. They cover eight
upstream `converter/docx/testdata` documents and a generated document with a
custom main part, inherited page size, negative margins, duplicate properties,
gutter and strict measure units. To regenerate, copy `generate_sections_test.go`
without its build tag into upstream `converter/internal/wordproc`, set
`BDF_DOCX_FIXTURES` to the DOCX testdata directory and `BDF_REFERENCE_OUTPUT`
to the generated MoonBit test file, and run `TestCodexDOCXSections`. Run
`moon fmt convert/docx` afterward. Both JavaScript and wasm-gc execute the
same expectations.

This internal reader covers basic section geometry for direct body paragraphs;
other section features, document content, and conversion are still to be added.

## Limited converter

`convert/docx` exposes `detect` and `convert` for a text-only subset of
WordprocessingML. It lays out paragraphs with approximate character widths and
supports explicit line/page breaks, tabs, paragraph spacing, alignment, basic
font weight/style/size and the section page geometry. Table rows are flattened to tab-separated paragraphs with tab stops from
`tblGrid`. Inline drawings with an embedded PNG/JPEG part are placed at their
`wp:extent`; numbered paragraphs receive decimal or bullet prefixes from
`numbering.xml` (level counters and left indents). Floating drawings, EMF/WMF
images, numbering overrides, first/even header variants, header images and
fields are rejected by the reader or omitted. Default header and footer
paragraph text is drawn at the section header/footer distances. The native
converter Worker advertises the `docx` format.

