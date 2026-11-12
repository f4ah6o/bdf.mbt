// Shared-module tests for the multi-page, embedded-image diagram encoder
// (encodeDiagramDocument of plugin/src/diagram-bdf.js). Like their
// single-diagram counterparts they verify decoded semantics through the
// INDEPENDENT reader (plugin/test/diagram-reader.mjs on @bdfkit/core),
// never the encoder's own bytes: page order and sizes, real per-part
// relative offsets, genuine img parts whose bytes are the actually
// supplied rasters, content-hash deduplication, object image tables that
// list those parts, save/restore isolation of image ops, and the bounded,
// deterministic, non-mutating resource validation.
//
// All raster fixtures are synthesized in-process
// (plugin/test/synthetic-image.mjs) from the PNG/JPEG specifications; no
// real files or private formats are involved.

import assert from "node:assert/strict";
import { test } from "node:test";
import { createHash } from "node:crypto";

import {
  MAX_DOCUMENT_PRIMITIVES,
  MAX_IMAGE_BYTES,
  MAX_IMAGE_RESOURCES,
  MAX_IMAGE_SIDE,
  MAX_PAGES,
  MAX_PRIMITIVES,
  MAX_TOTAL_IMAGE_BYTES,
  encodeDiagram,
  encodeDiagramDocument,
  DiagramEncodeError,
} from "../src/diagram-bdf.js";
import { openDiagramDocument } from "./diagram-reader.mjs";
import { syntheticJpeg, syntheticPng, syntheticPngHeader, syntheticPngPadded } from "./synthetic-image.mjs";
import { mulberry32 } from "./helpers.mjs";

const RED = [220, 30, 30];
const GREEN = [20, 180, 90];
const BLACK = { r: 0, g: 0, b: 0, a: 255 };

const redPng = () => syntheticPng(8, 8, RED);
const greenPng = () => syntheticPng(8, 8, GREEN);

function opsOf(ops, name) {
  return ops.filter(op => op.op === name);
}

const failsWith = (code, promise, what) => assert.rejects(
  promise,
  error => error instanceof DiagramEncodeError && error.code === code,
  what,
);

// The part region of a single-file BDF byte string starts right after the
// manifest; an entry's off is relative to that region start, exactly how
// core/container.mbt reads parts back.
const partRegionStart = (bytes, header) => header.manifestOff + header.manifestLen;

function documentOf(pages, images) {
  return { source: "smoke", title: "", pages, images };
}

test("encodeDiagramDocument emits a genuine 2-page BDF the core reader opens", async () => {
  const bytes = await encodeDiagramDocument(documentOf([
    { width: 300, height: 200, primitives: [{ kind: "rect", x: 10, y: 10, w: 40, h: 20, fill: BLACK }] },
    { width: 200, height: 300, primitives: [{ kind: "text", x: 5, y: 5, text: "page two", fontSize: 12 }] },
  ]));
  const opened = await openDiagramDocument(bytes);
  assert.equal(opened.header.version, 1);
  assert.equal(opened.header.flags, 0);
  assert.equal(opened.header.manifestEnc, "identity");
  assert.equal(opened.view.id, "pages");
  assert.equal(opened.view.kind, "fixed");
  assert.equal(opened.view.title, "");
  assert.equal(opened.pages.length, 2);
  assert.equal(opened.pages[0].page.w, 300);
  assert.equal(opened.pages[0].page.h, 200);
  assert.equal(opened.pages[1].page.w, 200);
  assert.equal(opened.pages[1].page.h, 300);
  for (const page of opened.pages) {
    assert.deepEqual(page.page.layers.map(layer => layer.role), ["content"]);
  }
  assert.equal(opsOf(opened.pages[0].ops, "fillRect").length, 1);
  assert.equal(opsOf(opened.pages[1].ops, "fillText").length, 1);
  // one obj part per page, no img parts
  assert.equal(opened.parts.length, 2);
  for (const entry of opened.parts) {
    assert.equal(entry.t, "obj");
    assert.equal(entry.enc, "identity");
  }
  assert.equal(new Set(opened.pages.map(page => page.objects[0].hash)).size, 2, "the two pages are distinct objects");
});

