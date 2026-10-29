import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { prepare_sample_painter, paint_sample, paint_embedded_glyphs, glyph_painter_object } from '../../_build/js/debug/build/compat/specimen/specimen.js';
const fonts = JSON.parse(gunzipSync(await readFile(new URL('./sample-paint.json.gz', import.meta.url))));
let count = 0;
for (const {name, input, index, cases} of fonts) {
  const bytes = gunzipSync(Buffer.from(input, 'base64'));
  for (const [i, {events, mode, docLanguage, pre, post, advance, object}] of cases.entries()) {
    const painter = prepare_sample_painter(bytes, index, mode, docLanguage);
    if (pre) paint_embedded_glyphs(painter, [1, 2], [0, advance], 10, 20, 16, 'pre');
    for (const event of events) paint_sample(painter, event.Text, event.X, event.Y, event.Size, event.Rtl, event.Lang);
    if (post) paint_embedded_glyphs(painter, [1, 2], [0, advance], 30, 40, 16, 'post');
    assert.ok(Buffer.from(glyph_painter_object(painter)).equals(Buffer.from(object, 'base64')), `${name}, face ${index}, case ${i}, mode ${mode}`);
    count++;
  }
}
console.log(`${count} shaped and fallback sample-painting objects match upstream byte for byte.`);
