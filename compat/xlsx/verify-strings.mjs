import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { xlsx_strings } from '../../_build/js/debug/build/compat/xlsx/xlsx.js';
const cases = JSON.parse(await readFile(new URL('./strings.json', import.meta.url)));
for (const [i, c] of cases.entries()) assert.deepEqual(JSON.parse(xlsx_strings(Buffer.from(c.input, 'base64'))), c.want, `XLSX string case ${i}`);
console.log(`${cases.length} XLSX shared string tables match upstream.`);
