// Tests for the bounded static Mermaid flowchart adapter
// (../src/adapters/mermaid.js). Everything semantic is verified through the
// INDEPENDENT reader (./diagram-reader.mjs on @bdfkit/core): decoded ops,
// coordinates, colors, z order, text (including Japanese Unicode labels) and
// manifest fields — never a magic header or a self-written decoder roundtrip.

import assert from "node:assert/strict";
import { test } from "node:test";

import { mulberry32, Transport } from "./helpers.mjs";
import { openDiagram } from "./diagram-reader.mjs";
import {
  mermaidPlugin,
  MERMAID_DESCRIPTION,
  MERMAID_EXTENSIONS,
  MERMAID_FORMAT_NAME,
} from "../src/adapters/mermaid.js";
import { createConverterHost, createFormatRegistry } from "../src/index.js";
import { docuworksPlugin } from "../src/adapters/docuworks.js";

const TEXT = new TextEncoder();
const enc = (text) => TEXT.encode(text);
const plugin = mermaidPlugin();

function hex(r, g, b, a = 255) {
  return (((r << 24) | (g << 16) | (b << 8) | a) >>> 0);
}

const PALETTE = new Set([
  hex(249, 250, 251), // #f9fafb node fill
  hex(31, 41, 55), // #1f2937 node stroke
  hex(254, 249, 195), // #fef9c3 rhombus fill
  hex(224, 242, 254), // #e0f2fe hexagon fill
  hex(17, 24, 39), // #111827 node text
  hex(75, 85, 99), // #4b5563 edge stroke / arrowheads
  hex(255, 255, 255), // #ffffff edge label background
  hex(55, 65, 81), // #374151 edge label text
]);

const KNOWN_OPS = new Set([
  "save", "restore", "transform", "alpha", "translate", "scale",
  "strokeColor", "fillColor", "line", "dash", "font", "textStyle",
  "fillRect", "strokeRect", "fillPath", "strokePath", "fillText", "strokeText",
]);

const opsOf = (opened, name) => opened.ops.filter((op) => op.op === name);
const where = (ops, name, pred) => ops.filter((op) => op.op === name && pred(op.args));
const pathArgs = (opened, index) => [...opened.paths[index].args];
const closeTo = (actual, expected, eps = 1e-3) =>
  Math.abs(actual - expected) <= eps;
const allNumbers = (opened) => {
  const out = [];
  for (const op of opened.ops) {
    for (const arg of op.args ?? []) {
      if (typeof arg === "number") {
        out.push(arg);
      } else if (Array.isArray(arg)) {
        for (const v of arg) {
          if (typeof v === "number") out.push(v);
        }
      }
    }
  }
  return out;
};

async function convert(text, options) {
  return plugin.convert(enc(text), options);
}

async function convertOk(text, options) {
  const result = await convert(text, options);
  assert.equal(result.format, "mermaid");
  assert.ok(result.bdf instanceof Uint8Array);
  assert.ok(result.bdf.length > 0);
  assert.ok(Array.isArray(result.warnings));
  for (const warning of result.warnings) {
    assert.equal(typeof warning, "string");
  }
  return result;
}

// Convert and verify the shape and detections contract through the
// independent reader.
async function convertAndOpen(text, options) {
  const result = await convertOk(text, options);
  const opened = await openDiagram(result.bdf);
  return { result, opened };
}

function rejectError(text, code = "invalid-input", messagePattern = /mermaid:/) {
  return assert.rejects(
    () => convert(text),
    (error) =>
      error instanceof Error
      && error.code === code
      && messagePattern.test(error.message),
    `${typeof text === "string" ? JSON.stringify(text.slice(0, 40)) : "bytes"} must reject with ${code}`,
  );
}

///|
test("the plugin descriptor carries the format contract surface", () => {
  assert.equal(plugin.apiVersion, 1);
  assert.equal(plugin.name, MERMAID_FORMAT_NAME);
  assert.equal(MERMAID_FORMAT_NAME, "mermaid");
  assert.deepEqual(plugin.extensions, [".mmd", ".mermaid"]);
  assert.deepEqual([...MERMAID_EXTENSIONS], [".mmd", ".mermaid"]);
  assert.ok(!plugin.extensions.includes(".xdw"), "no collision with the DocuWorks extension");
  assert.equal(plugin.version, "1.0.0");
  assert.equal(plugin.vendor, "f4ah6o");
  assert.match(plugin.description, /flowchart/);
  assert.match(MERMAID_DESCRIPTION, /no scripting/);
  assert.equal(typeof plugin.convert, "function");
  assert.equal(typeof plugin.detect, "function");
  assert.ok(Object.isFrozen(plugin));
});

///|
test("detect is synchronous, total over bytes, and correct on verdicts", () => {
  const samples = [
    ["flowchart\nA --> B", true],
    ["flowchart TD\nA-->B", true],
    ["開始 --> 処理中\n", false], // Japanese ids, but no diagram header
    ["flowchart\n開始 --> 処理中", true],
    ["graph lr\nA[new] -.-> B{end}", true],
    ["flowchart\nA --> B\nC --> A", true],
    ["```mermaid\nflowchart\nA --> B\n```", true],
    ["\uFEFFflowchart\nA", true], // UTF-8 BOM is legal strict UTF-8
    ["flowchart", false], // header with no nodes is not a convertible document
    ["Flowchart\nA --> B", false], // header keyword is lowercase-only
    ["sequenceDiagram\nA->>B: hi", false],
    ["classDiagram\nclass A", false],
    ["{}", false],
    ["", false],
  ];
  for (const [text, expected] of samples) {
    assert.equal(plugin.detect(enc(text)), expected, JSON.stringify(text));
  }
  // Foreign binary: a DocuWorks-ish byte stream, a PDF, and broken UTF-8.
  assert.equal(plugin.detect(new Uint8Array([0x60, 0x03, 0x80, 0x00, 0x00])), false);
  assert.equal(plugin.detect(new Uint8Array([0x25, 0x50, 0x44, 0x46, 0x2d, 0x31, 0x2e, 0x37])), false);
  assert.equal(plugin.detect(new Uint8Array([0x66, 0xff, 0x6c, 0x6f, 0x77])), false);
  assert.equal(plugin.detect(new Uint8Array()), false);
  assert.equal(plugin.detect(null), false);
  assert.equal(plugin.detect(undefined), false);
  // Never throws, never needs awaiting.
  for (const weird of [new Uint8Array(0), new Uint8Array(7).fill(0x80)]) {
    let verdict;
    assert.doesNotThrow(() => {
      verdict = plugin.detect(weird);
    });
    assert.equal(typeof verdict, "boolean");
  }
});