test("embedded images become real img parts with actual bytes, hashes and relative offsets", async () => {
  const red = redPng();
  const green = greenPng();
  const bytes = await encodeDiagramDocument(documentOf(
    [
      { width: 200, height: 100, primitives: [
        { kind: "image", image: "red", x: 10, y: 10, w: 80, h: 60 },
        { kind: "image", image: "red2", x: 10, y: 75, w: 20, h: 10 },
      ] },
      { width: 200, height: 100, primitives: [
        { kind: "image", image: "green", x: 0, y: 0, w: 50, h: 50 },
      ] },
    ],
    [
      { id: "red", data: red },
      { id: "red2", data: red.slice() }, // the same content under a second id
      { id: "green", data: green },
    ],
  ));
  const opened = await openDiagramDocument(bytes);
  const imgEntries = opened.parts.filter(entry => entry.t === "img");
  const objEntries = opened.parts.filter(entry => entry.t === "obj");
  assert.equal(objEntries.length, 2);
  // content deduplication: three ids, two distinct rasters, two img parts
  assert.equal(imgEntries.length, 2);
  // every part name is the real SHA-256 prefix of the bytes at its offset,
  // the offsets are packed from zero, and identity stores len == size
  const start = partRegionStart(bytes, opened.header);
  let off = 0;
  const storedImages = [];
  for (const entry of opened.parts) {
    assert.equal(entry.off, off, `off of ${entry.h}`);
    const stored = bytes.subarray(start + entry.off, start + entry.off + entry.len);
    assert.equal(createHash("sha256").update(stored).digest("hex").slice(0, 32), entry.h, "hash of the stored bytes");
    assert.equal(entry.size, entry.len, "identity encoding stores len == size");
    if (entry.t === "img") {
      storedImages.push(stored);
    }
    off += entry.len;
  }
  assert.equal(start + off, bytes.length, "the file ends exactly after the last part");
  const unique = [...new Map([[red, "red"], [green, "green"]]).keys()];
  assert.equal(storedImages.length, unique.length, "one img part per unique content");
  for (const stored of storedImages) {
    assert.ok(unique.some(source => stored.length === source.length),
      "every stored img part is one of the supplied rasters");
  }
  // the resolved part bytes are the actually supplied rasters, both present
  const seenColors = [];
  for (const entry of imgEntries) {
    const part = Buffer.from(await opened.part(entry.h));
    if (part.equals(red)) {
      seenColors.push("red");
    } else if (part.equals(green)) {
      seenColors.push("green");
    } else {
      seenColors.push("neither");
    }
  }
  assert.deepEqual(seenColors.sort(), ["green", "red"], "img parts are the supplied rasters");
  // object image tables list the actual img part hashes: the referenced
  // subset per page, deduplicated per content
  const redHash = createHash("sha256").update(red).digest("hex").slice(0, 32);
  const greenHash = createHash("sha256").update(green).digest("hex").slice(0, 32);
  assert.equal(new Set(imgEntries.map(entry => entry.h)).size, imgEntries.length, "img parts are distinct");
  assert.ok(imgEntries.some(entry => entry.h === redHash), "the red raster is an img part");
  assert.ok(imgEntries.some(entry => entry.h === greenHash), "the green raster is an img part");
  assert.deepEqual(opened.pages[0].objects[0].object.images, [redHash]);
  assert.deepEqual(opened.pages[1].objects[0].object.images, [greenHash]);
});

