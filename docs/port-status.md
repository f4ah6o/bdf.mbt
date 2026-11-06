# Port status

## Green gates

- `moon check --target js`
- `moon test --target js`
- `moon build --target js`
- `moon check --target wasm-gc`
- `moon test --target wasm-gc`
- `moon build --target wasm-gc`
- `npm run build:demo`
- `npm run test:demo`
- `npm run test:phase1-converter`
- `npm run test:phase2-converter`
- `npm run test:phase3-converter`
- `npm run test:phase4-converter`
- `npm run test:phase5-converter`
- `npm run test:converter-stream`
- `npm run test:export`
- `npm run test:phase8-type1`
- `npm run test:phase8-parquet`
- `npm run test:phase8-xlsx`
- `npm run test:phase9-drawio`
- `npm run test:phase9-parquet`
- `npm run test:phase11-markdown`
- `npm run test:phase12-docx`
- `npm run test:phase13-pdf`
- `npm run test:phase14-xlsx`
- `npm run test:phase15-pptx`
- `npm run test:viewer`
- `npm run test:visual`

## README Port backlog

- Done: opset 1 Canvas decoder, browser renderer and resource checks.
- Done: viewer `openFile` integration and PDF/DOCX/PPTX page streams.
- Done: DOM/OffscreenCanvas viewer, lazy pages, sheets, search, ARIA and MIDI.
- Done: MoonBit converters for the demo format set (PDF, DOCX, PPTX, XLSX,
  CSV, image, font, MIDI, MML, HP-GL/2, Jw_cad, text and binary DXF, SXF SFC,
  CGM, Gerber, KiCad PCB, draw.io, Parquet, audio, and reflowable/fixed-layout
  EPUB), plus AI, TIFF, PSD, EMF/WMF, IDML, Visio VSDX and MusicXML/MXL.
- Done: `convert/raster` PNG encoding and box scaling; the EMF/WMF metafile
  replay is also used by the DOCX and PPTX picture paths, with embedded
  EMF fixtures covering both Office integrations.
- Phase 2: `convert/idml` (complete with documented gaps) reads spreads, master spreads, layers, paths,
  colours, gradients (first stop), embedded images, stories and text indexes;
  threaded story flow is implemented; linked images, page-number markers and
  table stories are documented gaps. `convert/visio` reads VSDX page sheets, foreground and
  background pages, masters, layers, ShapeSheet geometry, solid fills/strokes,
  text and text indexes; theme quick styles, shadows, hyperlinks and pictures
  are documented gaps. `convert/drawingml` provides the shared approximate
  line breaking, alignment and frame-to-frame text flow. Full font metrics,
  OpenType shaping, tables and the remaining Visio theme/picture features are
  documented gaps. draw.io reads uncompressed and compressed XML, SVG/PNG
  exports and every diagram as a fitted fixed view with layers, wrappers,
  a practical mxGraph/flowchart/UML/BPMN shape registry, perimeters for edge
  attachment, edge labels and best-effort LaTeX→Unicode labels. Large
  AWS/Azure/GCP/Cisco icon tables, a full formula typesetting engine, images,
  line jumps and obstacle-aware routing are documented gaps; straight/curved
  edges, practical orthogonal/elbow routes and start/end marker variants are
  supported. Parquet tables are read with uncompressed, Snappy, GZIP, Brotli,
  Zstandard and LZ4 codecs, Data Page v1/v2, multiple row groups, dictionary/
  RLE/delta/byte-stream-split encodings, logical dates/timestamps/decimals,
  JSON-style nested values, WKB→WKT and WKT geometry columns, and Variant
  values. Variant metadata newer than version 1 and encrypted Parquet files
  are documented gaps.
