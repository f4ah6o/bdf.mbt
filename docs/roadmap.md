# Upstream port roadmap

This page is the forward plan for porting `shibukawa/bdf` to MoonBit. It says
what is left, in what order, and how each step is verified. It does not repeat
the current position: `docs/port-status.md` records what works today and
`docs/parity.md` records the document-level differences.

This page and the 21 milestone issues came from PR #7; the local follow-ups
were already in main. The statuses below were refreshed against the fixed main
head `b05cd93`. A PR can still be open after its patches are integrated, so
"integrated in main" describes the implementation, not the PR state.

## Status vocabulary

- `open` — not implemented.
- `done` — the acceptance work is integrated in main `b05cd93`.
- `superseded` — replaced by another issue; kept as a pointer.

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

The patches of PRs #6, #8, #9, #10 and #11 are integrated in main `b05cd93`.
PR #7 is this documentation branch and is not in main. The PRs themselves may
still be open; the table separates the two states.

| PR | Branch | PR state | Implementation in main `b05cd93` | What it changes |
|---|---|---|---|---|
| #6 | `vibe/xdw-conversion-accuracy` | open (unverified) | all six patches integrated | `convert/xdw` accuracy (path records, rotation, annotation windows, scanned strips) and `convert/metafile` EMF path records |
| #8 | `feat/20261109-native-target` | open (unverified) | all seven commits integrated | the M1 native flip, the local actrun matrix and the native conversion gate |
| #9 | `fix/20261109-docx-story-marks` | open (unverified) | integrated | DOCX paragraph marks for header and footer stories |
| #10 | `perf/20261109-test-sharding` | open (unverified) | integrated | XLSX render verification sharded by stable case ID |
| #11 | `fix/20261109-recapture-diagnostics` | open (unverified) | integrated | visual recapture keeps the diagnostics of the viewports that painted |
| #7 | `docs/20261109-upstream-port-roadmap` | open | not in main; this branch | this roadmap and the 21 issues it adds |

The integrated commits are not the PR branch SHAs: the patches were
cherry-picked, so the main history carries different commit IDs. The PR
branches are not ancestors of `b05cd93`.

PR #6 touches `convert/metafile`, which `convert/docx`, `convert/pptx` and
`convert/emf` import for embedded pictures. Measured on the combined tree, it
does not move the parity baseline: no parity fixture embeds a metafile.

PR #6 added `import { "f4ah6o/bdf/render" } for "wbtest"` to
`convert/metafile/moon.pkg` and `convert/xdw/moon.pkg`. PR #8 changes the
`supported_targets` line in those same two files. Both are integrated in main
`b05cd93`. `convert/metafile/moon.pkg` keeps the wbtest import; in
`convert/xdw/moon.pkg` the import is a regular dependency, because the text
index calls `@render.decode_commands` in production code (`8e968da`). Both
files declare native:

```text
# convert/metafile/moon.pkg
import {
  "f4ah6o/bdf/render",
} for "wbtest"

supported_targets = "+js+wasm-gc+native"

# convert/xdw/moon.pkg
import {
  "f4ah6o/bdf/render",
}

supported_targets = "+js+wasm-gc+native"
```

The combination was verified on a fixed tree: #8 at `eb8cf94` with the #6 diff
(`origin/main...7db0a5b`) applied as a patch, giving `2fcca8c`. Only those two
files conflicted. On that tree `check`, `test` and `build` passed on `js`
(2763 tests), `wasm-gc` (2747) and `native` (2747); the XLSX picture visual
compare reported 0.00% diff; and document parity reported 12 pass and 40 diff,
the same as #8 alone. These are historical fixed-head measurements, not
claims about main `b05cd93` or any later run.

The `convert/xdw` gaps are tracked separately from the upstream milestones.
The detailed issues are `20261109-xdw-hidden-text`,
`20261109-xdw-annotation-index` and `20261109-xdw-corpus-parity`.
`20261109-xdw-remaining-gaps` is superseded by them. Hidden-text and
annotation indexing are integrated in main `b05cd93` (`8e968da`, `959c032`,
`9f224fc`, `bb16d5b`); the 43-document corpus comparison remains open.

## Targets

