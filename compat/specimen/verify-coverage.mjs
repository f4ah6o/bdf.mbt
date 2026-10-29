import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { coverage } from '../../_build/js/debug/build/compat/specimen/specimen.js';
const cases = JSON.parse(gunzipSync(await readFile(new URL('./coverage.json.gz', import.meta.url))));
let total = 0;
for (const sample of cases) {
  const actual = JSON.parse(coverage(gunzipSync(Buffer.from(sample.input, 'base64')), sample.index));
  assert.deepEqual(actual, sample.coverage, sample.name);
  total += actual.length;
}
console.log(`${cases.length} font coverage cases and ${total} block counts match upstream.`);
