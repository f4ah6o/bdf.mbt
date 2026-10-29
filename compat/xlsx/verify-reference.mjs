import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { xlsx_reference } from '../../_build/js/debug/build/compat/xlsx/xlsx.js';
const cases = JSON.parse(await readFile(new URL('./reference.json', import.meta.url)));
for (const [i, c] of cases.entries()) assert.deepEqual(JSON.parse(xlsx_reference(c.input, c.column)), c.want, `XLSX reference case ${i}`);
console.log(`${cases.length} XLSX references and strings match upstream.`);
