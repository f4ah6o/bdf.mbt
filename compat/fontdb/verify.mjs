import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { BdfDocument, BufferSource } from '@bdfkit/core';
import { new_database, add_file, resolve, fallbacks, resolve_math, face_for, normalize, csv_document, csv_warnings } from '../../_build/js/debug/build/compat/fontdb/fontdb.js';

const fixture = JSON.parse(await readFile(new URL('./upstream.json', import.meta.url)));
const databases = fixture.groups.map(group => {
  const db = new_database();
  for (const index of group) {
    const file = fixture.files[index];
    assert.equal(add_file(db, file.path, gunzipSync(Buffer.from(file.gzip, 'base64'))), 1, file.path);
  }
  return db;
});
for (const sample of fixture.cases) {
  const db = databases[sample.group];
  let actual;
  switch (sample.kind) {
    case 'normalize': actual = normalize(sample.name); break;
    case 'resolve': actual = JSON.parse(resolve(db, sample.name, sample.bold, sample.italic, sample.cjk)); break;
    case 'fallbacks': actual = JSON.parse(fallbacks(db, sample.generic, sample.bold, sample.italic)); break;
    case 'math': actual = resolve_math(db, sample.name); break;
    case 'char': actual = JSON.parse(face_for(db, sample.latin, sample.ea, sample.code, sample.bold)); break;
    default: throw new Error('unexpected fixture');
  }
  assert.deepEqual(actual, sample.result, JSON.stringify(sample));
}
const longName = 'x' + '\u0315\u0300'.repeat(20000);
assert.equal(normalize(longName), longName.normalize('NFKC'), 'long combining sequences');
console.log(`${fixture.cases.length} font resolutions, fallbacks and normalization cases match upstream.`);

const collection = await readFile(new URL('../font/fixtures/bold.ttc', import.meta.url));
const collectionDb = new_database();
assert.equal(add_file(collectionDb, 'bold.ttc', collection), 2);
assert.equal(add_file(collectionDb, 'bold.ttc', collection), 0, 'duplicate collection');
assert.equal(JSON.parse(resolve(collectionDb, 'STIX Two Text', false, false, false)).index, 0);
assert.equal(JSON.parse(resolve(collectionDb, 'STIX Two Text', true, false, false)).index, 1);
const invalidCount = Buffer.from(collection);
invalidCount.writeUInt32BE(257, 8);
assert.equal(add_file(new_database(), 'oversized.ttc', invalidCount), 0, 'collection count limit');
assert.equal(add_file(new_database(), 'truncated.ttc', collection.subarray(0, 15)), 0, 'truncated collection directory');
const alphaBytes = gunzipSync(Buffer.from(fixture.files[11].gzip, 'base64'));
const manyFaces = new_database();
for (let i = 0; i < 64; i++) assert.equal(add_file(manyFaces, `alpha-${i}.ttf`, alphaBytes), 1);
assert.equal(JSON.parse(fallbacks(manyFaces, 'sans-serif', false, false)).length, 1, 'small databases include unlisted families');
assert.equal(add_file(manyFaces, 'alpha-64.ttf', alphaBytes), 1);
assert.equal(JSON.parse(fallbacks(manyFaces, 'sans-serif', false, false)).length, 0, 'large databases omit unlisted families');
console.log('Collection faces, duplicate paths, invalid boundaries and fallback limits verified.');

for (const sample of fixture.conversions) {
  const db = databases[sample.group];
  const data = Buffer.from(sample.input);
  const label = `group ${sample.group}, scenario ${sample.scenario}, mode ${sample.mode}`;
  const doc = await BdfDocument.open(new BufferSource(csv_document(db, data, sample.scenario, sample.mode)));
  assert.deepEqual(JSON.parse(csv_warnings(db, data, sample.scenario, sample.mode)), sample.warnings ?? [], label + ' warnings');
  assert.deepEqual(doc.manifest.views, sample.views, label + ' views');
  assert.deepEqual(doc.manifest.tables ?? [], sample.tables ?? [], label + ' tables');
  assert.deepEqual(doc.manifest.parts.map(part => ({type:part.t, hash:part.h})), sample.parts, label + ' parts');
}
console.log(`${fixture.conversions.length} multiple-font CSV conversions match upstream documents and warnings.`);
