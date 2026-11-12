// Shared diagram-to-BDF encoder for the file-format plugin adapters
// (Excalidraw, Mermaid). It implements the BDF single-file byte format with
// no runtime dependencies, so a plugin worker can emit genuine BDF bytes:
// the 32-byte header, a JSON manifest at a fixed offset, one vector "obj"
// part per diagram, and the opset-1 opcode stream inside it. Adapters only
// produce serializable primitives; every byte of BDF encoding lives here so
// both formats converge on the same writer and cannot drift apart.
//
// Byte-format facts this module encodes (verified against core/writer.mbt,
// core/container.mbt, core/object_encode.mbt of the bdf.mbt sources):
//   header : b"bdf\x00", u16le version 1, u16le flags 0,
//            u64le manifest offset, u64le manifest length,
//            u8 manifest encoding (0 identity), 7 zero bytes
//   part   : name/hash is the first 128 bits of SHA-256 as 32 lowercase hex
//            characters; entries carry {h, t, enc, len, size, off}
//   object : b"BOBJ", u16 opset 1, u16 reserved 0, 4 x f32 bbox,
//            varuint string table (varuint-length UTF-8, BOM trimmed),
//            varuint path table (inline: kind byte 0 + varuint verb count +
//            verbs + f32 coordinates), varuint paint table, varuint font
//            table (kind 1 system: family string, u16 weight, u8 style),
//            varuint image table (16 raw bytes per hash), varuint child
//            hashes, varuint ops length + ops bytes
//   image op: opcode 0x40, varuint image-table index, x/y/w/h as f32, per
//            core/object_builder_draw.mbt and render/render.mbt; the image
//            table lists the 32-hex-char names of "img" parts
//   Multi-page documents store one obj part per page plus one "img" part
//   per unique embedded raster, with part offsets RELATIVE to the manifest
//   end (core/container.mbt reads parts from manifest_offset + manifest_length).
// The manifest exposes one "fixed" view: single-diagram encoding pins it to
// one page and one "content" layer that references the object part; the
// document encoder emits the same shape with one page per input page.
//
// Contract guarantees the tests hold it to:
//   * every primitive is wrapped in save/restore, so stroke width, dash,
//     colors, alpha and transforms of one primitive never leak to the next;
//   * every number that reaches an f32 operand is finite AS FLOAT32 (a
//     strokeWidth of 1e300 is rejected, never encoded as Infinity);
//   * the input is never mutated: validation reads, it does not assign
//     (frozen primitives convert identically);
//   * the bounding box covers real rendering extents: alignment- and
//     baseline-aware text bands (estimated advance, CJK overridable), the
//     rotated AABB about the rotation pivot, and strokeWidth padding;
//   * aggregate caps (points, text volume) are checked before emission, so
//     a bounded input can never cause unbounded amplification;
//   * document encoding is bounded the same way: pages, resources, total
//     image bytes and document-wide primitive volume are capped up front,
//     and embedded images must be actual PNG or JPEG byte arrays (never
//     URLs, paths or SVG), content-deduplicated and referenced both ways.

export const BDF_MAX_PAGE_UNITS = 16777216; // 1 << 24, the reader's page-side cap
export const MAX_PRIMITIVES = 20000;
/** Per-document page cap of encodeDiagramDocument. */
export const MAX_PAGES = 256;
/** Document-wide primitive cap of encodeDiagramDocument (per page: MAX_PRIMITIVES). */
export const MAX_DOCUMENT_PRIMITIVES = 100000;
/** Per-document embedded-image resource count cap. */
export const MAX_IMAGE_RESOURCES = 256;
/** Per-image byte cap for embedded resources. */
export const MAX_IMAGE_BYTES = 4194304; // 4 MiB
/** Document-wide cap on the bytes of unique embedded images (deduplicated). */
export const MAX_TOTAL_IMAGE_BYTES = 33554432; // 32 MiB
/** Per-side raster pixel cap for embedded images. */
export const MAX_IMAGE_SIDE = 16384;
/** Raster pixel product cap for embedded images. */
export const MAX_IMAGE_PIXELS = 16777216; // 1 << 24
const MAX_IMAGE_ID_CHARS = 128;
const MAX_COORD_ABS = 1e6;
const MAX_ANGLE_ABS = 1e6;
const MAX_STROKE_WIDTH = 10000;
const MAX_DASH_SEGMENT = 100000;
const MAX_RADIUS = 1e6;
const MAX_ADVANCE = 1e7;
const MAX_POINTS_PER_PRIM = 10000;
const MAX_TOTAL_POINTS = 100000;
const MAX_TEXT_CHARS = 4096;
const MAX_TOTAL_TEXT_CHARS = 200000;

export class DiagramEncodeError extends Error {
  constructor(message, code = "invalid-input") {
    super(message);
    this.name = "DiagramEncodeError";
    this.code = code;
  }
}

///|
// Real SHA-256 in pure JS (no dependencies, worker-safe, synchronous). The
// part name is a format requirement, and it matches Node's crypto digest in
// the regression tests. The round-constant table is the same one the
// MoonBit core/sha256.mbt of this project uses (adapted from gaato/codecs.mbt,
// Apache-2.0; see licenses/Apache-2.0.txt).
const SHA256_K = [
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4,
  0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe,
  0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f,
  0x4a7484aa, 0x5cb0a9dc, 0x76f988da, 0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
  0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc,
  0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
  0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070, 0x19a4c116,
  0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7,
  0xc67178f2,
];

function sha256(bytes) {
  const k = SHA256_K;
  const bitLen = bytes.length * 8;
  const total = (Math.floor((bytes.length + 9 + 63) / 64)) * 64;
  const block = new Uint8Array(total);
  block.set(bytes);
  block[bytes.length] = 0x80;
  const view = new DataView(block.buffer);
  view.setUint32(total - 8, Math.floor(bitLen / 4294967296), false);
  view.setUint32(total - 4, bitLen >>> 0, false);
  const h = [
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
    0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
  ];
  const w = new Uint32Array(64);
  for (let start = 0; start < total; start += 64) {
    for (let i = 0; i < 16; i += 1) {
      w[i] = view.getUint32(start + i * 4, false);
    }
    for (let i = 16; i < 64; i += 1) {
      const a0 = w[i - 15];
      const s0 = ((a0 >>> 7) | (a0 << 25)) ^ ((a0 >>> 18) | (a0 << 14)) ^ (a0 >>> 3);
      const a1 = w[i - 2];
      const s1 = ((a1 >>> 17) | (a1 << 15)) ^ ((a1 >>> 19) | (a1 << 13)) ^ (a1 >>> 10);
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) >>> 0;
    }
    let [a, b, c, d, e, f, g, hh] = h;
    for (let i = 0; i < 64; i += 1) {
      const S1 = ((e >>> 6) | (e << 26)) ^ ((e >>> 11) | (e << 21)) ^ ((e >>> 25) | (e << 7));
      const ch = (e & f) ^ (~e & g);
      const temp1 = (hh + S1 + ch + k[i] + w[i]) >>> 0;
      const S0 = ((a >>> 2) | (a << 30)) ^ ((a >>> 13) | (a << 19)) ^ ((a >>> 22) | (a << 10));
      const maj = (a & b) ^ (a & c) ^ (b & c);
      const temp2 = (S0 + maj) >>> 0;
      hh = g; g = f; f = e;
      e = (d + temp1) >>> 0;
      d = c; c = b; b = a;
      a = (temp1 + temp2) >>> 0;
    }
    h[0] = (h[0] + a) >>> 0;
    h[1] = (h[1] + b) >>> 0;
    h[2] = (h[2] + c) >>> 0;
    h[3] = (h[3] + d) >>> 0;
    h[4] = (h[4] + e) >>> 0;
    h[5] = (h[5] + f) >>> 0;
    h[6] = (h[6] + g) >>> 0;
    h[7] = (h[7] + hh) >>> 0;
  }
  let out = "";
  for (const word of h) {
    out += word.toString(16).padStart(8, "0");
  }
  return out;
}

///|
// Growable byte buffer with the little-endian primitives BDF objects use.
class ByteWriter {
  constructor() {
    this.chunks = [];
    this.length = 0;
  }

  ensure(extra) {
    this.length += extra;
    if (this.length > 0x7ffffff0 || !Number.isSafeInteger(this.length)) {
      throw new DiagramEncodeError("encoded object exceeds 2 GiB limit", "too-large");
    }
  }

