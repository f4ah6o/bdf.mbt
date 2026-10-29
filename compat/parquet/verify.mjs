import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { encode_fixture, encode_large_fixture } from '../../_build/js/debug/build/compat/parquet/parquet.js';

const cases = JSON.parse(await readFile(new URL('./upstream.json', import.meta.url)));
for (const [index, data] of cases.entries()) {
  assert.deepEqual(Buffer.from(encode_fixture(index)), Buffer.from(data, 'base64'), 'Parquet fixture ' + index);
}
const large = Buffer.from(encode_large_fixture('x'.repeat(1048576)));
assert.ok(large.includes(Buffer.from('preserved')), 'large pages retain following rows');
console.log('Parquet bytes match upstream fixtures.');
