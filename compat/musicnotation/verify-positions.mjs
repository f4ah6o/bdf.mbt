import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { positions } from '../../_build/js/debug/build/compat/musicnotation/musicnotation.js';
const samples = JSON.parse(await readFile(new URL('./positions.json', import.meta.url)));
for (const [i, c] of samples.entries()) assert.deepEqual(JSON.parse(positions(c.fifths,c.sign,c.line,c.octave,c.events,c.notes)),c.want,`positions ${i}`);
console.log(`${samples.length} staff positions and accidental sets match upstream.`);
