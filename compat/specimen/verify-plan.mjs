import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { sample_plan } from '../../_build/js/debug/build/compat/specimen/specimen.js';

const cases = JSON.parse(gunzipSync(await readFile(new URL('./plan.json.gz', import.meta.url))));
for (const { name, input, index, text, ...expected } of cases) {
  const actual = JSON.parse(sample_plan(gunzipSync(Buffer.from(input, 'base64')), index, text));
  assert.deepEqual(actual, expected, name + ' ' + JSON.stringify(text));
}
console.log(`${cases.length} specimen sample plans match upstream.`);
