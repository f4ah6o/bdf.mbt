// Shared-module tests owned by the coordinator: the diagram-to-BDF encoder
// (plugin/src/diagram-bdf.js) and the independent reader helper
// (plugin/test/diagram-reader.mjs). Verification goes through @bdfkit/core
// (the project's own BDF reader, staged read-only), never through a
// re-implementation of the encoding. The regressions here mirror the
// independent review findings: dash state isolation, float32 overflow
// rejection, real text bounds, rotation pivots, strokeWidth padding,
// aggregate caps and no input mutation.

import assert from "node:assert/strict";
import { test } from "node:test";
import { createHash } from "node:crypto";

import { encodeDiagram } from "../src/diagram-bdf.js";
import { openDiagram } from "./diagram-reader.mjs";
import { mulberry32 } from "./helpers.mjs";

const BLACK = { r: 0, g: 0, b: 0, a: 255 };

function opsOf(ops, name) {
  return ops.filter(op => op.op === name);
}

function isBetween(ops, before, within, after) {
  const names = ops.map(op => op.op);
  const beforeAt = names.indexOf(before);
  const withinAt = names.indexOf(within);
  const afterAt = names.indexOf(after);
  assert.ok(beforeAt >= 0 && withinAt >= 0 && afterAt >= 0, names.join(","));
  assert.ok(beforeAt < withinAt && withinAt < afterAt, names.join(","));
}

test("encodeDiagram emits a genuine single-file BDF the core reader opens", async () => {
  const bytes = await encodeDiagram({
    width: 300, height: 200, source: "smoke", title: "t",
    primitives: [
      { kind: "rect", x: 10, y: 10, w: 40, h: 20, fill: { r: 1, g: 2, b: 3, a: 255 }, stroke: BLACK },
      { kind: "text", x: 10, y: 50, text: "hello", fontSize: 20 },
    ],
  });
  assert.equal(bytes[0], 0x62);
  const opened = await openDiagram(bytes);
  assert.equal(opened.header.version, 1);
  assert.equal(opened.header.flags, 0);
  assert.equal(opened.header.manifestEnc, "identity");
  assert.equal(opened.manifest.bdf, 1);
  assert.equal(opened.manifest.opset, 1);
  assert.equal(opened.manifest.unit, "pt");
  assert.equal(opened.view.kind, "fixed");
  assert.equal(opened.view.id, "page-0");
  assert.equal(opened.page.w, 300);
  assert.equal(opened.page.h, 200);
  assert.deepEqual(opened.page.layers, [{ role: "content", obj: opened.page.layers[0].obj }]);
  const entry = opened.parts[0];
  assert.equal(entry.t, "obj");
  assert.equal(entry.enc, "identity");
  assert.equal(entry.off, 0);
  assert.match(entry.h, /^[0-9a-f]{32}$/);
  // the part name is the real SHA-256 prefix of the stored part bytes
  const stored = bytes.subarray(opened.header.manifestOff + opened.header.manifestLen);
  assert.equal(createHash("sha256").update(stored).digest("hex").slice(0, 32), entry.h);
  assert.equal(entry.len, stored.length);
  // object tables decode with the right resources
  assert.deepEqual(opened.object.strings, ["hello"]);
  assert.equal(opened.object.fonts.length, 1);
  assert.equal(opened.object.paints.length, 0);
  assert.equal(opened.object.images.length, 0);
  assert.equal(opened.object.objects.length, 0);
  const rect = opsOf(opened.ops, "fillRect")[0];
  assert.deepEqual(rect.args, [10, 10, 40, 20]);
});

