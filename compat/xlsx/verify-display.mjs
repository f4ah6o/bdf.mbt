import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { xlsx_display } from '../../_build/js/debug/build/compat/xlsx/xlsx.js';
const cases = JSON.parse(await readFile(new URL('./display.json', import.meta.url)));
for (const [i, c] of cases.entries()) assert.deepEqual(JSON.parse(xlsx_display(Buffer.from(c.input, 'base64'), c.part, c.locale)), [c.palette, c.rows], `workbook display case ${i}`);
console.log(`${cases.length} XLSX worksheet cell displays match upstream.`);
