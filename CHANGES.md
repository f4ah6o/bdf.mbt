# Changes

## Unreleased

### Added

- `npm run verify:local` runs the self-test, lint, CI, demo, parity, visual and
  site gates through `actrun` in the current worktree and writes a manifest,
  logs and actrun run records under `_scratch/local-verify/`. Per-workflow
  shortcuts are `verify:local:self`, `verify:local:lint`, `verify:local:ci`,
  `verify:local:parity`, `verify:local:visual` and `verify:local:site`;
  `verify:local:plan` is a dry run.
- `npm run test:local-verify` runs the deterministic runner tests: status
  aggregation, empty and skipped steps, missing prerequisites, the
  retained-scope marker and the site server checks.
- `.github/local/moon-test.mjs` runs the retained packages using
  `compat/retained-test.mjs`; if the selector is missing, it reports
  `retained-scope: pending` rather than claiming retained coverage.
- DocuWorks (`.xdw`) documents now carry a text index, so body text and
  annotation text are searchable in the converted BDF.
- `include_hidden` keeps text that a later opaque fill covers; the default
  leaves covered text out. It is reachable as `xdw_convert(include_hidden=)`,
  as `convert(..., params={"include_hidden": "1"})`, and through the browser
  worker's existing `request.options.params.include_hidden`. There is no CLI
  flag for it yet.
- Word (`.docx`) conversions accept a `pages` selection such as `1-3,5,8-`
  and keep only those pages of the page view, in document order; the scroll
  view still holds the whole document. It is reachable as
  `docx_convert(pages=)`, as `form/docx.fill(pages=)`, and through the browser
  worker's existing `request.options.pages`. The page count, summary and text
  index describe the selected pages, and a link to a page left out is dropped.
  An invalid selection is an error, as upstream's `ParsePages` makes it.
- `npm run test:retained` and `npm run test:retained:js` run the MoonBit tests
  of the retained packages only, per target. A bare `moon test` still collects
  the dormant packages.

### Changed

- DocuWorks annotations use a separate `annotation` layer, which renderers can
  show or hide. Stored annotation text is indexed even when its drawing has no
  text or is missing. The static index reflects visible annotations: hiding
  them can reveal body text excluded from search unless `include_hidden` is set.
- DOCX view titles use the document title when no title is supplied, and
  conversion summaries and font warnings follow the upstream wording.
- The converter Worker no longer registers or dispatches PCB/KiCad (Gerber,
  Excellon, `.kicad_pcb`), musical-score (MML, MIDI, MusicXML/MXL) or EPUB
  conversions. A request for one of those formats fails with
  `unknown format "<name>"`, and their filename extensions are no longer
  detected. Audio playback and non-PCB CAD (DXF, Jw_cad, SXF, CGM, HP-GL/2)
  are unchanged.
- The viewer no longer offers those formats in its file picker, sample
  shortcuts or gallery, and the site no longer publishes their format pages.
- The four verification workflows run locally through `actrun` and cannot be
  triggered on GitHub. Pages deployment remains available separately through
  the manual `.github/workflows/pages-deploy.yml`; local verification never
  dispatches it or publishes the site.

### Fixed

- PDF streams whose `/Length` runs 1–8 bytes into the `endstream` marker are
  read up to that marker, preserving the reported content stream and binary
  payloads whose correct length does not overlap the marker.

- The converter Worker advertises the Office extensions upstream registers on
  the workbook, word-processing and presentation converters (`.xlsm`, `.xltx`,
  `.xltm`, `.docm`, `.dotx`, `.dotm`, `.pptm`, `.ppsx`, `.ppsm`, `.potx`,
  `.potm`), so a client's file picker offers them. A macro-enabled or template
  package is the same OPC package as its plain counterpart: macros are never
  executed and a VBA project is not carried into the BDF.
- A workbook is detected by its content like a document or a presentation, so
  a macro-enabled or template workbook converts under any name. A name with one
  of those extensions falls back to its converter when no detector claims the
  content, as upstream's `detectNamed` does, instead of failing as an
  unsupported image.
- JPEG 2000 sample conversion now uses float32 rounding and clamps extreme
  values before integer conversion, matching upstream for common precisions.
- DOCX formula warnings now include formulas in tables, headers and footers.
- EMF text with a Shift_JIS font charset now preserves Japanese characters,
  including searchable body text in DocuWorks documents.

- Covered text is left out of the DocuWorks index only when a fill provably
  hides it. A fill clipped away from the run, a translucent fill, a gradient or
  pattern fill, and an image no longer count as covers.
- DocuWorks index runs keep the ordinal the viewer draws them with, so a search
  hit lands on the right character after an earlier run is left out.
- DocuWorks index runs keep the separator the viewer computes, so phrases that
  span a line break stay searchable.

### Deprecated

### Removed

- The `test:visual` aggregate no longer requires the dropped-format suites.
  Their individual scripts stay defined so the dormant packages can still be
  run by hand.

### Security

### Migration

- Callers that converted Gerber/Excellon, KiCad, MML, MIDI, MusicXML or EPUB
  through the Worker need another converter for those files. The packages,
  sources and fixtures stay in the tree as dormant assets, but they are not
  maintained and are not part of the required verification.
- Run `npm run verify:local` before pushing. GitHub no longer runs the checks.
  Once separately authorized, Pages can be published by manually dispatching
  `.github/workflows/pages-deploy.yml`. Branch protection may still require the
  old check names. The local flow uses existing `node_modules`, `.mooncakes` and
  Playwright Chromium and does not run `npm ci`, `moon update` or
  `npx playwright install`.
