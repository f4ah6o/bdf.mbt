# bdf.mbt

MoonBit implementation of the BDF v1 wire-format reader and the browser-facing `@bdfkit/render`, `@bdfkit/convert`, and `@bdfkit/viewer` control layers.

- Targets: `js` and `wasm-gc`.
- `core`: checked BDF header, single and split documents (identity and deflate-raw), document writing and encryption assembly, BOBJ resource tables, MIDI sequences, cue indexes, and a bounded binary reader.
- `render`: backend-neutral, checked display-list decoder for every opset 1 Canvas 2D opcode, including paths, gradient paints, and drawing effects. It also extracts ordered text runs, semantic structure, figure bounds and link rectangles, serializes table-cell selections, calculates music and audio cue positions, and plans shared page-body prefixes.
- `convert`: the worker-client request/response lifecycle and stream command model. The browser adapter connects these to a Worker and a separately supplied compatible Wasm runtime; the native converter supports CSV, styled XLSX worksheets and chart sheets, font specimens, a checked PDF subset including Type 1 font conversion, Illustrator artboards through that PDF path, DOCX flow/scroll text layout, PPTX slides with master/layout layers, IDML through an approximate shared text-flow engine, Visio VSDX, HTML reader mode, Markdown scroll views, audio cards, TIFF, Photoshop, EMF/WMF, HP-GL/2 and HP-GL plots, Jw_cad drawings, text and binary DXF drawings, SXF SFC drawings, CGM, draw.io diagrams including compressed/SVG/PNG exports, Parquet tables, and the BMP, ICO, JPEG, PNG, GIF, WebP, AVIF and SVG image formats. SXF P21/P2Z, CGM cell arrays and hatches, the large draw.io stencil tables, and PCL/HP RTL raster jobs remain explicit gaps.
- `convert/font`: SFNT/TTC, WOFF and WOFF2 font specimen conversion to BDF, including overview, character charts, glyph grids, OpenType feature examples, collection face selection and text indexes. Embedded programs use WOFF2 by default, with an option to retain SFNT.
- `convert/csv`: CSV decoding, detection and conversion to BDF sheets, including built-in table styles, text indexes and typed Parquet tables. The converter accepts an explicitly supplied font or an in-memory font database, selecting fallback faces per character, subsetting TrueType and supported CFF outlines where permitted, and embedding WOFF2 by default. Host filesystem and system font discovery remain to be ported.
- `convert/xlsx`: OOXML workbooks with shared and inline strings, styles and number formats, merges, row/column geometry, hidden rows/columns, print areas, conditional formats, tables, hyperlinks, comments, embedded pictures, worksheet drawings, charts and chart sheets. The plain renderer emits sheet tiles and fixed chart-sheet pages with upstream text indexes, summaries and warnings; shape text wraps to its box, and the Worker adds the no-font warning and embedded-font count. Remaining gaps are documented in `compat/xlsx`: colour scales, data bars and icon sets are painted, embedded charts are SVG pictures while their labels are in the text index, and complex borders and exact number-format run segmentation are incomplete; the 8x8 pattern fills match upstream.
- `convert/pdf`, `convert/docx` and `convert/pptx`: the PDF path is public and Worker-backed. It covers object parsing, page trees, graphics, simple and composite text, metadata, text indexes, shared page prefixes, JPEG image XObjects and inline images, CCITT G3/G4 image XObjects and inline images, 8-bit Flate sample images in Gray, RGB and CMYK, 1-bit stencil image masks, stencil and colour-key `/Mask` attachments, 8-bit grayscale `/SMask` attachments, form XObjects with their resources, matrix, bounding box and transparency groups, axial/radial shadings with exponential or stitching functions, shading patterns, URI link annotations and URI actions inherited from form fields, optional-content layer visibility, annotation `/AP /N` appearance streams and state dictionaries, tiling patterns, encoded image masks (including ExtGState soft masks) for DCT, JPX and JBIG2 image data, JPX JPEG 2000 images, JBIG2 images (generic arithmetic and MMR regions, symbol dictionaries, text regions and halftone), Type3 glyph procedures, and embedded TrueType/OpenType font programs from `/FontFile2` or `/FontFile3` OpenType. The PDF standard security handler supports revisions 2, 3, 4, 5 and 6 (RC4 40/128-bit, AES-128 and AES-256); colour-key masks on JPX/JBIG2-encoded images are decoded and applied, while DCT colour-key masks fail with explicit errors; encrypted BDF single-file documents unlock with a password or P-256 key; embedded bare CFF programs are wrapped as OpenType; unsupported Type1 programs fall back to system fonts with a warning. Tagged structure is ignored for visual rendering. PDF, DOCX and PPTX conversions accept a `pages` selection and return only the requested pages. The PDF converter also accepts `kind=flow` to mark its pages as a flow view with full-page body rectangles, and `box=media|bleed|trim|art` to choose the page box. The DOCX path lays text out into the upstream pair of views: a `flow` page view with separate header, footer and body layers and body rectangles, and a page-free `scroll` view cut into strips (the `views=pages|scroll|both` option selects them). It reads settings, theme fonts, core metadata, hyperlinks, fields and Office Math (linearized for search), accepts footnotes/endnotes (their bodies are laid out above the footer and appended to the scroll view), and carries layer-aware text indexes. Real table cells are laid out with cell paragraphs, wrapping, grid and row spans, borders and fills, vertical alignment, row splitting and repeated header rows; `w:cols` columns, column breaks, vertical section bodies, PAGE/NUMPAGES regeneration, table widths (`w:tblW` dxa/pct) scaling the grid, header/footer images, header/footer tables, PAGEREF page resolution, REF bookmark text and numbering overrides are implemented. Paragraph shading and borders, page borders in a background layer, keepLines/widowControl/keepNext, text boxes, inline PNG/JPEG/EMF/WMF drawings with crops/rotation/flips, anchored drawings (floating left/right/top-and-bottom wrap and behind/in-front z-order) and first/even-page headers are supported. Exact font metrics and shaping, tight/through wrap contours and shadow painting, exact footnote separator/continuation indent, upright CJK glyphs in vertical text, table-style base, first/last row/column, banded row/column and corner-cell parts (borders/shading/margins/text formatting; TableGrid is applied) and the exact number of scroll strips remain documented gaps; autofit tables estimate text widths from run sizes.
The PPTX path emits the upstream `slides` fixed view with background, layout, master and body layers; master, layout and background objects are shared between slides. It renders solid, image and linear-gradient backgrounds, embedded pictures with alpha, source-rectangle cropping, rotation and flips, rectangle/rounded-rectangle/ellipse fill and stroke, line arrowheads (triangle/stealth/diamond/oval/arrow), theme colour schemes with luminance/tint/shade modifiers and theme major/minor fonts, placeholder inheritance by `idx` then type (transform, text chain and list styles), bullets (`buChar`/`buAutoNum`/`buBlip` with `buClr` and `buSzPct`/`buSzPts`), levels and indents, paragraph/line spacing, text-box insets/anchors, word and CJK wrapping with paragraph/line/wrap marks, vertical text, table cell text with spans/borders/fills, the 74 built-in table-style fills/bands/text with Medium-Style-2 borders, bar/line/pie/doughnut/area/scatter/radar/stacked charts with legends, axis titles, category, value (`dLbls`) and percentage labels, translated/scaled/rotated group shapes, and Office Math (`a14:m`) linearized for search instead of fallback pictures. Its text index matches upstream page for page. Preset geometries are generated from the upstream table (187 presets) and unknown presets warn and fall back to a rectangle; placeholder fill/line inheritance follows slide → layout → master with `p:style` theme references, and a supplied font database embeds subset WOFF2 faces with real metrics. Custom geometry is supported (arcTo is flattened to cubic Béziers); SmartArt diagram layout (its data-model text is drawn as a fallback), ink, 3D, other non-bar/line/pie/doughnut/area/scatter/radar charts and advanced vertical stacking remain documented gaps; chart titles use an explicit `c:title`, falling back to the series name for a single-series chart, and bar/line/pie/radar/scatter charts with `c:dTable` draw a category/series/value table honouring the show and border flags.
- `convert/raster`, `convert/tiff`, `convert/psd`, `convert/ai`, `convert/metafile` and `convert/emf`: PNG encoding, box-filter scaling and raster page assembly; classic TIFF and BigTIFF with strips and tiles, None, PackBits, LZW, Deflate and CCITT G3/G4 compression, 1–16-bit bilevel, grey, palette, RGB and CMYK samples, alpha and orientation; Photoshop PSD/PSB composite images, colour modes, artboards and XMP metadata; Illustrator artwork through the PDF converter with artboard trim boxes and placeholder detection; and EMF/WMF replay (GDI state, lines, polygons, rectangles, ellipses, rounded rectangles, text, bitmaps and hatch-colour fallback) for standalone pictures and for DOCX/PPTX drawings. TIFF JPEG compression and YCbCr pages, PSD layer compositing when a file has no composite, metafile paths/clipping and EMF+ only files are explicit gaps; unsupported pages fail or warn instead of being drawn incorrectly.
- `convert/drawingml`, `convert/idml` and `convert/visio`: the shared approximate DrawingML text layout (line breaking, alignment and multi-frame story flow) used by IDML; InDesign Markup packages (spreads and master spreads, page geometry, layers, path shapes, solid fills and strokes, first-stop gradient colours, embedded raster images, stories, threaded story flow and text indexes); and Visio 2013+ VSDX drawings with their own approximate text layout (page sheets, foreground/background pages, masters, layers, ShapeSheet geometry, solid fills/strokes, text and text indexes). Exact font metrics and shaping, linked IDML images, IDML page-number markers and table stories, and Visio theme quick styles, shadows, hyperlinks and pictures are documented gaps.
- `convert/reader`, `convert/html` and `convert/markdown`: the reader-mode block model (A4 pages for HTML); HTML reader text (headings, lists, code, quotes, tables). Markdown uses a pure-MoonBit CommonMark/GFM parser and produces the same 504-point scroll view as upstream: nested ordered/unordered lists and tasks, quotes, fenced and indented code, tables with alignments, raw HTML, links, image alternative text, footnotes, definition lists, YAML/TOML front matter, and `$...$`/`$$...$$` formulas and math code fences linearized to searchable text. The converter accepts `width` (the scroll column width in points), `size`, `font`, `mono` and `views` (`scroll|pages|both`) options; the default column is 36 ems at 12 points, the same 504-point strip upstream emits, and `pages` paginates into A4-like fixed pages. Views emit heading, paragraph, figure, list, table and cell marks plus link rectangles. Inline SVG and data-URI images are drawn as image parts (including sprite-sheet defs), while unresolved relative/remote images keep their alternative text and a warning. Long tables split across pages row by row with their header repeated, and quote bars repeat on every page; remote fetching, MARK structure and exact metrics remain documented gaps; sprite sheets may span multiple lines. Readability extraction, CSS, vertical writing, MHTML, embedded fonts and exact HTML reader-mode parity are documented gaps.
- `convert/audio`: one-page audio cards for MP3, AAC (ADTS and M4A), FLAC, Ogg Vorbis/Opus, WAV and AIFF: multi-value ID3v2/v1 tags, synchronized lyrics (SYLT), chapters (CHAP), APIC covers, RIFF INFO and ID3 chunks, AIFF text with 80-bit sample rates, FLAC Vorbis comments and pictures, Ogg Vorbis/Opus comments, METADATA_BLOCK_PICTURE covers and granule durations, MP4/iTunes metadata, cover art and chapters, Dublin Core metadata, lyrics/chapter card sections and the browser-playable audio part. DRM handling, ID3v2.2 tags, compressed ID3 frames, QuickTime `chpl` v1 chapters and Ogg FLAC/Speex remain documented gaps.
- `font/sfnt`: TrueType, OpenType and TTC face metadata, Unicode glyph maps and horizontal metrics, WOFF 1.0 decoding, and glyph and sample font programs for font specimens. TrueType and CFF specimen pruning compute the GSUB substitution closure, or accepts an explicitly supplied one. `font/db` resolves supplied font families, styles and per-character fallbacks; `convert/sheet` can draw using those faces. `font/woff2` decodes and encodes WOFF2; its encoder uses the glyf transform when possible and its Brotli output differs from upstream.
- \`form\` and \`print\`: text-form filling (\`form/textform\`, \`convert/textform\`), JSON/YAML/CSV/worksheet data sources, OOXML value/condition/list tags and DOCX/PPTX/XLSX fillers, a basic pdfme filler (text, tables, images, QR, Code 39/128, EAN-13/8, UPC-A, ITF, NW-7, arithmetic expressions), and PDF AcroForm field reading; IPP client/server with PWG/URF/PCLm raster encoders and readers, PDF printing, DNS-SD records and browsing over a supplied transport. PDF form appearance generation and text indexing, pdfme base-PDF content, form signing and picture inlining, BDF rasterization and OS multicast sockets remain gaps.
- `viewer`: document/view selection state and page placement in single, spread, and continuous modes, including RTL spreads and scroll strips.
- `browser` (JS only): Canvas 2D adapter that draws fixed/flow pages, scroll strips, continuous body regions, and sheet viewports, including password- and P-256-protected documents, into a DOM host, including paths, gradients, child objects, transparency groups, masks, asynchronously loaded images and fonts, and optional selectable text layers.

Main-thread interactive page views correct top-baseline selection and search
positions for a limited set of simple, single-layer text objects; see [browser support and
remaining limitations](docs/browser.md). Worker-backed and sheet views retain
their current behavior.

PCB/KiCad (Gerber, Excellon), musical-score (MML, MIDI, MusicXML) and EPUB conversion are outside the maintained porting scope. Their packages, sources and fixtures stay in the tree as dormant assets, but they are not registered with the converter Worker, not offered in the viewer, and not part of the required verification. Audio playback and non-PCB CAD (DXF, Jw_cad, SXF, CGM, HP-GL/2) remain in scope.

This is an **incremental port**, not a feature-equivalent replacement for the upstream npm packages. The Canvas renderer, DOM viewer, wasm-gc cryptography and native converter Worker are implemented; the remaining differences are the documented format subsets above, the upstream class-shaped low-level `BdfDocument`/`CanvasRenderer` APIs, and a smaller set of viewer edge cases. Unsupported drawing opcodes fail explicitly instead of silently rendering incorrectly.

Upstream implementation: https://github.com/shibukawa/bdf ([MIT license](licenses/Shibukawa-bdf.txt)). Wire specification: https://github.com/shibukawa/bdf/blob/main/docs/spec.md .

## Verify

```sh
moon update
moon check --target js
moon test --target js
moon build --target js
moon check --target wasm-gc
moon test --target wasm-gc
moon build --target wasm-gc
```

## API examples

```moonbit
let writer = @core.DocumentWriter::new()
let part_hash = writer.add_part("img", image_bytes)
let new_bdf_bytes = writer.write_single()
let split = writer.write_split() // save manifest and each part under parts/<hash>
let header = @core.parse_header(existing_bdf_bytes)
let document = @core.open_single(existing_bdf_bytes) // unencrypted BDF
let object = @core.decode_object(document.part(hash))
let commands = @render.compile_object(object) // Canvas command list
let image = @image.convert(image_bytes, name="picture.bmp") // @f4ah6o/bdf/convert/image
let pdf = @pdf.convert(pdf_bytes) // @f4ah6o/bdf/convert/pdf
let sfnt_bytes = @sfnt.decode_woff(woff_bytes) // @f4ah6o/bdf/font/sfnt
let sfnt2_bytes = @woff2.decode(woff2_bytes) // @f4ah6o/bdf/font/woff2
let web_font = @woff2.encode(sfnt_bytes)
let font_file = @font.load(font_bytes) // @f4ah6o/bdf/convert/font
let (faces, font_warnings) = font_file.select("all")
let specimen = @font.convert(font_bytes, @fontdb.Database::new())
let fonts = @fontdb.Database::new() // @f4ah6o/bdf/font/db
fonts.add_file("regular.ttf", regular_font_bytes)
fonts.add_file("bold.ttf", bold_font_bytes)
let sheet = @csv.convert_with_fonts(csv_bytes, fonts) // @f4ah6o/bdf/convert/csv
let client = @convert.Client::new()
let request = client.request(@convert.Convert, @convert.ConvertOptions::new())
let selected = @convert.page_numbers(@convert.parse_pages("1-3,5,8-"), 10)
let viewer = @viewer.Viewer::new()
viewer.set_layout(@viewer.Spread)
let sequence = @core.parse_smf(midi_bytes)
let seconds = @core.tick_to_seconds(sequence, 480.0)
let cues = @core.decode_cues(cue_bytes)
let cursor = @render.cursor_at_tick(cues, 480.0)
```

The `convert/image` package converts BMP, ICO, JPEG, PNG, GIF, WebP, AVIF and SVG images on both targets, preserving the input bytes and matching upstream page geometry and figure alternative text. JPEG and PNG EXIF orientation and metadata, JPEG IPTC, AVIF rotation, SVG metadata, and UTF-8 or BOM-marked UTF-16 XMP are supported. WebP EXIF orientation is reported but not applied, matching browsers. Some malformed SVG and XMP, other XML encodings, and PNG Creation Time timezone abbreviations are not yet supported. `bdf_create_native_converter` exposes the supported formats through a browser Worker without a Go runtime.

`DocumentWriter` accepts manifest-format JSON for metadata, views and tables, and writes an unencrypted single-file or split document with content-addressed, deduplicated parts. It chooses identity or raw DEFLATE storage using the upstream defaults. `single_to_split` and `split_to_single` copy stored parts between container forms and validate their hashes, including for encrypted documents without requiring a key. The JS browser adapter can encrypt a single-file document using a password or P-256 public key; the core sealing plan also supports a host-provided crypto implementation. `ObjectBuilder` generates drawing commands and resource tables.

The native converter Worker dispatches CSV/TSV, XLSX, DOCX, PPTX, font, PDF, image, AI, TIFF, PSD, EMF/WMF, IDML, Visio, Markdown, HTML, audio, HP-GL/2, Jw_cad, DXF, SXF SFC, CGM, draw.io and Parquet conversions without a Go runtime, including the same no-system-font fallback used by the upstream browser build and the 60 built-in Excel table styles. A font directory URL can supply `index.json` and TrueType/OpenType files; the native Worker currently fetches indexed font files in full rather than using upstream's range requests. When a font directory is supplied, XLSX embeds the first face and uses its cell metrics, otherwise it uses estimated metrics without embedding fonts. Format selection supports explicit format names, registered filename extensions and content detection.

The `core` package exposes `open_split` with a lazy host-provided loader for split documents. The loader is responsible for enforcing its supplied stored-size limit while reading. `decode_text_index` reads BTXT parts, and `render.view_text_index` loads a stored index or reconstructs one for paginated views and sheets, including external tile indexes. `TextSearch` finds normalized matches and maps them to UTF-16 offsets in the original runs; `render.locate_text_hit` measures their highlight rectangles. The `browser` package exposes `mount_bdf_async` for single-file documents, `mount_bdf_split_async` for split documents with an asynchronous part loader, and `mount_bdf` for documents that need no image or embedded font loading. The `mount_bdf_interactive_*` variants add an accessible text and link layer and search for pages and sheets. Call `unmount_bdf` to release retained resources. See [browser usage](docs/browser.md).

Search normalization uses Unicode 16.0 data. An upstream JavaScript runtime using a different Unicode version can differ for characters whose mappings changed between versions.
Tile coordinates are currently limited to signed 32-bit values.

`Page` now includes `body`, and `View` includes `direction` and
`continuous_gap` and `play`. Code constructing these public records directly
must supply those fields; parsed documents use `None`, `"ltr"`, `None`, and
`None` respectively when absent. `Document::play` and `SplitDocument::play`
load MIDI bytes and cues; their `audio` methods load recorded audio and cues.
The audio MIME type is restricted to `audio/*`. Page views with a MIDI sequence can switch to a piano roll using `bdf_set_music_mode_async`. The browser adapter plays MIDI with Web Audio and embedded recordings with an audio element, and maps playback positions to cues. MIDI parsing, channel state and timeline calculations work on both targets.

`ConvertOptions` includes a `params` map for format-specific options. Code
constructing this public record directly must provide the map; use
`ConvertOptions::new()` for an empty one.

## Port backlog

1. ~~Complete the opset 1 Canvas command decoder and browser Canvas renderer, and safe resource loading.~~ Done: every opset 1 draw opcode decodes to a command, the browser renderer dispatches every command variant, and path/paint/font/image references are range-checked. `render` and `browser` unit tests cover decoding, dispatch, and rejected references.
2. ~~Cryptography support on non-JavaScript hosts.~~ Done: `crypto` provides PBKDF2-HMAC-SHA-256, HKDF-SHA-256, AES-KW (RFC 3394), AES-GCM and P-256 ECDH in pure MoonBit, and `core` unlocks encrypted BDF single-file documents with a password or a P-256 private key. Vectors come from RFC 5869/3394, NIST GCM and Go-produced encrypted fixtures.
3. ~~MoonBit converter engines and viewer openFile integration for streaming page conversion.~~ Done: the viewer openFile path uses the converter stream API, and the native Worker now opens PDF/DOCX/PPTX conversions as page streams, returning one page BDF per `page` request. `core.select_pages` also supports explicit page selection.
4. ~~DOM/OffscreenCanvas viewer, lazy page rendering, sheet support, search, accessibility and music playback.~~ Done: the DOM viewer renders through Canvas/OffscreenCanvas with lazy pages, live sheet viewports, text search, ARIA text/table layers and MIDI playback. Browser, sheet, search and MIDI unit tests plus the demo cover these paths.
5. ~~Replace or separately port TinyGo converter engines for the desired document formats.~~ Done for the current phase: MoonBit engines cover the demo format set—PDF, DOCX, PPTX, XLSX, CSV, image, font, HP-GL/2, Jw_cad, DXF (text and binary), SXF SFC, CGM, draw.io, Parquet, AI, TIFF, PSD, EMF/WMF, IDML, Visio, HTML, Markdown and audio—and the native converter Worker serves them without the TinyGo runtime. HP-GL/2 plots, Jw_cad drawings, DXF model space and SXF SFC drawings, binary and clear-text CGM are now served; SXF P21/P2Z, CGM cell arrays and hatches, large draw.io icon libraries and a full formula typesetting engine remain outside this port.

## Site

The published site, [https://f4ah6o.github.io/bdf.mbt/](https://f4ah6o.github.io/bdf.mbt/), is a Japanese-only rebuild of the upstream BDF site ([shibukawa.github.io/bdf](https://shibukawa.github.io/bdf/)) in which every conversion and every drawing is bdf.mbt: the JavaScript build behind the viewer and the two Workers, and the wasm-gc build behind the exports. No Go or TinyGo runtime, and no `@bdfkit/*` package, is loaded at runtime.

| Path | What it does |
|---|---|
| `/` | The upstream 20-page sample as BDF, drawn by bdf.mbt; the same document written back to PDF, Markdown and search text (wasm-gc); MiniSearch over the page records; upstream's benchmark numbers with bdf.mbt's appended; the gallery |
| `/viewer/` | Drops a local file, converts it in the converter Worker (BDF, CSV, XLSX, DOCX, PPTX, image, font, AI, TIFF, PSD, EMF/WMF, IDML, Visio, HTML, Markdown, draw.io, Parquet, HP-GL/2, Jw_cad, DXF, SXF, CGM, audio, and a checked PDF subset including encrypted PDFs — the sample password is `demo`) and draws it with the rendering Worker |
| `/thumbnail/` | Thumbnails of the first page at four sizes, drawn with bdf.mbt and cropped or fitted the way upstream's `thumbnail` package does |
| `/text/` | The page records a search index wants, from the wasm-gc build |
| `/wasm-gc.html` | PDF→BDF and the same exports through WebAssembly GC |
| `/docs/` | The upstream Japanese documentation, adapted where bdf.mbt differs |

```sh
npm run build:site      # moon build (js, wasm-gc) and node site/build.mjs
npm run test:site       # Playwright over the built site, then the link checker
npm run test:previews   # the gallery previews and the sample checksums
npm run bench:site      # writes site/benchmarks/bdfmbt.json
npm run bench:upstream  # refreshes upstream's numbers in site/benchmarks/upstream.json
```

The benchmark section keeps upstream's published measurements (LibreOffice + Poppler against BDF's Go converters, with their methodology and date) and appends bdf.mbt's own, measured in Chromium by `site/benchmark.mjs`: Office conversion through the converter Worker, and the round trip in both the JavaScript and the wasm-gc build. The memory and energy charts stay upstream's alone, because a browser tab cannot measure what those numbers mean.

`site/docs-src/` holds the Japanese pages taken from upstream (`*.md`, MIT, listed with their commit in `site/docs-src/UPSTREAM-COMMIT`) and the two pages written for bdf.mbt (`api.md`, `licenses.md`). `site/build.mjs` renders them to `_build/pages/docs/`; each page names its source and says where bdf.mbt differs. `site/home.mjs` builds the top page, `site/nav.mjs` the sidebar, and `site/assets/` the stylesheet (upstream's, MIT) and the page scripts.

Publishing is a separate manual workflow: `.github/workflows/pages-deploy.yml`.
It is `workflow_dispatch` only, has no test or quality-check steps, and runs
only when a maintainer dispatches it after the deployment is separately
authorized. The local verification flow never runs it, never uploads a Pages
artifact and never publishes the site. Branch protection may still require the
old check names, so a pull request can stay blocked until the protection rules
are updated.

## Compatibility checks

The visual test compares the same BDF fixture with the upstream `@bdfkit/render`
and this library in Chromium at three viewport widths. It verifies that both
pages finish rendering and that their captured pixels differ by at most 0.05%
of the visible document area. The tests also compare text extraction expectations against upstream. The tests also compare the AI, TIFF, PSD and EMF/WMF converters with upstream pages and decoded pixels through `compat/converter/phase1-test.mjs`. These fixtures do not cover all upstream features.

```sh
npm ci
npx playwright install chromium
# Provision the pinned XLSX oracle as described in compat/xlsx/oracle/README.md.
export BDF_XLSX_ORACLE_BUILD=/path/to/oracle-build
# Required outside native Linux ARM64:
export BDF_XLSX_ORACLE_EMULATOR=/path/to/approved/qemu-aarch64
npm run verify:local
```

`npm run verify:local` runs the CI, demo, parity, visual and site gates through
`actrun` in the current worktree. It uses the installed Node, MoonBit,
Playwright and Python toolchains and the existing `node_modules`, `.mooncakes`
and Chromium; it does not run `npm ci`, `moon update` or
`npx playwright install`. Missing prerequisites block the affected gate instead
of being skipped silently.
The visual gate checks the XLSX oracle build identity, binary, adapters and
runtime seeds before starting; outside native Linux ARM64 it also checks the approved
executable QEMU and its hash. Missing or invalid configuration blocks the gate
with exit code 2. See [XLSX oracle preparation](compat/xlsx/oracle/README.md)
for the pinned versions and offline build procedure.

The flow writes a manifest, a summary, per-gate logs, actrun run records and the
exact git state under `_scratch/local-verify/<utc>-<sha>[-dirty]/`. The manifest
records the fixed commit, the dirty-tree diff hashes, every command and the true
exit code. Exit codes are 0 for a passing run, 1 for a failed gate and 2 for a
blocked or incomplete run. A successful selected subset is `partial-pass`, not
a full pass. `npm run verify:local:plan` is a dry run: it writes a
`dry-run` manifest and never reports success.

GitHub never runs the four verification workflows. Their only trigger is `push` with
`branches-ignore: ['**']`, which matches no branch, and there is no
`workflow_dispatch`, `pull_request` or `schedule` trigger, so neither a push nor
a manual dispatch can start them. actrun 0.32.0 only accepts a `push` trigger
and ignores branch filters, so the local flow still runs them. The files stay in
`.github/workflows` because actrun uses the workflow's directory as the
workspace, and only `.github/workflows` resolves to the repository root. The
hosted runner image, `actions/checkout`,
`actions/setup-node`, `hustcer/setup-moonbit`, `npm ci`, `moon update`,
`npx playwright install --with-deps`, the Pages artifact upload and the Pages
deployment are not exercised locally. They are reported as hosted-only, not as
passes. The deployment workflow is the only workflow GitHub can run; the four
verification workflows are inert.

The porting scope excludes PCB/KiCad (KiCad PCB, Gerber, Excellon), musical
score (MIDI score, MML, MusicXML, music notation) and EPUB. Audio cards and
non-PCB CAD remain in scope. The excluded formats are no longer registered in
the converter Worker or included in the visual aggregate. Their source files
and fixtures are preserved as dormant assets.

The `ci/test` gate runs `.github/local/moon-test.mjs` and the tracked
`compat/retained-test.mjs` selector for retained packages. If the selector is
missing, the wrapper reports `retained-scope: pending` instead of claiming
retained coverage. The min-test-count floor is 2700. A bare `moon test` also
collects dormant packages. See [verification scope](docs/verification-scope.md)
for the format matrix, gate boundaries and measurement history.

Per-workflow shortcuts: `npm run verify:local:ci`, `verify:local:parity`,
`verify:local:visual`, `verify:local:site`, `verify:local:lint`,
`verify:local:self`. The `self-test` gate runs
`node --test .github/local/verify.test.mjs compat/retained-test.test.mjs`,
which covers package selection and status aggregation,
empty and skipped steps, missing prerequisites, the retained-scope marker and
the site server checks. If actrun is installed, a small temporary workflow also
checks that oracle environment variables reach its step; no browser is opened.
The older
`test:ci-local`, `test:pages-local`, `test:parity-local` and
`test:visual-local` names are aliases for the same gates. `npm run test:prepush`
now runs the full local flow; `npm run test:prepush:quick` keeps the previous
subset.

See [visual fixtures](compat/visual/README.md).

### Rendering Worker

Build the JavaScript target with `moon build --target js` and serve the generated `render_worker/render_worker.js` alongside `browser/browser.js`. Create a client with `bdf_create_render_worker(workerUrl)`, or wrap an existing Worker with `bdf_render_worker_client(worker)`. The client follows the upstream rendering Worker request API, including transferred buffers and main-thread SVG rasterization. Buffer, single URL and split URL sources are supported. Single URLs can use HTTP Range requests to load parts lazily, falling back to one whole-file download if the server ignores Range. Segmented sources use request-specific P-256 keys and fetch pages on demand. Worker open options control the image cache budget, the maximum image size, and the decoded-image limit for each render.

For sheet views, the client adds `sheetClipboard(view, range)`: an inclusive rectangular cell range `{ row0, col0, row1, col1 }` is copied as `{ text, html }` (TSV and an HTML table), with hidden rows and columns skipped, merged cells clipped to the range, and scope marks preserved as `th` cells. A merged cell keeps its text in the tile of its anchor while its span can cross any number of tiles, so a range is resolved against every tile of the view's tile table, exactly like the in-browser sheet clipboard; `cell_clipboard` then does the clipping. Each copy loads and extracts the tile objects on demand (once per distinct object, with split parts fetched lazily and kept in the document's part cache), so the work per request is bounded by the tile count of the view. Selections beyond 1,000,000 cells, sheets whose tile table exceeds 4,096 tiles (rejected with an explicit worker error rather than silently losing merged anchors), and ranges outside the sheet are rejected as worker errors, as are results whose serialized text and HTML together exceed 8,388,608 UTF-16 code units; that limit counts `String.length()` code units of the finished serialization, not bytes, and is only checked after both strings are built. The public `bdf.mbt` npm package exports the client (`bdf_render_worker_client`) from its `.` entry and the Worker module from `./workers/render`, but the published releases to date (latest `2026.11.2`) predate this extension: their clients have no `sheetClipboard` method until the next release, and the generated `browser.d.ts` types the client as `any`, so the request keeps no TypeScript signature even then. This request is a bdf.mbt extension; the upstream rendering Worker does not provide it. Run `npm run test:render-worker-clipboard` (or `node compat/render_worker/clipboard-test.mjs`, `node compat/render_worker/merge-clipboard-test.mjs` and `node compat/render_worker/tile-cap-clipboard-test.mjs` individually) after `moon build browser render_worker --target js`: the first covers the request contract, the second covers merged spans wider than one tile for buffer, split and password-encrypted sources, and the third covers the 4,096-tile cap on a 4,097-tile sheet, which must be rejected before any tile object part is loaded.

### Worker-backed viewer

`new Viewer(host, options)` (or `bdf_create_viewer(host, options)`) creates a browser viewer backed by the rendering Worker. It supports page and sheet display, layout and zoom controls, lightbox mode, search, and streaming conversion through a supplied converter. Pass `options.renderer` to use an existing client, or `options.workerUrl` to choose the Worker module. See [browser usage](docs/browser.md). `compat/viewer/api-test.mjs` compares its API surface and core behavior with `@bdfkit/viewer`; module-load prototype population, subclassing and constructor edge cases remain documented gaps in `compat/viewer`.


## License

MIT; see [LICENSE](LICENSE). This port adapts code and fixtures from [shibukawa/bdf](https://github.com/shibukawa/bdf), licensed under [MIT](licenses/Shibukawa-bdf.txt). The raw DEFLATE implementation and the adapted SHA-256 implementation are supplied by [gaato/deflate](https://github.com/gaato/codecs.mbt), licensed under [Apache-2.0](licenses/Apache-2.0.txt); XMP parsing uses Apache-2.0 licensed [Milky2018/xml](https://github.com/moonbit-community/xml-mbt); browser Promise integration uses Apache-2.0 licensed [moonbitlang/async](https://github.com/moonbitlang/async). CSV decoding uses Apache-2.0 licensed [LL728/moon_encoding](https://github.com/LL728/moon_encoding), whose character tables incorporate [WHATWG Encoding data](licenses/WHATWG-Encoding.txt), and adapts algorithms from [golang.org/x/text](licenses/Go-x-text.txt). MIDI lyric handling uses Unicode tables from the [Go standard library](licenses/Go-x-text.txt). Adjustable arc calculations adapt Go standard library math code, including an approximation from the [Cephes Math Library](licenses/Cephes.txt). Markdown block and inline parsing uses [oilleelssq-wq/moonmarkdown](https://github.com/oilleelssq-wq/moonmarkdown) (MIT); the LaTeX linearizer and scroll layout are part of this port.

Music symbols use Bravura, distributed under the [SIL Open Font License](licenses/Bravura-OFL.txt).

PDF character maps include Adobe CMap data under the [Adobe CMap license](licenses/Adobe-CMap.txt).
PDF stream filters adapt [pdfcpu](https://github.com/pdfcpu/pdfcpu) code under the [Apache License 2.0](licenses/Apache-2.0.txt) and its Go-derived LZW decoder under the [Go BSD license](licenses/Go-x-text.txt). PDF CCITT fax decoding adapts [golang.org/x/image/ccitt](https://pkg.go.dev/golang.org/x/image/ccitt) under the [Go BSD license](licenses/Go-x-image.txt). PDF JPEG 2000 decoding adapts [trkbt10/jpeg2000](https://github.com/trkbt10/jpeg2000_mbt) under the [Apache License 2.0](convert/pdf/jpx/LICENSE).

Font test fixtures include STIX Two Text, distributed under the [SIL Open Font License](compat/font/fixtures/OFL.txt); see [font fixture notes](compat/font/README.md).
