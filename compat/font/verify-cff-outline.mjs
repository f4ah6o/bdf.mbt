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
    assert.equal(actual.ok, expected.ok, `${name}, glyph ${glyph} validity`);
    assert.deepEqual(actual.commands, expected.commands, `${name}, glyph ${glyph} commands`);
    if (expected.bounds === null) assert.equal(actual.bounds, null, `${name}, glyph ${glyph} bounds`);
    else {
      assert.ok(Array.isArray(actual.bounds), `${name}, glyph ${glyph} bounds missing`);
      for (let i = 0; i < 4; i++) assert.ok(Math.abs(actual.bounds[i] - expected.bounds[i]) <= 1e-10 * Math.max(1, Math.abs(expected.bounds[i])), `${name}, glyph ${glyph}, bound ${i}`);
    }
    total++;
  }
}
console.log(`${total} CFF outlines and bounds from ${fonts.length} fonts match upstream.`);
