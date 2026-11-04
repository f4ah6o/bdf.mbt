# bdf.mbt

MoonBit implementation of the BDF v1 wire-format reader and the browser-facing `@bdfkit/render`, `@bdfkit/convert`, and `@bdfkit/viewer` control layers.

- Targets: `js` and `wasm-gc`.
- `core`: checked BDF header, single and split documents (identity and deflate-raw), document writing and encryption assembly, BOBJ resource tables, MIDI sequences, cue indexes, and a bounded binary reader.
- `render`: backend-neutral, checked display-list decoder for every opset 1 Canvas 2D opcode, including paths, gradient paints, and drawing effects. It also extracts ordered text runs, semantic structure, figure bounds and link rectangles, serializes table-cell selections, calculates music and audio cue positions, and plans shared page-body prefixes.
- `convert`: the worker-client request/response lifecycle and stream command model. The browser adapter connects these to a Worker and a separately supplied compatible Wasm runtime; the native converter supports MIDI, MML, MusicXML, CSV, styled XLSX worksheets and chart sheets, font specimens, a checked PDF subset including Type 1 font conversion, Illustrator artboards through that PDF path, DOCX flow/scroll text layout, PPTX slides with master/layout layers, IDML through an approximate shared text-flow engine, Visio VSDX, EPUB (reflowable and picture-only fixed layout), HTML reader mode, Markdown scroll views, audio cards, TIFF, Photoshop, EMF/WMF, HP-GL/2 and HP-GL plots, Jw_cad drawings, text and binary DXF drawings, SXF SFC drawings, CGM, single-file Gerber and simple Excellon drill files, a KiCad PCB front view, draw.io diagrams including compressed/SVG/PNG exports, Parquet tables, and the BMP, ICO, JPEG, PNG, GIF, WebP, AVIF and SVG image formats. SXF P21/P2Z, clear-text CGM, KiCad schematics and back/layer views, Gerber board archives, the large draw.io stencil tables, and PCL/HP RTL raster jobs remain explicit gaps.
- `convert/midi`, `convert/mml`, `convert/musicxml` and `convert/music`: MIDI, RIFF MIDI, MML and MusicXML (including MXL archives) parsing, score notation, estimated guitar TAB views, BDF page rendering, playback sequences and position cues.
- `convert/font`: SFNT/TTC, WOFF and WOFF2 font specimen conversion to BDF, including overview, character charts, glyph grids, OpenType feature examples, collection face selection and text indexes. Embedded programs use WOFF2 by default, with an option to retain SFNT.
- `convert/csv`: CSV decoding, detection and conversion to BDF sheets, including built-in table styles, text indexes and typed Parquet tables. The converter accepts an explicitly supplied font or an in-memory font database, selecting fallback faces per character, subsetting TrueType and supported CFF outlines where permitted, and embedding WOFF2 by default. Host filesystem and system font discovery remain to be ported.
- `convert/xlsx`: OOXML workbooks with shared and inline strings, styles and number formats, merges, row/column geometry, hidden rows/columns, print areas, conditional formats, tables, hyperlinks, comments, embedded pictures, worksheet drawings, charts and chart sheets. The plain renderer emits sheet tiles and fixed chart-sheet pages with upstream text indexes, summaries and warnings; shape text wraps to its box, and the Worker adds the no-font warning and embedded-font count. Remaining gaps are documented in `compat/xlsx`: colour scales, data bars and icon sets are painted, embedded charts are SVG pictures while their labels are in the text index, and complex borders and exact number-format run segmentation are incomplete; the 8x8 pattern fills match upstream.
- `convert/pdf`, `convert/docx` and `convert/pptx`: the PDF path is public and Worker-backed. It covers object parsing, page trees, graphics, simple and composite text, metadata, text indexes, shared page prefixes, JPEG image XObjects and inline images, CCITT G3/G4 image XObjects and inline images, 8-bit Flate sample images in Gray, RGB and CMYK, 1-bit stencil image masks, stencil and colour-key `/Mask` attachments, 8-bit grayscale `/SMask` attachments, form XObjects with their resources, matrix, bounding box and transparency groups, axial/radial shadings with exponential or stitching functions, shading patterns, URI link annotations and URI actions inherited from form fields, optional-content layer visibility, annotation `/AP /N` appearance streams and state dictionaries, tiling patterns, encoded image masks (including ExtGState soft masks) for DCT, JPX and JBIG2 image data, JPX JPEG 2000 images, JBIG2 images (generic arithmetic and MMR regions, symbol dictionaries, text regions and halftone), Type3 glyph procedures, and embedded TrueType/OpenType font programs from `/FontFile2` or `/FontFile3` OpenType. The PDF standard security handler supports revisions 2, 3, 4, 5 and 6 (RC4 40/128-bit, AES-128 and AES-256); colour-key masks on JPX/JBIG2-encoded images are decoded and applied, while DCT colour-key masks fail with explicit errors; encrypted BDF single-file documents unlock with a password or P-256 key; embedded bare CFF programs are wrapped as OpenType; unsupported Type1 programs fall back to system fonts with a warning. Tagged structure is ignored for visual rendering. PDF, DOCX and PPTX conversions accept a `pages` selection and return only the requested pages. The PDF converter also accepts `kind=flow` to mark its pages as a flow view with full-page body rectangles, and `box=media|bleed|trim|art` to choose the page box. The DOCX path lays text out into the upstream pair of views: a `flow` page view with separate header, footer and body layers and body rectangles, and a page-free `scroll` view cut into strips (the `views=pages|scroll|both` option selects them). It reads settings, theme fonts, core metadata, hyperlinks, fields and Office Math (linearized for search), accepts footnotes/endnotes (their bodies are laid out above the footer and appended to the scroll view), and carries layer-aware text indexes. Real table cells are laid out with cell paragraphs, wrapping, grid and row spans, borders and fills, vertical alignment, row splitting and repeated header rows; `w:cols` columns, column breaks, vertical section bodies, PAGE/NUMPAGES regeneration, table widths (`w:tblW` dxa/pct) scaling the grid, header/footer images and numbering overrides are implemented. Paragraph shading and borders, page borders in a background layer, keepLines/widowControl/keepNext, text boxes, inline PNG/JPEG/EMF/WMF drawings with crops/rotation/flips, anchored drawings (floating left/right/top-and-bottom wrap and behind/in-front z-order) and first/even-page headers are supported. Exact font metrics and shaping, tight/through wrap contours and effect extents, exact footnote separator/continuation indent, upright CJK glyphs in vertical text, tables in headers/footers, PAGEREF/REF, table-style base, first/last row/column, banded row/column and corner-cell parts (borders/shading/margins/text formatting; TableGrid is applied) and the exact number of scroll strips remain documented gaps; autofit tables estimate text widths from run sizes.
The PPTX path emits the upstream `slides` fixed view with background, layout, master and body layers; master, layout and background objects are shared between slides. It renders solid, image and linear-gradient backgrounds, embedded pictures with alpha, source-rectangle cropping, rotation and flips, rectangle/rounded-rectangle/ellipse fill and stroke, line arrowheads (triangle/stealth/diamond/oval/arrow), theme colour schemes with luminance/tint/shade modifiers and theme major/minor fonts, placeholder inheritance by `idx` then type (transform, text chain and list styles), bullets (`buChar`/`buAutoNum`/`buBlip` with `buClr` and `buSzPct`/`buSzPts`), levels and indents, paragraph/line spacing, text-box insets/anchors, word and CJK wrapping with paragraph/line/wrap marks, vertical text, table cell text with spans/borders/fills, the 74 built-in table-style fills/bands/text with Medium-Style-2 borders, bar/line/pie/area/scatter/radar/stacked charts with legends, axis titles, category, value (`dLbls`) and percentage labels, translated/scaled/rotated group shapes, and Office Math (`a14:m`) linearized for search instead of fallback pictures. Its text index matches upstream page for page. Preset geometries are generated from the upstream table (187 presets) and unknown presets warn and fall back to a rectangle; placeholder fill/line inheritance follows slide → layout → master with `p:style` theme references, and a supplied font database embeds subset WOFF2 faces with real metrics. Custom geometry is supported (arcTo is flattened to cubic Béziers); SmartArt/ink, 3D, other non-bar/line/pie/area/scatter/radar charts and advanced vertical stacking remain documented gaps; chart titles use an explicit `c:title`, falling back to the series name for a single-series chart, and bar/line/pie charts with `c:dTable` draw a category/series/value table honouring the show and border flags.
- `convert/raster`, `convert/tiff`, `convert/psd`, `convert/ai`, `convert/metafile` and `convert/emf`: PNG encoding, box-filter scaling and raster page assembly; classic TIFF and BigTIFF with strips and tiles, None, PackBits, LZW, Deflate and CCITT G3/G4 compression, 1–16-bit bilevel, grey, palette, RGB and CMYK samples, alpha and orientation; Photoshop PSD/PSB composite images, colour modes, artboards and XMP metadata; Illustrator artwork through the PDF converter with artboard trim boxes and placeholder detection; and EMF/WMF replay (GDI state, lines, polygons, rectangles, ellipses, rounded rectangles, text, bitmaps and hatch-colour fallback) for standalone pictures and for DOCX/PPTX drawings. TIFF JPEG compression and YCbCr pages, PSD layer compositing when a file has no composite, metafile paths/clipping and EMF+ only files are explicit gaps; unsupported pages fail or warn instead of being drawn incorrectly.
- `convert/drawingml`, `convert/idml` and `convert/visio`: the shared approximate DrawingML text layout (line breaking, alignment and multi-frame story flow) used by IDML; InDesign Markup packages (spreads and master spreads, page geometry, layers, path shapes, solid fills and strokes, first-stop gradient colours, embedded raster images, stories, threaded story flow and text indexes); and Visio 2013+ VSDX drawings with their own approximate text layout (page sheets, foreground/background pages, masters, layers, ShapeSheet geometry, solid fills/strokes, text and text indexes). Exact font metrics and shaping, linked IDML images, IDML page-number markers and table stories, and Visio theme quick styles, shadows, hyperlinks and pictures are documented gaps.
- `convert/reader`, `convert/epub`, `convert/html` and `convert/markdown`: the reader-mode block model (A4 pages for HTML, A5 book pages for EPUB); EPUB container/spine chapter extraction and picture-only fixed-layout (pre-paginated) pages at their viewport size and reading direction; HTML reader text (headings, lists, code, quotes, tables). Markdown uses a pure-MoonBit CommonMark/GFM parser and produces the same 504-point scroll view as upstream: nested ordered/unordered lists and tasks, quotes, fenced and indented code, tables with alignments, raw HTML, links, image alternative text, footnotes, definition lists, YAML/TOML front matter, and `$...$`/`$$...$$` formulas and math code fences linearized to searchable text. The converter accepts `width` (the scroll column width in points), `size`, `font`, `mono` and `views` (`scroll|pages|both`) options; the default column is 36 ems at 12 points, the same 504-point strip upstream emits, and `pages` paginates into A4-like fixed pages. Views emit heading, paragraph, figure, list, table and cell marks plus link rectangles. Inline SVG and data-URI images are drawn as image parts (including sprite-sheet defs), while unresolved relative/remote images keep their alternative text and a warning. Long tables split across pages row by row with their header repeated, and quote bars repeat on every page; remote fetching, MARK structure and exact metrics remain documented gaps; sprite sheets may span multiple lines. Readability extraction, CSS, vertical writing, non-picture fixed-layout EPUB, MHTML, embedded fonts and exact HTML reader-mode parity are documented gaps.
- `convert/audio`: one-page audio cards for MP3, AAC (ADTS and M4A), FLAC, Ogg Vorbis/Opus, WAV and AIFF: multi-value ID3v2/v1 tags, synchronized lyrics (SYLT), chapters (CHAP), APIC covers, RIFF INFO and ID3 chunks, AIFF text with 80-bit sample rates, FLAC Vorbis comments and pictures, Ogg Vorbis/Opus comments, METADATA_BLOCK_PICTURE covers and granule durations, MP4/iTunes metadata, cover art and chapters, Dublin Core metadata, lyrics/chapter card sections and the browser-playable audio part. DRM handling, ID3v2.2 tags, compressed ID3 frames, QuickTime `chpl` v1 chapters and Ogg FLAC/Speex remain documented gaps.
- `font/sfnt`: TrueType, OpenType and TTC face metadata, Unicode glyph maps and horizontal metrics, WOFF 1.0 decoding, and glyph and sample font programs for font specimens. TrueType and CFF specimen pruning compute the GSUB substitution closure, or accepts an explicitly supplied one. `font/db` resolves supplied font families, styles and per-character fallbacks; `convert/sheet` can draw using those faces. `font/woff2` decodes and encodes WOFF2; its encoder uses the glyf transform when possible and its Brotli output differs from upstream.
- `viewer`: document/view selection state and page placement in single, spread, and continuous modes, including RTL spreads and scroll strips.
- `browser` (JS only): Canvas 2D adapter that draws fixed/flow pages, scroll strips, continuous body regions, and sheet viewports, including password- and P-256-protected documents, into a DOM host, including paths, gradients, child objects, transparency groups, masks, asynchronously loaded images and fonts, and optional selectable text layers.

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

