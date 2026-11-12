# Changes

## Unreleased

### Added

- A sheet clipboard extension to the rendering Worker client
  (`bdf_render_worker_client`): `sheetClipboard(view, range)` copies an
  inclusive rectangular cell range `{ row0, col0, row1, col1 }` as
  `{ text, html }` (TSV and an HTML table) with hidden rows and columns
  skipped, merged cells clipped by `cell_clipboard`, and scope marks
  preserved as `th` cells. Because a merged cell keeps its text in the
  tile of its anchor while its span can cross any number of tiles, the
  worker resolves a range against every tile of the view's tile table,
  like the in-browser sheet, instead of a window around the selection;
  tiles sharing one object part are extracted once per request and split
  parts are fetched lazily through the document's part cache. Selections
  beyond 1,000,000 cells, views whose tile table exceeds 4,096 tiles (an
  explicit error instead of silently losing merged anchors), ranges
  outside the sheet and results whose serialized text and HTML together
  exceed 8,388,608 UTF-16 code units (a `String.length()` count of the
  finished serialization, not a byte or allocation cap) are rejected as
  worker errors. `compat/render_worker/clipboard-test.mjs` covers the request
  contract for short spans, offscreen data, invalid ranges, hidden axes
  and split sources; the new
  `compat/render_worker/merge-clipboard-test.mjs` covers merged spans
  wider than one tile for buffer, split and password-encrypted sources
  against the generated `compat/sheet/merge.bdf` fixture; and the new
  `compat/render_worker/tile-cap-clipboard-test.mjs` covers the tile cap
  on a 4,097-tile sheet rejected before any tile object part is loaded
  (`npm run test:render-worker-clipboard` runs all three). The installed
  package smoke (`plugin/browser/library-smoke.mjs` through
  `npm run library:smoke`) additionally drives the tarball-installed
  client and render Worker so packaging omissions of the client method or
  the merged-cell fix fail the staging gates.
- Generic multiple-page and embedded raster-image document support in the
  shared diagram encoder (`bdf.mbt/plugin/diagram-bdf`):
  `encodeDiagramDocument({source, title, pages, images})` emits one obj
  part per page and one img part per unique embedded resource, with
  content-hash deduplication, per-part relative offsets, actual image
  hash tables (opset-1 image op), two-way reference integrity, positive
  drawn image rectangles, and caps on pages, primitives, resources, image
  bytes, raster dimensions and total volume. Embedded PNG and JPEG data
  is validated structurally and bounded (complete PNG chunk table with
  IHDR/IDAT/IEND; complete JPEG segment table with frame, scan
  entropy and EOI; truncation, trailing bytes and out-of-range lengths
  rejected; CRCs left to the decoder), never fetched from remote URLs,
  file paths, strings or other image formats. `encodeDiagram` keeps its
  single-page API, vector-only primitive union and byte-identical output;
  documented types ship in `types/diagram-bdf.d.ts` with a document-only
  primitive union that adds the image primitive; the independent-reader
  tests extend to multi-page documents
  (`plugin/test/diagram-document.test.mjs` with in-process synthetic
  genuinely decodable PNG/JPEG fixtures) plus a real-Chromium render
  smoke that decodes and draws both formats through the upstream
  `@bdfkit` renderer (`plugin/browser/diagram-render-smoke.mjs`,
  `npm run test:plugin:diagram`).
- A public PDF export API `bdf.mbt/pdf` (`exportPdf`) that writes BDF bytes
  as PDF bytes with the page count, the count of fonts used and the
  writer's warnings, in the browser and in Node: an explicit caller-provided
  fallback font with subset embedding for form text and Japanese, view
  selection, rejection of wrong types, broken BDF, unknown views and
  page-less selections, and never an empty PDF as a success. The writer now
  also warns about the characters the PDF standard font writes as `?` when
  no usable fallback font is supplied, instead of hiding the replacement.
  See the usage examples, the limits table and the warning contract in
  [plugin/library/README.md](plugin/library/README.md).

- Reproducible measurement, packing, packing-integrity and all-case
  equivalence tooling for the XLSX compat fixture store
  (`compat/xlsx/tools/`), with the 2026-11-12 baseline, storage-alternative
  comparison and migration evidence recorded in
  [docs/xlsx-fixture-storage.md](docs/xlsx-fixture-storage.md).

### Changed

