import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { track_notes } from '../../_build/js/debug/build/compat/midiinput/midiinput.js';

const samples = JSON.parse(await readFile(new URL('./notes.json', import.meta.url)));
for (const [i, sample] of samples.entries()) {
  const actual = JSON.parse(track_notes(Buffer.from(sample.input ?? '', 'base64'), sample.maxTick));
  assert.deepEqual(actual, sample.want, `track notes ${i}`);
}
console.log(`${samples.length} note, control, and warning cases match upstream.`);