  raw(bytes) {
    this.ensure(bytes.length);
    this.chunks.push(bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes));
  }

  u8(value) {
    this.ensure(1);
    this.chunks.push(new Uint8Array([value & 0xff]));
  }

  bytesOf(write, size) {
    const buffer = new ArrayBuffer(size);
    write(new DataView(buffer));
    this.ensure(size);
    this.chunks.push(new Uint8Array(buffer));
  }

  u16le(value) {
    this.bytesOf(view => view.setUint16(0, value, true), 2);
  }

  u32le(value) {
    this.bytesOf(view => view.setUint32(0, value >>> 0, true), 4);
  }

  u64le(value) {
    if (!Number.isSafeInteger(value) || value < 0) {
      throw new DiagramEncodeError("u64 offset out of range", "invalid-input");
    }
    this.bytesOf(view => {
      view.setUint32(0, value >>> 0, true);
      view.setUint32(4, Math.floor(value / 4294967296), true);
    }, 8);
  }

  f32le(value) {
    if (typeof value !== "number" || !Number.isFinite(value)) {
      throw new DiagramEncodeError("non-finite coordinate", "invalid-input");
    }
    // Float32 has a far smaller range than JS doubles: a finite input like
    // 1e300 must be rejected here instead of stored as Infinity.
    const rounded = Math.fround(value);
    if (!Number.isFinite(rounded) || rounded > 3.4028234663852886e38 || rounded < -3.4028234663852886e38) {
      throw new DiagramEncodeError("value out of the float32 range", "invalid-input");
    }
    this.bytesOf(view => view.setFloat32(0, rounded, true), 4);
  }

  varuint(value) {
    if (!Number.isSafeInteger(value) || value < 0) {
      throw new DiagramEncodeError("varuint out of range", "invalid-input");
    }
    let rest = value;
    const out = [];
    do {
      let byte = rest & 0x7f;
      rest = Math.floor(rest / 128);
      if (rest > 0) {
        byte |= 0x80;
      }
      out.push(byte);
    } while (rest > 0);
    this.ensure(out.length);
    this.chunks.push(new Uint8Array(out));
  }

  string(value) {
    const bytes = new TextEncoder().encode(value);
    // BDF writers strip UTF-8 BOMs from object strings before storing them.
    let start = 0;
    while (start + 3 <= bytes.length && bytes[start] === 0xef && bytes[start + 1] === 0xbb && bytes[start + 2] === 0xbf) {
      start += 3;
    }
    const size = bytes.length - start;
    this.varuint(size);
    this.raw(bytes.subarray(start));
  }

  toBytes() {
    const out = new Uint8Array(this.length);
    let at = 0;
    for (const chunk of this.chunks) {
      out.set(chunk, at);
      at += chunk.length;
    }
    return out;
  }
}

const OP = {
  SAVE: 0x01, RESTORE: 0x02,
  TRANSLATE: 0x04,
  FILL_COLOR: 0x10, STROKE_COLOR: 0x12,
  LINE: 0x14, DASH: 0x15, ALPHA: 0x16,
  FONT: 0x1a, TEXT_STYLE: 0x1b,
  FILL_RECT: 0x20, STROKE_RECT: 0x21,
  FILL_PATH: 0x22, STROKE_PATH: 0x23,
  FILL_TEXT: 0x30,
  IMAGE: 0x40,
};
const FILL_RULE_NONZERO = 0;

function colorError(what) {
  return new DiagramEncodeError(`${what} must be {r,g,b,a} integers 0..255`, "invalid-input");
}

function colorToU32(color) {
  if (color === null || color === undefined) {
    return null;
  }
  if (typeof color !== "object" || Array.isArray(color)) {
    throw colorError("color");
  }
  const { r, g, b, a } = color;
  for (const part of [r, g, b, a]) {
    if (!Number.isInteger(part) || part < 0 || part > 255) {
      throw colorError("color component");
    }
  }
  return (((r & 0xff) << 24) | ((g & 0xff) << 16) | ((b & 0xff) << 8) | (a & 0xff)) >>> 0;
}

function finiteNumber(value, what, limitAbs = MAX_COORD_ABS) {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new DiagramEncodeError(`${what} must be a finite number`, "invalid-input");
  }
  if (Math.abs(value) > limitAbs) {
    throw new DiagramEncodeError(`${what} ${value} exceeds the ${limitAbs} coordinate limit`, "too-large");
  }
  return value;
}

// The optional rotation pivot of a primitive: [x, y], or null for the
// intrinsic pivot (shape center / text anchor).
function pivotOf(prim) {
  if (prim.pivot === undefined || prim.pivot === null) {
    return null;
  }
  if (!Array.isArray(prim.pivot) || prim.pivot.length !== 2) {
    throw new DiagramEncodeError("pivot must be an [x, y] pair", "invalid-input");
  }
  return [finiteNumber(prim.pivot[0], "pivot x"), finiteNumber(prim.pivot[1], "pivot y")];
}

function styleOf(prim) {
  const style = {};
  style.fill = colorToU32(prim.fill);
  style.stroke = colorToU32(prim.stroke);
  style.strokeWidth = prim.strokeWidth === undefined ? 2 : prim.strokeWidth;
  if (typeof style.strokeWidth !== "number" || !Number.isFinite(style.strokeWidth)
    || style.strokeWidth <= 0 || style.strokeWidth > MAX_STROKE_WIDTH) {
    throw new DiagramEncodeError(`strokeWidth must be a positive finite number up to ${MAX_STROKE_WIDTH}`, "invalid-input");
  }
  if (prim.dash !== undefined && prim.dash !== null) {
    if (!Array.isArray(prim.dash) || prim.dash.length === 0 || prim.dash.length > 64) {
      throw new DiagramEncodeError("dash must be a non-empty array of at most 64 numbers", "invalid-input");
    }
    for (const segment of prim.dash) {
      if (typeof segment !== "number" || !Number.isFinite(segment) || segment < 0 || segment > MAX_DASH_SEGMENT) {
        throw new DiagramEncodeError(`dash segments must be numbers within 0..${MAX_DASH_SEGMENT}`, "invalid-input");
      }
    }
    style.dash = [...prim.dash];
  } else {
    style.dash = null;
  }
  style.opacity = prim.opacity === undefined ? 1 : prim.opacity;
  if (typeof style.opacity !== "number" || !Number.isFinite(style.opacity) || style.opacity < 0 || style.opacity > 1) {
    throw new DiagramEncodeError("opacity must be a number in 0..1", "invalid-input");
  }
  style.angle = prim.angle === undefined ? 0 : prim.angle;
  if (typeof style.angle !== "number" || !Number.isFinite(style.angle) || Math.abs(style.angle) > MAX_ANGLE_ABS) {
    throw new DiagramEncodeError("angle must be a finite number of radians within +/-1e6", "invalid-input");
  }
  return style;
}

// Image primitives carry no paint of their own: fill/stroke/dash/strokeWidth
// are rejected outright (silently ignoring them would hide adapter bugs),
// while opacity, angle and pivot behave exactly as for shapes.
function imageStyleOf(prim) {
  for (const field of ["fill", "stroke", "dash", "strokeWidth"]) {
    if (prim[field] !== undefined && prim[field] !== null) {
      throw new DiagramEncodeError(`image primitives do not take a ${field}`, "invalid-input");
    }
  }
  const style = { fill: null, stroke: null, strokeWidth: 2, dash: null };
  style.opacity = prim.opacity === undefined ? 1 : prim.opacity;
  if (typeof style.opacity !== "number" || !Number.isFinite(style.opacity) || style.opacity < 0 || style.opacity > 1) {
    throw new DiagramEncodeError("opacity must be a number in 0..1", "invalid-input");
  }
  style.angle = prim.angle === undefined ? 0 : prim.angle;
  if (typeof style.angle !== "number" || !Number.isFinite(style.angle) || Math.abs(style.angle) > MAX_ANGLE_ABS) {
    throw new DiagramEncodeError("angle must be a finite number of radians within +/-1e6", "invalid-input");
  }
  return style;
}

const TEXT_ALIGN = { left: 0, right: 1, center: 2, start: 3, end: 4 };
const TEXT_BASELINE = { alphabetic: 0, top: 1, middle: 2, bottom: 3, hanging: 4, ideographic: 5 };
const TEXT_DIRECTION = { inherit: 0, ltr: 1, rtl: 2 };
const FONT_STYLE = { normal: 0, italic: 1, oblique: 2 };

// Path verbs of the BDF object format (opset 1). RECT uses the dedicated
// fill/stroke rect opcodes instead of a path; every other shape is an inline
// path. ELLIPSE encodes the canvas ellipse() operand list: cx, cy, rx, ry,
// rotation, startAngle, endAngle, ccw-flag; ROUND_RECT encodes x, y, w, h, r.
const VERB_LINE = 1;
const VERB_CLOSE = 4;
const VERB_ROUND_RECT = 8;
const VERB_ELLIPSE = 6;

class PathBuilder {
  constructor() {
    this.verbs = [];
    this.args = [];
  }

  move(x, y) {
    this.verbs.push(0);
    this.args.push(x, y);
  }