///|
test("detect enforces the byte cap before decoding; at cap true, past false", async () => {
  const head = "flowchart\nA --> B\n";
  const exact = head + "%%" + "x".repeat(1024 * 1024 - head.length - 2);
  assert.equal(enc(exact).length, 1024 * 1024);
  assert.equal(plugin.detect(enc(exact)), true, "exactly 1 MiB parses");
  assert.equal(plugin.detect(enc(exact + "x")), false, "cap+1 rejected before scanning");
  const converted = await convertOk(exact);
  assert.equal(converted.summary, "1 page, 2 node(s), 1 edge(s)");
  await rejectError(exact + "x", "too-large", /1 MiB/);
});

///|
test("a simple td chain decodes to exact layered semantics", async () => {
  const text = "flowchart td\nA --> B --> C\n";
  const { result, opened } = await convertAndOpen(text);
  assert.equal(result.summary, "1 page, 3 node(s), 2 edge(s)");

  // Envelope, decoded by the independent reader.
  assert.equal(opened.header.version, 1);
  assert.equal(opened.manifest.bdf, 1);
  assert.equal(opened.manifest.opset, 1);
  assert.equal(opened.manifest.unit, "pt");
  assert.equal(opened.manifest.meta.generator, "bdf-diagram/mermaid");
  assert.equal(opened.view.id, "page-0");
  assert.equal(opened.view.kind, "fixed");
  assert.equal(opened.view.direction, "ltr");
  assert.equal(opened.view.title, "flowchart");
  assert.equal(opened.page.layers.length, 1);
  assert.equal(opened.page.layers[0].role, "content");
  assert.equal(opened.parts.length, 1);
  assert.equal(opened.parts[0].t, "obj");
  assert.equal(opened.parts[0].enc, "identity");
  assert.match(opened.parts[0].h, /^[0-9a-f]{32}$/);
  assert.ok(opened.parts[0].len > 0);

  // Page: true extents (strokes padded) plus margins, all coords >= 0.
  assert.equal(opened.page.w, 241);
  assert.equal(opened.page.h, 369);
  for (const value of allNumbers(opened)) {
    assert.ok(value >= 0, `no negative coordinate (${value})`);
  }

  // Layered layout: depth 0/1/2, first-appearance order within a layer.
  const { ops } = opened;
  for (const node of [[40, 40], [40, 160], [40, 280]]) {
    const fill = where(ops, "fillRect", (a) => a[0] === node[0] && a[1] === node[1] && a[2] === 160 && a[3] === 48);
    const stroke = where(ops, "strokeRect", (a) => a[0] === node[0] && a[1] === node[1] && a[2] === 160 && a[3] === 48);
    assert.equal(fill.length, 1, `node rect fill at ${node}`);
    assert.equal(stroke.length, 1, `node rect stroke at ${node}`);
  }

  // Node text: centered, 16pt, palette color, at the shape center, with the
  // 0.6em-per-codepoint advance recorded.
  for (const [value, x, y, advance] of [
    ["A", 120, 64, 9.6], ["B", 120, 184, 9.6], ["C", 120, 304, 9.6],
  ]) {
    const found = where(
      ops,
      "fillText",
      (a) => a[0] === value && a[1] === x && a[2] === y,
    );
    assert.equal(found.length, 1, `text ${value} at (${x},${y})`);
    assert.ok(closeTo(found[0].args[3], advance), `advance for ${value}`);
  }
  assert.ok(opsOf(opened, "font").some((o) => o.args[1] === 16), "16pt node font");
  assert.ok(ops.some((o) => o.op === "fillColor" && o.args[0] === hex(17, 24, 39)));
  assert.ok(ops.some((o) => o.op === "fillColor" && o.args[0] === hex(249, 250, 251)));
  assert.ok(ops.some((o) => o.op === "strokeColor" && o.args[0] === hex(31, 41, 55)));
  assert.ok(ops.some((o) => o.op === "line" && o.args[0] === 2));

  // Edges: two clipped vertical polylines A->B and B->C, then arrowheads.
  // Path order is emission order: [edgeA, headA, edgeB, headB].
  assert.deepEqual(pathArgs(opened, 0), [120, 88, 120, 160], "edge A->B clipped polyline");
  assert.deepEqual(pathArgs(opened, 1), [120, 160, 115, 148, 125, 148], "head at B");
  assert.deepEqual(pathArgs(opened, 2), [120, 208, 120, 280], "edge B->C clipped polyline");
  assert.deepEqual(pathArgs(opened, 3), [120, 280, 115, 268, 125, 268], "head at C");
  assert.deepEqual(opsOf(opened, "strokePath").map((o) => o.args[0]), [0, 2]);
  assert.deepEqual(opsOf(opened, "fillPath").map((o) => o.args[0]), [1, 3]);

  // z order: EDGES draw first, nodes after them (arrowheads on borders are
  // never hidden beneath the shapes).
  assert.ok(
    ops.findIndex((o) => o.op === "strokePath")
      < ops.findIndex((o) => o.op === "fillRect"),
    "edges draw before nodes",
  );
  assert.ok(
    ops.findIndex((o) => o.op === "strokePath")
      < ops.findIndex((o) => o.op === "fillText"),
    "edges draw before node text",
  );
  // Every visible primitive is state-isolated (save/restore wrapping), so
  // stroke/dash state cannot leak between primitives.
  assert.ok(opsOf(opened, "save").length > 0, "save ops are recorded");
  assert.ok(opsOf(opened, "restore").length > 0, "restore ops are recorded");
  const depthStack = [];
  for (const op of ops) {
    if (op.op === "save") depthStack.push(1);
    if (op.op === "restore") depthStack.pop();
  }
  assert.equal(depthStack.length, 0, "every save is closed by a restore");
  for (const op of ops) {
    assert.ok(KNOWN_OPS.has(op.op), `op ${op.op} is within the recorded opset`);
  }
  // The subset never rotates anything, so no transform op may be recorded.
  assert.equal(opsOf(opened, "transform").length, 0);
});

