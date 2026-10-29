import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { BdfDocument, BufferSource } from '@bdfkit/core';
import { new_database, add_file, csv_document, csv_warnings } from '../../_build/js/debug/build/compat/fontdb/fontdb.js';
const fixture = JSON.parse(await readFile(new URL('./upstream.json', import.meta.url)));
const cases = JSON.parse(await readFile(new URL('./order.json', import.meta.url)));
for (const sample of cases) {
  const db = new_database();
  for (const file of sample.files) assert.equal(add_file(db, file.path, gunzipSync(Buffer.from(fixture.files[file.index].gzip, 'base64'))), 1);
  const input = Buffer.from(sample.input);
  const doc = await BdfDocument.open(new BufferSource(csv_document(db, input, 0, sample.mode)));
  const label = `case ${sample.case} mode ${sample.mode}`;
  assert.deepEqual(JSON.parse(csv_warnings(db,input,0,sample.mode)),sample.warnings ?? [],label+' warnings');
  assert.deepEqual(doc.manifest.views,sample.views,label+' views');
  assert.deepEqual(doc.manifest.parts.map(p => ({type:p.t,hash:p.h})),sample.parts,label+' parts');
}
console.log(`${cases.length} font embedding orders match upstream.`);