  line(x, y) {
    this.verbs.push(VERB_LINE);
    this.args.push(x, y);
  }

  close() {
    this.verbs.push(VERB_CLOSE);
  }

  roundRect(x, y, w, h, r) {
    this.verbs.push(VERB_ROUND_RECT);
    this.args.push(x, y, w, h, r);
  }

  ellipse(cx, cy, rx, ry) {
    this.verbs.push(VERB_ELLIPSE);
    this.args.push(cx, cy, rx, ry, 0, 0, 2 * Math.PI, 0);
  }

  write(writer) {
    writer.varuint(this.verbs.length);
    for (const verb of this.verbs) {
      writer.u8(verb);
    }
    for (const arg of this.args) {
      writer.f32le(arg);
    }
  }
}

// The object image table stores each referenced part name as its 16 raw
// bytes (the first 128 bits of the part's SHA-256), as object_write_hash of
// core/object_encode.mbt does.
function imageHashBytes(hash) {
  if (!/^[0-9a-f]{32}$/.test(hash)) {
    throw new DiagramEncodeError("image part hash must be 32 lowercase hex characters", "invalid-input");
  }
  const out = new Uint8Array(16);
  for (let i = 0; i < 16; i += 1) {
    out[i] = parseInt(hash.slice(2 * i, 2 * i + 2), 16);
  }
  return out;
}

class ObjectBuilder {
  constructor() {
    this.ops = new ByteWriter();
    this.strings = [];
    this.stringIndex = new Map();
    this.paths = [];
    this.fonts = [];
    this.fontIndex = new Map();
    this.images = [];
    this.imageIndex = new Map();
    this.bbox = null; // {x, y, w, h}
    // When false, drawing ops no longer grow the bounding box: encodeDiagram
    // computes every primitive's extent explicitly (rotation-aware,
    // stroke-padded), so the unrotated op-level box must not leak in.
    this.autoGrow = true;
  }

  stringRef(value) {
    if (typeof value !== "string") {
      throw new DiagramEncodeError("text must be a string", "invalid-input");
    }
    if (value.length > MAX_TEXT_CHARS) {
      throw new DiagramEncodeError("text exceeds the 4096-character limit", "too-large");
    }
    if (this.stringIndex.has(value)) {
      return this.stringIndex.get(value);
    }
    const index = this.strings.length;
    this.strings.push(value);
    this.stringIndex.set(value, index);
    return index;
  }

  addPath(path) {
    this.paths.push(path);
    return this.paths.length - 1;
  }

  fontRef(family, weight, style) {
    const key = `${family}|${weight}|${style}`;
    if (this.fontIndex.has(key)) {
      return this.fontIndex.get(key);
    }
    const index = this.fonts.length;
    this.fonts.push({ family, weight, style });
    this.fontIndex.set(key, index);
    return index;
  }

  // Image tables hold part names: identical bytes are stored once, so the
  // index dedupes by hash exactly like the manifest dedupes parts.
  imageRef(hash) {
    if (this.imageIndex.has(hash)) {
      return this.imageIndex.get(hash);
    }
    const index = this.images.length;
    this.images.push(hash);
    this.imageIndex.set(hash, index);
    return index;
  }

  grow(x, y, w, h) {
    const left = w < 0 ? x + w : x;
    const top = h < 0 ? y + h : y;
    const width = Math.abs(w);
    const height = Math.abs(h);
    if (this.bbox === null) {
      this.bbox = { x: left, y: top, w: width, h: height };
      return;
    }
    const x0 = Math.min(this.bbox.x, left);
    const y0 = Math.min(this.bbox.y, top);
    const x1 = Math.max(this.bbox.x + this.bbox.w, left + width);
    const y1 = Math.max(this.bbox.y + this.bbox.h, top + height);
    this.bbox = { x: x0, y: y0, w: x1 - x0, h: y1 - y0 };
  }

  // The op-running interface mirrors the MoonBit ObjectBuilder one to one.
  save() { this.ops.u8(OP.SAVE); }
  restore() { this.ops.u8(OP.RESTORE); }

  translate(x, y) {
    this.ops.u8(OP.TRANSLATE);
    this.ops.f32le(x);
    this.ops.f32le(y);
  }

  transform(a, b, c, d, e, f) {
    this.ops.u8(0x03);
    for (const value of [a, b, c, d, e, f]) {
      this.ops.f32le(value);
    }
  }

  alpha(value) {
    this.ops.u8(OP.ALPHA);
    this.ops.f32le(value);
  }

  fillColor(value) {
    this.ops.u8(OP.FILL_COLOR);
    this.ops.u32le(value);
  }

  strokeColor(value) {
    this.ops.u8(OP.STROKE_COLOR);
    this.ops.u32le(value);
  }

  line(width) {
    this.ops.u8(OP.LINE);
    this.ops.f32le(width);
    this.ops.u8(0); // butt cap
    this.ops.u8(0); // miter join
    this.ops.f32le(10);
  }

  dash(segments) {
    this.ops.u8(OP.DASH);
    this.ops.varuint(segments.length);
    for (const segment of segments) {
      this.ops.f32le(segment);
    }
    this.ops.f32le(0);
  }

  font(index, size) {
    this.ops.u8(OP.FONT);
    this.ops.varuint(index);
    this.ops.f32le(size);
  }

  textStyle(align, baseline, direction) {
    this.ops.u8(OP.TEXT_STYLE);
    this.ops.u8(TEXT_ALIGN[align] ?? 0);
    this.ops.u8(TEXT_BASELINE[baseline] ?? 0);
    this.ops.u8(TEXT_DIRECTION[direction] ?? 0);
    this.ops.f32le(0);
  }

  fillRect(x, y, w, h) {
    if (this.autoGrow) {
      this.grow(x, y, w, h);
    }
    this.ops.u8(OP.FILL_RECT);
    this.ops.f32le(x); this.ops.f32le(y); this.ops.f32le(w); this.ops.f32le(h);
  }

  strokeRect(x, y, w, h) {
    if (this.autoGrow) {
      this.grow(x, y, w, h);
    }
    this.ops.u8(OP.STROKE_RECT);
    this.ops.f32le(x); this.ops.f32le(y); this.ops.f32le(w); this.ops.f32le(h);
  }

  fillPath(index) {
    this.ops.u8(OP.FILL_PATH);
    this.ops.varuint(index);
    this.ops.u8(FILL_RULE_NONZERO);
  }

  strokePath(index) {
    this.ops.u8(OP.STROKE_PATH);
    this.ops.varuint(index);
  }

  fillText(stringRef, x, y, advance) {
    this.ops.u8(OP.FILL_TEXT);
    this.ops.varuint(stringRef);
    this.ops.f32le(x); this.ops.f32le(y); this.ops.f32le(advance);
  }

  image(index, x, y, w, h) {
    if (!Number.isInteger(index) || index < 0 || index >= this.images.length) {
      throw new DiagramEncodeError("invalid image reference", "invalid-input");
    }
    if (this.autoGrow) {
      this.grow(x, y, w, h);
    }
    this.ops.u8(OP.IMAGE);
    this.ops.varuint(index);
    this.ops.f32le(x); this.ops.f32le(y); this.ops.f32le(w); this.ops.f32le(h);
  }

  encode(bbox) {
    const writer = new ByteWriter();
    writer.raw([0x42, 0x4f, 0x42, 0x4a]); // "BOBJ"
    writer.u16le(1); // opset
    writer.u16le(0); // reserved flags
    const box = bbox ?? this.bbox ?? { x: 0, y: 0, w: 0, h: 0 };
    for (const value of [box.x, box.y, box.w, box.h]) {
      writer.f32le(value);
    }
    writer.varuint(this.strings.length);
    for (const value of this.strings) {
      writer.string(value);
    }
    writer.varuint(this.paths.length);
    for (const path of this.paths) {
      writer.u8(0); // inline path
      path.write(writer);
    }
    writer.varuint(0); // no paints
    writer.varuint(this.fonts.length);
    for (const font of this.fonts) {
      writer.u8(1); // system font
      writer.string(font.family);
      writer.u16le(font.weight);
      writer.u8(FONT_STYLE[font.style] ?? 0);
    }
    writer.varuint(this.images.length);
    // Object image tables store part names as 16 raw bytes, mirroring
    // core/object_encode.mbt's object_write_hash.
    for (const image of this.images) {
      writer.raw(imageHashBytes(image));
    }
    writer.varuint(0); // no child objects
    writer.varuint(this.ops.length);
    writer.raw(this.ops.toBytes());
    return writer.toBytes();
  }
}

const DEFAULT_TEXT_FILL = { r: 30, g: 30, b: 30, a: 255 };

