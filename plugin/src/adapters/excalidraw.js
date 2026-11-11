// The Excalidraw adapter. It reads the JSON scene format Excalidraw's editor
// saves (`{ type: "excalidraw", elements: [...] }`, plus the plain
// `{ elements: [...] }` documents some tools emit), validates it within the
// documented limits, and turns each drawable element into the shared diagram
// primitive vocabulary. It never loads or embeds linked content, never renders
// freehand sketches, images or frames, and never renders deleted elements:
// those are skipped with a one-time warning per kind instead.
//
// Fidelity notes (deliberate, all warned when the scene uses them):
//   * opacity is the editor's percent scale (0..100), default 100;
//   * decomposed geometry (arrow shaft + heads, multi-line text) rotates as
//     one unit because every synthesized primitive carries the SAME original
//     element pivot;
//   * text advance is estimated per codepoint and is CJK-aware (wide
//     codepoints count 1.0 em, everything else 0.6 em);
//   * TEXT ALIGNMENT follows the shared encoder's anchor semantics, ONE
//     convention per align op even when a line OVERFLOWS the element box:
//     the emitted x is the glyph LEFT edge (align left = box start), the
//     glyph CENTER (align center = box center: overflowing lines stick out
//     symmetrically on both sides), or the glyph RIGHT edge (align right =
//     box right edge: overflowing lines stick out to the LEFT). Page
//     fitting mirrors the same align-aware band math, so ink placement and
//     the encoder's bands always agree.
//   * elbow/curved chains render as straight segments.
//
// Worker-safety: only ECMAScript built-ins reachable in a worker are used
// (TextDecoder); there is no DOM, no Node API, no eval and no dynamic import,
// so the descriptor can be imported into a worker bundle unchanged.

import { defineFormatPlugin, errorText } from "../contract.js";
import { acceptedParams, noPassword } from "../adapter-options.js";
import { encodeDiagram, strokedPolylineExtent } from "../diagram-bdf.js";

export const EXCALIDRAW_FORMAT_NAME = "excalidraw";
export const EXCALIDRAW_EXTENSIONS = [".excalidraw", ".excalidraw.json"];
export const EXCALIDRAW_DESCRIPTION =
  "Excalidraw scene (whiteboard rectangles, ellipses, diamonds, lines, arrows and text as vector primitives)";

// Input and element limits.
export const EXCALIDRAW_INPUT_LIMIT = 8 * 1024 * 1024; // 8 MiB
const ELEMENT_LIMIT = 10000;
const POINT_LIMIT = 500; // per line/arrow element
const COORD_LIMIT = 1e6;
const PAGE_LIMIT = 16777216; // pt, the encoder's own page limit
const PAGE_MARGIN = 16; // pt

// Generated-content limits, checked BEFORE building so oversized (but well
// formed) scenes fail fast without allocating the amplified geometry. They
// mirror the shared encoder's own caps, with adapter-owned error messages.
const PRIMITIVES_LIMIT = 20000;
const TOTAL_POINT_LIMIT = 100000;
const TOTAL_TEXT_CHAR_LIMIT = 200000;
const ELEMENT_TEXT_LIMIT = 100000; // one element's text, fails fast on giant strings
const LINE_TEXT_LIMIT = 4096; // the shared encoder's per-primitive string limit

// The shared encoder's own validity bounds, pre-bound here so user-facing
// errors carry adapter messages instead of surfacing from the encoder.
const STROKE_WIDTH_LIMIT = 10000;
const FONT_SIZE_LIMIT = 1000;
const ANGLE_LIMIT = 1e6;

const TEXT_LINE_HEIGHT = 1.25; // documented: line i sits at y + i * fontSize * 1.25
const ARROWHEAD_SIZE = 10; // head length = 10 * strokeWidth (documented formula)
const ARROWHEAD_SPAN = 0.5; // "arrow" head base half-width = 0.5 * head length
const TRIANGLEHEAD_SPAN = 0.75; // "triangle" head: same length, wider base
const ROUND_LIMIT = 16; // rect corner radius cap
const EMPTY_PAGE = { width: 640, height: 480 };

// One-time warnings; each is emitted at most once per conversion, in first
// occurrence order, and the wording is fixed so the list is deterministic.
const W_ROUND = "rectangle corner rounding is approximated";
const W_CUSTOM_FONT = "custom font families are out of scope, text renders in Helvetica";
const W_HATCH = "hand-drawn hatch fills are out of scope, shapes render without fill";
const W_COLOR = "unsupported color values are out of scope, rendered as #1e1e1e";
const W_IMAGE = "embedded images are not rendered (image elements are out of scope)";
const W_FREEDRAW = "freedraw strokes are out of scope, elements are skipped";
const W_FRAME = "frame elements are not rendered";
const W_NO_TYPE = "element type unsupported, skipped";
const W_EMPTY = "empty scene";
const W_OPACITY_CLAMP = "opacity values above 100 are clamped to 100";
const W_ELBOW = "elbow and curved arrows are approximated with straight segments";
const W_VERTICAL_ALIGN = "vertical alignment approximated";
const W_HYPERLINK = "element hyperlinks are not rendered";
const W_FRAME_CLIP = "frame clipping is not applied";

const DEFAULT_COLOR = "#1e1e1e"; // the editor's default stroke color
const DEFAULT_STROKE_WIDTH = 2;
const DEFAULT_FONT_SIZE = 20;

///|
// A thrown error with a stable `code` ("invalid-input" | "too-large" |
// "invalid-options"), like every other adapter failure.
function failure(message, code) {
  const error = new Error(`excalidraw: ${message}`);
  error.name = "ConvertError";
  error.code = code;
  return error;
}

