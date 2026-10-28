# bdf.mbt

MoonBit implementation of the BDF v1 wire-format reader and the browser-facing `@bdfkit/render`, `@bdfkit/convert`, and `@bdfkit/viewer` control layers.

- Targets: `js` and `wasm-gc`.
- `core`: checked BDF header, single and split documents (identity and deflate-raw), BOBJ resource tables, bounded binary reader.
- `render`: backend-neutral, checked display-list decoder for a currently supported subset of Canvas 2D opcodes, including paths, gradient paints, and drawing effects.
- `convert`: the worker-client request/response lifecycle and stream command model. Converter runtime itself (TinyGo) is **not** ported.
- `viewer`: document/view selection state and page placement in single, spread, and continuous modes.
- `browser` (JS only): Canvas 2D adapter that draws a subset of unencrypted fixed/flow BDF pages into a DOM host, including paths, gradients, child objects, and asynchronously loaded images and fonts.

This is an **incremental port**, not a feature-equivalent replacement for the upstream npm packages. In particular, a full DOM viewer, crypto, full opset 1 (masks, text selection, sheet tiles, music), browser Worker transport and PDF/Office/CAD decoders are not yet implemented. Unsupported drawing opcodes and protected inputs fail explicitly instead of silently rendering incorrectly.

Upstream implementation: https://github.com/shibukawa/bdf (MIT). Wire specification: https://github.com/shibukawa/bdf/blob/main/docs/spec.md .

## Verify

```sh
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
```

The `core` package exposes `open_split` with a lazy host-provided loader for split documents. The loader is responsible for enforcing its supplied stored-size limit while reading. The `browser` package exposes `mount_bdf_async` for supported single-file documents, and `mount_bdf` for documents that need no image or embedded font loading. See [browser usage](docs/browser.md).

## Port backlog

1. Complete the opset 1 Canvas command decoder and browser Canvas renderer, including masks and safe resource loading.
2. Host adapters for split documents and Web Crypto.
3. Browser Worker converter runtime transport, streaming page conversion and viewer openFile.
4. DOM/OffscreenCanvas viewer, lazy page rendering, sheet support, search, accessibility and music playback.
5. Replace or separately port TinyGo converter engines for the desired document formats.

## Compatibility checks

The visual test compares the same BDF fixture with the upstream `@bdfkit/render`
and this library in Chromium at three viewport widths. It verifies that both
pages finish rendering and that their captured pixels differ by at most 0.05%
of the visible document area. This fixture covers the supported drawing operations; it is not a complete
compatibility test of all upstream features.

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