test("rect with fill and stroke emits color, line, fill and stroke rect in z order", async () => {
  const opened = await openDiagram(await encodeDiagram({
    width: 100, height: 100, source: "smoke", title: "",
    primitives: [{ kind: "rect", x: 5, y: 6, w: 30, h: 15, fill: { r: 9, g: 8, b: 7, a: 6 }, stroke: { r: 1, g: 3, b: 5, a: 255 }, strokeWidth: 4 }],
  }));
  assert.equal(opsOf(opened.ops, "fillRect")[0].args[0], 5);
  const line = opsOf(opened.ops, "line")[0];
  assert.equal(line.args[0], 4); // width
  assert.equal(line.args[1], 0); // butt cap
  assert.equal(line.args[2], 0); // miter join
  const fillColor = opsOf(opened.ops, "fillColor")[0];
  assert.equal(fillColor.args[0], (9 << 24 | 8 << 16 | 7 << 8 | 6) >>> 0);
  const strokeColor = opsOf(opened.ops, "strokeColor")[0];
  assert.equal(strokeColor.args[0], (1 << 24 | 3 << 16 | 5 << 8 | 255) >>> 0);
  // the whole primitive is one save/restore-isolated block
  assert.equal(opsOf(opened.ops, "save").length, 1);
  assert.equal(opsOf(opened.ops, "restore").length, 1);
  isBetween(opened.ops, "save", "fillRect", "restore");
  isBetween(opened.ops, "save", "strokeRect", "restore");
});

test("dash state is isolated: a dashed shape cannot dash the next solid one", async () => {
  const opened = await openDiagram(await encodeDiagram({
    width: 200, height: 100, source: "smoke", title: "",
    primitives: [
      { kind: "rect", x: 0, y: 0, w: 20, h: 20, stroke: BLACK, dash: [3, 3] },
      { kind: "rect", x: 40, y: 0, w: 20, h: 20, stroke: BLACK },
    ],
  }));
  const names = opened.ops.map(op => op.op);
  assert.equal(names.filter(name => name === "dash").length, 1, names.join(","));
  assert.equal(names.filter(name => name === "save").length, 2);
  assert.equal(names.filter(name => name === "restore").length, 2);
  // the dash is inside the first primitive's block; the second primitive's
  // block has no dash op at all, so a replaying renderer draws it solid.
  const firstRestore = names.indexOf("restore");
  assert.ok(names.indexOf("dash") < firstRestore, "dash must be inside the first block");
  const secondBlock = names.slice(firstRestore + 1);
  assert.ok(!secondBlock.includes("dash"), secondBlock.join(","));
  assert.ok(secondBlock.includes("strokeRect"));
});

test("rounded rect becomes a roundRect path; ellipse an ellipse verb path", async () => {
  const opened = await openDiagram(await encodeDiagram({
    width: 200, height: 200, source: "smoke", title: "",
    primitives: [
      { kind: "rect", x: 10, y: 10, w: 50, h: 40, rounded: 8, stroke: BLACK },
      { kind: "ellipse", cx: 100, cy: 30, rx: 20, ry: 15, stroke: BLACK },
    ],
  }));
  assert.equal(opened.paths.length, 2);
  assert.deepEqual([...opened.paths[0].verbs], [8]);
  assert.deepEqual([...opened.paths[0].args], [10, 10, 50, 40, 8]);
  assert.deepEqual([...opened.paths[1].verbs], [6]);
  const ellipseArgs = [...opened.paths[1].args];
  assert.deepEqual(ellipseArgs.slice(0, 5), [100, 30, 20, 15, 0]);
  assert.ok(Math.abs(ellipseArgs[6] - Math.PI * 2) < 1e-6, ellipseArgs[6]);
  assert.equal(ellipseArgs[7], 0);
});