- XLSX compatibility fixtures now store input XLSX and expected BDF bytes
  deduplicated in a content-addressed pack store (`compat/xlsx/store/`)
  behind a packed-fixture loader; case sets, bytes, options, warnings,
  verifier comparisons, sharding and the visual harness are unchanged
  (all-case equivalence against `e02e4e02` recorded in
  [docs/xlsx-fixture-storage.md](docs/xlsx-fixture-storage.md)), shrinking
  the `compat/xlsx` working tree from 714 MiB to 334 MiB. Fixture
  regeneration now ends with `pack-fixtures.mjs`; see the new fixture
  storage section in `compat/xlsx/README.md`.

### Fixed

- draw.io labels now honor directional spacing, including AWS group-label icon clearance,
  block-spacing suppression, rotated content bounds, and exhausted-width wrapping.

- DOCX character-unit indents now shape layout: a `w:ind` attribute of
  `leftChars`/`rightChars`/`firstLineChars`/`hangingChars`
  (hundredths of a character, `startChars`/`endChars` included) replaces
  the corresponding point attribute scaled by the paragraph mark's font
  size, the way upstream's `para.indents()` does — `hangingChars` pulls
  the first line back, and an explicit zero or absent attribute keeps the
  point (`w:left`/`w:right`/`w:firstLine`/`w:hanging`) value. First-line
  origins, tab origins, wrap edges and the flow's re-based line starts
  all use the scaled indents in the page and scroll layouts, and the
  keepNext look-ahead sizes the next paragraph the same way;
  documents without character-unit attributes lay out exactly as before.

- PPTX connectors (`p:cxnSp`) are drawn: the slide tree admits them like
  `p:sp` shapes with their transforms, line styles, dashes and arrowheads,
  their placeholders are read through `p:nvCxnSpPr` the way upstream's
  `PlaceholderOf` does, and a connector box with a zero width or height
  (a straight connector between aligned shapes) keeps its shape instead
  of being skipped; upstream `drawSp` has no size guard. A connector
  without a transform stays out, matching upstream. A shape whose
  `p:cNvPr` carries `hidden="1"` — connectors included — is no longer
  drawn, as upstream `drawElem` leaves it out. The relaxed zero-extent
  rule is bounded to connectors; pictures, tables and charts keep the
  port's existing sizing admission.

- Installation and release guides now point to the published `bdf.mbt@2026.11.1`
  and document the remaining staged bootstrap reservation.

### Deprecated

### Removed

### Security

### Migration

## 2026.11.1 - 2026-11-12

### Added

- Manual CalVer npm release preparation using `f4ah6o/calver-action` and
  Trusted Publishing. Default runs retain an artifact without publishing;
  local staging artifacts remain private. See [the release procedure](docs/npm-release.md)
  for publication evidence and validation requirements.

- A versioned file-format plugin API with explicit startup registration,
  deterministic detection, validated conversion results, stream leases and
  asynchronous cleanup. DocuWorks uses the same public adapter contract.
  See [the API guide](docs/format-plugin-api.md) for supported options and
  differences from the native converter Worker.
- Excalidraw and Mermaid flowchart adapters convert supported diagram
  primitives to BDF. Hand-drawn strokes and fonts are outside the Excalidraw
  adapter's scope; [the diagram guide](docs/diagram-plugins.md) lists the
  supported elements and syntax.
- The published `bdf.mbt` JavaScript package with viewer, forms, converter Workers,
  plugin exports, TypeScript declarations, consumer examples and third-party
  license notices. Version `2026.11.1` uses npm Trusted Publishing; default local
  staging artifacts remain `private: true`. Downstream
  adapters can be composed in a browser-resolvable Worker without modifying
  the public dispatch code.

- The viewer can ask for access to local fonts and use selected faces during
  conversion. The request begins only when the user selects the control; font
  data stays local, while the generated BDF or PDF may embed selected faces.
  The picker is optional and unavailable in browsers without Local Font Access.
- The native converter Worker accepts `options.fontFiles`, named font byte
  arrays, in addition to the existing `options.fonts` directory URL. Byte
  input is copied, validated and isolated per request. PDF and DOCX do not
  use the supplied database, and XLSX uses only its first face.

- `compat/parity/render-diff.mjs` compares fixed fixtures through upstream and
  MoonBit converters and renderers independently, recording environment and
  input hashes.

