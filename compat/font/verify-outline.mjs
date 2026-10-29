import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { load_font, truetype_outline } from '../../_build/js/debug/build/compat/font/font.js';
const fonts = JSON.parse(gunzipSync(await readFile(new URL('./outlines.json.gz', import.meta.url))));
let total = 0;
for (const {name, input, index, cases} of fonts) {
  const font = load_font(gunzipSync(Buffer.from(input, 'base64')), index);
  for (const {glyph, ...expected} of cases) {
    const actual = JSON.parse(truetype_outline(font, glyph));
    assert.deepEqual(actual, expected, `${name}, face ${index}, glyph ${glyph}`);
    total++;
  }
}
console.log(`${total} TrueType outlines match upstream.`);
