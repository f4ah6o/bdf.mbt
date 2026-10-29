import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { prepare_score } from '../../_build/js/debug/build/compat/midiinput/midiinput.js';
const samples = JSON.parse(await readFile(new URL('./prepare.json', import.meta.url)));
for (const [i, c] of samples.entries()) assert.deepEqual(JSON.parse(prepare_score(Buffer.from(c.input, 'base64'))),c.want,`prepare ${i}`);
console.log(`${samples.length} prepared MIDI scores match upstream.`);
