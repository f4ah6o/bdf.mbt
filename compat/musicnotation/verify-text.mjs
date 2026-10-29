import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { music_text } from '../../_build/js/debug/build/compat/musicnotation/musicnotation.js';
const cases = JSON.parse(gunzipSync(await readFile(new URL('./text.json.gz', import.meta.url))));
const fonts = new Map([['', Buffer.alloc(0)]]);
for (const file of new Set(cases.map(c => c.file))) if (file) fonts.set(file, await readFile(new URL(`../font/fixtures/${file}`, import.meta.url)));
function compare(actual, expected, path) {
  if (typeof expected === 'number') { assert.ok(Math.abs(actual - expected) <= 1e-9, `${path}: ${actual} vs ${expected}`); return; }
  if (Array.isArray(expected)) { assert.equal(actual.length, expected.length, path); for (let i = 0; i < expected.length; i++) compare(actual[i], expected[i], `${path}[${i}]`); return; }
  assert.deepEqual(actual, expected, path);
}
for (const [i, c] of cases.entries()) compare(JSON.parse(music_text(c.file, fonts.get(c.file), c.text, c.size, c.bold, c.italic)), c.want, `case ${i}`);
console.log(`${cases.length} music text measurements and font runs match upstream.`);