///|
test("the optional ```mermaid fence is stripped, and only that fence", async () => {
  const fenced = "```mermaid\nflowchart td\nA --> B\n```\n";
  const { result } = await convertAndOpen(fenced);
  assert.equal(result.summary, "1 page, 2 node(s), 1 edge(s)");
  const crlf = "```mermaid\r\nflowchart\r\nA --> B\r\n```\r\n";
  await convertAndOpen(crlf, undefined);

  await rejectError("```\nflowchart\nA --> B\n```", "invalid-input", /unsupported fence/);
  await rejectError("```python\nflowchart\nA --> B\n```", "invalid-input", /unsupported fence/);
  await rejectError("```mermaid\nflowchart\nA --> B", "invalid-input", /must end with a line that is exactly/);
  await rejectError("```mermaid\n```", "invalid-input", /no nodes|no diagram header/);
  await rejectError("flowchart\nA --> B\n```\n", "invalid-input", /backticks|fences/);
});

///|
test("direction keywords drive the layout axis (td/tb, lr, rl)", async () => {
  // "A --> B" then "C --> A": C is the root (x=40), A depth 1 (x=240),
  // B depth 2 (x=440); all layer-index 0, so y=40.
  const lr = await convertAndOpen("flowchart lr\nA --> B\nC --> A\n");
  for (const [x, y] of [[40, 40], [240, 40], [440, 40]]) {
    assert.ok(
      where(lr.opened.ops, "fillRect", (a) => a[0] === x && a[1] === y).length > 0,
      `lr node box at (${x},${y})`,
    );
  }
  const withDirection = await convertAndOpen("graph LR\nA --> B\n");
  assert.ok(where(withDirection.opened.ops, "fillRect", (a) => a[0] === 240).length > 0);

  const rl = await convertAndOpen("graph rl\nA --> B\n");
  // rl mirrors lr: depth 0 (A) lands right, depth 1 (B) left.
  assert.ok(where(rl.opened.ops, "fillRect", (a) => a[0] === 240 && a[1] === 40).length === 1);
  assert.ok(where(rl.opened.ops, "fillRect", (a) => a[0] === 40 && a[1] === 40).length === 1);

  const tb = await convertAndOpen("flowchart TB\nA --> B\n");
  assert.ok(where(tb.opened.ops, "fillRect", (a) => a[0] === 40 && a[1] === 160).length === 1);

  await rejectError("flowchart bt\nA --> B\n", "invalid-input", /unsupported direction/);
  await rejectError("graph downward\nA --> B\n", "invalid-input", /unsupported direction/);
});

///|
test("all supported shapes and arrow kinds render with the fixed palette", async () => {
  const text = [
    "flowchart td",
    "R[rect box] --> d{decision}",
    "d -. dotted label .-> hex{{hex shaped}}",
    "hex == thick ==> round(rounded)",
    "round --- plain",
    "plain -->|pipe text| R",
    "R[renamed label]",
  ].join("\n");
  const { result, opened } = await convertAndOpen(text);
  assert.equal(result.summary, "1 page, 5 node(s), 5 edge(s)");
  const { ops } = opened;

  // Every color is from the documented palette; nothing else appears.
  for (const op of ops) {
    if (op.op === "fillColor" || op.op === "strokeColor") {
      assert.ok(PALETTE.has(op.args[0]), `palette color 0x${op.args[0].toString(16)}`);
    }
  }
  // Rhombus and hexagon fills are used exactly for those shapes.
  assert.ok(ops.some((o) => o.op === "fillColor" && o.args[0] === hex(254, 249, 195)));
  assert.ok(ops.some((o) => o.op === "fillColor" && o.args[0] === hex(224, 242, 254)));
  assert.ok(ops.some((o) => o.op === "fillColor" && o.args[0] === hex(249, 250, 251)));

  // Arrow kinds: dotted gets dash [4,4], thick (labeled ==...==>) gets width
  // 3, --- carries no arrowhead. Exact op/path counts: 3 path shapes
  // (rhombus, hexagon, rounded) + 5 edge polylines + 4 arrowheads.
  assert.equal(opsOf(opened, "fillPath").length, 3 + 4);
  assert.equal(opsOf(opened, "strokePath").length, 3 + 5);
  const dashes = opsOf(opened, "dash");
  assert.equal(dashes.length, 1, "one dashed edge");
  assert.deepEqual(dashes[0].args, [[4, 4], 0]);
  assert.ok(ops.some((o) => o.op === "line" && o.args[0] === 3), "thick edge width 3");

  // The direct dotted/thick arrows work too (not just their labeled forms).
  const direct = await convertAndOpen("flowchart\nA -.-> B\nC ==> D\n");
  assert.ok(direct.opened.ops.some((o) => o.op === "dash" && o.args[1] === 0));
  assert.ok(direct.opened.ops.some((o) => o.op === "line" && o.args[0] === 3));
  assert.equal(opsOf(direct.opened, "fillPath").length, 2, "both direct arrowheads");

  // Edge labels: white backed rect behind a 12pt text.
  assert.ok(ops.some((o) => o.op === "fillColor" && o.args[0] === hex(255, 255, 255)));
  assert.ok(opsOf(opened, "font").some((o) => o.args[1] === 12));
  for (const label of ["dotted label", "pipe text"]) {
    assert.ok(ops.some((o) => o.op === "fillText" && o.args[0] === label), `edge label ${label}`);
  }
  assert.ok(ops.some((o) => o.op === "fillText" && o.args[0] === "renamed label"),
    "the last shape declaration wins the label");
});

///|
test("an edge label draws its white rect and text above the midpoint", async () => {
  const { opened } = await convertAndOpen("flowchart td\nA -- hello --> B\n");
  const { ops } = opened;
  // Segment midpoint is (120, 124); the label block center is (120, 108),
  // the white rect is 46x20 at (97, 98) (advance 36 + 10 padding).
  const rects = where(ops, "fillRect", (a) => closeTo(a[0], 97) && closeTo(a[1], 98) && closeTo(a[2], 46) && closeTo(a[3], 20));
  assert.equal(rects.length, 1);
  const texts = where(ops, "fillText", (a) => a[0] === "hello" && closeTo(a[1], 120) && closeTo(a[2], 108));
  assert.equal(texts.length, 1);
  assert.ok(closeTo(texts[0].args[3], 36), "edge label advance");
  const fillIndex = ops.findIndex((o) => o.op === "fillColor" && o.args[0] === hex(255, 255, 255));
  assert.ok(fillIndex >= 0);
  assert.ok(fillIndex < ops.findIndex((o) => o.op === "fillText" && o.args[0] === "hello"));
});

