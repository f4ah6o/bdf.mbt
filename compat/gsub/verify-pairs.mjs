import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { open_gpos, position_pairs, gpos_truncated } from '../../_build/js/debug/build/compat/gsub/gsub.js';
const cases = JSON.parse(gunzipSync(await readFile(new URL('./pairs.json.gz', import.meta.url))));
let calls = 0, pairs = 0;
for (const [c, {name, data, lookups: entries, truncated}] of cases.entries()) {
  const table = open_gpos(Buffer.from(data ?? '', 'base64'));
  for (const [i, runs] of entries.entries()) for (const [n, expected] of runs.entries()) {
    assert.deepEqual(JSON.parse(position_pairs(table, i - 1, [1, 20, 100][n])), expected, `${name} case ${c}, lookup ${i - 1}, run ${n}`);
    calls++; pairs += expected.length;
  }
  assert.equal(gpos_truncated(table), truncated, `${name} case ${c}: work budget`);
}
console.log(`${calls} pair enumeration calls (${pairs} pairs) match upstream across ${cases.length} tables.`);
