import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { xlsx_date_format } from '../../_build/js/debug/build/compat/xlsx/xlsx.js';
const cases = JSON.parse(await readFile(new URL('./date-format.json', import.meta.url)));
for (const [i, c] of cases.entries()) assert.deepEqual(JSON.parse(xlsx_date_format(c.code, c.value, c.date1904)), [c.pieces, c.ok], `date format case ${i}: ${c.value}, ${c.code}, 1904=${c.date1904}`);
console.log(`${cases.length} XLSX date displays match upstream.`);