test("polygon closes, polyline stays open, and both live in the path table", async () => {
  const opened = await openDiagram(await encodeDiagram({
    width: 300, height: 300, source: "smoke", title: "",
    primitives: [
      { kind: "polygon", points: [[0, 0], [10, 0], [10, 10], [0, 10]], fill: BLACK },
      { kind: "polyline", points: [[20, 0], [30, 5], [40, 0]], stroke: BLACK },
    ],
  }));
  assert.equal(opened.paths.length, 2);
  assert.deepEqual([...opened.paths[0].verbs], [0, 1, 1, 1, 4]);
  assert.deepEqual([...opened.paths[0].args], [0, 0, 10, 0, 10, 10, 0, 10]);
  assert.deepEqual([...opened.paths[1].verbs], [0, 1, 1]);
  assert.deepEqual([...opened.paths[1].args], [20, 0, 30, 5, 40, 0]);
  // fill on a polyline is ignored by contract
  assert.equal(opsOf(opened.ops, "fillPath").length, 1);
  assert.notEqual(opsOf(opened.ops, "strokePath").length, 0);
});

test("text gets a system font, resolved style and the advance used for its bounds", async () => {
  const opened = await openDiagram(await encodeDiagram({
    width: 400, height: 100, source: "smoke", title: "",
    primitives: [{ kind: "text", x: 200, y: 50, text: "abc", fontSize: 10, align: "center", baseline: "middle", family: "Helvetica", weight: 700, style: "italic" }],
  }));
  const font = opened.object.fonts[0];
  assert.equal(font.kind, 1);
  assert.equal(font.family, "Helvetica");
  assert.equal(font.weight, 700);
  assert.equal(font.style, 1); // italic
  const fontOp = opsOf(opened.ops, "font")[0];
  assert.deepEqual(fontOp.args, [0, 10]);
  const textStyle = opsOf(opened.ops, "textStyle")[0];
  assert.deepEqual(textStyle.args, [2, 2, 1, 0]); // center, middle, ltr, spacing 0
  const text = opsOf(opened.ops, "fillText")[0];
  assert.equal(text.args[0], "abc");
  assert.equal(text.args[1], 200);
  assert.equal(text.args[2], 50);
  assert.ok(Math.abs(text.args[3] - 18) < 1e-4, text.args[3]); // 10 * 0.6 * 3
  // an explicit advance override reaches the recorded op
  const override = await openDiagram(await encodeDiagram({
    width: 400, height: 100, source: "smoke", title: "",
    primitives: [{ kind: "text", x: 10, y: 10, text: "日本語", fontSize: 10, advance: 30 }],
  }));
  const overridden = opsOf(override.ops, "fillText")[0];
  assert.ok(Math.abs(overridden.args[3] - 30) < 1e-6, overridden.args[3]);
});

test("text bounds cover the advance width and line height for every alignment", async () => {
  const text = "This is a long line"; // 18 codepoints
  const fontSize = 20;
  const advance = fontSize * 0.6 * text.length; // 216
  for (const align of ["left", "center", "right"]) {
    const opened = await openDiagram(await encodeDiagram({
      width: 500, height: 200, source: "smoke", title: "",
      primitives: [{ kind: "text", x: 10, y: 10, text, fontSize, align, baseline: "top" }],
    }));
    // top baseline: the band runs from (10, 10) to (10+advance, 10+1.2*size)
    assert.ok(Math.abs(opened.object.bbox.h - fontSize * 1.2) < 1e-3, `${align}: ${JSON.stringify(opened.object.bbox)}`);
    if (align === "left") {
      assert.ok(Math.abs(opened.object.bbox.x - 10) < 1e-3 && Math.abs(opened.object.bbox.y - 10) < 1e-3, `${align}: ${JSON.stringify(opened.object.bbox)}`);
      assert.ok(Math.abs(opened.object.bbox.w - advance) < 1e-3, `${align}: ${JSON.stringify(opened.object.bbox)}`);
    } else if (align === "center") {
      assert.ok(Math.abs(opened.object.bbox.x - (10 - advance / 2)) < 1e-3, `${align}: ${JSON.stringify(opened.object.bbox)}`);
    } else {
      assert.ok(Math.abs(opened.object.bbox.x - (10 - advance)) < 1e-3, `${align}: ${JSON.stringify(opened.object.bbox)}`);
    }
  }
  // middle baseline band straddles the anchor
  const middle = await openDiagram(await encodeDiagram({
    width: 500, height: 200, source: "smoke", title: "",
    primitives: [{ kind: "text", x: 100, y: 100, text: "mid", fontSize: 20, baseline: "middle" }],
  }));
  assert.ok(middle.object.bbox.y < 100 && middle.object.bbox.y + middle.object.bbox.h > 100,
    JSON.stringify(middle.object.bbox));
});