// Validated copy of a points list; the caller's array is never touched.
function pointList(prim, minPoints, what) {
  if (!Array.isArray(prim.points) || prim.points.length < minPoints || prim.points.length > MAX_POINTS_PER_PRIM) {
    throw new DiagramEncodeError(`${what} must have between ${minPoints} and ${MAX_POINTS_PER_PRIM} points`, "invalid-input");
  }
  const out = [];
  for (const point of prim.points) {
    if (!Array.isArray(point) || point.length !== 2) {
      throw new DiagramEncodeError(`${what} points must be [x, y] pairs`, "invalid-input");
    }
    out.push([finiteNumber(point[0], `${what} x`), finiteNumber(point[1], `${what} y`)]);
  }
  return out;
}

// An unrotated extent box for a primitive, used for the rotation pivot
// default and the bounding box (the rotated AABB of these corners).
// `points` is the validated points list (or null), `text` the resolved text
// metrics (or null); both come from the validation pass.
// The miter limit every emitted line() op carries; exported because the
// d.ts documents it and the extent helpers below clamp by it.
export const MITER_LIMIT = 10;

///|
// The stroke protrusion of a miter join at vertex `at`, joining the segment
// `prev -> at` to `at -> next`, for a stroke of the given width. The outer
// miter point sits on the bisector at half/sin(theta/2) from the vertex,
// where theta is the angle between the two segments; the miter limit clamps
// what actually renders (canvas bevels a join that exceeds it), so the bound
// never runs away for degenerate angles.
export function strokeJoinProtrusion(prev, at, next, strokeWidth) {
  const half = strokeWidth / 2;
  const v1x = prev[0] - at[0];
  const v1y = prev[1] - at[1];
  const v2x = next[0] - at[0];
  const v2y = next[1] - at[1];
  const l1 = Math.hypot(v1x, v1y);
  const l2 = Math.hypot(v2x, v2y);
  if (l1 === 0 || l2 === 0) {
    return half;
  }
  const cosTheta = Math.min(1, Math.max(-1, (v1x * v2x + v1y * v2y) / (l1 * l2)));
  const sinHalf = Math.sqrt(Math.max(0, (1 - cosTheta) / 2));
  if (sinHalf <= 1e-12) {
    // A straight continuation joins flush; the limit is the bound anyway.
    return half * MITER_LIMIT;
  }
  return Math.min(half / sinHalf, half * MITER_LIMIT);
}

///|
// Consecutive duplicate vertices render no geometry of their own, but they
// must not hide the join between the distinct segments on either side of
// them (the rendered corner stays). Extent math therefore works on a copy
// with consecutive duplicates collapsed; a closed ring also drops a final
// vertex that repeats the first, so the seam's join is found too.
function dedupeStrokedPoints(points, closed) {
  const out = [];
  for (const point of points) {
    const last = out[out.length - 1];
    if (last !== undefined && last[0] === point[0] && last[1] === point[1]) {
      continue;
    }
    out.push(point);
  }
  if (closed && out.length > 1) {
    const first = out[0];
    const last = out[out.length - 1];
    if (first[0] === last[0] && first[1] === last[1]) {
      out.pop();
    }
  }
  return out;
}

///|
// The page-space extent of a stroked polyline or closed polygon ring: the
// point cloud grown by half the stroke width on each side, plus the miter
// protrusions at the interior (a closed ring: every) vertices. Adapters use
// this for page fitting so thick acute joins cannot leave the page the way a
// plain half-width pad does. The result is a conservative bound: a join the
// canvas bevels on the miter limit stays covered by its clamped protrusion.
export function strokedPolylineExtent(points, strokeWidth, closed = false) {
  let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
  const include = (px, py) => {
    x0 = Math.min(x0, px); y0 = Math.min(y0, py);
    x1 = Math.max(x1, px); y1 = Math.max(y1, py);
  };
  for (const [x, y] of points) {
    include(x, y);
  }
  const half = strokeWidth / 2;
  if (Number.isFinite(x0)) {
    x0 -= half; y0 -= half; x1 += half; y1 += half;
  }
  const sane = dedupeStrokedPoints(points, closed);
  const count = sane.length;
  for (let i = 1; i < count - 1; i += 1) {
    // Polyline: only interior vertices carry a join.
    const p = strokeJoinProtrusion(sane[i - 1], sane[i], sane[i + 1], strokeWidth);
    include(sane[i][0] - p, sane[i][1] - p);
    include(sane[i][0] + p, sane[i][1] + p);
  }
  if (closed && count > 2) {
    // A closed ring joins at every vertex, including the seam.
    const ring = [
      sane[count - 1], ...sane, sane[0],
    ];
    for (let i = 1; i < ring.length - 1; i += 1) {
      const p = strokeJoinProtrusion(ring[i - 1], ring[i], ring[i + 1], strokeWidth);
      include(ring[i][0] - p, ring[i][1] - p);
      include(ring[i][0] + p, ring[i][1] + p);
    }
  }
  return { x: x0, y: y0, w: x1 - x0, h: y1 - y0 };
}

function primCorners(prim, points, textMetrics) {
  switch (prim.kind) {
    case "rect": {
      // Negative w/h keep the canvas mirror semantics: the rectangle runs
      // the other way. Normalize the corners FIRST so that padding,
      // rotation and the bbox below never see an unordered box (padding an
      // unordered box would shrink instead of grow it).
      const x0 = Math.min(prim.x, prim.x + prim.w);
      const y0 = Math.min(prim.y, prim.y + prim.h);
      const x1 = Math.max(prim.x, prim.x + prim.w);
      const y1 = Math.max(prim.y, prim.y + prim.h);
      return { cx: (x0 + x1) / 2, cy: (y0 + y1) / 2, box: [x0, y0, x1, y1] };
    }
    case "ellipse":
      return { cx: prim.cx, cy: prim.cy, box: [prim.cx - prim.rx, prim.cy - prim.ry, prim.cx + prim.rx, prim.cy + prim.ry] };
    case "polygon":
    case "polyline": {
      let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
      for (const [x, y] of points) {
        x0 = Math.min(x0, x); y0 = Math.min(y0, y);
        x1 = Math.max(x1, x); y1 = Math.max(y1, y);
      }
      return { cx: (x0 + x1) / 2, cy: (y0 + y1) / 2, box: [x0, y0, x1, y1] };
    }
    case "text": {
      // The band covers the estimated advance width by alignment, and the
      // text height by baseline; it rotates about (x, y) or the pivot.
      const { x, y } = prim;
      const { advance, fontSize } = textMetrics;
      const height = fontSize * 1.2;
      let x0;
      let x1;
      switch (prim.align ?? "left") {
        case "right":
        case "end":
          x0 = x - advance; x1 = x;
          break;
        case "center":
          x0 = x - advance / 2; x1 = x + advance / 2;
          break;
        default:
          x0 = x; x1 = x + advance;
      }
      let y0;
      let y1;
      switch (prim.baseline ?? "top") {
        case "middle":
          y0 = y - height / 2; y1 = y + height / 2;
          break;
        case "bottom":
          y0 = y - height; y1 = y;
          break;
        case "alphabetic":
          y0 = y - fontSize * 0.8; y1 = y + fontSize * 0.2;
          break;
        case "hanging":
          y0 = y - fontSize * 0.85; y1 = y + fontSize * 0.35;
          break;
        case "ideographic":
          y0 = y - fontSize * 0.8; y1 = y + fontSize * 0.2;
          break;
        default: // top
          y0 = y; y1 = y + height;
      }
      return { cx: x, cy: y, box: [x0, y0, x1, y1] };
    }
    case "image": {
      // Dimensions are validated positive before this runs; the corners
      // are ordered defensively anyway so the bbox math never sees an
      // inside-out box.
      const x0 = Math.min(prim.x, prim.x + prim.w);
      const y0 = Math.min(prim.y, prim.y + prim.h);
      const x1 = Math.max(prim.x, prim.x + prim.w);
      const y1 = Math.max(prim.y, prim.y + prim.h);
      return { cx: (x0 + x1) / 2, cy: (y0 + y1) / 2, box: [x0, y0, x1, y1] };
    }
    default:
      return null;
  }
}

function rotatedAABB(corners, pivotX, pivotY, angle) {
  if (angle === 0) {
    return { x: corners[0], y: corners[1], w: corners[2] - corners[0], h: corners[3] - corners[1] };
  }
  const cos = Math.cos(angle);
  const sin = Math.sin(angle);
  let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
  for (const [px, py] of [[corners[0], corners[1]], [corners[2], corners[1]], [corners[2], corners[3]], [corners[0], corners[3]]]) {
    const dx = px - pivotX;
    const dy = py - pivotY;
    const rx = pivotX + cos * dx - sin * dy;
    const ry = pivotY + sin * dx + cos * dy;
    x0 = Math.min(x0, rx); y0 = Math.min(y0, ry);
    x1 = Math.max(x1, rx); y1 = Math.max(y1, ry);
  }
  return { x: x0, y: y0, w: x1 - x0, h: y1 - y0 };
}

