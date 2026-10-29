import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { file_credits } from '../../_build/js/debug/build/compat/midiinput/midiinput.js';
const samples = JSON.parse(await readFile(new URL('./credits.json', import.meta.url)));
for (const [i, sample] of samples.entries()) {
  const actual = JSON.parse(file_credits(Buffer.from(sample.input ?? '', 'base64')));
  assert.deepEqual(actual, sample.want, `credits ${i}`);
}
console.log(`${samples.length} MIDI credits and track naming cases match upstream.`);
