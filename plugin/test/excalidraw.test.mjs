// Excalidraw adapter tests. Every conversion is verified through the
// independent reader (`openDiagram` on @bdfkit/core): never a magic-header
// sniff and never a decoder written by the adapter under test. Malformed
// documents must reject with a thrown Error carrying the documented code,
// never crash and never emit garbage.

import assert from "node:assert/strict";
import { test } from "node:test";

import {
  excalidrawPlugin,
  EXCALIDRAW_FORMAT_NAME,
  EXCALIDRAW_EXTENSIONS,
  EXCALIDRAW_DESCRIPTION,
} from "../src/adapters/excalidraw.js";
import { createFormatRegistry, docuworksPlugin } from "../src/index.js";
import { mulberry32, text as encodeText, docuworksLikeHeader } from "./helpers.mjs";
import { openDiagram } from "./diagram-reader.mjs";

const plugin = excalidrawPlugin();
const NO_OPTIONS = {};
const MARGIN = 16;
const INPUT_LIMIT = 8 * 1024 * 1024;
const PAGE_LIMIT = 16777216;

///|
// helpers ---------------------------------------------------------------

function sceneBytes(value) {
  return encodeText(JSON.stringify(value));
}

async function convertDoc(doc, options = NO_OPTIONS) {
  return plugin.convert(sceneBytes(doc), options);
}

async function openDoc(doc, options = NO_OPTIONS) {
  const result = await convertDoc(doc, options);
  assert.equal(result.format, EXCALIDRAW_FORMAT_NAME);
  assert.ok(result.bdf instanceof Uint8Array && result.bdf.length > 0, "bdf bytes");
  const opened = await openDiagram(result.bdf);
  return { result, opened };
}

///|
// A rectangle with solid red stroke, green fill, solid 2pt stroke, no angle.
function rectElement(over = {}) {
  return {
    type: "rectangle",
    id: "rect-1",
    x: 0,
    y: 0,
    width: 40,
    height: 20,
    strokeColor: "#ff0000",
    backgroundColor: "#00ff00",
    fillStyle: "solid",
    strokeStyle: "solid",
    strokeWidth: 2,
    ...over,
  };
}

function colorU32({ r, g, b, a }) {
  return (((r & 255) << 24) | ((g & 255) << 16) | ((b & 255) << 8) | (a & 255)) >>> 0;
}

const RED = colorU32({ r: 0xff, g: 0, b: 0, a: 0xff });
const GREEN = colorU32({ r: 0, g: 0xff, b: 0, a: 0xff });
const DEFAULT_COLOR = colorU32({ r: 0x1e, g: 0x1e, b: 0x1e, a: 0xff });

function approx(actual, expected, tolerance = 1e-6) {
  assert.ok(
    typeof actual === "number" && Number.isFinite(actual),
    `expected a finite number, got ${String(actual)}`,
  );
  assert.ok(
    Math.abs(actual - expected) <= tolerance,
    `expected ${actual} to be within ${tolerance} of ${expected}`,
  );
}

function approxArray(actual, expected, tolerance = 1e-6, message = "") {
  assert.ok(!Array.isArray(expected) || Array.isArray(actual) || actual instanceof Float32Array,
    `${message}: actual is not an array`);
  const list = Array.from(actual);
  assert.equal(list.length, expected.length, `${message}: length ${list.length} != ${expected.length}`);
  for (let i = 0; i < list.length; i += 1) {
    if (Array.isArray(expected[i])) {
      approxArray(list[i], expected[i], tolerance, `${message} [${i}]`);
    } else if (typeof expected[i] === "number") {
      approx(list[i], expected[i], tolerance);
    } else {
      assert.equal(list[i], expected[i], `${message} [${i}]`);
    }
  }
}

function opsOf(opened) {
  return opened.ops;
}

///|
// The semantic op list stripped of the save/restore scaffolding (rotation
// and opacity groups still assert their own scaffolding explicitly).
function contentOps(ops) {
  return ops.filter(op => op.op !== "save" && op.op !== "restore");
}

function checkDocumentShell(opened, { width, height }) {
  const { header, manifest, view, page, parts } = opened;
  assert.equal(header.version, 1, "bdf version 1");
  assert.equal(header.flags, 0, "bdf flags 0");
  assert.equal(header.manifestEnc, "identity", "identity manifest encoding");
  assert.ok(header.manifestOff > 0 && header.manifestLen > 0);
  assert.equal(manifest.bdf, 1);
  assert.equal(manifest.opset, 1);
  assert.equal(manifest.unit, "pt");
  assert.ok(manifest.meta && typeof manifest.meta === "object");
  assert.equal(view.id, "page-0");
  assert.equal(view.kind, "fixed");
  assert.equal(view.direction, "ltr");
  assert.equal(view.pages.length, 1, "one page");
  assert.equal(page.w, width, `page width ${page.w} != ${width}`);
  assert.equal(page.h, height, `page height ${page.h} != ${height}`);
  assert.equal(page.layers.length, 1);
  assert.equal(page.layers[0].role, "content", "single content layer");
  assert.equal(parts.length, 1, "one obj part");
  const part = parts[0];
  assert.equal(part.t, "obj", "part kind obj");
  assert.equal(part.enc, "identity", "part encoding identity");
  assert.ok(/^[0-9a-f]{32}$/.test(part.h), "32-char lowercase hex part name");
  assert.ok(typeof part.len === "number" && part.len > 0);
  assert.ok(typeof part.size === "number" && part.size > 0);
  assert.ok(typeof part.off === "number" && part.off >= 0);
  assert.ok(opened.object.ops instanceof Uint8Array, "decoded ops bytes");
  assert.ok(Array.isArray(opened.paths), "decoded inline paths");
}

///|
// One op whose args match `expected` (numbers compared with tolerance so
// float coordinates recorded by the reader need no bit-exactness).
function expectOp(opened, name, expectedArgs, message = "") {
  const candidates = opsOf(opened).filter(op => op.op === name);
  assert.ok(candidates.length > 0, `missing op "${name}" ${message}`);
  const found = candidates.find(op => {
    try {
      approxArray(op.args, expectedArgs, 1e-6, message);
      return true;
    } catch {
      return false;
    }
  });
  assert.ok(found !== undefined, message || `no "${name}" op with args ~${JSON.stringify(expectedArgs)}`);
  return found;
}

function expectNoOp(opened, name, message = "") {
  assert.ok(
    opsOf(opened).every(op => op.op !== name),
    message || `did not expect a "${name}" op`,
  );
}

function indexOfOp(opened, name, expectedArgs) {
  const found = expectOp(opened, name, expectedArgs);
  return opsOf(opened).indexOf(found);
}

function pathArgsOf(opened, pathIndex) {
  assert.ok(pathIndex >= 0 && pathIndex < opened.paths.length, `path index ${pathIndex} out of range`);
  return Array.from(opened.paths[pathIndex].args);
}

async function expectRejects(promise, code, messagePattern) {
  let error = null;
  let failed = false;
  try {
    await promise;
  } catch (caught) {
    error = caught;
    failed = true;
  }
  assert.ok(failed, "expected the promise to reject");
  assert.ok(error instanceof Error, `expected a thrown Error, got ${String(error)}`);
  if (code !== undefined) {
    assert.equal(error.code, code, `expected error code ${code}, got ${String(error?.code)}: ${error.message}`);
  }
  if (messagePattern !== undefined) {
    assert.match(error.message, messagePattern);
  }
  return error;
}

async function expectResolves(promise, message) {
  await promise;
  assert.ok(true, message);
}

///|
// descriptor -------------------------------------------------------------

test("the plugin carries the format contract surface", () => {
  assert.equal(plugin.apiVersion, 1);
  assert.equal(plugin.name, "excalidraw");
  assert.equal(plugin.version, "1.0.0");
  assert.equal(plugin.vendor, "f4ah6o");
  assert.deepEqual(EXCALIDRAW_EXTENSIONS, [".excalidraw", ".excalidraw.json"]);
  assert.deepEqual([...plugin.extensions], [...EXCALIDRAW_EXTENSIONS]);
  assert.ok(typeof plugin.description === "string" && plugin.description === EXCALIDRAW_DESCRIPTION);
  assert.ok(!EXCALIDRAW_EXTENSIONS.includes(".xdw"), "no extension collision with .xdw");
  assert.equal(typeof plugin.detect, "function");
  assert.ok(plugin.detect.constructor?.name !== "AsyncFunction", "detect must be synchronous");
  assert.equal(typeof plugin.convert, "function");
});

test("detect accepts exactly the Excalidraw document shapes", () => {
  assert.equal(plugin.detect(sceneBytes({ type: "excalidraw", elements: [] })), true);
  assert.equal(plugin.detect(sceneBytes({ type: "excalidraw", elements: [rectElement()] })), true);
  assert.equal(plugin.detect(sceneBytes({ elements: [] })), true);
  assert.equal(plugin.detect(sceneBytes({ elements: [{ type: "rectangle" }] })), true);
  assert.equal(plugin.detect(sceneBytes({ type: "excalidraw", elements: [5] })), true, "shape (a) only requires an array");

  assert.equal(plugin.detect(sceneBytes({ type: "excalidraw" })), false, "type without elements");
  assert.equal(plugin.detect(sceneBytes({ elements: 5 })), false, "elements must be an array");
  assert.equal(plugin.detect(sceneBytes({ elements: {} })), false);
  assert.equal(plugin.detect(sceneBytes([rectElement()])), false, "a top-level array is not a scene");
  assert.equal(plugin.detect(sceneBytes({ elements: [5] })), false, "elements[0] must be a plain object with a type");
  assert.equal(plugin.detect(sceneBytes({ appState: {} })), false);
  assert.equal(plugin.detect(encodeText("5")), false);
  assert.equal(plugin.detect(encodeText("not json")), false);
  assert.equal(plugin.detect(encodeText("")), false);
  assert.equal(plugin.detect(new Uint8Array(0)), false);
  assert.equal(plugin.detect(new Uint8Array([0x00, 0xff, 0x7f, 0x03, 0x60])), false, "binary garbage");
  assert.equal(plugin.detect(docuworksLikeHeader()), false, "DocuWorks bytes are foreign");
});

test("detect never throws and returns a synchronous boolean", () => {
  const hostiles = [
    new Uint8Array(0),
    new Uint8Array([0xff, 0xfe, 0xfd]),
    new Uint8Array(1024).fill(0x7b),
    encodeText("钱".repeat(1000)),
    encodeText('{"elements":[{"type":"rectangle"'),
  ];
  for (const bytes of hostiles) {
    const verdict = plugin.detect(bytes);
    assert.equal(typeof verdict, "boolean", "detect answers a boolean");
    assert.ok(verdict === false, `hostile input detected as true: ${verdict}`);
    assert.ok(!(verdict && typeof verdict.then === "function"));
  }
});

test("detect rejects oversized inputs without sniffing them", () => {
  const payload = '{"elements":[]}';
  const atLimit = encodeText(" ".repeat(INPUT_LIMIT - payload.length) + payload);
  assert.equal(atLimit.length, INPUT_LIMIT);
  assert.equal(plugin.detect(atLimit), true, "exactly at the limit is still sniffable");
  const over = encodeText(" ".repeat(INPUT_LIMIT - payload.length + 1) + payload);
  assert.equal(over.length, INPUT_LIMIT + 1);
  assert.equal(plugin.detect(over), false, "one byte over the limit is not sniffed");
});