// Text metrics resolve once per primitive: the advance (explicit override or
// the 0.6em-per-codepoint estimate; adapters pass a CJK-aware override), the
// validated font attributes and the resolved fill.
function textMetricsOf(prim) {
  if (typeof prim.text !== "string") {
    throw new DiagramEncodeError("text primitive needs a text string", "invalid-input");
  }
  if (prim.text.length > MAX_TEXT_CHARS) {
    throw new DiagramEncodeError("text exceeds the 4096-character limit", "too-large");
  }
  const fontSize = prim.fontSize === undefined ? 16 : prim.fontSize;
  if (typeof fontSize !== "number" || !Number.isFinite(fontSize) || fontSize <= 0 || fontSize > 1000) {
    throw new DiagramEncodeError("fontSize must be a positive finite number up to 1000", "invalid-input");
  }
  const advance = prim.advance === undefined
    ? fontSize * 0.6 * [...prim.text].length
    : prim.advance;
  if (typeof advance !== "number" || !Number.isFinite(advance) || advance < 0 || advance > MAX_ADVANCE) {
    throw new DiagramEncodeError(`text advance must be a finite number within 0..${MAX_ADVANCE}`, "invalid-input");
  }
  const fill = colorToU32(prim.fill ?? DEFAULT_TEXT_FILL);
  const family = typeof prim.family === "string" && prim.family !== "" ? prim.family : "Helvetica";
  const weight = prim.weight === undefined ? 400 : prim.weight;
  if (!Number.isInteger(weight) || weight < 100 || weight > 900) {
    throw new DiagramEncodeError("text weight must be an integer 100..900", "invalid-input");
  }
  const style = prim.style === undefined ? "normal" : prim.style;
  if (typeof style !== "string" || !(style in FONT_STYLE)) {
    throw new DiagramEncodeError("text style must be normal, italic or oblique", "invalid-input");
  }
  const align = prim.align === undefined ? "left" : prim.align;
  if (typeof align !== "string" || !(align in TEXT_ALIGN)) {
    throw new DiagramEncodeError("text align must be left, right, center, start or end", "invalid-input");
  }
  const baseline = prim.baseline === undefined ? "top" : prim.baseline;
  if (typeof baseline !== "string" || !(baseline in TEXT_BASELINE)) {
    throw new DiagramEncodeError("text baseline is not a known baseline", "invalid-input");
  }
  return { text: prim.text, fontSize, advance, fill, family, weight, style, align, baseline };
}

///|
// Aggregate caps accumulator shared by both entry points (document-wide:
// every page contributes before any page is built).
function newCaps() {
  return { points: 0, textChars: 0 };
}

function addCaps(caps, primitives) {
  for (const prim of primitives) {
    if (typeof prim !== "object" || prim === null || Array.isArray(prim)) {
      continue;
    }
    if (Array.isArray(prim.points)) {
      caps.points += prim.points.length;
      if (caps.points > MAX_TOTAL_POINTS) {
        throw new DiagramEncodeError(`document exceeds ${MAX_TOTAL_POINTS} total points`, "too-large");
      }
    }
    if (typeof prim.text === "string") {
      caps.textChars += prim.text.length;
      if (caps.textChars > MAX_TOTAL_TEXT_CHARS) {
        throw new DiagramEncodeError(`document exceeds ${MAX_TOTAL_TEXT_CHARS} total text characters`, "too-large");
      }
    }
  }
}

///|
// Pass 2 of one page: validate every primitive in order, grow the exact
// rotation-aware bounding box, and emit the ops. `images` is the resource
// registry (id -> record) or null when image primitives are not offered
// (the single-diagram entry point keeps rejecting them); `refs` collects
// the resource ids the page referenced.
function encodePageObject(primitives, images, refs) {
  const builder = new ObjectBuilder();
  builder.autoGrow = false;
  for (const prim of primitives) {
    if (typeof prim !== "object" || prim === null || Array.isArray(prim) || typeof prim.kind !== "string") {
      throw new DiagramEncodeError("primitive must be an object with a kind", "invalid-input");
    }
    const style = prim.kind === "image" ? imageStyleOf(prim) : styleOf(prim);
    const pivot = pivotOf(prim);
    let points = null;
    let rounded = null;
    let textMetrics = null;
    let imageRecord = null;

    switch (prim.kind) {
      case "rect": {
        finiteNumber(prim.x, "rect x"); finiteNumber(prim.y, "rect y");
        finiteNumber(prim.w, "rect w"); finiteNumber(prim.h, "rect h");
        if (prim.rounded !== undefined && prim.rounded !== null) {
          rounded = finiteNumber(prim.rounded, "rounded corner radius", MAX_RADIUS);
          if (rounded < 0) {
            throw new DiagramEncodeError("rounded corner radius must be >= 0", "invalid-input");
          }
        }
        break;
      }
      case "ellipse": {
        finiteNumber(prim.cx, "ellipse cx"); finiteNumber(prim.cy, "ellipse cy");
        finiteNumber(prim.rx, "ellipse rx", MAX_RADIUS); finiteNumber(prim.ry, "ellipse ry", MAX_RADIUS);
        if (prim.rx < 0 || prim.ry < 0) {
          throw new DiagramEncodeError("ellipse radii must be nonnegative", "invalid-input");
        }
        break;
      }
      case "polygon":
      case "polyline": {
        points = pointList(prim, prim.kind === "polygon" ? 3 : 2, prim.kind);
        break;
      }
      case "text": {
        finiteNumber(prim.x, "text x"); finiteNumber(prim.y, "text y");
        textMetrics = textMetricsOf(prim);
        break;
      }
      case "image": {
        if (images === null) {
          throw new DiagramEncodeError(`unknown primitive kind "${prim.kind}"`, "invalid-input");
        }
        finiteNumber(prim.x, "image x"); finiteNumber(prim.y, "image y");
        finiteNumber(prim.w, "image w"); finiteNumber(prim.h, "image h");
        // The BDF image op keeps canvas drawImage semantics, which do NOT
        // mirror nonpositive rectangles the way drawRect does; a nonpositive
        // rectangle draws nothing, so it is rejected outright.
        if (prim.w <= 0 || prim.h <= 0) {
          throw new DiagramEncodeError("image rectangle dimensions must be positive", "invalid-input");
        }
        if (typeof prim.image !== "string" || prim.image === "" || prim.image.length > MAX_IMAGE_ID_CHARS) {
          throw new DiagramEncodeError("image primitive needs a resource id of 1..128 characters", "invalid-input");
        }
        imageRecord = images.get(prim.image);
        if (imageRecord === undefined) {
          throw new DiagramEncodeError(`unknown image resource "${prim.image}"`, "invalid-input");
        }
        if (refs !== null) {
          refs.add(prim.image);
        }
        break;
      }
      default:
        throw new DiagramEncodeError(`unknown primitive kind "${prim.kind}"`, "invalid-input");
    }

    const corners = primCorners(prim, points, textMetrics);
    const pivotX = pivot === null ? corners.cx : pivot[0];
    const pivotY = pivot === null ? corners.cy : pivot[1];
    // Strokes grow the geometry extent by half the stroke width on each side;
    // a miter join on an acute corner grows past that (half/sin(theta/2),
    // clamped by the miter limit), so the protrusions join the bound too.
    let pad = (style.stroke !== null && prim.kind !== "text") ? style.strokeWidth / 2 : 0;
    if (style.stroke !== null && (prim.kind === "polygon" || prim.kind === "polyline") && points !== null) {
      const extent = strokedPolylineExtent(points, style.strokeWidth, prim.kind === "polygon");
      if (Number.isFinite(extent.x)) {
        corners.box = [extent.x, extent.y, extent.x + extent.w, extent.y + extent.h];
        pad = 0; // the extent already includes the stroke pads and joins
      }
    }
    const padded = [
      corners.box[0] - pad, corners.box[1] - pad,
      corners.box[2] + pad, corners.box[3] + pad,
    ];
    const aabb = rotatedAABB(padded, pivotX, pivotY, style.angle);
    builder.grow(aabb.x, aabb.y, aabb.w, aabb.h);
    if (prim.kind === "image") {
      emitImagePrim(builder, prim, style, builder.imageRef(imageRecord.hash), pivotX, pivotY);
    } else {
      emitPrimitive(builder, prim, style, corners, points, rounded, textMetrics, pivotX, pivotY);
    }
  }
  return builder.encode(null);
}

