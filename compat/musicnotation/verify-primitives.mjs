import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { curve, drawing } from '../../_build/js/debug/build/compat/musicnotation/musicnotation.js';
const samples = JSON.parse(await readFile(new URL('./primitives.json', import.meta.url)));
function compare(actual, expected, path) {
  if (typeof expected === 'number') { assert.ok(Math.abs(actual - expected) <= 1e-10, `${path}: ${actual} vs ${expected}`); return; }
  if (Array.isArray(expected)) { assert.equal(actual.length, expected.length, path); for (let i=0;i<expected.length;i++) compare(actual[i],expected[i],`${path}[${i}]`); return; }
  if (expected && typeof expected === 'object') { assert.deepEqual(Object.keys(actual).sort(), Object.keys(expected).sort(), path); for (const key of Object.keys(expected)) compare(actual[key],expected[key],`${path}.${key}`); return; }
  assert.deepEqual(actual,expected,path);
}
for (const [i, c] of samples.curves.entries()) compare(JSON.parse(curve(c.input)),c.want,`curve ${i}`);
for (const [i, c] of samples.drawings.entries()) compare(JSON.parse(drawing(c.ops,c.queries)),c.want,`drawing ${i}`);
console.log(`${samples.curves.length} curves and ${samples.drawings.length} drawing skylines match upstream.`);