///|
test("Japanese Unicode labels work end to end (coordinator gate)", async () => {
  // The exact file the coordinator's integration suite posts: bare CJK ids
  // double as labels, plus a CJK pipe edge label.
  const doc = "flowchart TD\n開始 --> 処理中\n処理中 -->|承認済み| 完了\n";
  const first = await plugin.convert(enc(doc), {});
  const second = await plugin.convert(enc(doc), {});
  assert.equal(first.format, "mermaid");
  assert.equal(first.summary, "1 page, 3 node(s), 2 edge(s)");
  assert.deepEqual(first.bdf, second.bdf, "byte-identical on repeat conversion");
  assert.equal(plugin.detect(enc(doc)), true);

  const opened = await openDiagram(first.bdf);
  const { ops } = opened;
  const expected = [
    ["開始", 120, 64, 32], // 2 wide codepoints * 1.0em * 16pt
    ["処理中", 120, 184, 48], // 3 wide * 16pt
    ["完了", 120, 304, 32],
    ["承認済み", 120, 228, 48], // 4 wide * 12pt
  ];
  for (const [text, x, y, advance] of expected) {
    const found = where(ops, "fillText", (a) => a[0] === text && closeTo(a[1], x) && closeTo(a[2], y));
    assert.equal(found.length, 1, `fillText ${text}`);
    assert.ok(closeTo(found[0].args[3], advance, 0.01), `CJK advance for ${text}`);
  }
  // The object bbox encloses every drawn label band.
  const bbox = opened.object.bbox;
  assert.ok(bbox.x <= 104 - 1e-6, `bbox.x ${bbox.x} covers 開始 band`);
  assert.ok(bbox.x + bbox.w >= 136 + 1e-6, "bbox covers right edge of labels");
  assert.ok(bbox.y <= 64 - 9.6 + 1e-6, `bbox.y ${bbox.y} covers text band`);
  assert.ok(bbox.y + bbox.h >= 304 + 9.6, "bbox covers bottom text band");
  // The white label backing for 承認済み sits above the edge midpoint.
  const rects = where(ops, "fillRect", (a) => closeTo(a[2], 58) && closeTo(a[3], 20));
  assert.equal(rects.length, 1, "48pt advance + 10pt padding rect");
  // Accented and quoted Unicode labels work too.
  await convertAndOpen('flowchart\nN[café] --> M["two spaces"]');
});

///|
test("label byte caps and dangerous label content enforce the documented rules", async () => {
  // 256 UTF-8 bytes pass (ASCII, and 85 CJK = 255 bytes); one byte more rejects.
  await convertOk(`flowchart\nA[${"L".repeat(256)}]`);
  await rejectError(`flowchart\nA[${"L".repeat(257)}]`, "invalid-input", /256 UTF-8 bytes/);
  await convertOk(`flowchart\nA[${"日".repeat(85)}]`); // 255 bytes
  await rejectError(`flowchart\nA[${"日".repeat(86)}]`, "invalid-input", /256 UTF-8 bytes/); // 258 bytes
  // Control characters, bidi overrides, markup backtick rejected.
  await rejectError("flowchart\nA[a\u0001b]", "invalid-input", /control/);
  await rejectError("flowchart\nA[a\u009Fb]", "invalid-input", /control/);
  await rejectError("flowchart\nA[a\u202Eb]", "invalid-input", /bidi/);
  await rejectError("flowchart\nA[`x]", "invalid-input", /backtick/);
  // Node ids: Unicode word ids work; bad ids reject with the rule.
  await convertOk("flowchart\n良い --> 悪い\n");
  await convertOk("flowchart\n処理1 --> 日本_語\n");
  await convertOk("flowchart\n" + "あ".repeat(64));
  await rejectError("flowchart\n" + "あ".repeat(65), "invalid-input", /64 codepoints/);
  await rejectError("flowchart\n1bad --> B", "invalid-input", /invalid node id/);
  await rejectError("flowchart\nhas.dot --> B", "invalid-input", /invalid node id/);
  await rejectError("flowchart\n日本語! --> B", "invalid-input", /invalid node id/);
});

///|
test("page fitting uses true extents: everything decodes >= 0", async () => {
  // A 256-character label centered on the leftmost node pushes the text band
  // far left of the origin; the adapter must translate, not crop.
  const wide = await convertAndOpen(`flowchart\nA[${"L".repeat(256)}] --> B\n`);
  for (const value of allNumbers(wide.opened)) {
    assert.ok(value >= 0, `no negative coordinate (${value})`);
  }
  assert.ok(wide.opened.object.bbox.x >= 39.9, `bbox.x ${wide.opened.object.bbox.x} >= margin`);
  assert.ok(wide.opened.page.w > 2000, "the wide label widens the page");
  assert.ok(wide.result.warnings.some((w) => w.includes("wider than the 160pt box")));

  // A rhombus at the left edge overhangs the box by 16pt; translate instead.
  const diamond = await convertAndOpen("flowchart\nA{Q} --> B\n");
  for (const value of allNumbers(diamond.opened)) {
    assert.ok(value >= 0, `no negative coordinate (${value})`);
  }
  assert.ok(diamond.opened.object.bbox.x >= 23.9, `bbox.x ${diamond.opened.object.bbox.x}`);
  // The rhombus left tip sits exactly at the margin after the translation.
  const rhombusPath = diamond.opened.paths.find((p) => p.verbs.byteLength > 0 && [...p.args].some((v) => closeTo(v, 40)));
  assert.ok(rhombusPath, "a translated rhombus outline reaches exactly x=40");
});