The native converter Worker dispatches CSV/TSV, XLSX, DOCX, PPTX, font, MIDI, MML, PDF, image, AI, TIFF, PSD, EMF/WMF, IDML, Visio, Markdown, HTML, EPUB, audio, HP-GL/2, Jw_cad, DXF, SXF SFC, CGM, Gerber/Excellon, KiCad PCB, draw.io and Parquet conversions without a Go runtime, including the same no-system-font fallback used by the upstream browser build and the 60 built-in Excel table styles. A font directory URL can supply `index.json` and TrueType/OpenType files; the native Worker currently fetches indexed font files in full rather than using upstream's range requests. When a font directory is supplied, XLSX embeds the first face and uses its cell metrics, otherwise it uses estimated metrics without embedding fonts. Format selection supports explicit format names, registered filename extensions and content detection. MIDI and MML options include time and key overrides and a TAB switch; MML also accepts dialect, octave direction and program options.

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
5. ~~Replace or separately port TinyGo converter engines for the desired document formats.~~ Done for the current phase: MoonBit engines cover the demo format set—PDF, DOCX, PPTX, XLSX, CSV, image, font, MIDI, MML, HP-GL/2, Jw_cad, DXF (text and binary), SXF SFC, CGM, Gerber, KiCad PCB, draw.io, Parquet, AI, TIFF, PSD, EMF/WMF, IDML, Visio, EPUB, HTML, Markdown and audio—and the native converter Worker serves them without the TinyGo runtime. MusicXML has a parser but is not wired into the Worker. HP-GL/2 plots, Jw_cad drawings, DXF model space and SXF SFC drawings, binary CGM and single-file Gerber are now served; SXF P21/P2Z, clear-text CGM, Gerber board archives, full Excellon headers, KiCad schematics/back and layer views, large draw.io icon libraries and a full formula typesetting engine remain outside this port.

