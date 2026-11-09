# Upstream port roadmap

This page is the forward plan for porting `shibukawa/bdf` to MoonBit. It says
what is left, in what order, and how each step is verified. It does not repeat
the current position: `docs/port-status.md` records what works today and
`docs/parity.md` records the document-level differences.

## Definition of done

The port is complete when both hold:

1. Every upstream package in scope has a MoonBit counterpart that passes
   `moon check`, `moon test` and `moon build` on every supported target.
2. The document parity harness reports 52 pass and 0 diff.

The first condition is breadth, the second is depth. Neither alone is
completion.

## Scope

Upstream is `shibukawa/bdf` at commit
`a5e4d7a6b202cfe73de44b0be51f6fb86cd8ee22` (the `.upstream` checkout):
861,749 lines of Go outside tests and 84,473 lines of tests.

### Missing packages in scope

| Upstream | Lines | MoonBit | State |
|---|---|---|---|
| `vector/pdfbdf` | 4,801 | `export/pdf` (1,717) | partial: gradients, tiling patterns, SMask, JPEG passthrough, SVG and shadows are missing |
| `vector/psbdf` | 2,083 | — | missing |
| `vector/internal` | 750 | — | missing, shared by both vector packages |
| `encoding/htmlro` | 5,278 | — | missing |
| `text/markdownbdf` | 1,542 | — | missing |
| `image/barcode` | 1,356 | — | missing |
| `image/svg` | 937 | — | missing |
| `image/rowenc` | 930 | — | missing |
| `sign` | 736 | — | missing |
| `conformance` | 657 | — | missing |
| `image/formula` | 503 | — | missing |
| `fixture` | 416 | — | missing |
| `thumbnail` | 357 | — | missing |
| `segment` | 180 | — | missing |

Everything already ported stays in scope for parity.

`vector/pdfbdf` and `vector/psbdf` both write BDF out; neither reads a new
input format. `vector/pdfbdf` is the upstream PDF writer, the same direction
as `export/pdf`. `vector/psbdf` writes PostScript and has no MoonBit
counterpart. `convert/pdf` is the opposite direction (it reads PDF) and is a
different package.

### Out of scope

| Upstream | Lines | Why |
|---|---|---|
| `image/imgconv` | 581,342 | Vendored WebP SIMD codec. The port reads WebP headers and metadata and reports pixel decoding as unsupported. |
| `docflow` | 25,473 | A document workflow server (S3/SFTP/SMTP/FTP adapters, web UI, OpenAPI). A separate product, not part of the BDF format or its converters. |
| `raster` | 9,015 | BDF rasterization onto ebitengine and `image`. MoonBit has no equivalent graphics host. |
| `cmd/bdf`, `cmd/bdfwasm`, `cmd/docflow` | 5,372 | CLI binaries. The library surface is the deliverable. |
| `contrib/otf` | 195 | A Go-specific OTF helper. |
| `site/` | — | The upstream site. This repository publishes its own. |

`internal/` (14,975 lines) is not listed separately: its packages are ported
under `convert/*` and `font/*` as their consumers need them.

`convert/xdw` is not an upstream converter. It is a port of
`ezpzfile/ezpzfile-xdw` v0.3 (MIT) that this repository added in PR #5, so it
is outside the definition of done. It stays in the supported format set and
must keep passing on every target.

## Work in flight

| PR | Branch | State | What it changes |
|---|---|---|---|
| #6 | `vibe/xdw-conversion-accuracy` | open, mergeable; parity, test and demo green, build and compare running | `convert/xdw` accuracy (path records, rotation, annotation windows, scanned strips) and `convert/metafile` EMF path records |

PR #6 touches `convert/metafile`, which `convert/docx`, `convert/pptx` and
`convert/emf` import for embedded pictures. Re-measure the parity baseline
after it lands: the M3 numbers in `docs/parity.md` predate it.

PR #6 also adds `import { "f4ah6o/bdf/render" } for "wbtest"` to
`convert/metafile/moon.pkg` and `convert/xdw/moon.pkg`. When the native flip
lands on top of it, keep both the test import and the `native` declaration in
those two files.

The remaining `convert/xdw` gaps are tracked separately from the upstream
milestones, in `20261109-xdw-remaining-gaps`.

## Targets

`moon --target` accepts `wasm`, `wasm-gc`, `js`, `native` and `llvm`. The
package manifest's `supported_targets` accepts `js`, `wasm-gc` and `native`;
`wasm` resolves to an empty set, so it is out of scope. `llvm` is not a
package target.

The port supports `js`, `wasm-gc` and `native`.

`viewer` is a 253-line model layer that imports only `core` and has no JS
externs, so it joins `native`. `bridge/wasm` is a `foreign_library` for the
wasm-gc exports; native has no consumer for it, so it stays `+js+wasm-gc`.

Browser-only packages stay `js`-only by design: `browser`, `print/ipp_js`,
`converter_worker`, `render_worker`, `native_converter_worker` and
`compat/*`.

## Milestones

### M1 — native target

`moon.mod` caps the whole module at `+js+wasm-gc`, so every package inherits
that cap. The recon (2026-11-09) flipped `moon.mod` and 73 `moon.pkg` files to
`+js+wasm-gc+native` and changed no source file. Every gate passed:

| Gate | Result |
|---|---|
| `moon check --target native` | 0 errors, 295 tasks |
| `moon test --target native` | 2730 / 2730 pass |
| `moon build --target native` | 0 errors, 145 tasks |

So M1 is a declaration flip, not a code port. The remaining work is:

1. Land the flip in review-sized slices: `crypto`/`core`/`encoding`/`font`,
   then `convert`/`export`, then `print`/`form`.
2. Add `native` to the CI matrix.
3. Add the native conversion gate: a fixture converts to BDF through a native
   binary. Compilation alone does not prove the converters run.
4. Locate the 3 `js`-only tests that the 16-test gap does not explain.

### M2 — missing packages

Three tracks that can run in parallel.

- **Track A** — `vector/pdfbdf` (close the gap in `export/pdf`) and
  `vector/psbdf` (a new BDF → PostScript writer). Both write BDF out; neither
  reads a new input format.
- **Track B** — `image/{barcode,svg,rowenc,formula}`, `text/markdownbdf`.
  Converter features on top of `convert/image`.
- **Track C** — `thumbnail`, `segment`, `sign`, `encoding/htmlro`,
  `conformance`, `fixture`. Independent, small, and unblocks the site and the
  conformance suite.

### M3 — document parity

Shared causes first, because they move several formats at once.

1. Shared fontset metrics (DOCX, Markdown, XLSX).
2. MARK emission (DOCX, PPTX, PDF).
3. Shared chart renderer (PPTX, XLSX).
4. PDF structure and form fields.
5. XLSX print view and number-format runs.
6. Markdown reader rules and resources.
7. The remaining per-format differences.

## Verification gates

| Gate | Command |
|---|---|
| JS | `moon check --target js && moon test --target js && moon build --target js` |
| wasm-gc | `moon check --target wasm-gc && moon test --target wasm-gc && moon build --target wasm-gc` |
| native | `moon check --target native && moon test --target native && moon build --target native` |
| Native conversion | a fixture converts to BDF through a native binary |
| Document parity | `node compat/parity/verify.mjs --strict` |
| Site | `npm run build:site && npm run test:site` |

`moon check --target native` alone is not a gate: it passes today by skipping
every package that does not declare `native`.

## Parallel execution

One issue is one branch and one worktree. Up to two run at once, because
`moon test` is the bottleneck. The main agent reviews and merges.

## Issue index

| Milestone | Issue | Upstream lines |
|---|---|---|
| M1 | `20261109-native-recon` | — |
| M1 | `20261109-native-crypto-core-encoding-font` | — |
| M1 | `20261109-native-convert-export` | — |
| M1 | `20261109-native-print-form-ci` | — |
| M2 A | `20261109-vector-pdfbdf` | 4,801 + 750 |
| M2 A | `20261109-vector-psbdf` | 2,083 |
| M2 B | `20261109-image-barcode-rowenc` | 2,286 |
| M2 B | `20261109-image-svg-formula` | 1,440 |
| M2 B | `20261109-text-markdownbdf` | 1,542 |
| M2 C | `20261109-thumbnail-segment` | 537 |
| M2 C | `20261109-sign` | 736 |
| M2 C | `20261109-encoding-htmlro` | 5,278 |
| M2 C | `20261109-conformance-fixture` | 1,073 |
| M3 | `20261109-parity-fontset-metrics` | — |
| M3 | `20261109-parity-mark-emission` | — |
| M3 | `20261109-parity-chart-renderer` | — |
| M3 | `20261109-parity-pdf-structure` | — |
| M3 | `20261109-parity-xlsx-print-view` | — |
| M3 | `20261109-parity-markdown-reader` | — |
| M3 | `20261109-parity-remaining` | — |
| XDW | `20261109-xdw-remaining-gaps` | — |

## Risks

- **Native is cheaper than expected, but the gate is still weak.**
  `moon check --target native` passes by skipping packages that do not declare
  `native`. The recon flipped every declaration and found no failures, so the
  remaining risk is not compilation but whether the converters actually run on
  native. The conversion gate is what proves it.
- **`encoding/htmlro` is the largest single gap** at 5,278 lines and depends
  on the reader-mode block model in `convert/reader`. It may need to split.
- **Parity is a moving target.** The harness compares against
  `@bdfkit/convert-all` 0.2.1. A reference upgrade can change the baseline.
- **`vector/psbdf` needs a PostScript interpreter.** The upstream package is
  small because it reuses `vector/internal`; the port must decide how much of
  the interpreter to share with `vector/pdfbdf`.
- **`sign` needs CMS and X.509.** `crypto` has the primitives but no ASN.1
  encoder. That is new surface, not a port of existing code.
- **PR #6 moves the parity baseline.** Its `convert/metafile` changes reach
  DOCX and PPTX pictures. Land it before M3 starts, or re-run the harness on
  top of it, so the 40 diffs are counted against one reference.
- **`convert/xdw` is outside the upstream scope but inside the test suite.**
  Its remaining gaps must not be counted as upstream parity, and its fixtures
  must keep passing on `js`, `wasm-gc` and `native`.