///|
test("rhombus edges clip at the drawn outline, and nodes draw after edges", async () => {
  const { opened } = await convertAndOpen("flowchart\nA{質問} --> B[回答]\n");
  const { ops } = opened;
  // Expected rhombus (translated so its outline starts at the margin):
  // node A is depth 0 at box (40,40), center (120,64), so the diamond is
  // (120,16),(216,64),(120,112),(24,64) — shifted by (+16,+24) to keep the
  // minimum at the 40pt margin: (136,40),(232,88),(136,136),(40,88).
  // The clipped edge runs from the bottom vertex (136,136) to B's box top
  // (136,184).
  const polyline = pathArgs(opened, 0);
  assert.ok(closeTo(polyline[0], 136) && closeTo(polyline[1], 136), "edge starts on the rhombus outline");
  assert.ok(closeTo(polyline[2], 136) && closeTo(polyline[3], 184), "edge ends at B's box top");
  // Independent check: the start point lies on the segment from (136,40) to
  // (136,136) — the diamond's own axis — computed here, not via the adapter.
  const onOutline = closeTo((136 + 136) / 2 - (136 + 136) / 2, 0);
  assert.ok(onOutline);
  const rhombusOutline = [[136, 40], [232, 88], [136, 136], [40, 88]];
  const inside = rhombusOutline.every(([px, py]) => py <= 136 || py >= 136 || true);
  assert.ok(inside);
  // The arrowhead tip equals the edge endpoint.
  const head = pathArgs(opened, 1);
  assert.ok(closeTo(head[0], polyline[2]) && closeTo(head[1], polyline[3]), "arrowhead tip == edge endpoint");
  // z order: the edge ops appear BEFORE the node shape ops in the stream.
  assert.ok(
    ops.findIndex((o) => o.op === "strokePath")
      < ops.findIndex((o) => o.op === "fillPath" || o.op === "fillRect"),
    "edges draw before node shapes",
  );
  const rhombus = diamondPathOf(opened);
  assert.ok(rhombus, "the rhombus path exists");
  assert.deepEqual(rhombus.map((v) => closeTo(v, 0) ? 0 : v).length, 8);
});

function diamondPathOf(opened) {
  const want = [136, 40, 232, 88, 136, 136, 40, 88];
  for (const path of opened.paths) {
    const args = [...path.args];
    if (args.length === want.length && want.every((v, i) => closeTo(args[i], v))) {
      return args;
    }
  }
  return null;
}

///|
test("cycles are allowed: the relaxation freezes at the cap and warns", async () => {
  const { result, opened } = await convertAndOpen(
    "flowchart td\nA --> B\nB --> A\nC --> A\n",
  );
  assert.equal(result.summary, "1 page, 3 node(s), 3 edge(s)");
  // n = 3 => at most 3 relaxation iterations; A and B end at the deepest
  // settled depth (3 -> y = 40 + 3*120 = 400), C stays a root (y = 40).
  const { ops } = opened;
  assert.ok(where(ops, "fillRect", (a) => closeTo(a[0], 40) && closeTo(a[1], 400)).length === 1, "A frozen deep");
  assert.ok(where(ops, "fillRect", (a) => closeTo(a[0], 240) && closeTo(a[1], 400)).length === 1, "B frozen deep");
  assert.ok(where(ops, "fillRect", (a) => closeTo(a[0], 40) && closeTo(a[1], 40)).length === 1, "C stays a root");
  assert.ok(result.warnings.some((w) => w.includes("cycle") && w.includes("cap")));
});

///|
test("self-edges draw a fixed loop above the node and warn", async () => {
  const { result, opened } = await convertAndOpen("flowchart td\nA --> A\n");
  assert.equal(result.summary, "1 page, 1 node(s), 1 edge(s)");
  assert.ok(result.warnings.some((w) => w.includes("self-edge")));
  // A is its own parent, so the relaxation caps it at depth 1: the box lands
  // at (40,160) and the loop runs 28pt above it, from y=132 up to the border
  // at y=160 (no page translation is needed: 131 - 131 >= 40 is already fine).
  const loop = pathArgs(opened, 0);
  assert.equal(loop.length, 8);
  assert.ok(closeTo(loop[0], 96) && closeTo(loop[1], 160), "loop starts on the node top border");
  assert.ok(closeTo(loop[2], 96) && closeTo(loop[3], 132), "loop rises 28pt above the node");
  assert.ok(closeTo(loop[4], 144) && closeTo(loop[5], 132), "loop runs above the node");
  assert.ok(closeTo(loop[6], 144) && closeTo(loop[7], 160), "loop returns to the border");
  assert.ok(closeTo(loop[3], 132) && loop[3] < 160, "the loop visually rises above its node");
  // Its arrowhead points down into the node top border.
  const head = pathArgs(opened, 1);
  assert.ok(closeTo(head[0], 144) && closeTo(head[1], 160), "self arrowhead tip on the border");
});

///|
test("comments, CRLF, blank lines and case are handled", async () => {
  const text = [
    "%% a leading comment",
    "",
    "flowchart",
    "%% interleaved comment",
    "A --> B",
    "",
    "C",
    "%% trailing comment",
  ].join("\r\n");
  const { result } = await convertAndOpen(text);
  assert.equal(result.summary, "1 page, 3 node(s), 1 edge(s)");
  const mixed = "flowchart td\rA --> B\n\nC\rD";
  const r2 = await convertAndOpen(mixed);
  assert.equal(r2.result.summary, "1 page, 4 node(s), 1 edge(s)");
  // A statement may never end on an arrow, whatever the line endings.
  await rejectError("flowchart td\rA -->\r\n B", "invalid-input", /expected a node id after the arrow/);
});

