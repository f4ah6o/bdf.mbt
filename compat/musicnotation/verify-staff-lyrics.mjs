import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { score_staff_lyrics } from '../../_build/js/debug/build/compat/midiinput/midiinput.js';
const samples = JSON.parse(gunzipSync(await readFile(new URL('./staff_lyrics.json.gz', import.meta.url))));
function compare(actual, expected, path) {
  if (typeof expected === 'number') { assert.ok(Math.abs(actual - expected) <= 1e-9, `${path}: ${actual} vs ${expected}`); return; }
  if (Array.isArray(expected)) { assert.equal(actual.length, expected.length, path); for (let i=0;i<expected.length;i++) compare(actual[i],expected[i],`${path}[${i}]`); return; }
  if (expected && typeof expected === 'object') { assert.deepEqual(Object.keys(actual).sort(),Object.keys(expected).sort(),path); for (const key of Object.keys(expected)) compare(actual[key],expected[key],`${path}.${key}`); return; }
  assert.deepEqual(actual,expected,path);
}
for (const [i, c] of samples.entries()) {
  const keys=Object.keys(c.widths), metrics=keys.flatMap(k=>c.metrics[k]);
  compare(JSON.parse(score_staff_lyrics(Buffer.from(c.input,'base64'),keys,keys.map(k=>c.widths[k]),metrics,c.width,c.indent)),c.want,`staff lyrics ${i}`);
}
console.log(`${samples.length} staff drawings with lyrics match upstream.`);
