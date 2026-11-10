# Changes

## Unreleased

### Added

- DocuWorks (`.xdw`) documents now carry a text index, so body text and
  annotation text are searchable in the converted BDF.
- `include_hidden` keeps text that a later opaque fill covers; the default
  leaves covered text out. It is reachable as `xdw_convert(include_hidden=)`,
  as `convert(..., params={"include_hidden": "1"})`, and through the browser
  worker's existing `request.options.params.include_hidden`. There is no CLI
  flag for it yet.
- Word (`.docx`) conversions accept a `pages` selection such as `1-3,5,8-`
  and keep only those pages of the page view, in document order; the scroll
  view still holds the whole document. It is reachable as
  `docx_convert(pages=)`, as `form/docx.fill(pages=)`, and through the browser
  worker's existing `request.options.pages`. The page count, summary and text
  index describe the selected pages, and a link to a page left out is dropped.
  An invalid selection is an error, as upstream's `ParsePages` makes it.
- `form` is the entry point of template filling, as upstream's `form`
  package. `compile` checks a template and makes a `.bdft` that holds it with
  the names its tags look up, the JSON Schema of its data and an optional
  sample; `fill` fills a template or a compiled template; `fields`,
  `describe` and `schema_of` read a template without filling it. The formats
  are xlsx, docx, pptx, pdf, pdfme and text.
- A fill that leaves names of the data open (`Options::open`, `OPEN_ALL`)
  makes a partly filled form (`.bdff`) of the values it holds, which another
  fill completes into the document that the template filled with all of the
  data at once. The description of a compiled template is the `tpl` part of
  upstream (version 1, the `source`/`from`/`digest` hashes, `filled`, `open`
  and `signed`), and `read_template` checks its version, its hashes and the
  256 MiB template and 64 MiB description limits.
- `form/xlsx`, `form/docx`, `form/pptx`, `form/pdf`, `form/pdfme` and
  `form/textform` read the fields of a template without filling it
  (`inspect`), with the location of each tag: the cell of a workbook, the
  part of an OOXML document, the line and column of a text template.
- `form/schema` gains `names`, `schema_open` and `has_name`: the names of the
  data of a template, and the schema of the names that a fill leaves open.
- `form/tag` fields carry the locations of their tags (`at`) and convert to
  and from the JSON of upstream's `Field`.
- `core` gains `sha256_hex` and `hash_of` for the hashes that a compiled
  template names its parts by.
- A fill without `strict` tells the names that the data has not, in every
  format: `the data has no "name"; it is left empty` for a tag of an OOXML
  document and for a field of a pdfme template. `form/xlsx` and `form/pptx`
  now keep the warnings of the fill instead of dropping them.
- `form/pdf` reads a field name as the parts of an object (`applicant.name`)
  when the data has no value under the whole name, as upstream does.
- A field of several variables of a pdfme template is filled by the values of
  its variables when the data has no object under the name of the field.
- `form/textform.show_result` shows a text template as it is, with its tags,
  on the pages of its paper, as upstream's `Show` does.

### Changed

- `form/tag.Field.kind` is mutable, so that a field that several tags name
  merges into one.

### Fixed

- A section of an OOXML template repeats the rows, paragraphs or table rows
  it covers instead of the raw XML between its tags, so a list that spans
  rows of a workbook or a table of a document fills to one row per item
  instead of a sheet with duplicate row numbers or a table with broken rows.
  A section that opens and closes in one cell or paragraph fills in place. A
  block that holds only control tags is dropped, and the rows of a filled
  worksheet are numbered again in the order of the document.
- A worksheet that no section repeats keeps its rows and cell references as
  they are, and a worksheet that a section repeats keeps the gaps of its
  rows: a template with rows 1 and 10 still has rows 1 and 10, and a row
  after a repeated row moves by the number of rows the section added. The
  merged cells and the dimension move with the rows; a formula, a hyperlink,
  a data validation, a conditional format, an auto filter or a table part
  that the fill cannot move is an error instead of a wrong cell.
- The references outside a worksheet that a section repeats are moved with
  its rows or refused before conversion: a defined name and a row break move
  with the row they name, a merge that covers a dropped row is an error, and
  a drawing, a chart, a pivot table or a formula of another sheet that names
  a sheet whose rows move is an error instead of a stale reference. A
  self-closing `<f/>` counts as a formula. A comment, a VML drawing, a
  slicer, a sparkline, an external link or a drawing that anchors to a sheet
  whose rows move is an error too. A row or a cell written across lines, with
  spaces around `=` or with single quotes is renumbered like any other,
  without a duplicate attribute. A `>` inside a quoted attribute value does
  not end the tag, and a namespaced `<x:row>`/`<x:c>` is renumbered like an
  unprefixed one. A `<sheet>` or `<Relationship>` written across lines, with
  tabs or with single quotes is read like any other, so the guards that need
  the sheet name still run; a worksheet whose rows move but whose name cannot
  be resolved from the workbook and its relationships is an error instead of
  a skipped guard. A calculation chain, a form control, a rich value or a web
  extension in a workbook whose rows move is an error too. A prefixed
  reference element that the fill does not move (`<x:mergeCell>`,
  `<x:dimension>`, `<x:rowBreaks>`, `<x:brk>`, `<x:hyperlink>`,
  `<x:dataValidation>`, `<x:conditionalFormatting>`, `<x:autoFilter>`,
  `<x:tablePart>`, `<x:drawing>`, `<x:legacyDrawing>`, `<x:sheet>`,
  `<x:definedName>` or `<x:Relationship>`) is an error when a section repeats
  rows, instead of a stale reference. So is an `<oleObject>`, `<control>`,
  `<sortState>`, `<protectedRange>`, `<ignoredError>`, `<cellWatch>` or
  `<customSheetView>` element, prefixed or not, and an opaque part whose
  references the fill cannot read (`xl/metadata.xml`, `xl/model/`,
  `customXml/`, `vbaProject.bin`). Macros are never executed, so a workbook
  with a macro project is refused rather than filled with references the fill
  cannot check. A sheet whose rows do not move keeps every reference
  untouched. An extension type outside this list may still need support
  before a row-expanding workbook that uses it can be filled.