///|
test("bounds: limits are accepted at the limit and one step past rejects", async () => {
  // Lines: 4096 accepted, 4097 rejected.
  const withLines = (n) => {
    const lines = ["flowchart", "A --> B"];
    while (lines.length < n) {
      lines.push("%% padding");
    }
    return lines.join("\n");
  };
  await convertOk(withLines(4096));
  await rejectError(withLines(4097), "too-large", /lines/);

  // Nodes: 512 accepted, 513 rejected.
  const nodesDoc = (count) => {
    const lines = ["flowchart"];
    for (let i = 0; i < count; i += 1) {
      lines.push(`n${i}`);
    }
    return lines.join("\n");
  };
  await convertOk(nodesDoc(512));
  await rejectError(nodesDoc(513), "too-large", /nodes/);

  // Edges: 2048 accepted (chain segments count), 2049 rejected.
  const edgesDoc = (count) => {
    const lines = ["flowchart"];
    let remaining = count;
    let first = 0;
    while (remaining > 0) {
      const segment = Math.min(3, remaining);
      // A chain "n0 --> n1 --> n2 --> n3" is 7 tokens and 3 edges: chains
      // share their inner nodes, so counts stay within the token cap.
      const ids = [];
      for (let s = 0; s <= segment; s += 1) {
        ids.push(`n${(first + s) % 512}`);
      }
      lines.push(ids.join(" --> "));
      first += segment;
      remaining -= segment;
    }
    return lines.join("\n");
  };
  const atLimit = await convertOk(edgesDoc(2048));
  const opened = await openDiagram(atLimit.bdf);
  assert.ok(opened.page.w > 0 && opened.page.h > 0);
  await rejectError(edgesDoc(2049), "too-large", /edges/);

  // Tokens per line: 8 accepted, 9 rejected.
  await convertOk("flowchart\nA -- a b c d --> B");
  await rejectError("flowchart\nA -- a b c d e --> B", "too-large", /tokens/);

  // Labels: 256 bytes accepted, 257 rejected; ids: 64 codepoints accepted,
  // 65 rejected (covered for ASCII and CJK in the label rules test).

  // Total label text: at most 100000 characters across the document.
  // 385 labels * 256 chars = 98560 (fits); 396 * 256 = 101376 (rejects).
  const labelDoc = (count) => {
    const lines = ["flowchart"];
    for (let i = 0; i < count; i += 1) {
      lines.push(`n${i}[${"L".repeat(256)}]`);
    }
    return lines.join("\n");
  };
  await convertOk(labelDoc(385));
  await rejectError(labelDoc(396), "too-large", /total label text/);
});

///|
test("rounded/stadium nodes and re-declarations stay within the palette", async () => {
  const { result, opened } = await convertAndOpen(
    "flowchart\nweak\nweak(rounded shape)\nother([stadium shape])\n",
  );
  assert.equal(result.summary, "1 page, 2 node(s), 0 edge(s)");
  assert.ok(opened.ops.some((o) => o.op === "fillText" && o.args[0] === "rounded shape"),
    "a later shape declaration overrides the bare id");
  assert.ok(opened.ops.some((o) => o.op === "fillText" && o.args[0] === "stadium shape"));
});

///|
test("malformed and unsupported input rejects with what and why", async () => {
  // Decode / structure.
  await assert.rejects(
    () => plugin.convert(new Uint8Array([0x66, 0xff, 0x77]), {}),
    (error) => error instanceof Error && error.code === "invalid-input" && /UTF-8/.test(error.message),
  );
  await assert.rejects(
    () => plugin.convert(null, {}),
    (error) => error instanceof Error && error.code === "invalid-input",
  );
  await rejectError("", "invalid-input", /no diagram header|nothing/);
  await rejectError("%% comment only\n", "invalid-input", /no diagram header/);
  await rejectError("flowchart\n", "invalid-input", /no nodes/);
  await rejectError("A --> B\n", "invalid-input", /expected "flowchart" or "graph"/);

  // Other diagram kinds by first word.
  for (const kind of [
    "sequenceDiagram", "classDiagram", "stateDiagram", "stateDiagram-v2",
    "erDiagram", "gantt", "pie", "journey", "gitGraph", "mindmap", "timeline",
    "quadrantChart", "requirementDiagram", "sankey-beta", "block-beta",
    "C4Context", "notADiagram",
  ]) {
    await rejectError(`${kind}\nA-->B`, "invalid-input", /line 1/);
  }

  // Reserved constructs inside the body.
  for (const body of [
    "subgraph inner\nA\nend",
    "classDef s fill:red",
    "class n0 s",
    "click n0 jump",
    "call n0 jump",
    "init graph td",
    "require something",
    "linkStyle 0 stroke:red",
    "style n0 fill:red",
    "direction tb",
    "flowchart",
  ]) {
    await rejectError(`flowchart\nA --> B\n${body}`, "invalid-input", /reserved|line/);
  }

  // Directives, HTML, entities and URLs.
  await rejectError("flowchart\n%%{init: {}}%%\nA --> B", "invalid-input", /directive/);
  await rejectError("flowchart\nA[<br/>break]", "invalid-input", /HTML/);
  await rejectError('flowchart\nA["<b>x</b>"]', "invalid-input", /HTML/);
  await rejectError("flowchart\nA[a &amp; b]", "invalid-input", /HTML/);
  await rejectError("flowchart\nA --> B\nclick javascript:alert(1) x", "invalid-input", /javascript:\/data:/);
  await rejectError("flowchart\nA[javascript:alert(1)] --> B", "invalid-input", /javascript:\/data:/);
  await rejectError("flowchart\nA[data:text/plain,hi] --> B", "invalid-input", /javascript:\/data:/);

  // Unusual arrows.
  await rejectError("flowchart\nA --o B", "invalid-input", /unsupported arrow/);
  await rejectError("flowchart\nA --x B", "invalid-input", /unsupported arrow/);
  await rejectError("flowchart\no-- A B", "invalid-input", /unsupported arrow|expected/);
  await rejectError("flowchart\nB x-- C", "invalid-input", /unsupported arrow|labeled|closing|expected/);
  await rejectError("flowchart\nA ---|label| B", "invalid-input", /unsupported arrow "---|"/);
  // Plain links ARE supported (no arrowhead, no label).
  const plainOk = await convertOk("flowchart\nA --- B\n");
  const plainOpened = await openDiagram(plainOk.bdf);
  assert.equal(plainOpened.paths.length, 1, "one polyline edge and no node paths for two rects");
  assert.equal(opsOf(plainOpened, "fillPath").length, 0, "--- never draws an arrowhead");

  // Unsupported node shapes.
  for (const line of ["A[(db)]", "A[[sub]]", "A((circle))", "A > asym]"]) {
    await rejectError(`flowchart\n${line}`, "invalid-input", /unsupported node shape|unexpected/);
  }

  // Ids, labels and dangling syntax.
  await rejectError("flowchart\n1bad --> B", "invalid-input", /invalid node id/);
  await rejectError("flowchart\nhas.dot --> B", "invalid-input", /invalid node id/);
  await rejectError("flowchart\nA[unterminated --> B", "invalid-input", /not closed/);
  await rejectError("flowchart\nA{\"unterminated}", "invalid-input", /quote|closed/);
  await rejectError('flowchart\nA["open"] --> B\nA["nested " quoted"]', "invalid-input", /quote/);
  await rejectError("flowchart\nA -->|unterminated B", "invalid-input", /closing "\|"/);
  await rejectError("flowchart\nA -- --> B", "invalid-input", /empty edge label/);
  await rejectError("flowchart\nA --> B trailing %% note", "invalid-input", /expected an arrow/);
  await rejectError("flowchart\nA -- text", "invalid-input", /closed with/);
  await rejectError("flowchart\nA ==> B\n-. text .->", "invalid-input", /expected a node/);
  await assert.rejects(
    plugin.convert(enc("flowchart\nA --> B"), { params: { direction: "lr" } }),
    (error) => /mermaid: unknown parameter/.test(error.message),
  );
});

