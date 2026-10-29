import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { barline } from '../../_build/js/debug/build/compat/musicnotation/musicnotation.js';
const cases = JSON.parse(gunzipSync(await readFile(new URL('./barlines.json.gz', import.meta.url))));
function compare(actual, expected, path) {
  if (typeof expected === 'number') { assert.ok(Math.abs(actual - expected) <= 1e-9, `${path}: ${actual} vs ${expected}`); return; }
  if (Array.isArray(expected)) { assert.equal(actual.length, expected.length, path); for (let i = 0; i < expected.length; i++) compare(actual[i], expected[i], `${path}[${i}]`); return; }
  assert.deepEqual(actual, expected, path);
}
for (const [i, c] of cases.entries()) compare(JSON.parse(barline(c.kind, c.x, c.top, c.bottom, c.tops, c.left)), c.want, `case ${i}`);
console.log(`${cases.length} barline drawings match upstream.`);
