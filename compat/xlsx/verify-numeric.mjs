import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { xlsx_numeric } from '../../_build/js/debug/build/compat/xlsx/xlsx.js';
const cases = JSON.parse(await readFile(new URL('./numeric.json', import.meta.url)));
for (const [i, c] of cases.entries()) assert.deepEqual(JSON.parse(xlsx_numeric(c.code, c.value)), [c.pieces, c.general], `numeric case ${i}: ${c.value}, ${c.code}`);
console.log(`${cases.length} XLSX numeric displays match upstream.`);
