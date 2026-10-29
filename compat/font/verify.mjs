import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { load_font, glyph, advance, metrics, geometry } from '../../_build/js/debug/build/compat/font/font.js';

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
}
assert.throws(() => load_font(new Uint8Array(11), 0));
assert.throws(() => load_font(new Uint8Array(12), 0));
const fontData = await readFile(new URL('../../compat/visual/synthetic.ttf', import.meta.url));
assert.throws(() => load_font(fontData, 1));
const collection = await readFile(new URL('./fixtures/bold.ttc', import.meta.url));
assert.throws(() => load_font(collection, 100));
assert.throws(() => load_font(collection.subarray(0, 12), 0));
console.log(`${synthetic.length} synthetic Unicode maps and malformed font boundaries match upstream.`);

const geometries = JSON.parse(await readFile(new URL('./geometry.json', import.meta.url)));
for (const sample of geometries) {
  const data = await readFile(new URL('../../' + sample.file, import.meta.url));
  const actual = JSON.parse(geometry(load_font(data, 0), sample.scenario));
  assert.deepEqual(actual.cols, sample.cols, `${sample.file}:${sample.scenario} columns`);
  assert.deepEqual(actual.rows, sample.rows, `${sample.file}:${sample.scenario} rows`);
  assert.equal(actual.frozen, sample.freeze?.rows ?? 0, `${sample.file}:${sample.scenario} frozen rows`);
}
console.log(`${geometries.length} single-font grid geometries match upstream.`);
