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
- `npm run test:visual`

## README Port backlog

- Done: opset 1 Canvas decoder, browser renderer and resource checks.
- Done: viewer `openFile` integration and PDF/DOCX/PPTX page streams.
- Done: DOM/OffscreenCanvas viewer, lazy pages, sheets, search, ARIA and MIDI.
- Done: MoonBit converters for the demo format set (PDF, DOCX, PPTX, XLSX,
  CSV, image, font, MIDI/MML/MusicXML, HP-GL/2, Jw_cad, DXF, SXF, CGM), plus AI, TIFF, PSD, EMF/WMF,
  IDML and Visio VSDX.
- Done: `convert/raster` PNG encoding and box scaling; the EMF/WMF metafile
  replay is also used by the DOCX and PPTX picture paths, with embedded
  EMF fixtures covering both Office integrations.
- Phase 2: `convert/idml` (complete with documented gaps) reads spreads, master spreads, layers, paths,
  colours, gradients (first stop), embedded images, stories and text indexes;
  threaded story flow, linked images, page-number markers and table stories
  are documented gaps. `convert/visio` reads VSDX page sheets, foreground and
  background pages, masters, layers, ShapeSheet geometry, solid fills/strokes,
  text and text indexes; theme quick styles, shadows, hyperlinks and pictures
  are documented gaps. `convert/drawingml` provides the shared approximate
  line breaking, alignment and frame-to-frame text flow. Full font metrics,
  OpenType shaping, tables and the remaining Visio theme/picture features are
  documented gaps.
- Phase 3: `convert/reader` provides the reader-mode block model and fixed A4 layout; `convert/epub` reads the container, manifest and spine; `convert/html` reads headings, paragraphs, lists, code, quotes, tables and images-as-alt-text; `convert/markdown` reads front matter, headings, lists, tasks, fences, quotes, rules, simple tables and inline links. Readability extraction, CSS, remote images, fixed-layout EPUB, MHTML, embedded fonts and exact CommonMark/GFM behavior are documented gaps.
- Phase 4: `convert/audio` writes one-page cards for MP3, AAC (ADTS/M4A), FLAC, Ogg Vorbis/Opus, WAV and AIFF with tags, covers, lyrics, durations and an optional playable audio part. MP4/iTunes tags and covers, Ogg duration, synchronized lyrics, chapters and DRM are documented gaps.
- Done: cryptography on non-JavaScript hosts. PBKDF2-HMAC-SHA-256,
  HKDF-SHA-256, AES-KW, AES-GCM and P-256 ECDH are in `crypto`, and encrypted
  BDF documents unlock with a password or P-256 private key through `core`.

## Converter gaps

- PDF: Type1 `/FontFile` programs still use the system-font fallback; bare CFF
  programs are wrapped as OpenType. Tiling patterns, JPX/JBIG2/CCITT images,
  form-field actions and encrypted PDFs are not supported.
- DOCX/PPTX: the converters intentionally implement the documented subsets.
  Unsupported features fail closed or are documented in `compat/docx` and
  `compat/pptx`.
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
  figures in the upstream fixture set. DXF model space is ported for ASCII
  R12 to 2018 files, with HATCH, binary DXF, layouts and non-top OCS entities
  as documented gaps. SXF SFC drawings are ported for sheets, layers, colours,
  line types, lines, polylines, circles, arcs, ellipses, text, markers,
  splines, clothoids and compound figures; P21/P2Z, dimensions, labels and
  hatches are documented gaps. Binary CGM pictures are ported for VDC extents,
  metric scaling, lines, markers, polygons, rectangles, circles, arcs, ellipses
  and text; clear-text CGM, gzip, cell arrays, tiles and hatches are documented
  gaps. PCL/HP RTL raster jobs are a documented gap: the escape
  sequences are skipped with a warning and only the HP-GL/2 instructions are
  converted. The remaining CAD formats (SXF P21, clear-text CGM), Gerber, KiCad and draw.io
  are not ported. Camera raw (DNG/CR2) is
  not an upstream converter and is outside the port. The subsets of the ported
  formats above are documented gaps, not claims of full parity.

## Next steps

1. Port Type1 font programs to CFF so `/FontFile` fonts embed natively.
2. Port the deferred SXF, CGM, Gerber/Excellon and KiCad converters, then the
   draw.io converter.
3. Port Parquet sheet input and the XLSX font-embedding mode.
4. Close documented gaps in the ported formats only where a source fixture can
   be compared with upstream.
