import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { score_systems } from '../../_build/js/debug/build/compat/midiinput/midiinput.js';
const samples = JSON.parse(await readFile(new URL('./systems.json', import.meta.url)));
function compare(actual, expected, path) {
  if (typeof expected === 'number') { assert.ok(Math.abs(actual - expected) <= 1e-9, `${path}: ${actual} vs ${expected}`); return; }
  if (Array.isArray(expected)) { assert.equal(actual.length, expected.length, path); for (let i=0;i<expected.length;i++) compare(actual[i],expected[i],`${path}[${i}]`); return; }
  assert.deepEqual(actual,expected,path);
}
for (const [i, c] of samples.entries()) compare(JSON.parse(score_systems(Buffer.from(c.input,'base64'),Object.keys(c.widths),Object.values(c.widths),c.width,c.indent)),c.want,`systems ${i}`);
console.log(`${samples.length} justified music system layouts match upstream.`);
