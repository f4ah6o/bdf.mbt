import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { prepare_painter, paint_glyphs, painter_object } from '../../_build/js/debug/build/compat/specimen/specimen.js';
const fonts = JSON.parse(gunzipSync(await readFile(new URL('./paint.json.gz', import.meta.url))));
let count = 0;
for (const {name, input, index, cases} of fonts) {
  const bytes = gunzipSync(Buffer.from(input, 'base64'));
  for (const [i, {events, object}] of cases.entries()) {
    const painter = prepare_painter(bytes, index);
    for (const event of events) paint_glyphs(painter, event.glyphs, event.offsets, event.X, event.Y, event.Size, event.Alt);
    assert.ok(Buffer.from(painter_object(painter)).equals(Buffer.from(object, 'base64')), `${name}, face ${index}, case ${i}`);
    count++;
  }
}
console.log(`${count} outline painting objects match upstream byte for byte.`);
