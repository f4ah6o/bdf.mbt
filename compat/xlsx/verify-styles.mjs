import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { xlsx_styles } from '../../_build/js/debug/build/compat/xlsx/xlsx.js';
const cases = JSON.parse(await readFile(new URL('./styles.json', import.meta.url)));
for (const [i, c] of cases.entries()) assert.deepEqual(JSON.parse(xlsx_styles(Buffer.from(c.input, 'base64'))), c.want, `XLSX styles case ${i}`);
console.log(`${cases.length} XLSX font and cell format sets match upstream.`);
