import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { open_gpos, gpos_attachments, gpos_truncated } from '../../_build/js/debug/build/compat/gsub/gsub.js';
const cases = JSON.parse(gunzipSync(await readFile(new URL('./attachments.json.gz', import.meta.url))));
let lookups = 0;
for (const [c, {name, data, lookups: entries, truncated}] of cases.entries()) {
  const table = open_gpos(Buffer.from(data ?? '', 'base64'));
  for (const [i, expected] of entries.entries()) {
    assert.deepEqual(JSON.parse(gpos_attachments(table, i - 1)), expected, `${name} case ${c}, lookup ${i - 1}`);
    lookups++;
  }
  assert.equal(gpos_truncated(table), truncated, `${name} case ${c}: work budget`);
}
console.log(`${lookups} mark attachment lookups match upstream across ${cases.length} tables.`);