///|
// options ----------------------------------------------------------------

test("convert accepts empty options and rejects everything else", async () => {
  const doc = { type: "excalidraw", elements: [] };
  await convertDoc(doc, {});
  await convertDoc(doc, NO_OPTIONS);
  await expectRejects(convertDoc(doc, { params: { include_hidden: "1" } }), "invalid-options", /unknown parameter/);
  await expectRejects(convertDoc(doc, { params: { anything: "" } }), "invalid-options", /unknown parameter/);
  await expectRejects(convertDoc(doc, { password: "hunter2" }), "invalid-options", /password/);
});

///|
// semantics ----------------------------------------------------------------

test("a rectangle renders with fill, stroke, margins and the documented shell", async () => {
  const { result, opened } = await openDoc({ type: "excalidraw", elements: [rectElement()] });
  // page size covers the geometry UNION PADDED by half the stroke on each
  // side (strokeWidth 2 -> +2 total), geometry itself anchors at 16 pt
  checkDocumentShell(opened, { width: 40 + 2 + 2 * MARGIN, height: 20 + 2 + 2 * MARGIN });
  assert.equal(opened.view.title, "Excalidraw diagram");
  assert.equal(result.summary, "1 page, 1 element(s)");
  assert.deepEqual(result.warnings, []);

  expectOp(opened, "strokeColor", [RED]);
  expectOp(opened, "line", [2, 0, 0, 10], "stroke width 2, butt cap, miter join");
  expectOp(opened, "fillColor", [GREEN]);
  expectOp(opened, "fillRect", [MARGIN + 1, MARGIN + 1, 40, 20]);
  expectOp(opened, "strokeRect", [MARGIN + 1, MARGIN + 1, 40, 20]);
  expectNoOp(opened, "alpha");
  expectNoOp(opened, "dash");
  expectNoOp(opened, "transform");
  expectNoOp(opened, "fillPath");
  expectNoOp(opened, "strokePath");
  expectNoOp(opened, "fillText");
  assert.ok(
    indexOfOp(opened, "fillRect", [MARGIN + 1, MARGIN + 1, 40, 20])
      < indexOfOp(opened, "strokeRect", [MARGIN + 1, MARGIN + 1, 40, 20]),
    "the fill is painted before the stroke",
  );
});

test("an ellipse renders as a filled and stroked path centered in its box", async () => {
  const { opened } = await openDoc({
    type: "excalidraw",
    elements: [rectElement({ type: "ellipse", x: 100, y: 50, width: 40, height: 20 })],
  });
  checkDocumentShell(opened, { width: 40 + 2 + 2 * MARGIN, height: 20 + 2 + 2 * MARGIN });
  expectOp(opened, "strokeColor", [RED]);
  expectOp(opened, "fillColor", [GREEN]);
  const fillOp = opsOf(opened).find(o => o.op === "fillPath");
  const strokeOp = opsOf(opened).find(o => o.op === "strokePath");
  assert.ok(fillOp && strokeOp, "an ellipse fills and strokes a path");
  expectNoOp(opened, "fillRect");
  expectNoOp(opened, "strokeRect");
  // center (120,60), radii (20,10); scene box x 100..140, y 50..70 ->
  // page offset (-84, -34) -> translated center (36, 26), radii unchanged.
  const args = pathArgsOf(opened, strokeOp.args[0]);
  approxArray(args.slice(0, 4), [37, 27, 20, 10], 1e-3, "the ellipse path carries center and radii");
  for (const value of args) {
    assert.ok(Number.isFinite(value), "ellipse path args are finite");
  }
});

test("a diamond renders the four inscribed side midpoints", async () => {
  const { opened } = await openDoc({
    type: "excalidraw",
    elements: [{ type: "diamond", x: 0, y: 0, width: 40, height: 20, strokeColor: "#ff0000", backgroundColor: "#00ff00", fillStyle: "solid", strokeStyle: "solid", strokeWidth: 2 }],
  });
  const fillOp = opsOf(opened).find(op => op.op === "fillPath");
  const strokeOp = opsOf(opened).find(op => op.op === "strokePath");
  assert.ok(fillOp && strokeOp, "a closed polygon fills and strokes a path");
  const args = pathArgsOf(opened, strokeOp.args[0]);
  approxArray(args,
    [38.236068, 17.118034, 58.236068, 27.118034, 38.236068, 37.118034, 18.236068, 27.118034],
    1e-3,
    "the diamond path walks top/right/bottom/left midpoints");
  approxArray(pathArgsOf(opened, fillOp.args[0]), args.slice(0, 8), 1e-3);
});

test("lines and arrows render polylines in absolute coordinates", async () => {
  const { opened } = await openDoc({
    type: "excalidraw",
    elements: [{
      type: "line",
      x: 10,
      y: 20,
      points: [[0, 0], [30, 10], [30, 40]],
      strokeColor: "#ff0000",
      strokeWidth: 2,
      strokeStyle: "solid",
    }],
  });
  const strokeOp = opsOf(opened).find(op => op.op === "strokePath");
  assert.ok(strokeOp, "an open chain strokes its path");
  expectNoOp(opened, "fillPath");
  expectNoOp(opened, "fillRect");
  // scene box x 10..40, y 20..60 -> offset (6, -4)
  approxArray(pathArgsOf(opened, strokeOp.args[0]),
    [17, 17, 47, 27, 47, 57], 1e-3,
    "points are made absolute with element x/y and translated to the margin");
});

test("an arrow adds a solid head on the final segment (documented formula)", async () => {
  const { opened } = await openDoc({
    type: "excalidraw",
    elements: [{
      type: "arrow",
      x: 0,
      y: 0,
      points: [[0, 0], [50, 0]],
      strokeColor: "#ff0000",
      strokeWidth: 2,
      strokeStyle: "solid",
    }],
  });
  const strokeOp = opsOf(opened).find(op => op.op === "strokePath");
  const fillOps = opsOf(opened).filter(op => op.op === "fillPath");
  assert.ok(strokeOp, "the shaft strokes");
  assert.equal(fillOps.length, 1, "exactly one filled head");
  // head: tip (50,0), length 10*strokeWidth = 20 back along the segment,
  // base half-width 10 -> corners (30,10) and (30,-10). Scene box
  // x 0..50, y -10..10 -> page offset (16, 26).
  approxArray(pathArgsOf(opened, fillOps[0].args[0]),
    [67, 26, 47, 16, 47, 36], 1e-3,
    "the head triangle is tip, then its two base corners");
  approxArray(pathArgsOf(opened, strokeOp.args[0]), [17, 26, 67, 26], 1e-3, "the shaft spans the two points");
});

test('arrowhead "none" suppresses the head; "triangle" warns once', async () => {
  const arrow = {
    type: "arrow",
    x: 0,
    y: 0,
    points: [[0, 0], [40, 0]],
    strokeColor: "#ff0000",
    strokeWidth: 2,
    strokeStyle: "solid",
  };
  const none = await openDoc({ type: "excalidraw", elements: [{ ...arrow, endArrowhead: "none" }] });
  expectNoOp(none.opened, "fillPath", "no head without an arrowhead");
  assert.deepEqual(none.result.warnings, []);

  // a "triangle" head is a supported shape: same length, WIDER base
  // (0.75 vs 0.5 of the head length), and no approximation warning
  const triangle = await openDoc({ type: "excalidraw", elements: [{ ...arrow, endArrowhead: "triangle" }] });
  const triangleHeads = opsOf(triangle.opened).filter(op => op.op === "fillPath");
  assert.equal(triangleHeads.length, 1);
  assert.deepEqual(triangle.result.warnings, [], " triangle heads render natively");
  const arrowHead = await openDoc({ type: "excalidraw", elements: [{ ...arrow, endArrowhead: "arrow" }] });
  const arrowHeadArgs = pathArgsOf(arrowHead.opened, opsOf(arrowHead.opened).find(op => op.op === "fillPath").args[0]);
  const triangleHeadArgs = pathArgsOf(triangle.opened, triangleHeads[0].args[0]);
  approx(Math.abs(arrowHeadArgs[3] - arrowHeadArgs[5]), 20, 1e-3, "arrow head base is 0.5 * length * 2 = 20");
  approx(Math.abs(triangleHeadArgs[3] - triangleHeadArgs[5]), 30, 1e-3, "triangle head base is 0.75 * length * 2 = 30");
});

test("text renders every line at the documented spacing", async () => {
  const { opened } = await openDoc({
    type: "excalidraw",
    elements: [{
      type: "text",
      id: "t",
      x: 12,
      y: 30,
      text: "ab\ncd\n\nef",
      fontSize: 20,
      fontFamily: 2,
      strokeColor: "#102030",
      fontWeight: 400,
    }],
  });
  const ops = opsOf(opened);
  const texts = ops.filter(op => op.op === "fillText");
  assert.equal(texts.length, 3, "empty lines emit no fillText op");
  const fontOps = ops.filter(op => op.op === "font");
  assert.equal(fontOps.length, texts.length, "one font op per text primitive");
  for (const font of fontOps) {
    assert.equal(font.args[1], 20, "font size carries through");
  }
  // scene box starts at the text anchor (12, 30) -> page offset (4, -14).
  // line i paints at (x, y + i * fontSize * 1.25).
  const expected = [
    ["ab", 16, 16],
    ["cd", 16, 16 + 25],
    ["ef", 16, 16 + 3 * 25],
  ];
  for (let i = 0; i < expected.length; i += 1) {
    assert.equal(texts[i].args[0], expected[i][0]);
    approx(texts[i].args[1], expected[i][1], 1e-6);
    approx(texts[i].args[2], expected[i][2], 1e-6);
  }
  expectOp(opened, "fillColor", [colorU32({ r: 0x10, g: 0x20, b: 0x30, a: 0xff })]);
  expectNoOp(opened, "strokeText");
  assert.ok(
    texts[0].args[3] === 0 || typeof texts[0].args[3] === "number",
    "the advance is recorded",
  );
});

test("fontFamily 3 maps to a monospace face; custom fonts warn once", async () => {
  const mono = await openDoc({
    type: "excalidraw",
    elements: [{ type: "text", id: "m", x: 0, y: 0, text: "m", fontSize: 16, fontFamily: 3, strokeColor: "#000000" }],
  });
  assert.deepEqual(mono.result.warnings, [], "monospace is in scope");
  assert.equal(opsOf(mono.opened).filter(op => op.op === "fillText").length, 1);

  const custom = await convertDoc({
    type: "excalidraw",
    elements: [
      { type: "text", id: "a", x: 0, y: 0, text: "a", fontSize: 16, fontFamily: 1, strokeColor: "#000000" },
      { type: "text", id: "b", x: 0, y: 40, text: "b", fontSize: 16, fontFamily: 4, strokeColor: "#000000" },
      { type: "text", id: "c", x: 0, y: 80, text: "c", fontSize: 16, strokeColor: "#000000" },
    ],
  });
  assert.equal(custom.warnings.length, 1, "Virgil, Excalifont and unstated fonts warn once together");
  assert.match(custom.warnings[0], /font/i);
});

