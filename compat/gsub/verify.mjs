import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { inspect_gsub } from '../../_build/js/debug/build/compat/gsub/gsub.js';

const samples = JSON.parse(gunzipSync(await readFile(new URL('./upstream.json.gz', import.meta.url))));
for (const sample of samples) {
  const actual = JSON.parse(inspect_gsub(Buffer.from(sample.data ?? '', 'base64'), sample.roots));
  assert.deepEqual(actual, {valid:sample.valid,result:sample.result,truncated:sample.truncated}, sample.name + ' roots ' + JSON.stringify(sample.roots));
}
console.log(`${samples.length} GSUB substitution closures match upstream.`);