function isPlainObject(value) {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function preview(value) {
  if (typeof value === "bigint") return String(value);
  if (typeof value === "object" && value !== null) return Array.isArray(value) ? "an array" : "an object";
  return JSON.stringify(value) ?? String(value);
}

function elementLabel(element, index) {
  const id = element?.id;
  return typeof id === "string" && id !== "" ? `element "${id}"` : `element ${index}`;
}

// A byte view the TextDecoder accepts; anything that cannot be a byte
// sequence at all is an input problem, not a content verdict.
function byteView(bytes, what) {
  if (bytes instanceof Uint8Array) return bytes;
  if (bytes instanceof ArrayBuffer) return new Uint8Array(bytes);
  if (ArrayBuffer.isView(bytes)) {
    return new Uint8Array(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  }
  throw failure(`${what} must be a byte sequence`, "invalid-input");
}

// ------------------------------------------------------------- detection ---

///|
// The accepted document shape. Two discriminators, no more:
//   (a) `type === "excalidraw"` with an `elements` array: a real scene;
//   (b) a bare `elements` array without any `type` at all (empty, or with a
//       plain first element carrying a string type) -- the LOOSE FALLBACK for
//       files saved without the type tag; detection never claims documents
//       that declare some other format.
function acceptsDocument(value) {
  if (!isPlainObject(value)) return false;
  const elements = value.elements;
  if (!Array.isArray(elements)) return false;
  if (value.type === "excalidraw") return true; // (a)
  if (value.type !== undefined && value.type !== null) return false; // conflicting type
  if (elements.length === 0) return true; // (b), empty scene
  return isPlainObject(elements[0]) && typeof elements[0].type === "string"; // (b)
}

// ---------------------------------------------------------------- colors ---

function parseColor(raw) {
  // "#RRGGBB", "#RRGGBBAA", "transparent" or null (unsupported).
  if (typeof raw !== "string") return null;
  const value = raw.toLowerCase();
  if (value === "transparent") return { r: 0, g: 0, b: 0, a: 0 };
  if (!/^#[0-9a-f]{6}([0-9a-f]{2})?$/.test(value)) return null;
  const r = parseInt(value.slice(1, 3), 16);
  const g = parseInt(value.slice(3, 5), 16);
  const b = parseInt(value.slice(5, 7), 16);
  const a = value.length === 9 ? parseInt(value.slice(7, 9), 16) : 255;
  return { r, g, b, a };
}

///|
// Color field read. Missing values are TRANSPARENT for fills (the editor's
// real default: no background paint) and #1e1e1e for strokes; anything the
// parser does not recognize warns once and falls back to #1e1e1e.
function readColor(ctx, raw, { missing = "default" } = {}) {
  if (raw === undefined || raw === null) {
    return missing === "transparent" ? { r: 0, g: 0, b: 0, a: 0 } : parseColor(DEFAULT_COLOR);
  }
  const parsed = parseColor(raw);
  if (parsed === null) {
    ctx.warn(W_COLOR);
    return parseColor(DEFAULT_COLOR);
  }
  return parsed;
}

// ---------------------------------------------------------------- values ---

function requireNumber(ctx, element, index, key, { positive = false } = {}) {
  const value = element[key];
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw failure(
      `${elementLabel(element, index)}: ${key} must be a finite number, not ${preview(value)}`,
      "invalid-input",
    );
  }
  if (positive && value <= 0) {
    throw failure(`${elementLabel(element, index)}: ${key} must be > 0, not ${value}`, "invalid-input");
  }
  return value;
}

// Excalidraw stores coordinates in scene space; the shared encoder accepts
// |coordinate| <= 1e6, so the same bound is enforced on the input with a
// precise message instead of surfacing from the encoder.
function requireCoordinate(ctx, element, index, key) {
  const value = requireNumber(ctx, element, index, key);
  if (Math.abs(value) > COORD_LIMIT) {
    throw failure(
      `${elementLabel(element, index)}: ${key} ${value} is outside the +/-${COORD_LIMIT} coordinate range`,
      "too-large",
    );
  }
  return value;
}

function optionalNumber(element, index, key, fallback) {
  const value = element[key];
  if (value === undefined || value === null) return fallback;
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw failure(
      `${elementLabel(element, index)}: ${key} must be a finite number, not ${preview(value)}`,
      "invalid-input",
    );
  }
  return value;
}

///|
// Opacity: ALWAYS the editor's percent scale, 0..100. Missing means 100
// (fully opaque, no alpha op). Values above 100 clamp to 100 with a one-time
// warning; anything negative is invalid input.
function opacityOf(ctx, element, index) {
  const raw = element.opacity;
  if (raw === undefined || raw === null) return 1;
  if (typeof raw !== "number" || !Number.isFinite(raw)) {
    throw failure(
      `${elementLabel(element, index)}: opacity must be a finite percent value 0..100, not ${preview(raw)}`,
      "invalid-input",
    );
  }
  if (raw < 0) {
    throw failure(
      `${elementLabel(element, index)}: opacity must be a percent value 0..100, not ${raw}`,
      "invalid-input",
    );
  }
  if (raw > 100) {
    ctx.warn(W_OPACITY_CLAMP);
    return 1;
  }
  return raw / 100;
}

// ---------------------------------------------------------------- style ---

function strokeWidthOf(ctx, element, index) {
  const raw = element.strokeWidth;
  if (raw === undefined || raw === null) return DEFAULT_STROKE_WIDTH;
  if (typeof raw !== "number" || !Number.isFinite(raw) || raw <= 0 || raw > STROKE_WIDTH_LIMIT) {
    throw failure(
      `${elementLabel(element, index)}: strokeWidth must be a positive finite number up to ${STROKE_WIDTH_LIMIT}, not ${preview(raw)}`,
      "invalid-input",
    );
  }
  return raw;
}

function dashOf(ctx, element, strokeWidth) {
  const style = element.strokeStyle;
  if (style === undefined || style === null || style === "solid") {
    return null;
  }
  // Documented: the base pattern is scaled by strokeWidth / 2.
  const scale = strokeWidth / 2;
  if (style === "dashed") return [8 * scale, 8 * scale];
  if (style === "dotted") return [1.5 * scale, 4.5 * scale];
  ctx.warn(`unsupported stroke style "${String(style)}": rendered solid`);
  return null;
}

function isHatchStyle(style) {
  return typeof style === "string" && ["hachure", "cross-hatch", "zigzag-vector", "zigzag"].includes(style);
}

function fillOf(ctx, element) {
  const style = element.fillStyle;
  if (style === undefined || style === null || style === "solid") {
    return true; // solid: use the (possibly transparent) background color
  }
  if (isHatchStyle(style)) {
    ctx.warn(W_HATCH);
    return false; // hand-drawn hatching is out of scope: no fill
  }
  ctx.warn(`unsupported fill style "${String(style)}": shape rendered without fill`);
  return false;
}

///|
// Everything an element contributes to its primitives, computed once per
// element. `stroke`/`fill` are null when the layer paints nothing.
function styleOf(ctx, element, index) {
  const strokeWidth = strokeWidthOf(ctx, element, index);
  const dash = dashOf(ctx, element, strokeWidth);
  const opacity = opacityOf(ctx, element, index);
  const angle = optionalNumber(element, index, "angle", 0);
  if (Math.abs(angle) > ANGLE_LIMIT) {
    throw failure(
      `${elementLabel(element, index)}: angle must be within +/-${ANGLE_LIMIT} radians, not ${angle}`,
      "invalid-input",
    );
  }
  const strokeColor = readColor(ctx, element.strokeColor, { missing: "default" });
  const solidFill = fillOf(ctx, element);
  const fillColor = solidFill ? readColor(ctx, element.backgroundColor, { missing: "transparent" }) : null;
  return {
    strokeWidth,
    dash,
    opacity,
    angle,
    stroke: strokeColor.a > 0 ? strokeColor : null,
    fill: fillColor !== null && fillColor.a > 0 ? fillColor : null,
  };
}

function applyStyle(prim, style, { stroked = true, filled = true } = {}) {
  if (stroked) {
    prim.stroke = style.stroke;
    prim.strokeWidth = style.strokeWidth;
    if (style.dash !== null) prim.dash = style.dash;
  }
  if (filled) {
    prim.fill = style.fill;
  }
  if (style.opacity !== 1) prim.opacity = style.opacity;
  if (style.angle !== 0) prim.angle = style.angle;
  return prim;
}

// ------------------------------------------------------------- geometry ---

///|
// The COSMETIC extent of one primitive: the stroke-inclusive ink footprint
// the page must contain. Fill-only shapes and text cover their raw geometry;
// stroked rect/ellipse rounds grow by half the stroke width, and stroked
// chains (lines, arrows, diamonds) use the shared encoder's own
// strokedPolylineExtent -- half-width PLUS miter protrusions -- so page
// fitting can never be tighter than the ink the encoder actually draws.
function primExtent(prim) {
  const stroked = prim.stroke !== undefined && prim.stroke !== null;
  let box;
  if (prim.kind === "rect") {
    box = [prim.x, prim.y, prim.x + prim.w, prim.y + prim.h];
  } else if (prim.kind === "ellipse") {
    box = [prim.cx - prim.rx, prim.cy - prim.ry, prim.cx + prim.rx, prim.cy + prim.ry];
  } else if (prim.kind === "text") {
    // The band is align-aware, exactly like the shared encoder's:
    // left [x, x+a], center [x-a/2, x+a/2], right [x-a, x]. An overflowing
    // line grows the band past the box edge per the documented rule.
    const advance = prim.advance ?? prim.fontSize * 0.6 * prim.text.length;
    const align = prim.align ?? "left";
    const x0 = align === "center"
      ? prim.x - advance / 2
      : align === "right" ? prim.x - advance : prim.x;
    const x1 = align === "center"
      ? prim.x + advance / 2
      : align === "right" ? prim.x : prim.x + advance;
    box = [x0, prim.y, x1, prim.y + prim.fontSize * TEXT_LINE_HEIGHT];
  } else {
    let x0 = Infinity;
    let y0 = Infinity;
    let x1 = -Infinity;
    let y1 = -Infinity;
    for (const [px, py] of prim.points) {
      if (px < x0) x0 = px;
      if (py < y0) y0 = py;
      if (px > x1) x1 = px;
      if (py > y1) y1 = py;
    }
    box = [x0, y0, x1, y1];
  }
  let cosmetic = box;
  if (stroked && (prim.kind === "polyline" || prim.kind === "polygon")) {
    const extent = strokedPolylineExtent(
      prim.points,
      prim.strokeWidth ?? DEFAULT_STROKE_WIDTH,
      prim.kind === "polygon",
    );
    cosmetic = [extent.x, extent.y, extent.x + extent.w, extent.y + extent.h];
  } else if (stroked) {
    const pad = (prim.strokeWidth ?? DEFAULT_STROKE_WIDTH) / 2;
    cosmetic = [box[0] - pad, box[1] - pad, box[2] + pad, box[3] + pad];
  }
  return {
    x0: cosmetic[0],
    y0: cosmetic[1],
    x1: cosmetic[2],
    y1: cosmetic[3],
    pivot: prim.pivot ?? [(box[0] + box[2]) / 2, (box[1] + box[3]) / 2],
  };
}

function pointsPivot(points) {
  let minX = Infinity;
  let minY = Infinity;
  let maxX = -Infinity;
  let maxY = -Infinity;
  for (const [px, py] of points) {
    if (px < minX) minX = px;
    if (py < minY) minY = py;
    if (px > maxX) maxX = px;
    if (py > maxY) maxY = py;
  }
  return [(minX + maxX) / 2, (minY + maxY) / 2];
}

///|
// CJK-aware advance estimate: wide codepoints count 1.0 em (roughly the full
// width a font gives them), everything else 0.6 em. The value rides the text
// primitive's `advance` field so the encoder's band and page fitting agree.
function charWidthEm(code) {
  if ((code >= 0x1100 && code <= 0x115f) // Hangul Jamo
    || (code >= 0x2e80 && code <= 0xa4cf) // CJK radicals .. Yi
    || (code >= 0xac00 && code <= 0xd7a3) // Hangul syllables
    || (code >= 0xf900 && code <= 0xfaff) // CJK compat ideographs
    || (code >= 0xfe30 && code <= 0xfe4f) // CJK compat forms
    || (code >= 0xff00 && code <= 0xff60) // fullwidth forms
    || (code >= 0xffe0 && code <= 0xffe6) // fullwidth signs
    || (code >= 0x20000 && code <= 0x3fffd)) {
    return 1;
  }
  return 0.6;
}

function estimateAdvance(text, fontSize) {
  let ems = 0;
  for (const ch of text) {
    ems += charWidthEm(ch.codePointAt(0));
  }
  return fontSize * ems;
}

///|
// The head verdict for one arrow end without warnings, shared by the early
// counting pass and the real conversion:
//   absent  : the end's default -- drawn for the END key only (the editor's
//            arrow), no head for the START key;
//   null/"none": no head (explicit);
//   "arrow"/"triangle": their shapes;
//   anything else: falls back to "arrow" geometry, with a warning in the
//            real pass (this function stays pure for counting).
function resolveHead(raw, isEnd) {
  if (raw === undefined) return isEnd ? "arrow" : "none";
  if (raw === null || raw === "none") return "none";
  if (raw === "arrow") return "arrow";
  if (raw === "triangle") return "triangle";
  return "arrow-fallback";
}

function headKindFor(ctx, element, key, legacyKey, isEnd) {
  const raw = element[key] !== undefined ? element[key] : element[legacyKey];
  const resolved = resolveHead(raw, isEnd);
  if (resolved === "arrow-fallback") {
    ctx.warn(`unsupported ${isEnd ? "end" : "start"} arrowhead "${String(raw)}": rendered as an "arrow" head`);
  }
  return resolved;
}

function headCountOf(element) {
  const end = resolveHead(element.endArrowhead !== undefined ? element.endArrowhead : element.arrowheadEnd, true);
  const start = resolveHead(element.startArrowhead !== undefined ? element.startArrowhead : element.arrowheadStart, false);
  return (end === "none" ? 0 : 1) + (start === "none" ? 0 : 1);
}

///|
// A filled head triangle. `tip` is the endpoint the head attaches to, `ux/uy`
// the unit vector pointing INTO the shaft (so the base lays on the shaft
// side), and the base half-width is a fraction of the head length:
// "arrow" = 0.5, "triangle" = 0.75 (wider, same length).
function headPolygon(tipX, tipY, ux, uy, strokeWidth, kind, pivotX, pivotY) {
  const size = ARROWHEAD_SIZE * strokeWidth;
  const span = (kind === "triangle" ? TRIANGLEHEAD_SPAN : ARROWHEAD_SPAN) * size;
  const bx = tipX + size * ux;
  const by = tipY + size * uy;
  const nx = -uy;
  const ny = ux;
  return {
    kind: "polygon",
    pivot: [pivotX, pivotY],
    points: [
      [tipX, tipY],
      [bx + span * nx, by + span * ny],
      [bx - span * nx, by - span * ny],
    ],
  };
}

// ------------------------------------------------------------ elements ----

///|
// Convert one element into primitives. Unsupported kinds warn once and are
// skipped; deleted elements vanish silently. Primitives append in array (z)
// order; every synthesized primitive of an element carries the element's own
// pivot so rotation keeps decomposed parts attached.
function convertElement(ctx, element, index) {
  if (element.isDeleted) {
    return; // deleted content never renders, silently
  }
  if (typeof element.link === "string" && element.link !== "") {
    ctx.warn(W_HYPERLINK);
  }
  if (typeof element.frameId === "string" && element.frameId !== "") {
    ctx.warn(W_FRAME_CLIP);
  }
  const type = element.type;
  if (typeof type !== "string") {
    ctx.warn(W_NO_TYPE);
    return;
  }
  switch (type) {
    case "rectangle": return rectangle(ctx, element, index);
    case "ellipse": return ellipse(ctx, element, index);
    case "diamond": return diamond(ctx, element, index);
    case "line": return lineOrArrow(ctx, element, index, false);
    case "arrow": return lineOrArrow(ctx, element, index, true);
    case "text": return text(ctx, element, index);
    case "image":
      ctx.warn(W_IMAGE);
      return; // embedded images are never fetched or embedded
    case "freedraw":
      ctx.warn(W_FREEDRAW);
      return; // freehand strokes are out of scope
    case "frame":
      ctx.warn(W_FRAME);
      return; // containers are not rendered
    default:
      ctx.warn(`unsupported element type "${type}": element skipped`);
      return;
  }
}

function boxEdges(ctx, element, index) {
  const x = requireCoordinate(ctx, element, index, "x");
  const y = requireCoordinate(ctx, element, index, "y");
  const w = requireCoordinate(ctx, element, index, "width");
  const h = requireCoordinate(ctx, element, index, "height");
  return { x: Math.min(x, x + w), y: Math.min(y, y + h), w: Math.abs(w), h: Math.abs(h) };
}

function rectangle(ctx, element, index) {
  const { x, y, w, h } = boxEdges(ctx, element, index);
  if (w === 0 || h === 0) return; // degenerate boxes paint nothing
  const style = styleOf(ctx, element, index);
  const prim = applyStyle(
    { kind: "rect", x, y, w, h, pivot: [x + w / 2, y + h / 2] },
    style,
  );
  if (element.roundness !== undefined && element.roundness !== null) {
    // Corners are rounded with min(16, smallest side / 4): the hand-drawn
    // roundness Excalidraw draws is out of scope, so the radius is derived
    // from the shape alone.
    prim.rounded = Math.min(ROUND_LIMIT, Math.min(w, h) / 4);
    ctx.warn(W_ROUND);
  }
  ctx.paint(prim);
}

function ellipse(ctx, element, index) {
  const { x, y, w, h } = boxEdges(ctx, element, index);
  if (w === 0 || h === 0) return;
  const style = styleOf(ctx, element, index);
  ctx.paint(applyStyle({
    kind: "ellipse",
    pivot: [x + w / 2, y + h / 2],
    cx: x + w / 2,
    cy: y + h / 2,
    rx: w / 2,
    ry: h / 2,
  }, style));
}

function diamond(ctx, element, index) {
  const { x, y, w, h } = boxEdges(ctx, element, index);
  if (w === 0 || h === 0) return;
  const style = styleOf(ctx, element, index);
  // An Excalidraw diamond inscribes in its box: the four side midpoints.
  const points = [
    [x + w / 2, y],
    [x + w, y + h / 2],
    [x + w / 2, y + h],
    [x, y + h / 2],
  ];
  ctx.paint(applyStyle({ kind: "polygon", pivot: [x + w / 2, y + h / 2], points }, style));
}

///|
// line/arrow points are relative to the element x/y; both the delta pair and
// the resulting absolute coordinate are validated (the absolute one against
// the shared coordinate range).
function absolutePoints(ctx, element, index, x, y) {
  const raw = element.points;
  if (!Array.isArray(raw)) {
    throw failure(
      `${elementLabel(element, index)}: points must be an array, not ${preview(raw)}`,
      "invalid-input",
    );
  }
  if (raw.length > POINT_LIMIT) {
    throw failure(
      `${elementLabel(element, index)}: ${raw.length} points exceed the ${POINT_LIMIT}-point-per-element limit`,
      "too-large",
    );
  }
  if (raw.length < 2) {
    throw failure(
      `${elementLabel(element, index)}: a line needs at least two points, not ${raw.length}`,
      "invalid-input",
    );
  }
  return raw.map((point, pointIndex) => {
    if (!Array.isArray(point) || point.length < 2 || typeof point[0] !== "number"
      || typeof point[1] !== "number" || !Number.isFinite(point[0]) || !Number.isFinite(point[1])) {
      throw failure(
        `${elementLabel(element, index)}: point ${pointIndex} must be a pair of finite numbers`,
        "invalid-input",
      );
    }
    const ax = x + point[0];
    const ay = y + point[1];
    if (Math.abs(ax) > COORD_LIMIT || Math.abs(ay) > COORD_LIMIT) {
      throw failure(
        `${elementLabel(element, index)}: point ${pointIndex} (${ax}, ${ay}) is outside the +/-${COORD_LIMIT} coordinate range`,
        "too-large",
      );
    }
    return [ax, ay];
  });
}

function lineOrArrow(ctx, element, index, isArrow) {
  const x = requireCoordinate(ctx, element, index, "x");
  const y = requireCoordinate(ctx, element, index, "y");
  const points = absolutePoints(ctx, element, index, x, y);
  const style = styleOf(ctx, element, index);

  // Elbow/curved chains are approximated with straight segments: anything
  // longer than two segments, or a rounded (curved) multi-segment chain.
  if (points.length > 3 || (points.length > 2 && element.roundness !== undefined && element.roundness !== null)) {
    ctx.warn(W_ELBOW);
  }

  // ONE pivot for the whole element: shaft and any heads rotate as a unit.
  const [pivotX, pivotY] = pointsPivot(points);
  ctx.paint(applyStyle(
    { kind: "polyline", pivot: [pivotX, pivotY], points },
    style,
    { filled: false }, // an open chain paints a stroke only
  ));
  if (!isArrow || style.stroke === null) return; // heads are fill-only

  const endKind = headKindFor(ctx, element, "endArrowhead", "arrowheadEnd", true);
  const startKind = headKindFor(ctx, element, "startArrowhead", "arrowheadStart", false);
  const last = points[points.length - 1];
  const beforeLast = points[points.length - 2];
  const first = points[0];
  const second = points[1];

  if (endKind !== "none") {
    // end head: tip is the last point, pointing back along the final segment
    const dx = last[0] - beforeLast[0];
    const dy = last[1] - beforeLast[1];
    const length = Math.hypot(dx, dy);
    if (length > 0) {
      const head = headPolygon(last[0], last[1], -dx / length, -dy / length, style.strokeWidth, endKind, pivotX, pivotY);
      head.fill = style.stroke;
      if (style.opacity !== 1) head.opacity = style.opacity;
      if (style.angle !== 0) head.angle = style.angle;
      ctx.paint(head);
    }
  }
  if (startKind !== "none") {
    // start head: tip is the first point, pointing into the shaft
    const dx = second[0] - first[0];
    const dy = second[1] - first[1];
    const length = Math.hypot(dx, dy);
    if (length > 0) {
      const head = headPolygon(first[0], first[1], dx / length, dy / length, style.strokeWidth, startKind, pivotX, pivotY);
      head.fill = style.stroke;
      if (style.opacity !== 1) head.opacity = style.opacity;
      if (style.angle !== 0) head.angle = style.angle;
      ctx.paint(head);
    }
  }
}

function text(ctx, element, index) {
  const x = requireCoordinate(ctx, element, index, "x");
  const y = requireCoordinate(ctx, element, index, "y");
  const raw = element.fontSize;
  let fontSize;
  if (raw === undefined || raw === null) {
    fontSize = DEFAULT_FONT_SIZE;
  } else if (typeof raw !== "number" || !Number.isFinite(raw) || raw <= 0 || raw > FONT_SIZE_LIMIT) {
    throw failure(
      `${elementLabel(element, index)}: fontSize must be a positive finite number up to ${FONT_SIZE_LIMIT}, not ${preview(raw)}`,
      "invalid-input",
    );
  } else {
    fontSize = raw;
  }
  const content = element.text;
  if (content === undefined || content === null) return; // nothing to render
  if (typeof content !== "string") {
    throw failure(
      `${elementLabel(element, index)}: text must be a string, not ${preview(content)}`,
      "invalid-input",
    );
  }
  if (element.verticalAlign !== undefined && element.verticalAlign !== null && element.verticalAlign !== "top") {
    ctx.warn(W_VERTICAL_ALIGN);
  }
  // fontFamily 2 -> Helvetica, 3 -> monospace; every other editor/personal
  // font (Virgil, Excalifont, custom) falls back to Helvetica, warned once.
  const font = element.fontFamily;
  let family = "Helvetica";
  if (font === 3) family = "monospace";
  else if (font !== 2 && font !== undefined && font !== null) {
    ctx.warn(W_CUSTOM_FONT);
  }
  const color = readColor(ctx, element.strokeColor, { missing: "default" });
  if (color.a === 0) return; // invisible text paints nothing
  const opacity = opacityOf(ctx, element, index);
  const angle = optionalNumber(element, index, "angle", 0);
  if (Math.abs(angle) > ANGLE_LIMIT) {
    throw failure(
      `${elementLabel(element, index)}: angle must be within +/-${ANGLE_LIMIT} radians, not ${angle}`,
      "invalid-input",
    );
  }

  const lines = content.split("\n");
  let maxAdvance = 0;
  for (const line of lines) {
    if (line !== "") {
      maxAdvance = Math.max(maxAdvance, estimateAdvance(line, fontSize));
    }
  }
  let align = "left";
  if (element.textAlign === "center" || element.textAlign === "right") {
    align = element.textAlign;
  } else if (element.textAlign === "start") {
    align = "left";
  } else if (element.textAlign === "end") {
    align = "right";
  } else if (element.textAlign !== undefined
    && element.textAlign !== null && element.textAlign !== "left") {
    ctx.warn(`unsupported text alignment "${String(element.textAlign)}": rendered left`);
  }
  let boxWidth = maxAdvance;
  if (element.width !== undefined && element.width !== null) {
    const rawWidth = element.width;
    if (typeof rawWidth !== "number" || !Number.isFinite(rawWidth)
      || Math.abs(rawWidth) > COORD_LIMIT) {
      throw failure(
        `${elementLabel(element, index)}: width must be a finite number within the coordinate range, not ${preview(rawWidth)}`,
        "invalid-input",
      );
    }
    // bound/container text carries the container's inner width
    boxWidth = Math.abs(rawWidth);
  }
  // The whole element's text box: same pivot for every synthesized line so a
  // rotation turns the block as one unit around its own center.
  const boxHeight = lines.length * fontSize * TEXT_LINE_HEIGHT;
  const pivotX = x + boxWidth / 2;
  const pivotY = y + boxHeight / 2;

  // ONE anchor convention per align op (see the module header): the emitted
  // x is the glyph LEFT edge, CENTER, or RIGHT edge -- never a left-band
  // position while the encoder centers/right-aligns the glyphs at it. The
  // anchor is the same for every line of the element (box start / box
  // center / box right edge), so short and overflowing lines share the
  // anchored fragment of the rule instead of a hard left clamp.
  const anchorX = align === "center"
    ? x + boxWidth / 2
    : align === "right"
      ? x + boxWidth
      : x;
  if (Math.abs(anchorX) > COORD_LIMIT) {
    throw failure(
      `${elementLabel(element, index)}: a text anchor lands outside the +/-${COORD_LIMIT} coordinate range`,
      "too-large",
    );
  }

  let offset = 0;
  for (const line of lines) {
    if (line !== "") {
      const lineY = y + offset;
      if (Math.abs(lineY) > COORD_LIMIT) {
        throw failure(
          `${elementLabel(element, index)}: a text line lands outside the +/-${COORD_LIMIT} coordinate range`,
          "too-large",
        );
      }
      const advance = estimateAdvance(line, fontSize);
      const prim = {
        kind: "text",
        pivot: [pivotX, pivotY],
        x: anchorX,
        y: lineY,
        text: line,
        fontSize,
        family,
        align,
        baseline: "top",
        fill: color,
        advance,
      };
      if (opacity !== 1) prim.opacity = opacity;
      if (angle !== 0) prim.angle = angle;
      ctx.paint(prim);
    }
    offset += fontSize * TEXT_LINE_HEIGHT;
  }
}

///|
// Early caps: count what the scene WOULD generate -- per element: shapes one
// primitive, line/arrow one polyline plus up to two 3-point head polygons,
// text one primitive per non-empty line -- and reject before building
// anything when a total cap would be exceeded. Deleted elements and unknown
// kinds generate nothing and are skipped here (the real pass still validates
// every element it draws).
function countGenerated(elements) {
  let primitives = 0;
  let totalPoints = 0;
  let totalChars = 0;
  for (const element of elements) {
    if (!isPlainObject(element) || element.isDeleted) continue;
    const type = element.type;
    if (typeof type !== "string") continue;
    if (type === "rectangle" || type === "ellipse" || type === "diamond") {
      primitives += 1;
    } else if (type === "line" || type === "arrow") {
      const heads = type === "arrow" ? headCountOf(element) : 0;
      primitives += 1 + heads;
      if (Array.isArray(element.points)) {
        totalPoints += element.points.length + heads * 3;
      }
    } else if (type === "text" && typeof element.text === "string") {
      if (element.text.length > ELEMENT_TEXT_LIMIT) {
        throw failure(
          `a text element holds ${element.text.length} characters, over the ${ELEMENT_TEXT_LIMIT}-character limit`,
          "too-large",
        );
      }
      for (const line of element.text.split("\n")) {
        if (line === "") continue;
        if (line.length > LINE_TEXT_LIMIT) {
          throw failure(
            `a text line holds ${line.length} characters, over the ${LINE_TEXT_LIMIT}-character limit`,
            "too-large",
          );
        }
        primitives += 1;
        totalChars += line.length;
      }
    }
  }
  if (primitives > PRIMITIVES_LIMIT) {
    throw failure(
      `the scene would generate ${primitives} primitives, over the ${PRIMITIVES_LIMIT} limit`,
      "too-large",
    );
  }
  if (totalPoints > TOTAL_POINT_LIMIT) {
    throw failure(
      `the scene would generate ${totalPoints} points, over the ${TOTAL_POINT_LIMIT} limit`,
      "too-large",
    );
  }
  if (totalChars > TOTAL_TEXT_CHAR_LIMIT) {
    throw failure(
      `the scene would generate ${totalChars} text characters, over the ${TOTAL_TEXT_CHAR_LIMIT} limit`,
      "too-large",
    );
  }
}

// -------------------------------------------------------------- the scene --

function sceneContext() {
  const warnings = [];
  const seen = new Set();
  const primitives = [];
  const ctx = {
    primitives,
    warn(message) {
      if (!seen.has(message)) {
        seen.add(message);
        warnings.push(message);
      }
    },
    // Records one rendered primitive in array (z) order; a last guard keeps
    // primitives that would paint nothing out of the stream.
    paint(prim) {
      if (prim.kind === "text") {
        if (prim.fill === null || prim.fill === undefined) return;
      } else if (prim.kind === "polyline") {
        if (prim.stroke === null || prim.stroke === undefined) return;
      } else if ((prim.fill === null || prim.fill === undefined)
        && (prim.stroke === null || prim.stroke === undefined)) {
        return;
      }
      primitives.push(prim);
    },
  };
  return { ctx, warnings };
}

///|
// Shift every coordinate of every primitive by the page-fitting offset,
// including every decomposed part's shared pivot.
function translate(primitives, dx, dy) {
  for (const prim of primitives) {
    if (prim.kind === "rect") {
      prim.x += dx;
      prim.y += dy;
    } else if (prim.kind === "ellipse") {
      prim.cx += dx;
      prim.cy += dy;
    } else if (prim.kind === "text") {
      prim.x += dx;
      prim.y += dy;
    } else {
      for (const point of prim.points) {
        point[0] += dx;
        point[1] += dy;
      }
    }
    if (prim.pivot) {
      prim.pivot[0] += dx;
      prim.pivot[1] += dy;
    }
  }
}

function largestCoordinate(primitives) {
  let largest = 0;
  for (const prim of primitives) {
    const coords = [];
    if (prim.kind === "rect") {
      coords.push(prim.x, prim.y, prim.x + prim.w, prim.y + prim.h);
    } else if (prim.kind === "ellipse") {
      coords.push(prim.cx, prim.cy, prim.cx + prim.rx, prim.cy + prim.ry, prim.cx - prim.rx, prim.cy - prim.ry);
    } else if (prim.kind === "text") {
      coords.push(prim.x, prim.y);
    } else {
      for (const [px, py] of prim.points) {
        coords.push(px, py);
      }
    }
    for (const value of coords) {
      if (Math.abs(value) > largest) largest = Math.abs(value);
    }
  }
  return largest;
}

///|
// The converter core: bytes -> primitives -> shared encoder -> BDF bytes.
async function convertScene(bytes, options) {
  acceptedParams(options, [], EXCALIDRAW_FORMAT_NAME);
  noPassword(options, EXCALIDRAW_FORMAT_NAME);

  const view = byteView(bytes, "the input");
  if (view.byteLength > EXCALIDRAW_INPUT_LIMIT) {
    throw failure(
      `the scene is ${view.byteLength} bytes, over the ${EXCALIDRAW_INPUT_LIMIT}-byte limit`,
      "too-large",
    );
  }
  let sceneText;
  try {
    sceneText = new TextDecoder("utf-8", { fatal: true }).decode(view);
  } catch (error) {
    throw failure(`the scene is not valid UTF-8: ${errorText(error)}`, "invalid-input");
  }
  let document;
  try {
    document = JSON.parse(sceneText);
  } catch (error) {
    throw failure(`the scene is not valid JSON: ${errorText(error)}`, "invalid-input");
  }
  if (!isPlainObject(document) || !Array.isArray(document.elements)) {
    throw failure("the document is not an Excalidraw scene (no elements array)", "invalid-input");
  }
  if (document.type !== undefined && document.type !== null && document.type !== "excalidraw") {
    throw failure(
      `the document declares type ${JSON.stringify(document.type)}, which conflicts with the Excalidraw format`,
      "invalid-input",
    );
  }
  const elements = document.elements;
  if (elements.length > ELEMENT_LIMIT) {
    throw failure(
      `the scene holds ${elements.length} elements, over the ${ELEMENT_LIMIT}-element limit`,
      "too-large",
    );
  }
  // Oversized (but well formed) scenes reject BEFORE any geometry is built.
  countGenerated(elements);

  const { ctx, warnings } = sceneContext();
  let painted = 0;
  for (let index = 0; index < elements.length; index += 1) {
    const element = elements[index];
    if (!isPlainObject(element) && element?.isDeleted !== true) {
      throw failure(`element ${index} is not a plain object`, "invalid-input");
    }
    const before = ctx.primitives.length;
    convertElement(ctx, element, index);
    if (ctx.primitives.length > before) {
      painted += 1; // elements render (and count) in array order
    }
  }

  // Page geometry. The union of all primitives' Cosmetic extents (rotated
  // about each element pivot) IS the ink footprint. The page offset anchors
  // ITS minimum at the 16 pt margin -- so no matter how thick a supported
  // stroke is, the outermost ink stays fully on the page; the page size is
  // that union plus the margin on each side, rounded to integers. An empty
  // scene keeps the default page (with a warning).
  let minX = Infinity;
  let minY = Infinity;
  let maxX = -Infinity;
  let maxY = -Infinity;
  for (const prim of ctx.primitives) {
    const extent = primExtent(prim);
    const angle = prim.angle ?? 0;
    const [pivotX, pivotY] = extent.pivot;
    const corners = [
      [extent.x0, extent.y0],
      [extent.x1, extent.y0],
      [extent.x1, extent.y1],
      [extent.x0, extent.y1],
    ];
    if (angle !== 0) {
      const cos = Math.cos(angle);
      const sin = Math.sin(angle);
      for (const corner of corners) {
        const rx = corner[0] - pivotX;
        const ry = corner[1] - pivotY;
        corner[0] = pivotX + cos * rx - sin * ry;
        corner[1] = pivotY + sin * rx + cos * ry;
      }
    }
    for (const [px, py] of corners) {
      if (px < minX) minX = px;
      if (py < minY) minY = py;
      if (px > maxX) maxX = px;
      if (py > maxY) maxY = py;
    }
  }

  let width;
  let height;
  if (ctx.primitives.length === 0) {
    ctx.warn(W_EMPTY);
    width = EMPTY_PAGE.width;
    height = EMPTY_PAGE.height;
  } else {

    const dx = PAGE_MARGIN - minX;
    const dy = PAGE_MARGIN - minY;
    width = Math.round(maxX - minX + 2 * PAGE_MARGIN);
    height = Math.round(maxY - minY + 2 * PAGE_MARGIN);
    if (width <= 0 || height <= 0 || width > PAGE_LIMIT || height > PAGE_LIMIT) {
      throw failure(
        `the scene needs a ${Math.round(width)}x${Math.round(height)} pt page, outside the page limits`,
        "too-large",
      );
    }
    translate(ctx.primitives, dx, dy);
    const largest = largestCoordinate(ctx.primitives);
    if (largest > COORD_LIMIT) {
      throw failure(
        `the scene spans more than the +/-${COORD_LIMIT} coordinate range after page fitting`,
        "too-large",
      );
    }
  }

  let bdf;
  try {
    bdf = await encodeDiagram({
      width,
      height,
      source: EXCALIDRAW_FORMAT_NAME,
      title: "Excalidraw diagram",
      primitives: ctx.primitives,
    });
  } catch (error) {
    const wrapped = new Error(`excalidraw: ${errorText(error)}`);
    const code = error?.code;
    wrapped.code = typeof code === "string" && code !== "" ? code : "invalid-input";
    throw wrapped;
  }
  if (!(bdf instanceof Uint8Array)) {
    throw failure("the encoder produced no byte output", "invalid-input");
  }
  return {
    bdf,
    format: EXCALIDRAW_FORMAT_NAME,
    summary: `1 page, ${painted} element(s)`,
    warnings,
  };
}

// ------------------------------------------------------------ descriptor ---

export function excalidrawPlugin() {
  const plugin = {
    apiVersion: 1,
    name: EXCALIDRAW_FORMAT_NAME,
    description: EXCALIDRAW_DESCRIPTION,
    extensions: [...EXCALIDRAW_EXTENSIONS],
    version: "1.0.0",
    vendor: "f4ah6o",
    ///|
    // Detection is total and synchronous: any failure (size, decode, parse,
    // shape) is a plain `false`, never a throw, an over-cap input is not
    // sniffed at all, and documents declaring a foreign `type` are never
    // claimed (they belong to whatever format owns that type).
    detect(bytes) {
      try {
        const view = byteView(bytes, "the input");
        if (view.byteLength > EXCALIDRAW_INPUT_LIMIT) return false;
        const sceneText = new TextDecoder().decode(view);
        const value = JSON.parse(sceneText);
        return acceptsDocument(value);
      } catch {
        return false;
      }
    },
    async convert(bytes, options) {
      return convertScene(bytes, options);
    },
  };
  return defineFormatPlugin(plugin);
}
