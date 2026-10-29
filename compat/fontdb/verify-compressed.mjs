import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { BdfDocument, BufferSource } from '@bdfkit/core';
import { new_database, add_file, csv_compressed_document, csv_compressed_warnings } from '../../_build/js/debug/build/compat/fontdb/fontdb.js';
const fixture = JSON.parse(await readFile(new URL('./compressed.json', import.meta.url)));
const databases = fixture.groups.map(group => {
  const db = new_database();
  for (const index of group) { const file = fixture.files[index]; assert.equal(add_file(db, file.path, gunzipSync(Buffer.from(file.gzip, 'base64'))), 1); }
  return db;
});
let fonts = 0;
for (const sample of fixture.conversions) {
  const db = databases[sample.group], data = Buffer.from(sample.input);
  const label = `group ${sample.group}, scenario ${sample.scenario}, mode ${sample.mode}`;
  const doc = await BdfDocument.open(new BufferSource(csv_compressed_document(db, data, sample.scenario, sample.mode)));
  assert.deepEqual(JSON.parse(csv_compressed_warnings(db, data, sample.scenario, sample.mode)), sample.warnings ?? [], label + ': warnings');
  const normalize = views => views.map(view => ({...view, ...(view.tiles ? {tiles:Object.fromEntries(Object.keys(view.tiles).map(k => [k, 'normalized']))} : {})}));
  assert.deepEqual(normalize(doc.manifest.views), normalize(sample.views), label + ': views and indexes');
  assert.deepEqual(doc.manifest.tables ?? [], sample.tables ?? [], label + ': tables');
  assert.deepEqual(doc.manifest.parts.map(p => p.t), sample.parts.map(p => p.type), label + ': part types');
  for (const part of doc.manifest.parts.filter(p => p.t === 'font')) {
    assert.equal(Buffer.from(await doc.part(part.h)).subarray(0,4).toString(), 'wOF2', label + ': WOFF2 font'); fonts++;
  }
}
console.log(`${fixture.conversions.length} compressed multi-font CSV conversions match upstream layout and warnings; ${fonts} fonts embedded.`);
