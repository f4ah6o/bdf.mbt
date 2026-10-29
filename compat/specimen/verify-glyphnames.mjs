import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { glyph_names } from '../../_build/js/debug/build/compat/specimen/specimen.js';

const cases = JSON.parse(gunzipSync(await readFile(new URL('./glyphnames.json.gz', import.meta.url))));
for (const sample of cases) {
  const actual = JSON.parse(glyph_names(gunzipSync(Buffer.from(sample.input, 'base64')), sample.index));
  assert.deepEqual(actual, sample.names, sample.name);
}
console.log(`${cases.length} TrueType and CFF glyph name sets match upstream.`);
