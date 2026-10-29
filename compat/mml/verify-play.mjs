import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { mml_play } from '../../_build/js/debug/build/compat/mml/mml.js';
const cases = JSON.parse(await readFile(new URL('./play.json', import.meta.url)));
for (const [i, c] of cases.entries()) assert.deepEqual(JSON.parse(mml_play(c.input, c.dialect, c.octave, c.program)), c.want, `case ${i} ${c.dialect} ${JSON.stringify(c.input)}`);
console.log(`${cases.length} MML playback cases match upstream.`);
