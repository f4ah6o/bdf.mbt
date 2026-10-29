import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { lyrics } from '../../_build/js/debug/build/compat/midiinput/midiinput.js';
const samples = JSON.parse(await readFile(new URL('./lyrics.json', import.meta.url)));
for (const [i, sample] of samples.entries()) {
  const actual = JSON.parse(lyrics(Buffer.from(sample.input ?? '', 'base64')));
  assert.deepEqual(actual, sample.want, `lyrics ${i}`);
}
console.log(`${samples.length} MIDI lyric assignment cases match upstream.`);
