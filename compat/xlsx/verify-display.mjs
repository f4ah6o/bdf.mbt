import assert from 'node:assert/strict';
import { xlsx_display } from '../../_build/js/debug/build/compat/xlsx/xlsx.js';
import { loadFixture } from './fixtures.mjs';
const cases = await loadFixture('./display.json');
for (const [i, c] of cases.entries()) assert.deepEqual(JSON.parse(xlsx_display(Buffer.from(c.input, 'base64'), c.part, c.locale)), [c.palette, c.rows], `workbook display case ${i}`);
console.log(`${cases.length} XLSX worksheet cell displays match upstream.`);
