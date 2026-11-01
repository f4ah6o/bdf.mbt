# Wasm size comparison

This page compares the browser Wasm payload of the same converter parts: the
wasm-gc modules this port links today and the published upstream `@bdfkit` Wasm
presets. The port does not ship a Wasm build yet, so the modules below are
linked only for measurement (see
[compat/size](../compat/size/README.md)); the browser demo and the converter
worker still use the `js` target.

## Results

Measured with `moon 0.1.20261023` and upstream `@bdfkit` 0.2.1 (TinyGo 0.42.0).
Compression is gzip level 9 and brotli quality 11 from Node's zlib.

| Preset | bdf.mbt raw | bdf.mbt gzip | bdf.mbt brotli | upstream raw | upstream gzip | upstream brotli | raw ratio | gzip ratio |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| PDF + EPUB | 1,090,661 B (1.04 MiB) | 465,726 B (454.8 KiB) | 397,128 B (387.8 KiB) | 8,089,066 B (7.71 MiB) | 3,034,462 B (2.89 MiB) | 2,210,739 B (2.11 MiB) | 0.13x | 0.15x |
| Office | 3,490,298 B (3.33 MiB) | 1,476,380 B (1.41 MiB) | 956,350 B (933.9 KiB) | 9,645,490 B (9.20 MiB) | 3,623,223 B (3.46 MiB) | 2,622,476 B (2.50 MiB) | 0.36x | 0.41x |
| All | 4,768,089 B (4.55 MiB) | 1,909,255 B (1.82 MiB) | 1,288,322 B (1.23 MiB) | 15,652,735 B (14.93 MiB) | 6,235,394 B (5.95 MiB) | 4,700,090 B (4.48 MiB) | 0.30x | 0.31x |

The ratio is bdf.mbt divided by upstream. The closest like-for-like row is
PDF + EPUB: the module is 7.4 times smaller raw and 6.5 times smaller with
gzip. The Office and All rows are smaller partly because this port covers fewer
formats (see [Scope](#scope)).

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
| Office | 8 | 9 | Upstream's CSV, DOCX, EPUB, IDML, Parquet, PDF, PPTX, Visio and XLSX minus Parquet input, which this port does not read. XLSX uses `convert_plain_no_fonts`, because the font-embedding path is not ported. |
| All | 19 | 29 | Every format the native converter worker dispatches. Upstream also includes CGM, draw.io, DXF, Gerber, HP-GL, Jw_cad, KiCad, Parquet and SXF. MusicXML is parsed by `convert/musicxml` but is not wired into the worker, so it is not counted. |

Feature gaps are documented in the [README](../README.md) and
[port status](port-status.md). The sizes therefore measure the same converter
packages, not feature-equivalent implementations.

## Current JavaScript build

The shipped browser build is still JavaScript:

| File | raw | gzip | brotli |
| --- | ---: | ---: | ---: |
| `native_converter_worker.js` | 13,059,420 B (12.45 MiB) | 2,078,859 B (1.98 MiB) | 1,330,265 B (1.27 MiB) |
| `browser.js` | 14,954,899 B (14.26 MiB) | 2,276,011 B (2.17 MiB) | 1,458,061 B (1.39 MiB) |

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
