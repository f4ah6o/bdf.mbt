import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { open_gpos, position_singles, position_pair, gpos_truncated } from '../../_build/js/debug/build/compat/gsub/gsub.js';
const cases = JSON.parse(gunzipSync(await readFile(new URL('./position-values.json.gz', import.meta.url))));
let lookups = 0, pairs = 0;
for (const [c, {name, data, lookups: entries, truncated}] of cases.entries()) {
  const table = open_gpos(Buffer.from(data ?? '', 'base64'));
  for (const [i, {singles, pairs: tests}] of entries.entries()) {
    assert.deepEqual(JSON.parse(position_singles(table, i)), singles, `${name} case ${c}, lookup ${i} singles`);
    for (const pair of tests) {
      assert.deepEqual(JSON.parse(position_pair(table, i, pair.first, pair.second)), pair, `${name} case ${c}, lookup ${i}, pair ${pair.first}/${pair.second}`);
      pairs++;
    }
    lookups++;
  }
  assert.equal(gpos_truncated(table), truncated, `${name} case ${c}: work budget`);
}
console.log(`${lookups} single-position lookups and ${pairs} pair queries match upstream across ${cases.length} tables.`);
