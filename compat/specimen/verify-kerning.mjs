import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { kerning_description } from '../../_build/js/debug/build/compat/specimen/specimen.js';
const cases = JSON.parse(gunzipSync(await readFile(new URL('./kerning.json.gz', import.meta.url))));
for (const sample of cases) {
  assert.equal(kerning_description(gunzipSync(Buffer.from(sample.input, 'base64')), sample.index), sample.result, sample.name);
}
console.log(`${cases.length} specimen kerning descriptions match upstream.`);
