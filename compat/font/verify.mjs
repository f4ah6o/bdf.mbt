import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { BdfDocument, BufferSource } from '@bdfkit/core';
import { load_font, glyph, advance, metrics, geometry, drawing_tile, csv_document, csv_warnings, canvas_program } from '../../_build/js/debug/build/compat/font/font.js';

const fixtures = JSON.parse(await readFile(new URL('./upstream.json', import.meta.url)));
for (const expected of fixtures) {
  const data = await readFile(new URL('../../' + expected.file, import.meta.url));
  const font = load_font(data, expected.index);
  const actual = JSON.parse(metrics(font));
  for (const key of ['count', 'upem', 'cff', 'ascent', 'descent', 'underlinePos', 'underlineThick', 'capHeight', 'embeddable', 'subsettable', 'family', 'style', 'weight', 'italic', 'monospace', 'math']) {
    assert.equal(actual[key], expected[key], `${expected.file}:${expected.index} ${key}`);
  }
  const mapped = Buffer.alloc(0x110000 * 2);
  for (let code = 0; code < 0x110000; code++) mapped.writeUInt16BE(glyph(font, code), code * 2);
  assert.equal(createHash('sha256').update(mapped).digest('hex'), expected.cmapHash, expected.file + ' Unicode map');
  const count = Math.min(expected.count + 3, 65536);
  const widths = Buffer.alloc(count * 2);
  for (let id = 0; id < count; id++) widths.writeUInt16BE(advance(font, id), id * 2);
  assert.equal(createHash('sha256').update(widths).digest('hex'), expected.advanceHash, expected.file + ' advances');
}
console.log(`${fixtures.length} TrueType, OpenType and collection faces match upstream metrics and Unicode maps.`);

const synthetic = JSON.parse(await readFile(new URL('./synthetic.json', import.meta.url)));
const cmapHashes = JSON.parse(await readFile(new URL('./rebuild.json', import.meta.url)));
for (const [index, expected] of synthetic.entries()) {
  const font = load_font(Buffer.from(expected.data, 'base64'), 0);
  const mapped = Buffer.alloc(0x110000 * 2);
  for (let code = 0; code < 0x110000; code++) mapped.writeUInt16BE(glyph(font, code), code * 2);
  assert.equal(createHash('sha256').update(mapped).digest('hex'), expected.cmapHash, `synthetic cmap ${index}`);
  assert.deepEqual(JSON.parse(metrics(font)), {
    count: 300, upem: 1000, cff: false, ascent: 0.8, descent: 0.25,
    underlinePos: -0.1, underlineThick: 0.05, capHeight: 0.7, embeddable: true, subsettable: true,
    family: '', style: 'Regular', weight: 400, italic: false, monospace: false, math: false,
  });
  assert.deepEqual([0, 1, 2, 3, 4, 299].map(id => advance(font, id)), [400, 500, 600, 700, 700, 700]);
  const program = Buffer.from(canvas_program(font));
  let cmap;
  for (let i = 0; i < program.readUInt16BE(4); i++) {
    const rec = 12 + 16 * i;
    if (program.toString('ascii', rec, rec + 4) === 'cmap') {
      const offset = program.readUInt32BE(rec + 8), length = program.readUInt32BE(rec + 12);
      cmap = program.subarray(offset, offset + length);
    }
  }
  assert.ok(cmap, `synthetic cmap ${index} missing`);
  assert.equal(createHash('sha256').update(cmap).digest('hex'), cmapHashes[index], `synthetic rebuilt cmap ${index}`);
}
assert.throws(() => load_font(new Uint8Array(11), 0));
assert.throws(() => load_font(new Uint8Array(12), 0));
const fontData = await readFile(new URL('../../compat/visual/synthetic.ttf', import.meta.url));
assert.throws(() => load_font(fontData, 1));
const collection = await readFile(new URL('./fixtures/bold.ttc', import.meta.url));
assert.throws(() => load_font(collection, 100));
assert.throws(() => load_font(collection.subarray(0, 12), 0));
assert.throws(() => csv_document(Buffer.from('a,b'), collection, 0, -1));
assert.throws(() => csv_document(Buffer.from('a,b'), collection, 0, 2));
assert.throws(() => csv_document(Buffer.from('a,b'), fontData, 0, 1));
console.log(`${synthetic.length} synthetic Unicode maps and malformed font boundaries match upstream.`);

const defaultFonts = JSON.parse(await readFile(new URL('./defaults.json', import.meta.url)));
for (const [index, sample] of defaultFonts.entries()) {
  const rebuilt = Buffer.from(canvas_program(load_font(Buffer.from(sample.data, 'base64'), 0)));
  assert.equal(createHash('sha256').update(rebuilt).digest('hex'), sample.sha256, `missing font tables ${index}`);
  assert.deepEqual(rebuilt, Buffer.from(sample.program, 'base64'), `missing font tables ${index} bytes`);
}
console.log(`${defaultFonts.length} fonts with missing or truncated tables rebuild identically to upstream.`);

