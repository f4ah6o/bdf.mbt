import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { decode, error } from '../../_build/js/debug/build/compat/woff/woff.js';

const samples = JSON.parse(await readFile(new URL('./upstream.json', import.meta.url)));
for (const sample of samples) {
  const input = gunzipSync(Buffer.from(sample.input, 'base64'));
  assert.equal(error(input), sample.error, sample.name + ' error');
  if (!sample.error) assert.deepEqual(Buffer.from(decode(input)), gunzipSync(Buffer.from(sample.output, 'base64')), sample.name + ' SFNT bytes');
}
console.log(`${samples.length} WOFF containers match upstream decoding and errors.`);