test("opacity maps to alpha and rotation to a transform around the shape center", async () => {
  const angle = Math.PI / 2;
  const { opened } = await openDoc({
    type: "excalidraw",
    elements: [{ ...rectElement({ x: 10, y: 10, width: 40, height: 20 }), angle, opacity: 50 }],
  });
  const ops = opsOf(opened);

  //Rotated 90 degrees: cos ~ 0, sin = 1. The 40x20 rect at (10,10) rotated
  // around its center (30,20) occupies (20,0)-(40,40); the STROKE-INCLUSIVE
  // rotated box (19,-1)-(41,41) anchors at the margin, so the page offset is
  // (-3, 17) and the center sits at (27,37). The rotation group is
  // save, translate(27,37), transform(0,1,-1,0,0,0), translate(-27,-37),
  // alpha(0.5), styles, fillRect, strokeRect, restore.
  checkDocumentShell(opened, { width: 52 + 2, height: 72 + 2 });
  const saveIndex = ops.findIndex(op => op.op === "save");
  assert.ok(saveIndex >= 0, "a rotated shape opens with save");
  assert.equal(ops[saveIndex + 1].op, "translate", "the pivot moves to the center");
  approxArray(ops[saveIndex + 1].args, [27, 37], 1e-6, "center translate");
  const transformIndex = saveIndex + 2;
  assert.equal(ops[transformIndex].op, "transform", "the rotation is a transform op");
  approxArray(ops[transformIndex].args, [0, 1, -1, 0, 0, 0], 1e-9, "rotation matrix with no translation of its own");
  assert.equal(ops[transformIndex + 1].op, "translate", "the pivot moves back");
  approxArray(ops[transformIndex + 1].args, [-27, -37], 1e-6, "back-translate");
  const alphaIndex = transformIndex + 2;
  assert.equal(ops[alphaIndex].op, "alpha", "alpha follows the rotation");
  approx(ops[alphaIndex].args[0], 0.5, 1e-6);
  const restoreIndex = ops.findIndex((op, index) => index > transformIndex && op.op === "restore");
  assert.ok(restoreIndex > alphaIndex, "the rotation closes with restore");
  const fillIndex = indexOfOp(opened, "fillRect", [10 - 3, 10 + 17, 40, 20]);
  const strokeIndex = indexOfOp(opened, "strokeRect", [10 - 3, 10 + 17, 40, 20]);
  assert.ok(alphaIndex < fillIndex && fillIndex < strokeIndex && strokeIndex < restoreIndex,
    "the shape paints inside its rotation group, fill before stroke");
  // the group makes the matrix behave: transform * (point) maps the rect's
  // own coordinates onto the rotated placement the page was fitted to
  expectOp(opened, "fillColor", [GREEN]);
  expectOp(opened, "strokeColor", [RED]);
});

test("dash patterns scale by strokeWidth/2 exactly as documented", async () => {
  dashed: {
    const { opened } = await openDoc({
      type: "excalidraw",
      elements: [rectElement({ strokeStyle: "dashed", strokeWidth: 4 })],
    });
    const dash = opsOf(opened).find(op => op.op === "dash");
    assert.ok(dash, "dashed stroke emits dash");
    approxArray(dash.args[0], [16, 16], 1e-6, "dashed base [8,8] * (4/2)");
    approx(dash.args[1], 0, 1e-9);
  }
  dotted: {
    const { opened } = await openDoc({
      type: "excalidraw",
      elements: [rectElement({ strokeStyle: "dotted", strokeWidth: 4 })],
    });
    const dash = opsOf(opened).find(op => op.op === "dash");
    assert.ok(dash, "dotted stroke emits dash");
    approxArray(dash.args[0], [3, 9], 1e-6, "dotted base [1.5,4.5] * (4/2)");
  }
  solid: {
    const { opened } = await openDoc({ type: "excalidraw", elements: [rectElement({ strokeStyle: "solid" })] });
    expectNoOp(opened, "dash");
  }
  unit: {
    const { opened } = await openDoc({
      type: "excalidraw",
      elements: [rectElement({ strokeStyle: "dashed", strokeWidth: 2 })],
    });
    const dash = opsOf(opened).find(op => op.op === "dash");
    assert.ok(dash);
    approxArray(dash.args[0], [8, 8], 1e-6, "dashed base [8,8] * (2/2)");
  }
});

