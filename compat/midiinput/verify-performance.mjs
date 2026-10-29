import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { performance } from '../../_build/js/debug/build/compat/midiinput/midiinput.js';
const samples = JSON.parse(await readFile(new URL('./performance.json', import.meta.url)));
for (const [i, sample] of samples.entries()) {
  const actual = JSON.parse(performance(Buffer.from(sample.input ?? '', 'base64')));
  assert.deepEqual(actual, sample.want, `performance ${i}`);
}
console.log(`${samples.length} MIDI performance cases match upstream (excluding lyrics).`);
