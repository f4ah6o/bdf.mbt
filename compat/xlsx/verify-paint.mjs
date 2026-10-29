import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { xlsx_paint } from '../../_build/js/debug/build/compat/xlsx/xlsx.js';
const cases = JSON.parse(await readFile(new URL('./paint.json', import.meta.url)));
for (const [i, c] of cases.entries()) assert.deepEqual(JSON.parse(xlsx_paint(Buffer.from(c.input, 'base64'))), c.want, `XLSX paint styles case ${i}`);
console.log(`${cases.length} XLSX fill and border sets match upstream.`);
