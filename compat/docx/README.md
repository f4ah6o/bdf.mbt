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

This generated section suite covers basic section geometry for direct body
paragraphs. The converter below is exercised separately by the DOCX unit
tests and the native Worker.

## Converter

`convert/docx` exposes `detect` and `convert` for WordprocessingML. It emits
the same pair of views as upstream:

- `pages` (`flow`) with `header`, `footer` and `body` layers and the body
  rectangle of each page. Header/footer text is laid out at the section
  distances; default, first-page and even-page stories are selected.
- `scroll` with page-free body text cut into strips.

Both views carry layer-aware text indexes. Dublin Core metadata (title,
creator, subject, description, identifier, language, created, modified) is
read from the OPC core properties and the title can be overridden by the
caller.

The reader accepts `settings.xml`, `footnotes.xml` and `endnotes.xml` (their
bodies are not laid out yet), hyperlinks, simple fields, symbols, tracked
insertions/deletions, content controls, alternate content and revision
metadata. Office Math (`m:oMath`/`m:oMathPara`) is linearized for search and
layout. Paragraphs are laid out with approximate character widths and support
explicit line/page/column breaks, tabs and leaders, paragraph spacing,
alignment, keep-with-next, basic font weight/style/size/colour, shading,
borders, caps/small caps, super/subscript, emphasis marks, hidden text, theme
fonts, decimal/bullet numbering and section page geometry. Table rows are
flattened to tab-separated paragraphs with cell shading, grid spans, borders,
paragraph shading/borders and `tblGrid` tab stops. Inline drawings with an
embedded PNG/JPEG/EMF/WMF part are placed at their `wp:extent`; text-box
content is flattened; `a:srcRect` crops and `a:xfrm` rotation/flips are
honoured; anchored drawings use page-relative `wp:posOffset` coordinates.

Documented gaps: exact font metrics and OpenType shaping, real table cells and
floating text wrapping, columns, vertical section layout, footnote and endnote
bodies, field result regeneration (cached `PAGE`/`NUMPAGES` values are used),
header images, numbering overrides, and page counts that depend on those
features. The native converter Worker advertises the `docx` format.
