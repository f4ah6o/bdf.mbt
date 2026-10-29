import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { spell, estimate, time } from '../../_build/js/debug/build/compat/musicnotation/musicnotation.js';
const samples = JSON.parse(await readFile(new URL('./upstream.json', import.meta.url)));
for (const [i, c] of samples.spelling.entries()) assert.deepEqual(JSON.parse(spell(c.key,c.fifths,c.minor,c.hint)), c.want, `spelling ${i}`);
for (const [i, c] of samples.estimate.entries()) assert.deepEqual(JSON.parse(estimate(c.hist,c.flats)), c.want, `estimate ${i}`);
for (const [i, c] of samples.meter.entries()) assert.deepEqual(JSON.parse(time(c.beats,c.beatType)), c.want, `meter ${i}`);
console.log(`${samples.spelling.length} pitch spellings, ${samples.estimate.length} key estimates, and ${samples.meter.length} meters match upstream.`);