///|
// Layout and emission of one single-file BDF: parts are stored in the given
// order right after the manifest, so each entry's off is relative to the
// manifest end, exactly how core/container.mbt reads them back.
function writeSingleFileDocument({ meta, views, parts }) {
  const entries = [];
  let offset = 0;
  for (const part of parts) {
    entries.push({
      h: part.hash,
      t: part.kind,
      enc: "identity",
      len: part.bytes.length,
      size: part.bytes.length,
      off: offset,
    });
    offset += part.bytes.length;
  }
  const manifest = {
    bdf: 1,
    opset: 1,
    unit: "pt",
    meta,
    views,
    parts: entries,
  };
  const manifestBytes = new TextEncoder().encode(JSON.stringify(manifest));
  if (manifestBytes.length > 268435456) {
    throw new DiagramEncodeError("manifest exceeds the 256 MiB limit", "too-large");
  }
  const out = new ByteWriter();
  out.raw([0x62, 0x64, 0x66, 0x00]); // "bdf\0"
  out.u16le(1); // format version
  out.u16le(0); // flags: plain single file
  out.u64le(32); // manifest offset
  out.u64le(manifestBytes.length);
  out.u8(0); // identity manifest encoding
  out.raw(new Uint8Array(7));
  out.raw(manifestBytes);
  for (const part of parts) {
    out.raw(part.bytes);
  }
  return out.toBytes();
}

///|
// Encode the diagram document as a complete single-file BDF byte string.
// Deterministic: identical input produces byte-identical output. The input
// is treated as read-only.
export async function encodeDiagram(input) {
  if (typeof input !== "object" || input === null || Array.isArray(input)) {
    throw new DiagramEncodeError("encodeDiagram needs an input object", "invalid-input");
  }
  const { width, height, source, title, primitives } = input;
  if (typeof source !== "string" || source === "" || !/^[a-z][a-z0-9-]*$/.test(source)) {
    throw new DiagramEncodeError("source must be a lowercase format identifier", "invalid-input");
  }
  const pageTitle = title === undefined ? "" : title;
  if (typeof pageTitle !== "string" || pageTitle.length > 512) {
    throw new DiagramEncodeError("title must be a string of at most 512 characters", "invalid-input");
  }
  finiteNumber(width, "width", BDF_MAX_PAGE_UNITS);
  finiteNumber(height, "height", BDF_MAX_PAGE_UNITS);
  if (width <= 0 || height <= 0 || width > BDF_MAX_PAGE_UNITS || height > BDF_MAX_PAGE_UNITS) {
    throw new DiagramEncodeError(`page size must be within 0 < w, h <= ${BDF_MAX_PAGE_UNITS}`, "invalid-input");
  }
  if (!Array.isArray(primitives) || primitives.length > MAX_PRIMITIVES) {
    throw new DiagramEncodeError(
      `primitives must be an array of at most ${MAX_PRIMITIVES} items`,
      primitives === undefined || !Array.isArray(primitives) ? "invalid-input" : "too-large",
    );
  }

  // Pass 1 (cheap, before any emission): aggregate caps, so input sizes
  // cannot amplify into unbounded work. Per-primitive validation happens in
  // pass 2 with its stable per-primitive error order.
  const caps = newCaps();
  addCaps(caps, primitives);

  const objectBytes = encodePageObject(primitives, null, null);
  const hash = sha256(objectBytes).slice(0, 32);
  return writeSingleFileDocument({
    meta: { generator: `bdf-diagram/${source}` },
    views: [{
      id: "page-0",
      kind: "fixed",
      title: pageTitle,
      direction: "ltr",
      pages: [{
        w: width,
        h: height,
        layers: [{ role: "content", obj: hash }],
      }],
    }],
    parts: [{ hash, kind: "obj", bytes: objectBytes }],
  });
}

// Every primitive is wrapped in save/restore: stroke width, dash, colors,
// alpha and transform of one primitive can never leak into the next (a
// dashed shape followed by a solid shape must not draw the second dashed).
function emitShape(builder, prim, style, corners, points, rounded, pivotX, pivotY) {
  const wantsStroke = style.stroke !== null;
  const wantsFill = style.fill !== null && prim.kind !== "polyline";
  if (!wantsStroke && !wantsFill) {
    return;
  }
  builder.save();
  if (style.angle !== 0) {
    const cos = Math.cos(style.angle);
    const sin = Math.sin(style.angle);
    builder.translate(pivotX, pivotY);
    builder.transform(cos, sin, -sin, cos, 0, 0);
    builder.translate(-pivotX, -pivotY);
  }
  if (style.opacity !== 1) {
    builder.alpha(style.opacity);
  }
  if (wantsStroke) {
    builder.strokeColor(style.stroke);
    builder.line(style.strokeWidth);
    if (style.dash) {
      builder.dash(style.dash);
    }
  }
  if (wantsFill) {
    builder.fillColor(style.fill);
  }

  if (prim.kind === "rect" && !rounded) {
    if (wantsFill) {
      builder.fillRect(prim.x, prim.y, prim.w, prim.h);
    }
    if (wantsStroke) {
      builder.strokeRect(prim.x, prim.y, prim.w, prim.h);
    }
  } else {
    const path = new PathBuilder();
    if (prim.kind === "rect") {
      path.roundRect(prim.x, prim.y, prim.w, prim.h, rounded);
    } else if (prim.kind === "ellipse") {
      path.ellipse(prim.cx, prim.cy, prim.rx, prim.ry);
    } else {
      path.move(points[0][0], points[0][1]);
      for (let i = 1; i < points.length; i += 1) {
        path.line(points[i][0], points[i][1]);
      }
      if (prim.kind === "polygon") {
        path.close();
      }
    }
    const index = builder.addPath(path);
    if (wantsFill) {
      builder.fillPath(index);
    }
    if (wantsStroke) {
      builder.strokePath(index);
    }
  }
  builder.restore();
}

// Text emission: same save/restore discipline, font and text-style state
// inside the block, rotation about the pivot (default: the text anchor x, y).
function emitTextPrim(builder, prim, style, textMetrics, pivotX, pivotY) {
  builder.save();
  if (style.angle !== 0) {
    const cos = Math.cos(style.angle);
    const sin = Math.sin(style.angle);
    builder.translate(pivotX, pivotY);
    builder.transform(cos, sin, -sin, cos, 0, 0);
    builder.translate(-pivotX, -pivotY);
  }
  if (style.opacity !== 1) {
    builder.alpha(style.opacity);
  }
  const fontIndex = builder.fontRef(textMetrics.family, textMetrics.weight, textMetrics.style);
  builder.font(fontIndex, textMetrics.fontSize);
  builder.textStyle(textMetrics.align, textMetrics.baseline, "ltr");
  if (textMetrics.fill !== null) {
    builder.fillColor(textMetrics.fill);
  }
  builder.fillText(builder.stringRef(textMetrics.text), prim.x, prim.y, textMetrics.advance);
  builder.restore();
}

// Image emission: the same save/restore discipline; rotation about the
// pivot (default: the drawn rectangle's center) and alpha inside the block.
function emitImagePrim(builder, prim, style, imageTableIndex, pivotX, pivotY) {
  builder.save();
  if (style.angle !== 0) {
    const cos = Math.cos(style.angle);
    const sin = Math.sin(style.angle);
    builder.translate(pivotX, pivotY);
    builder.transform(cos, sin, -sin, cos, 0, 0);
    builder.translate(-pivotX, -pivotY);
  }
  if (style.opacity !== 1) {
    builder.alpha(style.opacity);
  }
  builder.image(imageTableIndex, prim.x, prim.y, prim.w, prim.h);
  builder.restore();
}

function emitPrimitive(builder, prim, style, corners, points, rounded, textMetrics, pivotX, pivotY) {
  if (prim.kind === "text") {
    emitTextPrim(builder, prim, style, textMetrics, pivotX, pivotY);
    return;
  }
  emitShape(builder, prim, style, corners, points, rounded, pivotX, pivotY);
}

///|
// Embedded raster resources are actual bytes, never references: URLs, file
// paths and strings are rejected, and the accepted types are only bounded
// PNG (8-byte signature + IHDR) and JPEG (SOI + SOF frame header), both with
// readable dimensions. SVG, GIF, BMP and WebP stay out of the plugin, and
// the bytes are never modified or coerced into other formats.
function imageDataView(data) {
  if (data instanceof Uint8Array) {
    return data;
  }
  if (data instanceof ArrayBuffer) {
    return new Uint8Array(data);
  }
  throw new DiagramEncodeError("image data must be PNG or JPEG bytes in a Uint8Array or ArrayBuffer, never a URL or a string", "invalid-input");
}

