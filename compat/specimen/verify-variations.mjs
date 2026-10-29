import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { variations } from '../../_build/js/debug/build/compat/specimen/specimen.js';
const fixture = JSON.parse(gunzipSync(await readFile(new URL('./variations.json.gz', import.meta.url))));
const names = Buffer.from(fixture.names, 'base64');
for (const [index, sample] of fixture.cases.entries()) {
  const actual = JSON.parse(variations(Buffer.from(sample.data ?? '', 'base64'), names));
  assert.deepEqual(actual, { axes: sample.axes, instances: sample.instances }, `${sample.name} ${index}`);
}
console.log(`${fixture.cases.length} variable-font tables match upstream.`);
