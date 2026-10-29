import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { xlsx_format_sections } from '../../_build/js/debug/build/compat/xlsx/xlsx.js';
const cases = JSON.parse(await readFile(new URL('./sections.json', import.meta.url)));
for (const [i, c] of cases.entries()) assert.deepEqual(JSON.parse(xlsx_format_sections(c.code)), c.want, `format sections case ${i}`);
console.log(`${cases.length} XLSX number format section splits match upstream.`);
