import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { paint_text } from '../../_build/js/debug/build/compat/musicnotation/musicnotation.js';
const cases = JSON.parse(gunzipSync(await readFile(new URL('./text_painter.json.gz', import.meta.url))));
const fonts = new Map([['', Buffer.alloc(0)]]);
for (const file of new Set(cases.map(c => c.file))) if (file) fonts.set(file, await readFile(new URL(`../font/fixtures/${file}`, import.meta.url)));
for (const [i, c] of cases.entries()) {
  const texts = c.lines.map(v => v[0]);
  const values = c.lines.flatMap(v => [v[1], v[2], v[3], v[4], +v[5], +v[6]]);
  assert.deepEqual(Buffer.from(JSON.parse(paint_text(c.file, fonts.get(c.file), c.lang, texts, values))), Buffer.from(c.want, 'base64'), `case ${i}`);
}
console.log(`${cases.length} music text BDF objects match upstream byte for byte.`);
