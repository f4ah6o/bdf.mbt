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

`convert/docx` exposes `detect` and `convert` for WordprocessingML.
`convert(data, title?="", views?="both")` selects the views with `views`:
`both` (the default), `pages` or `scroll`; any other value is rejected.

- `pages` (`flow`) with `header`, `footer` and `body` layers and the body
  rectangle of each page. Header/footer paragraphs are laid out at the section
  distances, with text, tabs, images and page fields; the default, first-page
  and even-page stories follow `titlePg` and `settings.xml`'s
  `evenAndOddHeaders`, and header/footer references carry over to sections
  that name none of their own. A header or footer taller than its margin
  pushes the body area in unless the margin is exact.
- `scroll` with page-free body text cut into strips between lines; the
  strips include the scroll margin and real table cells.

Both views carry layer-aware text indexes numbered by text layer (header,
footer, body, skipping absent stories). Dublin Core metadata (title, creator,
subject, description, identifier, language, created, modified) is read from
the OPC core properties and the title can be overridden by the caller.

The reader accepts `settings.xml`, `footnotes.xml` and `endnotes.xml`;
footnote and endnote bodies are laid out above the footer on the page that
refers to them and appended to the scroll view, with approximate superscript
markers. References inside table cells are collected onto the page as well. External `w:hyperlink` relationships become link commands and internal
`w:anchor` links point at the bookmark page; it also reads fields, symbols,
tracked
insertions/deletions, content controls, alternate content and revision
metadata. Office Math (`m:oMath`/`m:oMathPara`) is linearized for search and
layout. Paragraphs are laid out with approximate character widths and support
word wrapping at spaces, explicit line/page/column breaks, tabs and leaders,
paragraph and character spacing, run position, alignment, keep-with-next, basic font
weight/style/size/colour, shading, borders, underline/strike, caps/small caps,
super/subscript,
emphasis marks, hidden text, theme fonts, decimal/bullet numbering and section
page geometry. `w:pgBorders` rules are drawn on a page's background layer,
honouring `offsetFrom` and the first/not-first display filters. Tables are real tables: a `tblGrid` (or equal columns when it
is missing), grid spans, vertical merges with row spans, cell margins,
borders and fills from cells and `tblBorders`, vertical alignment, row
heights (`trHeight`, `cantSplit`, `tblHeader`), rows split between lines
across columns and pages, and header rows repeated on every page a table
reaches. Cell text wraps at the cell width; nested tables are laid out inside
their cell. Table rows are no longer flattened to tab-separated paragraphs.

Sections flow through `w:cols` columns (equal and unequal widths, column
breaks, continuous sections, separator rules and odd/even-page starts with a
blank page when the parity asks for one). Sections with `w:textDirection` vertical
text turn their page body by 90 degrees with upstream's matrix
`(0,1,-1,0,page width-right margin,top margin)`; headers and footers stay
upright and the scroll view is horizontal. `PAGE`, `NUMPAGES` and
`SECTIONPAGES` fields regenerate their result per page (the layout is run
twice so `NUMPAGES` knows the page count and `PAGEREF` knows bookmark pages)
instead of using the cached value; `REF` uses the bookmark text;
`PAGE` honours `pgNumType` `start` and `fmt` (decimal, roman, letters,
full-width and enclosed digits). Numbering instances honour
`lvlOverride`/`startOverride`. Inline drawings with an embedded
PNG/JPEG/EMF/WMF part are placed at their `wp:extent`; text-box content is
flattened; `a:srcRect` crops and `a:xfrm` rotation/flips are honoured.
Anchored drawings (`wp:anchor`) float: their position is resolved against the
page, the margins, the column or the paragraph (including `wp:simplePos`),
and their wrap keeps the text out of their area. Square, tight and through
wrapping shorten the lines beside a left or right object as `wrapText` asks
(`bothSides`, `left`, `right`, `largest`; tight and through use the
object's box rather than its contour), top-and-bottom wrapping pushes the
lines below the object, and the `distT/distB/distL/distR` distances are
honoured. A paragraph whose paragraph-relative object does not fit below the
text of the page moves to the next page with it. Objects with `behindDoc`
are drawn before the text of the page, the others after it in
`relativeHeight` order, all in the body layer. The converter
reaches the upstream page counts for the five `converter/docx/testdata`
fixtures (basic 3, styles 1, grid 4, vertical 2, math 1) and repeats the grid
table's header row on pages 2-4.

The package's `layout_wbtest.mbt` builds small DOCX packages as stored ZIP
archives so each test shows its WordprocessingML: cell wrapping and grid
spans, vertical merges, repeated header rows, columns, vertical pages,
regenerated page fields, header images, numbering overrides, floating
drawings with left/right/top-and-bottom wrapping and behind/in-front order,
the `views` selection and inline-drawing regression. Floating drawings inside
table cells and headers/footers are drawn at their anchor (without wrap).

Documented gaps: exact font metrics and OpenType shaping, tight/through wrap
contours (the object's box is used), painting the shadows that
`wp:effectExtent` reserves room for (the reserved space is kept),
floating drawings in vertical text (they are drawn turned with the flow and
keep no space), page-relative objects that would not fit are drawn
clipped rather than moved, exact footnote separator/continuation
indentation, upright CJK glyphs in vertical text (the whole body is turned,
Latin and CJK alike),
per-section `SECTIONPAGES` (the document page count is used),
table-style base, first/last row/column, banded and corner-cell parts
(borders/shading/margins/text formatting and TableGrid are applied), exact
scroll strip counts (the approximate metrics make the basic fixture 1 strip
where upstream makes 2; the other fixtures match). The native converter Worker
advertises the `docx` format.
