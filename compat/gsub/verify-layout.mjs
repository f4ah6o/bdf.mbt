import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { layout_metadata } from '../../_build/js/debug/build/compat/gsub/gsub.js';
const cases = JSON.parse(gunzipSync(await readFile(new URL('./layout.json.gz', import.meta.url))));
for (const [i, { name, data, gpos, ...expected }] of cases.entries()) {
  const actual = JSON.parse(layout_metadata(Buffer.from(data ?? '', 'base64'), gpos));
  assert.deepEqual(actual, expected, `${name} ${i} ${gpos ? 'GPOS' : 'GSUB'}`);
}
console.log(`${cases.length} GSUB and GPOS layout metadata cases match upstream.`);