test("image ops index the object image table and stay save/restore isolated", async () => {
  const opened = await openDiagramDocument(await encodeDiagramDocument(documentOf(
    [{ width: 400, height: 400, primitives: [
      { kind: "image", image: "a", x: 10, y: 20, w: 100, h: 50, opacity: 0.5, angle: Math.PI / 2, pivot: [0, 0] },
      { kind: "image", image: "a", x: 260, y: 280, w: 40, h: 20 },
      { kind: "rect", x: 0, y: 0, w: 5, h: 5, fill: BLACK },
    ] }],
    [{ id: "a", data: redPng() }],
  )));
  const ops = opened.pages[0].ops;
  const images = opsOf(ops, "image");
  assert.equal(images.length, 2);
  // the same content twice resolves to one object-table index
  assert.deepEqual(images.map(op => op.args[0]), [0, 0]);
  assert.deepEqual(images[0].args.slice(1), [10, 20, 100, 50]);
  assert.deepEqual(images[1].args.slice(1), [260, 280, 40, 20]);
  // opacity and rotation live inside the primitive's save/restore block
  const names = ops.map(op => op.op);
  const saveAt = names.indexOf("save");
  const firstImageAt = names.indexOf("image");
  const restoreAt = names.indexOf("restore");
  assert.ok(saveAt >= 0 && restoreAt > saveAt, names.join(","));
  assert.ok(names.indexOf("alpha") > saveAt && names.indexOf("alpha") < firstImageAt, "alpha inside the block");
  assert.ok(names.indexOf("transform") > saveAt && names.indexOf("transform") < firstImageAt, "transform inside the block");
  assert.ok(firstImageAt < restoreAt, "the image op draws inside the block");
  const transform = opsOf(ops, "transform")[0];
  for (const [at, expected] of [[0, 0], [1, 1], [2, -1], [3, 0], [4, 0], [5, 0]]) {
    assert.ok(Math.abs(transform.args[at] - expected) < 1e-6, `${at}: ${transform.args[at]}`);
  }
  // save/restore balance over the whole page (every visible primitive pairs)
  let depth = 0;
  for (const op of ops) {
    if (op.op === "save") depth += 1;
    if (op.op === "restore") depth -= 1;
    assert.ok(depth >= 0, "restore before save");
  }
  assert.equal(depth, 0);
  // the pages' extent: the rotated image grows a rotated AABB (100x50 at
  // (10,20) rotated 90 degrees about (0,0) maps to x in [-70,-20], y in
  // [10,110]), unioned with the mirrored image (260..300, 280..300) and
  // the little rect (0..5, 0..5)
  const bbox = opened.pages[0].objects[0].object.bbox;
  const expected = { x: -70, y: 0, w: 300 - (-70), h: 300 };
  for (const key of Object.keys(expected)) {
    assert.ok(Math.abs(bbox[key] - expected[key]) < 1e-3, `${key}: ${JSON.stringify(bbox)}`);
  }
});

