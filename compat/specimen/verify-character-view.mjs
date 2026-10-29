import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { render_character_view, glyph_view_count, glyph_view_height, glyph_view_object } from '../../_build/js/debug/build/compat/specimen/specimen.js';
const {files, cases} = JSON.parse(gunzipSync(await readFile(new URL('./character-view.json.gz', import.meta.url))));
const decoded = Object.fromEntries(Object.entries(files).map(([name, data]) => [name, gunzipSync(Buffer.from(data, 'base64'))]));
let pageCount = 0;
for (const [i, {name, index, uiFont, system, outlined, glyphHash, pages}] of cases.entries()) {
  const view = render_character_view(decoded[name], index, uiFont ? decoded['stix.ttf'] : new Uint8Array(), system, outlined, glyphHash);
  assert.equal(glyph_view_count(view), pages.length, `case ${i}: page count`);
  for (const [j, page] of pages.entries()) {
    assert.equal(glyph_view_height(view, j), page.height, `case ${i}, page ${j}: height`);
    const actual = Buffer.from(glyph_view_object(view, j));
    const expected = Buffer.from(page.object, 'base64');
    assert.ok(actual.equals(expected), `case ${i} (${name}, face ${index}, system=${system}, outlined=${outlined}), page ${j}: object; first difference ${actual.findIndex((v, k) => v !== expected[k])}, lengths ${actual.length}/${expected.length}`);
    pageCount++;
  }
}
console.log(`${pageCount} character-chart pages in ${cases.length} views match upstream byte for byte.`);
