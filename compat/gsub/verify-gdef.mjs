import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { inspect_gdef } from '../../_build/js/debug/build/compat/gsub/gsub.js';
const cases = JSON.parse(gunzipSync(await readFile(new URL('./gdef.json.gz', import.meta.url))));
for (const [i, {name, data, ...expected}] of cases.entries()) {
  const actual = JSON.parse(inspect_gdef(Buffer.from(data ?? '', 'base64')));
  assert.deepEqual(actual, expected, `${name} ${i}`);
}
console.log(`${cases.length} GDEF class, attachment and mark-set cases match upstream.`);