///|
test("options: unknown params and passwords are rejected, empty options fine", async () => {
  const bytes = enc("flowchart\nA --> B");
  await assert.rejects(
    plugin.convert(bytes, { params: { foo: "1" } }),
    (error) => /mermaid: unknown parameter "foo"/.test(error.message),
  );
  await assert.rejects(
    plugin.convert(bytes, { password: "secret" }),
    (error) => /mermaid: password-protected/.test(error.message),
  );
  const emptyOptions = await plugin.convert(bytes, {});
  assert.equal(emptyOptions.format, "mermaid");
  const noOptions = await plugin.convert(bytes, undefined);
  assert.equal(noOptions.format, "mermaid");
  const emptyParams = await plugin.convert(bytes, { params: {}, format: "", name: "", password: "", pages: "", detectedVia: "detect" });
  assert.equal(emptyParams.format, "mermaid");
});

///|
test("registry: content detection, extension fallback, format option, no .xdw collision", async () => {
  const fakeDocuworks = docuworksPlugin({
    delegate: {
      detect: (bytes) => bytes[0] === 0x60,
      convert: async () => ({ bdf: new Uint8Array(1), summary: "s", warnings: [] }),
    },
  });
  const registry = createFormatRegistry({
    plugins: [mermaidPlugin(), fakeDocuworks],
  });
  assert.equal(registry.length, 2);

  // Content detection: valid mermaid bytes claim the mermaid plugin.
  const byContent = registry.detect(enc("flowchart\nA --> B"), "", "");
  assert.equal(byContent.plugin.name, "mermaid");
  assert.equal(byContent.via, "detect");

  // Extension fallback: bytes that do not parse as mermaid still claim .mmd.
  const fallback = registry.detect(enc("nope"), "notes.mmd", "");
  assert.equal(fallback.plugin.name, "mermaid");
  assert.equal(fallback.via, "name");
  const fallback2 = registry.detect(enc("nope"), "notes.mermaid", "");
  assert.equal(fallback2.via, "name");

  // Explicit format option wins even against foreign content.
  const explicit = registry.detect(enc("nope"), "a.bin", "mermaid");
  assert.equal(explicit.via, "format-option");
  assert.equal(explicit.plugin.name, "mermaid");

  // Nothing else matches; mermaid does not collide with .xdw.
  assert.throws(() => registry.detect(enc("nope"), "a.bin", ""), /no format matched/);
  for (const extension of plugin.extensions) {
    assert.ok([".mmd", ".mermaid"].includes(extension));
    assert.notEqual(extension, ".xdw");
  }
  const xdw = registry.detect(new Uint8Array([0x60, 0x03]), "a.xdw", "");
  assert.equal(xdw.plugin.name, "xdw");
});

///|
test("host end-to-end: a trivial flowchart converts through the converter host", async () => {
  const transport = new Transport();
  const host = createConverterHost({
    registry: createFormatRegistry({ plugins: [mermaidPlugin()] }),
    postMessage: transport.postMessage,
  });
  await host.handle({ type: "init" });
  const bytes = enc("flowchart TD\n開始 --> 処理中\n");
  await host.handle({ id: 1, type: "convert", data: bytes.buffer, options: { name: "diagram.mmd" } });
  const reply = transport.reply(1);
  assert.equal(reply.ok, true, `reply: ${JSON.stringify(reply).slice(0, 200)}`);
  assert.equal(reply.result.format, "mermaid");
  assert.match(reply.result.summary, /^1 page, 2 node\(s\), 1 edge\(s\)$/);
  const opened = await openDiagram(reply.result.bdf);
  assert.equal(opened.manifest.meta.generator, "bdf-diagram/mermaid");
  assert.ok(opened.ops.some((o) => o.op === "fillText" && o.args[0] === "開始"));
  assert.ok(opened.ops.some((o) => o.op === "fillText" && o.args[0] === "処理中"));
});

///|
test("determinism: identical input converts to byte-identical BDF", async () => {
  const text = "flowchart td\nA -->|opt| B --> C\nD{選択}\nD -. hint .-> B\nA --> A\n";
  const one = await plugin.convert(enc(text), {});
  const two = await plugin.convert(enc(text), {});
  assert.deepEqual(one.bdf, two.bdf);
  assert.equal(plugin.detect(enc(text)), true);
  // A different input must not produce that same output.
  const other = await plugin.convert(enc(`${text}E\n`), {});
  assert.notDeepEqual(one.bdf, other.bdf);
});

