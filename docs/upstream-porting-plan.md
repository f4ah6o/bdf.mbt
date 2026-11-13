# Upstream porting plan: gap audit 2026-11-12

Feature-by-feature audit of `shibukawa/bdf` (Go) against `f4ah6o/bdf.mbt`
(MoonBit), produced by the gap-audit worker of 2026-11-12. This document
records what is already implemented, what is partial, what is missing and
what is deliberately excluded, with the evidence behind each row, and it
proposes small, independently reviewable implementation slices. It is an
audit: no implementation changes are part of this run.

## Sources and method

| Side | Revision | Location |
|---|---|---|
| Upstream (Go, read-only) | `a5e4d7a6b202cfe73de44b0be51f6fb86cd8ee22` | `local read-only upstream checkout` (`go.sum` is locally dirty; all evidence was taken from tracked files at this commit) |
| Port (MoonBit) | `61f195b38293415a46a6aca4cff99187ba68ea5e` (= `origin/main` at audit start) | this worktree, branch `chore/20261112-upstream-gap-audit` |

Method: the PPTX, DOCX and XLSX lead areas were compared side by side at
code level (three read-only subagents, one per format group, with the key
findings re-verified in this session against the exact lines cited). The
remaining format groups were reconciled from the existing status documents
and issue files, with spot checks where a row is load-bearing. Evidence
classes per row:

- **[V]** verified against code on both sides this run (line references below);
- **[D]** carried from an existing status doc that itself cites code or
  fixtures (path given);
- **[I]** carried from an existing issue document (`issues/open/…`).

Only [V] rows are confirmed code-level findings from this run. [D] and [I]
rows are inventory leads requiring verification before implementation.

### Out of audit scope (active work, not duplicated here)

| Work | Branch / worktree | State at audit time |
|---|---|---|
| PDF export public API | `feat/20261112-pdf-export-public-api` (worktree `bdf-pdf-export-api-20261112`) | 1 commit ahead of `origin/main` (issue doc) |
| DocuWorks fidelity gate PR1 | `feat/20261112-xdw-fidelity` (worktree `bdf-xdw-fidelity-20261112`) | 2 commits ahead (docs + test) |
| Selection clipboard | `fix/20261112-selection-clipboard` (worktree `bdf-selection-upstream-20261112`) | checked out at `19fe3255` with uncommitted changes under `browser/` |
| XLSX fixture storage | `chore/20261112-xlsx-fixture-storage` | merged as PR #2 (in `main`) |
| PPTX connectors | `fix/20261112-pptx-connectors` (worktree `bdf-pptx-connectors-20261112`) | implementation is in progress in this dedicated worktree; do not assign slice 1 again. |

Deliberately excluded porting scope (unchanged from
`docs/verification-scope.md`): KiCad/PCB (Gerber, Excellon, `kicad`),
musical scores (MIDI score, MML, MusicXML), EPUB. Private downstream formats and source are excluded. No private source,
document or organization information is included in this audit.

## Gap matrix

The matrix records the original audit; subsequent work has addressed some gaps.
PPTX shape, connector and picture click links now preserve supported external
relationships. Internal slide actions remain open (see
`issues/open/20261112-pptx-internal-shape-links.md`).

### PPTX (`convert/pptx` vs upstream `converter/pptx` + `converter/internal/ooxml/drawingml`)