`moon --target` accepts `wasm`, `wasm-gc`, `js`, `native` and `llvm`. The
package manifest's `supported_targets` accepts `js`, `wasm-gc` and `native`;
`wasm` resolves to an empty set, so it is out of scope. `llvm` is not a
package target.

Main `b05cd93` declares `supported_targets = "+js+wasm-gc+native"` in
`moon.mod` and in 74 `moon.pkg` files. The port supports `js`, `wasm-gc` and
`native`.

`viewer` is a 165-line model layer (`viewer.mbt`, plus an 88-line test
file) that imports only `core` and has no JS externs, so it joins `native`.
`bridge/wasm` is a `foreign_library` for the wasm-gc exports; native has no
consumer for it, so it stays `+js+wasm-gc`.

Browser-only packages stay `js`-only by design: `browser`, `print/ipp_js`,
`converter_worker`, `render_worker`, `native_converter_worker` and
`compat/*`, except `compat/size/*`, which is `wasm-gc`-only.

## Milestones

### M1 — native target

M1 is integrated in main `b05cd93`. `moon.mod` declares
`+js+wasm-gc+native`, and the retained packages declare `native` in their
`moon.pkg` files. The recon (2026-11-09) flipped `moon.mod` and 73 `moon.pkg`
files and changed no source file; #8 added `viewer`, which brings main to 74.
Every gate passed on that fixed head:

| Gate | Result |
|---|---|
| `moon check --target native` | 0 errors |
| `moon test --target native` | 2730 / 2730 pass |
| `moon build --target native` | 0 errors |

These are historical fixed-head measurements from the recon, not claims about
main `b05cd93` or any later run.

So M1 was a declaration flip, not a code port. PR #8 carried seven commits
ordered by the dependency graph; all seven are integrated in main `b05cd93`:

| Commit | Packages |
|---|---|
| 1 | `core`, `crypto` |
| 2 | `encoding/parquet`, `encoding/zip`, `font/{cff,otlayout,woff2,sfnt,db}` |
| 3 | `render`, `viewer`, `form/*`, `convert/*`, `export/*` |
| 4 | `print`, `print/{dnssd,ipp,raster,server}` |
| 5 | the local actrun matrix and the empty-run guard |
| 6 | the native conversion gate: convert checked-in fixtures from disk |
| 7 | the native conversion gate: assert page counts and extracted text |

The graph forces the grouping. `export/search` needs `render`,
`convert/textform` needs `form/data`, and `print/server` needs `convert/pdf`,
so a slice cannot be verified until its dependencies are native too.

Final state, measured on the #8 branch (`eb8cf94`), historical:

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

`moon test` exits 0 when it runs no tests, so the local actrun `ci/test` job
captures the output, requires the summary line, and fails below 2700 tests or
on any failure.

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

Verification runs locally through `actrun`; GitHub never runs the verification
workflows. The gates are defined in `.github/workflows/` and driven by
`npm run verify:local`:

| Gate | Local command | What it runs |
|---|---|---|
| Self-test | `npm run verify:local:self` | `node --test .github/local/verify.test.mjs` |
| CI matrix | `npm run verify:local:ci` | `.github/workflows/ci.yml` job `test` through actrun: retained `moon check`, `moon test` and `moon build` on `js`, `wasm-gc` and `native`, with the min-test-count assertion |
| Demo | `npm run verify:local:ci` | `.github/workflows/ci.yml` job `demo`: sample verification, demo build, browser tests and previews |
| Document parity | `npm run verify:local:parity` | `.github/workflows/parity.yml`: retained JS build and `compat/parity/verify.mjs --limit=100` |
| Visual | `npm run verify:local:visual` | `.github/workflows/visual.yml`: the retained visual aggregate |
| Site | `npm run verify:local:site` | `.github/workflows/pages.yml` job `build`: site build, site tests, previews, benchmarks and the vlmkit checks |
| Full local flow | `npm run verify:local` | all of the above |

A focused run uses the same runner directly, for example
`node_modules/.bin/actrun workflow run .github/workflows/ci.yml --local --job test`.
The exact skip-action list and run roots are owned by `.github/local/verify.mjs`;
see the README and `docs/verification-scope.md`.

`moon check --target native` alone is not a gate: it can pass by skipping
packages that do not declare `native`. The local matrix runs check, test and
build on the retained packages, and the fixture gate proves a native binary
converts a real document.

