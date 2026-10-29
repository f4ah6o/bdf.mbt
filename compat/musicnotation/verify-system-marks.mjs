import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { score_system_marks } from '../../_build/js/debug/build/compat/midiinput/midiinput.js';
const samples = JSON.parse(gunzipSync(await readFile(new URL('./system_marks.json.gz', import.meta.url))));
function compare(actual, expected, path) {
  if (typeof expected === 'number') { assert.ok(Math.abs(actual - expected) <= 1e-9, `${path}: ${actual} vs ${expected}`); return; }
  if (Array.isArray(expected)) { assert.equal(actual.length, expected.length, path); for (let i=0;i<expected.length;i++) compare(actual[i],expected[i],`${path}[${i}]`); return; }
  if (expected && typeof expected === 'object') { assert.deepEqual(Object.keys(actual).sort(),Object.keys(expected).sort(),path); for (const key of Object.keys(expected)) compare(actual[key],expected[key],`${path}.${key}`); return; }
  assert.deepEqual(actual,expected,path);
}
for (const [i, c] of samples.entries()) {
  const keys=Object.keys(c.widths), metrics=keys.flatMap(k=>c.metrics[k]);
  const sysKeys=Object.keys(c.systemMetrics), sysMetrics=sysKeys.flatMap(k=>c.systemMetrics[k]);
  compare(JSON.parse(score_system_marks(Buffer.from(c.input,'base64'),keys,keys.map(k=>c.widths[k]),metrics,sysKeys,sysMetrics,c.width,c.indent)),c.want,`system marks ${i}`);
}
console.log(`${samples.length} staff drawings with system marks match upstream.`);
