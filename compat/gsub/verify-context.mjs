import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { lookup_contexts } from '../../_build/js/debug/build/compat/gsub/gsub.js';
const cases = JSON.parse(gunzipSync(await readFile(new URL('./context.json.gz', import.meta.url))));
let lookups = 0;
for (const [i, {name, data, gpos, contexts, truncated}] of cases.entries()) {
  const actual = JSON.parse(lookup_contexts(Buffer.from(data ?? '', 'base64'), gpos));
  assert.deepEqual(actual, {contexts, truncated}, `${name} ${i} ${gpos ? 'GPOS' : 'GSUB'}`);
  lookups += contexts.length;
}
console.log(`${lookups} contextual lookup inspections in ${cases.length} tables match upstream.`);
