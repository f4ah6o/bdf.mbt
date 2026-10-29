import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { isDeepStrictEqual } from 'node:util';
import { features } from '../../_build/js/debug/build/compat/specimen/specimen.js';
const cases = JSON.parse(gunzipSync(await readFile(new URL('./features.json.gz', import.meta.url))));
for (const [i, {name, input, index, groups}] of cases.entries()) {
  const actual = JSON.parse(features(gunzipSync(Buffer.from(input, 'base64')), index));
  if (!isDeepStrictEqual(actual, groups)) {
    const pos = Math.max(0, groups.findIndex((v, j) => !isDeepStrictEqual(v, actual[j])));
    console.error(name, i, pos, JSON.stringify(actual[pos]), JSON.stringify(groups[pos]));
    assert.fail(`${name} ${i}: feature groups differ`);
  }
}
console.log(`${cases.length} feature-group cases match upstream.`);
