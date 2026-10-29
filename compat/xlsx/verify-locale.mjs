import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { xlsx_locale } from '../../_build/js/debug/build/compat/xlsx/xlsx.js';
const cases = JSON.parse(await readFile(new URL('./locale.json', import.meta.url)));
for (const [i, c] of cases.entries()) assert.deepEqual(JSON.parse(xlsx_locale(Buffer.from(c.input, 'base64'))), c.want, `XLSX locale case ${i}`);
console.log(`${cases.length} OOXML metadata and XLSX locales match upstream.`);
