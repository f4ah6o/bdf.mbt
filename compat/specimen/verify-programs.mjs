import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { prepare_programs } from '../../_build/js/debug/build/compat/specimen/specimen.js';
const {inputs, cases} = JSON.parse(gunzipSync(await readFile(new URL('./programs.json.gz', import.meta.url))));
for (const {name, input, selection, text, ignore, ...expected} of cases) {
  const actual = JSON.parse(prepare_programs(gunzipSync(Buffer.from(inputs[input], 'base64')), selection, text, ignore));
  assert.deepEqual(actual, expected, `${name}, selection=${selection}, ignore=${ignore}, text=${text}`);
}
console.log(`${cases.length} specimen embedding plans match upstream.`);
