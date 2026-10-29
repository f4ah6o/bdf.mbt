import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { BdfDocument, BufferSource } from '@bdfkit/core';
import { csv_document, csv_warnings } from '../../_build/js/debug/build/compat/font/font.js';
import { cff_program, cff_order, raw_program, raw_order, sfnt_program, sfnt_supported, raw_prune } from '../../_build/js/debug/build/compat/cff/cff.js';

const cases = JSON.parse(await readFile(new URL('./upstream.json', import.meta.url)));
for (const [index, sample] of cases.entries()) {
  const font = await readFile(new URL('../../' + sample.file, import.meta.url));
  let cff;
  for (let i = 0; i < font.readUInt16BE(4); i++) {
    const rec = 12 + i * 16;
    if (font.toString('ascii', rec, rec + 4) === 'CFF ') {
      const offset = font.readUInt32BE(rec + 8), length = font.readUInt32BE(rec + 12);
      cff = font.subarray(offset, offset + length);
    }
  }
  assert.ok(cff, `CFF table ${index}`);
  assert.deepEqual(Buffer.from(cff_program(font, cff, sample.text)), Buffer.from(sample.program, 'base64'), `CFF bytes ${index}`);
  assert.deepEqual(JSON.parse(cff_order(font, cff, sample.text)), sample.order, `CFF glyph order ${index}`);
}
console.log(`${cases.length} real CFF programs and glyph orders match upstream.`);

const synthetic = JSON.parse(await readFile(new URL('./synthetic.json', import.meta.url)));
for (const sample of synthetic) {
  const data = Buffer.from(sample.data, 'base64');
  const glyphs = String.fromCodePoint(...sample.gids);
  if (sample.error) {
    assert.throws(() => raw_program(data, glyphs), sample.name);
    continue;
  }
  assert.deepEqual(Buffer.from(raw_program(data, glyphs)), Buffer.from(sample.program, 'base64'), sample.name + ' bytes');
  assert.deepEqual(JSON.parse(raw_order(data, glyphs)), sample.order, sample.name + ' glyph order');
}
assert.throws(() => raw_program(Buffer.alloc(3), ''), 'short header');
assert.throws(() => raw_program(Buffer.from([1, 0, 4, 1, 0, 1, 0]), ''), 'invalid INDEX');
console.log(`${synthetic.length} CFF composite, CID, subroutine and execution-limit cases match upstream.`);

const sfnts = JSON.parse(await readFile(new URL('./sfnt.json', import.meta.url)));
for (const sample of sfnts) {
  const font = Buffer.from(sample.data, 'base64');
  assert.equal(sfnt_supported(font, sample.text), sample.supported, sample.name + ' supported');
  assert.deepEqual(Buffer.from(sfnt_program(font, sample.text)), Buffer.from(sample.program, 'base64'), sample.name + ' SFNT bytes');
}
console.log(`${sfnts.length} CFF OpenType subsets and bounded fallbacks match upstream.`);

const large = JSON.parse(await readFile(new URL('./large.json', import.meta.url)));
const largeFont = gunzipSync(Buffer.from(large.font_gzip, 'base64'));
const input = Buffer.from(large.input);
const converted = await BdfDocument.open(new BufferSource(csv_document(input, largeFont, 10, 0)));
const baseline = await BdfDocument.open(new BufferSource(Buffer.from(large.bdf, 'base64')));
assert.deepEqual(JSON.parse(csv_warnings(input, largeFont, 10, 0)), large.warnings, 'large CFF warnings');
assert.deepEqual(converted.manifest.views, baseline.manifest.views, 'large CFF view');
assert.deepEqual(converted.manifest.parts, baseline.manifest.parts, 'large CFF parts');
assert.equal(converted.manifest.parts.some(part => part.t === 'font'), false, 'large CFF not embedded');
for (const part of converted.manifest.parts) {
  assert.deepEqual(Buffer.from(await converted.part(part.h)), Buffer.from(await baseline.part(part.h)), 'large CFF part ' + part.t);
}
console.log('Large unsubsettable CFF falls back with the upstream warning.');

const prunes = JSON.parse(await readFile(new URL('./prune.json', import.meta.url)));
const realFont = await readFile(new URL('../font/fixtures/stix.otf', import.meta.url));
let realCff;
for (let i = 0; i < realFont.readUInt16BE(4); i++) {
  const rec = 12 + i * 16;
  if (realFont.toString('ascii', rec, rec + 4) === 'CFF ') {
    const offset = realFont.readUInt32BE(rec + 8), length = realFont.readUInt32BE(rec + 12);
    realCff = realFont.subarray(offset, offset + length);
  }
}
for (const sample of prunes) {
  const input = sample.source === 'real' ? realCff : Buffer.from(synthetic.find(item => item.name === sample.name).data, 'base64');
  if (sample.error) { assert.throws(() => raw_prune(input, sample.glyphs), sample.name); continue; }
  const actual = Buffer.from(raw_prune(input, sample.glyphs));
  assert.equal(actual.length, sample.size, sample.name + ' retained glyph count size');
  assert.equal(createHash('sha256').update(actual).digest('hex'), sample.hash, sample.name + ' retained glyph numbers');
  if (sample.program) assert.deepEqual(actual, Buffer.from(sample.program, 'base64'));
}
console.log(`${prunes.length} CFF pruning cases preserve upstream glyph numbering and bytes.`);
