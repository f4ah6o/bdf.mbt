import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { list_substitutions } from '../../_build/js/debug/build/compat/gsub/gsub.js';
const cases = JSON.parse(gunzipSync(await readFile(new URL('./substitutions.json.gz', import.meta.url))));
for (const {name, data, index, limit, items, truncated} of cases) {
  const actual = JSON.parse(list_substitutions(Buffer.from(data ?? '', 'base64'), index, limit));
  assert.deepEqual(actual, {items, truncated}, `${name}: lookup ${index}, limit ${limit}`);
}
console.log(`${cases.length} lookup substitution enumerations match upstream.`);