test("JPEG resources are accepted when structurally complete and decodable", async () => {
  const jpeg = syntheticJpeg(16, 16); // a genuine baseline JPEG: PIL and Chromium both decode it
  const pages = () => [{ width: 320, height: 240, primitives: [{ kind: "image", image: "j", x: 0, y: 0, w: 320, h: 240 }] }];
  const opened = await openDiagramDocument(await encodeDiagramDocument(documentOf(pages(), [{ id: "j", data: jpeg }])));
  const entry = opened.parts.find(part => part.t === "img");
  assert.equal(entry.len, jpeg.length);
  assert.deepEqual(new Uint8Array(await opened.part(entry.h)), jpeg);
  assert.deepEqual(opened.pages[0].objects[0].object.images, [entry.h]);
  // ArrayBuffer data encodes byte-identically to Uint8Array data
  const asBuffer = await encodeDiagramDocument(documentOf(pages(), [{ id: "j", data: jpeg.slice().buffer }]));
  const asArray = await encodeDiagramDocument(documentOf(pages(), [{ id: "j", data: jpeg }]));
  assert.deepEqual(asBuffer, asArray);
  // every mutation of the structure is rejected
  const noEoi = jpeg.subarray(0, jpeg.length - 2);
  const noScan = (() => {
    const at = jpeg.findIndex((byte, i) => byte === 0xda && jpeg[i - 1] === 0xff);
    return Uint8Array.from([...jpeg.subarray(0, at - 2), ...jpeg.subarray(jpeg.length - 2)]);
  })();
  const truncatedScan = (() => { const at = jpeg.length - 20; return jpeg.subarray(0, at); })();
  const segmentOverrun = (() => {
    const copy = jpeg.slice();
    const at = copy.findIndex((byte, i) => byte === 0xdb && copy[i - 1] === 0xff);
    new DataView(copy.buffer).setUint16(at + 2, 9);
    return copy;
  })();
  for (const [what, data] of [
    ["EOI stripped", noEoi],
    ["scan stripped (SOF + EOI only)", noScan],
    ["truncated inside the scan", truncatedScan],
    ["segment length pointing past the end", segmentOverrun],
  ]) {
    await failsWith("invalid-input", encodeDiagramDocument(documentOf(pages(), [{ id: "j", data }])), what);
  }
});

test("reference integrity holds both ways", async () => {
  const pageWith = id => ({ width: 10, height: 10, primitives: [{ kind: "image", image: id, x: 0, y: 0, w: 5, h: 5 }] });
  const base = documentOf([pageWith("a")], [{ id: "a", data: redPng() }]);
  // a reference to an unknown resource
  await failsWith("invalid-input", encodeDiagramDocument(documentOf([pageWith("nope")], base.images)), "unknown reference");
  // a defined resource no page draws
  await failsWith(
    "invalid-input",
    encodeDiagramDocument(documentOf(base.pages, [...base.images, { id: "spare", data: greenPng() }])),
    "unreferenced resource",
  );
  // duplicate ids
  await failsWith(
    "invalid-input",
    encodeDiagramDocument(documentOf(base.pages, [...base.images, { id: "a", data: greenPng() }])),
    "duplicate id",
  );
  // nonpositive drawn rectangles are rejected: the canvas image op has no
  // mirroring, so such a primitive would silently draw nothing
  for (const bad of [[0, 5], [5, 0], [-4, 6], [6, -4]]) {
    await failsWith(
      "invalid-input",
      encodeDiagramDocument(documentOf(
        [{ width: 20, height: 20, primitives: [{ kind: "image", image: "a", x: 0, y: 0, w: bad[0], h: bad[1] }] }],
        [{ id: "a", data: redPng() }],
      )),
      `nonpositive image dims ${JSON.stringify(bad)}`,
    );
  }
  // the single-diagram entry point still rejects image primitives outright
  await assert.rejects(encodeDiagram({
    width: 10, height: 10, source: "smoke", title: "",
    primitives: [{ kind: "image", image: "a", x: 0, y: 0, w: 5, h: 5 }],
  }), error => error instanceof DiagramEncodeError && /unknown primitive kind/.test(error.message));
});

