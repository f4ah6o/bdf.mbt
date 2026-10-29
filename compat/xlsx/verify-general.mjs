import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { xlsx_general } from '../../_build/js/debug/build/compat/xlsx/xlsx.js';
const cases = JSON.parse(await readFile(new URL('./general.json', import.meta.url)));
for (const c of cases) {
  const value = Buffer.from(c.bits, 'hex').readDoubleBE();
  assert.equal(xlsx_general(value, c.width), c.want, `XLSX General case ${c.index}: ${value}, width ${c.width}`);
}
// The upstream function recurses indefinitely for this value.
assert.equal(xlsx_general(Buffer.from('75154fdd7f73bf3f', 'hex').readDoubleBE(), 6), '');
console.log(`${cases.length} XLSX General numbers match upstream.`);
