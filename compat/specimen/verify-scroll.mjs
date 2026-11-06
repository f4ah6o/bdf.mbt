import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
const ffiArray = value => {
  if (Array.isArray(value)) {
    value.buf = value;
    value.len = value.length;
  }
  return value;
};

import { scroll_plan } from '../../_build/js/debug/build/compat/specimen/specimen.js';
const cases = JSON.parse(gunzipSync(await readFile(new URL('./scroll.json.gz', import.meta.url))));
for (const [i, {events, ...expected}] of cases.entries()) {
  const actual = JSON.parse(scroll_plan(ffiArray(events.map(e => e.kind)), ffiArray(events.map(e => e.value)), ffiArray(events.map(e => e.name))));
  assert.deepEqual(actual, expected, `scroll case ${i}`);
}
console.log(`${cases.length} specimen scroll layouts match upstream.`);
