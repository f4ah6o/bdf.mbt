import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { inspect_gpos_pairs } from '../../_build/js/debug/build/compat/gsub/gsub.js';
const cases = JSON.parse(gunzipSync(await readFile(new URL('./gpos.json.gz', import.meta.url))));
for (const [i, {name, data, queries, ...expected}] of cases.entries()) {
  const actual = JSON.parse(inspect_gpos_pairs(Buffer.from(data ?? '', 'base64'), queries ?? []));
  assert.deepEqual(actual, expected, `${name} ${i}`);
}
console.log(`${cases.length} GPOS pair-count and shared-budget cases match upstream.`);
