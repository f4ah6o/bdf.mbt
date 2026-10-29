import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { score_tab_views } from '../../_build/js/debug/build/compat/midiinput/midiinput.js';
const cases = JSON.parse(gunzipSync(await readFile(new URL('./tab_views.json.gz', import.meta.url))));
for (const [i, c] of cases.entries()) {
  if (i % 100 === 0) process.stdout.write(`Checking TAB score ${i}/${cases.length}\n`);
  const actual = JSON.parse(score_tab_views(Buffer.from(c.input, 'base64'), c.width, c.height, c.sp, c.title));
  const expected = c.want.map(([id, title, pages]) => [id, title, pages.map(([w, h, hash]) => [Math.fround(w), Math.fround(h), hash])]);
  assert.deepEqual(actual, expected, `case ${i}`);
}
console.log(`${cases.length} MIDI scores' TAB view pages match upstream.`);