- Phase 3: `convert/reader` provides the reader-mode block model (A4 pages for HTML, A5 book pages for EPUB); `convert/epub` reads the container, manifest and spine and converts picture-only pre-paginated books page-for-page at their viewport size and reading direction; `convert/html` reads headings, paragraphs, lists, code, quotes, tables and images-as-alt-text. `convert/markdown` now uses a pure-MoonBit CommonMark/GFM parser and builds the upstream 504-point scroll view, with nested lists and tasks, quotes, fenced and indented code, aligned tables, raw HTML, links, image alternative text, footnotes, definition lists, YAML/TOML front matter and linearized `$...$`/`$$...$$`/math-fence formulas. Inline SVG and data-URI images are drawn as image parts, with sprite-sheet defs borrowing and alt-text warnings for unresolved relative/remote images; `views=pages|both` emits A4-like pages with per-page text indexes. Heading, paragraph, figure, list, table, cell, line and wrap marks and link rectangles are emitted; nested list depth marks are partial. Long tables split across pages row by row with repeated headers, and quote bars repeat on every page; remote fetching and exact metrics remain documented gaps; sprite sheets may span multiple lines. Readability extraction, CSS, vertical writing, non-picture fixed layout, MHTML, embedded fonts and exact HTML reader-mode parity are documented gaps.
- Phase 4: `convert/audio` writes one-page cards for MP3, AAC (ADTS/M4A), FLAC, Ogg Vorbis/Opus, WAV and AIFF with multi-value ID3 tags, synchronized lyrics and chapters, APIC/FLAC/Ogg pictures, MP4/iTunes metadata and cover art, Ogg granule durations, corrected AIFF 80-bit sample rates, Dublin Core metadata and an optional playable audio part. DRM handling,
  ID3v2.2 tags, compressed ID3 frames, QuickTime `chpl` v1 chapters and Ogg
  FLAC/Speex remain documented gaps.
- Done: cryptography on non-JavaScript hosts. PBKDF2-HMAC-SHA-256,
  HKDF-SHA-256, AES-KW, AES-GCM and P-256 ECDH are in `crypto`, and encrypted
  BDF documents unlock with a password or P-256 private key through `core`.

## Document parity harness

- `npm run test:parity` converts the upstream document fixtures with the
  upstream TinyGo Wasm converter and the MoonBit native Worker and compares
  the canonical BDF, text index, MARK/LINK, summary and warnings. It is not a
  green gate yet: the current baseline is 12 pass, 40 diff, 0 one-sided error
  (see [docs/parity.md](parity.md)).
- The target commit is `a5e4d7a`; fixtures live in
  `compat/parity/fixtures`.
- The program scope now includes `form/` (template filling) and `print/`
  (IPP/CUPS), after the document converter parity gates.

## Form and print

- `form/tag` is ported: text and tags, values, sections, pictures, number
  formats, modes, text columns and code options, plus scopes, JSON truthiness
  and items, date parsing, value text, section variables and field collection,
  with the upstream tag and scope tests as MoonBit tests (12 tests).
- `form/textpart` is ported for the print image: width/cells/tall/rows, plain
  text with margins/paper/CRLF, the version-1 JSON encode/decode with its
  limits and checks, and the BDF part glue (`from_document`, `Image::add_to`)
  with 6 tests.
- `form/data` loads JSON, YAML, CSV/TSV/TXT and XLSX workbooks as objects
  or lists (numbers/booleans/empty values, header rows, named values and
  dotted names, merging), with 5 tests.
- `form/pdf` reads AcroForm field names, values (literal, hex, UTF-16BE,
  name), types, rectangles, page references, field flags, read-only/required
  state, no-export, alternate names, maximum lengths, default values,
  default font
  sizes/colors/fonts, backgrounds/borders/widths/styles (solid, dashed,
  underline, bevel, inset), alignment and
  display/export
  choice options (both names kept, display values map to export values,
  multiple values become a PDF array and are read back),
  writes values into classic-xref or xref-stream PDFs with an incremental
  update (30 tests, centered comb characters, multiline wrapping, masked
  password fields,
  referenced appearance streams, missing-required reporting, maximum-length enforcement
  in fills and overlays, hexadecimal field names, surrogate
  pairs, control-character escapes, optional read-only skipping, escaped
  literals, UTF-16BE hex, buttons, appearance on-state names, referenced
  AcroForms and `/NeedAppearances`), and draws a blank-page value overlay
  (checkbox `X`, multiline flags, maximum lengths, clipped wrapped values, MediaBox or CropBox sizing, optional
  read-only skipping).