test("resource validation: only bounded actual PNG or JPEG bytes pass", async () => {
  const badResources = [
    ["string URL", "https://example.invalid/a.png", "invalid-input"],
    ["bare string", "hello", "invalid-input"],
    ["plain number", 5, "invalid-input"],
    ["svg text", new TextEncoder().encode("<svg xmlns=\"http://www.w3.org/2000/svg\"/>"), "invalid-input"],
    ["gif", new Uint8Array([0x47, 0x49, 0x46, 0x38, 0x37, 0x61, 1, 0, 1, 0, 0, 0]), "invalid-input"],
    ["bmp", new Uint8Array([0x42, 0x4d, ...new Uint8Array(30)]), "invalid-input"],
    ["empty", new Uint8Array(0), "invalid-input"],
    ["truncated png", syntheticPng(4, 4).subarray(0, 24), "invalid-input"],
    ["png idat truncated", syntheticPng(4, 4).subarray(0, syntheticPng(4, 4).length - 3), "invalid-input"],
    ["png without IHDR", (() => { const b = syntheticPngHeader(2, 2); b.set([0, 0, 0, 0], 12); return b; })(), "invalid-input"],
    ["png header only (no IDAT, no IEND)", syntheticPngHeader(2, 2), "invalid-input"],
    ["png with trailing bytes after IEND", new Uint8Array([...syntheticPng(2, 2), 1, 2, 3]), "invalid-input"],
    ["png chunk length pointing past the end", (() => { const b = syntheticPng(2, 2); new DataView(b.buffer).setUint32(8, 99999); return b; })(), "invalid-input"],
    ["png palette image without PLTE", (() => { const b = syntheticPng(2, 2); b[8 + 16 + 1] = 3; return b; })(), "invalid-input"],
    ["png unknown critical chunk", (() => {
      const b = syntheticPng(2, 2);
      const at = b.findIndex((_, i) => b[i] === 0x49 && b[i + 1] === 0x44 && b[i + 2] === 0x41 && b[i + 3] === 0x54);
      b.set([0x4b, 0x44, 0x41, 0x54], at); // "KDAT": critical, unregistered
      return b;
    })(), "invalid-input"],
    ["zero width png", syntheticPngHeader(0, 2), "invalid-input"],
    ["side past the cap", syntheticPngHeader(MAX_IMAGE_SIDE + 1, 2), "too-large"],
    ["pixels past the product cap", syntheticPngHeader(5000, 5000), "too-large"],
    ["bytes past the per-image cap", (() => { const b = new Uint8Array(MAX_IMAGE_BYTES + 1); b.set(syntheticPngPadded(200)); return b; })(), "too-large"],
    ["jpeg without a frame header", new Uint8Array([0xff, 0xd8, 0xff, 0xd9, 0, 0]), "invalid-input"],
    ["jpeg segment header truncated", syntheticJpeg(8, 8).subarray(0, 30), "invalid-input"],
  ];
  for (const [what, data, code] of badResources) {
    await failsWith(
      code,
      encodeDiagramDocument(documentOf(
        [{ width: 10, height: 10, primitives: [{ kind: "image", image: "a", x: 0, y: 0, w: 5, h: 5 }] }],
        [{ id: "a", data }],
      )),
      what,
    );
  }
  // images entry shapes (null means "no images" and is accepted)
  for (const images of ["image.png", [{ id: "a" }], [{ data: redPng() }], [{ id: "a", data: null }]]) {
    await failsWith("invalid-input", encodeDiagramDocument(documentOf([{ width: 10, height: 10, primitives: [] }], images)), "entry shape");
  }
  await assert.doesNotReject(encodeDiagramDocument(documentOf([{ width: 10, height: 10, primitives: [] }], null)));
});

