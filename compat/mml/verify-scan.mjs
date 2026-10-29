import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { mml_scan } from '../../_build/js/debug/build/compat/mml/mml.js';
const cases = JSON.parse(await readFile(new URL('./scan.json', import.meta.url)));
for (const [i, c] of cases.entries()) assert.deepEqual(JSON.parse(mml_scan(c.input)), c.want, `case ${i} ${JSON.stringify(c.input)}`);
console.log(`${cases.length} MML number, length and loop scanning cases match upstream.`);
