import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { BdfDocument, BufferSource } from '@bdfkit/core';
import { csv_compressed_document, csv_compressed_warnings, load_font, glyph, advance, metrics } from '../../_build/js/debug/build/compat/font/font.js';
import { decode_woff2, decode_valid, decode_bytes } from '../../_build/js/debug/build/compat/woff2/woff2.js';
const cases = JSON.parse(await readFile(new URL('./csv.json', import.meta.url)));
const normalize = views => views.map(view => ({...view, ...(view.tiles ? {tiles:Object.fromEntries(Object.keys(view.tiles).map(k => [k,'normalized']))} : {})}));
let fonts = 0;
for (const sample of cases) {
  let font = await readFile(new URL('../../' + sample.file, import.meta.url));
  if (sample.noSubsetLicense) for (let i=0; i<font.readUInt16BE(4); i++) { const rec=12+i*16; if (font.toString('ascii',rec,rec+4)==='OS/2') font.writeUInt16BE(0x100,font.readUInt32BE(rec+8)+8); }
  if (sample.oversized) font = Buffer.concat([font, Buffer.alloc(2*1024*1024)]);
  const input = Buffer.from(sample.input), label = `${sample.file}:${sample.index ?? 0}:${sample.scenario}`;
  const doc = await BdfDocument.open(new BufferSource(csv_compressed_document(input,font,sample.scenario,sample.index ?? 0)));
  assert.deepEqual(JSON.parse(csv_compressed_warnings(input,font,sample.scenario,sample.index ?? 0)),sample.warnings ?? [],label+': warnings');
  assert.deepEqual(normalize(doc.manifest.views),normalize(sample.views),label+': views');
  assert.deepEqual(doc.manifest.tables ?? [],sample.tables ?? [],label+': tables');
  const embedded = doc.manifest.parts.find(part => part.t === 'font');
  assert.equal(!!embedded,!!sample.fontHash,label+': font availability');
  if (embedded) {
    const compressed=Buffer.from(await doc.part(embedded.h)); let program=compressed;
    if (compressed.subarray(0,4).toString()==='wOF2') { const decoded=decode_woff2(compressed); assert.equal(decode_valid(decoded),true,label+': WOFF2'); program=Buffer.from(decode_bytes(decoded)); fonts++; }
    const original=load_font(font,sample.index ?? 0), rebuilt=load_font(program,0);
    const a=JSON.parse(metrics(original)), b=JSON.parse(metrics(rebuilt));
    assert.equal(b.upem,a.upem,label+': units per em'); assert.equal(b.family,a.family,label+': family');
    for (const ch of sample.input) { const before=glyph(original,ch.codePointAt(0)), after=glyph(rebuilt,ch.codePointAt(0)); if (after !== 0) assert.equal(advance(rebuilt,after),advance(original,before),label+': glyph advance'); }
  }
}
console.log(`${cases.length} single-font CSV conversions preserve upstream views and font metrics; ${fonts} fonts encoded as WOFF2.`);