///|
// Signature, size, structure and dimension validation: deterministic,
// read-only and bounded — the PNG chunk table and the JPEG segment table
// are each walked with every length checked against the actual bytes, so a
// truncated file, a chunk/segment length pointing past the end, a missing
// SOS or EOI, or a raster whose bytes end before its last declared chunk
// is rejected up front. CRCs and entropy data are not re-verified (the
// browser decodes the same bytes); everything structural is.
function imageRasterInfo(bytes) {
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const check = (width, height) => {
    if (!Number.isInteger(width) || !Number.isInteger(height) || width < 1 || height < 1) {
      throw new DiagramEncodeError("image dimensions must be positive integers", "invalid-input");
    }
    if (width > MAX_IMAGE_SIDE || height > MAX_IMAGE_SIDE) {
      throw new DiagramEncodeError(`image side exceeds ${MAX_IMAGE_SIDE} pixels`, "too-large");
    }
    if (width * height > MAX_IMAGE_PIXELS) {
      throw new DiagramEncodeError(`image exceeds ${MAX_IMAGE_PIXELS} total pixels`, "too-large");
    }
  };
  const isPngSignature = bytes.length >= 8 && bytes[0] === 0x89 && bytes[1] === 0x50
    && bytes[2] === 0x4e && bytes[3] === 0x47 && bytes[4] === 0x0d
    && bytes[5] === 0x0a && bytes[6] === 0x1a && bytes[7] === 0x0a;
  if (isPngSignature) {
    return pngRasterInfo(bytes, view, check);
  }
  if (bytes.length >= 4 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) {
    return jpegRasterInfo(bytes, view, check);
  }
  throw new DiagramEncodeError("embedded images must be bounded PNG or JPEG bytes (SVG, GIF, BMP, WebP and URLs are not accepted)", "invalid-input");
}

///|
// Bounded PNG structure: the 8-byte signature, a first chunk that is a
// 13-byte IHDR inside the file, every chunk length in range, at least one
// non-empty IDAT before the IEND, and a file that ends exactly at the
// IEND chunk (no truncation, no trailing bytes). Palette images must
// actually carry a PLTE chunk; dimensions come from the IHDR.
function pngRasterInfo(bytes, view, check) {
  const isType = (at, type) => type.every((byte, i) => bytes[at + i] === byte);
  if (bytes.length < 8) {
    throw new DiagramEncodeError("PNG data is truncated before the chunk table", "invalid-input");
  }
  let at = 8;
  let width = 0;
  let height = 0;
  let colorType = 0;
  let hasPalette = false;
  let idatBytes = 0;
  let sawIend = false;
  if (!isType(12, [0x49, 0x48, 0x44, 0x52])) {
    throw new DiagramEncodeError("PNG data does not start with an IHDR chunk", "invalid-input");
  }
  while (at < bytes.length) {
    if (bytes.length - at < 12) {
      throw new DiagramEncodeError("PNG chunk table is truncated", "invalid-input");
    }
    const length = view.getUint32(at);
    if (length > bytes.length - at - 12) {
      throw new DiagramEncodeError("PNG chunk length points past the end of the data", "invalid-input");
    }
    const kind = isType(at + 4, [0x49, 0x48, 0x44, 0x52]) ? "IHDR"
      : isType(at + 4, [0x50, 0x4c, 0x54, 0x45]) ? "PLTE"
      : isType(at + 4, [0x49, 0x44, 0x41, 0x54]) ? "IDAT"
      : isType(at + 4, [0x49, 0x45, 0x4e, 0x44]) ? "IEND"
      : isType(at + 4, [0x74, 0x52, 0x4e, 0x53]) ? "tRNS"
      : isType(at + 4, [0x67, 0x61, 0x6d, 0x41]) ? "gAMA"
      : isType(at + 4, [0x74, 0x45, 0x58, 0x74]) ? "tEXt"
      : isType(at + 4, [0x7a, 0x54, 0x58, 0x74]) ? "zTXt"
      : isType(at + 4, [0x69, 0x54, 0x58, 0x74]) ? "iTXt"
      : null;
    if (kind === null) {
      // Ancillary and private chunks are skipped structurally; an unknown
      // chunk with an UPPERCASE name bit would be critical to a real
      // decoder, so it is rejected rather than silently accepted.
      const first = bytes[at + 4];
      if (first >= 0x41 && first <= 0x5a) {
        throw new DiagramEncodeError("PNG data contains an unknown critical chunk", "invalid-input");
      }
    } else if (kind === "IHDR") {
      if (at !== 8 || length !== 13) {
        throw new DiagramEncodeError("PNG IHDR must be the first, 13-byte chunk", "invalid-input");
      }
      width = view.getUint32(at + 8);
      height = view.getUint32(at + 12);
      const bitDepth = bytes[at + 16];
      colorType = bytes[at + 17];
      if (view.getUint8(at + 18) !== 0 || view.getUint8(at + 19) !== 0 || view.getUint8(at + 20) > 1) {
        throw new DiagramEncodeError("PNG IHDR has invalid compression, filter or interlace fields", "invalid-input");
      }
      if (![1, 2, 4, 8, 16].includes(bitDepth)
        || ![0, 2, 3, 4, 6].includes(colorType)
        || (colorType === 3 && ![1, 2, 4, 8].includes(bitDepth))
        || ((colorType === 2 || colorType === 4 || colorType === 6) && bitDepth !== 8 && bitDepth !== 16)
        || (colorType === 4 && bitDepth < 8)) {
        throw new DiagramEncodeError("PNG IHDR has an invalid bit depth / color type pair", "invalid-input");
      }
      if (width === 0 || height === 0) {
        throw new DiagramEncodeError("image dimensions must be positive integers", "invalid-input");
      }
      check(width, height);
    } else if (kind === "PLTE") {
      hasPalette = true;
      if (length === 0 || length % 3 !== 0 || length > 768) {
        throw new DiagramEncodeError("PNG PLTE chunk has an invalid length", "invalid-input");
      }
    } else if (kind === "IDAT") {
      if (sawIend) {
        throw new DiagramEncodeError("PNG IDAT chunk appears after IEND", "invalid-input");
      }
      idatBytes += length;
    } else if (kind === "IEND") {
      if (length !== 0) {
        throw new DiagramEncodeError("PNG IEND chunk must be empty", "invalid-input");
      }
      sawIend = true;
    }
    at += 12 + length;
    if (sawIend) {
      break;
    }
  }
  if (!sawIend) {
    throw new DiagramEncodeError("PNG data is truncated before the IEND chunk", "invalid-input");
  }
  if (at !== bytes.length) {
    throw new DiagramEncodeError("PNG data has bytes after the IEND chunk", "invalid-input");
  }
  if (idatBytes === 0) {
    throw new DiagramEncodeError("PNG data has no IDAT image data", "invalid-input");
  }
  if (colorType === 3 && !hasPalette) {
    throw new DiagramEncodeError("PNG palette image has no PLTE chunk", "invalid-input");
  }
  return { format: "png", width, height };
}

