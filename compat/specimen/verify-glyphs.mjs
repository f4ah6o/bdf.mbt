import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { isDeepStrictEqual } from 'node:util';
import { glyph_details } from '../../_build/js/debug/build/compat/specimen/specimen.js';
const cases = JSON.parse(gunzipSync(await readFile(new URL('./glyphs.json.gz', import.meta.url))));
let count = 0;
for (const { name, index, input, ...expected } of cases) {
  const actual = JSON.parse(glyph_details(gunzipSync(Buffer.from(input, 'base64')), index));
  for (const key of ['glyphs', 'counts']) {
    if (!isDeepStrictEqual(actual[key], expected[key])) {
      const i = expected[key].findIndex((v, j) => !isDeepStrictEqual(v, actual[key][j]));
      console.error(name, key, i, actual[key][i], expected[key][i]);
      assert.fail(`${name} ${key} differs`);
    }
  }
  count += actual.glyphs.length;
}
console.log(`${cases.length} faces and ${count} glyph mappings match upstream Unicode script counts.`);