const geometries = JSON.parse(await readFile(new URL('./geometry.json', import.meta.url)));
for (const sample of geometries) {
  const data = await readFile(new URL('../../' + sample.file, import.meta.url));
  const actual = JSON.parse(geometry(load_font(data, 0), sample.scenario));
  assert.deepEqual(actual.cols, sample.cols, `${sample.file}:${sample.scenario} columns`);
  assert.deepEqual(actual.rows, sample.rows, `${sample.file}:${sample.scenario} rows`);
  assert.equal(actual.frozen, sample.freeze?.rows ?? 0, `${sample.file}:${sample.scenario} frozen rows`);
}
console.log(`${geometries.length} single-font grid geometries match upstream.`);

const drawings = JSON.parse(await readFile(new URL('./drawing.json', import.meta.url)));
for (const sample of drawings) {
  const data = await readFile(new URL('../../' + sample.file, import.meta.url));
  const font = load_font(data, 0);
  for (const [index, part] of sample.parts.entries()) {
    assert.deepEqual(Buffer.from(drawing_tile(font, sample.scenario, sample.fontHash, index)), Buffer.from(part.data, 'base64'), `${sample.file}:${sample.scenario} drawing ${index}`);
  }
}
console.log(`${drawings.length} single-font grid drawings match upstream object bytes.`);

const conversions = JSON.parse(await readFile(new URL('./csv.json', import.meta.url)));
for (const sample of conversions) {
  const font = await readFile(new URL('../../' + sample.file, import.meta.url));
  const input = Buffer.from(sample.input);
  const doc = await BdfDocument.open(new BufferSource(csv_document(input, font, sample.scenario, sample.index ?? 0)));
  const label = `${sample.file}:${sample.index ?? 0}:${sample.scenario}`;
  assert.deepEqual(JSON.parse(csv_warnings(input, font, sample.scenario, sample.index ?? 0)), sample.warnings ?? [], label + ' warnings');
  const embedded = doc.manifest.parts.find(part => part.t === 'font');
  assert.equal(embedded?.h ?? '', sample.fontHash, label + ' font hash');
  if (embedded) {
    const program = Buffer.from(await doc.part(embedded.h));
    if (sample.bdf) {
      const baseline = await BdfDocument.open(new BufferSource(Buffer.from(sample.bdf, 'base64')));
      assert.deepEqual(program, Buffer.from(await baseline.part(sample.fontHash)), label + ' font bytes');
    }
    const tableHashes = {};
    const n = program.readUInt16BE(4);
    for (let i = 0; i < n; i++) {
      const rec = 12 + i * 16;
      const tag = program.toString('ascii', rec, rec + 4);
      if (!(tag in sample.fontTables)) continue;
      const offset = program.readUInt32BE(rec + 8), length = program.readUInt32BE(rec + 12);
      const bytes = Buffer.from(program.subarray(offset, offset + length));
      if (tag === 'head' && bytes.length >= 12) bytes.fill(0, 8, 12);
      tableHashes[tag] = createHash('sha256').update(bytes).digest('hex');
    }
    assert.deepEqual(tableHashes, sample.fontTables, label + ' font tables');
    const original = load_font(font, sample.index ?? 0), rebuilt = load_font(program, 0);
    const originalMetrics = JSON.parse(metrics(original)), rebuiltMetrics = JSON.parse(metrics(rebuilt));
    assert.equal(rebuiltMetrics.count, originalMetrics.count, label + ' glyph count');
    assert.equal(rebuiltMetrics.upem, originalMetrics.upem, label + ' units per em');
    assert.equal(rebuiltMetrics.family, originalMetrics.family, label + ' font family');
    for (const ch of sample.input) {
      const code = ch.codePointAt(0);
      assert.equal(glyph(rebuilt, code), glyph(original, code), label + ' glyph ' + code);
    }
  }
  assert.deepEqual(doc.manifest.views, sample.views, label + ' views');
  assert.deepEqual(doc.manifest.tables ?? [], sample.tables ?? [], label + ' tables');
  const actualParts = doc.manifest.parts.filter(part => part.t !== 'font');
  assert.equal(actualParts.length, sample.parts.length, label + ' part count');
  for (const [index, part] of sample.parts.entries()) {
    assert.equal(actualParts[index].t, part.type, label + ' part type');
    const actual = Buffer.from(await doc.part(actualParts[index].h));
    assert.equal(actualParts[index].h, part.hash, label + ' part hash');
    assert.deepEqual(actual, Buffer.from(part.data, 'base64'), label + ' part ' + index);
  }
}
console.log(`${conversions.length} CSV conversions match upstream layout, objects, indexes, tables and warnings including embedded font hashes.`);
