import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { xlsx_range } from '../../_build/js/debug/build/compat/xlsx/xlsx.js';
const cases = JSON.parse(await readFile(new URL('./range.json', import.meta.url)));
for (const [i, c] of cases.entries()) assert.deepEqual(JSON.parse(xlsx_range(c.input)), c.want, `XLSX range case ${i}: ${JSON.stringify(c.input)}`);
console.log(`${cases.length} XLSX ranges match upstream.`);