- The options of a tag are applied by the fill of an OOXML document:
  `{{total | fmt:"#,##0.00"}}` writes the number in its format instead of
  warning that the data has no `total | fmt:"#,##0.00"` and leaving the cell
  empty. `fmt:` uses the XLSX number formats, as upstream's `Formatter` does.
- A list of an OOXML template fills `_index`, `_count`, `_first`, `_last`
  and, for a section of pages, `_page` and `_pages`; a list of values fills
  `{{.}}`; and a comment tag `{{! ... }}` leaves nothing instead of warning
  that the control tag is not supported.
- A text template whose UTF-8 character is cut by the 1024-byte or the
  `MAX_TEXT_HEAD` sample that detection reads is still read as a text
  template, instead of being refused as a file that is not one. Bytes that
  are not UTF-8 at all, and NUL bytes, are still refused, and the detection
  of ZIP and PDF templates is unchanged.
- `form.compile` without sample data shows the template with its tags instead
  of filling it with an empty object, which replaced every tag with nothing.
  A template of pdfme keeps what its designer left in its fields as its
  sample, and that sample is not checked strictly, as upstream does.
- `form.fill` reports the fields of the template it filled (`Result.fields`)
  instead of an empty list.
- `form/pdfme.inspect` leaves out the shapes of a template (`line`,
  `rectangle` and the other types that nothing fills) instead of reporting
  them as text fields, keeps the options of a `select`, and reads a
  `circleMark` as a boolean.
- `Options.strict` is honored by every format, not only by text: a name that
  the data does not have is an error in xlsx, docx, pptx, pdf and pdfme, as
  upstream's `Strict` makes it. A name inside a branch that is not taken is
  not asked for, a name of a list is asked for in each item, `null` is a
  value (an empty one), and the name of a condition is asked for before the
  branch is chosen. A fill that leaves names open turns strict off, as
  upstream does.
- EMF text with a Shift_JIS font charset now preserves Japanese characters,
  including searchable body text in DocuWorks documents.

- Covered text is left out of the DocuWorks index only when a fill provably
  hides it. A fill clipped away from the run, a translucent fill, a gradient or
  pattern fill, and an image no longer count as covers.
- DocuWorks index runs keep the ordinal the viewer draws them with, so a search
  hit lands on the right character after an earlier run is left out.
- DocuWorks index runs keep the separator the viewer computes, so phrases that
  span a line break stay searchable.
- `form/pdf` reads the type of a field (`/FT`) from the whole object that
  holds its name, so a PDF whose writer puts `/FT` before `/T` (as most do)
  gets the right field types instead of the type of the next field.

### Deprecated

### Removed

### Security

### Migration

- A section of an OOXML template that spans cells, paragraphs or rows
  repeats the blocks it covers, and a block that holds only control tags is
  dropped. A template that relied on the raw span between the tags, which
  produced malformed XML, now fills to a valid document. A section that
  opens and closes in one cell or paragraph still fills in place. A sheet
  that a section repeats is renumbered, and a formula or a reference that
  the fill cannot move is an error. A section that starts in a table row and
  ends outside it is an error, a section of `| slots` is an error (write
  `| rows`), and a picture tag (`{{%name}}`) is reported and left empty.

- `form/pdf.read_fields` now reports the type of a field whose writer puts
  `/FT` before `/T`. A caller that treated an empty type as a text field sees
  `/Tx` instead.
- A partly filled form (`.bdff`) is completed with `form.fill`; `form.compile`
  refuses it, as it refuses a compiled template (`.bdft`).
- A text template that is not UTF-8 is an error (`text: the template is not
  text of UTF-8`) instead of being filled with replacement characters.
- `form.fill` reads the fields of the template before it fills it, so a PDF
  without form fields is an error even without `Options::open`, as upstream's
  `ErrNoForm` makes it.
- `form/xlsx.fill`, `form/docx.fill`, `form/pptx.fill`, `form/pdf.fill_pdf`
  and `form/pdfme.fill` take `strict?`, and `form.fill` passes
  `Options.strict` to all of them. A fill of an OOXML document or of a pdfme
  template without `strict` now reports a warning for each name that the data
  has not, and `form/xlsx` and `form/pptx` return those warnings instead of
  an empty list.