| Feature | Upstream evidence | Port evidence | Status | Conf. | Class |
|---|---|---|---|---|---|
| `p:cxnSp` collected as a shape | `drawingml/shape.go:294`/`:322` treats `cxnSp` like `sp`; `pptx/template.go:361`,`:833` | `convert/pptx/convert.mbt:742-767` `pptx_collect_shapes` matches only `sp`/`pic`/`graphicFrame`/`grpSp`; `cxnSp` falls to `_ => ()` — silently dropped from every layer, no warning | **missing** | high | [V] |
| Zero-extent connectors (`a:ext cy="0"`/`cx="0"`) | `shape.go:158` xfrm logic gives up only with no offset/size at all; `features.pptx` slide 5 connectors are flat and render | `convert/pptx/render_page.mbt:102-104` skips any shape with `width<=0 \|\| height<=0` | **missing** | high | [V] |
| Connector geometry presets (`straightConnector1`, `bent/curvedConnector2-5`, `flowChartConnector`) | presets table + unknown-preset→rect-with-warning (`shape.go:364-366`) | all present in `convert/pptx/presets_generated.mbt:217-247,462-486,1499` but unreachable from `cxnSp` | implemented, unreachable for `cxnSp` | high | [V] |
| Line style from `a:ln`, `p:style lnRef`, dash | `drawingml/fill.go:404-477`, theme line matrix | `convert/pptx/paint.mbt:227-410` (incl. `lnRef` fallback) | implemented (for `sp`) | high | [V] |
| Arrow heads/tails (`a:headEnd`/`a:tailEnd`, 5 kinds, 3 sizes) | `fill.go:470-477`, `fill.go:518`, `fill.go:556`; attached at path tangent ends `shape.go:428-429` | `paint.mbt:394-407,648-757` (`pptx_draw_arrow`, `pptx_stroke_geometry_path`) | implemented (no `cxnSp` reaches it) | high | [V] |
| Connector attachment (`stCxn`/`endCxn` re-routing) | not implemented upstream either (drawn at own `a:xfrm`) | same (nothing to do) | n/a — parity by omission | high | [V] |
| Fixture-backed expectation | `pptx/testdata/basic.pptx` slide 3 (red `line` connector, `tailEnd` triangle; `TestConvertBasic` asserts zero warnings, `pptx_test.go:250`); `features.pptx` slide 5 (3 flat connectors, dash styles × 4 head/tail kinds) | both decks already embedded (gz+base64) in `convert/pptx/presentation_generated_wbtest.mbt`, which enumerates the connector transforms only in whitebox asserts | — | high | [V] |
| Other drawing gaps noticed in passing | shape hyperlinks (`shape.go:629`), FIGURE alt-text marks (`shape.go:276-289`), `cNvPr@hidden` skip (`shape.go:305`) | no `hlinkClick` handling in `convert/pptx`; no FIGURE mark; no hidden skip | missing | high | [V] |
| SmartArt layout, ink, 3D, extra chart types | upstream partial too | documented | deliberate / documented gaps | — | [D] `docs/port-status.md` PPTX section |

### DOCX (`convert/docx` vs upstream `converter/docx` + `converter/internal/wordproc`, `converter/internal/ooxml/drawingml`, `internal/xmltree`)

