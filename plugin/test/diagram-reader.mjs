// Test helper: an INDEPENDENT reader for the BDF documents the diagram
// encoder produces, built on the read-only @bdfkit/core package rather than
// on anything this worktree defines. Tests assert against decoded semantics
// (manifest, object tables, recorded drawing ops), never against a magic
// header or an encoder of their own.
//
// The recorded `ops` list mirrors the BDF opset-1 op stream with references
// resolved: string indices become their text, font/paint indices stay, and
// colors are the raw 0xRRGGBBAA u32 (r = (n >>> 24) & 255, g = (n >>> 16) & 255,
// b = (n >>> 8) & 255, a = n & 255).

import {
  BufferSource,
  BdfDocument,
  NoopSink,
  decodeObject,
  parseHeader,
  walk,
} from "@bdfkit/core";

class RecordingSink extends NoopSink {
  constructor(ops) {
    super();
    this.ops = ops;
  }

  save() { this.ops.push({ op: "save", args: [] }); }
  restore() { this.ops.push({ op: "restore", args: [] }); }
  translate(x, y) { this.ops.push({ op: "translate", args: [x, y] }); }
  transform(a, b, c, d, e, f) { this.ops.push({ op: "transform", args: [a, b, c, d, e, f] }); }
  scale(x, y) { this.ops.push({ op: "scale", args: [x, y] }); }
  alpha(value) { this.ops.push({ op: "alpha", args: [value] }); }
  fillColor(value) { this.ops.push({ op: "fillColor", args: [value >>> 0] }); }
  strokeColor(value) { this.ops.push({ op: "strokeColor", args: [value >>> 0] }); }
  line(width, cap, join, miter) { this.ops.push({ op: "line", args: [width, cap, join, miter] }); }
  dash(segments, offset) { this.ops.push({ op: "dash", args: [[...segments], offset] }); }
  font(index, size) { this.ops.push({ op: "font", args: [index, size] }); }
  textStyle(align, baseline, direction, spacing) { this.ops.push({ op: "textStyle", args: [align, baseline, direction, spacing] }); }
  fillRect(x, y, w, h) { this.ops.push({ op: "fillRect", args: [x, y, w, h] }); }
  strokeRect(x, y, w, h) { this.ops.push({ op: "strokeRect", args: [x, y, w, h] }); }
  fillPath(index, rule) { this.ops.push({ op: "fillPath", args: [index, rule] }); }
  strokePath(index) { this.ops.push({ op: "strokePath", args: [index] }); }
  fillText(text, x, y, advance) { this.ops.push({ op: "fillText", args: [text, x, y, advance] }); }
  strokeText(text, x, y, advance) { this.ops.push({ op: "strokeText", args: [text, x, y, advance] }); }
  clipRect(x, y, w, h) { this.ops.push({ op: "clipRect", args: [x, y, w, h] }); }
}

///|
// Open an encoded diagram BDF file and decode its full semantic surface:
// header, manifest JSON, the single fixed view, its page and layers, the
// object part with its tables, its inline paths, and the recorded draw ops
// of every layer in draw order. Throws whatever @bdfkit/core throws on
// malformed input (BdfFormatError), so rejection tests can assert.throws.
export async function openDiagram(bytes) {
  const header = parseHeader(bytes);
  const document = await BdfDocument.open(new BufferSource(bytes));
  const manifest = document.manifest;
  if (!Array.isArray(manifest.views) || manifest.views.length < 1) {
    throw new Error("diagram-reader: manifest has no views");
  }
  const one = (what, list) => {
    if (list.length !== 1) {
      throw new Error(`diagram-reader: expected exactly 1 ${what}, got ${list.length}`);
    }
    return list[0];
  };
  const view = manifest.views[0];
  const page = one("page of the diagram view", view.pages ?? []);
  const layers = page.layers ?? [];
  if (layers.length < 1) {
    throw new Error("diagram-reader: the page has no layers");
  }
  const ops = [];
  const objects = [];
  const paths = [];
  for (const layer of layers) {
    const hash = layer.obj;
    const entry = document.entry(hash);
    const object = decodeObject(await document.part(hash));
    objects.push({ hash, entry, object });
    for (const path of object.paths) {
      if (path.inline) {
        paths.push({ verbs: path.inline.verbs, args: path.inline.args });
      } else {
        paths.push({ hash: path.hash, index: path.index });
      }
    }
    walk(object, new RecordingSink(ops));
  }
  return {
    header,
    manifest,
    view,
    page,
    parts: manifest.parts,
    object: objects[0].object,
    objects,
    paths,
    ops,
  };
}
