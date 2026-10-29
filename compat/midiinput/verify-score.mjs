import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { score } from '../../_build/js/debug/build/compat/midiinput/midiinput.js';
const samples = JSON.parse(await readFile(new URL('./score.json', import.meta.url)));
for (const [i, sample] of samples.entries()) {
  assert.deepEqual(JSON.parse(score(Buffer.from(sample.input ?? '', 'base64'))),sample.want,`score ${i}`);
}
console.log(`${samples.length} MIDI-derived scores match upstream before engraving.`);
