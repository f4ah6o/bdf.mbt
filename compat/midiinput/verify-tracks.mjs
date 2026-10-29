import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { scan_track } from '../../_build/js/debug/build/compat/midiinput/midiinput.js';

const samples = JSON.parse(await readFile(new URL('./tracks.json', import.meta.url)));
for (const [i, sample] of samples.entries()) {
  const actual = JSON.parse(scan_track(Buffer.from(sample.input ?? '', 'base64'), sample.maxTick));
  assert.deepEqual(actual, sample.want, `track ${i}`);
}
console.log(`${samples.length} track boundary cases match upstream.`);