- `npm run verify:local` runs the self-test, lint, CI, demo, parity, visual and
  site gates through `actrun` in the current worktree and writes a manifest,
  logs and actrun run records under `_scratch/local-verify/`. Per-workflow
  shortcuts are `verify:local:self`, `verify:local:lint`, `verify:local:ci`,
  `verify:local:parity`, `verify:local:visual` and `verify:local:site`;
  `verify:local:plan` is a dry run.

- `npm run test:local-verify` runs the deterministic runner tests: status
  aggregation, empty and skipped steps, missing prerequisites, the
  retained-scope marker and the site server checks.

- `.github/local/moon-test.mjs` runs the retained packages using
  `compat/retained-test.mjs`; if the selector is missing, it reports
  `retained-scope: pending` rather than claiming retained coverage.

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

- `npm run test:retained` and `npm run test:retained:js` run the MoonBit tests
  of the retained packages only, per target. A bare `moon test` still collects
  the dormant packages.

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

- A fill without `strict` reports missing names for OOXML and pdfme: `the data has no "name"; it is left empty` for a tag of an OOXML
  document and for a field of a pdfme template. `form/xlsx` and `form/pptx`
  now keep the warnings of the fill instead of dropping them.

- `form/pdf` reads a field name as the parts of an object (`applicant.name`)
  when the data has no value under the whole name, as upstream does.

- A field of several variables of a pdfme template is filled by the values of
  its variables when the data has no object under the name of the field.

- `form/textform.show_result` shows a text template as it is, with its tags,
  on the pages of its paper, as upstream's `Show` does.

### Changed

- Required visual verification excludes musical-score and piano-roll suites;
  audio playback and excluded-format rejection checks remain required.

- The site marks upstream MHTML documentation as unsupported by bdf.mbt and
  identifies the excluded porting formats.

- DocuWorks annotations use a separate `annotation` layer, which renderers can
  show or hide. Stored annotation text is indexed even when its drawing has no
  text or is missing. The static index reflects visible annotations: hiding
  them can reveal body text excluded from search unless `include_hidden` is set.

- DOCX view titles use the document title when no title is supplied, and
  conversion summaries and font warnings follow the upstream wording.

- The converter Worker no longer registers or dispatches PCB/KiCad (Gerber,
  Excellon, `.kicad_pcb`), musical-score (MML, MIDI, MusicXML/MXL) or EPUB
  conversions. A request for one of those formats fails with
  `unknown format "<name>"`, and their filename extensions are no longer
  detected. Audio playback and non-PCB CAD (DXF, Jw_cad, SXF, CGM, HP-GL/2)
  are unchanged.

- The viewer no longer offers those formats in its file picker, sample
  shortcuts or gallery, and the site no longer publishes their format pages.

- The four verification workflows run locally through `actrun` and cannot be
  triggered on GitHub. Pages deployment remains available separately through
  the manual `.github/workflows/pages-deploy.yml`; local verification never
  dispatches it or publishes the site.

- `form/tag.Field.kind` is mutable, so that a field that several tags name
  merges into one.

### Fixed

- Metafile pen widths now follow the logical-to-page transform, correcting
  overly thick DocuWorks shape outlines: a geometric pen emits
  `width * matrix.scale()` page points, and a cosmetic pen emits a fixed
  0.75pt hairline instead of dividing by the scale. The hairline is a
  96dpi-inspired approximation of one pixel, not a guarantee of one output
  device pixel, and browser zoom scales it. An anisotropic matrix uses the
  geometric mean of its axes, which approximates GDI's elliptical pen. A
  positive geometric width below one page point is left unclamped.

- DocuWorks image annotations with kind 7 bitmap bands now retain their
  stored top-to-bottom row order. Ordinary page DIBs and RLE8 keep their
  existing orientation.
- DocuWorks DW03 and DW06 clips replace the previous clip, so images in
  subsequent disjoint regions remain visible. EMF `SELECTCLIPPATH` with
  `RGN_COPY` also replaces rather than intersects the previous region.

- DocuWorks kind 7 bitmap annotations with more than one band now decode every
  band and join them in order, instead of reading only the first. The band
  count, each band's stored and expanded sizes, and the joined output and
  stored copies are checked against the bytes that are really there and the
  picture caps, so a truncated or oversized body is refused rather than read
  past. The bitmap offset and band-header bounds use subtraction, so a crafted
  header cannot wrap a check and read out of bounds.

