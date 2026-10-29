import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { score_columns } from '../../_build/js/debug/build/compat/midiinput/midiinput.js';
const samples = JSON.parse(await readFile(new URL('./columns.json', import.meta.url)));
function compare(actual, expected, path) {
  if (typeof expected === 'number') { assert.ok(Math.abs(actual - expected) <= 1e-10, `${path}: ${actual} vs ${expected}`); return; }
  if (Array.isArray(expected)) { assert.equal(actual.length, expected.length, path); for (let i=0;i<expected.length;i++) compare(actual[i],expected[i],`${path}[${i}]`); return; }
  if (expected && typeof expected === 'object') { assert.deepEqual(Object.keys(actual).sort(), Object.keys(expected).sort(), path); for (const key of Object.keys(expected)) compare(actual[key],expected[key],`${path}.${key}`); return; }
  assert.deepEqual(actual,expected,path);
}
for (const [i, c] of samples.entries()) compare(JSON.parse(score_columns(Buffer.from(c.input,'base64'),Object.keys(c.widths),Object.values(c.widths))),c.want,`columns ${i}`);
console.log(`${samples.length} music measure columns match upstream.`);