## Browser demo

The [browser demo](https://f4ah6o.github.io/bdf.mbt/) ([source](demo/README.md)) displays the upstream 20-page sample
and supports local BDF, CSV, XLSX, DOCX flow/scroll text layout, PPTX slides with master/layout layers, image, font, AI, TIFF, PSD, EMF/WMF, IDML, Visio, EPUB, HTML, Markdown, draw.io, Parquet and a checked PDF subset including Type 1 font conversion using the MoonBit JavaScript build. The PDF section includes encrypted-password retry and a feature showcase for tiling patterns, JPX/JBIG2 images and Type3 glyphs; the encrypted sample password is `demo`.
The same page now writes the displayed BDF back to PDF (embedded fonts and
links), Markdown, and the upstream page-record JSON used by search, and indexes
those records with MiniSearch. A [wasm-gc demo](https://f4ah6o.github.io/bdf.mbt/wasm-gc.html)
runs PDF→BDF and the same exports in WebAssembly GC. The benchmark section
places the upstream BDF (Go) CLI next to bdf.mbt's JavaScript and wasm-gc
medians on the same 20-page BDF and its 20-page source PDF; the table is
generated by `npm run bench:demo` and `npm run bench:upstream`. The PDF writer
approximates gradients with a solid stop and still omits masks, filters, images
and tagged structure; those limits are reported as warnings in the page.
The repository's Pages publishing source must be configured before the
`Demo pages` workflow can publish it.

## Compatibility checks

The visual test compares the same BDF fixture with the upstream `@bdfkit/render`
and this library in Chromium at three viewport widths. It verifies that both
pages finish rendering and that their captured pixels differ by at most 0.05%
of the visible document area. The tests also compare text extraction expectations against upstream. The tests also compare the AI, TIFF, PSD and EMF/WMF converters with upstream pages and decoded pixels through `compat/converter/phase1-test.mjs`. These fixtures do not cover all upstream features.

```sh
npm ci
npx playwright install chromium
npm run test:visual
npm run test:ci-local
```

The last command uses `actrun` to execute the MoonBit workflow in a temporary
workspace. It skips checkout and MoonBit setup and uses the locally installed
`moon`; the GitHub Actions setup steps and hosted Linux environment are not
validated by that local run. See [visual fixtures](compat/visual/README.md).

### Rendering Worker

Build the JavaScript target with `moon build --target js` and serve the generated `render_worker/render_worker.js` alongside `browser/browser.js`. Create a client with `bdf_create_render_worker(workerUrl)`, or wrap an existing Worker with `bdf_render_worker_client(worker)`. The client follows the upstream rendering Worker request API, including transferred buffers and main-thread SVG rasterization. Buffer, single URL and split URL sources are supported. Single URLs can use HTTP Range requests to load parts lazily, falling back to one whole-file download if the server ignores Range. Segmented sources use request-specific P-256 keys and fetch pages on demand. Worker open options control the image cache budget, the maximum image size, and the decoded-image limit for each render.

### Worker-backed viewer

`new Viewer(host, options)` (or `bdf_create_viewer(host, options)`) creates a browser viewer backed by the rendering Worker. It supports page and sheet display, layout and zoom controls, lightbox mode, search, and streaming conversion through a supplied converter. Pass `options.renderer` to use an existing client, or `options.workerUrl` to choose the Worker module. See [browser usage](docs/browser.md). `compat/viewer/api-test.mjs` compares its API surface and core behavior with `@bdfkit/viewer`; module-load prototype population, subclassing and constructor edge cases remain documented gaps in `compat/viewer`.


## License

MIT; see [LICENSE](LICENSE). This port adapts code and fixtures from [shibukawa/bdf](https://github.com/shibukawa/bdf), licensed under [MIT](licenses/Shibukawa-bdf.txt). The raw DEFLATE implementation and the adapted SHA-256 implementation are supplied by [gaato/deflate](https://github.com/gaato/codecs.mbt), licensed under [Apache-2.0](licenses/Apache-2.0.txt); XMP parsing uses Apache-2.0 licensed [Milky2018/xml](https://github.com/moonbit-community/xml-mbt); browser Promise integration uses Apache-2.0 licensed [moonbitlang/async](https://github.com/moonbitlang/async). CSV decoding uses Apache-2.0 licensed [LL728/moon_encoding](https://github.com/LL728/moon_encoding), whose character tables incorporate [WHATWG Encoding data](licenses/WHATWG-Encoding.txt), and adapts algorithms from [golang.org/x/text](licenses/Go-x-text.txt). MIDI lyric handling uses Unicode tables from the [Go standard library](licenses/Go-x-text.txt). Adjustable arc calculations adapt Go standard library math code, including an approximation from the [Cephes Math Library](licenses/Cephes.txt). Markdown block and inline parsing uses [oilleelssq-wq/moonmarkdown](https://github.com/oilleelssq-wq/moonmarkdown) (MIT); the LaTeX linearizer and scroll layout are part of this port.

Music symbols use Bravura, distributed under the [SIL Open Font License](licenses/Bravura-OFL.txt).

PDF character maps include Adobe CMap data under the [Adobe CMap license](licenses/Adobe-CMap.txt).
PDF stream filters adapt [pdfcpu](https://github.com/pdfcpu/pdfcpu) code under the [Apache License 2.0](licenses/Apache-2.0.txt) and its Go-derived LZW decoder under the [Go BSD license](licenses/Go-x-text.txt). PDF CCITT fax decoding adapts [golang.org/x/image/ccitt](https://pkg.go.dev/golang.org/x/image/ccitt) under the [Go BSD license](licenses/Go-x-image.txt). PDF JPEG 2000 decoding adapts [trkbt10/jpeg2000](https://github.com/trkbt10/jpeg2000_mbt) under the [Apache License 2.0](convert/pdf/jpx/LICENSE).

Font test fixtures include STIX Two Text, distributed under the [SIL Open Font License](compat/font/fixtures/OFL.txt); see [font fixture notes](compat/font/README.md).
