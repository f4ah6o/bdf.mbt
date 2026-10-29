import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { ooxml_package } from '../../_build/js/debug/build/compat/ooxml/ooxml.js';
const cases = JSON.parse(await readFile(new URL('./package.json', import.meta.url)));
for (const [i, c] of cases.entries()) {
  const want = [c.want[0].map(([exists, size, content, error]) => [exists, size, content === null ? null : [...Buffer.from(content, 'base64')], error]), c.want[1], c.want[2], c.want[3]];
  const actual = JSON.parse(ooxml_package(Buffer.from(c.input, 'base64')));
  for (const rels of actual[1]) rels.sort((a, b) => a[0] < b[0] ? -1 : a[0] > b[0] ? 1 : 0);
  assert.deepEqual(actual, want, `OOXML package case ${i}`);
}
console.log(`${cases.length} OOXML packages match upstream part and relationship handling.`);
