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
| #8 | `feat/20261109-native-target` | open, not merged | the M1 native flip, the CI matrix and the native conversion gate |

PR #6 touches `convert/metafile`, which `convert/docx`, `convert/pptx` and
`convert/emf` import for embedded pictures. Re-measure the parity baseline
after it lands: the M3 numbers in `docs/parity.md` predate it.

PR #6 also adds `import { "f4ah6o/bdf/render" } for "wbtest"` to
`convert/metafile/moon.pkg` and `convert/xdw/moon.pkg`. PR #8 changes the
`supported_targets` line in those same two files. The merged result must keep
both:

```text
import {
  "f4ah6o/bdf/render",
} for "wbtest"

supported_targets = "+js+wasm-gc+native"
```

That combination was verified on all three targets: 6/6 for
`convert/metafile` and `convert/xdw`. PR #8 does not carry #6's changes, so
whichever lands second resolves the two files by hand.

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
`compat/*`, except `compat/size/*`, which is `wasm-gc`-only.

## Milestones

### M1 — native target

`moon.mod` caps the whole module at `+js+wasm-gc`, so every package inherits
that cap. The recon (2026-11-09) flipped `moon.mod` and 73 `moon.pkg` files to
`+js+wasm-gc+native` and changed no source file. Every gate passed:

| Gate | Result |
|---|---|
| `moon check --target native` | 0 errors |
| `moon test --target native` | 2730 / 2730 pass |
| `moon build --target native` | 0 errors |

So M1 is a declaration flip, not a code port. It landed in PR #8 as six
commits ordered by the dependency graph:

| Commit | Packages |
|---|---|
| 1 | `core`, `crypto` |
| 2 | `encoding/parquet`, `encoding/zip`, `font/{cff,otlayout,woff2,sfnt,db}` |
| 3 | `render`, `viewer`, `form/*`, `convert/*`, `export/*` |
| 4 | `print`, `print/{dnssd,ipp,raster,server}` |
| 5 | CI matrix and the empty-run guard |
| 6 | the native conversion gate |

The graph forces the grouping. `export/search` needs `render`,
`convert/textform` needs `form/data`, and `print/server` needs `convert/pdf`,
so a slice cannot be verified until its dependencies are native too.

Final state, measured on the branch:

| Target | Tests |
|---|---|
| `native` | 2733 / 2733 |
| `js` | 2749 / 2749 |
| `wasm-gc` | 2733 / 2733 |

The 16-test gap between `js` and `native` is `browser` (13) and
`print/ipp_js` (3), both `js`-only by design. Nothing is unexplained.

The conversion gate lives in `convert/all/fixture_file_wbtest.mbt`: three
tests read `compat/pdf/fixtures/*.pdf` and `compat/html/fixtures/article.html`
through `moonbitlang/x/fs` and run them through `convert`. A missing fixture
fails the test instead of skipping it. `moon test` runs the binary from the
module root, so the paths are relative to it.

`moon test` exits 0 when it runs no tests, so the CI job captures the output,
requires the summary line, and fails below 2700 tests or on any failure.

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

| Milestone | Issue | Upstream lines | Status |
|---|---|---|---|
| M1 | `20261109-native-recon` | — | reference only, not merged |
| M1 | `20261109-native-crypto-core-encoding-font` | — | landed in #8 |
| M1 | `20261109-native-convert-export` | — | landed in #8 |
| M1 | `20261109-native-print-form-ci` | — | landed in #8 |
| M2 A | `20261109-vector-pdfbdf` | 4,801 + 750 | open |
| M2 A | `20261109-vector-psbdf` | 2,083 | open |
| M2 B | `20261109-image-barcode-rowenc` | 2,286 | open |
| M2 B | `20261109-image-svg-formula` | 1,440 | open |
| M2 B | `20261109-text-markdownbdf` | 1,542 | open |
| M2 C | `20261109-thumbnail-segment` | 537 | open |
| M2 C | `20261109-sign` | 736 | open |
| M2 C | `20261109-encoding-htmlro` | 5,278 | open |
| M2 C | `20261109-conformance-fixture` | 1,073 | open |
| M3 | `20261109-parity-fontset-metrics` | — | open |
| M3 | `20261109-parity-mark-emission` | — | open |
| M3 | `20261109-parity-chart-renderer` | — | open |
| M3 | `20261109-parity-pdf-structure` | — | open |
| M3 | `20261109-parity-xlsx-print-view` | — | open |
| M3 | `20261109-parity-markdown-reader` | — | open |
| M3 | `20261109-parity-remaining` | — | open |
| XDW | `20261109-xdw-remaining-gaps` | — | open |

## Risks

- **Native is a declaration flip, and the gate now proves it runs.**
  `moon check --target native` passes by skipping packages that do not declare
  `native`, so it was never evidence on its own. PR #8 flipped every
  declaration and added a conversion gate that reads real fixtures from disk.
  The remaining risk is coverage, not compilation: three fixtures run on
  native, and the rest of the checked-in corpus still only runs on `js`.
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
