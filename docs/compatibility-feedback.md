# Compatibility feedback tracking

The feedback was recorded against `77204ba7fe572759af7a64bf717d18393d9b4126`.
Its original inputs and execution environment were not provided, so the
reported percentages are not reproduced or attributed to a specific cause.
The fixes below are included in `302b0d3d1367e5d64145749d3ed697d106aa8a7a`,
which was confirmed as the remote `main` HEAD after publication on 2026-11-10.

## Office extensions and other names

- **Fixed:** `4841906` advertises `.xlsm`, `.xltx`, `.xltm`, `.docm`, `.dotx`,
  `.dotm`, `.pptm`, `.ppsx`, `.ppsm`, `.potx` and `.potm`. The Worker and
  `convert/all` detect workbooks by content and use these aliases as name
  fallbacks. `compat/converter/office-extensions-test.mjs` exercises 14 Office
  extensions with synthetic and public packages by content, explicit format,
  and name. VBA is neither executed nor carried into the BDF.
- **Unimplemented:** `.mht` and `.mhtml` need a MIME/MHTML reader. `0bf76e9`
  notes this on the copied upstream site pages; the Worker does not advertise
  them.
- **Excluded:** KiCad and Gerber/Excellon, musical-score formats and EPUB are
  outside the porting scope. A generic `.zip` extension was registered upstream
  for the excluded Gerber multi-file input; ZIP itself is a container, not a
  general conversion format. A ZIP with workbook content can still be detected
  as a workbook.
- **MoonBit additions:** draw.io `.drawio.svg` / `.drawio.png` and DocuWorks
  `.xdw` / `.xbd` have no equivalent in the compared upstream registry.

The original list of 22 other extensions was not supplied. The comparison above
uses the upstream and MoonBit registries and is not a claim that each of the 22
has individually been matched to the feedback.

## PDF stream length

`dc497ba` recovers when the declared stream end overlaps the first 1–8 bytes of
`endstream`. It keeps correctly bounded binary payloads, retains the declared
length when it falls short or includes the whole marker, and rejects a length
past the file. The change is tested with direct and indirect lengths, binary
payloads, cross-reference streams and a page conversion. It does not recover
every possible incorrect length or change the general unknown-operator policy.

## Fixed-input drawing comparison

`0d5972d` adds `compat/parity/render-diff.mjs` and preserves the configured CAD
pen cap. The harness compares upstream conversion/upstream rendering, upstream
conversion/MoonBit rendering, MoonBit conversion/upstream rendering, and
MoonBit conversion/MoonBit rendering. It records fixture hashes, versions,
fonts, viewport, scale and repeat noise. It uses public or synthetic fixtures;
it does not contain private documents.

One investigation at `092c13c` plus the then-uncommitted fixes used Chromium
156.0.8078.4, scale 1, two repeats and published `@bdfkit` 0.2.1 packages. On
its selected page-0 fixtures, rendering the same BDF with either renderer had
0% pixel difference; conversion-only differences ranged from 0% to 16.1448%.
The selected JWW fixtures went from 0.0440% and 0.2691% to 0% after the cap
fix. A three-page check found PPTX differences of 0%, 0.8963% and 21.9321% per
page. These measurements are fixture-specific, not explanations of the
original percentages. Font rendering, DOM viewer behavior and other fixtures
remain separate questions.

On integrated HEAD `0d5972d03a257cf7c750c52a56dd514bc6589781`, 715 targeted
PDF/Office/CAD tests passed on each of `js`, `wasm-gc` and `native`; 22 browser
tests, the Office extension matrix and the strict BDF render control also
passed. The detailed commands, logs and exit codes are in the orchestration
workspace under `logs/integration/compat-*`.

## Downstream observations at `6f2918f`

A second, anonymized downstream report was recorded against `6f2918f`. It
supplied one sample per format, Chromium 1200x850 at DPR 1, and no input
files, harness or organization data. The percentages are therefore reported
values, not reproduced measurements, and they are not attributed to a cause.

| Target | Reported pixel difference |
| --- | ---: |
| PDF | 0.321% |
| Excel | 20.694% |
| Word | 10.262% |
| PowerPoint | 2.028% |
| JWW | 0% |
| BDF | 0% |
| Reference redraw (control) | 0% |
| Threshold | 0.05% |

The same report said the JWW text-layer comparison failed despite the 0%
pixel difference, and that the Word reference had four detected page
elements against three in the current build. Neither is reproduced here:
`compat/converter/phase5-test.mjs` passes its JWW text-index assertion, and
`compat/parity/verify.mjs --format=docx` shows no page-count difference for
the eight DOCX fixtures (the only count difference is the documented
`docx/basic#scroll` strip count, upstream 2 against 1). The two
investigations are tracked in `issues/open/20261110-jww-text-index-sample.md`
and `issues/open/20261110-docx-page-count-sample.md`.

What is reproducible at this commit:

- `node compat/converter/office-extensions-test.mjs` reports 24 advertised
  formats and 14 Office extensions converted by content, explicit format and
  name. The downstream report also states that a synthetic DOCM neither executed
  nor embedded VBA; this worktree did not independently rerun that case.
- `convert/pdf/file_stream_wbtest.mbt` holds 12 stream-length tests. The reported 38-byte stream declared as 39 was verified downstream;
  `file_stream_wbtest.mbt:50` covers the same one-byte overlap using a
  different 33-byte body. Recovery covers 1-8 bytes of overlap with
  `endstream`; a declared length that swallows the whole nine-byte marker is
  deliberately not recovered and is only asserted as such
  (`file_stream_wbtest.mbt:81`). Whether a real file needs that case remains
  unassessed.
- `html` advertises `.html`, `.htm` and `.xhtml` only; `.mht` and `.mhtml`
  stay unregistered because the MIME/MHTML reader is not ported. They remain
  in the name-only list in `convert/all/all.mbt:498` so CSV and image
  detection do not claim them.
- The excluded formats (`epub`, `gerber`, `kicad`, `midi`, `mml`,
  `musicxml`) are asserted as unregistered in
  `office-extensions-test.mjs:33`. They are not reintroduced.

The reported 48 extension-list differences cannot be reconciled: the upstream
registry dump used for the comparison was not supplied. This repository's own
counts are 24 advertised formats, 14 Office extensions, 87 name-only
extensions and 6 excluded formats. The bounded record is
`issues/open/20261110-downstream-render-feedback.md`.
