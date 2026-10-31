# bdf.mbt

MoonBit implementation of the BDF v1 wire-format reader and the browser-facing `@bdfkit/render`, `@bdfkit/convert`, and `@bdfkit/viewer` control layers.

- Targets: `js` and `wasm-gc`.
- `core`: checked BDF header, single and split documents (identity and deflate-raw), document writing and encryption assembly, BOBJ resource tables, MIDI sequences, cue indexes, and a bounded binary reader.
- `render`: backend-neutral, checked display-list decoder for a currently supported subset of Canvas 2D opcodes, including paths, gradient paints, and drawing effects. It also extracts ordered text runs, semantic structure, figure bounds and link rectangles, serializes table-cell selections, calculates music and audio cue positions, and plans shared page-body prefixes.
- `convert`: the worker-client request/response lifecycle and stream command model. The browser adapter connects these to a Worker and a separately supplied compatible Wasm runtime; the native converter supports MIDI, MML, CSV, a limited XLSX subset, font specimens, a checked PDF subset, a limited DOCX text subset, a limited PPTX shape/text subset, and the BMP, ICO, JPEG, PNG, GIF, WebP, AVIF and SVG image formats. Other converter engines remain to be ported.
- `convert/midi`, `convert/mml` and `convert/music`: MIDI, RIFF MIDI and MML parsing, score notation, estimated guitar TAB views, BDF page rendering, playback sequences and position cues.
- `convert/font`: SFNT/TTC, WOFF and WOFF2 font specimen conversion to BDF, including overview, character charts, glyph grids, OpenType feature examples, collection face selection and text indexes. Embedded programs use WOFF2 by default, with an option to retain SFNT.
- `convert/csv`: CSV decoding, detection and conversion to BDF sheets, including built-in table styles, text indexes and typed Parquet tables. The converter accepts an explicitly supplied font or an in-memory font database, selecting fallback faces per character, subsetting TrueType and supported CFF outlines where permitted, and embedding WOFF2 by default. Host filesystem and system font discovery remain to be ported.
- `convert/pdf`, `convert/docx` and `convert/pptx`: the PDF path is public and Worker-backed. It covers object parsing, page trees, graphics, simple and composite text, metadata, text indexes, shared page prefixes, JPEG image XObjects and inline images, 8-bit Flate sample images in Gray, RGB and CMYK, 1-bit stencil image masks, stencil and colour-key `/Mask` attachments, 8-bit grayscale `/SMask` attachments, form XObjects with their resources, matrix, bounding box and transparency groups, axial/radial shadings with exponential or stitching functions, shading patterns, URI link annotations, optional-content layer visibility, annotation `/AP /N` appearance streams and state dictionaries, and embedded TrueType/OpenType font programs from `/FontFile2` or `/FontFile3` OpenType. Tiling patterns, bare Type1/CFF font programs, encoded images with masks, JPX/JBIG2/CCITT images, form-field actions and encryption are not yet implemented. Tagged structure is ignored for visual rendering. The DOCX path also exposes a limited text converter with approximate metrics; table rows are flattened to tab-separated text on grid tab stops, inline PNG/JPEG drawings are embedded, decimal/bullet numbering is prefixed, and default, first-page and even-page header/footer text is drawn; header images, numbering overrides and floating/EMF/WMF drawings remain unsupported. The PPTX path exposes a limited slide shape/text converter with solid slide backgrounds, embedded pictures, theme colour schemes with luminance/tint/shade modifiers, theme major/minor fonts, paragraph default run properties, layout/master backgrounds and non-placeholder decorations, placeholder transform and default run-format inheritance, table text flattening and translated group shapes; charts and group rotation/scaling remain unsupported.
- `font/sfnt`: TrueType, OpenType and TTC face metadata, Unicode glyph maps and horizontal metrics, WOFF 1.0 decoding, and glyph and sample font programs for font specimens. TrueType and CFF specimen pruning compute the GSUB substitution closure, or accepts an explicitly supplied one. `font/db` resolves supplied font families, styles and per-character fallbacks; `convert/sheet` can draw using those faces. `font/woff2` decodes and encodes WOFF2; its encoder uses the glyf transform when possible and its Brotli output differs from upstream.
- `viewer`: document/view selection state and page placement in single, spread, and continuous modes, including RTL spreads and scroll strips.
- `browser` (JS only): Canvas 2D adapter that draws fixed/flow pages, scroll strips, continuous body regions, and sheet viewports, including password- and P-256-protected documents, into a DOM host, including paths, gradients, child objects, transparency groups, masks, asynchronously loaded images and fonts, and optional selectable text layers.

