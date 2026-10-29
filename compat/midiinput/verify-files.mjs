import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { read_file } from '../../_build/js/debug/build/compat/midiinput/midiinput.js';

const samples = JSON.parse(await readFile(new URL('./files.json', import.meta.url)));
for (const [i, sample] of samples.entries()) {
  const actual = JSON.parse(read_file(Buffer.from(sample.input ?? '', 'base64')));
  if (!actual.error && actual.smf !== null) actual.smf = Buffer.from(actual.smf).toString('base64');
  assert.deepEqual(actual, sample.want, `file ${i}`);
}
console.log(`${samples.length} MIDI file and repair cases match upstream.`);