test("limits: pages, primitives, resources and bytes are capped at the boundary", async () => {
  // pages: at cap accepted (one shared empty object part), one past fails
  const emptyPage = () => ({ width: 10, height: 10, primitives: [] });
  const atCap = await openDiagramDocument(await encodeDiagramDocument(documentOf(Array.from({ length: MAX_PAGES }, emptyPage))));
  assert.equal(atCap.pages.length, MAX_PAGES);
  // identical empty pages dedupe to a single object part
  assert.equal(atCap.parts.filter(entry => entry.t === "obj").length, 1);
  await failsWith("too-large", encodeDiagramDocument(documentOf(Array.from({ length: MAX_PAGES + 1 }, emptyPage))), "pages past the cap");
  await failsWith("too-large", encodeDiagramDocument(documentOf([])), "empty pages");
  // per-page primitive cap (the single-diagram tests cover the boundary too)
  const fat = () => ({ width: 10, height: 10, primitives: Array.from({ length: MAX_PRIMITIVES + 1 }, () => ({ kind: "rect", x: 0, y: 0, w: 1, h: 1 })) });
  await failsWith("too-large", encodeDiagramDocument(documentOf([fat()])), "per-page primitives");
  // document-wide primitive cap: exactly at the cap goes through
  const pageOf = n => ({ width: 10, height: 10, primitives: Array.from({ length: n }, () => ({ kind: "rect", x: 0, y: 0, w: 1, h: 1 })) });
  const docPages = [];
  let remaining = MAX_DOCUMENT_PRIMITIVES;
  while (remaining > 0) {
    const take = Math.min(remaining, MAX_PRIMITIVES);
    docPages.push(pageOf(take));
    remaining -= take;
  }
  await encodeDiagramDocument(documentOf(docPages));
  await failsWith("too-large", encodeDiagramDocument(documentOf([
    ...docPages,
    { width: 10, height: 10, primitives: [{ kind: "rect", x: 0, y: 0, w: 1, h: 1, fill: BLACK }] },
  ])), "document-wide primitives one past the cap");
  // resource count cap
  const imagesAt = count => Array.from({ length: count }, (_, i) => ({
    id: `i${i}`,
    data: syntheticPng(2, 2, [i & 255, (i >> 2) & 255, (i >> 4) & 255]),
  }));
  const pageDrawing = ids => ({ width: 10, height: 10, primitives: ids.map(id => ({ kind: "image", image: id, x: 0, y: 0, w: 2, h: 2 })) });
  const atCapImages = imagesAt(MAX_IMAGE_RESOURCES);
  await encodeDiagramDocument(documentOf([pageDrawing(atCapImages.map(image => image.id))], atCapImages));
  const pastImages = imagesAt(MAX_IMAGE_RESOURCES + 1);
  await failsWith("too-large", encodeDiagramDocument(documentOf([pageDrawing(pastImages.map(image => image.id))], pastImages)), "resources past the cap");
  // unique image bytes cap: every 4 MiB raster is unique, so nine exceed 32 MiB
  const fatImages = Array.from({ length: Math.floor(MAX_TOTAL_IMAGE_BYTES / MAX_IMAGE_BYTES) + 1 }, (_, i) => ({
    id: `f${i}`,
    data: syntheticPngPadded(MAX_IMAGE_BYTES, i),
  }));
  await failsWith(
    "too-large",
    encodeDiagramDocument(documentOf([pageDrawing(fatImages.map(image => image.id))], fatImages)),
    "total image bytes past the cap",
  );
});

test("encoding is deterministic and the input is never mutated, frozen input included", async () => {
  const makeInput = () => ({
    source: "smoke", title: "deterministic",
    pages: [
      { width: 200, height: 150, primitives: [
        { kind: "image", image: "a", x: 10, y: 10, w: 40, h: 30, opacity: 0.8, angle: 0.2 },
        { kind: "rect", x: 0, y: 0, w: 5, h: 5, fill: BLACK },
      ] },
      { width: 100, height: 100, primitives: [{ kind: "text", x: 4, y: 4, text: "page 2", fontSize: 9 }] },
    ],
    images: [
      { id: "a", data: redPng() },
      { id: "b", data: greenPng() }, // referenced on no page: must fail below
    ],
  });
  const drawn = structuredClone(makeInput());
  drawn.pages[0].primitives.push({ kind: "image", image: "b", x: 60, y: 60, w: 9, h: 9 });
  // a byte-level snapshot the typed arrays survive (JSON drops them)
  const snapshot = snapshotBytes(drawn);
  const first = await encodeDiagramDocument(drawn);
  const second = await encodeDiagramDocument(drawn);
  assert.deepEqual(first, second);
  assert.equal(snapshotBytes(drawn), snapshot, "the encoder never mutates its input");
  const frozen = structuredClone(drawn);
  deepFreeze(frozen);
  await assert.doesNotReject(encodeDiagramDocument(frozen));
  // and the unreferenced variant of the same input is rejected cleanly
  await failsWith("invalid-input", encodeDiagramDocument(makeInput()), "unreferenced image");
});

