import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { mml_source } from '../../_build/js/debug/build/compat/mml/mml.js';
const cases = JSON.parse(await readFile(new URL('./source.json', import.meta.url)));
for (const [i, c] of cases.entries()) assert.deepEqual(JSON.parse(mml_source(c.input, c.dialect)), c.want, `case ${i} ${c.dialect} ${JSON.stringify(c.input)}`);
console.log(`${cases.length} MML source and comment cases match upstream.`);
