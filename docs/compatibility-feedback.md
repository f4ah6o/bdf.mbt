# Compatibility feedback tracking

The feedback was recorded against `77204ba7fe572759af7a64bf717d18393d9b4126`.
Its original inputs and execution environment were not provided, so the
reported percentages are not reproduced or attributed to a specific cause.
The changes below are local integration commits; they have not been confirmed
on `main` and must not trigger a downstream notification yet.

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
