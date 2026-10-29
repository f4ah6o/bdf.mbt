import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { xlsx_workbook } from '../../_build/js/debug/build/compat/xlsx/xlsx.js';
const cases = JSON.parse(await readFile(new URL('./workbook.json', import.meta.url)));
for (const [i, c] of cases.entries()) assert.deepEqual(JSON.parse(xlsx_workbook(Buffer.from(c.input, 'base64'))), c.want, `XLSX workbook case ${i}`);
console.log(`${cases.length} XLSX workbook sheet lists match upstream.`);