test("stroke width pads the bounding box so thick strokes are not culled", async () => {
  const opened = await openDiagram(await encodeDiagram({
    width: 200, height: 100, source: "smoke", title: "",
    primitives: [{ kind: "polyline", points: [[50, 50], [100, 50]], stroke: BLACK, strokeWidth: 10 }],
  }));
  assert.ok(Math.abs(opened.object.bbox.y - 45) < 1e-3, JSON.stringify(opened.object.bbox));
  assert.ok(Math.abs(opened.object.bbox.h - 10) < 1e-3, JSON.stringify(opened.object.bbox));
  assert.ok(Math.abs(opened.object.bbox.x - 45) < 1e-3, JSON.stringify(opened.object.bbox));
});

test("rotation uses the given pivot: boxes rotate about it, not their own centers", async () => {
  // A rect near its own center rotated about (0, 0) moves far away: the emitted
  // pivots must be (0, 0), not the box center.
  const opened = await openDiagram(await encodeDiagram({
    width: 400, height: 400, source: "smoke", title: "",
    primitives: [{ kind: "rect", x: 90, y: 90, w: 20, h: 20, angle: Math.PI / 2, pivot: [0, 0], stroke: BLACK }],
  }));
  const translates = opsOf(opened.ops, "translate").map(op => op.args);
  assert.deepEqual(translates[0], [0, 0]);
  assert.deepEqual(translates[1], [-0, -0]);
  const transform = opsOf(opened.ops, "transform")[0];
  for (const [at, expected] of [[0, 0], [1, 1], [2, -1], [3, 0], [4, 0], [5, 0]]) {
    assert.ok(Math.abs(transform.args[at] - expected) < 1e-6, `${at}: ${transform.args[at]}`);
  }
  // rotated AABB of the pivot-rotated box: 90 degrees at (0,0) maps
  // (90..110, 90..110) to a 20x20 box at x in (-110..-90), y in 90..110,
  // padded by half the stroke width (1) on each side by the bbox pass
  assert.ok(Math.abs(opened.object.bbox.w - 22) < 1e-3, JSON.stringify(opened.object.bbox));
  assert.ok(opened.object.bbox.x >= -112 && opened.object.bbox.x <= -110, JSON.stringify(opened.object.bbox));
  // default pivot is still the shape's own center
  const centered = await openDiagram(await encodeDiagram({
    width: 400, height: 400, source: "smoke", title: "",
    primitives: [{ kind: "rect", x: 90, y: 90, w: 20, h: 20, angle: Math.PI / 2, stroke: BLACK }],
  }));
  const centeredTranslates = opsOf(centered.ops, "translate").map(op => op.args);
  assert.deepEqual(centeredTranslates[0], [100, 100]);
  assert.deepEqual(centeredTranslates[1], [-100, -100]);
  // text rotates about its anchor by default
  const text = await openDiagram(await encodeDiagram({
    width: 400, height: 400, source: "smoke", title: "",
    primitives: [{ kind: "text", x: 100, y: 100, text: "abc", fontSize: 10, angle: Math.PI }],
  }));
  const textTranslates = opsOf(text.ops, "translate").map(op => op.args);
  assert.deepEqual(textTranslates[0], [100, 100]);
  assert.deepEqual(textTranslates[1], [-100, -100]);
});

