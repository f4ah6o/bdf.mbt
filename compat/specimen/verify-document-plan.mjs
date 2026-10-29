import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { document_plan } from '../../_build/js/debug/build/compat/specimen/specimen.js';
const cases = JSON.parse(gunzipSync(await readFile(new URL('./document-plan.json.gz', import.meta.url))));
for (const {name, input, selection, title, ...expected} of cases) {
  const actual = JSON.parse(document_plan(gunzipSync(Buffer.from(input, 'base64')), selection, title));
  assert.deepEqual(actual, expected, `${name}, selection=${selection}, title=${title}`);
}
console.log(`${cases.length} specimen document plans match upstream conversion.`);
