import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { scroll_plan } from '../../_build/js/debug/build/compat/specimen/specimen.js';
const cases = JSON.parse(gunzipSync(await readFile(new URL('./scroll.json.gz', import.meta.url))));
for (const [i, {events, ...expected}] of cases.entries()) {
  const actual = JSON.parse(scroll_plan(events.map(e => e.kind), events.map(e => e.value), events.map(e => e.name)));
  assert.deepEqual(actual, expected, `scroll case ${i}`);
}
console.log(`${cases.length} specimen scroll layouts match upstream.`);