- `form/ooxml` replaces `{{name}}` tags in OOXML XML parts, including tags
  split across runs (the run markup between them is removed), expands
  boolean `{{#name}}`/`{{^name}}` conditions, expands object-list
  `{{#items}}`…`{{/items}}` sections item by item, fills header/footer
  parts, and rebuilds stored ZIPs (4 tests); `form/docx` fills headers and
  footers, rendered header/footer values and filled table cells (6 tests), `form/xlsx` fills sheets, shared strings and inline strings and renders the filled cell (4 tests), and
  `form/pptx` fills slides and speaker notes, converts the filled deck and renders shape text through a slide layout (4 tests). Scalar
  list items are reported.
- `form/pdfme` fills a pdfme template (blank pages, text/line/rectangle/
  checkbox/radio-group (column/row)/table/rectangle (solid/dashed)/image
  (PNG/JPEG/SVG, stretch/contain/cover/none)/signature
  fields, table column widths, alignment/vertical
  alignment, colors, backgrounds, alternate row colors, font sizes/families,
  cell/column/header padding, truncation, border colors/widths/styles and
  header styles,
  static schema,
  multiVariableText variables, text backgrounds/borders,
  base-PDF MediaBox/CropBox page size, rotation, all pages, content and tables,
  QR codes, Code 39, Code 93, Code 128, GS1-128, EAN-13, EAN-8, UPC-A, UPC-E,
  ITF, NW-7 and MSI barcodes, arithmetic expressions with
  abs/round/floor/ceil/min/max) into BDF; extra base pages without a schema
  and other 1D formats are gaps (30 tests).
- `form/schema` writes the JSON Schema of the data of a template from its
  fields and a sample (objects, lists, conditions, pictures/codes, number
  formats, options, defaults, slots and the `x-bdf` keyword), with 3 tests.
- `form/textform` reads a plain-text template: the front matter (grid,
  margins, skip/title, font, ambiguous width, comments, quoted scalars and
  flow/block mappings), body lines and tags, page breaks, character/line
  attribute sections (`_wide`, `_tall`, `_big`, `preprinted`), section
  matching/modes and field collection. Filling covers values, inverted and
  normal sections (rows/slots/pages), section variables, columns
  (width/right/center/cut/wrap), combining marks, tabs, attribute ranges,
  automatic pagination/title lines and the print image; strict data and a
  number formatter are options (`fill_result_with`), and `fill_sources`
  connects form/data's JSON/YAML/CSV sources; 17 tests.
- `convert/textform` lays the image out as a fixed BDF view: grid columns,
  baseline, paper/body layers, tall characters, paragraph/table/cell marks,
  the print image as the `text` part, a text index and the `pages` option;
  `convert`/`convert_sources` fill and render in one step, using the front
  matter font family (5 tests). Font embedding and the remaining font
  options of the upstream converter remain.
- Next are the textform font options, the form partials and the other
  per-format fillers.
- CI runs `moon check/test/build` for js and wasm-gc, a demo job that
  builds and tests the demo, a parity workflow that converts the document
  fixtures with the upstream Wasm package and the MoonBit worker, and the
  full visual compatibility suite (converter, worker, font, XLSX, specimen
  and demo fixtures). All workflows pass on MoonBit 0.1.20261104; the
  compatibility JS exports use string/JSON values so they also work on the
  older 0.1.20261020 toolchain. The latest local full suite is js 2688/2688
  and wasm-gc 2672/2672; document parity is 12 pass / 40 diff.
