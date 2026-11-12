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

The pure Viewer ellipse appears discontinuous. The tested pen is solid.
The locally decompressed ellipse EMF contains `EXTCREATEPEN` with style
`0x00010000` (`PS_GEOMETRIC | PS_SOLID`), width 6 and COLORREF `0xcc9900`
(`#0099cc`). Its annotation property `ARCATT_LINE` was 0. A valid synthetic
variant with `ARCATT_LINE` 1 (correct stored size and trailer check, accepted by
the Viewer) rendered pixel-identically (126 stroke pixels, 44 components, a
12-pixel apex gap in both). This one controlled attribute change did not
change the observed discontinuity.

Curve-following controls distinguish the appearances. A synthetic solid ellipse
with the same box and a 2-pixel outline forms one connected stroke component; a
12-dash control forms 12. The Viewer's ellipse forms 44 components and its
topmost row has a 12-pixel gap in the middle of the apex, where a solid ellipse
is continuous. The extracted EMF rendered by an independent renderer
(LibreOffice) forms one connected solid ellipse (909 stroke pixels, continuous
apex). The converter also emits a solid stroke with an empty dash array.

The observations favor a rendering-path difference and provide no reason to
change the converter's current solid-pen interpretation. They do not exclude
every other XDW attribute or renderer interaction. The exact cause (Wine GDI versus the Viewer's EMF renderer) is
not isolated; a different renderer drawing the EMF solid is not by itself proof
of a Viewer bug. Do not change the converter to match the Viewer's dashes
without a controlled rendering-path comparison. Regression tests in
`convert/metafile/emf_wbtest.mbt` now cover both `EXTCREATEPEN` PS_DASH (emits a
dash) and PS_GEOMETRIC | PS_SOLID (emits none).

## Font family

The annotation EMF's `LOGFONT` face is a NUL-terminated fixed `LF_FACESIZE`
buffer. The converter decoded the whole buffer, so the BDF font family carried
25 trailing NULs (`"ＭＳ ゴシック\u0000…"`). A browser cannot match that name
and falls back. The face decoder now stops at the first NUL; the shared UTF-16
decoder still preserves an explicit trailing NUL for `EXTTEXTOUTW`. The BDF
family is `"ＭＳ ゴシック"`, and regressions cover the face split, the shared
decoder, and the encoded object's font table.

The browser environment does not have MS Gothic; fontconfig resolves the family
to Noto Sans Mono CJK JP. The candidate's glyph shapes therefore still differ
from the Viewer, whose actual selected font is not independently confirmed.
The text advance is unchanged and the first line's measured width is close
(about 188 px at nominal 75 dpi versus 189 px in the Viewer). The
candidate's text colour is blue, the same as the Viewer's text; the cyan in the
Viewer page is not the text line sampled here. The remaining glyph difference
may involve font selection and rasterization; these remain uncontrolled.

## Sticky note

The stored sticky-note EMF (record 14, attribute 7) draws a `#999999` shadow
rectangle (6,6)-(468,180), then a `#80ffff` note rectangle (0,0)-(461,173) with
a `#666666` pen width 1, then the text. The note's childdim is 39.53x15.19 mm;
the EMF window is 467x179 units, so the note rectangle is 39.02x14.68 mm and the
shadow's visible border is the 6-unit (0.51 mm) margin.

The BDF fills the shadow (`#999999`) before the note (`#80ffff`), and its
clip rectangle is the childdim (112.054x43.058 pt = 39.53x15.19 mm).
In the sampled Viewer image, the exact-color predicate found no `#999999`
pixels, a fill bbox of 115x40 px and an edge bbox of 117x42 px. At nominal
75 dpi the predicted fill is 115.2x43.3 px and childdim is 116.7x44.9 px:
**the measured height does not match either prediction**. The candidate at
96 dpi has a 146x53 px exact-color fill bbox and 146 exact-color shadow pixels.
These bboxes depend on antialiasing, crop and color thresholds, not only shape
geometry; the two captures are not scale-matched.

The stored shadow and BDF paint order agree, but that alone does not prove the
converter's output is correct. A Viewer clip/redraw convention, subpixel pen
rasterization, crop/alignment, or converter behavior may explain the observed
edge/shadow difference. No converter change is justified by this measurement.
Next, use matched-scale captures with verified local bounds and inspect alpha/
near-color pixels, then isolate the shadow/clip with a controlled drawing.
Do not add a sticky-note-specific clip or minimum pen width merely to fit this
one screenshot. Pure fidelity remains NOT_RUN.

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
2. Resolve the sticky-note height discrepancy and shadow behavior with
   matched-scale, verified-bounds captures before assigning a cause.
3. Identify and match the actual fonts selected by both rendering paths before
   attributing remaining glyph differences to the converter.
4. Only then add the smallest converter regression/fix.

No proprietary screenshots or extracted corpus bytes are included in this
increment, and no additional DocuWorks product or SDK was acquired.