test("opacity is emitted as alpha inside the save/restore block", async () => {
  const opened = await openDiagram(await encodeDiagram({
    width: 100, height: 100, source: "smoke", title: "",
    primitives: [{ kind: "rect", x: 0, y: 0, w: 10, h: 10, fill: BLACK, opacity: 0.5 }],
  }));
  const alpha = opsOf(opened.ops, "alpha")[0];
  assert.ok(Math.abs(alpha.args[0] - 0.5) < 1e-7);
  isBetween(opened.ops, "save", "alpha", "restore");
});

test("no value that overflows float32 is emitted, finite JS doubles included", async () => {
  const bad = [
    [{ kind: "rect", x: 0, y: 0, w: 10, h: 10, stroke: BLACK, strokeWidth: 1e300 }],
    [{ kind: "rect", x: 0, y: 0, w: 10, h: 10, stroke: BLACK, strokeWidth: 10001 }],
    [{ kind: "rect", x: 0, y: 0, w: 10, h: 10, stroke: BLACK, dash: [1e300, 2] }],
    [{ kind: "rect", x: 0, y: 0, w: 10, h: 10, stroke: BLACK, rounded: 1e300 }],
    [{ kind: "ellipse", cx: 0, cy: 0, rx: 1e300, ry: 5, stroke: BLACK }],
    [{ kind: "ellipse", cx: 0, cy: 0, rx: -1, ry: 5, stroke: BLACK }],
    [{ kind: "text", x: 0, y: 0, text: "x", fontSize: 10, advance: 1e300 }],
    [{ kind: "rect", x: 10, y: 0, w: 1e301, h: 2, stroke: BLACK }],
    [{ kind: "polyline", points: [[0, 0], [1e300, 0]], stroke: BLACK }],
  ];
  for (const [primitive] of bad) {
    await assert.rejects(
      encodeDiagram({ width: 4000, height: 4000, source: "smoke", title: "", primitives: [primitive] }),
      error => error instanceof Error && typeof error.code === "string",
      JSON.stringify(primitive),
    );
  }
  // every emitted f32 operand of an accepted document is finite
  const opened = await openDiagram(await encodeDiagram({
    width: 4000, height: 4000, source: "smoke", title: "",
    primitives: [{ kind: "rect", x: 0, y: 0, w: 10, h: 10, stroke: BLACK, strokeWidth: 10000 }],
  }));
  for (const op of opened.ops) {
    for (const value of op.args) {
      if (typeof value === "number") {
        assert.ok(Number.isFinite(value), `${op.op}: ${value}`);
      }
    }
  }
});

test("encoding is deterministic byte for byte", async () => {
  const input = {
    width: 250, height: 120, source: "smoke", title: "determinism",
    primitives: [
      { kind: "rect", x: 1, y: 2, w: 3, h: 4, fill: BLACK, angle: 0.3 },
      { kind: "ellipse", cx: 50, cy: 50, rx: 4, ry: 5, stroke: BLACK },
      { kind: "text", x: 10, y: 90, text: "same bytes", fontSize: 12 },
    ],
  };
  const first = await encodeDiagram(input);
  const second = await encodeDiagram(input);
  assert.deepEqual(first, second);
});

test("input primitives are never mutated and frozen input converts identically", async () => {
  const prim = { kind: "text", x: 10, y: 10, text: "frozen", fontSize: 10, fill: null };
  const snapshot = JSON.stringify(prim);
  await encodeDiagram({ width: 100, height: 100, source: "smoke", title: "", primitives: [prim] });
  assert.equal(JSON.stringify(prim), snapshot);
  const fresh = JSON.parse(snapshot);
  await assert.doesNotReject(encodeDiagram({
    width: 100, height: 100, source: "smoke", title: "",
    primitives: [Object.freeze(fresh)],
  }));
});