- `print/raster` is started: the PWG Raster page header (1796 bytes,
  PWG 5102.4), row compression (runs/literals), the stream writer with row
  repetition, the reader, page fitting (print-scaling, orientation,
  sheet-back mirrors), RGBA-to-gray/RGB/one-bit row conversion, and Apple
  Raster headers/streams, a PCLm writer with RunLengthDecode and
  FlateDecode strips, and one-page PWG/URF/PCLm encoders from RGBA pixels,
  `PclmWriter::write_image_row` for RGBA rows, and bounded PWG reads,
  with 19 tests.
  `print/server` answers Get-Printer-Attributes,
  Validate-Job, Create/Print-Job, Send-Document, Get-Job-Attributes, Cancel-Job and
  Get-Jobs in memory (which-jobs, my-jobs and limit filters), with an HTTP
  request/response envelope, job-id/job-uri lookup, Print-Job/Send-Document
  documents stored on the job, Send-Document chunk appends, requested job
  requested-attribute filtering for create/print/send/get/list job responses,
  document-format and copies validation for Validate-Job, Print-Job and
  Send-Document, completed-job Send-Document/Cancel-Job rejection,
  job-state reasons, and PWG/URF/PDF page counting/abort (22 tests). `print/ipp` now has the tags, the
  message model and the binary request/response codec (integers, booleans,
  strings, languages, resolution, range, dateTime, octet strings and
  nested collections, with decode limits for bytes, attributes, values,
  value size and collection depth, and the group/attribute accessors
  (strings, ints, booleans, collections, resolutions, ranges), plus printer
  URL parsing (ipp/ipps/http/https, port 631, IPv6), requested-attributes,
  attribute filtering, printer groups, job/printer states and JobStatus
  parsing, the Printer model with media-col parsing, and DNS-SD TXT
  records/services (formats, URLs), and the HTTP request/response
  envelope around IPP messages, and a transport-agnostic Client that builds
  printer/job requests, response status checks/StatusError, and a
  transport-agnostic send over an HTTP post callback, and high-level
  fetch-printer/validate/create/send/print/job/cancel/jobs operations, and
  `print_pdf` sends a PDF after the Print-Job message, `print_data`
  sends any format, `decode_prefix` leaves the document after the
  message, `get_jobs` lists jobs, and `print_pwg`/`print_urf`/
  `print_pclm` wrap the formats; 26 tests).
  `print` exports a BDF document as PDF (`bdf_pdf`) and prints it
  (`print_bdf`, 1 test). `print/dnssd` has the DNS wire format (queries,
  responses, PTR/SRV/TXT/A/AAAA records, printer advertisement records,
  discovery of services from responses, IPv4/IPv6 addresses, mDNS
  probe/announce messages and browsing over a caller-supplied transport;
  7 tests). `print/ipp_js` adds the browser/Node fetch transport and
  `send_async`/`send_document_async`, `print_pdf_async` and
  `get_jobs_async` (3 tests).
  The CUPS client and the print server remain.

## Converter gaps

- PDF: Type1 `/FontFile` programs are interpreted into Type 2 outlines and a
  name-keyed CFF, then embedded; unsupported programs fall back to system fonts
  with a warning, and bare CFF programs are wrapped as OpenType. Tiling patterns, encoded image masks with
  ExtGState soft masks, JPX images, full JBIG2 decoding (generic arithmetic and
  MMR regions, symbol dictionaries, text regions, refinement, pattern
  dictionaries and halftone), Type3 glyph procedures, URI actions on form
  fields, and standard-security-handler revisions 2, 3, 4, 5 and 6 (RC4,
  AES-128 and AES-256) are supported. JPX/JBIG2-encoded images with
  colour-key masks are decoded and composited, and a 4-component JPX image
  without a declared colour space is now treated as RGB with an alpha
  component (the JPX fixture drops from 8 to 3 differences). DCT colour-key
  masks, tagged structure, one RGB JP2 rounding difference and
  CCITT/JBIG2/JPX masks combined with colour-key masks remain explicit gaps;
  CCITT G3/G4 image XObjects and inline images are decoded.
- XLSX: `convert/xlsx` renders styled worksheets with number formats, merges,
  row/column geometry, print areas, conditional formats, tables, links,
  pictures, drawings and charts, plus fixed chart-sheet pages, with upstream
  text indexes, summaries and warnings. Color scales, data bars and icon sets
  are painted. Embedded charts are SVG pictures (their labels are in the
  text index), and shape text wraps to its box. Patterned fills, complex borders
  and exact number-format run segmentation remain documented gaps in
  `compat/xlsx`.