function deepFreeze(value) {
  if (value === null || typeof value !== "object" || ArrayBuffer.isView(value) || value instanceof ArrayBuffer) {
    // typed arrays cannot be Object.freeze'd; the objects around them are
    return value;
  }
  for (const key of Object.getOwnPropertyNames(value)) {
    deepFreeze(value[key]);
  }
  Object.freeze(value);
  return value;
}

// A deterministic byte-level fingerprint of the input: JSON with typed
// arrays normalized to base64 (JSON.stringify alone turns them into plain
// objects, so it cannot witness raster mutation).
function snapshotBytes(input) {
  const normalize = value => {
    if (value instanceof Uint8Array) {
      return Buffer.from(value).toString("base64");
    }
    if (Array.isArray(value)) {
      return value.map(normalize);
    }
    if (value !== null && typeof value === "object") {
      return Object.fromEntries(Object.keys(value).sort().map(key => [key, normalize(value[key])]));
    }
    return value;
  };
  return JSON.stringify(normalize(input));
}

test("property loop: random multi-page documents keep every invariant (60 cases)", async () => {
  const rng = mulberry32(0x0bdfd0c);
  for (let round = 0; round < 60; round += 1) {
    const pageCount = 1 + rng.integer(4);
    const red = redPng();
    const green = greenPng();
    const jpeg = syntheticJpeg(8 + rng.integer(8), 8 + rng.integer(8));
    const sources = [
      { id: "red", data: red },
      { id: "green", data: green },
      { id: "jpeg", data: jpeg },
    ];
    const drawing = sources.filter(() => rng.integer(2) === 1);
    if (drawing.length === 0) {
      drawing.push(sources[0]);
    }
    const pages = [];
    for (let p = 0; p < pageCount; p += 1) {
      const primitives = [];
      const imageCount = rng.integer(4);
      for (let i = 0; i < imageCount; i += 1) {
        primitives.push({
          kind: "image",
          image: drawing[rng.integer(drawing.length)].id,
          x: rng.integer(40), y: rng.integer(30),
          w: 10 + rng.integer(40), h: 10 + rng.integer(40),
          ...(rng.integer(3) === 0 ? { opacity: rng.next() } : {}),
          ...(rng.integer(4) === 0 ? { angle: rng.next() * Math.PI } : {}),
        });
      }
      const rects = rng.integer(3);
      for (let i = 0; i < rects; i += 1) {
        primitives.push({ kind: "rect", x: rng.integer(50), y: rng.integer(50), w: 10 + rng.integer(30), h: 10 + rng.integer(30), fill: BLACK });
      }
      const texts = rng.integer(2);
      for (let i = 0; i < texts; i += 1) {
        primitives.push({ kind: "text", x: rng.integer(60), y: rng.integer(40), text: `p${p}t${i}`, fontSize: 8 + rng.integer(10) });
      }
      if (primitives.length === 0) {
        primitives.push({ kind: "rect", x: 1, y: 1, w: 2, h: 2, fill: BLACK });
      }
      pages.push({ width: 100 + rng.integer(200), height: 80 + rng.integer(150), primitives });
    }
    const usedIds = new Set(pages.flatMap(page => page.primitives)
      .filter(prim => prim.kind === "image")
      .map(prim => prim.image));
    const drawn = sources.filter(source => usedIds.has(source.id));
    const input = documentOf(pages, drawn.map(source => ({ id: source.id, data: source.data })));
    const bytes = await encodeDiagramDocument(input);
    const opened = await openDiagramDocument(bytes);
    assert.equal(opened.pages.length, pageCount, "page count");
    // per-page invariants
    for (let p = 0; p < pageCount; p += 1) {
      assert.equal(opened.pages[p].page.w, pages[p].width, "page width");
      assert.equal(opened.pages[p].page.h, pages[p].height, "page height");
      const kinds = primitive => pages[p].primitives.filter(item => item.kind === primitive).length;
      assert.equal(opsOf(opened.pages[p].ops, "image").length, kinds("image"), "image count");
      assert.equal(opsOf(opened.pages[p].ops, "fillRect").length, kinds("rect"), "rect count");
      assert.equal(opsOf(opened.pages[p].ops, "fillText").length, kinds("text"), "text count");
      const visible = pages[p].primitives.length;
      assert.equal(opsOf(opened.pages[p].ops, "save").length, visible, "save count");
      assert.equal(opsOf(opened.pages[p].ops, "restore").length, visible, "restore count");
      let depth = 0;
      for (const op of opened.pages[p].ops) {
        if (op.op === "save") depth += 1;
        if (op.op === "restore") depth -= 1;
        assert.ok(depth >= 0, "restore before save");
      }
      assert.equal(depth, 0, "unbalanced save/restore");
      // every image op references a real table index that names a real img part
      for (const op of opsOf(opened.pages[p].ops, "image")) {
        const table = opened.pages[p].objects[0].object.images;
        assert.ok(op.args[0] < table.length, "image index out of range");
        const entry = opened.parts.find(part => part.h === table[op.args[0]]);
        assert.ok(entry !== undefined, "image table does not name a manifest part");
        assert.equal(entry.t, "img");
      }
    }
    // document invariants: packed relative offsets, real hashes, no duplicates
    const start = partRegionStart(bytes, opened.header);
    const hashes = new Set();
    let off = 0;
    for (const entry of opened.parts) {
      assert.equal(entry.off, off, "part offset");
      assert.ok(!hashes.has(entry.h), "duplicate part hash");
      hashes.add(entry.h);
      const stored = bytes.subarray(start + entry.off, start + entry.off + entry.len);
      assert.equal(createHash("sha256").update(stored).digest("hex").slice(0, 32), entry.h, "part hash");
      off += entry.len;
    }
    assert.equal(start + off, bytes.length, "file length");
    // one img part per unique drawn raster
    const imgEntries = opened.parts.filter(entry => entry.t === "img");
    const uniqueDrawn = new Set(input.images.map(image => createHash("sha256").update(image.data).digest("hex"))).size;
    assert.equal(imgEntries.length, uniqueDrawn, "img part count equals the unique drawn content count");
    // deterministic re-encode of identical input
    assert.deepEqual(await encodeDiagramDocument(input), bytes, "byte-identical re-encode");
  }
});

test("rejected documents never produce output: malformed inputs fail with named errors", async () => {
  const bad = [
    { source: "Smoke", title: "", pages: [{ width: 10, height: 10, primitives: [] }] },
    { source: "smoke", title: "", pages: [{ width: 0, height: 10, primitives: [] }] },
    { source: "smoke", title: "", pages: [{ width: 10, height: 10, primitives: "no" }] },
    { source: "smoke", title: "", pages: [{ width: 10, height: 10, primitives: [{ kind: "ellipse" }] }] },
    { source: "smoke", title: "", pages: "none" },
    null,
    "string",
  ];
  for (const input of bad) {
    await assert.rejects(encodeDiagramDocument(input), DiagramEncodeError);
  }
});

// Progressive JPEG has multiple SOS markers, each validated independently.
import { syntheticProgressiveJpeg } from "./synthetic-image.mjs";
test("accepts a genuine progressive JPEG with multiple scans", async () => {
  const bytes = await encodeDiagramDocument({source:"test", pages:[{width:40,height:40,primitives:[{kind:"image",image:"p",x:0,y:0,w:16,h:16}]}],images:[{id:"p",data:syntheticProgressiveJpeg()}]});
  assert.ok(bytes.length > 500);
});