The only workflow GitHub can run is the manual Pages deployment,
`.github/workflows/pages-deploy.yml`. It is `workflow_dispatch` only and is
kept as the existing deployment definition. The local flow never runs or
dispatches it, never uploads a Pages artifact and never publishes the site.

## Parallel execution

One issue is one branch and one worktree. Up to two run at once, because
`moon test` is the bottleneck. The main agent reviews and merges.

## Issue index

The status column uses the vocabulary above. Every issue file under
`issues/open/` appears exactly once.

| Milestone | Issue | Upstream lines | Status |
|---|---|---|---|
| M1 | `20261109-native-recon` | — | done: recon recorded; branch not merged |
| M1 | `20261109-native-crypto-core-encoding-font` | — | done: integrated in main `b05cd93` (#8) |
| M1 | `20261109-native-convert-export` | — | done: integrated in main `b05cd93` (#8) |
| M1 | `20261109-native-print-form-ci` | — | done: integrated in main `b05cd93` (#8) |
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
| XDW | `20261109-xdw-remaining-gaps` | — | superseded: see the three XDW issues below |
| XDW | `20261109-xdw-hidden-text` | — | done: `8e968da`, `959c032` |
| XDW | `20261109-xdw-annotation-index` | — | done: `8e968da`, `959c032`, `bb16d5b` |
| XDW | `20261109-xdw-corpus-parity` | — | open: 43-document corpus validation |
| Local | `20261110-async-cancellation-cleanup` | — | open |
| Local | `20261110-compiler-warning-classes` | — | open |
| Local | `20261110-docx-page-count-sample` | — | open |
| Local | `20261110-downstream-render-feedback` | — | open |
| Local | `20261110-jww-text-index-sample` | — | open |
| Local | `20261110-pages-node24-actions` | — | open |
| Local | `20261110-vlmkit-hono-advisory` | — | open |

## Risks

- **Native is a declaration flip, and the gate now proves it runs.**
  `moon check --target native` passes by skipping packages that do not declare
  `native`, so it was never evidence on its own. The integrated #8 patches
  flipped every retained declaration and added a conversion gate that reads
  real fixtures from disk. The remaining risk is coverage, not compilation:
  three fixtures run on native, and the rest of the checked-in corpus still
  only runs on `js`.
- **`encoding/htmlro` is the largest single gap** at 5,278 lines and depends
  on the reader-mode block model in `convert/reader`. It may need to split.
- **Parity is a moving target.** The harness compares against
  `@bdfkit/convert-all` 0.2.1. A reference upgrade can change the baseline.
- **`vector/psbdf` needs a rasterizer, not an interpreter.** Upstream
  `psbdf.Write(w io.Writer, doc *bdf.Document, opts *Options)` writes BDF as
  PostScript; it never reads PostScript, so there is no interpreter to port.
  What it does need is `vector/internal/flatten`, which draws the regions
  PostScript cannot express (alpha, blend modes, groups, soft masks, shadows,
  filters) as pictures through `raster/imagebdf`. `raster` is out of scope, so
  the port must either bring a minimal rasterizer or accept that those regions
  degrade to vectors.
- **`sign` needs CMS and X.509.** `core` and `crypto` have the primitives but
  no ASN.1 encoder. That is new surface, not a port of existing code.
- **PR #6 does not move the parity baseline, measured.** The harness covers 52
  cases (pdf 15, docx 12, pptx 8, xlsx 11, markdown 6). Running it on #8 alone
  and on #8 + #6 gave the same 12 pass / 40 diff, and no case changed status,
  because no parity DOCX or PPTX fixture embeds an EMF or WMF picture. The
  metafile path is exercised by the `convert/metafile` and `convert/xdw` tests
  instead. That is a historical fixed-head measurement; re-measure if a parity
  fixture gains an embedded metafile.
- **`convert/xdw` is outside the upstream scope but inside the test suite.**
  Its remaining gaps must not be counted as upstream parity, and its fixtures
  must keep passing on `js`, `wasm-gc` and `native`. Hidden-text and
  annotation indexing are integrated; the 43-document corpus comparison is
  still open in `20261109-xdw-corpus-parity`.
