import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { load_font, has_cff_outlines, load_cff_outlines, cff_outline } from '../../_build/js/debug/build/compat/font/font.js';
const fonts = JSON.parse(gunzipSync(await readFile(new URL('./cff-outlines.json.gz', import.meta.url))));
let total = 0;
for (const {name, input, valid, cases} of fonts) {
  const font = load_font(gunzipSync(Buffer.from(input, 'base64')), 0);
  assert.equal(has_cff_outlines(font), valid, `${name}: CFF outlines validity`);
  if (!valid) continue;
  const cff = load_cff_outlines(font);
  for (const {glyph, ...expected} of cases) {
    const actual = JSON.parse(cff_outline(cff, glyph));
    assert.deepEqual(actual, expected, `${name}, glyph ${glyph}`);
    total++;
  }
}
console.log(`${total} CFF outlines from ${fonts.length} fonts match upstream.`);
