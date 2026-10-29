import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { detect, inspect_file, select } from '../../_build/js/debug/build/compat/fontinput/fontinput.js';

const fixtures = JSON.parse(await readFile(new URL('./upstream.json', import.meta.url)));
for (const sample of fixtures.detect) assert.equal(detect(Buffer.from(sample.input ?? '', 'base64')), sample.result, 'font detection');
let choices = 0;
for (const sample of fixtures.files) {
  const input = gunzipSync(Buffer.from(sample.input, 'base64'));
  assert.equal(detect(input), sample.detect, sample.name + ' detection');
  const expected = sample.error ? {error:sample.error} : {error:'',container:sample.container,collection:sample.collection,size:sample.size,faces:sample.faces};
  assert.deepEqual(JSON.parse(inspect_file(input)), expected, sample.name + ' loading');
  for (const choice of sample.choices ?? []) {
    assert.deepEqual(JSON.parse(select(input, choice.spec)), {error:choice.error,indexes:choice.indexes,warnings:choice.warnings}, `${sample.name}: ${JSON.stringify(choice.spec)}`);
    choices++;
  }
}
console.log(`${fixtures.detect.length} detection cases, ${fixtures.files.length} font files and ${choices} collection selections match upstream.`);
