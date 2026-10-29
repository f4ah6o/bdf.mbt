import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { decode_woff2, decode_valid, decode_bytes } from '../../_build/js/debug/build/compat/woff2/woff2.js';
const cases = JSON.parse(gunzipSync(await readFile(new URL('./upstream.json.gz', import.meta.url))));
let valid = 0;
for (const [i, test] of cases.entries()) {
  const result = decode_woff2(Buffer.from(test.input ?? '', 'base64'));
  assert.equal(decode_valid(result), test.valid, `case ${i} ${test.name}: acceptance`);
  if (test.valid) {
    const actual = Buffer.from(decode_bytes(result)), expected = Buffer.from(test.output, 'base64');
    assert.ok(actual.equals(expected), `case ${i} ${test.name}: SFNT differs at ${actual.findIndex((v, k) => v !== expected[k])}, lengths ${actual.length}/${expected.length}`);
    valid++;
  }
}
console.log(`${cases.length} WOFF2 decoding cases, including ${valid} valid SFNTs, match upstream.`);