- DocuWorks body images compressed as BI_RLE8 now decode with their palette,
  bottom-up or top-down row orientation, encoded and absolute runs,
  end-of-line/end-of-bitmap and delta escapes, and absolute-run padding.
  Truncated records, out-of-range palette indices, runs or deltas outside the
  bitmap, end-of-line escapes past the last row, streams without an
  end-of-bitmap escape, and bitmaps above 64 Mi pixels (256 MiB of RGBA) are
  rejected instead of being read as uncompressed rows. DIB headers are
  validated before their palette offset is used: an undersized, oversized or
  wrapped biSize, and a biClrUsed above the 2^bpp table (256 for 8 bpp), are
  rejected. The pixel limit applies to uncompressed DIBs too, so a header that
  would previously overflow the RGBA size now fails explicitly; a 600 dpi A4
  scan (about 34.8 Mi pixels) stays below it. Unsupported bit depths are
  rejected before the stride calculation, so an untrusted biBitCount cannot
  overflow it.

- Files named for excluded formats no longer fall through to CSV detection,
  while the excluded converters remain unregistered.

- CSV visual checks now wait for each page to finish rendering before capture,
  while retaining the nonblank and exact pixel comparisons.

- CAD paths now retain the pen line cap, including round caps on Jw_cad paths.

- PDF streams whose `/Length` runs 1–8 bytes into the `endstream` marker are
  read up to that marker, preserving the reported content stream and binary
  payloads whose correct length does not overlap the marker.

- The converter Worker advertises the Office extensions upstream registers on
  the workbook, word-processing and presentation converters (`.xlsm`, `.xltx`,
  `.xltm`, `.docm`, `.dotx`, `.dotm`, `.pptm`, `.ppsx`, `.ppsm`, `.potx`,
  `.potm`), so a client's file picker offers them. A macro-enabled or template
  package is the same OPC package as its plain counterpart: macros are never
  executed and a VBA project is not carried into the BDF.

- A workbook is detected by its content like a document or a presentation, so
  a macro-enabled or template workbook converts under any name. A name with one
  of those extensions falls back to its converter when no detector claims the
  content, as upstream's `detectNamed` does, instead of failing as an
  unsupported image.

- JPEG 2000 sample conversion now uses float32 rounding and clamps extreme
  values before integer conversion, matching upstream for common precisions.

- DOCX formula warnings now include formulas in tables, headers and footers.

- EMF text with a Shift_JIS font charset now preserves Japanese characters,
  including searchable body text in DocuWorks documents.

- Covered text is left out of the DocuWorks index only when a fill provably
  hides it. A fill clipped away from the run, a translucent fill, a gradient or
  pattern fill, and an image no longer count as covers.

- DocuWorks index runs keep the ordinal the viewer draws them with, so a search
  hit lands on the right character after an earlier run is left out.

- DocuWorks index runs keep the separator the viewer computes, so phrases that
  span a line break stay searchable.

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
  a skipped guard. A close tag with a space, a tab or a newline before the
  `>`, as in `</rowBreaks >`, ends the block it closes, so a row break and a
  defined name still move; a block that is not closed at all is an error
  instead of a reference left behind. A calculation chain, a form control, a
  rich value or a web extension in a workbook whose rows move is an error
  too. A prefixed
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

- `form/pdf` reads the type of a field (`/FT`) from the whole object that
  holds its name, so a PDF whose writer puts `/FT` before `/T` (as most do)
  gets the right field types instead of the type of the next field.

### Deprecated


### Removed

- The `test:visual` aggregate no longer requires the dropped-format suites.
  Their individual scripts stay defined so the dormant packages can still be
  run by hand.

### Security


### Migration

- Callers that converted Gerber/Excellon, KiCad, MML, MIDI, MusicXML or EPUB
  through the Worker need another converter for those files. The packages,
  sources and fixtures stay in the tree as dormant assets, but they are not
  maintained and are not part of the required verification.

- Run `npm run verify:local` before pushing. GitHub no longer runs the checks.
  Once separately authorized, Pages can be published by manually dispatching
  `.github/workflows/pages-deploy.yml`. Branch protection may still require the
  old check names. The local flow uses existing `node_modules`, `.mooncakes` and
  Playwright Chromium and does not run `npm ci`, `moon update` or
  `npx playwright install`.

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
