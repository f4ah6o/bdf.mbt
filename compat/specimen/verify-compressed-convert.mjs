import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { BdfDocument, BufferSource } from '@bdfkit/core';
import { convert_specimen_compressed, converted_specimen_bytes, converted_specimen_report } from '../../_build/js/debug/build/compat/specimen/specimen.js';
const {files, cases} = JSON.parse(gunzipSync(await readFile(new URL('./compressed-convert.json.gz', import.meta.url))));
const decoded = Object.fromEntries(Object.entries(files).map(([name, data]) => [name, gunzipSync(Buffer.from(data, 'base64'))]));
let fonts = 0, pages = 0;
for (const [i, c] of cases.entries()) {
  const where = `${c.name}, case ${i}`;
  const result = convert_specimen_compressed(decoded[c.name], c.uiFont ? decoded['stix.ttf'] : new Uint8Array(), c.selection, c.title, c.text, c.system, c.noIndex, c.noSubset, c.ignore);
  assert.deepEqual(JSON.parse(converted_specimen_report(result)), {summary:c.summary,warnings:c.warnings}, `${where}: report`);
  const doc = await BdfDocument.open(new BufferSource(converted_specimen_bytes(result)));
  const meta = {...doc.manifest.meta}; delete meta.generator;
  assert.deepEqual(meta, c.meta, `${where}: metadata`);
  const withoutObjects = views => views.map(view => ({...view, pages: view.pages.map(page => ({...page, layers: page.layers.map(layer => ({...layer,obj:'normalized'}))}))}));
  assert.deepEqual(withoutObjects(doc.manifest.views), withoutObjects(c.views), `${where}: views and text indexes`);
  for (const part of doc.manifest.parts.filter(part => part.t === 'font')) {
    const bytes = Buffer.from(await doc.part(part.h));
    assert.equal(bytes.subarray(0,4).toString(), 'wOF2', `${where}: embedded font`); fonts++;
  }
  for (const part of c.parts.filter(part => part.type === 'idx')) {
    assert.deepEqual(Buffer.from(await doc.part(part.hash)), Buffer.from(part.data, 'base64'), `${where}: text index`);
  }
  pages += c.views.reduce((n, view) => n + view.pages.length, 0);
}
console.log(`${cases.length} WOFF2-embedded conversions match upstream metadata, ${pages} page layouts and text indexes; ${fonts} fonts encoded.`);