///|
// Bounded JPEG structure: SOI, then every segment (marker + length) fully
// inside the file, exactly one frame (SOF) before a scan, a start-of-scan
// inside the file followed by at least one entropy byte, and an EOI that
// ends the file. Entropy bytes are walked with FF00 byte-stuffing,
// restart markers and FF fill honored, but not decoded (the browser
// decodes the same bytes later).
function jpegRasterInfo(bytes, view, check) {
  let at = 2; // SOI consumed
  let width = null;
  let height = null;
  let scanning = false;
  let scanBytes = 0;
  let sawScan = false;
  const isStandalone = marker => marker === 0x01 || (marker >= 0xd0 && marker <= 0xd7);
  while (at < bytes.length) {
    if (scanning) {
      // inside the entropy-coded scan: skip byte-stuffed FF00 pairs,
      // restart markers and FF fill bytes until a real marker appears
      if (bytes[at] !== 0xff) {
        scanBytes += 1;
        at += 1;
        continue;
      }
      if (at + 1 >= bytes.length) {
        throw new DiagramEncodeError("JPEG data is truncated inside the scan", "invalid-input");
      }
      const next = bytes[at + 1];
      if (next === 0x00) {
        scanBytes += 2;
        at += 2;
        continue;
      }
      if (next === 0xff) {
        at += 1; // fill byte before a marker
        continue;
      }
      if (next >= 0xd0 && next <= 0xd7) {
        scanBytes += 2; // restart markers sit inside the entropy stream
        at += 2;
        continue;
      }
      if (next === 0x01) {
        at += 2; // TEM inside the scan
        continue;
      }
      const entropy = scanBytes;
      scanning = false;
      if (sawScan && entropy === 0) {
        throw new DiagramEncodeError("JPEG scan has no entropy data", "invalid-input");
      }
      // fall through: process the marker that ended the scan
    }
    if (bytes[at] !== 0xff) {
      throw new DiagramEncodeError("JPEG marker stream is malformed", "invalid-input");
    }
    const marker = bytes[at + 1];
    if (marker === 0xff) {
      at += 1;
      continue;
    }
    if (isStandalone(marker)) {
      at += 2;
      continue;
    }
    if (marker === 0xd8) {
      throw new DiagramEncodeError("JPEG has a second start of image", "invalid-input");
    }
    if (marker === 0xd9) {
      if (at + 2 !== bytes.length) {
        throw new DiagramEncodeError("JPEG EOI must be the last bytes of the file", "invalid-input");
      }
      if (width === null || height === null) {
        throw new DiagramEncodeError("JPEG data has no frame header before EOI", "invalid-input");
      }
      if (!sawScan) {
        throw new DiagramEncodeError("JPEG data has no start-of-scan", "invalid-input");
      }
      return { format: "jpeg", width, height };
    }
    if (marker === 0xda) {
      if (width === null || height === null) {
        throw new DiagramEncodeError("JPEG scan starts before the frame header", "invalid-input");
      }
      if (sawScan) {
        throw new DiagramEncodeError("JPEG has more than one scan", "invalid-input");
      }
      if (at + 4 > bytes.length) {
        throw new DiagramEncodeError("JPEG scan header is truncated", "invalid-input");
      }
      const length = view.getUint16(at + 2);
      if (length < 6 || at + 2 + length > bytes.length) {
        throw new DiagramEncodeError("JPEG scan header is out of range", "invalid-input");
      }
      sawScan = true;
      scanning = true;
      at += 2 + length;
      continue;
    }
    if (at + 4 > bytes.length) {
      throw new DiagramEncodeError("JPEG segment header is truncated", "invalid-input");
    }
    const length = view.getUint16(at + 2);
    if (length < 2 || at + 2 + length > bytes.length) {
      throw new DiagramEncodeError("JPEG segment length points past the end of the data", "invalid-input");
    }
    if (marker >= 0xc0 && marker <= 0xcf && marker !== 0xc4 && marker !== 0xc8 && marker !== 0xcc) {
      if (width !== null) {
        throw new DiagramEncodeError("JPEG has more than one frame header", "invalid-input");
      }
      if (length < 8 || at + 9 > bytes.length) {
        throw new DiagramEncodeError("JPEG frame header is truncated", "invalid-input");
      }
      height = view.getUint16(at + 5);
      width = view.getUint16(at + 7);
      check(width, height);
    }
    at += 2 + length;
  }
  throw new DiagramEncodeError("JPEG data is truncated before the EOI marker", "invalid-input");
}

///|
// The resource registry of one document: validated entries keyed by id and
// deduplicated by content hash, so identical bytes are stored (and hashed)
// exactly once no matter how many ids or references point at them.
function imageResourceRegistry(images) {
  const byId = new Map();
  const parts = [];
  const byHash = new Map();
  let totalUniqueBytes = 0;
  for (const entry of images) {
    if (typeof entry !== "object" || entry === null || Array.isArray(entry)) {
      throw new DiagramEncodeError("images entries must be {id, data} objects", "invalid-input");
    }
    const { id, data } = entry;
    if (typeof id !== "string" || id === "" || id.length > MAX_IMAGE_ID_CHARS) {
      throw new DiagramEncodeError("image id must be a string of 1..128 characters", "invalid-input");
    }
    if (byId.has(id)) {
      throw new DiagramEncodeError(`duplicate image id "${id}"`, "invalid-input");
    }
    const bytes = imageDataView(data);
    if (bytes.length > MAX_IMAGE_BYTES) {
      throw new DiagramEncodeError(`image "${id}" exceeds the ${MAX_IMAGE_BYTES}-byte resource cap`, "too-large");
    }
    imageRasterInfo(bytes);
    const hash = sha256(bytes).slice(0, 32);
    let record = byHash.get(hash);
    if (record === undefined) {
      if (totalUniqueBytes + bytes.length > MAX_TOTAL_IMAGE_BYTES) {
        throw new DiagramEncodeError(`document exceeds ${MAX_TOTAL_IMAGE_BYTES} total unique image bytes`, "too-large");
      }
      totalUniqueBytes += bytes.length;
      record = { hash, kind: "img", bytes };
      byHash.set(hash, record);
      parts.push(record);
    }
    byId.set(id, record);
  }
  return { byId, parts };
}

///|
// Validate one page object of encodeDiagramDocument: bounded size and the
// same page-size rules as the single-diagram entry point.
function documentPageRecord(page) {
  if (typeof page !== "object" || page === null || Array.isArray(page)) {
    throw new DiagramEncodeError("pages entries must be {width, height, primitives} objects", "invalid-input");
  }
  const { width, height, primitives } = page;
  finiteNumber(width, "width", BDF_MAX_PAGE_UNITS);
  finiteNumber(height, "height", BDF_MAX_PAGE_UNITS);
  if (width <= 0 || height <= 0 || width > BDF_MAX_PAGE_UNITS || height > BDF_MAX_PAGE_UNITS) {
    throw new DiagramEncodeError(`page size must be within 0 < w, h <= ${BDF_MAX_PAGE_UNITS}`, "invalid-input");
  }
  if (!Array.isArray(primitives) || primitives.length > MAX_PRIMITIVES) {
    throw new DiagramEncodeError(
      `primitives must be an array of at most ${MAX_PRIMITIVES} items`,
      primitives === undefined || !Array.isArray(primitives) ? "invalid-input" : "too-large",
    );
  }
  return { width, height, primitives };
}

///|
// Encode a multi-page diagram document as a complete single-file BDF byte
// string: one obj part per page plus one img part per unique embedded
// image, all content-deduplicated, referenced both ways, and verified
// byte-for-byte by the same invariants as encodeDiagram. Deterministic and
// read-only, exactly like the single-diagram entry point.
export async function encodeDiagramDocument(input) {
  if (typeof input !== "object" || input === null || Array.isArray(input)) {
    throw new DiagramEncodeError("encodeDiagramDocument needs an input object", "invalid-input");
  }
  const { source, title, pages, images } = input;
  if (typeof source !== "string" || source === "" || !/^[a-z][a-z0-9-]*$/.test(source)) {
    throw new DiagramEncodeError("source must be a lowercase format identifier", "invalid-input");
  }
  const documentTitle = title === undefined ? "" : title;
  if (typeof documentTitle !== "string" || documentTitle.length > 512) {
    throw new DiagramEncodeError("title must be a string of at most 512 characters", "invalid-input");
  }
  if (!Array.isArray(pages) || pages.length < 1 || pages.length > MAX_PAGES) {
    throw new DiagramEncodeError(
      `pages must be a non-empty array of at most ${MAX_PAGES} page objects`,
      Array.isArray(pages) ? "too-large" : "invalid-input",
    );
  }
  const imageList = images === undefined || images === null ? [] : images;
  if (!Array.isArray(imageList) || imageList.length > MAX_IMAGE_RESOURCES) {
    throw new DiagramEncodeError(
      `images must be an array of at most ${MAX_IMAGE_RESOURCES} resources`,
      Array.isArray(imageList) ? "too-large" : "invalid-input",
    );
  }
  const registry = imageResourceRegistry(imageList);

  const pageRecords = [];
  let totalPrimitives = 0;
  for (const page of pages) {
    const record = documentPageRecord(page);
    totalPrimitives += record.primitives.length;
    if (totalPrimitives > MAX_DOCUMENT_PRIMITIVES) {
      throw new DiagramEncodeError(`document exceeds ${MAX_DOCUMENT_PRIMITIVES} total primitives`, "too-large");
    }
    pageRecords.push(record);
  }
  const caps = newCaps();
  for (const record of pageRecords) {
    addCaps(caps, record.primitives);
  }

  // Referenced ids must resolve (checked while building each page below) and
  // every defined resource must be drawn by some page: bounded documents
  // never carry unreferenced bytes.
  const refs = new Set();
  const objectParts = [];
  const viewPages = [];
  for (const record of pageRecords) {
    const objectBytes = encodePageObject(record.primitives, registry.byId, refs);
    const hash = sha256(objectBytes).slice(0, 32);
    if (!objectParts.some(part => part.hash === hash)) {
      objectParts.push({ hash, kind: "obj", bytes: objectBytes });
    }
    viewPages.push({
      w: record.width,
      h: record.height,
      layers: [{ role: "content", obj: hash }],
    });
  }
  for (const id of registry.byId.keys()) {
    if (!refs.has(id)) {
      throw new DiagramEncodeError(`image "${id}" is never referenced by any page`, "invalid-input");
    }
  }

  return writeSingleFileDocument({
    meta: { generator: `bdf-diagram/${source}` },
    views: [{
      id: "pages",
      kind: "fixed",
      title: documentTitle,
      direction: "ltr",
      pages: viewPages,
    }],
    parts: [...objectParts, ...registry.parts],
  });
}
