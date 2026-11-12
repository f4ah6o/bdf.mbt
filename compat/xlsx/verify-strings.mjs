import assert from 'node:assert/strict';
import { xlsx_strings } from '../../_build/js/debug/build/compat/xlsx/xlsx.js';
import { loadFixture } from './fixtures.mjs';
const cases = await loadFixture('./strings.json');
for (const [i, c] of cases.entries()) assert.deepEqual(JSON.parse(xlsx_strings(Buffer.from(c.input, 'base64'))), c.want, `XLSX string case ${i}`);
console.log(`${cases.length} XLSX shared string tables match upstream.`);