test("property loop: random documents decode with intact invariants (120 cases)", async () => {
  const rng = mulberry32(0x00bdf00);
  for (let i = 0; i < 120; i += 1) {
    const primitives = [];
    const rects = rng.integer(6);
    let expectedFills = 0;
    let expectedStrokes = 0;
    let expectedBlocks = 0;
    for (let j = 0; j < rects; j += 1) {
      const wantFill = rng.integer(2) === 1;
      const wantStroke = rng.integer(2) === 1;
      primitives.push({
        kind: "rect",
        x: rng.integer(180) + 10, y: rng.integer(110) + 10,
        w: rng.integer(40) + 10, h: rng.integer(30) + 10,
        ...(wantFill ? { fill: BLACK } : {}),
        ...(wantStroke ? { stroke: BLACK, strokeWidth: rng.integer(4) + 1 } : {}),
        ...(rng.integer(4) === 0 ? { opacity: rng.next() } : {}),
        ...(rng.integer(5) === 0 ? { dash: [4, 4] } : {}),
      });
      expectedFills += wantFill ? 1 : 0;
      expectedStrokes += wantStroke ? 1 : 0;
      if (wantFill || wantStroke) {
        expectedBlocks += 1;
      }
    }
    const texts = rng.integer(4);
    for (let j = 0; j < texts; j += 1) {
      primitives.push({ kind: "text", x: rng.integer(200) + 20, y: rng.integer(80) + 20, text: `t${j}`, fontSize: rng.integer(14) + 8 });
    }
    expectedBlocks += texts;
    const bytes = await encodeDiagram({ width: 300, height: 200, source: "smoke", title: "pbt", primitives });
    const opened = await openDiagram(bytes);
    assert.equal(opened.page.w, 300);
    assert.equal(opsOf(opened.ops, "fillRect").length, expectedFills, "fill count");
    assert.equal(opsOf(opened.ops, "strokeRect").length, expectedStrokes, "stroke count");
    assert.equal(opsOf(opened.ops, "fillText").length, texts, "text count");
    // every visible primitive contributes exactly one save/restore pair, so
    // state (alpha, dash, rotation) can never leak between them
    assert.equal(opsOf(opened.ops, "save").length, expectedBlocks);
    assert.equal(opsOf(opened.ops, "restore").length, expectedBlocks);
    let depth = 0;
    for (const op of opened.ops) {
      if (op.op === "save") depth += 1;
      if (op.op === "restore") depth -= 1;
      assert.ok(depth >= 0, "restore before save");
    }
    assert.equal(depth, 0);
    // geometry stays on the page (the bbox covers strokes and rotations)
    assert.ok(opened.object.bbox.x >= -1 && opened.object.bbox.y >= -1);
    assert.ok(opened.object.bbox.x + opened.object.bbox.w <= opened.page.w + 1);
    assert.ok(opened.object.bbox.y + opened.object.bbox.h <= opened.page.h + 1);
    // re-encoding identical input yields identical bytes (spot check)
    const again = await encodeDiagram({ width: 300, height: 200, source: "smoke", title: "pbt", primitives });
    assert.deepEqual(again, bytes);
  }
});

test("limits: primitive count at the boundary works, one past the boundary fails", async () => {
  const atLimit = Array.from({ length: 20000 }, (_, i) => ({ kind: "rect", x: 0, y: 0, w: 1, h: 1, fill: BLACK }));
  const exactly = await encodeDiagram({ width: 4, height: 4, source: "smoke", title: "", primitives: atLimit });
  assert.ok(exactly.length > 0);
  await assert.rejects(
    encodeDiagram({ width: 4, height: 4, source: "smoke", title: "", primitives: [...atLimit, { kind: "rect", x: 0, y: 0, w: 1, h: 1 }] }),
    error => error.code === "too-large",
  );
});

