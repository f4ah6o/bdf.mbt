import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { decode_text } from '../../_build/js/debug/build/compat/midiinput/midiinput.js';
const samples = JSON.parse(await readFile(new URL('./text.json', import.meta.url)));
for (const [i, sample] of samples.entries()) {
  const actual = JSON.parse(decode_text(Buffer.from(sample.input ?? '', 'base64')));
  assert.deepEqual(actual, sample.want, `text ${i}`);
}
console.log(`${samples.length} MIDI metadata decoding cases match upstream.`);
