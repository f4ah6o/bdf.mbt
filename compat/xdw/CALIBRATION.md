# Genuine Viewer calibration observations (2026-11-12)

Diagnostic evidence, not a fidelity PASS and not a converter fix. Screenshots,
input extracts and capture manifests are retained locally and are not committed.
The sample is `site/samples/demo.xdw`, SHA256
`850d855590cc340a345ae994824d17fa3489f7a26e60208340ba190ec138b0ac`.

## Environment and geometry

DocuWorks Viewer Light 10.1.1 ran in an isolated WineHQ 11.0 WoW64 environment.
Its Page Properties independently reported one page, 210 × 148 mm.
At the displayed 100% zoom, the observed white interior was 618 × 435 pixels.
Including an assumed one-pixel border on each side gives 620 × 437 pixels:

- horizontal effective scale: `620 / 210 * 25.4 = 74.99 dpi`;
- vertical effective scale: `437 / 148 * 25.4 = 75.00 dpi`.

This is consistent with approximately 75 dpi after pixel rounding in this
particular environment. It does not establish that every Viewer environment
uses 75 dpi or that the assumed border belongs to document content.
The 133% trial was horizontally clipped, so it is not a full-page oracle.
Its roughly 581–582-pixel vertical extent is only a scale diagnostic.

The candidate at 96 dpi was 794 × 560 pixels. Do not resample either result to
force an exact comparison or copy the UI zoom value into oracle DPI metadata.
Separate source page dimensions, floor/ceil rounding, border inclusion and
clipping before using a strict pixel comparison. System fallback fonts also
remain uncontrolled. Genuine comparison through `verify.mjs` remains NOT_RUN.

## Ellipse investigation

The pure Viewer ellipse appeared broken/thinner than the candidate's solid
outline. Selected horizontal scanlines contain separated colour runs; this is
**not proof of a dashed pen**. A solid ellipse can intersect a scanline in two
separate runs, and antialiasing, pixel alignment and the colour threshold alter
those runs. The clipped 133% image cannot establish full-page equivalence.

The locally decompressed ellipse EMF contains `EXTCREATEPEN` with style
`0x00010000` (`PS_GEOMETRIC | PS_SOLID`), width 6 and COLORREF `0xcc9900`
(`#0099cc`). Its annotation property `ARCATT_LINE` was 0. The rectangle had
`RECTATT_LINE` 0 as well. The converter handles `EXTCREATEPEN` and emits an empty
dash array for this solid pen. These observations do not yet justify changing
that conversion.

## Diagnostic tool and next increment

`node compat/xdw/measure.mjs IMAGE.png --page-mm 210x148 --json` reports a
**heuristic** page box and effective scale. `--page-rect x0,y0,x1,y1` supplies
manually checked inclusive bounds. Automatic detection picks the largest
connected near-white region and assumes a one-pixel border; white UI panels,
content touching edges or clipped pages can invalidate that assumption.
`--scan Y --stroke R,G,B` records colour runs, not a dash classifier.
PNG inputs are bounded to 64 MiB and 20 million pixels; interlaced, duplicate
header and incomplete files are rejected before decoding.

Next steps:
1. Obtain an unclipped pure image with independently checked content-only bounds.
2. Compare the ellipse along its curve or across a sequence of matched rows,
   including a synthetic solid-ellipse control. Control pixel scale and colour
   threshold before deciding whether the apparent gaps reflect a line style.
3. If a genuine style difference remains, use a valid synthetic XDW variant
   changing one annotation attribute at a time. Validate the container in the
   pure Viewer; do not infer correctness from the candidate alone.
4. Only then add the smallest converter regression/fix. Keep Latin font fallback
   and sticky-note edge/shadow observations separate until similarly controlled.

No proprietary screenshots or extracted corpus bytes are included in this
increment, and no additional DocuWorks product or SDK was acquired.
