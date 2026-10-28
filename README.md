# bdf.mbt

MoonBit implementation of the BDF v1 wire-format reader and the browser-facing `@bdfkit/render`, `@bdfkit/convert`, and `@bdfkit/viewer` control layers.

- Targets: `js` and `wasm-gc`.
- `core`: checked BDF header, single and split documents (identity and deflate-raw), BOBJ resource tables, MIDI sequences, cue indexes, and a bounded binary reader.
- `render`: backend-neutral, checked display-list decoder for a currently supported subset of Canvas 2D opcodes, including paths, gradient paints, and drawing effects. It also extracts ordered text runs, semantic structure, figure bounds and link rectangles, serializes table-cell selections, and calculates music and audio cue positions.
- `convert`: the worker-client request/response lifecycle and stream command model. Converter runtime itself (TinyGo) is **not** ported.
- `viewer`: document/view selection state and page placement in single, spread, and continuous modes, including RTL spreads and scroll strips.
- `browser` (JS only): Canvas 2D adapter that draws fixed/flow pages, scroll strips, continuous body regions, and sheet viewports, including password- and P-256-protected documents, into a DOM host, including paths, gradients, child objects, transparency groups, masks, asynchronously loaded images and fonts, and optional selectable text layers.

This is an **incremental port**, not a feature-equivalent replacement for the upstream npm packages. In particular, a full DOM viewer, wasm-gc cryptography, some interactive sheet features, browser Worker transport and PDF/Office/CAD decoders are not yet implemented. Unsupported drawing opcodes fail explicitly instead of silently rendering incorrectly.

Upstream implementation: https://github.com/shibukawa/bdf (MIT). Wire specification: https://github.com/shibukawa/bdf/blob/main/docs/spec.md .

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
let header = @core.parse_header(bdf_bytes)
let document = @core.open_single(bdf_bytes) // unencrypted BDF
let object = @core.decode_object(document.part(hash))
let commands = @render.compile_object(object) // Canvas command list
let client = @convert.Client::new()
let request = client.request(@convert.Convert, @convert.ConvertOptions::new())
let viewer = @viewer.Viewer::new()
viewer.set_layout(@viewer.Spread)
let sequence = @core.parse_smf(midi_bytes)
let seconds = @core.tick_to_seconds(sequence, 480.0)
let cues = @core.decode_cues(cue_bytes)
let cursor = @render.cursor_at_tick(cues, 480.0)
```

The `core` package exposes `open_split` with a lazy host-provided loader for split documents. The loader is responsible for enforcing its supplied stored-size limit while reading. `decode_text_index` reads BTXT parts, and `render.view_text_index` loads a stored index or reconstructs one for paginated views and sheets, including external tile indexes. `TextSearch` finds normalized matches and maps them to UTF-16 offsets in the original runs; `render.locate_text_hit` measures their highlight rectangles. The `browser` package exposes `mount_bdf_async` for single-file documents, `mount_bdf_split_async` for split documents with an asynchronous part loader, and `mount_bdf` for documents that need no image or embedded font loading. The `mount_bdf_interactive_*` variants add an accessible text and link layer and search for pages and sheets. Call `unmount_bdf` to release retained resources. See [browser usage](docs/browser.md).

Search normalization uses Unicode 16.0 data. An upstream JavaScript runtime using a different Unicode version can differ for characters whose mappings changed between versions.
Tile coordinates are currently limited to signed 32-bit values.

`Page` now includes `body`, and `View` includes `direction` and
`continuous_gap` and `play`. Code constructing these public records directly
must supply those fields; parsed documents use `None`, `"ltr"`, `None`, and
`None` respectively when absent. `Document::play` and `SplitDocument::play`
load MIDI bytes and cues; their `audio` methods load recorded audio and cues.
The audio MIME type is restricted to `audio/*`. Page views with a MIDI sequence can switch to a piano roll using `bdf_set_music_mode_async`. The browser adapter plays MIDI with Web Audio and embedded recordings with an audio element, and maps playback positions to cues. MIDI parsing, channel state and timeline calculations work on both targets.

## Port backlog

1. Complete the opset 1 Canvas command decoder and browser Canvas renderer, and safe resource loading.
2. Cryptography support on non-JavaScript hosts.
3. Browser Worker converter runtime transport, streaming page conversion and viewer openFile.
4. DOM/OffscreenCanvas viewer, lazy page rendering, sheet support, search, accessibility and music playback.
5. Replace or separately port TinyGo converter engines for the desired document formats.

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

## License

MIT; see [LICENSE](LICENSE). The raw DEFLATE implementation is supplied by [gaato/deflate](https://github.com/gaato/codecs.mbt), licensed under Apache-2.0; browser Promise integration uses Apache-2.0 licensed [moonbitlang/async](https://github.com/moonbitlang/async).
