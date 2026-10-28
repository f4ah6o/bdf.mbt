# bdf.mbt

MoonBit implementation of the BDF v1 wire-format reader and the browser-facing `@bdfkit/render`, `@bdfkit/convert`, and `@bdfkit/viewer` control layers.

- Targets: `js` and `wasm-gc`.
- `core`: checked BDF header, identity single-file manifest, BOBJ resource table, bounded binary reader.
- `render`: backend-neutral, checked display-list decoder for a currently supported subset of Canvas 2D opcodes.
- `convert`: the worker-client request/response lifecycle and stream command model. Converter runtime itself (TinyGo) is **not** ported.
- `viewer`: document/view selection state and page placement in single, spread, and continuous modes.\n- `browser` (JS only): Canvas 2D adapter that draws a limited subset of uncompressed fixed/flow BDF pages into a DOM host.

This is an **incremental port**, not a feature-equivalent replacement for the upstream npm packages. In particular, a full DOM viewer, decompression, crypto, full opset 1 (paths, paints, masks, text selection, sheet tiles, music), browser Worker transport and PDF/Office/CAD decoders are not yet implemented. Unsupported drawing opcodes and protected/compressed inputs fail explicitly instead of silently rendering incorrectly.

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
let document = @core.open_single(bdf_bytes) // identity, unencrypted BDF only
let object = @core.decode_object(document.part(hash))
let commands = @render.compile_object(object) // Canvas command list
let client = @convert.Client::new()
let request = client.request(@convert.Convert, @convert.ConvertOptions::new())
let viewer = @viewer.Viewer::new()
viewer.set_layout(@viewer.Spread)
```

The `browser` package exposes `mount_bdf` for supported documents. See [browser usage](docs/browser.md).\n\n## Port backlog

1. Complete the opset 1 Canvas command decoder and browser Canvas renderer with safe resource loading and recursive object limits.
2. Host adapters for split documents, bounded deflate-raw decompression and Web Crypto.
3. Browser Worker converter runtime transport, streaming page conversion and viewer openFile.
4. DOM/OffscreenCanvas viewer, lazy page rendering, sheet support, search, accessibility and music playback.
5. Replace or separately port TinyGo converter engines for the desired document formats.

## License

MIT; see [LICENSE](LICENSE).