- DOCX: `convert/docx` emits the upstream `pages` (`flow`) and `scroll`
  views (`views=both|pages|scroll`), with separate header/footer/body layers,
  page body rectangles, Dublin Core metadata, layer-aware text indexes,
  hyperlinks, regenerated PAGE/NUMPAGES fields, numbering overrides, Office
  Math and settings/footnote/endnote parts. Footnote and endnote bodies are
  laid out above the footer and appended to the scroll view. Real table cells
  wrap with grid/row spans, borders/fills, vertical alignment, row splitting
  and repeated header rows; columns, column breaks and vertical section
  bodies are implemented. Anchored drawings float left/right with square
  wrap or above/below a band, with behind/in-front z-order and page-fit
  movement; page borders are drawn in a background layer. Exact font
  metrics/shaping, tight/through contours and shadow painting, exact footnote separators, upright CJK in vertical text, tables in
  table-style base, first/last row/column,
  banded row/column and corner-cell parts (borders/shading/margins/text
  formatting; TableGrid is applied) remain documented gaps in `compat/docx`; autofit tables
  estimate text widths from run sizes.
- PPTX: `convert/pptx` emits the upstream `slides` fixed view with
  background/layout/master/body layers, shared master objects, placeholder
  text inheritance, bullets and levels, tables, bar/line/pie/area/scatter/radar charts with axis titles, line
  arrowheads and linearized Office Math. Preset geometry uses the upstream
  187-preset table
  and custom `a:custGeom` paths are evaluated with the same guide engine
  (arcTo is flattened to cubic Béziers), placeholder fill/line inheritance
  follows slide → layout → master, and a supplied font database embeds subset
  WOFF2 faces with real metrics. The 74 predefined table styles resolve
  fills, bands and header text; Medium-Style-2 also draws its grid/header
  borders. SmartArt diagram layout (data-model text fallback), ink, 3D and other chart types remain gaps; chart titles
  use `c:title` or the single-series name, and bar/line charts with `c:dTable`
  draw a category/series/value table. Advanced vertical stacking remains a
  documented gap in `compat/pptx`.
- AI: PDF-based Illustrator 9+ artwork only; PostScript files (Illustrator 8
  and earlier) and files saved without PDF content are explicit errors.
- TIFF: JPEG compression, YCbCr pages and DNG camera raw are not supported;
  affected pages are left blank with a warning. Classic TIFF and BigTIFF,
  strips and tiles, None/PackBits/LZW/Deflate/CCITT compression, 1-16-bit
  bilevel, grey, palette, RGB and CMYK samples, alpha and orientation are
  covered.
- Photoshop: the stored composite is used. A file saved without
  "Maximize Compatibility" has no composite and fails explicitly because
  layer compositing is not implemented.
- EMF/WMF: a documented subset (GDI state, lines, polygons, rectangles,
  ellipses, rounded rectangles, text, bitmaps and hatch-colour fallback)
  is replayed. Path records, clipping beyond rectangles, EMF+ only files and
  glyph-indexed text are warnings or gaps.
- HP-GL/2 and HP-GL plots are ported for vector instructions, labels, line
  types, fills, hatching and clip windows; Jw_cad drawings are ported for the
  figures in the upstream fixture set. DXF model space is ported for text and
  binary R12 to 2018 files, with HATCH, paper-space layouts and non-top OCS
  entities as documented gaps. SXF SFC drawings are ported for sheets, layers, colours,
  line types, lines, polylines, circles, arcs, ellipses, text, markers,
  splines, clothoids and compound figures; P21/P2Z, dimensions, labels and
  hatches are documented gaps. Binary CGM pictures are ported for VDC extents,
  metric scaling, lines, markers, polygons, rectangles, circles, arcs, ellipses
  and text; clear-text CGM, gzip, cell arrays, tiles and hatches are documented
  gaps. Single-file Gerber is ported for FS/MO/AD/AM, D01/D02/D03, linear and
  circular interpolation, regions, standard apertures and an approximate macro
  aperture, drawn 1:1; simple Excellon drill files with METRIC/INCH tools are
  also read. Board page scaling, zip archives, full Excellon headers, clear
  polarity and exact macros are documented gaps. KiCad `.kicad_pcb` boards are
  ported as a front view with Edge.Cuts, tracks, vias, pads and reference/value
  text; schematics, projects, back/layer views, zones and 3D models are
  documented gaps. PCL/HP RTL raster jobs are a documented gap: the escape
  sequences are skipped with a warning and only the HP-GL/2 instructions are
  converted. The remaining CAD formats (SXF P21, clear-text CGM), Gerber board archives and KiCad schematics/back-layers are not
  ported; draw.io large icon tables and full math typesetting remain gaps,
  while Parquet WKB and Variant are supported with the limits noted above. Camera raw (DNG/CR2) is
  not an upstream converter and is outside the port. The subsets of the ported
  formats above are documented gaps, not claims of full parity.