test("colors accept #RRGGBB, #RRGGBBAA and transparent; others fall back once", async () => {
  const alpha = await openDoc({
    type: "excalidraw",
    elements: [rectElement({ backgroundColor: "#00ff0080", strokeColor: "#123456" })],
  });
  expectOp(alpha.opened, "strokeColor", [colorU32({ r: 0x12, g: 0x34, b: 0x56, a: 0xff })]);
  expectOp(alpha.opened, "fillColor", [colorU32({ r: 0, g: 0xff, b: 0, a: 0x80 })]);

  const fallback = await openDoc({
    type: "excalidraw",
    elements: [
      rectElement({ id: "a", strokeColor: "rebeccapurple", y: 100 }),
      rectElement({ id: "b", strokeColor: "hsl(0 0% 0%)", y: 200 }),
      rectElement({ id: "c", strokeColor: "#fff", y: 300 }),
    ],
  });
  expectOp(fallback.opened, "strokeColor", [DEFAULT_COLOR]);
  assert.equal(fallback.result.warnings.length, 1, "one fallback warning");
  assert.match(fallback.result.warnings[0], /#1e1e1e/);

  const transparent = await openDoc({
    type: "excalidraw",
    elements: [rectElement({ strokeColor: "transparent", backgroundColor: "transparent" })],
  });
  const fillOps = opsOf(transparent.opened).filter(op => op.op === "fillRect");
  assert.equal(fillOps.length, 0, "a shape with nothing to paint renders nothing");
  assert.equal(transparent.result.summary, "1 page, 0 element(s)");
  assert.deepEqual(transparent.result.warnings, ["empty scene"]);
});

test("hatch fills drop the fill and warn once", async () => {
  const { result, opened } = await openDoc({
    type: "excalidraw",
    elements: [
      rectElement({ fillStyle: "hachure", id: "a" }),
      rectElement({ fillStyle: "cross-hatch", id: "b", y: 50 }),
      rectElement({ fillStyle: "zigzag-vector", id: "c", y: 100 }),
      rectElement({ fillStyle: "zigzag", id: "d", y: 150 }),
    ],
  });
  expectNoOp(opened, "fillColor");
  expectNoOp(opened, "fillRect");
  expectNoOp(opened, "fillPath");
  expectOp(opened, "strokeRect", [MARGIN + 1, MARGIN + 1, 40, 20]);
  assert.equal(result.warnings.length, 1, "one hatch warning regardless of the hatch flavor");
  assert.match(result.warnings[0], /hatch/);
});

test("roundness approximates corners with min(16, min(w,h)/4) and warns once", async () => {
  const rounded = await openDoc({
    type: "excalidraw",
    elements: [rectElement({ roundness: { type: 3 }, width: 120, height: 60 })],
  });
  assert.equal(rounded.result.warnings.length, 1);
  assert.match(rounded.result.warnings[0], /round/);
  // the rounded rect is emitted as a roundRect path verb: x,y,w,h and the
  // radius min(16, min(120,60)/4) = 15, at the page margin
  const strokeOp = opsOf(rounded.opened).find(op => op.op === "strokePath");
  const fillOp = opsOf(rounded.opened).find(op => op.op === "fillPath");
  assert.ok(strokeOp && fillOp, "a rounded rect fills and strokes a path");
  expectNoOp(rounded.opened, "fillRect");
  approxArray(pathArgsOf(rounded.opened, strokeOp.args[0]),
    [MARGIN + 1, MARGIN + 1, 120, 60, 15], 1e-3, "roundRect verb with computed radius");
  const capped = await convertDoc({
    type: "excalidraw",
    elements: [rectElement({ roundness: 5, width: 8, height: 8 }), rectElement({ roundness: 5, width: 8, height: 8, y: 40 })],
  });
  assert.equal(capped.warnings.length, 1, "rounding warns once");
  const flat = await openDoc({
    type: "excalidraw",
    elements: [rectElement({ roundness: null, width: 8, height: 8 })],
  });
  assert.deepEqual(flat.result.warnings, [], "roundness: null is not present");
  expectOp(flat.opened, "fillRect", [MARGIN + 1, MARGIN + 1, 8, 8], "roundness: null renders a plain rect");
});

test("deleted elements never render, silently", async () => {
  const { result, opened } = await openDoc({
    type: "excalidraw",
    elements: [
      rectElement({ id: "gone", isDeleted: true }),
      { type: "text", id: "kept", x: 0, y: 0, text: "kept", fontSize: 20, strokeColor: "#000000" },
    ],
  });
  assert.deepEqual(result.warnings, []);
  assert.equal(result.summary, "1 page, 1 element(s)");
  const texts = opsOf(opened).filter(op => op.op === "fillText");
  assert.equal(texts.length, 1);
  expectNoOp(opened, "fillRect");
  expectNoOp(opened, "strokeRect");
  const onlyDeleted = await openDoc({ type: "excalidraw", elements: [rectElement({ isDeleted: true })] });
  assert.deepEqual(onlyDeleted.result.warnings, ["empty scene"]);
  assert.equal(onlyDeleted.opened.page.w, 640);
  assert.equal(onlyDeleted.opened.page.h, 480);
});

test("unsupported kinds are excluded with exactly one warning each, in order", async () => {
  const { result, opened } = await openDoc({
    type: "excalidraw",
    elements: [
      { type: "image", id: "i1", x: 0, y: 0, width: 10, height: 10 },
      { type: "freedraw", id: "f1", x: 0, y: 0, points: [[0, 0]], width: 10, height: 10 },
      { type: "frame", id: "fr1", x: 0, y: 0, width: 10, height: 10, children: ["i1"] },
      { type: "mystery", id: "m", x: 0, y: 0 },
      { type: "image", id: "i2", x: 20, y: 0, width: 10, height: 10 },
      rectElement({ y: 200 }),
    ],
  });
  assert.equal(result.warnings.length, 4, "image, freedraw, frame, unknown type -- each once");
  for (const warning of result.warnings) {
    assert.equal(result.warnings.filter(w => w === warning).length, 1, `"${warning}" is deduplicated`);
  }
  assert.match(result.warnings[0], /image/);
  assert.match(result.warnings[1], /freedraw/);
  assert.match(result.warnings[2], /frame/);
  assert.match(result.warnings[3], /mystery/);
  assert.equal(opsOf(opened).filter(op => op.op === "fillRect").length, 1, "only the rectangle paints");
  assert.equal(result.summary, "1 page, 1 element(s)");
});

test("groups (parentId) do not change z order; members render in array order", async () => {
  const elements = [
    rectElement({ id: "a", parentId: "g1", strokeColor: "#010101", backgroundColor: "#010101", y: 0 }),
    rectElement({ id: "b", parentId: "g1", strokeColor: "#020202", backgroundColor: "#020202", y: 40 }),
    rectElement({ id: "c", parentId: "g2", strokeColor: "#030303", backgroundColor: "#030303", y: 80 }),
  ];
  const { opened } = await openDoc({ type: "excalidraw", elements });
  const colorSequence = contentOps(opsOf(opened))
    .filter(op => op.op === "strokeColor" || op.op === "fillColor")
    .map(op => op.args[0]);
  const colors = ["#010101", "#020202", "#030303"].map(hex => parseInt(hex.slice(1, 7), 16) * 0x100 + 0xff);
  const compressed = [];
  for (const paint of colorSequence) {
    if (compressed[compressed.length - 1] !== paint) compressed.push(paint);
  }
  assert.deepEqual(compressed, colors, "elements paint strictly in array order");
});

test("the summary counts painted elements only", async () => {
  const { result } = await openDoc({
    type: "excalidraw",
    elements: [
      rectElement({ id: "a", isDeleted: true }),
      { type: "frame", id: "f" },
      rectElement({ id: "b" }),
      rectElement({ id: "c", y: 60 }),
    ],
  });
  assert.equal(result.summary, "1 page, 2 element(s)");
});

///|
// page geometry ------------------------------------------------------------

///|
// review item 1: the cosmetic (stroke-inclusive) extent anchors at the
// margin, so thick strokes never leave the page ---------------------------

test("thick strokes stay fully on the page; ink anchors at the margin", async () => {
  const { opened } = await openDoc({ elements: [rectElement({ strokeWidth: 100 })] });
  // 40x20 rect, sw 100: cosmetic box (-50,50)-(90,70) -> page offset (66,66)
  checkDocumentShell(opened, { width: 40 + 100 + 2 * MARGIN, height: 20 + 100 + 2 * MARGIN });
  expectOp(opened, "strokeRect", [MARGIN + 50, MARGIN + 50, 40, 20],
    "a strokeWidth-100 rect decodes at the margin plus half its stroke");
  const strokeOp = expectOp(opened, "strokeRect", [MARGIN + 50, MARGIN + 50, 40, 20]);
  for (const value of strokeOp.args) {
    assert.ok(value >= MARGIN, `every decoded op coordinate stays on-page (${value})`);
  }
  approx(opened.object.bbox.x, MARGIN, 1e-2, "the ink bbox starts exactly at the margin");
  approx(opened.object.bbox.y, MARGIN, 1e-2, "the ink bbox starts exactly at the margin");
  approx(opened.object.bbox.x + opened.object.bbox.w, opened.page.w - MARGIN, 1e-2,
    "the ink bbox ends exactly at the other margin");
  approx(opened.object.bbox.y + opened.object.bbox.h, opened.page.h - MARGIN, 1e-2,
    "the ink bbox ends exactly at the other margin");

  // boundary: sw 32 (half the 16 pt margin) and one step past it
  const atBoundary = await openDoc({ elements: [rectElement({ strokeWidth: 32 })] });
  expectOp(atBoundary.opened, "strokeRect", [MARGIN + 16, MARGIN + 16, 40, 20],
    "sw 32: the fill sits at margin + 16, its stroke touches the page edge exactly at 16");
  approx(atBoundary.opened.object.bbox.x, MARGIN, 1e-2);
  const pastBoundary = await openDoc({ elements: [rectElement({ strokeWidth: 33 })] });
  expectOp(pastBoundary.opened, "strokeRect", [MARGIN + 16.5, MARGIN + 16.5, 40, 20],
    "sw 33 shifts by its own half stroke, its ink still starts at 16");
  approx(pastBoundary.opened.object.bbox.x, MARGIN, 1e-2);

  // strokeless content anchors its GEOMETRY exactly at the margin: the ink
  // IS the geometry, so the classic thin default case stays at (16,16)
  const fillOnly = await openDoc({
    elements: [{
      type: "rectangle", id: "f", x: 0, y: 0, width: 30, height: 30,
      strokeColor: "transparent", backgroundColor: "#00ff00", fillStyle: "solid",
    }],
  });
  expectOp(fillOnly.opened, "fillRect", [MARGIN, MARGIN, 30, 30],
    "a fill-only rect decodes exactly at the margin");
  approx(fillOnly.opened.object.bbox.x, MARGIN, 1e-2);
});

///|
// coordinator follow-up: non-integral ink spans (miter protrusions at a
// sharp vertex) must round the page size UP, never down, so no ink lands
// outside the page minus the margin band ---------------------------------

test("miter-protruded ink stays inside the margin band (page rounds up)", async () => {
  // duplicate-apex zig: the miter bound at the right-angle apex gives a
  // 7.071pt protrusion past the vertex -> the NON-INTEGRAL ink span rounds
  // the page UP; round() would have placed ink past the margin band.
  const { opened } = await openDoc({
    elements: [{
      type: "line", id: "zig", x: 0, y: 0,
      points: [[0, 0], [100, 100], [100, 100], [200, 0]],
      strokeWidth: 10, strokeColor: "#000000",
    }],
  });
  const bbox = opened.object.bbox;
  const page = opened.page;
  approx(bbox.x, MARGIN, 1e-2, "ink starts at the left margin");
  approx(bbox.y, MARGIN, 1e-2, "ink starts at the top margin");
  // ink span: geometry 0..100, miter protrusion 7.071 past the apex,
  // half stroke 5 below y=0 -> span 112.0710678 (NOT an integer)
  approx(bbox.y + bbox.h, MARGIN + 112.0710678, 1e-3,
    "the miter protrusion extends the decoded bbox past the integer span");
  assert.ok(Number.isInteger(page.w) && Number.isInteger(page.h),
    "page dimensions are integers");
  assert.ok(bbox.x >= MARGIN - 1e-6 && bbox.y >= MARGIN - 1e-6,
    "no ink before the margin");
  assert.ok(bbox.x + bbox.w <= page.w - MARGIN + 1e-3,
    `right ink ${bbox.x + bbox.w} stays inside page ${page.w} minus margin`);
  assert.ok(bbox.y + bbox.h <= page.h - MARGIN + 1e-3,
    `bottom ink ${bbox.y + bbox.h} stays inside page ${page.h} minus margin`);
  // the rounding rule itself: ceil(span + 2*margin), never round-down
  approx(page.h, Math.ceil(112.0710678 + 2 * MARGIN), 1e-6,
    "page height rounds the non-integral span UP");
  approx(page.w, Math.ceil(bbox.w + 2 * MARGIN), 1e-6,
    "page width rounds the non-integral span UP");
});

test("page geometry unions rendered extents plus a 16pt margin", async () => {
  const { opened } = await openDoc({
    type: "excalidraw",
    elements: [
      rectElement({ x: 10.5, y: 20, width: 30, height: 40 }),
      rectElement({ x: 200, y: -50, width: 10, height: 10 }),
    ],
  });
  // extent x 10.5..210, y -50..60 -> 231.5 -> 232 and 142 wide/tall pages
  checkDocumentShell(opened, { width: Math.round(199.5 + 2 + 2 * MARGIN), height: (60 - -50) + 2 + 2 * MARGIN });
  expectOp(opened, "strokeRect", [MARGIN + 1, 87, 30, 40], "the leftmost element anchors at the margin in x");
  expectOp(opened, "strokeRect", [206.5, MARGIN + 1, 10, 10], "the uppermost element anchors at the margin in y");
});

test("an empty scene keeps a default 640x480 page", async () => {
  const { result, opened } = await openDoc({ elements: [] });
  checkDocumentShell(opened, { width: 640, height: 480 });
  assert.deepEqual(result.warnings, ["empty scene"]);
  assert.equal(result.summary, "1 page, 0 element(s)");
  const typed = await openDoc({ type: "excalidraw", elements: [] });
  assert.deepEqual(typed.result.warnings, ["empty scene"]);
  assert.equal(typed.result.summary, "1 page, 0 element(s)");
});

///|
// malformed input and bounds ------------------------------------------------

test("malformed documents reject with invalid-input, never garbage", async () => {
  await expectRejects(plugin.convert(new Uint8Array(0), NO_OPTIONS), "invalid-input", /JSON/);
  await expectRejects(plugin.convert(encodeText("["), NO_OPTIONS), "invalid-input", /JSON/);
  await expectRejects(plugin.convert(new Uint8Array([0x7b, 0x22, 0xff, 0x7d]), NO_OPTIONS), "invalid-input", /UTF-8/);
  await expectRejects(plugin.convert(encodeText("5"), NO_OPTIONS), "invalid-input", /scene/);
  await expectRejects(plugin.convert(encodeText("[1,2]"), NO_OPTIONS), "invalid-input", /scene/);
  await expectRejects(plugin.convert(encodeText("{}"), NO_OPTIONS), "invalid-input", /scene/);
  await expectRejects(plugin.convert(encodeText('{"type":"excalidraw"}'), NO_OPTIONS), "invalid-input", /scene/);
  await expectRejects(plugin.convert(encodeText('{"type":"excalidraw","elements":5}'), NO_OPTIONS), "invalid-input", /scene/);
  await expectRejects(plugin.convert(encodeText('{"elements":[5]}'), NO_OPTIONS), "invalid-input", /element 0/);
  await expectRejects(plugin.convert(encodeText('{"elements":null}'), NO_OPTIONS), "invalid-input", /scene/);
  await expectRejects(plugin.convert(encodeText('{"type":"excalidraw","elements":[5]}'), NO_OPTIONS), "invalid-input", /element 0/);
  // an elements array PLUS a conflicting explicit type is never an Excalidraw
  // scene, detect does not claim it and convert names the conflict
  await expectRejects(plugin.convert(encodeText('{"type":"other","elements":[]}'), NO_OPTIONS), "invalid-input", /conflicts/);
  await expectRejects(plugin.convert(encodeText('{"type":"drawio","elements":[{"type":"rectangle"}]}'), NO_OPTIONS), "invalid-input", /conflicts/);
  await expectRejects(plugin.convert(encodeText('{"type":5,"elements":[]}'), NO_OPTIONS), "invalid-input", /conflicts/);
  await expectRejects(plugin.convert(null, NO_OPTIONS), "invalid-input", /byte/);
});

test("invalid numbers reject with invalid-input", async () => {
  const cases = [
    [{ ...rectElement(), x: "NaN" }, /x must be a finite number/],
    [{ type: "rectangle", id: "x", x: null, y: 0, width: 4, height: 4, strokeColor: "#000000" }, /x must be a finite number/],
    [{ ...rectElement(), width: "40" }, /width must be a finite number/],
    [{ ...rectElement(), strokeWidth: -1 }, /strokeWidth/],
    [{ ...rectElement(), strokeWidth: 0 }, /strokeWidth/],
    [{ ...rectElement(), opacity: -0.5 }, /opacity/],
    [{ ...rectElement(), angle: "30" }, /angle/],
    [{ type: "text", id: "t", x: 0, y: 0, fontSize: 0, text: "a", strokeColor: "#000000" }, /fontSize/],
    [{ type: "text", id: "t", x: 0, y: 0, fontSize: 20, text: 5, strokeColor: "#000000" }, /text must be a string/],
    [{ type: "line", id: "l", x: 0, y: 0, points: [[0, 0], ["3", 0]], strokeColor: "#000000" }, /point 1 must be a pair/],
    [{ type: "line", id: "l", x: 0, y: 0, points: 5, strokeColor: "#000000" }, /points must be/],
    [{ type: "line", id: "l", x: 0, y: 0, points: [[0, 0]], strokeColor: "#000000" }, /at least two points/],
    [{ type: "arrow", id: "l", x: 0, y: 0, points: [], strokeColor: "#000000" }, /at least two points/],
  ];
  for (const [element, pattern] of cases) {
    // JSON.stringify would drop NaN/Infinity to null, so send a typed
    // non-number (string/null) to hit the same validation, plus the real
    // NaN via a pre-serialized document.
    await expectRejects(convertDoc({ elements: [element, element] }), "invalid-input", pattern);
  }
  // NaN and Infinity cannot travel through JSON: as a literal they are a
  // JSON syntax error, and JSON.stringify would coerce them to null (which
  // the first two cases already cover through the strict parser).
  const nanDoc = '{"type":"excalidraw","elements":[{"type":"rectangle","id":"nan","x":NaN,"y":0,"width":4,"height":4,"strokeColor":"#000000"}]}';
  await expectRejects(plugin.convert(encodeText(nanDoc), NO_OPTIONS), "invalid-input", /JSON/);
  const infDoc = '{"type":"excalidraw","elements":[{"type":"rectangle","id":"inf","x":0,"y":Infinity,"width":4,"height":4,"strokeColor":"#000000"}]}';
  await expectRejects(plugin.convert(encodeText(infDoc), NO_OPTIONS), "invalid-input", /JSON/);
});

test("the documented limits accept the boundary value and reject one step past", async () => {
  // exactly 10000 elements
  const rect = { type: "rectangle", x: 0, y: 0, width: 4, height: 4, strokeColor: "#112233", backgroundColor: "#112233", fillStyle: "solid", strokeStyle: "solid", strokeWidth: 1 };
  const atLimit = await convertDoc({ elements: Array.from({ length: 10000 }, () => ({ ...rect })) });
  assert.match(atLimit.summary, /^1 page, 10000 element\(s\)$/);
  await expectRejects(convertDoc({ elements: Array.from({ length: 10001 }, () => ({ ...rect })) }), "too-large", /element/);

  // exactly 500 points on one line, then one more
  const points = Array.from({ length: 500 }, (_, i) => [i, i % 7]);
  const longLine = await convertDoc({
    elements: [{ type: "line", x: 0, y: 0, points, strokeColor: "#ff0000", strokeWidth: 1, strokeStyle: "solid" }],
  });
  assert.ok(longLine.bdf.length > 0);
  await expectRejects(convertDoc({
    elements: [{ type: "arrow", x: 0, y: 0, points: [...points, [500, 0]], strokeColor: "#ff0000", strokeWidth: 1 }],
  }), "too-large", /point/);

  // exactly the coordinate limit and one step past
  await openDoc({ elements: [rectElement({ x: 1e6, y: 1e6, width: 4, height: 4 })] });
  await expectRejects(convertDoc({ elements: [rectElement({ x: 1000000.5, y: 0 })] }), "too-large", /coordinate/);
  await expectResolves(convertDoc({
    elements: [{ type: "line", x: 1e6, y: 0, points: [[0, 0], [0, 0]], strokeColor: "#000000", strokeWidth: 1, strokeStyle: "solid" }],
  }), "absolute point exactly at the limit is accepted");
  await expectRejects(convertDoc({
    elements: [{ type: "line", x: 1e6, y: 0, points: [[0, 0], [10, 0]], strokeColor: "#000000" }],
  }), "too-large", /point 1/);

  // exactly the input limit (8 MiB), then one byte over
  const payload = '{"elements":[]}';
  const exact = encodeText(" ".repeat(INPUT_LIMIT - payload.length) + payload);
  assert.equal(exact.length, INPUT_LIMIT);
  const atInputLimit = await plugin.convert(exact, NO_OPTIONS);
  assert.equal(atInputLimit.warnings.length, 1);
  assert.equal(atInputLimit.warnings[0], "empty scene");
  await expectRejects(plugin.convert(new Uint8Array(INPUT_LIMIT + 1), NO_OPTIONS), "too-large", /bytes/);
});

test("opacity is the editor's single percent scale, 0..100 (review item 4)", async () => {
  // alpha = percent / 100, decoded from the real op stream. opacity:1 means
  // ONE PERCENT (alpha 0.01); only 100 (and a missing key) is fully opaque.
  for (const [percent, alpha] of [[0, 0], [0.5, 0.005], [1, 0.01], [50, 0.5], [99, 0.99]]) {
    const { opened } = await openDoc({ elements: [rectElement({ opacity: percent, y: 0 })] });
    const alphaOp = opsOf(opened).find(op => op.op === "alpha");
    assert.ok(alphaOp, `opacity ${percent} must emit an alpha op`);
    approx(alphaOp.args[0], alpha, 1e-6, `opacity ${percent} -> alpha ${alpha}`);
  }
  const at100 = await openDoc({ elements: [rectElement({ opacity: 100 })] });
  expectNoOp(at100.opened, "alpha", "percent 100 is fully opaque: no alpha op");
  const absent = await openDoc({ elements: [{ ...rectElement(), opacity: undefined }] });
  expectNoOp(absent.opened, "alpha", "a missing opacity defaults to 100");

  // above 100 clamps to 100 with exactly one warning; negative rejects
  const clamped = await openDoc({ elements: [rectElement({ opacity: 500, y: 100 })] });
  expectNoOp(clamped.opened, "alpha", "over-100 clamps to fully opaque");
  assert.deepEqual(clamped.result.warnings, ["opacity values above 100 are clamped to 100"]);
  await expectRejects(convertDoc({ elements: [rectElement({ opacity: -1 })] }), "invalid-input", /opacity/);
  await expectRejects(convertDoc({ elements: [rectElement({ opacity: "50" })] }), "invalid-input", /opacity/);
});

///|
// determinism ---------------------------------------------------------------

///|
// review item 5: arrowhead semantics on BOTH ends -------------------------

test("arrowheads resolve per end: absent, null, arrow, triangle, unsupported", async () => {
  const arrow = {
    type: "arrow",
    x: 0,
    y: 0,
    points: [[0, 0], [60, 0]],
    strokeColor: "#ff0000",
    strokeWidth: 2,
    strokeStyle: "solid",
  };
  const heads = async (over) => {
    const scene = await openDoc({ elements: [{ ...arrow, ...over }] });
    return {
      fills: opsOf(scene.opened).filter(op => op.op === "fillPath"),
      warnings: scene.result.warnings,
      opened: scene.opened,
    };
  };
  // END: the absent key draws the editor's default head; explicit null (and
  // the legacy "none") draws NOTHING
  const endAbsent = await heads({});
  assert.equal(endAbsent.fills.length, 1, "an absent endArrowhead draws the default head");
  assert.deepEqual(endAbsent.warnings, []);
  const endNull = await heads({ endArrowhead: null });
  assert.equal(endNull.fills.length, 0, "an explicit null endArrowhead draws no head");
  assert.deepEqual(endNull.warnings, [], "explicitly suppressed heads do not warn");
  const endNone = await heads({ endArrowhead: "none" });
  assert.equal(endNone.fills.length, 0, '"none" is the same as null');
  const endUnsupported = await heads({ endArrowhead: "spinny" });
  assert.equal(endUnsupported.fills.length, 1, "an unknown end arrowhead still draws a head");
  assert.deepEqual(endUnsupported.warnings,
    ['unsupported end arrowhead "spinny": rendered as an "arrow" head']);

  // START: absent and null draw nothing (the editor's default has no tail
  // head); known values draw; unknown values fall back warned, never vanish
  const startNull = await heads({ startArrowhead: null });
  assert.equal(startNull.fills.length, 1, "only the end head draws");
  const startArrow = await heads({ startArrowhead: "arrow" });
  assert.equal(startArrow.fills.length, 2, "a start head draws beside the end head");
  assert.deepEqual(startArrow.warnings, [], '"arrow" start heads are native');
  const startTriangle = await heads({ startArrowhead: "triangle" });
  assert.equal(startTriangle.fills.length, 2, '"triangle" start heads are native too');
  const startUnsupported = await heads({ startArrowhead: "wiggly" });
  assert.equal(startUnsupported.fills.length, 2, "an unknown start arrowhead still draws a head");
  assert.deepEqual(startUnsupported.warnings,
    ['unsupported start arrowhead "wiggly": rendered as an "arrow" head']);

  // geometry: heads attach tip-first -- the END head on the last point, the
  // START head on the first point (scene box x 0..60, y -10..10 -> +16, +26)
  const both = await heads({ startArrowhead: "arrow" });
  const firstHead = pathArgsOf(both.opened, both.fills[0].args[0]);
  const secondHead = pathArgsOf(both.opened, both.fills[1].args[0]);
  approxArray(firstHead.slice(0, 2), [77, 26], 1e-3, "the end head tip sits on the last point");
  approxArray(secondHead.slice(0, 2), [17, 26], 1e-3, "the start head tip sits on the first point");
});

///|
// review item 6: detection must not claim foreign JSON ---------------------

test("detection never claims a document that declares a foreign type", () => {
  assert.equal(plugin.detect(sceneBytes({ type: "other", elements: [] })), false, "foreign type, empty elements");
  assert.equal(plugin.detect(sceneBytes({ type: "drawio", elements: [rectElement()] })), false, "foreign type, live elements");
  assert.equal(plugin.detect(sceneBytes({ type: "mermaid", text: "flowchart TD\nA-->B" })), false);
  // the LOOSE FALLBACK: a bare elements array with NO type key at all stays
  // detectable (documented), and so does the real type tag
  assert.equal(plugin.detect(sceneBytes({ elements: [] })), true, "bare elements array (no type) is the loose fallback");
  assert.equal(plugin.detect(sceneBytes({ elements: [{ type: "line" }] })), true);
  assert.equal(plugin.detect(sceneBytes({ type: "excalidraw", elements: [] })), true);
});

///|
// review item 1: per-primitive state isolation -----------------------------

test("dashed stroke state cannot leak into a later solid shape", async () => {
  const { opened } = await openDoc({
    elements: [
      rectElement({ id: "dashed", strokeStyle: "dashed", y: 0 }),
      rectElement({ id: "solid", strokeStyle: "solid", y: 100 }),
    ],
  });
  const ops = opsOf(opened);
  assert.equal(ops.filter(op => op.op === "dash").length, 1, "exactly one dash record");
  const dashIndex = ops.findIndex(op => op.op === "dash");
  const solidSave = ops.findIndex((op, index) => index > dashIndex && op.op === "save");
  const solidRestore = ops.findIndex((op, index) => index > solidSave && op.op === "restore");
  assert.ok(solidSave > dashIndex && solidRestore > solidSave, "each primitive owns a save..restore block");
  assert.ok(
    ops.slice(solidSave, solidRestore + 1).every(op => op.op !== "dash"),
    "the solid group inherits no dash",
  );
});

///|
// review item 7: decomposed parts share one element pivot ------------------

test("a rotated arrow's head stays attached to the shaft tip", async () => {
  const angle = Math.PI / 3;
  const { opened } = await openDoc({
    elements: [{
      type: "arrow",
      id: "a",
      x: 10,
      y: 30,
      points: [[0, 0], [80, 10], [120, -20]],
      angle,
      strokeColor: "#123456",
      strokeWidth: 2,
      strokeStyle: "solid",
    }],
  });
  const ops = opsOf(opened);
  // every visible primitive is one save..restore block; a rotated block is
  // save, translate(px,py), transform, translate(-px,-py), ..., draws, restore
  const groups = [];
  for (let i = 0; i < ops.length; i += 1) {
    if (ops[i].op !== "save") continue;
    let end = -1;
    for (let j = i + 1; j < ops.length; j += 1) {
      if (ops[j].op === "restore") { end = j; break; }
    }
    groups.push(ops.slice(i, end + 1));
  }
  assert.equal(groups.length, 2, "shaft and head each draw once");
  const readGroup = (group, what) => {
    assert.equal(group[1].op, "translate", `${what} rotates about a pivot`);
    const [px, py] = group[1].args;
    const transform = group[2];
    assert.equal(transform.op, "transform", `${what} records the rotation matrix`);
    const [a, b, c, d] = transform.args;
    const mapped = ([x, y]) => [
      px + a * (x - px) + c * (y - py),
      py + b * (x - px) + d * (y - py),
    ];
    return { pivot: [px, py], mapped };
  };
  const shaftGroup = groups.find(group => group.some(op => op.op === "strokePath"));
  const headGroup = groups.find(group => group.some(op => op.op === "fillPath"));
  const shaft = readGroup(shaftGroup, "the shaft");
  const head = readGroup(headGroup, "the head");
  approx(shaft.pivot[0], head.pivot[0], 1e-9, "one shared pivot x");
  approx(shaft.pivot[1], head.pivot[1], 1e-9, "one shared pivot y");
  const shaftArgs = pathArgsOf(opened, shaftGroup.find(op => op.op === "strokePath").args[0]);
  const shaftTail = [shaftArgs[shaftArgs.length - 2], shaftArgs[shaftArgs.length - 1]];
  const headArgs = pathArgsOf(opened, headGroup.find(op => op.op === "fillPath").args[0]);
  const headTip = [headArgs[0], headArgs[1]];
  const mappedTail = shaft.mapped(shaftTail);
  const mappedTip = head.mapped(headTip);
  assert.ok(
    Math.abs(mappedTail[0] - mappedTip[0]) <= 1e-3 && Math.abs(mappedTail[1] - mappedTip[1]) <= 1e-3,
    `the head tip stays on the shaft end under rotation: (${mappedTail.join(",")}) vs (${mappedTip.join(",")})`,
  );
});

test("multi-line text rotates about one element-level pivot", async () => {
  const angle = -Math.PI / 4;
  const { opened } = await openDoc({
    elements: [{
      type: "text",
      id: "t",
      x: 30,
      y: 60,
      text: "one\ntwo\nthree",
      fontSize: 20,
      fontFamily: 2,
      strokeColor: "#001122",
      angle,
    }],
  });
  const ops = opsOf(opened);
  const pivots = [];
  for (let i = 0; i < ops.length; i += 1) {
    if (ops[i].op === "save" && ops[i + 1]?.op === "translate") {
      pivots.push(ops[i + 1].args);
    }
  }
  assert.equal(pivots.length, 3, "every line primitive rotates");
  for (const pivot of pivots.slice(1)) {
    approxArray(pivot, pivots[0], 1e-9, "all lines share the element pivot");
  }
  // the shared pivot is the WHOLE text box center -- x + maxAdvance/2 and
  // y + lineHeight*lines/2 -- translated by the same page offset the line
  // anchors carry; a per-line pivot would sit at x + lineAdvance/2 instead.
  const firstLine = ops.filter(op => op.op === "fillText")[0].args;
  const expectedPivot = [
    30 + 60 / 2 + (firstLine[1] - 30),
    60 + (3 * 20 * 1.25) / 2 + (firstLine[2] - 60),
  ];
  approxArray(pivots[0], expectedPivot, 1e-6, "the pivot is the element text-box center");
  const lines = ops.filter(op => op.op === "fillText");
  assert.equal(lines.length, 3);
});

///|
// review item 8: early caps, oversized input never emits -------------------

test("oversized but well-formed scenes reject early, never emit", async () => {
  // one giant string in a single element fails fast at the per-element cap
  await expectRejects(
    convertDoc({
      elements: [{ type: "text", id: "g", x: 0, y: 0, text: "a".repeat(100001), strokeColor: "#000000" }],
    }),
    "too-large", /100000/,
  );
  // a single line longer than the encoder's per-primitive string limit
  await expectRejects(
    convertDoc({
      elements: [{ type: "text", id: "l", x: 0, y: 0, text: "b".repeat(4097), strokeColor: "#000000" }],
    }),
    "too-large", /4096/,
  );
  // total generated characters across primitives over the encoder budget
  const words = { type: "text", id: "w", x: 0, y: 0, text: "x".repeat(2500), strokeColor: "#000000" };
  await expectRejects(
    convertDoc({ elements: Array.from({ length: 90 }, (_, i) => ({ ...words, y: i })) }),
    "too-large", /characters/,
  );
  // generated primitives: a 20000-line text element sits exactly at the cap
  const atLimit = await convertDoc({
    elements: [{ type: "text", id: "p", x: 0, y: 0, text: "x\n".repeat(20000), strokeColor: "#000000" }],
  });
  assert.ok(atLimit.bdf.length > 0, "20000 generated primitives still convert");
  await expectRejects(
    convertDoc({
      elements: [{ type: "text", id: "p", x: 0, y: 0, text: "x\n".repeat(20001), strokeColor: "#000000" }],
    }),
    "too-large", /primitives/,
  );
  // total points: 200 lines of 500 points is exactly the budget
  const line = (i) => ({
    type: "line",
    id: `l${i}`,
    x: i,
    y: 0,
    points: Array.from({ length: 500 }, (_, n) => [n, n % 7]),
    strokeColor: "#ff0000",
    strokeWidth: 1,
    strokeStyle: "solid",
  });
  const atPoints = await convertDoc({ elements: Array.from({ length: 200 }, (_, i) => line(i)) });
  assert.ok(atPoints.bdf.length > 0, "exactly 100000 points still convert");
  await expectRejects(
    convertDoc({ elements: Array.from({ length: 201 }, (_, i) => line(i)) }),
    "too-large", /points/,
  );
});

///|
// review item 10: real defaults, explicit unsupported-feature warnings -----

test("missing paints default correctly: background transparent, stroke #1e1e1e", async () => {
  const noBackground = await openDoc({
    elements: [{
      type: "rectangle", id: "r", x: 0, y: 0, width: 30, height: 30,
      strokeWidth: 2, strokeStyle: "solid", strokeColor: "#ff0000",
    }],
  });
  expectNoOp(noBackground.opened, "fillColor", "no background key means no fill, not a dark fill");
  expectNoOp(noBackground.opened, "fillRect");
  expectOp(noBackground.opened, "strokeRect", [MARGIN + 1, MARGIN + 1, 30, 30]);
  assert.deepEqual(noBackground.result.warnings, []);

  const noStroke = await openDoc({
    elements: [{
      type: "rectangle", id: "r", x: 0, y: 0, width: 30, height: 30,
      strokeStyle: "solid", backgroundColor: "#00ff00", fillStyle: "solid",
    }],
  });
  expectOp(noStroke.opened, "strokeColor", [DEFAULT_COLOR], "missing strokeColor falls back to the editor default");
  expectOp(noStroke.opened, "fillColor", [GREEN]);
  assert.deepEqual(noStroke.result.warnings, []);
});

test("unsupported features warn explicitly, once each, in order", async () => {
  const { result, opened } = await openDoc({
    type: "excalidraw",
    elements: [
      rectElement({ id: "r1", roundness: { type: 3 }, fillStyle: "hachure", y: 0 }),
      {
        type: "arrow", id: "a1", x: 0, y: 400,
        points: [[0, 0], [30, 0], [60, 10], [90, 0]],
        startArrowhead: "mystery", strokeColor: "#000000",
        strokeWidth: 2, strokeStyle: "solid",
      },
      { type: "text", id: "t1", x: 0, y: 500, text: "bound", fontSize: 20, strokeColor: "#000000", verticalAlign: "middle" },
      { ...rectElement({ id: "r2", y: 600 }), link: "https://example.com/a" },
      { ...rectElement({ id: "r3", y: 700 }), frameId: "frame-1" },
    ],
  });
  assert.deepEqual(result.warnings, [
    "hand-drawn hatch fills are out of scope, shapes render without fill",
    "rectangle corner rounding is approximated",
    "elbow and curved arrows are approximated with straight segments",
    'unsupported start arrowhead "mystery": rendered as an "arrow" head',
    "vertical alignment approximated",
    "element hyperlinks are not rendered",
    "frame clipping is not applied",
  ]);
  // nothing silently disappears: the elbow arrow still draws a shaft, the
  // fallback start head AND the default end head. The second strokePath is
  // the rounded rectangle r1 (a roundRect path verb, hatched so fill-less).
  assert.equal(opsOf(opened).filter(op => op.op === "fillPath").length, 2, "both heads draw");
  assert.equal(opsOf(opened).filter(op => op.op === "strokePath").length, 2,
    "the elbow chain and the rounded hatch rect both stroke");
});

///|
// review follow-up: the align anchor convention survives OVERFLOW -- a line
// wider than the element box still anchors at the box center / right edge,
// never at a hard left clamp ---------------------------------------------

test("overflowing lines keep the align anchors (center/right, plus a left control)", async () => {
  const fontSize = 20;
  const lines = "a\nmuch much longer line here"; // advances: 12 and 312 (26 chars)
  const width = 300; // the widest line overflows the box by 12 pt
  const overflowAdvance = 26 * 12; // 26 narrow codepoints * 0.6 em * 20pt = 312

  // CENTER: one glyph-center anchor at the BOX CENTER for every line; the
  // overflowing line sticks out SYMMETRICALLY on both sides
  {
    const { opened } = await openDoc({
      elements: [{
        type: "text", id: "c", x: 0, y: 0, text: lines, fontSize, width,
        textAlign: "center", strokeColor: "#000000",
      }],
    });
    assert.equal(opsOf(opened).find(op => op.op === "textStyle").args[0], 2, "align op stays center");
    const textOps = opsOf(opened).filter(op => op.op === "fillText");
    assert.equal(textOps.length, 2);
    approx(textOps[0].args[3], 12, 1e-3, "short line advance");
    approx(textOps[1].args[3], overflowAdvance, 1e-3, "overflowing line advance");
    // bands: "a" [144,156], overflow [-6,306] -> page offset 16-(-6) = 22,
    // so the shared decoded glyph center = 150 + 22 = 172 = box center + 22
    for (const line of textOps) {
      approx(line.args[1], 150 + (MARGIN + 6), 1e-3,
        "every line anchors at the decoded box center, overflowing or not");
    }
    approx(opened.object.bbox.x, MARGIN, 1e-2,
      "the symmetric overflow starts exactly at the margin, never beyond it");
    approx(opened.object.bbox.x + opened.object.bbox.w, MARGIN + 312, 1e-2,
      "and ends symmetrically at the margin's mirror");
    checkDocumentShell(opened, { width: 312 + 2 * MARGIN, height: 2 * 25 + 2 * MARGIN });
  }

  // RIGHT: one right-edge anchor at the BOX RIGHT EDGE for every line; the
  // overflowing line sticks out to the LEFT of the box
  {
    const { opened } = await openDoc({
      elements: [{
        type: "text", id: "r", x: 0, y: 0, text: lines, fontSize, width,
        textAlign: "right", strokeColor: "#000000",
      }],
    });
    assert.equal(opsOf(opened).find(op => op.op === "textStyle").args[0], 1, "align op stays right");
    const textOps = opsOf(opened).filter(op => op.op === "fillText");
    // bands: "a" [288,300], overflow [-12,300] -> page offset 28, so the
    // shared decoded right edge = 300 + 28 = 328 for BOTH lines
    for (const line of textOps) {
      approx(line.args[1], 300 + (MARGIN + 12), 1e-3,
        "every line anchors at the decoded box right edge");
    }
    approx(opened.object.bbox.x, MARGIN, 1e-2,
      "the left overflow starts exactly at the margin");
    approx(opened.object.bbox.x + opened.object.bbox.w, 300 + MARGIN + 12, 1e-2,
      "the ink ends at the box right edge");
    checkDocumentShell(opened, { width: 312 + 2 * MARGIN, height: 2 * 25 + 2 * MARGIN });
  }

  // LEFT control: the overflow simply runs to the RIGHT, past the box edge
  {
    const { opened } = await openDoc({
      elements: [{
        type: "text", id: "l", x: 0, y: 0, text: lines, fontSize, width,
        textAlign: "left", strokeColor: "#000000",
      }],
    });
    assert.equal(opsOf(opened).find(op => op.op === "textStyle").args[0], 0, "align op stays left");
    const textOps = opsOf(opened).filter(op => op.op === "fillText");
    for (const line of textOps) {
      approx(line.args[1], MARGIN, 1e-3, "every line anchors at the box start");
    }
    approx(opened.object.bbox.x, MARGIN, 1e-2);
    approx(opened.object.bbox.x + opened.object.bbox.w, MARGIN + 312, 1e-2,
      "the overflow to the right stays inside the page");
    checkDocumentShell(opened, { width: 312 + 2 * MARGIN, height: 2 * 25 + 2 * MARGIN });
  }
});

///|
// review item 2: textAlign is real for left/center/right, inside the
// element's own text box --------------------------------------------------

test("textAlign left/center/right place unequal lines inside the text box", async () => {
  const lines = "a\nmedium line\na very much longer line";
  const fontSize = 20;
  // narrow codepoints count 0.6 em; the widest line measures 23 * 0.6 * 20
  // so the measured box is 276 wide
  const box = 276;
  const advances = [12, 132, 276];
  // anchor convention per align op (left edge / glyph center / right edge):
  // every line of the element shares ONE decoded anchor:
  //   left   -> box start    decoded  = 16
  //   center -> box center   decoded  = 16 + 276/2 = 154
  //   right  -> box right edge decoded = 16 + 276    = 292
  const cases = [["left", 0, MARGIN], ["center", 2, MARGIN + box / 2], ["right", 1, MARGIN + box]];
  // page offset: the ink minimum is the widest line's band start at 10
  for (const [align, alignOp, anchor] of cases) {
    const { opened } = await openDoc({
      elements: [{
        type: "text", id: align, x: 10, y: 50, text: lines, fontSize,
        textAlign: align, strokeColor: "#000000",
      }],
    });
    const textOps = opsOf(opened).filter(op => op.op === "fillText");
    assert.equal(textOps.length, 3, `${align}: three non-empty lines`);
    for (let i = 0; i < 3; i += 1) {
      approx(textOps[i].args[1], anchor, 1e-3,
        `${align}: line ${i} decodes at the shared align anchor`);
      approx(textOps[i].args[3], advances[i], 1e-3, `${align}: line ${i} keeps its CJK-aware advance`);
    }
    const style = opsOf(opened).find(op => op.op === "textStyle");
    assert.ok(style, `${align}: a textStyle op exists`);
    assert.equal(style.args[0], alignOp, `${align} maps to the contract align value`);
    assert.equal(style.args[1], 1, "baseline stays top");
    // bands/bbox stay consistent: the ink spans exactly the box, at margin
    approx(opened.object.bbox.x, MARGIN, 1e-2, `${align}: ink starts at the margin`);
    approx(opened.object.bbox.w, box, 1e-2, `${align}: the ink spans the box`);
  }

  // bound/container text: the element's OWN width is the box, wider than
  // every line; right-aligned lines all end at the box's right edge
  const bound = await openDoc({
    elements: [{
      type: "text", id: "b", x: 0, y: 50, text: lines, fontSize, width: 400,
      textAlign: "right", strokeColor: "#000000",
    }],
  });
  const boundOps = opsOf(bound.opened).filter(op => op.op === "fillText");
  // the element box runs 0..400; under right-edge anchor semantics each
  // band is [anchor - advance, anchor] with the shared anchor at 400. The
  // widest line STARTS at 400 - 276 = 124, which becomes the ink minimum, so
  // the page offset 16 - 124 pushes the decoded anchor to 400 - 108 = 292
  // (the anchor IS the glyph right edge -- the band ends at it exactly)
  // every line decodes at the SAME right edge, and the widest band starts
  // at the margin
  for (const line of boundOps) {
    approx(line.args[1], 276 + MARGIN, 1e-3, "every right-aligned line anchors at the box right edge");
    approx(line.args[1], 276 + MARGIN, 1e-3,
      "and its glyphs end exactly there (the anchor IS the right edge)");
  }
  approx(Math.min(...boundOps.map(l => l.args[1] - l.args[3])), MARGIN, 1e-3,
    "the widest line's band starts exactly at the margin");
  checkDocumentShell(bound.opened, { width: 276 + 2 * MARGIN, height: 3 * 25 + 2 * MARGIN });

  // mixed CJK: centered wide and narrow lines share the element box
  const cjk = await openDoc({
    elements: [{
      type: "text", id: "jp", x: 0, y: 0, text: "こんにちは\nhi", fontSize,
      textAlign: "center", strokeColor: "#000000",
    }],
  });
  const cjkOps = opsOf(cjk.opened).filter(op => op.op === "fillText");
  assert.equal(cjkOps[0].args[0], "こんにちは");
  approx(cjkOps[0].args[3], 100, 1e-3);
  approx(cjkOps[1].args[3], 24, 1e-3);
  // the shared glyph-center anchor is the box center: 0 + 100/2, +16
  for (const line of cjkOps) {
    approx(line.args[1], MARGIN + 50, 1e-3, "both lines center on the box center");
  }

  // unknown alignment values warn once and render left
  const fallback = await openDoc({
    elements: [
      { type: "text", id: "a", x: 0, y: 0, text: "x", fontSize, textAlign: "justify", strokeColor: "#000000" },
      { type: "text", id: "b", x: 0, y: 60, text: "y", fontSize, textAlign: "weird", strokeColor: "#000000" },
    ],
  });
  assert.deepEqual(fallback.result.warnings.length, 2, "one warning per unknown value");
  assert.match(fallback.result.warnings[0], /justify/);
  const fallbackStyle = opsOf(fallback.opened).find(op => op.op === "textStyle");
  assert.equal(fallbackStyle.args[0], 0, "unknown alignments render left");
});

///|
// Japanese labels: Unicode strings survive with a CJK-aware advance --------

///|
// review item 3: negative rect geometry normalizes; zero-area paints nothing

test("negative rect width/height normalize to their corner box", async () => {
  const { opened } = await openDoc({
    elements: [{
      type: "rectangle", id: "r", x: 100, y: 100, width: -80, height: -50,
      strokeColor: "#ff0000", backgroundColor: "#00ff00", fillStyle: "solid",
      strokeStyle: "solid", strokeWidth: 10,
    }],
  });
  // normalized box (20,50)-(100,100); sw 10 -> cosmetic (15,45)-(105,105);
  // the ink anchors at the margin: offset (1,-29)
  const width = 105 - 15;
  const height = 105 - 45;
  checkDocumentShell(opened, { width: width + 2 * MARGIN, height: height + 2 * MARGIN });
  expectOp(opened, "strokeRect", [20 + 1, 50 - 29, 80, 50], "the corner box, normalized");
  expectOp(opened, "fillRect", [21, 21, 80, 50]);
  approx(opened.object.bbox.x, MARGIN, 1e-2);
  approx(opened.object.bbox.y, MARGIN, 1e-2);
  approx(opened.object.bbox.w, width, 1e-2, "the review's (15,45,90,60) pre-offset box");
  approx(opened.object.bbox.h, height, 1e-2);

  // zero-area geometry paints nothing and converts without error
  const flat = await openDoc({
    elements: [rectElement({ id: "flat", width: 0 }), rectElement({ id: "live", y: 100 })],
  });
  assert.equal(flat.result.summary, "1 page, 1 element(s)", "degenerate elements do not count");
  assert.equal(opsOf(flat.opened).filter(op => op.op === "fillRect").length, 1,
    "only the live rect paints");
  assert.deepEqual(flat.result.warnings, [], "degenerate geometry is not an error");
});

test("text advance is CJK-aware for Japanese labels", async () => {
  const { opened } = await openDoc({
    elements: [{ type: "text", id: "jp", x: 10, y: 10, text: "こんにちは", fontSize: 20, strokeColor: "#000000" }],
  });
  const textOp = opsOf(opened).find(op => op.op === "fillText");
  assert.equal(textOp.args[0], "こんにちは", "the Unicode string survives the round trip");
  approx(textOp.args[3], 5 * 20 * 1.0, 1e-3, "five wide codepoints count 1.0 em each");
  const mixed = await openDoc({
    elements: [{ type: "text", id: "mx", x: 0, y: 200, text: "Aあ1", fontSize: 20, strokeColor: "#000000" }],
  });
  approx(opsOf(mixed.opened).find(op => op.op === "fillText").args[3], (0.6 + 1.0 + 0.6) * 20, 1e-3,
    "narrow codepoints still count 0.6 em");
});

test("the same scene encodes to byte-identical BDF", async () => {
  const doc = {
    type: "excalidraw",
    elements: [
      rectElement(),
      { type: "ellipse", x: 20, y: 20, width: 10, height: 30, strokeColor: "#00ff0080", backgroundColor: "#112233", fillStyle: "hachure", strokeStyle: "dashed", strokeWidth: 3, opacity: 0.25, angle: Math.PI / 4 },
      { type: "arrow", x: 0, y: 0, points: [[0, 0], [5, 5], [40, 2]], strokeColor: "#123456", strokeWidth: 2, strokeStyle: "dotted", endArrowhead: "triangle" },
      { type: "text", x: 3, y: 90, text: "z\nz", fontSize: 24, fontFamily: 7, strokeColor: "#000000" },
    ],
  };
  const first = await convertDoc(doc);
  const second = await convertDoc(doc);
  assert.equal(first.bdf.length, second.bdf.length);
  for (let i = 0; i < first.bdf.length; i += 1) {
    assert.equal(first.bdf[i], second.bdf[i], `byte ${i}`);
  }
  assert.deepEqual(second.warnings, first.warnings);
  assert.deepEqual(second.summary, first.summary);

  // ids differ, rendered geometry must still be identical
  const renamed = JSON.parse(JSON.stringify(doc, (key, value) => (key === "id" ? `x${value}` : value)));
  const third = await convertDoc(renamed);
  for (let i = 0; i < first.bdf.length; i += 1) {
    assert.equal(third.bdf[i], first.bdf[i], `byte ${i} after rename`);
  }
});

///|
// registry integration ------------------------------------------------------

test("the registry detects by content, explicit format and extension", () => {
  const registry = createFormatRegistry({
    plugins: [
      excalidrawPlugin(),
      docuworksPlugin({
        delegate: { detect: bytes => bytes[0] === 0x60, convert: async () => ({ bdf: new Uint8Array(1), summary: "s" }) },
      }),
    ],
  });
  const bytes = sceneBytes({ type: "excalidraw", elements: [rectElement()] });

  const byContent = registry.detect(bytes, "scene.txt");
  assert.equal(byContent.plugin.name, "excalidraw");
  assert.equal(byContent.via, "detect");

  const byExtension = registry.detect(encodeText("not a scene"), "whiteboard.excalidraw");
  assert.equal(byExtension.plugin.name, "excalidraw");
  assert.equal(byExtension.via, "name");

  const byLongerExtension = registry.detect(encodeText("not a scene"), "whiteboard.excalidraw.json");
  assert.equal(byLongerExtension.plugin.name, "excalidraw");

  const byFormat = registry.detect(encodeText("anything"), "x.bin", "excalidraw");
  assert.equal(byFormat.plugin.name, "excalidraw");
  assert.equal(byFormat.via, "format-option");

  assert.equal(registry.detect(docuworksLikeHeader(), "a.xdw").plugin.name, "xdw", "the DocuWorks claims stay intact");
  assert.equal(registry.detect(docuworksLikeHeader(), "a.xdw").via, "detect");
  assert.throws(() => registry.detect(encodeText("mystery"), "mystery.zzz"), /no format matched/);
});

///|
// bounded property test -----------------------------------------------------

function uniqueColor(index) {
  return `#${((index + 1) * 0x111111).toString(16).padStart(6, "0")}`;
}

function uniqueColorU32(index) {
  return colorU32({
    r: (index + 1) * 0x11,
    g: (index + 1) * 0x11,
    b: (index + 1) * 0x11,
    a: 255,
  });
}

///|
// A synthetic scene with known paint expectations: every painted element
// gets a unique color so the recorded color-op sequence pins z order exactly.
function generateScene(rng) {
  const doc = { type: "excalidraw", elements: [] };
  const info = { expectedColors: [], expectedLines: [], painted: 0 };
  const kinds = ["rectangle", "ellipse", "diamond", "line", "arrow", "text"];
  const noise = ["frame", "image", "freedraw"];
  const count = rng.integer(9); // 0..8 paintable elements
  let noiseAdded = false;
  for (let index = 0; index < count; index += 1) {
    const kind = rng.pick(kinds);
    const color = uniqueColor(index);
    const element = {
      id: `e${index}`,
      type: kind,
      x: rng.integer(460) - 30,
      y: rng.integer(340) - 30,
      strokeWidth: rng.pick([1, 2, 3, 4]),
      strokeStyle: rng.pick(["solid", "dashed", "dotted"]),
      strokeColor: color,
      backgroundColor: color,
      fillStyle: rng.pick(["solid", "solid", "hachure"]),
      opacity: rng.pick([1, 0.5, 0.25]),
      angle: rng.pick([0, Math.PI / 4, Math.PI / 2, -Math.PI / 3]),
    };
    if (kind === "rectangle" || kind === "ellipse" || kind === "diamond") {
      element.width = rng.integer(60) + 6;
      element.height = rng.integer(60) + 6;
      doc.elements.push(element);
      // strokeColor then fillColor for a solid fill, strokeColor only for a hatch
      info.expectedColors.push(uniqueColorU32(index));
      if (element.fillStyle === "solid") info.expectedColors.push(uniqueColorU32(index));
      info.painted += 1;
    } else if (kind === "line" || kind === "arrow") {
      if (rng.next() < 0.8) {
        delete element.fillStyle;
        delete element.backgroundColor;
        const points = [[0, 0]];
        for (let p = rng.integer(5) + 1; p > 0; p -= 1) { // >= 2 points
          points.push([rng.integer(200), -rng.integer(80)]);
        }
        element.points = points;
        doc.elements.push(element);
        info.expectedColors.push(uniqueColorU32(index)); // the stroked chain
        if (kind === "arrow") info.expectedColors.push(uniqueColorU32(index)); // the filled head
        info.painted += 1;
      } else {
        element.isDeleted = true; // deleted content never renders
        element.points = [[0, 0], [1, 1]];
        doc.elements.push(element);
      }
    } else {
      // single-line text: color rides fillColor exactly once
      const line = rng.pick(["alpha", "beta", "gamma", "d1"]);
      element.text = line;
      element.fontSize = rng.pick([12, 20, 28]);
      element.fontFamily = rng.pick([2, 3]);
      delete element.width;
      delete element.fillStyle;
      delete element.backgroundColor;
      doc.elements.push(element);
      info.expectedColors.push(uniqueColorU32(index));
      info.expectedLines.push(line);
      info.painted += 1;
    }
    if (!noiseAdded && rng.next() < 0.35) {
      noiseAdded = true;
      doc.elements.push({ id: `n${index}`, type: rng.pick(noise), x: 0, y: 0, width: 8, height: 8 });
    }
  }
  if (count === 0 && rng.next() < 0.3) {
    doc.elements.push({ id: "f", type: "frame", x: 0, y: 0, width: 4, height: 4 });
  }
  return { doc, info };
}

test("bounded property test: synthetic scenes satisfy the semantic invariants", { timeout: 300000 }, async () => {
  const cases = 150;
  for (let i = 0; i < cases; i += 1) {
    const rng = mulberry32((0x9e3779b9 * (i + 1)) >>> 0);
    const { doc, info } = generateScene(rng);
    try {
      await verifyPbtCase(doc, info);
    } catch (error) {
      error.message = `pbt case ${i}: ${error.message}`;
      throw error;
    }
  }
});

async function verifyPbtCase(doc, info) {
  const first = await convertDoc(doc);
  if (first.warnings.length > 0) {
    const counts = new Map();
    for (const warning of first.warnings) {
      counts.set(warning, (counts.get(warning) ?? 0) + 1);
    }
    for (const [warning, seen] of counts) {
      assert.equal(seen, 1, `warning "${warning}" must be deduplicated`);
    }
  }
  const opened = await openDiagram(first.bdf);

  // shell invariants
  checkDocumentShell(opened, { width: opened.page.w, height: opened.page.h });
  assert.ok(Number.isInteger(opened.page.w) && opened.page.w > 0 && opened.page.w <= PAGE_LIMIT);
  assert.ok(Number.isInteger(opened.page.h) && opened.page.h > 0 && opened.page.h <= PAGE_LIMIT);
  assert.equal(first.summary, `1 page, ${info.painted} element(s)`);

  // determinism: byte-identical second run, warning-identical too
  const second = await convertDoc(doc);
  assert.equal(second.bdf.length, first.bdf.length, "re-encode length");
  for (let b = 0; b < first.bdf.length; b += 1) {
    if (second.bdf[b] !== first.bdf[b]) assert.fail(`byte ${b} differs on re-encode`);
  }
  assert.deepEqual(second.warnings, first.warnings);
  assert.deepEqual(second.summary, first.summary);

  // z order / draw order: the recorded color ops follow the element order
  const paints = contentOps(opened.ops)
    .map(op => (op.op === "strokeColor" || op.op === "fillColor" ? op.args[0] : null))
    .filter(value => value !== null);
  assert.deepEqual(paints, info.expectedColors);

  // text content
  const texts = opened.ops.filter(op => op.op === "fillText").map(op => op.args[0]);
  assert.deepEqual(texts, info.expectedLines);

  // every recorded numeric value is sane
  for (const op of contentOps(opened.ops)) {
    const numeric = [];
    if (op.op === "fillRect" || op.op === "strokeRect") numeric.push(...op.args);
    if (op.op === "fillText" || op.op === "strokeText") numeric.push(op.args[1], op.args[2]);
    if (op.op === "alpha") numeric.push(op.args[0]);
    if (op.op === "line") numeric.push(op.args[0]);
    if (op.op === "dash") numeric.push(...op.args[0], op.args[1]);
    for (const value of numeric) {
      assert.ok(Number.isFinite(value), `${op.op} args contain NaN/Infinity`);
      assert.ok(Math.abs(value) <= 1e6 + 1e-9, `${op.op} value ${value} exceeds the encoder range`);
    }
    if (op.op === "dash") {
      for (const segment of op.args[0]) {
        assert.ok(segment > 0, "dash segments are positive");
      }
    }
    if (op.op === "fillRect" || op.op === "strokeRect") {
      assert.ok(op.args[2] > 0 && op.args[3] > 0, "rect width/height are positive");
    }
  }
  // ink containment: the decoded object bbox -- stroke padding and miter
  // protrusions included -- must sit inside the margin band of the page
  if (info.painted > 0) {
    const bbox = opened.object.bbox;
    assert.ok(bbox.x > MARGIN - 0.6, `ink bbox starts on-page (x=${bbox.x})`);
    assert.ok(bbox.y > MARGIN - 0.6, `ink bbox starts on-page (y=${bbox.y})`);
    assert.ok(opened.page.w - (bbox.x + bbox.w) > MARGIN - 0.8,
      `ink ends inside the right margin (page ${opened.page.w}, ink ${bbox.x + bbox.w})`);
    assert.ok(opened.page.h - (bbox.y + bbox.h) > MARGIN - 0.8,
      `ink ends inside the bottom margin (page ${opened.page.h}, ink ${bbox.y + bbox.h})`);
  }

  // every group is closed: restores match saves
  const saves = opened.ops.filter(op => op.op === "save").length;
  const restores = opened.ops.filter(op => op.op === "restore").length;
  assert.equal(saves, restores, "save/restore are balanced");
  // every rotation group carries a pure rotation matrix between translates
  for (let index = 0; index < opened.ops.length; index += 1) {
    const op = opened.ops[index];
    if (op.op === "transform") {
      assert.equal(op.args.length, 6);
      const [a, b, c, d, e, f] = op.args;
      approx(a * a + b * b, 1, 1e-6, "row 1 of the rotation matrix is a unit vector");
      approx(c * c + d * d, 1, 1e-6, "row 2 of the rotation matrix is a unit vector");
      approx(e, 0, 1e-9, "the transform itself carries no translation");
      approx(f, 0, 1e-9, "the transform itself carries no translation");
      assert.equal(opened.ops[index - 1].op, "translate");
      assert.equal(opened.ops[index + 1].op, "translate");
      approx(opened.ops[index - 1].args[0], -opened.ops[index + 1].args[0], 1e-6, "the pivot moves out and back");
      approx(opened.ops[index - 1].args[1], -opened.ops[index + 1].args[1], 1e-6, "the pivot moves out and back");
    }
  }
}

test("regression: scenes that warn still warn deterministically", async () => {
  const doc = {
    elements: [
      { id: "1", type: "text", x: 0, y: 0, text: "x", fontSize: 20, fontFamily: 4, strokeColor: "#000000" },
      { id: "2", type: "text", x: 0, y: 30, text: "y", fontSize: 20, fontFamily: 1, strokeColor: "#000000" },
      { id: "3", type: "freedraw", x: 0, y: 0 },
    ],
  };
  const one = await convertDoc(doc);
  const two = await convertDoc(doc);
  assert.deepEqual(one.warnings, two.warnings);
  assert.equal(one.warnings.length, 2, "custom fonts warn once, freedraw warns once");
  assert.match(one.warnings[0], /font/i);
  assert.match(one.warnings[1], /freedraw/i);
});
