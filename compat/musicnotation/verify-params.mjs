import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { music_params } from '../../_build/js/debug/build/compat/musicnotation/musicnotation.js';
const cases = JSON.parse(await readFile(new URL('./params.json', import.meta.url)));
for (const [i, c] of cases.entries()) assert.deepEqual(JSON.parse(music_params(c.input)), c.want, `case ${i} ${JSON.stringify(c.input)}`);
console.log(`${cases.length} music parameter parsing cases match upstream.`);
