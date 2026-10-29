import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { info_tables } from '../../_build/js/debug/build/compat/specimen/specimen.js';
const cases = JSON.parse(gunzipSync(await readFile(new URL('./info.json.gz', import.meta.url))));
for (const [index, {name,tables,...expected}] of cases.entries()) {
  const input = tag => Buffer.from(tables[tag] ?? '', 'base64');
  const actual = JSON.parse(info_tables(input('cmap'),input('meta'),input('COLR'),input('CPAL'),input('sbix'),input('CBLC'),input('SVG ')));
  assert.deepEqual(actual, expected, `${name} ${index}`);
}
console.log(`${cases.length} cmap variation, language and color-table cases match upstream.`);
