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
- Phase 3: `convert/reader` provides the reader-mode block model (A4 pages for HTML, A5 book pages for EPUB); `convert/epub` reads the container, manifest and spine and converts picture-only pre-paginated books page-for-page at their viewport size and reading direction; `convert/html` reads headings, paragraphs, lists, code, quotes, tables and images-as-alt-text. `convert/markdown` now uses a pure-MoonBit CommonMark/GFM parser and builds the upstream 504-point scroll view, with nested lists and tasks, quotes, fenced and indented code, aligned tables, raw HTML, links, image alternative text, footnotes, definition lists, YAML/TOML front matter and linearized `$...$`/`$$...$$`/math-fence formulas. Inline SVG and data-URI images are drawn as image parts, with sprite-sheet defs borrowing and alt-text warnings for unresolved relative/remote images; `views=pages|both` emits A4-like pages with per-page text indexes. Heading, paragraph, figure, list, table, cell, line and wrap marks and link rectangles are emitted; nested list depth marks are partial. Long tables split across pages row by row with repeated headers; remote fetching, multi-line sprite borrowing, repeated quote bars and exact metrics remain documented gaps. Readability extraction, CSS, vertical writing, non-picture fixed layout, MHTML, embedded fonts and exact HTML reader-mode parity are documented gaps.
- Phase 4: `convert/audio` writes one-page cards for MP3, AAC (ADTS/M4A), FLAC, Ogg Vorbis/Opus, WAV and AIFF with multi-value ID3 tags, synchronized lyrics and chapters, APIC/FLAC/Ogg pictures, MP4/iTunes metadata and cover art, Ogg granule durations, corrected AIFF 80-bit sample rates, Dublin Core metadata and an optional playable audio part. DRM handling,
  ID3v2.2 tags, compressed ID3 frames, QuickTime `chpl` v1 chapters and Ogg
  FLAC/Speex remain documented gaps.
- Done: cryptography on non-JavaScript hosts. PBKDF2-HMAC-SHA-256,
  HKDF-SHA-256, AES-KW, AES-GCM and P-256 ECDH are in `crypto`, and encrypted
  BDF documents unlock with a password or P-256 private key through `core`.

## Converter gaps

- PDF: Type1 `/FontFile` programs are interpreted into Type 2 outlines and a
  name-keyed CFF, then embedded; unsupported programs fall back to system fonts
  with a warning, and bare CFF programs are wrapped as OpenType. Tiling patterns, encoded image masks with
  ExtGState soft masks, JPX images, full JBIG2 decoding (generic arithmetic and
  MMR regions, symbol dictionaries, text regions, refinement, pattern
  dictionaries and halftone), Type3 glyph procedures, URI actions on form
  fields, and standard-security-handler revisions 2, 3, 4 and 6 (RC4, AES-128
  and AES-256) are supported. Revision 5 encryption, encoded images with
  colour-key masks, tagged structure, and CCITT/JBIG2/JPX masks combined with
  colour-key masks remain explicit gaps; CCITT G3/G4 image XObjects and inline
  images are decoded.
- XLSX: `convert/xlsx` renders styled worksheets with number formats, merges,
  row/column geometry, print areas, conditional formats, tables, links,
  pictures, drawings and charts, plus fixed chart-sheet pages, with upstream
  text indexes, summaries and warnings. Color scales, data bars and icon sets
  are not painted, embedded charts are SVG pictures (their labels are in the
  text index), shape text does not wrap, and patterned fills, complex borders
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
  movement. Exact font metrics/shaping, tight/through contours and effect
  extents, exact footnote separators, upright CJK in vertical text, tables in
  headers/footers, PAGEREF/REF, page borders, keep/widow chains and table
  styles/autofit remain documented gaps in `compat/docx`.
- PPTX: `convert/pptx` emits the upstream `slides` fixed view with
  background/layout/master/body layers, shared master objects, placeholder
  text inheritance, bullets and levels, tables, bar/line/pie charts, line
  arrowheads and linearized Office Math. Preset geometry uses the upstream
  187-preset table
  and custom `a:custGeom` paths are evaluated with the same guide engine
  (arcTo is flattened to cubic Béziers), placeholder fill/line inheritance
  follows slide → layout → master, and a supplied font database embeds subset
  WOFF2 faces with real metrics. SmartArt/ink, 3D, other chart types, chart
  data tables/titles, table style
  banding, blip bullets and advanced vertical stacking remain
  documented gaps in `compat/pptx`.
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
