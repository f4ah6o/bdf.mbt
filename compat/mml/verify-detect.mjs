import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { mml_detection } from '../../_build/js/debug/build/compat/mml/mml.js';
const cases = JSON.parse(await readFile(new URL('./detect.json', import.meta.url)));
for (const [i, c] of cases.entries()) assert.deepEqual(JSON.parse(mml_detection(c.input)), c.want, `case ${i} ${JSON.stringify(c.input)}`);
console.log(`${cases.length} MML detection and dialect cases match upstream.`);
