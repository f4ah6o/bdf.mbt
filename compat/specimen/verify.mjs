import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { glyph_program, sample_program, pruned_program } from '../../_build/js/debug/build/compat/specimen/specimen.js';

const samples = JSON.parse(gunzipSync(await readFile(new URL('./upstream.json.gz', import.meta.url))));
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
for (const sample of samples) {
  const input = gunzipSync(Buffer.from(sample.input, 'base64'));
  const actual = Buffer.from(glyph_program(input, sample.index));
  assert.equal(hash(actual), sample.outputHash, sample.name + ' glyph program');
  assert.equal(actual.length, sample.outputSize, sample.name + ' program length');
  if (sample.visual) assert.equal(hash(gunzipSync(Buffer.from(sample.visual, 'base64'))), sample.outputHash, sample.name + ' visual baseline');
  const actualSample = Buffer.from(sample_program(input, sample.index));
  assert.equal(actualSample.length > 0, sample.sampleOK, sample.name + ' sample availability');
  assert.equal(actualSample.length, sample.sampleSize, sample.name + ' sample size');
  assert.equal(hash(actualSample), sample.sampleHash, sample.name + ' whole sample');
  for (const prune of sample.pruned) {
    const actualPruned = Buffer.from(pruned_program(input, sample.index, prune.keep));
    assert.equal(actualPruned.length > 0, prune.ok, sample.name + ' pruned sample availability');
    assert.equal(actualPruned.length, prune.size, sample.name + ' pruned sample size');
    assert.equal(hash(actualPruned), prune.hash, sample.name + ' pruned sample ' + JSON.stringify(prune.text));
  }
}
console.log(`${samples.length} glyph, whole-sample and pruned TrueType programs match upstream byte for byte.`);