This is an **incremental port**, not a feature-equivalent replacement for the upstream npm packages. In particular, a full DOM viewer, wasm-gc cryptography, some interactive sheet features and the public PDF/Office/CAD converter engines remain incomplete. Unsupported drawing opcodes fail explicitly instead of silently rendering incorrectly.

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

The native converter Worker supports MIDI, MML, CSV, TSV and font specimens with the same no-system-font fallback used by the upstream browser build, including the 60 built-in Excel table styles. A font directory URL can supply `index.json` and TrueType/OpenType files; the native Worker currently fetches indexed font files in full rather than using upstream's range requests. The Worker also converts a limited XLSX subset using estimated font metrics without embedding fonts. Format selection supports explicit `midi`, `mml`, `csv`, `xlsx` and `font`, registered filename extensions, and content detection. MIDI and MML options include time and key overrides and a TAB switch; MML also accepts dialect, octave direction and program options.

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

1. Complete the opset 1 Canvas command decoder and browser Canvas renderer, and safe resource loading.
2. Cryptography support on non-JavaScript hosts.
3. MoonBit converter engines and viewer openFile integration for streaming page conversion.
4. DOM/OffscreenCanvas viewer, lazy page rendering, sheet support, search, accessibility and music playback.
5. Replace or separately port TinyGo converter engines for the desired document formats.

## Browser demo

The [browser demo](https://f4ah6o.github.io/bdf.mbt/) ([source](demo/README.md)) displays the upstream 20-page sample
and supports local BDF, CSV, XLSX, a limited DOCX text subset, a limited PPTX shape/text subset, image, font and a checked PDF subset using the MoonBit JavaScript build.
The repository's Pages publishing source must be configured before the
`Demo pages` workflow can publish it.

## Compatibility checks

The visual test compares the same BDF fixture with the upstream `@bdfkit/render`
and this library in Chromium at three viewport widths. It verifies that both
pages finish rendering and that their captured pixels differ by at most 0.05%
of the visible document area. The tests also compare text extraction expectations against upstream. These fixtures do not cover all upstream features.

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

`new Viewer(host, options)` (or `bdf_create_viewer(host, options)`) creates a browser viewer backed by the rendering Worker. It supports page and sheet display, layout and zoom controls, lightbox mode, search, and streaming conversion through a supplied converter. Pass `options.renderer` to use an existing client, or `options.workerUrl` to choose the Worker module. See [browser usage](docs/browser.md). The viewer port is still being validated against the full upstream behavior and API.


## License

MIT; see [LICENSE](LICENSE). This port adapts code and fixtures from [shibukawa/bdf](https://github.com/shibukawa/bdf), licensed under [MIT](licenses/Shibukawa-bdf.txt). The raw DEFLATE implementation and the adapted SHA-256 implementation are supplied by [gaato/deflate](https://github.com/gaato/codecs.mbt), licensed under [Apache-2.0](licenses/Apache-2.0.txt); XMP parsing uses Apache-2.0 licensed [Milky2018/xml](https://github.com/moonbit-community/xml-mbt); browser Promise integration uses Apache-2.0 licensed [moonbitlang/async](https://github.com/moonbitlang/async). CSV decoding uses Apache-2.0 licensed [LL728/moon_encoding](https://github.com/LL728/moon_encoding), whose character tables incorporate [WHATWG Encoding data](licenses/WHATWG-Encoding.txt), and adapts algorithms from [golang.org/x/text](licenses/Go-x-text.txt). MIDI lyric handling uses Unicode tables from the [Go standard library](licenses/Go-x-text.txt). Adjustable arc calculations adapt Go standard library math code, including an approximation from the [Cephes Math Library](licenses/Cephes.txt).

Music symbols use Bravura, distributed under the [SIL Open Font License](licenses/Bravura-OFL.txt).

PDF character maps include Adobe CMap data under the [Adobe CMap license](licenses/Adobe-CMap.txt).
PDF stream filters adapt [pdfcpu](https://github.com/pdfcpu/pdfcpu) code under the [Apache License 2.0](licenses/Apache-2.0.txt) and its Go-derived LZW decoder under the [Go BSD license](licenses/Go-x-text.txt).

Font test fixtures include STIX Two Text, distributed under the [SIL Open Font License](compat/font/fixtures/OFL.txt); see [font fixture notes](compat/font/README.md).
