import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { BdfDocument, BufferSource } from '@bdfkit/core';
import { encode_fixture, encode_large_fixture, document_fixture } from '../../_build/js/debug/build/compat/parquet/parquet.js';

const cases = JSON.parse(await readFile(new URL('./upstream.json', import.meta.url)));
for (const [index, data] of cases.entries()) {
  assert.deepEqual(Buffer.from(encode_fixture(index)), Buffer.from(data, 'base64'), 'Parquet fixture ' + index);
}
const large = Buffer.from(encode_large_fixture('x'.repeat(1048576)));
assert.ok(large.includes(Buffer.from('preserved')), 'large pages retain following rows');
const doc = await BdfDocument.open(new BufferSource(document_fixture(true)));
assert.equal(doc.manifest.tables.length, 1);
const table = doc.manifest.tables[0];
assert.equal(table.id, 'data');
assert.equal(table.title, 'Names');
assert.equal(table.view, 'sheet1');
assert.equal(table.rows, 2);
assert.deepEqual(table.columns, [
  { name: 'name', type: 'string' },
  { name: 'amount', type: 'number' },
  { name: 'day', type: 'date' },
]);
assert.deepEqual(Buffer.from(await doc.part(table.part)), Buffer.from(cases[4], 'base64'));
const without = await BdfDocument.open(new BufferSource(document_fixture(false)));
assert.equal(without.manifest.tables.length, 0);
assert.equal(without.manifest.parts.length, 0);
console.log('Parquet bytes match upstream fixtures.');