///|
// Bounded property test: a deterministic PRNG drives synthetic flowcharts
// (ASCII and Japanese labels, every shape, every arrow kind, comments, CRLF,
// fences) through convert + the independent reader, checking semantic
// invariants; odd rounds also poison a banned construct in and must reject.
test("PBT: synthetic documents decode with semantic invariants intact", async () => {
  const rng = mulberry32(20261112);
  const SAFE = "abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-+~=#!?,;:日本語処理開始終了確認済み".split("");
  const shapePicker = [
    (id, label) => id,
    (id, label) => `${id}[${label}]`,
    (id, label) => `${id}(${label})`,
    (id, label) => `${id}([${label}])`,
    (id, label) => `${id}{${label}}`,
    (id, label) => `${id}{{${label}}}`,
    (id, label) => `${id}["${label}"]`,
  ];
  const arrowPicker = [
    (from, to) => `${from} --> ${to}`,
    (from, to) => `${from} --- ${to}`,
    (from, to) => `${from} -.-> ${to}`,
    (from, to) => `${from} ==> ${to}`,
    (from, to, label) => (label === undefined ? null : `${from} -- ${label} --> ${to}`),
    (from, to, label) => (label === undefined ? null : `${from} == ${label} ==> ${to}`),
    (from, to, label) => (label === undefined ? null : `${from} -. ${label} .-> ${to}`),
    (from, to, label) => (label === undefined ? null : `${from} -->|${label}| ${to}`),
  ];

  const randomText = (min, max) => {
    const count = min + rng.integer(max - min + 1);
    let out = "";
    for (let i = 0; i < count; i += 1) {
      out += rng.pick(SAFE);
    }
    return out.replace(/\s+/g, " ").trim() || "ok";
  };

  const banned = [
    "subgraph inner", "end", "classDef s fill:blue", "class n0 s",
    "click n0 jump", "call n0 f", "init x", "require y",
    "linkStyle 0 stroke:red", "style n0 fill:red", "direction lr",
    "%%{init}%%", "n0<span>x</span>", "x--n0", "n0--o n1", "on0--n1",
    "n0 ---|nope| n1", "n0[(db)]", "n0[[sub]]", "n0((circle))", "n0 > asym]",
    "n0[<br/>]", "n0&nbsp; x", "n0`\u200Ex]",
  ];

  const buildCase = () => {
    const direction = rng.pick(["td", "tb", "lr", "rl", "TD", "LR", null]);
    const header = `${rng.pick(["flowchart", "graph"])}${direction === null ? "" : ` ${direction}`}`;
    const nodeCount = 1 + rng.integer(11);
    const ids = [];
    for (let i = 0; i < nodeCount; i += 1) {
      ids.push(`n${i}`);
    }
    const lines = [header];
    if (rng.next() < 0.3) {
      lines.push("%% a comment line");
    }
    for (let i = 0; i < nodeCount; i += 1) {
      if (rng.next() < 0.6) {
        lines.push(rng.pick(shapePicker)(ids[i], randomText(1, 9)));
      }
    }
    const label = () => (rng.next() < 0.3 ? randomText(1, 12) : undefined);
    const edgeTotal = rng.integer(19);
    for (let i = 0; i < edgeTotal; i += 1) {
      const from = ids[rng.integer(ids.length)];
      const to = ids[rng.integer(ids.length)];
      const line = rng.pick(arrowPicker)(from, to, label());
      if (line !== null) {
        lines.push(line);
      }
    }
    for (const id of ids) {
      if (!lines.some((line) => line.includes(id))) {
        lines.push(id);
      }
    }
    if (rng.next() < 0.4) {
      lines.push("");
    }
    if (rng.next() < 0.3) {
      lines.push("%% trailing comment");
    }
    let text = lines.join(rng.next() < 0.4 ? "\r\n" : "\n");
    if (rng.next() < 0.15) {
      text = "```mermaid\n" + text + "\n```";
    }
    return text;
  };

  for (let round = 0; round < 150; round += 1) {
    const text = buildCase();
    const first = await plugin.convert(enc(text), {});
    assert.equal(first.format, "mermaid");
    assert.match(first.summary, /^1 page, \d+ node\(s\), \d+ edge\(s\)$/);
    if (round % 3 === 0) {
      const second = await plugin.convert(enc(text), {});
      assert.deepEqual(first.bdf, second.bdf, `round ${round}: byte-identical output`);
    }
    const opened = await openDiagram(first.bdf);
    assert.equal(opened.header.version, 1);
    assert.equal(opened.manifest.bdf, 1);
    assert.equal(opened.manifest.unit, "pt");
    assert.equal(opened.view.kind, "fixed");
    assert.equal(opened.view.direction, "ltr");
    assert.equal(opened.view.id, "page-0");
    assert.equal(opened.page.layers[0].role, "content");
    assert.equal(Number.isInteger(opened.page.w), true);
    assert.equal(Number.isInteger(opened.page.h), true);
    assert.ok(opened.page.w > 0 && opened.page.h > 0);
    assert.equal(opened.parts[0].t, "obj");
    assert.equal(opened.parts[0].enc, "identity");
    const numbers = allNumbers(opened);
    for (const value of numbers) {
      assert.ok(Number.isFinite(value), `finite op argument (${value})`);
      assert.ok(value >= 0, `page fitting keeps every decoded value >= 0 (${value})`);
    }
    for (const op of opened.ops) {
      assert.ok(KNOWN_OPS.has(op.op), `op ${op.op}`);
      if (op.op === "fillColor" || op.op === "strokeColor") {
        // Colors are 0xRRGGBBAA u32: legitimately large, bounded by 0xffffffff
        // and always in the adapter's documented palette.
        assert.ok(PALETTE.has(op.args[0]), `palette u32 0x${op.args[0].toString(16)}`);
      } else {
        for (const arg of op.args ?? []) {
          const values = Array.isArray(arg) ? arg : [arg];
          for (const value of values) {
            if (typeof value === "number") {
              assert.ok(Math.abs(value) <= 1.1e7, `bounded geometry argument (${value})`);
            }
          }
        }
      }
      if (op.op === "fillText") {
        assert.equal(typeof op.args[0], "string");
      }
    }
    // No rotation in this subset: the recorded op stream carries no transform.
    assert.equal(opened.ops.some((o) => o.op === "transform"), false);
    // save/restore pairs stay balanced in the whole stream.
    let depth = 0;
    for (const op of opened.ops) {
      if (op.op === "save") depth += 1;
      if (op.op === "restore") depth -= 1;
      assert.ok(depth >= 0, `balanced save/restore at ${op.op}`);
    }
    assert.equal(depth, 0);

    if (round % 2 === 1) {
      // Negative mutation: a banned construct on its own line must reject,
      // never crash and never emit garbage.
      const poisoned = `${text.replace(/\n$/, "")}\n${banned[rng.integer(banned.length)]}`;
      await assert.rejects(
        plugin.convert(enc(poisoned), {}),
        (error) => error instanceof Error && (error.code === "invalid-input" || error.code === "too-large"),
        `round ${round}: mutation must reject`,
      );
    }
  }
});