| Feature | Upstream evidence | Port evidence | Status | Conf. | Class |
|---|---|---|---|---|---|
| Paragraph-mark run properties (`w:pPr/w:rPr`) used for layout (empty-paragraph height, `lh` spacing, char-unit indents, list label style, empty-math centering) | `wordproc/model.go:396-398` resolves `pPr/rPr` into `p.mark`; consumed at `inline.go:50-57,253,491-512`, `flow.go:682`, `math.go:74-77`; list labels merged with level `rPr` (`model.go:923-940`) | `convert/docx/document_text.mbt:2196` passes `None` as the direct node; `DocxStyles::resolve_run` (`convert/docx/style_resolver.mbt:308-342`) would apply one. Mark is consumed (`layout.mbt:240-244,631-640`) but with a fixed 1.2 em height, and `numbering.mbt:227,258` omits the level `rPr` merge | **partial** (direct rPr never read) | high | [V] |
| Character-unit indents (`leftChars`/`rightChars`/`firstLineChars`/`hangingChars` — units of 1/100 char, scaled by mark size) | `inline.go:50-57` | parsed at `convert/docx/paragraph_props.mbt:219-235` but grep shows the fields are never applied in `layout.mbt` (only pt indents `left/first/right` are) | **missing** | high | [V] |
| `mc:AlternateContent` Choice vs Fallback | parse-time `resolveAlternates` (`internal/xmltree/xmltree.go:446-508`) with supported-prefix set `wps,wpg,wpc,wp14,w14,w15,a14,pic14` (`wordproc/docx.go:43-45`); tests `converter/internal/ooxml/ooxml_test.go:97-112,225-250`; `testdata/basic.docx`/`form-fixed.docx` carry `Requires="wps"` + VML fallbacks | `convert/docx/document_text.mbt:1001-1010` picks the first `Choice` unconditionally, never reads `Requires`; inline-only (`:1317-1323`, `:1416-1423`) | **partial** | high | [V] |
| Non-image drawings: text boxes | full `wps` pipeline: `wordproc/draw.go:266-306` walks `w:txbxContent` through the real layout engine (anchor, insets `drawingml/graphic.go:130-160`, vertical anchor, wrap) | `convert/docx/document_text.mbt:588-649`: all `w:t` under `txbxContent` joined by spaces into one inline text item; no box geometry, alignment or shape | **partial** (text kept; layout lost) | high | [V] |
| Non-image drawings: plain shapes/groups/charts (no blip, no txbx) | drawn via `DrawGraphic` (`drawingml/graphic.go:42-122`); `basic.docx`'s anchored `roundRect` + centered textbox converts with zero warnings (`docx_test.go:150-154`) | `document_text.mbt:649` raises `InvalidDocx` → fatal `DocxInvalid` (`convert.mbt:247,264`, `document_text.mbt:253-255`) | **missing** (hard failure) | high | [V] |
| Legacy VML `w:pict` | used as Fallback content (see AlternateContent row) | no `pict` handling anywhere in `convert/docx` | missing (reachable only via Fallback row fix) | high | [V] |
| Header/footer/table/figure marks, per-word run emission, tight/through wrap, shadows, footnote separators, vertical CJK, table styles, SECTIONPAGES | upstream implemented | documented gaps, tracked by parity harness (`docs/parity.md` DOCX row) | partial (tracked) | — | [D]+[I] `issues/open/20261109-parity-remaining.md` |
| DOCX page-count sample parity | `docx.md` fixture | sample added 2026-11-10 | open | — | [I] `issues/open/20261110-docx-page-count-sample.md` |

### XLSX (`convert/xlsx`, `convert/sheet`, `compat/xlsx` vs upstream `converter/xlsx`)