test("limits: aggregate point and text volume caps trip before emission", async () => {
  // 21 polylines x 5000 points: per-primitive legal, 105000 total > 100000
  const fatPoly = { kind: "polyline", points: Array.from({ length: 5000 }, (_, i) => [i, i % 7]), stroke: BLACK };
  await assert.rejects(
    encodeDiagram({ width: 10000, height: 10000, source: "smoke", title: "", primitives: Array(21).fill(fatPoly) }),
    error => error.code === "too-large",
  );
  // 51 texts x 4096 chars: per-primitive legal, 208896 total > 200000
  const fatText = { kind: "text", x: 0, y: 0, text: "a".repeat(4096), fontSize: 10 };
  await assert.rejects(
    encodeDiagram({ width: 100000, height: 100, source: "smoke", title: "", primitives: Array(51).fill(fatText) }),
    error => error.code === "too-large",
  );
});

test("limits: page size 1<<24 accepted, above rejected", async () => {
  const max = 16777216;
  const ok = await encodeDiagram({ width: max, height: max, source: "smoke", title: "", primitives: [] });
  assert.ok(ok.length > 0);
  await assert.rejects(
    encodeDiagram({ width: max + 1, height: 10, source: "smoke", title: "", primitives: [] }),
    error => error.code === "too-large",
  );
  await assert.rejects(
    encodeDiagram({ width: 0, height: 10, source: "smoke", title: "", primitives: [] }),
    error => error.code === "invalid-input",
  );
  await assert.rejects(
    encodeDiagram({ width: NaN, height: 10, source: "smoke", title: "", primitives: [] }),
    error => error.code === "invalid-input",
  );
});

test("invalid inputs are rejected with codes, not crashes", async () => {
  const bad = [
    [{ width: 100, height: 100, source: "smoke", title: "", primitives: [{ kind: "circle", x: 0 }] }],
    [{ width: 100, height: 100, source: "smoke", title: "", primitives: [{ kind: "rect", x: 0, y: 0, w: 1, h: 1, fill: { r: 0, g: 0, b: 0, a: 999 } }] }],
    [{ width: 100, height: 100, source: "smoke", title: "", primitives: [{ kind: "rect", x: 2e6, y: 0, w: 1, h: 1 }] }],
    [{ width: 100, height: 100, source: "smoke", title: "", primitives: [{ kind: "text", x: 0, y: 0, text: "x", fontSize: 0 }] }],
    [{ width: 100, height: 100, source: "smoke", title: "", primitives: [{ kind: "text", x: 0, y: 0, text: "y".repeat(5000), fontSize: 10 }] }],
    [{ width: 100, height: 100, source: "smoke", title: "", primitives: [{ kind: "polyline", points: [[0, 0]], stroke: BLACK }] }],
    [{ width: 100, height: 100, source: "smoke", title: "", primitives: [{ kind: "polygon", points: [[0, 0], [1, 0]], fill: BLACK }] }],
    [{ width: 100, height: 100, source: "smoke", title: "", primitives: [{ kind: "polygon", x: 0 }] }],
    [{ width: 100, height: 100, source: "smoke", title: "", primitives: [{ kind: "rect", x: Infinity, y: 0, w: 1, h: 1 }] }],
    [{ width: 100, height: 100, source: "smoke", title: "", primitives: [{ kind: "rect", x: 0, y: 0, w: 1, h: 1, pivot: [1e300, 0] }] }],
    [{ width: 100, height: 100, source: "Smoke", title: "", primitives: [] }],
    [{ width: 100, height: 100, primitives: [] }],
  ];
  for (const [input] of bad) {
    await assert.rejects(encodeDiagram(input), error => error instanceof Error && typeof error.code === "string");
  }
});

test("openDiagram rejects malformed BDF bytes through the core reader", async () => {
  await assert.rejects(openDiagram(new Uint8Array(4)), Error);
  const good = await encodeDiagram({ width: 10, height: 10, source: "smoke", title: "", primitives: [] });
  const corrupt = new Uint8Array(good);
  corrupt[0] = 0x00;
  await assert.rejects(openDiagram(corrupt), Error);
});
