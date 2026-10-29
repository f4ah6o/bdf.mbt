import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { xlsx_cells } from '../../_build/js/debug/build/compat/xlsx/xlsx.js';
const cases = JSON.parse(await readFile(new URL('./cells.json', import.meta.url)));
for (const [i, c] of cases.entries()) assert.deepEqual(JSON.parse(xlsx_cells(Buffer.from(c.input, 'base64'), c.part)), c.want, `XLSX cells case ${i}`);
console.log(`${cases.length} XLSX worksheet cell sets match upstream.`);
