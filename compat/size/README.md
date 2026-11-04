# Wasm size probes

These packages link the converter engines into wasm-gc executables so the size
of a browser Wasm payload can be compared with the upstream `@bdfkit` presets.
Every `main` references the same conversion entry point the native converter
worker calls, so the linker keeps the converter code; the programs are never
run.

- `baseline`: an empty executable, for the linker and runtime overhead.
- `pdf_epub`: PDF and EPUB, the two formats of `@bdfkit/convert-pdf-epub`.
- `office`: the formats of `@bdfkit/convert-office` that this port converts.
- `all`: every format `browser/native_converter_worker.mbt` dispatches.

## Measure

```sh
npm ci
moon build --target wasm-gc --release
node compat/size/measure.mjs --json _build/wasm-size/sizes.json
```

The script reads the `convert-all` and `convert-office` Wasm files from
`node_modules`, and downloads `@bdfkit/convert-pdf-epub` 0.2.1 from the npm
registry when it is not installed. It prints a Markdown table of raw, gzip and
brotli sizes and the size of the `name` custom section.

Options:

- `--fast`: use brotli quality 9 instead of 11.
- `--js`: also measure `native_converter_worker.js` and `browser.js` (build
  them first with `moon build --target js --release`).
- `--json <path>`: write the measurements as JSON.

## Scope

- PDF + EPUB: the same two converters as upstream, so this is the closest
  like-for-like comparison. The port does not cover every PDF feature.
- Office: upstream's nine formats, including Parquet input and the
  XLSX font-embedding entry point.
- All: the 28 formats the native converter worker dispatches. Upstream's all
  preset also includes MusicXML, which `convert/musicxml` parses but the worker
  does not yet dispatch.

## Notes

- The upstream files are TinyGo 0.42.0 builds from `@bdfkit` 0.2.1. They
  include the TinyGo runtime, asyncify and the `syscall/js` imports, and a
  `name` custom section of 303–648 KB. The bdf.mbt modules are wasm-gc release
  builds; their `name` section is 40-45 B.
- `moon build --target wasm-gc` links these executables, so the harness also
  checks that the whole converter set links in one module.
- Run the probes only for measurement; they are not shipped. See
  [docs/wasm-size.md](../../docs/wasm-size.md) for the latest numbers.