## Next steps

1. ~~Port Type1 font programs to CFF so `/FontFile` fonts embed natively.~~
   Done: Type 1 charstrings are interpreted into Type 2 outlines and a
   name-keyed CFF, then embedded through the existing CFF path.
2. Close the remaining fixture-backed gaps, in this order:
   - draw.io route/shape/stencil suites (the upstream `route`, `shapes`,
     `shapes_basic`, `shapes_libs`, `shapes_aws4`, `stencil` and
     `aws_legacy` fixtures; only the top-level files are exercised today).
   - KiCad schematics, projects and drawing sheets (`demo.zip`, `demo/`,
     `frame/`).
   - SXF P21/P2Z (`shapes.p21`, `shapes.p2z`); the SFC path is complete.
   - Reader-mode resources (`html/math.html`). Markdown math, SVG text and
     the `math.md`/`svg.md` fixtures are ported.
   - EPUB vertical writing and non-picture fixed layout (`vertical.epub`).
   - IDML `simpleidml/` packages, linked images and table stories.
   - PPTX font directories and non-rectangular preset geometries
     (`testdata/fonts`); DOCX and PPTX OMML math are ported.
   - PSD layer compositing when a file has no composite, and TIFF
     JPEG/YCbCr pages.
   - ~~The MusicXML to BDF converter (the parser exists but the Worker does
     not dispatch it).~~ Done: `convert/musicxml` builds the score and playback
     sequence, and the native Worker dispatches `musicxml`/`mxl`.
   - The upstream class-shaped `BdfDocument`, `CanvasRenderer` and
     `PageRenderer` APIs.
3. ~~Port Parquet sheet input.~~ Done for flat and nested tables with common
   codecs, Data Page v1/v2, common encodings, WKB→WKT/WKT geometry and
   Variant version 1; encryption remains.
4. ~~Port the XLSX font-embedding mode.~~ Done: `convert_plain_with_font`
   embeds an explicit face and uses its advances/metrics; the Worker picks the
   first face of a supplied font directory.
5. Keep importing the remaining upstream test data for every ported format and
   assert either parity or the exact documented warning; never skip a fixture
   silently.

## Status at round 100

- Full MoonBit tests: 2630/2630 pass on JS and 2614/2614 pass on wasm-gc.
- Document parity harness: 12 pass, 40 diff, 0 one-sided errors, 0 both-error.
- Demo: all 20 upstream pages plus search, navigation, download, CSV, SVG,
  fonts, XLSX, draw.io, Parquet, sheet switching, embedded PNG, save/reload,
  warnings, replacement, errors and the mobile path pass.
- Form: textform, data (JSON/YAML/CSV/TSV/XLSX), OOXML value/condition/list
  tags with DOCX/PPTX/XLSX wrappers, basic pdfme fields/QR/barcodes/
  expressions, and PDF AcroForm reading plus an overlay.
- Print: IPP client/server, PWG/URF/PCLm encoders and readers, PDF and
  raster printing, DNS-SD records and browse over a supplied transport.
- Not complete: upstream document parity is still 12/52; PDF form writing,
  form partials, OOXML rows that cross table structure, pdfme base-PDF
  content, BDF rasterization, real CUPS/UDP sockets and several documented
  converter subsets remain gaps. This port is not claimed to be complete.

