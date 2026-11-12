import assert from 'node:assert/strict';
import { xlsx_workbook } from '../../_build/js/debug/build/compat/xlsx/xlsx.js';
import { loadFixture } from './fixtures.mjs';
const cases = await loadFixture('./workbook.json');
for (const [i, c] of cases.entries()) assert.deepEqual(JSON.parse(xlsx_workbook(Buffer.from(c.input, 'base64'))), c.want, `XLSX workbook case ${i}`);
console.log(`${cases.length} XLSX workbook sheet lists match upstream.`);
