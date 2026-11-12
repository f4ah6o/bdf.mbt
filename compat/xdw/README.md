# DocuWorks fidelity evidence gate (local, experimental)

This first increment verifies **already captured** genuine DocuWorks and bdf.mbt
page images. It does not install DocuWorks, capture its UI, download documents,
call a vision API, or claim that a converter is accurate merely because it runs.
The tests are synthetic contract tests, not DocuWorks fidelity results.

## Why an independent oracle

The XDW implementation derives from
[ezpzfile-xdw](https://github.com/ezpzfile/ezpzfile-xdw), whose
[dwapi](https://github.com/ezpzfile/ezpzfile-xdw/tree/main/tools/dwapi) uses
DocuWorks' own DLL and whose
[dwview](https://github.com/ezpzfile/ezpzfile-xdw/tree/main/tools/dwview) captures
Viewer Light. Its [compare.sh](https://github.com/ezpzfile/ezpzfile-xdw/blob/main/tools/webshot/compare.sh)
compares page 1; this gate instead requires every declared page. Pure upstream
Rust-vs-MoonBit parity is useful, but is not independent evidence of correctness.

Existing `compat/visual` uses pinned vlmkit 0.23.2 to compare BDF renderers.
It cannot establish that XDW input was interpreted correctly. Use its capture
readiness discipline and optional local `vlmkit diff png` diagnostics alongside
this gate. Confirm the pinned CLI's help before use; do not upgrade it just to
match current online documentation. AI-generated explanations are not an oracle.

## Run

```
npm run test:xdw-fidelity
node node_modules/@mizchi/actrun/dist/actrun.js workflow run .github/local/xdw-fidelity.yml
node compat/xdw/verify.mjs /local/evidence/corpus.json /local/evidence/oracle.json /local/evidence/candidate.json > /local/evidence/report.json
```

Exit 0 = PASS, 1 = FAIL or malformed ERROR, 2 = NOT_RUN (capture arguments absent).
Missing named files, missing pages, corrupt data and unsupported warnings are
errors, never passes. No zero-document corpus is accepted. `test:xdw-fidelity`
exercises the verifier and the capture adapter's synthetic unit tests; it does
**not** run the browser smoke, capture a genuine oracle, or imply corpus
comparison passed.

Candidate capture only (no genuine oracle):

```
moon build --target js
node compat/xdw/capture.mjs --corpus /local/evidence/corpus.json --out /local/evidence/candidate-run --dpi 96
node compat/xdw/verify.mjs /local/evidence/corpus.json /local/evidence/oracle.json /local/evidence/candidate-run/candidate.json
```

`capture.mjs` prints `CAPTURED`, `INCOMPLETE` or `ERROR`, never `PASS`, and
always records `oracle: "NOT_RUN"`. The verifier remains the only PASS/FAIL gate.

## Calibration

`node compat/xdw/measure.mjs IMAGE.png --page-mm 210x148` reports a capture's
heuristic page rectangle and implied dpi; `--scan Y --stroke R,G,B` reports
one row's colour runs, not a dash classification. It is diagnostic tooling,
not a gate. `CALIBRATION.md` records the genuine Viewer geometry (approximately
75 dpi at the observed 100% zoom, subject to border/rounding assumptions) and
the ellipse investigation: the stored EMF pen is solid, an independent renderer
draws it solid, and changing ARCATT_LINE from 0 to 1 did not change the
observed gaps. The exact rendering-path cause is not isolated; the converter's
current solid-pen interpretation is retained. The annotation font family is now split at
the EMF face's first NUL; the browser's MS Gothic fallback and the sticky-note
edge/shadow remain controlled-comparison targets.

## Artifact contract

Keep evidence outside the repository. All paths are relative to their manifest
and must stay within that directory, including symlink targets. Inputs/images
are limited to 64 MiB each and non-interlaced PNGs to 20 million pixels.
Duplicate headers, incomplete chunks and interlaced PNGs are rejected before decoding. Large documents must
be explicitly addressed in a future bounded streaming implementation, not skipped.

A corpus manifest has this structure (placeholder hashes must be replaced):

```json
{
  "schema": 1,
  "expectedDocuments": 1,
  "expectedPages": 2,
  "thresholds": {"channelDelta": 0, "maxChangedRatio": 0},
  "thresholdRationale": "Exact same-environment initial gate; calibrate independently for genuine oracle fonts",
  "documents": [{
    "id": "public-example",
    "file": "public-example.xdw",
    "sha256": "FULL_LOWERCASE_SHA256_OF_INPUT",
    "pages": 2,
    "blankPages": [],
    "access": "public",
    "source": "https://verified-publisher.example/document.xdw",
    "licenseNotes": "Record actual publisher terms, local-use permission and whether redistribution is allowed"
  }]
}
```

Determine expected pages from genuine DocuWorks, not from the candidate being
measured. A manifest's source URL and license notes are audit records, **not** a
permission grant or proof of origin. Review them before downloading or using data.
No corpus document has been added with this increment. The existing issue
`issues/open/20261109-xdw-corpus-parity.md` identifies upstream corpus candidates
and a public sample; the upstream manifest's license does not automatically
license the documents.
Pin input hashes and the upstream corpus revision; report unavailable sources.

Both capture manifests:

```json
{
  "schema": 1,
  "role": "oracle",
  "engine": "DocuWorks",
  "version": "ACTUAL_PRODUCT_VERSION",
  "createdAt": "2026-11-12T00:00:00Z",
  "platform": "ACTUAL_OS_AND_CAPTURE_TOOL_VERSION",
  "fonts": "EXACT_FONT_MANIFEST_OR_DIGEST",
  "dpi": 96,
  "pages": [{
    "document": "public-example", "page": 1,
    "inputSha256": "FULL_LOWERCASE_SHA256_OF_INPUT",
    "image": "oracle/public-example-1.png",
    "sha256": "FULL_LOWERCASE_SHA256_OF_PNG",
    "width": 794, "height": 1123,
    "text": "Actual independently verified text in documented reading order",
    "warnings": []
  }]
}
```

Include page 2 as well. Candidate has role `candidate`, engine `bdf.mbt`, full
40-character `commit`, package/build version, browser version in platform and
its own images. Oracle engine must be `DocuWorks` or `DocuWorks Viewer Light`.
Images must be **page content only**, with matching dimensions, DPI and crop.
Record font inventory for each side; explain substitutions in the evaluation
record. This schema records claimed provenance, not a cryptographic attestation
of the renderer. Capture adapters and original logs must substantiate it.

`text` is exact, unnormalised text. For image-only pages use an explicitly verified
empty string. Do not put empty text just because extraction is unimplemented:
there is currently no partial/unknown-text PASS. Viewer Light-only users may need
manual extraction/verification before populating this field. Selection, copy and
search must also be tested in the browser; equal extracted text is not proof of
correct selection geometry. `warnings` must be empty: resolve unsupported records
or report a failed case instead of suppressing them.

Blank pages are rejected unless independently declared in `blankPages`. Detection
composites RGBA on white. Pixel comparison also composites on white and records
changed-pixel ratio and exact text equality, rather than relying on a subjective
VLM verdict. Baseline approval and threshold calibration are manual, reviewed
steps. Do not import the renderer-parity 0.05% threshold into cross-font DocuWorks
comparisons uncritically. Current gate fails on the first invalid artifact; it
must be fixed and rerun, not treated as a complete coverage report.

## Candidate capture adapter (local, experimental)

`compat/xdw/capture.mjs` automates only the bdf.mbt side of the evidence. It
takes a reviewed corpus manifest, validates the same schema, counts, SHA256
hashes, path containment (including symlink targets) and 64 MiB input limit as
the verifier, then converts each input with the already-built
`_build/js/debug/build/native_converter_worker/native_converter_worker.js`.
It does not build, install, download or accept a licence.

For every page it renders in real Chromium at `ceil(page.w * dpi / 72)` by
`ceil(page.h * dpi / 72)` device pixels, awaits `preparePage`,
`document.fonts.ready` and `renderPage`, and writes:

```
candidate-run/
  candidate.json          # verifier input, declared pages only, CAPTURED runs only
  capture.json            # full run record, including extra pages and errors
  candidate/<doc>-<page>.png
```

Only fixed/flow page views are captured. Sheet views are not rendered; a
document whose declared page count includes sheet views surfaces as a page-count
mismatch instead of a silent partial capture.

`capture.json` records the exact `git rev-parse HEAD` commit, whether the
worktree was dirty, the Chromium and Playwright versions, the converter path,
SHA256, size and mtime, the corpus manifest hash, the DPI, the font assumption,
every captured page (including pages beyond the declared count), mismatches,
converter warnings, errors, blocked external requests, page errors, console
errors, failed requests and the loopback request log (capped at 500 entries;
`requestsTruncated` records whether entries were dropped). The browser re-hashes
the served input bytes and the adapter requires that hash to equal the corpus
hash. If `git status` fails, `dirty` is `null` with a `statusError` and the run
is an error rather than a guessed clean tree.

`candidate.json` contains only declared pages 1..N. Extra pages are recorded in
`capture.json` but omitted from the candidate manifest; missing pages make the
manifest incomplete. Converter warnings are copied to every candidate page, so
the verifier rejects them instead of the adapter hiding them. A blank page is
rejected unless the corpus declares it in `blankPages`, and a declared blank page
that renders ink is an `unexpected-content` mismatch.

`candidate.json` is written only when the run is `CAPTURED`. An `INCOMPLETE` or
`ERROR` run keeps `capture.json` and any partial PNGs for diagnosis but leaves no
candidate manifest, so a failed capture cannot be consumed as a successful one.
The manifest records `status` and `dirty`; the verifier requires `CAPTURED` and a
boolean `dirty`.

Text is the BDF text index joined with the renderer's separator rules
(`Sep.SPACE` -> space, `Sep.BREAK` -> newline, layer change -> blank line). It
is candidate-side extraction, not independently verified reading order. Empty
text means the text index had no runs for that page; it is not a claim that the
page is image-only. Fonts are recorded as an assumption: embedded BDF font
faces are listed when Chromium reports them, and other text uses Chromium's
system fallback, which is not pinned. The adapter does not verify text
selection, annotation geometry, line clipping or Japanese glyph fidelity.

The capture server binds `127.0.0.1` on an ephemeral port and serves only
`compat/xdw/`, `node_modules/@bdfkit/`, the built native converter worker and
the validated input bytes under a random token. Playwright aborts and records
any HTTP(S) request whose origin is not the exact capture server origin, and the
capture page sets a restrictive CSP (`default-src 'none'` plus only the
directives the renderer needs). No source-document URL is fetched. Missing
worker, missing bdfkit runtime, missing Playwright or missing Chromium is an
explicit error; the adapter does not install anything.

`CAPTURED` means the candidate side completed without warnings, mismatches or
errors. It is **not** a fidelity pass. The genuine DocuWorks/Wine oracle remains
NOT RUN in this environment, and the verifier still returns NOT_RUN when the
oracle manifest is absent.

Tests:

```
npm run test:xdw-capture
npm run test:xdw-capture:browser
```

The unit tests are synthetic contract tests. The browser smoke requires
`moon build --target js` and Playwright Chromium; it captures the in-repository
`site/samples/demo.xdw`, asserts the candidate manifest, PNG hashes and
dimensions, text, warnings, the served-input hash, and that the verifier returns
NOT_RUN without an oracle. It also declares two pages for the one-page sample and
asserts that the incomplete run keeps `capture.json` and the partial PNG but
writes no `candidate.json`. It is a smoke test, not DocuWorks fidelity evidence.

## Capturing the evidence (genuine oracle still manual)

1. Use a licensed genuine DocuWorks environment. `dwapi render` can create a BMP
   at a specified DPI; convert losslessly to PNG, retaining the original BMP and
   command/version logs. Viewer Light screenshots are a fallback, but require
   verified page crop/scale and all-page iteration. Do not silently compare UI
   chrome or fit-to-window screenshots with fixed-DPI page bitmaps.
2. Convert the same hash-checked input through bdf.mbt's public XDW plugin. The
   candidate side is now automated by `compat/xdw/capture.mjs`: it renders every
   resulting BDF page with the pinned Playwright Chromium, awaits explicit render
   completion and all fonts/images, and preserves converter warnings, page count
   and text. `convert/xdw/kind7_browser_test.mjs` remains the synthetic pixel
   assertion for kind 7, not a corpus adapter.
3. Build the two manifests from these outputs, hash each original PNG, then run
   this gate. Preserve reference, candidate, and local vlmkit heatmaps for failures.
4. Minimize real failures into original synthetic regression fixtures before
   publishing fixes. Keep corpus binaries/derived images local unless their
   redistribution license has been separately verified.

Neither Wine nor a dedicated `~/wine` prefix was found on the investigated
ms-01-alpha environment on 2026-11-12. That is a tooling check, not proof that no
Windows installation exists elsewhere. Genuine-oracle capture, public corpus
acquisition, all-page comparison and browser text-selection verification remain
**NOT RUN**. The candidate adapter does not change that status. Proprietary
installation/license acceptance is not automated.
Use a dedicated Wine prefix if adopted: upstream's viewer helper stops programs
in that prefix, so never reuse a person's active desktop prefix.

## Next increments

- Reviewed public corpus manifest with pinned hashes and independently verified
  page totals; start with representative vector, scan, rotation and annotation cases.
- Genuine-oracle adapters with readiness/timeouts and immutable run directories;
  no manual provenance fabrication. The candidate adapter is implemented, but the
  genuine DocuWorks/Wine side remains NOT RUN.
- Run the candidate adapter against the reviewed corpus once the manifest is
  approved, then compare with the genuine oracle and preserve failures.
- Geometry/annotation comparisons, line clipping, Japanese glyphs, text selection
  and hidden-text regression checks, plus all-page coverage reports.
- Threshold calibration using independently reviewed reference changes; intentional
  defect tests to demonstrate that missing content is detected.

No external VLM service is necessary. Do not send private source documents or
screenshots to a model API. Local pixel comparisons are the default.
