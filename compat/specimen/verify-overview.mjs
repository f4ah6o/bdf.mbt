import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { isDeepStrictEqual } from 'node:util';
import { overview } from '../../_build/js/debug/build/compat/specimen/specimen.js';
const cases = JSON.parse(gunzipSync(await readFile(new URL('./overview.json.gz', import.meta.url))));
for (const [i, {name, input, index, outline, ...expected}] of cases.entries()) {
  const actual = JSON.parse(overview(gunzipSync(Buffer.from(input, 'base64')), index, outline));
  for (const key of ['sections','tables']) {
    if (!isDeepStrictEqual(actual[key], expected[key])) {
      const pos = expected[key].findIndex((v, j) => !isDeepStrictEqual(v, actual[key][j]));
      console.error(name, i, key, pos, JSON.stringify(actual[key][pos]), JSON.stringify(expected[key][pos]));
      assert.fail(`${name} ${i} ${key} differs`);
    }
  }
}
console.log(`${cases.length} specimen overview tables match upstream.`);
