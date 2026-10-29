import assert from 'node:assert/strict';
import { isDeepStrictEqual } from 'node:util';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { specimen_names } from '../../_build/js/debug/build/compat/specimen/specimen.js';
const cases = JSON.parse(gunzipSync(await readFile(new URL('./names.json.gz', import.meta.url))));
let records = 0;
for (const { name, input, ...expected } of cases) {
  const actual = JSON.parse(specimen_names(Buffer.from(input, 'base64')));
  for (const key of Object.keys(expected)) {
    if (!isDeepStrictEqual(actual[key], expected[key])) {
      if (key === 'records') {
        const index = expected.records.findIndex((v, i) => !isDeepStrictEqual(v, actual.records[i]));
        console.error(name, key, index, 'actual', actual.records[index], 'expected', expected.records[index]);
      } else if (key === 'locals') {
        const index = expected.locals.findIndex((v, i) => !isDeepStrictEqual(v, actual.locals[i]));
        console.error(name, key, index, 'actual', actual.locals[index]?.slice(0,3), 'expected', expected.locals[index]?.slice(0,3));
      } else console.error(name, key, actual[key], expected[key]);
      assert.fail(`${name} ${key} differs`);
    }
  }
  records += expected.records.length;
}
console.log(`${cases.length} name tables and ${records} decoded records match upstream.`);
