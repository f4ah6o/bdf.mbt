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
pnpm run test:xdw-fidelity
node node_modules/@mizchi/actrun/dist/actrun.js workflow run .github/local/xdw-fidelity.yml
node compat/xdw/verify.mjs /local/evidence/corpus.json /local/evidence/oracle.json /local/evidence/candidate.json > /local/evidence/report.json
```

Exit 0 = PASS, 1 = FAIL or malformed ERROR, 2 = NOT_RUN (capture arguments absent).
Missing named files, missing pages, corrupt data and unsupported warnings are
errors, never passes. No zero-document corpus is accepted. `test:xdw-fidelity`
only exercises the verifier; it does **not** imply corpus comparison passed.

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
No sample document has been added with this increment. The existing issue
`issues/open/20261109-xdw-corpus-parity.md` identifies public candidate sources;
the upstream manifest's license does not automatically license the documents.
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

## Capturing the evidence (not automated in this increment)

1. Use a licensed genuine DocuWorks environment. `dwapi render` can create a BMP
   at a specified DPI; convert losslessly to PNG, retaining the original BMP and
   command/version logs. Viewer Light screenshots are a fallback, but require
   verified page crop/scale and all-page iteration. Do not silently compare UI
   chrome or fit-to-window screenshots with fixed-DPI page bitmaps.
2. Convert the same hash-checked input through bdf.mbt's public XDW plugin. Render
   every resulting BDF page with a pinned browser/renderer. Await explicit render
   completion and all fonts/images; save each canvas as PNG. Preserve converter
   warnings, page count and text. The existing
   `convert/xdw/kind7_browser_test.mjs` demonstrates synthetic conversion and pixel
   assertions, not a ready-made real-corpus capture adapter.
3. Build the two manifests from these outputs, hash each original PNG, then run
   this gate. Preserve reference, candidate, and local vlmkit heatmaps for failures.
4. Minimize real failures into original synthetic regression fixtures before
   publishing fixes. Keep corpus binaries/derived images local unless their
   redistribution license has been separately verified.

Neither Wine nor a dedicated `~/wine` prefix was found on the investigated
ms-01-alpha environment on 2026-11-12. That is a tooling check, not proof that no
Windows installation exists elsewhere. Genuine-oracle capture, public corpus
acquisition, all-page comparison and browser text-selection verification remain
**NOT RUN**. Proprietary installation/license acceptance is not automated.
Use a dedicated Wine prefix if adopted: upstream's viewer helper stops programs
in that prefix, so never reuse a person's active desktop prefix.

## Next increments

- Reviewed public corpus manifest with pinned hashes and independently verified
  page totals; start with representative vector, scan, rotation and annotation cases.
- Automatic candidate capture and genuine-oracle adapters with readiness/timeouts
  and immutable run directories; no manual provenance fabrication.
- Geometry/annotation comparisons, line clipping, Japanese glyphs, text selection
  and hidden-text regression checks, plus all-page coverage reports.
- Threshold calibration using independently reviewed reference changes; intentional
  defect tests to demonstrate that missing content is detected.

No external VLM service is necessary. Do not send private source documents or
screenshots to a model API. Local pixel comparisons are the default.