| Feature | Upstream evidence | Port evidence | Status | Conf. | Class |
|---|---|---|---|---|---|
| Column-width formula (ECMA 18.3.1.13), default/base column width, runs | `geom.go:11,114-129`; parse clamps `sheet.go:182-193`; `render.go:475-489` | `convert/xlsx/layout.mbt:71-113` byte-identical; fixture-verified (`compat/xlsx/verify-layout.mjs`) | implemented | high | [V] |
| Font-derived MDW (max digit width of workbook default font) | `geom.go:96-107` (`return 7` only when no face loaded); font-dependent behavior tested (`grid_test.go:74`, MDW 9 with M PLUS 1p) | hard-coded `7.0` at `convert/xlsx/plain.mbt:2976-2977` and `:3813-3820` even for `convert_plain_with_font`; the algorithm exists but is unwired (`convert/sheet/font_geometry.mbt:35-51` `font_mdw`, only used by `compat/font/fixture.mbt:53`) | **partial** (exact only for MDW-7 fonts, e.g. Calibri 11) | high | [V] |
| Default row height from font line metrics | `render.go:503-504` + `geom.go:133-142` (real Asc/Desc; estimated 0.9/0.25 only without fonts) | `plain.mbt:3009` always `(0.9+0.25)*size`, also when a font is supplied (drawing side does read real metrics, `convert/sheet/draw_existing.mbt:490-498`) | **partial** (with-font path) | high | [V] |
| Auto/fitted row heights, shrink-to-fit, General-`#` fitting | measured with real per-rune advances (`render.go:538-561`, `text.go:412-462`) | `plain.mbt:4594-4862,5044-5067` structurally identical but always with `sized_fallback_advance` (0.25/1.0/0.55 em, `convert/sheet/grid.mbt:10-19` = `fontset.go:267-283`) | **partial** (no-font contract fixture-verified; with-font estimate and with-font drawing use different advances → clipped/oversized rows possible) | high | [V] |
| No-font estimated path as a whole (the port's main path) | estimated-metrics warnings/marks (`xlsx.go:367`); compat fixtures generated with `NoSystemFonts: true, SystemFonts: true` (`compat/xlsx/generate_render_test.go:533,548,561,574`) | `convert_plain_no_fonts` matches: 4 parity harness xlsx form cases pass (`docs/parity.md`) | implemented | high | [V] |
| Indent step | `text.go:86,231` `(mdw+3)*0.75` | `plain.mbt:4772-4787` fixed `7.5` | partial (MDW-7 fonts only) | high | [V] |
| Grid autofit columns (CSV path), 50-digit cap, filter button | `grid.go:63-64,205-268` | `convert/sheet/grid.mbt:74-124` constants all match; font-aware variant `grid_geometry_with_font` exists unwired; no CSV-with-font pipeline | implemented / partial (font path unreachable) | high | [V] |
| Print view (`views=print`), header/footer, print geometry | `print.go`, `headerfooter.go` | absent; first parity diff (`docs/parity.md` XLSX row) | missing | high | [V]+[D] |
| Patterned fills, complex borders, exact number-format runs, charts as shared renderer | upstream implemented | documented gaps | partial (tracked) | — | [D] `docs/port-status.md` XLSX section; [I] `issues/open/20261109-parity-xlsx-print-view.md` |
| Multi-face font resolution/fallback/embedding | `xlsx.go:330-352`, `fontset.go:156-241` | single face by API design (`convert/all/all.mbt:93-118`) with upstream-matching per-char fallback | deliberate deviation (documented API shape) | high | [V] |

### Other formats and areas (reconciled; class per row)

| Area | Status vs upstream | Evidence / class |
|---|---|---|
| PDF converter (structure tags, marked content, JPX/mask corner cases, form-field URI actions, Type1/CFF, JBIG2, security handlers) | partial; 7/52 parity cases pass; tagged structure + MARK ops are the main diffs | [D] `docs/parity.md`; port-status “Converter gaps — PDF”. Public-API work excluded (branch above) |
| XDW (DocuWorks) | partial; annotation index, hidden text, corpus parity tracked; active fidelity gate elsewhere | [I] `issues/open/20261109-xdw-*.md`, `20261109-thumbnail-segment.md`; active branch excluded |
| Markdown | partial (reader-rule gaps: line boxes, headings, tables; page height, font count) | [D] `docs/parity.md` Markdown row; [I] `issues/open/20261109-parity-markdown-reader.md` |
| HTML reader mode | partial (resources `html/math.html`, readability, CSS, vertical writing) | [D] port-status Phase 3 |
| IDML/Visio/draw.io | partial, documented per-feature gaps; draw.io route/shape suites are the next fixture-backed targets | [D] port-status Phase 2, “Next steps” 2 |
| TIFF/PSD/EMF/WMF/AI | implemented-with-documented-subsets (JPEG/YCbCr TIFF, PSD compositing, EMF+ …) | [D] port-status “Converter gaps” |
| CAD (DXF/SXF/CGM/HP-GL/2, Jw_cad) | partial, documented subsets; P21/P2Z missing | [D] port-status |
| Audio cards, Parquet, CSV, image/svg/font | implemented with documented limits | [D] port-status |
| Form (`form/*`: tag, data, pdf, ooxml, docx/xlsx/pptx wrappers, pdfme, schema, textform) | largely ported; signing (`sign/` upstream = JCS+PEM) not ported; picture inlining, OOXML field `at`, strict-complete flags remain | [D] port-status “Form and print”; [V] for sign (branch `sign` at upstream; absent in port) |
| Print (IPP client/server, PWG/URF/PCLm) | implemented in-memory; real CUPS/UDP transports remain | [D] port-status “Form and print” |
| Viewer/browser/renderer | implemented; selection clipboard active elsewhere; PDF radial-gradient group compositing diff | [D] `docs/parity.md` PDF-viewer row |
| BDF segment reading, thumbnails, `text/markdownbdf`, `vector/{pdfbdf,psbdf}`, `raster/{imagebdf,ebitenginebdf}` (BDF rasterization), `docflow/`, `conformance/`, `cmd/` CLI | missing or intentionally out of scope in the MoonBit port (per-branch issues exist) | [I] `issues/open/20261109-{thumbnail-segment,vector-pdfbdf,vector-psbdf,parity-markdown-reader…}.md`, `20261109-native-convert-export.md`; `docflow/` has no port issue yet (`knowledge-inputs/` is upstream-side survey material only) |
| KiCad/Gerber/Excellon, MIDI/MML/MusicXML scores, EPUB | deliberately excluded | [D] `docs/verification-scope.md` |

## Top three implementation slices (recommended order)

Each slice is small, independently reviewable, uses only local gates
(`moon test`, unit tests; `npm run verify:local` subsets where relevant),
and ends with the acceptance tests written below. Issue documents for the
verified gaps are in `issues/open/` (see links).

### Slice 1 — PPTX: collect `cxnSp` and allow zero-extent open shapes

Issue: `issues/open/20261112-pptx-cxnsp.md` (reserved branch
`fix/20261112-pptx-connectors`; worktree `bdf-pptx-connectors-20261112`).

- Add `"cxnSp"` to `pptx_collect_shapes`
  (`convert/pptx/convert.mbt:750`). The emit path is already
  shape-generic: a `cxnSp` has no `txBody`, connectors' `fillRef idx="0"`
  yields no fill, `lnRef`→theme line fallback, presets and arrowheads all
  already exist (`presets_generated.mbt`, `paint.mbt`).
- Loosen the zero-extent skip at `convert/pptx/render_page.mbt:102-104`
  so a shape with one zero dimension is still drawn (upstream renders
  `a:ext cy="0"` connectors; `shape.go:158`).
- Do **not** add `stCxn`/`endCxn` re-routing: upstream does not have it.

Acceptance tests:

1. New whitebox test mirroring "PPTX rectangle outlines are stroked"
   (`convert_wbtest.mbt:1588`): minimal deck, one `p:cxnSp`,
   `prstGeom prst="line"`, off (100,100) → ext (200,0) — i.e. the flat
   case, `a:ln w="25400"` solid `C00000`, `<a:tailEnd type="triangle"/>`.
   After conversion, the body layer must contain one `StrokePath` whose
   path is that horizontal line, stroke color `C00000`, one filled
   triangle at the tail, and `warnings` must be empty.
2. Regression against the embedded upstream decks
   (`presentation_generated_wbtest.mbt` already decodes
   `basic.pptx`/`features.pptx`): for `basic.pptx` slide 3 the body layer
   gains exactly one red 2pt stroke with a filled triangle tail and no
   new warning; for `features.pptx` slide 5 all three connectors
   contribute ops (dashes and head/tail decorations), deterministically.
3. Existing suites stay green: `npm run test:phase15-pptx`, and no
   change to the passing parity case `pptx/basic#slide-1`.

### Slice 2 — DOCX: paragraph-mark run properties (`w:pPr/w:rPr`)

Issue: `issues/open/20261112-docx-mark-rpr.md`.

- In `convert/docx/document_text.mbt:2196` pass
  `docx_style_child(direct, "rPr")` instead of `None` into
  `self.styles.resolve_run(paragraph_style, …)` (the resolver already
  applies a direct node, `style_resolver.mbt:341`).
- Optionally the same session: merge the list level `rPr` into the label
  style (`numbering.mbt:227,258`) — upstream `model.go:923-940` — but that
  can also be a follow-up if the slice should stay minimal.

Acceptance tests:

1. Unit test on `DocxTextWalker::blocks`: body
   `<w:p><w:pPr><w:rPr><w:sz w:val="60"/></w:rPr></w:pPr></w:p>` (empty
   paragraph, document default 10pt) → `mark.size == 30.0`
   (mirrors `document_text_wbtest.mbt:131-165`).
2. Layout test through `docx_layout_paragraph`: the empty paragraph's
   line height uses the mark's size (≈ `30 * 1.2` pt), matching a
   run-only reference paragraph of the same size.
3. Upstream oracle: `wordproc/model.go:397` + `inline.go:491-499`; the
   existing inheritance test (`document_text_wbtest.mbt:163`) must stay
   green (style-chain case unchanged).

### Slice 3 — DOCX: `Requires`-aware `mc:AlternateContent` selection

Issue: `issues/open/20261112-docx-alternate-content.md`.

- Replace `docx_alternate_content`
  (`convert/docx/document_text.mbt:1001-1010`) with: pick the first
  `mc:Choice` whose every `Requires` prefix is in the supported set
  `["wps","wpg","wpc","wp14","w14","w15","a14","pic14"]` (mirror of
  upstream `wordproc/docx.go:43-45`); else the first `mc:Fallback`; else
  (as today) the first Choice.

Acceptance tests:

1. Fixture mirroring upstream `ooxml_test.go:97-112`:
   `Requires="wps"` Choice containing a `blip` picture + Fallback with
   run text "FALLBACK" → picture item extracted.
2. Same doc with `Requires="c14"` → the Fallback run text reaches the
   text index, and a Choice with an unsupported drawing plus a picture
   Fallback no longer raises `DocxInvalid` (today it does).
3. No synthetic `AlternateContent` in test data shares elements with the
   excluded private formats — all fixtures are handcrafted
   minimal parts, no upstream private content.

## Follow-up slices (verified, ranked after the top three)

4. DOCX non-image drawing degrade path
   (`issues/open/20261112-docx-drawing-degrade.md`): replace the fatal
   `docx_text_unsupported("drawing without an embedded image")`
   (`document_text.mbt:649`) with skip-plus-warning (keep the existing
   `txbxContent` text extraction), and keep long-term upstream parity as
   full `wps`/VML rendering tracked by the parity harness. Needs one
   design decision: warn vs. `DocxUnsupported` — upstream renders these,
   so a warning is only a stepping stone.
5. DOCX character-unit indents: apply the parsed
   `leftChars`/`rightChars`/`firstLineChars`/`hangingChars` fields
   (`paragraph_props.mbt:219-235`) in `layout.mbt`, scaled by the
   paragraph-mark size after slice 2 lands (upstream
   `inline.go:50-57`). Amended from docx-mark-rpr issue to avoid a
   duplicate umbrella issue.
6. XLSX font-derived MDW + row heights for `convert_plain_with_font`
   (`issues/open/20261112-xlsx-font-metrics.md`): wire the existing
   `font_mdw` into `plain.mbt:2976-2977, 3813-3820` and
   `xlsx_plain_indent`, and feed real face metrics (ascent/descent,
   advances) into default/fitted row heights; acceptance: Calibri-11
   fixtures unchanged (MDW still 7), a non-7-MDW fixture matches a newly
   generated upstream expectation. Lower office-user value than 1-3
   because the default no-font path already matches upstream.

## Not run / boundaries of this audit

- No tests were executed for this audit (it is read-only); all verdicts
  cite code. The acceptance tests above are proposals for the
  implementers.
- The upstream `go.sum` working-tree modification was ignored; evidence
  comes from tracked files and `git show a5e4d7a:…` handles.
- Sibling worktrees were only inspected via `git log`/`git status` to
  avoid duplicating active work; their contents were not used.
- Per-format deep audits beyond PPTX/DOCX/XLSX were not re-run; those
  rows are reconciled from the existing docs and issues that cite code
  and fixtures, as labeled.
- Upstream's `docflow/`, `conformance/`, `cmd/`, `packages/` trees have
  no dedicated port issues yet except where listed; they are candidates
  for the next audit round, not evidence of ported behavior.
