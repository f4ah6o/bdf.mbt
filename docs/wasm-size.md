# Wasm size comparison

This page compares the browser Wasm payload of the same converter parts: the
wasm-gc modules this port links today and the published upstream `@bdfkit` Wasm
presets. The demo ships a wasm-gc build for PDF→BDF and the export tabs
(`bridge/wasm`); the full converter Worker still uses the `js` target, so the
modules below are linked for measurement (see
[compat/size](../compat/size/README.md)).

## Results

Measured with `moon 0.1.20261029` and upstream `@bdfkit` 0.2.1 (TinyGo 0.42.0).
Compression is gzip level 9 and brotli quality 11 from Node's zlib.

The numbers below predate the scope reduction. The `all` and `office` probes no
longer link the dormant PCB/KiCad, musical-score and EPUB packages, so
re-measuring them will report a smaller module and the `office` row no longer
matches upstream's nine-format preset. The `pdf-epub` probe still links
`compat/size/pdf_epub` unchanged, so its row still includes EPUB.

| Preset | bdf.mbt raw | bdf.mbt gzip | bdf.mbt brotli | upstream raw | upstream gzip | upstream brotli | raw ratio | gzip ratio |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| PDF + EPUB | 1,543,654 B (1.47 MiB) | 618,808 B (604.3 KiB) | 477,769 B (466.6 KiB) | 8,089,066 B (7.71 MiB) | 3,034,462 B (2.89 MiB) | 2,210,739 B (2.11 MiB) | 0.19x | 0.20x |
| Office | 4,184,523 B (3.99 MiB) | 1,736,430 B (1.66 MiB) | 1,180,332 B (1.13 MiB) | 9,645,490 B (9.20 MiB) | 3,623,223 B (3.46 MiB) | 2,622,476 B (2.50 MiB) | 0.43x | 0.48x |
| All | 5,654,144 B (5.39 MiB) | 2,220,385 B (2.12 MiB) | 1,515,729 B (1.45 MiB) | 15,652,735 B (14.93 MiB) | 6,235,394 B (5.95 MiB) | 4,700,090 B (4.48 MiB) | 0.36x | 0.36x |

The ratio is bdf.mbt divided by upstream. The closest like-for-like row is
PDF + EPUB: the module is 5.2 times smaller raw and 4.9 times smaller with
gzip. The Office row covers the same nine formats; the All row was measured
before the scope reduction and still includes the dormant packages.

The `name` custom section, which `tinygo build -no-debug` still emits, is
303,219 B (PDF + EPUB), 362,241 B (Office) and 648,101 B (All) in the upstream
files; the bdf.mbt release modules have a 40–45 B section. The rest of the gap
includes the TinyGo runtime, its asyncify transform and the `syscall/js`
imports.

An empty wasm-gc executable is 177 B, so the bdf.mbt figures are almost
entirely converter code. The modules have no imports of their own.

## How the numbers were produced

The bdf.mbt side is a set of executable packages under
[`compat/size`](../compat/size). Each `main` references the conversion entry
points the native converter worker calls, so the linker keeps them; the program
is never run. Built with:

```sh
moon build --target wasm-gc --release
```

The upstream files are the published Wasm presets, built by upstream with
`tinygo build -target wasm -no-debug`:

- `@bdfkit/convert-all` and `@bdfkit/convert-office` from `npm ci`
- `@bdfkit/convert-pdf-epub` 0.2.1, downloaded from the npm registry by the
  measurement script when it is not installed

To reproduce:

```sh
npm ci
moon build --target wasm-gc --release
node compat/size/measure.mjs --json _build/wasm-size/sizes.json
```

`--js` also measures the release JavaScript build, `--fast` uses brotli
quality 9.

## Scope

| Preset | bdf.mbt | upstream | Notes |
| --- | ---: | ---: | --- |
| PDF + EPUB | 2 | 2 | Same converter packages. The PDF and EPUB features are not complete: see the PDF and EPUB sections of the [README](../README.md). |
| Office | 9 | 9 | Upstream's CSV, DOCX, EPUB, IDML, Parquet, PDF, PPTX, Visio and XLSX. Parquet input and the XLSX font-embedding entry point are linked. |
| All | 28 | 29 | Every format the native converter worker dispatches. Upstream also includes MusicXML, which `convert/musicxml` parses but the worker does not yet dispatch. |

Feature gaps are documented in the [README](../README.md) and
[port status](port-status.md). The sizes therefore measure the same converter
packages, not feature-equivalent implementations.

## Current JavaScript build

The full converter Worker ships as JavaScript (the demo's PDF→BDF/export
wasm-gc build is separate):

| File | raw | gzip | brotli |
| --- | ---: | ---: | ---: |
| `native_converter_worker.js` | 16,872,735 B (16.09 MiB) | 2,504,068 B (2.39 MiB) | 1,606,624 B (1.53 MiB) |
| `browser.js` | 18,708,413 B (17.84 MiB) | 2,700,704 B (2.58 MiB) | 1,733,896 B (1.65 MiB) |

For reference, upstream's `@bdfkit/convert` worker bundles the TinyGo JS glue
in a 19,878 B `worker.js`; a browser deployment of the bdf.mbt Wasm modules
would likewise need a small host shim, which the figures above do not count.

## Caveats

- The two sides use different runtimes and toolchains (TinyGo with the Go
  runtime and asyncify, MoonBit with the wasm-gc runtime). Raw sizes are not a
  runtime or performance comparison.
- Some compatibility oracles use a locally built `GOOS=js GOARCH=wasm` Office
  preset of 30,442,581 B. It contains the full Go runtime and is not the
  browser payload, so it is not part of this comparison.
- Sizes depend on the compiler versions; the versions used are printed by
  `compat/size/measure.mjs`.
